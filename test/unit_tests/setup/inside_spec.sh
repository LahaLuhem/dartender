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

  # Gives owner/repo a Protected ruleset that requires exactly the checks named.
  # shellcheck disable=SC2016  # jq programs, whose $ARGS and $checks are jq variables
  ruleset_with() {
    local checks
    checks="$(jq -c -n '[$ARGS.positional[] | {context: ., integration_id: 15368}]' --args "$@")"
    RULESET="$(jq -c --argjson checks "${checks}" '(.rules[]
      | select(.type == "required_status_checks") | .parameters.required_status_checks) = $checks
      | . + {id: 42}' "${SHELLSPEC_PROJECT_ROOT}/scripts/setup/protected.example.json")"
    export RULESET RULESETS='[{"id": 42, "name": "Protected"}]'
  }

  # How many of the checks sent for the ruleset have a blank name.
  blank_checks() {
    jq '[.rules[] | select(.type == "required_status_checks")
      | .parameters.required_status_checks[].context | select(test("^\\s*$"))] | length' "${BODY}"
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

  Describe "the ci caller's inputs"
    # Gives the repo in r a ci caller whose inputs all differ from ci.yml's defaults.
    with_caller() {
      local caller
      caller="$(printf '%s\n' 'jobs:' '  ci:' '    with:' '      coveralls: false' \
        '      min-coverage: 90' '      coverage-excludes: lib/x.dart')"
      track "${r}" .github/workflows/ci.yml "${caller}"
    }

    It "starts each question from what the repo's ci caller passes now"
      r="$(repo "${manifest}")"
      track "${r}" pubspec.yaml
      with_caller
      cd "${r}" || return
      When run script "${script}"
      The status should be success
      The output should be present
      The result of function asked should include '--default=false Upload coverage to Coveralls?'
      The result of function asked should include '--value 90'
      The result of function asked should include '--value lib/x.dart'
    End

    Describe 'what gets typed'
      Parameters
        'the lowest coverage' 'coverage that passes' 80 '--min_coverage 80 '
        'the excludes' 'space-separated' 'lib/y.dart' '--coverage_excludes lib/y.dart'
      End

      It "takes what gets typed for $1 over what the repo has now"
        r="$(repo "${manifest}")"
        track "${r}" pubspec.yaml
        with_caller
        export TYPE_ON="$2" TYPED="$3"
        cd "${r}" || return
        When run script "${script}"
        The status should be success
        The output should be present
        The result of function make_call should include "$4"
      End
    End

    It 'takes a no to Coveralls when the repo has it on'
      r="$(repo "${manifest}")"
      track "${r}" pubspec.yaml
      export DECLINE_ON='Coveralls'
      cd "${r}" || return
      When run script "${script}"
      The status should be success
      The output should be present
      The result of function make_call should include '--coveralls false '
    End

    It 'takes a yes to Coveralls when the repo has it off'
      r="$(repo "${manifest}")"
      track "${r}" pubspec.yaml
      with_caller
      export ACCEPT_ON='Coveralls'
      cd "${r}" || return
      When run script "${script}"
      The status should be success
      The output should be present
      The result of function make_call should include '--coveralls true '
    End

    It "stops before writing anything at a lowest coverage that isn't a number"
      r="$(repo "${manifest}")"
      track "${r}" pubspec.yaml
      export TYPE_ON='coverage that passes' TYPED='ninety'
      cd "${r}" || return
      When run script "${script}"
      The status should be failure
      The output should be present
      The error should include 'Invalid input'
      The result of function make_call should be blank
      The file "${r}/.github/dependabot.yml" should not be exist
    End

    It 'stops at ctrl+c in an input, instead of taking what was there'
      r="$(repo "${manifest}")"
      track "${r}" pubspec.yaml
      export ABORT_ON='coverage that passes'
      cd "${r}" || return
      When run script "${script}"
      The status should equal 130
      The output should be present
      The result of function make_call should be blank
    End

    It "asks nothing under -y, keeping what the repo's ci caller passes now"
      r="$(repo "${manifest}")"
      track "${r}" pubspec.yaml
      with_caller
      cd "${r}" || return
      When run script "${script}" -y
      The status should be success
      The output should be present
      The contents of file "${CALLS}" should not include 'gum '
      The result of function make_call should end with \
        '--coveralls false --min_coverage 90 --coverage_excludes lib/x.dart'
    End
  End

  Describe "the repo's own checks"
    It 'starts from the ones its ruleset requires besides the shared ones, and keeps them'
      r="$(repo "${manifest}")"
      track "${r}" pubspec.yaml
      already_set_up
      ruleset_with 'ci / ok' 'conventions / ok' bench-ok
      cd "${r}" || return
      When run script "${script}"
      The status should be success
      The output should be present
      The result of function asked should include '--value bench-ok'
      The contents of file "${CALLS}" should not include 'api PUT'
    End

    It "starts from none on a ruleset that doesn't require the shared checks yet"
      r="$(repo "${manifest}")"
      track "${r}" pubspec.yaml
      # Like a repo's ruleset from before dartender.
      ruleset_with repo-ok package-ok
      cd "${r}" || return
      When run script "${script}"
      The status should be success
      The output should be present
      The result of function sent_checks should not include 'repo-ok'
    End

    It 'requires each check typed, one per line'
      r="$(repo "${manifest}")"
      track "${r}" pubspec.yaml
      export TYPE_ON='own checks' TYPED=$'bench-ok\nBrowser tests (dart2js + dart2wasm)'
      cd "${r}" || return
      When run script "${script}"
      The status should be success
      The output should be present
      The result of function sent_checks should include 'bench-ok'
      The result of function sent_checks should include 'Browser tests (dart2js + dart2wasm)'
    End

    It 'leaves blank lines out'
      r="$(repo "${manifest}")"
      track "${r}" pubspec.yaml
      export TYPE_ON='own checks' TYPED=$'bench-ok\n\n  \n'
      cd "${r}" || return
      When run script "${script}"
      The status should be success
      The output should be present
      The result of function sent_checks should include 'bench-ok'
      The result of function blank_checks should equal 0
    End

    It 'asks nothing under -y, keeping the ones the ruleset requires'
      r="$(repo "${manifest}")"
      track "${r}" pubspec.yaml
      already_set_up
      ruleset_with 'ci / ok' 'conventions / ok' bench-ok
      cd "${r}" || return
      When run script "${script}" -y
      The status should be success
      The output should be present
      The contents of file "${CALLS}" should not include 'gum '
      The contents of file "${CALLS}" should not include 'api PUT'
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
