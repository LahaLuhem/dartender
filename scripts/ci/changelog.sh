#!/usr/bin/env bash
# shellcheck disable=SC2154  # actions/changelog sets REPO, BRANCH, TYPE, TITLE and DRY_RUN
set -euo pipefail

path="$(git rev-parse --show-prefix)CHANGELOG.md"
# Sent with the commit, so GitHub refuses it only if CHANGELOG.md itself changed since the checkout.
blob="$(git rev-parse "HEAD:${path}")"
cider log "${TYPE}" "${TITLE}"
if git diff --quiet -- CHANGELOG.md; then
  echo "::error::cider left CHANGELOG.md as it was." >&2
  exit 1
fi
git diff -- CHANGELOG.md
if [[ ${DRY_RUN} == true ]]; then
  echo "A dry run, so nothing gets committed."
  exit 0
fi

# An App's commits start workflows, unlike GITHUB_TOKEN's, so [skip ci] keeps this one from CI.
body="$(jq -n --rawfile changelog CHANGELOG.md --arg sha "${blob}" --arg branch "${BRANCH}" \
  '{message: "Changelog updated [skip ci]", content: ($changelog | @base64), sha: $sha,
    branch: $branch}')"
if ! url="$(gh api --method PUT "repos/${REPO}/contents/${path}" --input - \
  --jq .commit.html_url <<< "${body}")"; then
  echo "::error::GitHub didn't take the commit. If ${path} changed on ${BRANCH} meanwhile," \
    "re-running this job writes the line on top of that." >&2
  exit 1
fi
echo "Committed the line: ${url}"
