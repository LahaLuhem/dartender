# shellcheck shell=bash
# shellcheck disable=SC2154  # ShellSpec sets the SHELLSPEC_* variables
Include test/utils/pub.sh

Describe 'ci/packages.sh'
  script="${SHELLSPEC_PROJECT_ROOT}/scripts/ci/packages.sh"

  setup() {
    repo="$(mktemp -d "${SHELLSPEC_TMPBASE}/repo.XXXXXX")"
  }
  BeforeEach 'setup'

  pubspec() {
    mkdir -p "${repo}/$2"
    printf 'name: %s\n%s' "$1" "${3-}" > "${repo}/$2/pubspec.yaml"
  }

  It 'lists a single package as the root, publishing'
    pubspec a .
    pub_lists a:.
    When run script "${script}" "${repo}"
    The output should equal "$(printf 'a\t.\ttrue')"
  End

  It "lists a workspace's root first, then each member by its folder, and whether each publishes"
    pubspec w . $'publish_to: none\n'
    pubspec a packages/a
    pubspec b packages/b $'publish_to: none\n'
    pub_lists w:. a:packages/a b:packages/b
    expected="$(printf '%s\t%s\t%s\n' w . false a packages/a true b packages/b false)"
    When run script "${script}" "${repo}"
    The output should equal "${expected}"
  End

  It 'lists the folders from the root when the root is reached through a symlink'
    pubspec a .
    ln -s "${repo}" "${repo}.link"
    pub_lists a:.
    When run script "${script}" "${repo}.link"
    The output should equal "$(printf 'a\t.\ttrue')"
  End

  It "fails when pub can't list the packages"
    pubspec a .
    pub_fails 'Error on line 1 of packages/b/pubspec.yaml'
    When run script "${script}" "${repo}"
    The status should be failure
    The output should equal ''
    The error should equal 'Error on line 1 of packages/b/pubspec.yaml'
  End
End
