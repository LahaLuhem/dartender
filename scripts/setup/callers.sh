#!/usr/bin/env bash
# Writes a package repo's caller workflows from dartender's brick, for its admin to commit.
set -euo pipefail
here="$(dirname "${BASH_SOURCE[0]}")"
source "${here}/common.sh"

usage() {
  error "Usage: callers.sh <coveralls> <min-coverage> <coverage-excludes> [folder]"
  exit 2
}

[[ $# -ge 3 && $# -le 4 ]] || usage
coveralls="$1" min_coverage="$2" coverage_excludes="$3" repo="${4:-.}"
branch="$(git -C "${repo}" symbolic-ref --short refs/remotes/origin/HEAD)"
branch="${branch#origin/}"

# Global, so mason leaves no mason.yaml in the repo.
mason add -g callers --path "${here}/../../bricks/callers" > /dev/null
rc=0
out="$(mason make callers --output-dir "${repo}" --on-conflict overwrite --set-exit-if-changed \
  --default_branch "${branch}" --coveralls "${coveralls}" --min_coverage "${min_coverage}" \
  --coverage_excludes "${coverage_excludes}" 2>&1)" || rc=$?
case "${rc}" in
  0) success "The callers in ${repo}/.github/workflows are already up to date" ;;
  # What --set-exit-if-changed exits with when it changed a file.
  70) success "Wrote the callers in ${repo}/.github/workflows" ;;
  *)
    error "mason couldn't write the callers: ${out}"
    exit "${rc}"
    ;;
esac
