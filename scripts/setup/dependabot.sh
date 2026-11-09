#!/usr/bin/env bash
set -euo pipefail
here="$(dirname "${BASH_SOURCE[0]}")"
source "${here}/common.sh"
repo="${1:-.}"

detected="$("${here}/../detect.sh" "${repo}")"
pairs="$(sed -n 's/^dependabot=//p' <<< "${detected}")"
generators="$(sed -n 's/^generators=//p' <<< "${detected}")"
# Majors stay out of the group, so each one gets a PR of its own. A pinned generator is left
# out altogether, since the codegen job bumps it alongside the output it regenerates.
config="$(jq --argjson generators "${generators}" '
  ($generators | map({key: .directory, value: .packages}) | from_entries) as $owned
  | {version: 2, updates: map(. + {
      schedule: {interval: "weekly"},
      groups: {(."package-ecosystem"): {patterns: ["*"], "update-types": ["minor", "patch"]}}
    }
    | if ."package-ecosystem" == "pub" and ($owned[.directory] // [] | length) > 0
      then . + {ignore: ($owned[.directory] | map({"dependency-name": .}))}
      else . end)}' <<< "${pairs}" | yq -p json '.updates[].groups[][] style="flow"')"

header="# Written by dartender's scripts/setup/dependabot.sh, whose next run undoes hand edits."
wanted="$(printf '%s\n' "${header}" "${config}")"

file="${repo}/.github/dependabot.yml"
current=''
if [[ -f ${file} ]]; then current="$(< "${file}")"; fi
if [[ ${current} == "${wanted}" ]]; then
  success "${file} is already up to date"
else
  printf '%s\n' "${wanted}" > "${file}"
  success "Wrote ${file}"
fi
