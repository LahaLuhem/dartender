#!/usr/bin/env bash
# shellcheck disable=SC2154  # actions/codegen-bump sets what this reads
set -euo pipefail

# Into a variable first, so a jq failure stops the run instead of looping zero times.
folders="$(jq -r '.[] | [.directory, (.packages | join(" "))] | @tsv' <<< "${GENERATORS}")"

bumped=0
while IFS=$'\t' read -r directory ours; do
  if [[ -z "${ours}" ]]; then continue; fi
  folder=".${directory%/}"
  echo "::group::${folder}"
  # A package already at its newest is left out of `pub outdated`, so this filters as well.
  moves="$(cd "${folder}" && dart pub outdated --json | jq -r --arg ours "${ours}" \
    '($ours | split(" ")) as $mine | .packages[]
      | select(.kind == "dev" and (.package as $p | $mine | index($p)))
      | [.package, .latest.version] | @tsv')"
  while IFS=$'\t' read -r package version; do
    if [[ -z "${package}" ]]; then continue; fi
    # Exact again, so the next run still reads it as this job's to move.
    (cd "${folder}" && dart pub add "dev:${package}:${version}")
    bumped=$((bumped + 1))
  done <<< "${moves}"
  echo "::endgroup::"
done <<< "${folders}"

echo "Generators bumped: ${bumped}."
