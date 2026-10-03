#!/usr/bin/env bash
set -euo pipefail
here="$(dirname "${BASH_SOURCE[0]}")"
package="${1-}"

packages="$("${here}/packages.sh")"
declare -A published=()
while IFS=$'\t' read -r name dir publishes; do
  if [[ ${publishes} == true ]]; then published["${name}"]="${dir}"; fi
done <<< "${packages}"

if [[ -z ${package} ]]; then
  if [[ ${#published[@]} -ne 1 ]]; then
    echo "::error::This repo publishes ${#published[@]} packages, so the package input has to name" \
      "one." >&2
    exit 1
  fi
  package="${!published[*]}"
fi
folder="${published[${package}]-}"
if [[ -z ${folder} ]]; then
  echo "::error::No package here that publishes is called ${package}." >&2
  exit 1
fi
# tag-package.sh reads the tag back by the same rule when publish.yml runs on it.
prefix=''
if [[ ${#published[@]} -gt 1 ]]; then prefix="${package}-"; fi
printf '%s\t%s\t%s\n' "${folder}" "${package}" "${prefix}"
