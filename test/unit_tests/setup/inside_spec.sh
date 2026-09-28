# shellcheck shell=bash
# shellcheck disable=SC2154  # ShellSpec sets the SHELLSPEC_* variables
Include test/utils/repo.sh
Include test/utils/gh.sh

# The scripts it runs have specs of their own, so this covers what chaining them can break.
Describe 'setup/inside.sh'
  script="${SHELLSPEC_PROJECT_ROOT}/scripts/setup/inside.sh"
  manifest='{"image":"img","checks":[{"name":"a","cmd":"a"}]}'

  BeforeEach 'fresh_gh'

  sent_checks() {
    jq -r '.rules[] | select(.type == "required_status_checks")
      | .parameters.required_status_checks[].context' "${BODY}"
  }

  mtime() {
    stat -c %Y "${r}/.github/dependabot.yml"
  }

  # The calls that change something on GitHub.
  writes() {
    grep -vE '^(api GET |repo view |gum |mason )' "${CALLS}" || :
  }

  make_call() {
    grep '^mason make ' "${CALLS}" || :
  }

  asked() {
    grep '^gum ' "${CALLS}" || :
  }

  blocks() {
    yq '[.updates[] | ."package-ecosystem" + " " + .directory] | .[]' \
      "${r}/.github/dependabot.yml"
  }

  default_of() {
    INPUT="$1" yq '.on.workflow_call.inputs[strenv(INPUT)].default' \
      "${SHELLSPEC_PROJECT_ROOT}/.github/workflows/ci.yml"
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
    track "${r}" .github/workflows/ci.yml
    export MASON_RC=0
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
    The result of function make_call should be blank
    The file "${r}/.github/dependabot.yml" should not be exist
    The contents of file "${CALLS}" should not include 'api '
  End

  Describe 'the callers'
    It "writes them first, with what the repo's ci caller passes now"
      r="$(repo "${manifest}")"
      track "${r}" pubspec.yaml
      caller="$(printf '%s\n' 'jobs:' '  ci:' '    with:' '      coveralls: false' \
        '      min-coverage: 90' '      coverage-excludes: lib/x.dart')"
      track "${r}" .github/workflows/ci.yml "${caller}"
      cd "${r}" || return
      When run script "${script}"
      The status should be success
      The output should be present
      The line 1 of result of function asked should include 'callers'
      The result of function make_call should end with \
        '--coveralls false --min_coverage 90 --coverage_excludes lib/x.dart'
    End

    It "falls back to ci.yml's own defaults for a repo without a ci caller"
      r="$(repo "${manifest}")"
      track "${r}" pubspec.yaml
      coveralls="$(default_of coveralls)"
      min_coverage="$(default_of min-coverage)"
      excludes="$(default_of coverage-excludes)"
      cd "${r}" || return
      When run script "${script}"
      The status should be success
      The output should be present
      The result of function make_call should end with \
        "--coveralls ${coveralls} --min_coverage ${min_coverage} --coverage_excludes ${excludes}"
    End

    It "has the same run's dependabot.yml watch the callers it wrote"
      r="$(repo "${manifest}")"
      track "${r}" pubspec.yaml
      cd "${r}" || return
      When run script "${script}"
      The status should be success
      The output should be present
      The result of function blocks should include 'github-actions /'
    End

    It 'leaves them alone when told no'
      r="$(repo "${manifest}")"
      track "${r}" pubspec.yaml
      export DECLINE_ON='callers'
      cd "${r}" || return
      When run script "${script}"
      The status should be success
      The output should be present
      The result of function make_call should be blank
      The file "${r}/.github/dependabot.yml" should be exist
    End
  End

  Describe 'asking before each part'
    It 'leaves the dependabot.yml alone when told no, and still sets up GitHub'
      r="$(repo "${manifest}")"
      track "${r}" pubspec.yaml
      export DECLINE_ON='dependabot.yml'
      cd "${r}" || return
      When run script "${script}"
      The status should be success
      The output should be present
      The file "${r}/.github/dependabot.yml" should not be exist
      The contents of file "${CALLS}" should include 'api POST repos/owner/repo/rulesets'
    End

    It 'leaves GitHub alone when told no, and still writes the dependabot.yml'
      r="$(repo "${manifest}")"
      track "${r}" pubspec.yaml
      export DECLINE_ON='GitHub'
      cd "${r}" || return
      When run script "${script}"
      The status should be success
      The output should be present
      The file "${r}/.github/dependabot.yml" should be exist
      The result of function writes should be blank
    End

    It 'stops at ctrl+c instead of taking it as a no'
      r="$(repo "${manifest}")"
      track "${r}" pubspec.yaml
      export ABORT_ON='dependabot.yml'
      cd "${r}" || return
      When run script "${script}"
      The status should equal 130
      The output should be present
      The file "${r}/.github/dependabot.yml" should not be exist
      The result of function writes should be blank
    End

    It 'asks nothing under -y, and does every part'
      r="$(repo "${manifest}")"
      track "${r}" pubspec.yaml
      cd "${r}" || return
      When run script "${script}" -y
      The status should be success
      The output should be present
      The contents of file "${CALLS}" should not include 'gum '
      The result of function make_call should be present
      The file "${r}/.github/dependabot.yml" should be exist
      The contents of file "${CALLS}" should include 'api POST repos/owner/repo/rulesets'
    End
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
