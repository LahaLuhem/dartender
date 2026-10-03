#!/usr/bin/env bash
set -euo pipefail
here="$(dirname "${BASH_SOURCE[0]}")"

packages="$("${here}/packages.sh")"
declare -A publishes_in=()
while IFS=$'\t' read -r _ dir publishes; do publishes_in["${dir}"]="${publishes}"; done <<< "${packages}"

declare -A changed=()
while IFS= read -r file; do
  if [[ -z ${file} ]]; then continue; fi
  # The deepest package folder holding the file owns it, so a member's change isn't its root's.
  owner='' longest=-1
  for dir in "${!publishes_in[@]}"; do
    prefix="${dir}/"
    if [[ ${dir} == . ]]; then prefix=''; fi
    if [[ ${file} == "${prefix}"* && ${#prefix} -gt ${longest} ]]; then
      owner="${dir}" longest="${#prefix}"
    fi
  done
  if [[ ${publishes_in[${owner}]-} == true ]]; then changed["${owner}"]=1; fi
done

if [[ ${#changed[@]} -gt 0 ]]; then printf '%s\n' "${!changed[@]}" | sort; fi
