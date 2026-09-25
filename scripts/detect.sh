#!/usr/bin/env bash
# Prints what ci.yml needs to know about a package, as key=value lines for $GITHUB_OUTPUT.
set -euo pipefail
cd "${1:-.}"

manifest=.github/lint-checks.json
# No checks, or a check with no command, would lint nothing and still pass, so both fail here.
valid='.image and (.checks | length > 0) and all(.checks[];
  (.name | type == "string" and length > 0) and (.cmd | type == "string" and test("\\S")))'
if ! jq -e "${valid}" "${manifest}" >/dev/null 2>&1; then
  echo "::error::${manifest} is missing, malformed or empty." \
    "It needs an \"image\" and at least one check, each with a \"name\" and a \"cmd\"." >&2
  exit 1
fi
checks="$(jq -c .checks "${manifest}")"
image="$(jq -r .image "${manifest}")"
echo "lint-checks=${checks}"
echo "lint-image=${image}"
