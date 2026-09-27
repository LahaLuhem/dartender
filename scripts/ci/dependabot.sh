#!/usr/bin/env bash
# Fails on each pair from detect.sh that no block in the repo's dependabot.yml watches.
# shellcheck disable=SC2154  # actions/dependabot sets PAIRS
set -euo pipefail
# Dependabot matches `directories` globs against the folders in its checkout, dotfolders included.
shopt -s dotglob
cd "${1:-.}"

config=.github/dependabot.yml
if [[ ! -f ${config} && -f .github/dependabot.yaml ]]; then config=.github/dependabot.yaml; fi
entries=''
if [[ -f ${config} ]]; then
  updates="$(yq -o json '.updates // []' "${config}")"
  entries="$(jq -r '.[] | ."package-ecosystem" as $e
    | (.directory // empty | [$e, ., "directory"]),
      ((.directories // [])[] | [$e, ., "directories"])
    | @tsv' <<< "${updates}")"
fi

declare -A watched=()
while IFS=$'\t' read -r ecosystem dir key; do
  if [[ -z ${ecosystem} ]]; then continue; fi
  dir="/${dir#/}"
  if [[ ${dir} != / ]]; then dir="${dir%/}"; fi
  # Only `directories` takes globs.
  if [[ ${key} == directories && ${dir} =~ [*?[] ]]; then
    # shellcheck disable=SC2086  # unquoted, so the glob expands
    for match in ${dir#/}; do
      if [[ -d ${match} ]]; then watched["${ecosystem} /${match}"]=1; fi
    done
  else
    watched["${ecosystem} ${dir}"]=1
  fi
done <<< "${entries}"

listed="$(jq -r '.[] | "\(."package-ecosystem") \(.directory)"' <<< "${PAIRS}")"
fail=0
while IFS= read -r pair; do
  if [[ -z ${pair} || -v watched["${pair}"] ]]; then continue; fi
  echo "::error::No block in ${config} watches ${pair%% *} in ${pair#* }."
  fail=1
done <<< "${listed}"
if [[ ${fail} -eq 1 ]]; then
  echo "::error::dartender's scripts/setup/setup.sh writes a block for each of them."
fi
exit "${fail}"
