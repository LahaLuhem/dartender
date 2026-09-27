# shellcheck shell=bash
# shellcheck disable=SC2154  # ShellSpec sets the SHELLSPEC_* variables
Describe 'setup/apply.sh'
  apply="${SHELLSPEC_PROJECT_ROOT}/scripts/setup/apply.sh"
  example="${SHELLSPEC_PROJECT_ROOT}/scripts/setup/protected.example.json"
  labels="${SHELLSPEC_PROJECT_ROOT}/scripts/sem-labels.json"

  fresh_log() {
    dir="$(mktemp -d "${SHELLSPEC_TMPBASE}/apply.XXXXXX")"
    export CALLS="${dir}/calls" BODY="${dir}/body.json" SETTINGS_BODY="${dir}/settings.json" \
      RULESETS='[]' RULESET='{}' LABELS='[]' SETTINGS='{}' FAIL_ON=''
    : > "${CALLS}"
  }
  BeforeEach 'fresh_log'

  # Stands in for gh. Logs `api <method> <path>` whatever the flag order, keeps sent bodies,
  # answers reads from the variables above, and fails a call matching ${FAIL_ON}.
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
    if [[ " $* " == *" --input - "* ]]; then
      if [[ ${path} == */rulesets* ]]; then cat > "${BODY}"; else cat > "${SETTINGS_BODY}"; fi
    else
      # Like a gh that reads stdin anyway, which would eat the rest of a loop's input.
      cat > /dev/null
    fi
    case "${line}" in
      'api GET repos/owner/repo/rulesets') printf '%s\n' "${RULESETS}" ;;
      'api GET repos/owner/repo/rulesets/'*) printf '%s\n' "${RULESET}" ;;
      'api GET repos/owner/repo/labels') printf '%s\n' "${LABELS}" ;;
      'api GET repos/owner/repo') printf '%s\n' "${SETTINGS}" ;;
      *) ;;
    esac
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

  set_labels() {
    local set
    set="$(awk '/^label create / { print $3 }' "${CALLS}")"
    sort <<< "${set}"
  }

  sent_settings() {
    jq -r 'to_entries | sort_by(.key)[] | "\(.key)=\(.value)"' "${SETTINGS_BODY}"
  }

  writes() {
    grep -v '^api GET ' "${CALLS}" || :
  }

  It 'creates the example ruleset when the repo has none by its name'
    When run script "${apply}" owner/repo
    The status should be success
    The output should be present
    The contents of file "${CALLS}" should include 'api POST repos/owner/repo/rulesets'
    The contents of file "${CALLS}" should not include 'api PUT'
    The contents of file "${BODY}" should satisfy same_json_as "${example}"
  End

  It 'updates the ruleset in place when the one by that name differs'
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

  It 'creates every label in sem-labels.json that the repo lacks'
    When run script "${apply}" owner/repo
    The status should be success
    The output should be present
    The result of function unset_labels should be blank
  End

  It 'rewrites only the labels that are missing or differ'
    # sem-add in another colour, and no sem-skip at all.
    LABELS="$(jq -c 'map(select(.name != "sem-skip")
      | if .name == "sem-add" then .color = "000000" else . end | . + {id: 1})' "${labels}")"
    export LABELS
    expected="$(printf '%s\n' sem-add sem-skip)"
    When run script "${apply}" owner/repo
    The status should be success
    The output should be present
    The result of function set_labels should equal "${expected}"
  End

  It 'turns on auto-merge and rebase-only merging, and deletes merged branches'
    expected="$(printf '%s\n' allow_auto_merge=true allow_merge_commit=false \
      allow_rebase_merge=true allow_squash_merge=false delete_branch_on_merge=true)"
    When run script "${apply}" owner/repo
    The status should be success
    The output should be present
    The result of function sent_settings should equal "${expected}"
  End

  It 'changes nothing that is already set, and says so'
    export RULESETS='[{"id": 42, "name": "Protected"}]'
    # Plus the fields GitHub adds.
    RULESET="$(jq -c '. + {id: 42, node_id: "RRS_1", source: "owner/repo", _links: {}}' \
      "${example}")"
    LABELS="$(jq -c 'map(. + {id: 1, default: false})' "${labels}")"
    export RULESET LABELS SETTINGS='{"id": 1, "allow_auto_merge": true, "allow_rebase_merge": true,
      "allow_squash_merge": false, "allow_merge_commit": false, "delete_branch_on_merge": true}'
    When run script "${apply}" owner/repo
    The status should be success
    The output should include 'already'
    The result of function writes should be blank
  End

  Describe "when the API won't take the ruleset"
    Parameters
      'api GET repos/owner/repo/rulesets' '[]'
      'api GET repos/owner/repo/rulesets/42' '[{"id": 42, "name": "Protected"}]'
      'api POST' '[]'
      'api PUT' '[{"id": 42, "name": "Protected"}]'
    End

    It "says how to set it by hand and stops, when '$1' fails"
      export FAIL_ON="$1" RULESETS="$2"
      When run script "${apply}" owner/repo
      The status should be failure
      The error should include "${example}"
      The contents of file "${CALLS}" should include "$1"
      The contents of file "${CALLS}" should not include 'label create'
      The contents of file "${CALLS}" should not include 'api PATCH'
    End
  End

  It 'stops at any other gh call that fails, without the reminder'
    export FAIL_ON='label create'
    When run script "${apply}" owner/repo
    The status should be failure
    The output should be present
    The error should be blank
    The contents of file "${CALLS}" should include 'label create'
    The contents of file "${CALLS}" should not include 'api PATCH'
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
