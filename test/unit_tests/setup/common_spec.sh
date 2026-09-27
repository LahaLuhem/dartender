# shellcheck shell=bash
Include scripts/setup/common.sh

Describe 'setup/common.sh'
  # So a script can hand its output to another and still show its errors.
  It 'sends errors to stderr and everything else to stdout'
    say_all() {
      info 'one'
      success 'two'
      error 'three'
    }
    When call say_all
    The output should include 'one'
    The output should include 'two'
    The output should not include 'three'
    The error should include 'three'
  End
End
