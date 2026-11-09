# shellcheck shell=bash
# shellcheck disable=SC2154  # ShellSpec sets the SHELLSPEC_* variables

pub_lists() {
  # Its own folder, so a spec's gh mock isn't shadowed by the one in test/utils/bin.
  export PATH="${SHELLSPEC_PROJECT_ROOT}/test/utils/pub:${PATH}" LISTED="$*" PUB_FAILS=''
}

pub_fails() {
  export PATH="${SHELLSPEC_PROJECT_ROOT}/test/utils/pub:${PATH}" LISTED='' PUB_FAILS="$1"
}

# What `pub outdated` still has room to move, as "<package>:<kind>:<newest>" words.
pub_outdated() {
  export PATH="${SHELLSPEC_PROJECT_ROOT}/test/utils/pub:${PATH}" OUTDATED="$*" LISTED='' PUB_FAILS=''
  ADDED="$(mktemp "${SHELLSPEC_TMPBASE}/added.XXXXXX")"
  export ADDED
}

# One "<folder> pub add dev:<package>:<version>" line per bump, in the order they ran.
pub_added() {
  cat "${ADDED}"
}
