# shellcheck shell=bash
# shellcheck disable=SC2154  # ShellSpec sets the SHELLSPEC_* variables

fresh_gh() {
  dir="$(mktemp -d "${SHELLSPEC_TMPBASE}/gh.XXXXXX")"
  export PATH="${SHELLSPEC_PROJECT_ROOT}/test/utils/bin:${PATH}" CALLS="${dir}/calls" \
    BODY="${dir}/body.json" SETTINGS_BODY="${dir}/settings.json" \
    RULESETS='[]' RULESET='{}' LABELS='[]' SETTINGS='{}' FAIL_ON='' DECLINE_ON='' ABORT_ON='' \
    ACCEPT_ON='' TYPE_ON='' TYPED='' MASON_RC=70
  : > "${CALLS}"
}

# The way GitHub hands them back, with fields of its own added and no cider types.
already_set_up() {
  local example="${SHELLSPEC_PROJECT_ROOT}/scripts/setup/protected.example.json"
  RULESET="$(jq -c '. + {id: 42, node_id: "RRS_1", source: "owner/repo", _links: {}}' "${example}")"
  RULESETS="$(jq -c '[{id: 42, name: .name}]' "${example}")"
  LABELS="$(jq -c 'map({name, color, description} + {id: 1, default: false})' \
    "${SHELLSPEC_PROJECT_ROOT}/scripts/sem-labels.json")"
  export RULESET RULESETS LABELS SETTINGS='{"id": 1,
    "allow_auto_merge": true, "allow_rebase_merge": true, "allow_squash_merge": false,
    "allow_merge_commit": false, "delete_branch_on_merge": true}'
}
