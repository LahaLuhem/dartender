#!/usr/bin/env bash
# Writes a package repo's .github/dependabot.yml from what detect.sh finds, for its admin to commit.
set -euo pipefail
here="$(dirname "${BASH_SOURCE[0]}")"
source "${here}/common.sh"
repo="${1:-.}"

pairs="$("${here}/../detect.sh" "${repo}" | sed -n 's/^dependabot=//p')"
# Majors stay out of the group, so each one gets a PR of its own.
config="$(jq '{version: 2, updates: map(. + {
  schedule: {interval: "weekly"},
  groups: {(."package-ecosystem"): {patterns: ["*"], "update-types": ["minor", "patch"]}}
})}' <<< "${pairs}" | yq -p json '.updates[].groups[][] style="flow"')"

file="${repo}/.github/dependabot.yml"
printf '%s\n' "# Written by dartender's scripts/setup/dependabot.sh, which rewrites it each run." \
  "${config}" > "${file}"
success "Wrote ${file}"
