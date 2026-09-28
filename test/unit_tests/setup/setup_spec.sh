# shellcheck shell=bash
# shellcheck disable=SC2154  # ShellSpec sets the SHELLSPEC_* variables
Include test/utils/repo.sh
Include test/utils/gh.sh

# What runs inside the container has a spec of its own, inside_spec.sh, so this covers the handover.
Describe 'setup/setup.sh'
  script="${SHELLSPEC_PROJECT_ROOT}/scripts/setup/setup.sh"

  BeforeEach 'fresh_gh'

  run_call() {
    grep '^docker run ' "${CALLS}" || :
  }

  It 'builds its image, then runs the setup in it on the repo it was started in'
    r="$(repo)"
    cd "${r}" || return
    When run script "${script}"
    The status should be success
    The output should be present
    The line 1 of contents of file "${CALLS}" should start with 'docker build '
    The result of function run_call should include "--volume ${r}:/repo --workdir /repo"
    The result of function run_call should include "--volume ${SHELLSPEC_PROJECT_ROOT}:/dartender"
    The result of function run_call should include ' /dartender/scripts/setup/inside.sh'
  End

  It "hands the container the admin's GitHub token, keeping it off docker's command line"
    r="$(repo)"
    cd "${r}" || return
    When run script "${script}"
    The status should be success
    The output should be present
    The result of function run_call should include '--env GH_TOKEN '
    The result of function run_call should not include 'stand-in-token'
    The contents of file "${CALLS}" should include 'with GH_TOKEN=stand-in-token'
  End

  It 'hands its arguments on to the setup'
    r="$(repo)"
    cd "${r}" || return
    When run script "${script}" --check bench-ok
    The status should be success
    The output should be present
    The result of function run_call should end with 'inside.sh --check bench-ok'
  End

  It 'fails when the setup inside the container fails'
    r="$(repo)"
    export FAIL_ON='docker run'
    cd "${r}" || return
    When run script "${script}"
    The status should be failure
    The output should be present
  End

  Describe 'what stops it before the setup runs'
    Parameters
      "gh isn't logged in" 'auth token'
      "the image won't build" 'docker build'
    End

    It "stops when $1"
      r="$(repo)"
      export FAIL_ON="$2"
      cd "${r}" || return
      When run script "${script}"
      The status should be failure
      The output should be present
      The result of function run_call should be blank
    End
  End
End
