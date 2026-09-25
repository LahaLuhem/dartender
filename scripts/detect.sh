#!/usr/bin/env bash
# Prints what ci.yml needs to know about a package, as key=value lines for $GITHUB_OUTPUT.
set -euo pipefail
cd "${1:-.}"

manifest=.github/lint-checks.json
# An empty matrix would run zero linters and still pass, so a broken manifest has to fail here.
if ! jq -e '.image and (.checks | length > 0)' "${manifest}" >/dev/null 2>&1; then
  echo "::error::${manifest} is missing, malformed or empty." \
    "It needs an \"image\" and at least one check." >&2
  exit 1
fi
checks="$(jq -c .checks "${manifest}")"
image="$(jq -r .image "${manifest}")"
echo "lint-checks=${checks}"
echo "lint-image=${image}"
