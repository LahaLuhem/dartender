#!/usr/bin/env bash
set -euo pipefail

manifest=.github/codegen.json
# Into a variable first, so a jq failure stops the run instead of looping zero times.
steps="$(jq -r '.steps[] | [.name, (.folder // "."), .cmd] | @tsv' "${manifest}")"

while IFS=$'\t' read -r name folder cmd; do
  echo "::group::${name}"
  # shellcheck disable=SC2086  # unquoted so the command splits into words and its globs expand
  (cd "${folder}" || exit; ${cmd})
  echo "::endgroup::"
done <<< "${steps}"
