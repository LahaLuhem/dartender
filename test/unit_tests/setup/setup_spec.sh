# shellcheck shell=bash
# shellcheck disable=SC2154  # ShellSpec sets the SHELLSPEC_* variables
Include test/utils/repo.sh
Include test/utils/gh.sh

# The two scripts it runs have specs of their own, so this covers what chaining them can break.
Describe 'setup/setup.sh'
  script="${SHELLSPEC_PROJECT_ROOT}/scripts/setup/setup.sh"
  manifest='{"image":"img","checks":[{"name":"a","cmd":"a"}]}'

  BeforeEach 'fresh_gh'

  sent_checks() {
    jq -r '.rules[] | select(.type == "required_status_checks")
      | .parameters.required_status_checks[].context' "${BODY}"
  }

  mtime() {
    stat -c %Y "${r}/.github/dependabot.yml"
  }

  writes() {
    grep -vE '^(api GET |repo view )' "${CALLS}" || :
  }

  It "writes the dependabot.yml of the repo it runs in, then sets up that repo's GitHub side"
    r="$(repo "${manifest}")"
    track "${r}" pubspec.yaml
    cd "${r}" || return
    When run script "${script}"
    The status should be success
    The output should be present
    The file "${r}/.github/dependabot.yml" should be exist
    The contents of file "${CALLS}" should include 'api POST repos/owner/repo/rulesets'
    The contents of file "${CALLS}" should include 'api PATCH repos/owner/repo'
  End

  It 'hands each --check on to the ruleset'
    r="$(repo "${manifest}")"
    track "${r}" pubspec.yaml
    cd "${r}" || return
    When run script "${script}" --check bench-ok
    The status should be success
    The output should be present
    The result of function sent_checks should include 'bench-ok'
  End

  It 'changes nothing on a repo that is already set up, and says so'
    r="$(repo "${manifest}")"
    track "${r}" pubspec.yaml
    "${SHELLSPEC_PROJECT_ROOT}/scripts/setup/dependabot.sh" "${r}" > /dev/null
    # Backdated, so a rewrite would show even within the same second.
    touch -t 200001010000 "${r}/.github/dependabot.yml"
    stamp="$(mtime)"
    already_set_up
    cd "${r}" || return
    When run script "${script}"
    The status should be success
    The output should include 'already'
    The result of function mtime should equal "${stamp}"
    The result of function writes should be blank
  End

  It "leaves GitHub alone when it can't write the dependabot.yml"
    # No lint manifest, which detect.sh stops on.
    r="$(repo)"
    cd "${r}" || return
    When run script "${script}"
    The status should be failure
    The output should be present
    The stderr should be present
    The contents of file "${CALLS}" should not include 'api '
  End

  It "changes nothing when it can't tell which GitHub repo it's in"
    r="$(repo "${manifest}")"
    track "${r}" pubspec.yaml
    export FAIL_ON='repo view'
    cd "${r}" || return
    When run script "${script}"
    The status should be failure
    The file "${r}/.github/dependabot.yml" should not be exist
    The contents of file "${CALLS}" should not include 'api '
  End

  Describe 'a command line it refuses before doing anything'
    Parameters
      '--help'
      '--check'
      'owner/repo'
    End

    It "refuses '$1'"
      r="$(repo "${manifest}")"
      track "${r}" pubspec.yaml
      cd "${r}" || return
      When run script "${script}" "$1"
      The status should be failure
      The error should be present
      The file "${r}/.github/dependabot.yml" should not be exist
      The contents of file "${CALLS}" should equal ''
    End
  End
End
