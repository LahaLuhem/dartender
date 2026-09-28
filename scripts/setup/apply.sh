#!/usr/bin/env bash
# Sets a package repo's ruleset, sem-* labels and merge settings, with gh logged in as its admin.
# Whatever is already set stays as it is, so running it again is safe.
set -euo pipefail
here="$(dirname "${BASH_SOURCE[0]}")"
source "${here}/common.sh"

usage() {
  error "Usage: apply.sh <owner/repo>"
  exit 2
}

[[ $# -eq 1 && $1 != -* ]] || usage
repo="$1"

# Compares only $want's fields, since GitHub adds its own, like ids and links.
# shellcheck disable=SC2016  # a jq program, whose $want and $got are jq variables
same='. as $got | $want == ($want | with_entries(.value = $got[.key]))'

body="$(< "${here}/protected.example.json")"
name="$(jq -r .name <<< "${body}")"

# For when the API won't take the ruleset, like with a token that can't manage rulesets.
by_hand() {
  error "Couldn't set the ruleset. Import ${here}/protected.example.json under Settings → Rules," \
    "then make sure it kept the admin bypass."
  exit 1
}

# Matched by name, so a second run updates the ruleset instead of adding another.
rulesets="$(gh api --paginate "repos/${repo}/rulesets")" || by_hand
id="$(jq -r --arg name "${name}" '.[] | select(.name == $name) | .id' <<< "${rulesets}")"
if [[ -z ${id} ]]; then
  gh api --silent --method POST "repos/${repo}/rulesets" --input - <<< "${body}" || by_hand
  success "Ruleset ${name}: created"
  info "Delete the repo's older ruleset, if it has one, since nothing runs its required checks now."
else
  ruleset="$(gh api "repos/${repo}/rulesets/${id}")" || by_hand
  if jq -e --argjson want "${body}" "${same}" <<< "${ruleset}" > /dev/null; then
    success "Ruleset ${name}: already set"
  else
    gh api --silent --method PUT "repos/${repo}/rulesets/${id}" --input - <<< "${body}" || by_hand
    success "Ruleset ${name}: updated"
  fi
fi

# The sem-* labels that are missing or differ, ignoring the cider type, which GitHub doesn't keep.
have="$(gh api --paginate "repos/${repo}/labels")"
todo="$(jq -n -r --slurpfile want "${here}/../sem-labels.json" '
  [inputs[] | {name, color, description}] as $have
  | $want[0][] | {name, color, description} | select(IN($have[]) | not)
  | [.name, .color, .description, if (.name | IN($have[].name)) then "updated" else "created" end]
  | @tsv' <<< "${have}")"
if [[ -z ${todo} ]]; then
  success "Labels: already set"
else
  mapfile -t rows <<< "${todo}"
  for row in "${rows[@]}"; do
    IFS=$'\t' read -r label color description how <<< "${row}"
    gh label create "${label}" --repo "${repo}" --color "${color}" --description "${description}" \
      --force
    success "Label ${label}: ${how}"
  done
fi

merge='{"allow_auto_merge": true, "allow_rebase_merge": true, "allow_squash_merge": false,
  "allow_merge_commit": false, "delete_branch_on_merge": true}'
settings="$(gh api "repos/${repo}")"
if jq -e --argjson want "${merge}" "${same}" <<< "${settings}" > /dev/null; then
  success "Merge settings: already set"
else
  gh api --silent --method PATCH "repos/${repo}" --input - <<< "${merge}"
  success "Merge settings: updated"
fi
