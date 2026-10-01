#!/usr/bin/env bash
# shellcheck disable=SC2154  # actions/tag-package sets what this reads
set -euo pipefail
here="$(dirname "${BASH_SOURCE[0]}")"

packages="$("${here}/packages.sh")"
declare -A published=()
while IFS=$'\t' read -r name dir publishes; do
  if [[ ${publishes} == true ]]; then published["${name}"]="${dir}"; fi
done <<< "${packages}"

case "${TAG}" in
  # Package names can't start with a digit, so this is a bare version.
  [0-9]*)
    if [[ ${#published[@]} -ne 1 ]]; then
      echo "::error::This repo publishes ${#published[@]} packages, so a tag names the one to publish," \
        "like <package>-${TAG}." >&2
      exit 1
    fi
    folder="${published[*]}"
    ;;
  *)
    if [[ ${#published[@]} -eq 1 ]]; then
      echo "::error::This repo publishes only ${!published[*]}, so its tags are bare versions, like" \
        "1.2.0." >&2
      exit 1
    fi
    name="${TAG%%-*}"
    folder="${published[${name}]-}"
    if [[ -z ${folder} ]]; then
      echo "::error::No package here that publishes is called ${name}." >&2
      exit 1
    fi
    ;;
esac
echo "folder=${folder}"
