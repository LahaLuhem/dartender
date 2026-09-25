#!/usr/bin/env bash
# shellcheck disable=SC2154  # actions/lint sets DEFAULTS, LINTERPOL_IMAGE and LINT_CMD
set -euo pipefail
# A repo lints with the shared configs unless it brings its own.
[[ -e .rumdl.toml ]] || cp "${DEFAULTS}/rumdl.toml" .rumdl.toml
[[ -e .yamllint.yaml ]] || cp "${DEFAULTS}/yamllint.yaml" .yamllint.yaml
# shellcheck disable=SC2086  # unquoted so it splits into tool and args, and globs like *.sh expand
docker run --rm -v "${PWD}:/work:ro" "${LINTERPOL_IMAGE}" ${LINT_CMD}
