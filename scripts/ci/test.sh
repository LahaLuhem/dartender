#!/usr/bin/env bash
# Tests every package in one very_good run from the root, gated on their combined coverage, so a
# suite that covers another package's code counts there.
# shellcheck disable=SC2154  # actions/test sets FLUTTER, MIN_COVERAGE and EXCLUDES
set -euo pipefail
here="$(dirname "${BASH_SOURCE[0]}")"

packages="$("${here}/packages.sh")"
paths=()
while IFS=$'\t' read -r _ dir _; do
  lib="${dir}/lib" tests="${dir}/test"
  if [[ -d "${lib}" ]]; then paths+=("--report-on=${lib#./}"); fi
  if [[ -d "${tests}" ]]; then paths+=("${tests#./}"); fi
done <<< "${packages}"

command=(very_good dart test --check-ignore)
if [[ "${FLUTTER}" == true ]]; then command=(very_good test); fi
# very_good passes without testing anything when the folder it starts in has no test folder.
mkdir -p test
# --no-optimization runs the test files as written, instead of merged into one.
exec "${command[@]}" --coverage --min-coverage "${MIN_COVERAGE}" --exclude-coverage "${EXCLUDES}" \
  --collect-coverage-from imports --no-optimization "${paths[@]}"
