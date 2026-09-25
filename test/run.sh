#!/usr/bin/env bash
# CI runs this too, so a local run and a CI run can't drift apart.
set -euo pipefail
cd "$(dirname "$0")/.."
# From stdin, so Docker isn't sent the fixture packages and whatever builds sit in them.
docker build --quiet --tag dartender-specs - < test/Dockerfile >/dev/null
exec docker run --rm --volume "${PWD}:/work:ro" dartender-specs "$@"
