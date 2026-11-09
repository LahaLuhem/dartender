#!/usr/bin/env bash
# shellcheck disable=SC2154  # actions/codegen-plan sets what this reads
set -euo pipefail

skip() {
  echo "$1" >&2
  echo "go=false"
  exit 0
}

# Anything but a finished CI run is the weekly bump, which has no run to look at.
if [[ "${EVENT}" != workflow_run ]]; then
  printf '%s\n' "go=true" "mode=bump" "branch=${DEFAULT_BRANCH}"
  exit 0
fi

run="$(gh api "repos/${REPO}/actions/runs/${RUN_ID}")"
conclusion="$(jq -r .conclusion <<< "${run}")"
if [[ "${conclusion}" != failure ]]; then
  skip "That run ended as ${conclusion}, so there is nothing to repair."
fi

# An installation token reaches this repo only, so a fork's branch stays red for a human.
head_repo="$(jq -r '.head_repository.full_name' <<< "${run}")"
if [[ "${head_repo}" != "${REPO}" ]]; then
  skip "${head_repo} is a fork, which this installation cannot push to."
fi

# Its own push starts the run that would send it back here.
message="$(jq -r '.head_commit.message' <<< "${run}")"
if [[ "${message}" == *"${MARKER}"* ]]; then
  skip "That run was on this job's own commit, so repairing it again would loop."
fi

jobs="$(gh api --paginate "repos/${REPO}/actions/runs/${RUN_ID}/jobs")"
# The calling job's id prefixes it, so `ci / Codegen` in a package repo.
failed="$(jq -r '.jobs[] | select(.conclusion == "failure")
  | select(.name == "Codegen" or (.name | endswith("/ Codegen"))) | .name' <<< "${jobs}")"
if [[ -z "${failed}" ]]; then
  skip "Something other than Codegen failed in that run, so this job has no business in it."
fi

branch="$(jq -r .head_branch <<< "${run}")"
printf '%s\n' "go=true" "mode=repair" "branch=${branch}"
