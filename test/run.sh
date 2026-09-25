#!/usr/bin/env bash
# CI runs this too, so a local run and a CI run can't drift apart.
set -euo pipefail
cd "$(dirname "$0")/.."
docker build --quiet --tag dartender-specs test >/dev/null
exec docker run --rm --volume "${PWD}:/work:ro" dartender-specs "$@"
