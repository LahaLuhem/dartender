#!/usr/bin/env bash
# Sets up the package repo it runs in, from a container that brings every tool the setup needs.
set -euo pipefail
here="$(dirname "${BASH_SOURCE[0]}")"
source "${here}/common.sh"
root="$(cd "${here}/../.." && pwd)"

info "Getting the setup image ready, which takes a while the first time"
docker build --quiet --tag dartender-setup - < "${here}/Dockerfile" > /dev/null
GH_TOKEN="$(gh auth token)"
export GH_TOKEN
# The scripts come in as a mount rather than in the image, so a cached image can't run stale ones.
# GH_TOKEN goes by name only, which keeps the token out of ps.
exec docker run --rm --env GH_TOKEN --volume "${PWD}:/repo" --workdir /repo \
  --volume "${root}:/dartender:ro" dartender-setup /dartender/scripts/setup/inside.sh "$@"
