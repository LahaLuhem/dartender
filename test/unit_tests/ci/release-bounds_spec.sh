# shellcheck shell=bash
# shellcheck disable=SC2154  # ShellSpec sets the SHELLSPEC_* variables
Include test/utils/pub.sh

Describe 'ci/release-bounds.sh'
  script="${SHELLSPEC_PROJECT_ROOT}/scripts/ci/release-bounds.sh"

  setup() {
    repo="$(mktemp -d "${SHELLSPEC_TMPBASE}/repo.XXXXXX")"
    cd "${repo}" || return
  }
  BeforeEach 'setup'

  # Writes folder $1's pubspec for package $2, with the lines in $3 after its name.
  pubspec() {
    mkdir -p "$1"
    printf 'name: %s\n%s' "$2" "${3-}" > "$1/pubspec.yaml"
  }

  It "refuses a release whose own bound on a sibling is below the major the repo builds against"
    pubspec . w $'publish_to: none\n'
    pubspec packages/a a $'version: 2.0.0\n'
    pubspec packages/b b $'version: 1.1.0\ndependencies:\n  a: ">=1.0.0 <3.0.0"\n'
    pub_lists w:. a:packages/a b:packages/b
    When run script "${script}" b 1.1.0
    The status should be failure
    The error should include '>=1.0.0 <3.0.0'
  End

  It "raises a dependent's lower bound to the new version, as a caret, and changes nothing else"
    pubspec . w $'publish_to: none\n'
    mkdir -p packages/a
    # Comments on top, like minted's, which throw yq's line numbers off.
    printf '# One.\n# Two.\nname: a\nversion: 2.0.0\ndependencies:\n  # Kept as written.\n  b: %s\n\n  c: ^1.0.0\n' \
      '">=1.0.0 <2.0.0"' > packages/a/pubspec.yaml
    pubspec packages/b b $'version: 1.1.0\ndependencies:\n  c: ^1.0.0\n'
    pubspec packages/c c $'version: 1.2.0\n'
    pub_lists w:. a:packages/a b:packages/b c:packages/c
    When run script "${script}" b 1.1.0
    The output should include 'packages/a/pubspec.yaml'
    The contents of file packages/a/pubspec.yaml should equal \
      $'# One.\n# Two.\nname: a\nversion: 2.0.0\ndependencies:\n  # Kept as written.\n  b: ^1.1.0\n\n  c: ^1.0.0'
  End

  It 'raises the entry in its own section, as indented, and leaves an override of it alone'
    pubspec . w $'publish_to: none\n'
    pubspec packages/a a $'version: 2.0.0\ndependencies:\n    b: ^1.0.0\ndependency_overrides:\n  b:\n    path: ../b\n'
    pubspec packages/b b $'version: 1.1.0\n'
    pub_lists w:. a:packages/a b:packages/b
    When run script "${script}" b 1.1.0
    The output should include 'packages/a/pubspec.yaml'
    The contents of file packages/a/pubspec.yaml should equal \
      $'name: a\nversion: 2.0.0\ndependencies:\n    b: ^1.1.0\ndependency_overrides:\n  b:\n    path: ../b'
  End

  It "raises dev dependencies' bounds too, the workspace root's included"
    pubspec . w $'publish_to: none\ndev_dependencies:\n  b: ^1.0.0\n'
    pubspec packages/b b $'version: 1.1.0\n'
    pubspec packages/c c $'publish_to: none\ndev_dependencies:\n  b: ^1.0.0\n'
    pub_lists w:. b:packages/b c:packages/c
    When run script "${script}" b 1.1.0
    The output should include 'packages/c/pubspec.yaml'
    The contents of file pubspec.yaml should equal $'name: w\npublish_to: none\ndev_dependencies:\n  b: ^1.1.0'
    The contents of file packages/c/pubspec.yaml should equal \
      $'name: c\npublish_to: none\ndev_dependencies:\n  b: ^1.1.0'
  End

  It 'leaves a bound already at the new version alone'
    pubspec . w $'publish_to: none\n'
    pubspec packages/a a $'version: 1.0.0\ndependencies:\n  b: ">=1.1.0 <2.0.0"\n'
    pubspec packages/b b $'version: 1.1.0\n'
    pub_lists w:. a:packages/a b:packages/b
    When run script "${script}" b 1.1.0
    The contents of file packages/a/pubspec.yaml should equal \
      $'name: a\nversion: 1.0.0\ndependencies:\n  b: ">=1.1.0 <2.0.0"'
  End

  It 'ignores bounds with no version in them, like any'
    pubspec . w $'publish_to: none\n'
    pubspec packages/a a $'version: 2.0.0\ndependencies:\n  b: any\n'
    pubspec packages/b b $'version: 1.1.0\ndependencies:\n  a: any\n'
    pub_lists w:. a:packages/a b:packages/b
    When run script "${script}" b 1.1.0
    The status should be success
    The contents of file packages/a/pubspec.yaml should equal \
      $'name: a\nversion: 2.0.0\ndependencies:\n  b: any'
  End

  It "fails with pub's own error when the packages can't be listed"
    pubspec . a $'version: 1.1.0\n'
    pub_fails 'Error on line 1 of packages/b/pubspec.yaml'
    When run script "${script}" a 1.1.0
    The status should be failure
    The output should equal ''
    The error should equal 'Error on line 1 of packages/b/pubspec.yaml'
  End
End
