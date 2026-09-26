# shellcheck shell=bash
# shellcheck disable=SC2154  # ShellSpec sets the SHELLSPEC_* variables
Describe 'ci/branch-name.sh'
  check="${SHELLSPEC_PROJECT_ROOT}/scripts/ci/branch-name.sh"

  Describe 'a branch that follows the pattern'
    Parameters
      'feature/#12-dark-mode'
      'bugfix/#3-null-check'
      'chore/#4-tidy-readme'
      'refactor/#7-split-parser'
    End

    It "passes $1"
      export BRANCH="$1"
      When run script "${check}"
      The status should be success
    End
  End

  Describe "a branch that doesn't"
    Parameters
      'hotfix/#5-crash'
      'acceptance-test-issues/#6-login'
      'Feature/#12-dark-mode'
      'feature/12-dark-mode'
      'feature/#dark-mode'
      'feature/#12'
      'feature/#12-'
      'dark-mode'
    End

    It "fails $1"
      export BRANCH="$1"
      When run script "${check}"
      The status should be failure
      The output should include "Branch '$1'"
    End
  End
End
