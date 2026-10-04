# shellcheck shell=bash
# shellcheck disable=SC2154  # ShellSpec sets the SHELLSPEC_* variables

Describe 'ci/lint-rules.sh'
  script="${SHELLSPEC_PROJECT_ROOT}/scripts/ci/lint-rules.sh"

  setup() {
    dir="$(mktemp -d "${SHELLSPEC_TMPBASE}/lints.XXXXXX")"
    options="${dir}/analysis_options.yaml"
    export ASKED="${dir}/asked" GH_FAILS='' DART_VERSION=3.13.5
    : > "${ASKED}"
    # The SDK's list: 2 stable lints, an experimental one, a deprecated one and a removed one.
    export RULES='[
      {"name": "avoid_print", "state": "stable"},
      {"name": "no_raw_types", "state": "stable"},
      {"name": "var_with_no_type_annotation", "state": "experimental"},
      {"name": "one_member_abstracts", "state": "deprecated"},
      {"name": "avoid_as", "state": "removed"}
    ]'
    decides avoid_print no_raw_types var_with_no_type_annotation
  }
  BeforeEach 'setup'

  # Writes the options file with each named lint turned on.
  decides() {
    printf 'linter:\n  rules:\n' > "${options}"
    for rule; do printf '    %s: true\n' "${rule}" >> "${options}"; done
  }

  Mock dart
    echo "Dart SDK version: ${DART_VERSION} (stable) (Tue Sep 29 01:00:52 2026 -0700) on \"linux_x64\""
  End

  Mock gh
    echo "$*" >> "${ASKED}"
    if [[ -n ${GH_FAILS} ]]; then
      echo "${GH_FAILS}" >&2
      exit 1
    fi
    printf '%s\n' "${RULES}"
  End

  It 'passes when the file decides every stable and experimental lint, the rest left out'
    When run script "${script}" "${options}"
    The status should be success
    The output should be present
  End

  It 'counts a lint turned off as decided'
    decides avoid_print var_with_no_type_annotation
    printf '    no_raw_types: false\n' >> "${options}"
    When run script "${script}" "${options}"
    The status should be success
    The output should be present
  End

  It "fails naming each lint the file doesn't decide"
    decides avoid_print
    When run script "${script}" "${options}"
    The status should be failure
    The error should include 'no_raw_types'
    The error should include 'var_with_no_type_annotation'
  End

  It "fails on a name Dart doesn't list, like an old spelling"
    decides avoid_print no_raw_types var_with_no_type_annotation prefer_iterable_whereType
    When run script "${script}" "${options}"
    The status should be failure
    The error should include 'prefer_iterable_whereType'
  End

  It 'asks for the lint list of the Dart that runs it'
    export DART_VERSION=3.14.0
    When run script "${script}" "${options}"
    The status should be success
    The output should be present
    The contents of file "${ASKED}" should include 'ref=3.14.0'
  End

  It "fails with gh's own error when it can't get the list"
    export GH_FAILS='HTTP 404: Not Found'
    When run script "${script}" "${options}"
    The status should be failure
    The error should include 'HTTP 404'
  End

  # With a file that decides nothing too, so nothing else can fail it.
  It 'fails on an empty list rather than passing on nothing'
    export RULES='[]'
    decides
    When run script "${script}" "${options}"
    The status should be failure
    The error should be present
  End

  It "fails on a list that isn't JSON rather than passing on nothing"
    export RULES='<!DOCTYPE html>'
    When run script "${script}" "${options}"
    The status should be failure
    The error should be present
  End

  It "fails before asking for a list when it can't tell which Dart runs it"
    export DART_VERSION=''
    When run script "${script}" "${options}"
    The status should be failure
    The error should be present
    The contents of file "${ASKED}" should equal ''
  End
End
