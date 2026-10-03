# shellcheck shell=bash
# shellcheck disable=SC2154  # ShellSpec sets the SHELLSPEC_* variables
Include test/utils/pub.sh

Describe 'ci/changelog-packages.sh'
  script="${SHELLSPEC_PROJECT_ROOT}/scripts/ci/changelog-packages.sh"

  setup() {
    repo="$(mktemp -d "${SHELLSPEC_TMPBASE}/repo.XXXXXX")"
    cd "${repo}" || return
  }
  BeforeEach 'setup'

  pubspec() {
    mkdir -p "$2"
    printf 'name: %s\n%s' "$1" "${3-}" > "$2/pubspec.yaml"
  }

  It "gives a one-package repo's line to its package, whatever the PR changed"
    pubspec a .
    pub_lists a:.
    Data
      #|test/a_test.dart
      #|.github/workflows/ci.yml
    End
    When run script "${script}"
    The output should equal '.'
  End

  It 'gives the line to each package the PR changed'
    pubspec w . $'publish_to: none\n'
    pubspec a packages/a
    pubspec b packages/b
    pubspec c packages/c
    pub_lists w:. a:packages/a b:packages/b c:packages/c
    Data
      #|packages/a/lib/a.dart
      #|packages/c/README.md
      #|packages/c/test/c_test.dart
    End
    When run script "${script}"
    The output should equal "$(printf '%s\n' packages/a packages/c)"
  End

  It "gives no line to a package that doesn't publish"
    pubspec w . $'publish_to: none\n'
    pubspec a packages/a
    pubspec b packages/b $'publish_to: none\n'
    pub_lists w:. a:packages/a b:packages/b
    Data
      #|packages/b/lib/b.dart
      #|.github/workflows/ci.yml
    End
    When run script "${script}"
    The output should equal ''
  End

  It "gives a member's change to the member, not to the root around it"
    pubspec w .
    pubspec a packages/a
    pub_lists w:. a:packages/a
    Data
      #|packages/a/lib/a.dart
    End
    When run script "${script}"
    The output should equal 'packages/a'
  End

  It "doesn't give a package the change of a folder whose name starts the same"
    pubspec w . $'publish_to: none\n'
    pubspec a packages/a
    pub_lists w:. a:packages/a
    Data
      #|packages/ab/notes.md
    End
    When run script "${script}"
    The output should equal ''
  End

  It "fails with pub's own error when the packages can't be listed"
    pubspec a .
    pub_fails 'Error on line 1 of packages/b/pubspec.yaml'
    Data
      #|lib/a.dart
    End
    When run script "${script}"
    The status should be failure
    The output should equal ''
    The error should equal 'Error on line 1 of packages/b/pubspec.yaml'
  End
End
