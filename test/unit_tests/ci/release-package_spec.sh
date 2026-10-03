# shellcheck shell=bash
# shellcheck disable=SC2154  # ShellSpec sets the SHELLSPEC_* variables
Include test/utils/pub.sh

Describe 'ci/release-package.sh'
  script="${SHELLSPEC_PROJECT_ROOT}/scripts/ci/release-package.sh"

  setup() {
    repo="$(mktemp -d "${SHELLSPEC_TMPBASE}/repo.XXXXXX")"
    cd "${repo}" || return
  }
  BeforeEach 'setup'

  pubspec() {
    mkdir -p "$2"
    printf 'name: %s\n%s' "$1" "${3-}" > "$2/pubspec.yaml"
  }

  It "releases a repo's only package under a bare tag"
    pubspec a .
    pub_lists a:.
    When run script "${script}" ''
    The output should equal $'.\ta\t'
  End

  It 'releases the package it names, under a tag that names it'
    pubspec w . $'publish_to: none\n'
    pubspec a packages/a
    pubspec b packages/b
    pub_lists w:. a:packages/a b:packages/b
    When run script "${script}" b
    The output should equal $'packages/b\tb\tb-'
  End

  It "releases a workspace's only published package under a bare tag"
    pubspec w . $'publish_to: none\n'
    pubspec a packages/a $'publish_to: none\n'
    pubspec b packages/b
    pub_lists w:. a:packages/a b:packages/b
    When run script "${script}" ''
    The output should equal $'packages/b\tb\t'
  End

  It 'fails without a name where several packages publish'
    pubspec w . $'publish_to: none\n'
    pubspec a packages/a
    pubspec b packages/b
    pub_lists w:. a:packages/a b:packages/b
    When run script "${script}" ''
    The status should be failure
    The output should equal ''
    The error should be present
  End

  It "fails on a package that doesn't publish"
    pubspec w . $'publish_to: none\n'
    pubspec a packages/a
    pubspec b packages/b
    pubspec c packages/c $'publish_to: none\n'
    pub_lists w:. a:packages/a b:packages/b c:packages/c
    When run script "${script}" c
    The status should be failure
    The output should equal ''
    The error should be present
  End

  It 'fails on a name no package here has'
    pubspec w . $'publish_to: none\n'
    pubspec a packages/a
    pubspec b packages/b
    pub_lists w:. a:packages/a b:packages/b
    When run script "${script}" d
    The status should be failure
    The output should equal ''
    The error should be present
  End

  It "fails with pub's own error when the packages can't be listed"
    pubspec a .
    pub_fails 'Error on line 1 of packages/b/pubspec.yaml'
    When run script "${script}" ''
    The status should be failure
    The output should equal ''
    The error should equal 'Error on line 1 of packages/b/pubspec.yaml'
  End
End
