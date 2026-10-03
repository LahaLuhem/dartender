#!/usr/bin/env bash
set -euo pipefail
here="$(dirname "${BASH_SOURCE[0]}")"

packages="$("${here}/packages.sh")"
mapfile -t rows <<< "${packages}"
failed=()
for row in "${rows[@]}"; do
  IFS=$'\t' read -r name dir publishes <<< "${row}"
  # pub.dev only documents what it publishes.
  if [[ ${publishes} != true ]]; then continue; fi
  # dart doc exits 0 on warnings, so its summary decides, and an error shows there too.
  log="$(cd "${dir}" && dart doc --dry-run 2>&1)" || :
  printf '%s:\n%s\n' "${name}" "${log}"
  if ! grep -q '^Found 0 warnings and 0 errors\.$' <<< "${log}"; then failed+=("${name}"); fi
done
if [[ ${#failed[@]} -gt 0 ]]; then
  echo "::error::dart doc didn't come back clean for ${failed[*]}, see its output above." >&2
  exit 1
fi
