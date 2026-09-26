#!/usr/bin/env bash
# shellcheck disable=SC2154  # actions/branch-name sets BRANCH
set -euo pipefail
pattern='^(feature|bugfix|chore|refactor)/#[0-9]+-.+$'

if [[ ! "${BRANCH}" =~ ${pattern} ]]; then
  echo "::error::Branch '${BRANCH}' should look like <type>/#<issue>-<name>, with <type> one of" \
    "feature, bugfix, chore or refactor. For example chore/#4-tidy-readme."
  exit 1
fi
