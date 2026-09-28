#!/usr/bin/env bash
# What setup.sh runs in its container: the repo's dependabot.yml, then its settings on GitHub.
set -euo pipefail
here="$(dirname "${BASH_SOURCE[0]}")"
source "${here}/common.sh"

usage() {
  error "Usage: setup.sh [--check <local gate>]..."
  exit 2
}

parse_checks "$@"
repo="$(gh repo view --json nameWithOwner --jq .nameWithOwner)"
info "Setting up ${repo}"
"${here}/dependabot.sh"
"${here}/apply.sh" "${repo}" "$@"
success "${repo} is set up"
