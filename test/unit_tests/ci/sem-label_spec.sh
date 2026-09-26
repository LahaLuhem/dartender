# shellcheck shell=bash
# shellcheck disable=SC2154  # ShellSpec sets the SHELLSPEC_* variables
Describe 'ci/sem-label.sh'
  check="${SHELLSPEC_PROJECT_ROOT}/scripts/ci/sem-label.sh"
  export REPO=owner/repo PR=7

  # Stands in for the API, answering only the call for this PR's labels.
  Mock gh
    if [[ "$*" != "api repos/${REPO}/pulls/${PR} --jq .labels[].name" ]]; then
      echo "unexpected call: gh $*" >&2
      exit 9
    fi
    printf '%s\n' "${LABELS}"
  End

  Describe 'a PR with one sem-* label it knows'
    Parameters
      sem-add
      sem-change
      sem-deprecate
      sem-remove
      sem-bugfix
      sem-security
      sem-skip
    End

    It "passes $1"
      export LABELS=$'bug\n'"$1"
      When run script "${check}"
      The status should be success
    End
  End

  It 'fails a PR without a sem-* label'
    export LABELS='bug'
    When run script "${check}"
    The status should be failure
    The output should include 'it has 0'
  End

  It 'fails a PR with no labels at all'
    export LABELS=''
    When run script "${check}"
    The status should be failure
    The output should include 'it has 0'
  End

  It 'fails a PR with two'
    export LABELS=$'sem-add\nsem-bugfix'
    When run script "${check}"
    The status should be failure
    The output should include 'it has 2'
  End

  It "fails a sem-* label the repos don't use"
    export LABELS='sem-feature'
    When run script "${check}"
    The status should be failure
    The output should include "sem-feature isn't"
  End

  It "fails when the API can't be reached"
    Mock gh
      (exit 4)
    End
    When run script "${check}"
    The status should be failure
  End
End
