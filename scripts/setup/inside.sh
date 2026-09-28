#!/usr/bin/env bash
# What setup.sh runs in its container: the repo's callers, dependabot.yml and GitHub settings.
set -euo pipefail
here="$(dirname "${BASH_SOURCE[0]}")"
source "${here}/common.sh"

usage() {
  error "Usage: setup.sh [-y] [--check <local gate>]..."
  exit 2
}

# Sets answer to yes or no. A plain call rather than an if condition, so set -e holds inside it.
ask() {
  answer=yes
  if [[ ${yes} == true ]]; then return; fi
  local rc=0
  gum confirm --default=true "$1" || rc=$?
  # gum exits 0 for yes and 1 for no, so anything else, like 130 for ctrl+c, stops the setup.
  if [[ ${rc} -gt 1 ]]; then exit "${rc}"; fi
  if [[ ${rc} -eq 1 ]]; then answer=no; fi
}

# What the repo's ci caller passes for the input $1 now, or else ci.yml's own default for it.
caller_value() {
  local caller=.github/workflows/ci.yml
  export INPUT="$1"
  if [[ -f ${caller} ]] \
    && yq -e '(.jobs.ci.with // {}) | has(strenv(INPUT))' "${caller}" > /dev/null; then
    yq '.jobs.ci.with[strenv(INPUT)]' "${caller}"
  else
    yq '.on.workflow_call.inputs[strenv(INPUT)].default' "${here}/../../.github/workflows/ci.yml"
  fi
}

yes=false
if [[ ${1-} == -y ]]; then
  yes=true
  shift
fi
parse_checks "$@"
repo="$(gh repo view --json nameWithOwner --jq .nameWithOwner)"
info "Setting up ${repo}"
# Before dependabot.yml, which then covers them.
ask "Write the callers in .github/workflows?"
if [[ ${answer} == yes ]]; then
  coveralls="$(caller_value coveralls)"
  min_coverage="$(caller_value min-coverage)"
  coverage_excludes="$(caller_value coverage-excludes)"
  "${here}/callers.sh" "${coveralls}" "${min_coverage}" "${coverage_excludes}"
else
  info "Left the callers in .github/workflows as they are"
fi
ask "Write .github/dependabot.yml?"
if [[ ${answer} == yes ]]; then
  "${here}/dependabot.sh"
else
  info "Left .github/dependabot.yml as it is"
fi
ask "Set the ruleset, sem-* labels and merge settings on GitHub?"
if [[ ${answer} == yes ]]; then
  "${here}/apply.sh" "${repo}" "$@"
else
  info "Left the settings on GitHub as they are"
fi
success "Done with ${repo}"
