# shellcheck shell=bash
# shellcheck disable=SC2154  # ShellSpec sets the SHELLSPEC_* variables

# Puts the stand-ins first on PATH, with a fresh log and owner/repo set up with nothing.
fresh_gh() {
  dir="$(mktemp -d "${SHELLSPEC_TMPBASE}/gh.XXXXXX")"
  export PATH="${SHELLSPEC_PROJECT_ROOT}/test/utils/bin:${PATH}" CALLS="${dir}/calls" \
    BODY="${dir}/body.json" SETTINGS_BODY="${dir}/settings.json" \
    RULESETS='[]' RULESET='{}' LABELS='[]' SETTINGS='{}' FAIL_ON='' DECLINE_ON='' ABORT_ON='' \
    MASON_RC=70
  : > "${CALLS}"
}

# Gives owner/repo the example ruleset, the sem-* labels and the merge settings, each with the
# fields GitHub adds.
already_set_up() {
  RULESET="$(jq -c '. + {id: 42, node_id: "RRS_1", source: "owner/repo", _links: {}}' \
    "${SHELLSPEC_PROJECT_ROOT}/scripts/setup/protected.example.json")"
  LABELS="$(jq -c 'map(. + {id: 1, default: false})' \
    "${SHELLSPEC_PROJECT_ROOT}/scripts/sem-labels.json")"
  export RULESET LABELS RULESETS='[{"id": 42, "name": "Protected"}]' SETTINGS='{"id": 1,
    "allow_auto_merge": true, "allow_rebase_merge": true, "allow_squash_merge": false,
    "allow_merge_commit": false, "delete_branch_on_merge": true}'
}
