# shellcheck shell=bash
# shellcheck disable=SC2154  # ShellSpec sets the SHELLSPEC_* variables
Describe 'setup/apply.sh'
  apply="${SHELLSPEC_PROJECT_ROOT}/scripts/setup/apply.sh"
  example="${SHELLSPEC_PROJECT_ROOT}/scripts/setup/protected.example.json"
  labels="${SHELLSPEC_PROJECT_ROOT}/scripts/sem-labels.json"

  fresh_log() {
    dir="$(mktemp -d "${SHELLSPEC_TMPBASE}/apply.XXXXXX")"
    export CALLS="${dir}/calls" BODY="${dir}/body.json" RULESETS='[]' FAIL_ON=''
    : > "${CALLS}"
  }
  BeforeEach 'fresh_log'

  # Stands in for gh. It logs an api call as `api <method> <path>` whatever the flag order, keeps a
  # body sent on stdin, lists ${RULESETS}, and fails any call that matches ${FAIL_ON}.
  Mock gh
    method=GET path='' prev=''
    for arg; do
      if [[ ${prev} == --method ]]; then method="${arg}"; fi
      if [[ ${arg} == repos/* ]]; then path="${arg}"; fi
      prev="${arg}"
    done
    if [[ $1 == api ]]; then line="api ${method} ${path}"; else line="$*"; fi
    echo "${line}" >> "${CALLS}"
    if [[ -n ${FAIL_ON} && ${line} == *"${FAIL_ON}"* ]]; then exit 1; fi
    if [[ " $* " == *" --input - "* ]]; then cat > "${BODY}"; fi
    if [[ ${line} == 'api GET repos/owner/repo/rulesets' ]]; then printf '%s\n' "${RULESETS}"; fi
  End

  # Whether the JSON on stdin says the same as the file $1, whatever the formatting.
  same_json_as() {
    jq -S . > "${dir}/sent.json"
    jq -S . "$1" > "${dir}/want.json"
    cmp -s "${dir}/sent.json" "${dir}/want.json"
  }

  # Whether stdin holds exactly the given lines, in order. satisfy sends it without a final newline.
  lines_are() {
    local want actual
    printf -v want '%s\n' "$@"
    IFS= read -r -d '' actual || :
    [[ ${actual%$'\n'} == "${want%$'\n'}" ]]
  }

  sent_checks() {
    jq -r '.rules[] | select(.type == "required_status_checks")
      | .parameters.required_status_checks[].context' "${BODY}"
  }

  distinct_integration_ids() {
    jq '[.. | .integration_id? // empty] | unique | length' "${BODY}"
  }

  # Labels in sem-labels.json that no `gh label create <name> ... --force` call set up.
  unset_labels() {
    local names name
    grep -q '^label create ' "${CALLS}" || echo 'no label was set up at all'
    names="$(jq -r '.[].name' "${labels}")"
    while IFS= read -r name; do
      grep -q -- "^label create ${name} .*--force$" "${CALLS}" || echo "${name}"
    done <<< "${names}"
  }

  repo_edit_call() {
    grep '^repo edit owner/repo ' "${CALLS}"
  }

  It 'creates the example ruleset when the repo has none by its name'
    When run script "${apply}" owner/repo
    The status should be success
    The output should be present
    The contents of file "${CALLS}" should include 'api POST repos/owner/repo/rulesets'
    The contents of file "${CALLS}" should not include 'api PUT'
    The contents of file "${BODY}" should satisfy same_json_as "${example}"
  End

  It 'updates the ruleset in place when the repo already has one by that name'
    export RULESETS='[{"id": 42, "name": "Protected"}]'
    When run script "${apply}" owner/repo
    The status should be success
    The output should be present
    The contents of file "${CALLS}" should include 'api PUT repos/owner/repo/rulesets/42'
    The contents of file "${CALLS}" should not include 'api POST'
  End

  It 'leaves a ruleset with another name alone'
    export RULESETS='[{"id": 7, "name": "Releases"}]'
    When run script "${apply}" owner/repo
    The status should be success
    The output should be present
    The contents of file "${CALLS}" should include 'api POST repos/owner/repo/rulesets'
    The contents of file "${CALLS}" should not include 'rulesets/7'
  End

  It 'requires each --check on GitHub Actions, after the shared checks'
    When run script "${apply}" owner/repo --check bench-ok --check 'bench (app) / ok'
    The status should be success
    The output should be present
    The result of function sent_checks should satisfy \
      lines_are 'ci / ok' 'conventions / ok' 'bench-ok' 'bench (app) / ok'
    The result of function distinct_integration_ids should equal 1
  End

  It 'sets up every label in sem-labels.json, updating the ones that exist'
    When run script "${apply}" owner/repo
    The status should be success
    The output should be present
    The result of function unset_labels should be blank
  End

  It 'turns on auto-merge and rebase-only merging, and deletes merged branches'
    When run script "${apply}" owner/repo
    The status should be success
    The output should be present
    The result of function repo_edit_call should include '--enable-auto-merge'
    The result of function repo_edit_call should include '--enable-rebase-merge'
    The result of function repo_edit_call should include '--enable-squash-merge=false'
    The result of function repo_edit_call should include '--enable-merge-commit=false'
    The result of function repo_edit_call should include '--delete-branch-on-merge'
  End

  It 'stops at the first gh call that fails'
    export FAIL_ON='api GET'
    When run script "${apply}" owner/repo
    The status should be failure
    The contents of file "${CALLS}" should include 'api GET'
    The contents of file "${CALLS}" should not include 'label create'
    The contents of file "${CALLS}" should not include 'repo edit'
  End

  It 'refuses to run without a repo, before calling gh'
    When run script "${apply}"
    The status should be failure
    The error should be present
    The contents of file "${CALLS}" should equal ''
  End

  Describe 'a command line it refuses before calling gh'
    Parameters
      '--help'
      '--check bench-ok'
      'owner/repo --bogus'
      'owner/repo --check'
    End

    It "refuses '$1'"
      # shellcheck disable=SC2086  # split on purpose, into the arguments the row stands for
      When run script "${apply}" $1
      The status should be failure
      The error should be present
      The contents of file "${CALLS}" should equal ''
    End
  End
End
