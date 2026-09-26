#!/usr/bin/env bash
# shellcheck disable=SC2154  # actions/commit-conventions sets PR_BODY, BASE_SHA and HEAD_SHA
set -euo pipefail
range="${BASE_SHA}..${HEAD_SHA}"
max=82
fail=0

if [[ -z "${PR_BODY//[[:space:]]/}" ]]; then
  echo "::error::The pull request needs a description."
  fail=1
fi

merges="$(git log --merges --format='%h %s' "${range}")"
if [[ -n "${merges}" ]]; then
  echo "::error::Rebase onto the base branch instead of merging it in:"
  echo "${merges}"
  fail=1
fi

subjects="$(git log --format=%s "${range}")"
while IFS= read -r subject; do
  if [[ ${#subject} -gt ${max} ]]; then
    echo "::error::Commit subject over ${max} characters: ${subject}"
    fail=1
  fi
done <<< "${subjects}"

exit "${fail}"
