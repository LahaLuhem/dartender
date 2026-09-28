# shellcheck shell=bash
# shellcheck disable=SC2154  # ShellSpec sets the SHELLSPEC_* variables
Describe 'ci/changelog.sh'
  script="${SHELLSPEC_PROJECT_ROOT}/scripts/ci/changelog.sh"
  # shellcheck disable=SC2016  # a title holding backticks and a dollar sign, as typed
  export REPO=owner/repo BRANCH=master TYPE=added TITLE='Add `putAll` for $HOME' DRY_RUN=false

  # A checkout whose last commit holds a CHANGELOG.md in the folder $1, which the job runs in.
  checkout() {
    local root
    root="$(mktemp -d "${SHELLSPEC_TMPBASE}/checkout.XXXXXX")"
    mkdir -p "${root}/$1"
    printf '## 1.0.0 - 2026-09-26\n\n- Initial version.\n' > "${root}/$1/CHANGELOG.md"
    git -C "${root}" init -q
    git -C "${root}" add .
    git -C "${root}" -c user.name=spec -c user.email=spec@example.com commit -q -m First
    cd "${root}/$1" || return
  }

  setup() {
    local dir
    dir="$(mktemp -d "${SHELLSPEC_TMPBASE}/changelog.XXXXXX")"
    export ARGS="${dir}/args" CALLS="${dir}/calls" SENT="${dir}/sent.json"
    : > "${CALLS}"
    checkout .
  }
  BeforeEach 'setup'

  # Adds a line to CHANGELOG.md the way cider would, and keeps what it was called with.
  Mock cider
    printf '%s\n' "$@" > "${ARGS}"
    printf -- '- %s\n' "$3" >> CHANGELOG.md
  End

  # Keeps what gets sent, and answers with the new commit's URL.
  Mock gh
    echo "gh $*" >> "${CALLS}"
    cat > "${SENT}"
    echo https://github.com/owner/repo/commit/1
  End

  sent_sha() { jq -r .sha "${SENT}"; }
  sent_branch() { jq -r .branch "${SENT}"; }
  sent_message() { jq -r .message "${SENT}"; }
  # Whether the body on stdin carries CHANGELOG.md as it is now.
  carries_the_file() {
    jq -j '.content | @base64d' > "${SENT}.content"
    cmp -s "${SENT}.content" CHANGELOG.md
  }

  It 'runs cider log with the type and the whole title'
    expected="$(printf '%s\n' log added "${TITLE}")"
    When run script "${script}"
    The status should be success
    The output should include "${TITLE}"
    The contents of file "${ARGS}" should equal "${expected}"
  End

  It 'commits CHANGELOG.md as cider left it, to the branch it checked out'
    When run script "${script}"
    The status should be success
    The output should be present
    The contents of file "${CALLS}" should include '--method PUT'
    The contents of file "${CALLS}" should include 'repos/owner/repo/contents/CHANGELOG.md'
    The contents of file "${SENT}" should satisfy carries_the_file
    The result of function sent_branch should equal master
  End

  It 'commits over the blob it checked out, so GitHub refuses it if the file changed since'
    blob="$(git rev-parse HEAD:CHANGELOG.md)"
    When run script "${script}"
    The status should be success
    The output should be present
    The result of function sent_sha should equal "${blob}"
  End

  It 'marks the commit so it starts no CI run'
    When run script "${script}"
    The status should be success
    The output should be present
    The result of function sent_message should include '[skip ci]'
  End

  It 'commits a package in a subfolder at its path in the repo'
    checkout pkg/dart
    blob="$(git rev-parse HEAD:pkg/dart/CHANGELOG.md)"
    When run script "${script}"
    The status should be success
    The output should be present
    The contents of file "${CALLS}" should include 'repos/owner/repo/contents/pkg/dart/CHANGELOG.md'
    The result of function sent_sha should equal "${blob}"
  End

  It 'shows the line in a dry run, and commits nothing'
    export DRY_RUN=true
    When run script "${script}"
    The status should be success
    The output should include "${TITLE}"
    The contents of file "${CALLS}" should equal ''
  End

  It 'fails without committing when cider leaves CHANGELOG.md as it was'
    Mock cider
      :
    End
    When run script "${script}"
    The status should be failure
    The error should include 'as it was'
    The contents of file "${CALLS}" should equal ''
  End

  It 'fails without committing when cider fails, even partway through'
    Mock cider
      echo '- half a line' >> CHANGELOG.md
      echo 'FormatException: Invalid release header format: "1.0.0"' >&2
      (exit 70)
    End
    When run script "${script}"
    The status should be failure
    The error should include 'FormatException'
    The contents of file "${CALLS}" should equal ''
  End

  It 'says to re-run the job when GitHub refuses the commit'
    Mock gh
      echo 'gh: CHANGELOG.md does not match 5626abf (HTTP 409)' >&2
      (exit 1)
    End
    When run script "${script}"
    The status should be failure
    The output should be present
    The error should include 're-run'
  End
End
