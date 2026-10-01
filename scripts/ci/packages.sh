#!/usr/bin/env bash
# Prints the repo's packages, root first, as tab-separated `<name> <folder> <publishes>` lines,
# folders relative to the root.
set -euo pipefail
cd "${1:-.}"

# pub prints resolved paths.
root="$(pwd -P)"
listed="$(dart pub workspace list --json)"
rows="$(jq -r '.packages[] | [.name, .path] | @tsv' <<< "${listed}")"
while IFS=$'\t' read -r name path; do
  dir="${path#"${root}"}"
  dir="${dir#/}"
  dir="${dir:-.}"
  publish_to="$(yq '.publish_to // ""' "${dir}/pubspec.yaml")"
  publishes=true
  if [[ "${publish_to}" == none ]]; then publishes=false; fi
  printf '%s\t%s\t%s\n' "${name}" "${dir}" "${publishes}"
done <<< "${rows}"
