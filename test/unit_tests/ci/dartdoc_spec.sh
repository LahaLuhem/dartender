# shellcheck shell=bash
# shellcheck disable=SC2154  # ShellSpec sets the SHELLSPEC_* variables
Describe 'ci/dartdoc.sh'
  script="${SHELLSPEC_PROJECT_ROOT}/scripts/ci/dartdoc.sh"

  setup() {
    repo="$(mktemp -d "${SHELLSPEC_TMPBASE}/repo.XXXXXX")"
    cd "${repo}" || return
    # Not pub_lists, which would put its dart ahead of the mock below that hands it the listing.
    export ROOT="${repo}" DOCUMENTED="${repo}.documented" OUTCOMES='' LISTED='' PUB_FAILS='' \
      LISTER="${SHELLSPEC_PROJECT_ROOT}/test/utils/pub/dart"
    : > "${DOCUMENTED}"
  }
  BeforeEach 'setup'

  pubspec() {
    mkdir -p "$2"
    printf 'name: %s\n%s' "$1" "${3-}" > "$2/pubspec.yaml"
  }

  # Its root doesn't publish, and nor does gamma.
  workspace() {
    pubspec w . $'publish_to: none\n'
    pubspec alpha packages/alpha
    pubspec beta packages/beta
    pubspec gamma packages/gamma $'publish_to: none\n'
    export LISTED='w:. alpha:packages/alpha beta:packages/beta gamma:packages/gamma'
  }

  # Like dart doc without a terminal, it names no package, and exits 0 on a warning.
  Mock dart
    if [[ $* != 'doc --dry-run' ]]; then exec "${LISTER}" "$@"; fi
    dir="${PWD#"${ROOT}"}" dir="${dir#/}" dir="${dir:-.}"
    echo "${dir}" >> "${DOCUMENTED}"
    case " ${OUTCOMES} " in
      *" ${dir}=warning "*)
        echo '  warning: unresolved doc reference [Nope]'
        echo 'Found 1 warning and 0 errors.'
        ;;
      *" ${dir}=error "*)
        echo '  error: unresolved doc reference [Nope]'
        echo 'Found 0 warnings and 1 error.'
        exit 1
        ;;
      *" ${dir}=reworded "*) echo 'Documented 1 library, all clean.' ;;
      *) echo 'Found 0 warnings and 0 errors.' ;;
    esac
  End

  It 'documents a single package from the root'
    pubspec alpha .
    export LISTED=alpha:.
    When run script "${script}"
    The status should be success
    The output should include 'Found 0 warnings and 0 errors.'
    The contents of file "${DOCUMENTED}" should equal .
  End

  It 'documents each package a workspace publishes, and no other'
    workspace
    When run script "${script}"
    The status should be success
    The output should be present
    The contents of file "${DOCUMENTED}" should equal "$(printf '%s\n' packages/alpha packages/beta)"
  End

  It "names each package above its result, since dart doc's own output doesn't"
    workspace
    When run script "${script}"
    The status should be success
    The output should include 'alpha'
    The output should include 'beta'
  End

  It 'fails on a warning, which it shows, after documenting the other packages too'
    workspace
    export OUTCOMES='packages/alpha=warning'
    When run script "${script}"
    The status should be failure
    The output should include 'unresolved doc reference [Nope]'
    The error should include 'alpha'
    The contents of file "${DOCUMENTED}" should equal "$(printf '%s\n' packages/alpha packages/beta)"
  End

  It 'fails when dart doc ends in an error'
    workspace
    export OUTCOMES='packages/beta=error'
    When run script "${script}"
    The status should be failure
    The output should be present
    The error should include 'beta'
  End

  It "fails on a summary it can't read, so a rewording in dart doc can't pass everything"
    workspace
    export OUTCOMES='packages/alpha=reworded'
    When run script "${script}"
    The status should be failure
    The output should be present
    The error should include 'alpha'
  End

  It "fails with pub's own error when the packages can't be listed"
    pubspec alpha .
    export PUB_FAILS='Error on line 1 of packages/b/pubspec.yaml'
    When run script "${script}"
    The status should be failure
    The output should equal ''
    The error should equal 'Error on line 1 of packages/b/pubspec.yaml'
    The contents of file "${DOCUMENTED}" should equal ''
  End
End
