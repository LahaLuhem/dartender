#!/usr/bin/env bash
# shellcheck disable=SC2154  # actions/sem-label sets REPO and PR
set -euo pipefail
allowed=(sem-add sem-change sem-deprecate sem-remove sem-bugfix sem-security sem-skip)
printf -v choices '%s, ' "${allowed[@]}"
choices="${choices%, }"

# Asked fresh, since the labels in the event that started this run can be out of date by now.
labels="$(gh api "repos/${REPO}/pulls/${PR}" --jq '.labels[].name')"
sems=()
while IFS= read -r label; do
  if [[ ${label} == sem-* ]]; then sems+=("${label}"); fi
done <<< "${labels}"

if [[ ${#sems[@]} -ne 1 ]]; then
  echo "::error::The PR needs exactly one sem-* label, and it has ${#sems[@]}." \
    "Pick one of ${choices}."
  exit 1
fi
if [[ " ${allowed[*]} " != *" ${sems[0]} "* ]]; then
  echo "::error::${sems[0]} isn't a sem-* label this repo uses. Pick one of ${choices}."
  exit 1
fi
