#!/usr/bin/env bash
# Prints the changelog line a push needs as type= and title= for $GITHUB_OUTPUT, or nothing when
# there's no line to write. Everything else goes to stderr, so it can't land in the outputs.
# shellcheck disable=SC2154  # actions/changelog-type sets REPO and SHA
set -euo pipefail
here="$(dirname "${BASH_SOURCE[0]}")"

# The self-test's stand-ins, since dartender's own PRs carry no sem-* label.
if [[ -n ${LABEL:-} ]]; then
  who="The self-test's stand-in" label="${LABEL}" title="${TITLE:-}"
else
  pulls="$(gh api "repos/${REPO}/commits/${SHA}/pulls")"
  # A rebase merge lists every commit it brought under the PR, but only the last is its merge commit.
  merged="$(jq -c --arg sha "${SHA}" 'first(.[] | select(.merge_commit_sha == $sha))' \
    <<< "${pulls}")"
  if [[ -z ${merged} ]]; then
    echo "No pull request merged ${SHA:0:7}, so there's no line to write." >&2
    exit 0
  fi
  number="$(jq -r .number <<< "${merged}")"
  title="$(jq -r .title <<< "${merged}")"
  author="$(jq -r .user.login <<< "${merged}")"
  who="#${number}"
  if [[ ${author} == 'dependabot[bot]' ]]; then
    echo "${who} is Dependabot's, and its line gets written at release time." >&2
    exit 0
  fi
  # The conventions gate's own check, which reads the labels fresh and prints the one it found.
  if ! label="$(PR="${number}" "${here}/sem-label.sh")"; then
    echo "${label}" >&2
    exit 1
  fi
fi

entry="$(jq -c --arg label "${label}" '.[] | select(.name == $label)' "${here}/../sem-labels.json")"
if [[ -z ${entry} ]]; then
  echo "::error::${label} isn't one of the labels in sem-labels.json." >&2
  exit 1
fi
type="$(jq -r '.cider // ""' <<< "${entry}")"
if [[ -z ${type} ]]; then
  echo "${who} is ${label}, so there's no line to write." >&2
  exit 0
fi
echo "${who} is ${label}, so its line goes under ${type^}." >&2
echo "type=${type}"
# cider takes one line, and a line break here would start another output.
echo "title=${title//[$'\r\n']/ }"
