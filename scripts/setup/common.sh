# shellcheck shell=bash
# Sourced by the scripts next to it, for one way of saying things and one bash to count on.

info() { echo "🔔 $*"; }
success() { echo "✔️ $*"; }
error() { echo "❌ $*" >&2; }

# 4.4 is the first to take an empty array under `set -u`, and 5 is the simpler line to draw.
if [[ "${BASH_VERSINFO[0]:-0}" -lt 5 ]]; then
  error "This needs bash 5 or newer, and this is ${BASH_VERSION:-another shell}." \
    "macOS still ships 3.2, so install a newer one (brew install bash)."
  exit 1
fi
