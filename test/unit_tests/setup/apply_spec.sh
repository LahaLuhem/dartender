# shellcheck shell=bash
# shellcheck disable=SC2154  # ShellSpec sets the SHELLSPEC_* variables
Include test/utils/gh.sh

Describe 'setup/apply.sh'
  apply="${SHELLSPEC_PROJECT_ROOT}/scripts/setup/apply.sh"
  example="${SHELLSPEC_PROJECT_ROOT}/scripts/setup/protected.example.json"
  labels="${SHELLSPEC_PROJECT_ROOT}/scripts/sem-labels.json"
  # The example ruleset, the way GitHub lists a repo's rulesets.
  ours="$(jq -c '[{id: 42, name: .name}]' "${example}")"

  BeforeEach 'fresh_gh'

  # Whether the JSON on stdin says the same as the file $1, whatever the formatting.
  same_json_as() {
    jq -S . > "${dir}/sent.json"
    jq -S . "$1" > "${dir}/want.json"
    cmp -s "${dir}/sent.json" "${dir}/want.json"
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
    export RULESETS="${ours}"
    When run script "${apply}" owner/repo
    The status should be success
    The output should be present
    The contents of file "${CALLS}" should include 'api PUT repos/owner/repo/rulesets/42'
    The contents of file "${CALLS}" should not include 'api POST'
  End

  It 'renames a ruleset still called Protected, in the same call that updates it'
    export RULESETS='[{"id": 42, "name": "Protected"}]'
    When run script "${apply}" owner/repo
    The status should be success
    The output should include 'Protected'
    The contents of file "${CALLS}" should include 'api PUT repos/owner/repo/rulesets/42'
    The contents of file "${CALLS}" should not include 'api POST'
    The contents of file "${BODY}" should satisfy same_json_as "${example}"
  End

  It 'leaves a ruleset with another name alone'
    export RULESETS='[{"id": 7, "name": "Releases"}]'
    When run script "${apply}" owner/repo
    The status should be success
    The output should be present
    The contents of file "${CALLS}" should include 'api POST repos/owner/repo/rulesets'
    The contents of file "${CALLS}" should not include 'rulesets/7'
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
    already_set_up
    When run script "${apply}" owner/repo
    The status should be success
    The output should include 'already'
    The result of function writes should be blank
  End

  Describe "when the API won't take the ruleset"
    Parameters
      'api GET repos/owner/repo/rulesets' none
      'api GET repos/owner/repo/rulesets/42' ours
      'api POST' none
      'api PUT' ours
    End

    It "says how to set it by hand and stops, when '$1' fails"
      export FAIL_ON="$1"
      if [[ $2 == ours ]]; then export RULESETS="${ours}"; fi
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
      'owner/repo --bogus x'
      'owner/repo --check'
      # A repo's own checks go in a ruleset of the repo's own.
      'owner/repo --check bench-ok'
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
