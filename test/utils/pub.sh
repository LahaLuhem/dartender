# shellcheck shell=bash
# shellcheck disable=SC2154  # ShellSpec sets the SHELLSPEC_* variables

pub_lists() {
  # Its own folder, so a spec's gh mock isn't shadowed by the one in test/utils/bin.
  export PATH="${SHELLSPEC_PROJECT_ROOT}/test/utils/pub:${PATH}" LISTED="$*" PUB_FAILS=''
}

pub_fails() {
  export PATH="${SHELLSPEC_PROJECT_ROOT}/test/utils/pub:${PATH}" LISTED='' PUB_FAILS="$1"
}
