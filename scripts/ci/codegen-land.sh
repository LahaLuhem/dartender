#!/usr/bin/env bash
# shellcheck disable=SC2154  # actions/codegen-land sets what this reads
set -euo pipefail

git add --all
if git diff --cached --quiet; then
  echo "Nothing moved, so there is nothing to land."
  exit 0
fi
git diff --cached --stat

if [[ "${DRY_RUN}" == true ]]; then
  echo "A dry run, so nothing gets pushed."
  exit 0
fi

# No [skip ci] here, unlike the changelog's: the whole point is for the check to run again.
git -c "user.name=${AUTHOR_NAME}" -c "user.email=${AUTHOR_EMAIL}" commit --quiet -m "${MARKER}"

if [[ "${LAND}" == push ]]; then
  # Dependabot gives up rebasing a branch once anyone else pushes to it, so this commit stays.
  git push origin "HEAD:refs/heads/${BRANCH}"
  echo "Pushed the regen onto ${BRANCH}."
  exit 0
fi

# Forced, since last week's PR may still be open with a stale bump on it.
git push --force origin "HEAD:refs/heads/${BUMP_BRANCH}"
waiting="$(gh pr list --repo "${REPO}" --head "${BUMP_BRANCH}" --state open --json number \
  --jq 'length')"
if [[ "${waiting}" != 0 ]]; then
  echo "The PR already open from ${BUMP_BRANCH} now holds this."
  exit 0
fi
body="Generators moved to their newest, with the output they make. Dependabot leaves these"
body+=" alone, so this run is what moves them."
gh pr create --repo "${REPO}" --base "${BRANCH}" --head "${BUMP_BRANCH}" --title "${MARKER}" \
  --body "${body}"
