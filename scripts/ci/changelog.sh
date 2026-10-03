#!/usr/bin/env bash
# shellcheck disable=SC2154  # actions/changelog sets what this reads
set -euo pipefail
here="$(dirname "${BASH_SOURCE[0]}")"

# The self-test's stand-in, since dartender's own PRs carry no sem-* label.
if [[ -n ${FILES} ]]; then
  files="${FILES}"
else
  # A moved file changed the package it left as well.
  files="$(gh api --paginate "repos/${REPO}/pulls/${NUMBER}/files" \
    --jq '.[] | .filename, .previous_filename // empty')"
fi
packages="$("${here}/changelog-packages.sh" <<< "${files}")"
if [[ -z ${packages} ]]; then
  echo "The PR changed no package that publishes, so there's no line to write." >&2
  exit 0
fi
mapfile -t folders <<< "${packages}"

# Every line before the first commit, so a CHANGELOG.md cider can't read stops them all.
for folder in "${folders[@]}"; do
  (cd "${folder}" && cider log "${TYPE}" "${TITLE}")
  if git diff --quiet -- "${folder}/CHANGELOG.md"; then
    echo "::error::cider left ${folder}/CHANGELOG.md as it was." >&2
    exit 1
  fi
  git diff -- "${folder}/CHANGELOG.md"
done
if [[ ${DRY_RUN} == true ]]; then
  echo "A dry run, so nothing gets committed."
  exit 0
fi

for folder in "${folders[@]}"; do
  path="$(git -C "${folder}" rev-parse --show-prefix)CHANGELOG.md"
  # Sent with the commit, so GitHub refuses it only if CHANGELOG.md itself changed since the checkout.
  blob="$(git rev-parse "HEAD:${path}")"
  # An App's commits start workflows, unlike GITHUB_TOKEN's, so [skip ci] keeps this one from CI.
  body="$(jq -n --rawfile changelog "${folder}/CHANGELOG.md" --arg sha "${blob}" \
    --arg branch "${BRANCH}" '{message: "Changelog updated [skip ci]",
      content: ($changelog | @base64), sha: $sha, branch: $branch}')"
  if ! url="$(GH_TOKEN="${COMMIT_TOKEN}" gh api --method PUT "repos/${REPO}/contents/${path}" \
    --input - --jq .commit.html_url <<< "${body}")"; then
    echo "::error::GitHub didn't take the commit to ${path}. If it changed on ${BRANCH} meanwhile," \
      "a re-run writes the line on top of that, and again into any package committed above." >&2
    exit 1
  fi
  echo "Committed the line: ${url}"
done
