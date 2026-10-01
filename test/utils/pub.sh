# shellcheck shell=bash
# shellcheck disable=SC2154  # ShellSpec sets the SHELLSPEC_* variables

# Has the dart stand-in list the `<name>:<folder>` packages given. Its own folder, so a spec's gh
# mock isn't shadowed by the one in test/utils/bin.
pub_lists() {
  export PATH="${SHELLSPEC_PROJECT_ROOT}/test/utils/pub:${PATH}" LISTED="$*" PUB_FAILS=''
}

# Has the dart stand-in fail the way pub does, with the message $1.
pub_fails() {
  export PATH="${SHELLSPEC_PROJECT_ROOT}/test/utils/pub:${PATH}" LISTED='' PUB_FAILS="$1"
}
