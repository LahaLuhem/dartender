# shellcheck shell=bash
# shellcheck disable=SC2154  # ShellSpec sets the SHELLSPEC_* variables

Describe 'ci/lint-rules.sh'
  script="${SHELLSPEC_PROJECT_ROOT}/scripts/ci/lint-rules.sh"

  setup() {
    dir="$(mktemp -d "${SHELLSPEC_TMPBASE}/lints.XXXXXX")"
    options="${dir}/analysis_options.yaml"
    export ASKED="${dir}/asked" GH_FAILS='' GH_FAILS_ON='' DART_VERSION=3.13.5
    : > "${ASKED}"
    # The SDK's list: 2 stable lints, an experimental one, a deprecated one and a removed one.
    export RULES='[
      {"name": "avoid_print", "state": "stable"},
      {"name": "no_raw_types", "state": "stable"},
      {"name": "var_with_no_type_annotation", "state": "experimental"},
      {"name": "one_member_abstracts", "state": "deprecated"},
      {"name": "avoid_as", "state": "removed"}
    ]'
    # The same lints in messages.yaml, keyed in camelCase with every state each went through. As
    # JSON, which yq reads too.
    export MESSAGES='{"LinterLintCode": {
      "avoidPrint": {"state": {"stable": "2.0"}},
      "noRawTypes": {"state": {"stable": "3.13"}},
      "varWithNoTypeAnnotation": {"state": {"experimental": "3.13"}},
      "oneMemberAbstracts": {"state": {"stable": "2.0", "deprecated": "3.13"}},
      "avoidAs": {"state": {"stable": "2.0", "removed": "3.0"}}
    }}'
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
    if [[ -n ${GH_FAILS} && "$*" == *"${GH_FAILS_ON}"* ]]; then
      echo "${GH_FAILS}" >&2
      exit 1
    fi
    if [[ "$*" == *messages.yaml* ]]; then
      printf '%s\n' "${MESSAGES}"
    else
      printf '%s\n' "${RULES}"
    fi
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

  It 'fails naming each deprecated or removed lint the file mentions, turned off too'
    printf '    one_member_abstracts: false\n    avoid_as: true\n' >> "${options}"
    When run script "${script}" "${options}"
    The status should be failure
    The error should include 'one_member_abstracts'
    The error should include 'avoid_as'
  End

  # Like unnecessary_await_in_return at 3.13.5.
  It "doesn't ask for a decision on a lint the analyzer has deprecated, though rules.json lists it stable"
    export RULES='[{"name": "avoid_print", "state": "stable"},
      {"name": "unnecessary_await_in_return", "state": "stable"}]'
    export MESSAGES='{"LinterLintCode": {"avoidPrint": {"state": {"stable": "2.0"}},
      "unnecessaryAwaitInReturn": {"state": {"stable": "2.1", "deprecated": "3.13"}}}}'
    decides avoid_print
    When run script "${script}" "${options}"
    The status should be success
    The output should be present
  End

  It 'finds a lint messages.yaml keys with digits or under a shared name'
    export RULES='[{"name": "lines_longer_than_80_chars", "state": "stable"},
      {"name": "always_declare_return_types", "state": "stable"}]'
    export MESSAGES='{"LinterLintCode": {
      "linesLongerThan80Chars": {"state": {"stable": "2.0", "deprecated": "3.13"}},
      "alwaysDeclareReturnTypesOfFunctions": {"sharedName": "alwaysDeclareReturnTypes",
        "state": {"stable": "2.0", "removed": "3.13"}},
      "alwaysDeclareReturnTypesOfMethods": {"sharedName": "alwaysDeclareReturnTypes"}}}'
    decides lines_longer_than_80_chars always_declare_return_types
    When run script "${script}" "${options}"
    The status should be failure
    The error should include 'lines_longer_than_80_chars'
    The error should include 'always_declare_return_types'
  End

  It 'asks for both lists of the Dart that runs it'
    export DART_VERSION=3.14.0
    When run script "${script}" "${options}"
    The status should be success
    The output should be present
    The contents of file "${ASKED}" should include 'rules.json?ref=3.14.0'
    The contents of file "${ASKED}" should include 'messages.yaml?ref=3.14.0'
  End

  It "fails with gh's own error when it can't get the list"
    export GH_FAILS='HTTP 404: Not Found'
    When run script "${script}" "${options}"
    The status should be failure
    The error should include 'HTTP 404'
  End

  # With a list and a file that agree, so nothing else can fail it.
  It "fails with gh's own error when it can't get messages.yaml"
    export GH_FAILS='HTTP 404: Not Found' GH_FAILS_ON=messages.yaml
    export RULES='[{"name": "avoid_print", "state": "stable"}]'
    decides avoid_print
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

  # With lists and a file that agree, so nothing else can fail it.
  It 'fails when messages.yaml has nothing deprecated or removed, rather than letting all through'
    export RULES='[{"name": "avoid_print", "state": "stable"}]'
    export MESSAGES='{"LinterLintCode": {"avoidPrint": {"state": {"stable": "2.0"}}}}'
    decides avoid_print
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
