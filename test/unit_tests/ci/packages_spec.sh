# shellcheck shell=bash
# shellcheck disable=SC2154  # ShellSpec sets the SHELLSPEC_* variables
Describe 'ci/packages.sh'
  script="${SHELLSPEC_PROJECT_ROOT}/scripts/ci/packages.sh"

  setup() {
    repo="$(mktemp -d "${SHELLSPEC_TMPBASE}/repo.XXXXXX")"
  }
  BeforeEach 'setup'

  # A pubspec for the package $1 in the folder $2, with the lines $3 after its name.
  pubspec() {
    mkdir -p "${repo}/$2"
    printf 'name: %s\n%s' "$1" "${3-}" > "${repo}/$2/pubspec.yaml"
  }

  # Lists $LISTED's `<name>:<folder>` pairs the way pub does, by resolved path.
  Mock dart
    root="$(pwd -P)"
    jq -n --arg root "${root}" --arg listed "${LISTED}" '{packages: [$listed | split(" ")[]
      | split(":") | {name: .[0], path: (if .[1] == "." then $root else "\($root)/\(.[1])" end)}]}'
  End

  It 'lists a single package as the root, publishing'
    pubspec a .
    export LISTED='a:.'
    When run script "${script}" "${repo}"
    The output should equal "$(printf 'a\t.\ttrue')"
  End

  It "lists a workspace's root first, then each member by its folder, and whether each publishes"
    pubspec w . $'publish_to: none\n'
    pubspec a packages/a
    pubspec b packages/b $'publish_to: none\n'
    export LISTED='w:. a:packages/a b:packages/b'
    expected="$(printf '%s\t%s\t%s\n' w . false a packages/a true b packages/b false)"
    When run script "${script}" "${repo}"
    The output should equal "${expected}"
  End

  It 'lists the folders from the root when the root is reached through a symlink'
    pubspec a .
    ln -s "${repo}" "${repo}.link"
    export LISTED='a:.'
    When run script "${script}" "${repo}.link"
    The output should equal "$(printf 'a\t.\ttrue')"
  End

  It "fails when pub can't list the packages, instead of listing none"
    Mock dart
      echo 'Could not find a file named "pubspec.yaml"' >&2
      (exit 66)
    End
    When run script "${script}" "${repo}"
    The status should be failure
    The output should equal ''
    The error should include 'pubspec.yaml'
  End
End
