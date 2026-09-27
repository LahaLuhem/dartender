#!/usr/bin/env bash
# Sets a package repo's ruleset, sem-* labels and merge settings, with gh logged in as its admin.
set -euo pipefail
here="$(dirname "${BASH_SOURCE[0]}")"

usage() {
  echo "Usage: apply.sh <owner/repo> [--check <local gate>]..." >&2
  exit 2
}

[[ $# -gt 0 && $1 != -* ]] || usage
repo="$1"
shift
checks=()
while [[ $# -gt 0 ]]; do
  [[ $1 == --check && $# -gt 1 ]] || usage
  checks+=("$2")
  shift 2
done

# Local gates run on GitHub Actions like the shared ones, so they take the same integration id.
# The `+` form because macOS's bash 3.2 calls an empty array unset, which `set -u` stops on.
body="$(jq '
  (.rules[] | select(.type == "required_status_checks") | .parameters.required_status_checks) |=
    . + [$ARGS.positional[] as $gate | {context: $gate, integration_id: .[0].integration_id}]
' "${here}/protected.example.json" --args ${checks[@]+"${checks[@]}"})"
name="$(jq -r .name "${here}/protected.example.json")"

# For when the API won't take the ruleset, like with a token that can't manage rulesets.
by_hand() {
  echo "Couldn't set the ruleset. Import ${here}/protected.example.json under Settings → Rules," \
    "add each --check as a required check, then make sure it kept the admin bypass." >&2
  exit 1
}

# Matched by name, so a second run updates the ruleset instead of adding another.
rulesets="$(gh api --paginate "repos/${repo}/rulesets")" || by_hand
id="$(jq -r --arg name "${name}" '.[] | select(.name == $name) | .id' <<< "${rulesets}")"
if [[ -n ${id} ]]; then
  gh api --silent --method PUT "repos/${repo}/rulesets/${id}" --input - <<< "${body}" || by_hand
  echo "Ruleset ${name}: updated"
else
  gh api --silent --method POST "repos/${repo}/rulesets" --input - <<< "${body}" || by_hand
  echo "Ruleset ${name}: created"
fi

labels="$(jq -r '.[] | [.name, .color, .description] | @tsv' "${here}/../sem-labels.json")"
while IFS=$'\t' read -r label color description; do
  gh label create "${label}" --repo "${repo}" --color "${color}" --description "${description}" \
    --force
done <<< "${labels}"

gh repo edit "${repo}" --enable-auto-merge --enable-rebase-merge --enable-squash-merge=false \
  --enable-merge-commit=false --delete-branch-on-merge
