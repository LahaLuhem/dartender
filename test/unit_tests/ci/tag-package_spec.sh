# shellcheck shell=bash
# shellcheck disable=SC2154  # ShellSpec sets the SHELLSPEC_* variables
Include test/utils/pub.sh

Describe 'ci/tag-package.sh'
  script="${SHELLSPEC_PROJECT_ROOT}/scripts/ci/tag-package.sh"

  setup() {
    repo="$(mktemp -d "${SHELLSPEC_TMPBASE}/repo.XXXXXX")"
    cd "${repo}" || return
  }
  BeforeEach 'setup'

  pubspec() {
    mkdir -p "$2"
    printf 'name: %s\n%s' "$1" "${3-}" > "$2/pubspec.yaml"
  }

  It "publishes a repo's only package from a bare version"
    pubspec a .
    pub_lists a:.
    export TAG=1.2.0
    When run script "${script}"
    The output should equal 'folder=.'
  End

  It 'publishes the package a tag names'
    pubspec w . $'publish_to: none\n'
    pubspec a packages/a
    pubspec b packages/b
    pub_lists w:. a:packages/a b:packages/b
    export TAG=b-1.2.0
    When run script "${script}"
    The output should equal 'folder=packages/b'
  End

  It "publishes a workspace's only published package from a bare version"
    pubspec w . $'publish_to: none\n'
    pubspec a packages/a $'publish_to: none\n'
    pubspec b packages/b
    pub_lists w:. a:packages/a b:packages/b
    export TAG=1.2.0
    When run script "${script}"
    The output should equal 'folder=packages/b'
  End

  It 'fails on a bare version where several packages publish'
    pubspec w . $'publish_to: none\n'
    pubspec a packages/a
    pubspec b packages/b
    pub_lists w:. a:packages/a b:packages/b
    export TAG=1.2.0
    When run script "${script}"
    The status should be failure
    The output should equal ''
    The error should be present
  End

  It 'fails on a tag that names the package where only one publishes'
    pubspec a .
    pub_lists a:.
    export TAG=a-1.2.0
    When run script "${script}"
    The status should be failure
    The output should equal ''
    The error should be present
  End

  It "fails on a tag that names a package that doesn't publish"
    pubspec w . $'publish_to: none\n'
    pubspec a packages/a
    pubspec b packages/b
    pubspec c packages/c $'publish_to: none\n'
    pub_lists w:. a:packages/a b:packages/b c:packages/c
    export TAG=c-1.2.0
    When run script "${script}"
    The status should be failure
    The output should equal ''
    The error should be present
  End

  It 'fails on a tag that names no package here'
    pubspec w . $'publish_to: none\n'
    pubspec a packages/a
    pubspec b packages/b
    pub_lists w:. a:packages/a b:packages/b
    export TAG=d-1.2.0
    When run script "${script}"
    The status should be failure
    The output should equal ''
    The error should be present
  End

  It "fails with pub's own error when the packages can't be listed"
    pubspec a .
    pub_fails 'Error on line 1 of packages/b/pubspec.yaml'
    export TAG=1.2.0
    When run script "${script}"
    The status should be failure
    The output should equal ''
    The error should equal 'Error on line 1 of packages/b/pubspec.yaml'
  End
End
