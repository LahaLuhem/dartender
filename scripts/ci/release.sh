#!/usr/bin/env bash
# shellcheck disable=SC2154  # actions/release and the runner set what this reads
set -euo pipefail
here="$(dirname "${BASH_SOURCE[0]}")"

# From another branch, the push would carry that branch's commits onto the default one. A dry run
# pushes nothing, so it can start anywhere.
if [[ ${DRY_RUN} != true && ${REF} != "refs/heads/${BRANCH}" ]]; then
  echo "::error::A release goes out from ${BRANCH}, and this run started on ${REF}." >&2
  exit 1
fi

picked="$("${here}/release-package.sh" "${PACKAGE}")"
IFS=$'\t' read -r folder name prefix <<< "${picked}"
version="$(yq '.version' "${folder}/pubspec.yaml")"

# The self-test's stand-ins, since no Dependabot PR touches its fixtures.
if [[ -n ${TITLES} ]]; then
  titles="${TITLES}"
else
  since="${prefix}${version}"
  if ! git rev-parse --quiet --verify "refs/tags/${since}" > /dev/null; then
    echo "::error::There's no tag ${since} for ${name}'s version, so there's no telling what came" \
      "after its last release. Tag the commit that released it." >&2
    exit 1
  fi
  titles="$("${here}/dependabot-lines.sh" "${folder}" "${since}")"
fi
if [[ -n ${titles} ]]; then
  while IFS= read -r title; do
    (cd "${folder}" && cider log changed "${title}")
  done <<< "${titles}"
fi

notes="$(cd "${folder}" && cider describe --only-body)"
if [[ -z ${notes//[[:space:]]/} ]]; then
  echo "::error::${name} has nothing under Unreleased, so there's nothing to release." >&2
  exit 1
fi

(cd "${folder}" && cider bump "${BUMP}" > /dev/null)
# From the pubspec, since pub's chatter can reach cider's output.
next="$(yq '.version' "${folder}/pubspec.yaml")"
tag="${prefix}${next}"
(cd "${folder}" && cider release)
"${here}/release-bounds.sh" "${name}" "${next}"
# The example's lockfile pins this package's version, so every bump leaves it stale.
if git ls-files --error-unmatch "${folder}/example/pubspec.lock" > /dev/null 2>&1; then
  (cd "${folder}/example" && flutter pub get)
fi

# Everything is the release's own, since the checkout started clean.
git add --update
# As whoever started the run, the way a release from a laptop was. The App only pushes it.
git -c user.name="${ACTOR}" -c user.email="${ACTOR_ID}+${ACTOR}@users.noreply.github.com" \
  commit --quiet --message "Prep for release ${tag}"
git show --stat HEAD
# After the commit, since pub checks the notes name the version and nothing is left uncommitted.
(cd "${folder}" && dart pub publish --dry-run)
git tag "${tag}"

if [[ ${DRY_RUN} == true ]]; then
  printf '## %s, as a dry run\n\n%s\n' "${tag}" "${notes}" >> "${GITHUB_STEP_SUMMARY}"
  echo "A dry run, so nothing gets pushed."
  exit 0
fi

auth="$(printf 'x-access-token:%s' "${PUSH_TOKEN}" | base64 | tr -d '\n')"
# The runner masks the token itself, not this form of it.
echo "::add-mask::${auth}"
# Atomic, so the tag that starts publish.yml can't land without its commit.
if ! git -c "http.https://github.com/.extraheader=AUTHORIZATION: basic ${auth}" \
  push --atomic origin "HEAD:refs/heads/${BRANCH}" "refs/tags/${tag}"; then
  echo "::error::GitHub didn't take the push. If ${BRANCH} moved since this run started, run the" \
    "release again." >&2
  exit 1
fi
printf '## %s\n\n%s\n' "${tag}" "${notes}" >> "${GITHUB_STEP_SUMMARY}"
echo "Pushed ${tag}, and publish.yml takes it from here."
