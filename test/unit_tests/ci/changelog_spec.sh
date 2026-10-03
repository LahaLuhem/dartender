# shellcheck shell=bash
# shellcheck disable=SC2154  # ShellSpec sets the SHELLSPEC_* variables
Include test/utils/pub.sh

Describe 'ci/changelog.sh'
  script="${SHELLSPEC_PROJECT_ROOT}/scripts/ci/changelog.sh"
  # shellcheck disable=SC2016  # a title holding backticks and a dollar sign, as typed
  export REPO=owner/repo BRANCH=master NUMBER=7 FILES='' TYPE=added TITLE='Add `putAll` for $HOME' \
    DRY_RUN=false GH_TOKEN=job-token COMMIT_TOKEN=app-token REFUSE=''

  setup() {
    local dir
    dir="$(mktemp -d "${SHELLSPEC_TMPBASE}/changelog.XXXXXX")"
    export ARGS="${dir}/args" READS="${dir}/reads" SENT="${dir}/sent.json"
    : > "${READS}"
    : > "${SENT}"
    checkout="$(mktemp -d "${SHELLSPEC_TMPBASE}/checkout.XXXXXX")"
  }
  BeforeEach 'setup'

  package() {
    mkdir -p "${checkout}/$2"
    printf 'name: %s\n%s' "$1" "${3-}" > "${checkout}/$2/pubspec.yaml"
    printf '## 1.0.0 - 2026-09-26\n\n- Initial version of %s.\n' "$1" > "${checkout}/$2/CHANGELOG.md"
  }

  # Commits the checkout and runs in its folder $1, where pub lists the rest.
  clone() {
    git -C "${checkout}" init -q
    git -C "${checkout}" add .
    git -C "${checkout}" -c user.name=spec -c user.email=spec@example.com commit -q -m First
    cd "${checkout}/$1" || return
    shift
    pub_lists "$@"
  }

  # The PR's changed files, on one page of GitHub's answer.
  changed() {
    PAGES="$(jq -cn '[$ARGS.positional | map({filename: .})]' --args "$@")"
    export PAGES
  }

  one_package() {
    package a .
    clone . a:.
    changed lib/a.dart
  }

  # Its root, in folder $1, doesn't publish, and its members a, b and c do.
  workspace() {
    package w "$1" $'publish_to: none\n'
    package a "$1/packages/a"
    package b "$1/packages/b"
    package c "$1/packages/c"
    clone "$1" w:. a:packages/a b:packages/b c:packages/c
  }

  Mock cider
    printf '%s\n' "$@" > "${ARGS}"
    printf -- '- %s\n' "$3" >> CHANGELOG.md
  End

  Mock gh
    case "$*" in
      'api --paginate repos/owner/repo/pulls/7/files --jq '*)
        echo "${GH_TOKEN}" >> "${READS}"
        # Like gh, the filter goes over each page on its own.
        jq -r ".[] | $5" <<< "${PAGES}"
        ;;
      'api repos/owner/repo/pulls/7/files --jq '*)
        echo "${GH_TOKEN}" >> "${READS}"
        jq -r ".[0] | $4" <<< "${PAGES}"
        ;;
      'api --method PUT repos/owner/repo/contents/'*)
        if [[ -n ${REFUSE} ]]; then
          echo "${REFUSE}" >&2
          exit 1
        fi
        jq -c --arg path "${4#repos/owner/repo/contents/}" --arg token "${GH_TOKEN}" \
          '. + {path: $path, token: $token}' >> "${SENT}"
        echo https://github.com/owner/repo/commit/1
        ;;
      *)
        echo "unexpected call: gh $*" >&2
        exit 9
        ;;
    esac
  End

  committed() { jq -r .path "${SENT}"; }
  sent_sha() { jq -r .sha "${SENT}"; }
  sent_branch() { jq -r .branch "${SENT}"; }
  sent_message() { jq -r .message "${SENT}"; }
  sent_token() { jq -r .token "${SENT}"; }
  carry_their_files() {
    local bodies body path
    bodies="$(cat)"
    [[ -n ${bodies} ]] || return 1
    # A here-string, since ShellSpec drops the last line break, and read skips a line without one.
    while IFS= read -r body; do
      path="$(jq -r .path <<< "${body}")"
      jq -j '.content | @base64d' <<< "${body}" > "${SENT}.content"
      cmp -s "${SENT}.content" "${checkout}/${path}" || return 1
    done <<< "${bodies}"
  }

  It 'runs cider log with the type and the whole title'
    one_package
    expected="$(printf '%s\n' log added "${TITLE}")"
    When run script "${script}"
    The status should be success
    The output should include "${TITLE}"
    The contents of file "${ARGS}" should equal "${expected}"
  End

  It 'commits CHANGELOG.md as cider left it, to the branch it checked out'
    one_package
    When run script "${script}"
    The status should be success
    The output should be present
    The result of function committed should equal CHANGELOG.md
    The contents of file "${SENT}" should satisfy carry_their_files
    The result of function sent_branch should equal master
  End

  It 'commits over the blob it checked out, so GitHub refuses it if the file changed since'
    one_package
    blob="$(git rev-parse HEAD:CHANGELOG.md)"
    When run script "${script}"
    The status should be success
    The output should be present
    The result of function sent_sha should equal "${blob}"
  End

  It 'marks the commit so it starts no CI run'
    one_package
    When run script "${script}"
    The status should be success
    The output should be present
    The result of function sent_message should include '[skip ci]'
  End

  It "reads the PR with the job's token, and commits with the one the rulesets let past"
    one_package
    When run script "${script}"
    The status should be success
    The output should be present
    The contents of file "${READS}" should equal job-token
    The result of function sent_token should equal app-token
  End

  It 'writes the line into each package the PR changed, in a commit of its own'
    workspace .
    changed packages/a/lib/a.dart packages/c/README.md
    When run script "${script}"
    The status should be success
    The output should be present
    The result of function committed should equal \
      "$(printf '%s\n' packages/a/CHANGELOG.md packages/c/CHANGELOG.md)"
    The contents of file "${SENT}" should satisfy carry_their_files
  End

  It 'counts a file the PR moved for the package it left as well'
    workspace .
    export PAGES='[[{"filename": "packages/b/lib/a.dart", "previous_filename": "packages/a/lib/a.dart"}]]'
    When run script "${script}"
    The status should be success
    The output should be present
    The result of function committed should equal \
      "$(printf '%s\n' packages/a/CHANGELOG.md packages/b/CHANGELOG.md)"
  End

  It "counts the PR's files on every page of GitHub's answer"
    workspace .
    export PAGES='[[{"filename": "packages/a/lib/a.dart"}], [{"filename": "packages/c/lib/c.dart"}]]'
    When run script "${script}"
    The status should be success
    The output should be present
    The result of function committed should equal \
      "$(printf '%s\n' packages/a/CHANGELOG.md packages/c/CHANGELOG.md)"
  End

  It 'writes nothing when the PR changed no package that publishes'
    workspace .
    changed .github/workflows/ci.yml README.md
    When run script "${script}"
    The status should be success
    The error should include 'no package that publishes'
    The file "${ARGS}" should not be exist
    The contents of file "${SENT}" should equal ''
  End

  It "takes the self-test's stand-in files instead of asking the API"
    workspace .
    export NUMBER='' FILES=packages/b/lib/b.dart
    When run script "${script}"
    The status should be success
    The output should be present
    The result of function committed should equal packages/b/CHANGELOG.md
    The contents of file "${READS}" should equal ''
  End

  It "commits a member's CHANGELOG.md at its path in the repo, from a root in a subfolder"
    workspace fixtures/ws
    changed packages/b/lib/b.dart
    blob="$(git rev-parse HEAD:fixtures/ws/packages/b/CHANGELOG.md)"
    When run script "${script}"
    The status should be success
    The output should be present
    The result of function committed should equal fixtures/ws/packages/b/CHANGELOG.md
    The result of function sent_sha should equal "${blob}"
    The contents of file "${SENT}" should satisfy carry_their_files
  End

  It 'shows the line in a dry run, and commits nothing'
    one_package
    export DRY_RUN=true
    When run script "${script}"
    The status should be success
    The output should include "${TITLE}"
    The contents of file "${SENT}" should equal ''
  End

  It 'fails without committing when cider leaves CHANGELOG.md as it was'
    one_package
    Mock cider
      :
    End
    When run script "${script}"
    The status should be failure
    The error should include 'as it was'
    The contents of file "${SENT}" should equal ''
  End

  It 'commits nothing when cider fails in any package, even partway through'
    workspace .
    changed packages/a/lib/a.dart packages/b/lib/b.dart
    Mock cider
      echo '- half a line' >> CHANGELOG.md
      if [[ ${PWD} == */packages/b ]]; then
        echo 'FormatException: Invalid release header format: "1.0.0"' >&2
        exit 70
      fi
    End
    When run script "${script}"
    The status should be failure
    The output should be present
    The error should include 'FormatException'
    The contents of file "${SENT}" should equal ''
  End

  It "fails without writing a line when the PR's files can't be read"
    one_package
    Mock gh
      echo 'gh: Not Found (HTTP 404)' >&2
      (exit 1)
    End
    When run script "${script}"
    The status should be failure
    The error should include 'Not Found'
    The file "${ARGS}" should not be exist
  End

  It "fails without writing a line when pub can't list the packages"
    one_package
    pub_fails 'Error on line 1 of pubspec.yaml'
    When run script "${script}"
    The status should be failure
    The error should include 'Error on line 1'
    The file "${ARGS}" should not be exist
  End

  It 'says to re-run the job when GitHub refuses the commit'
    one_package
    export REFUSE='gh: CHANGELOG.md does not match 5626abf (HTTP 409)'
    When run script "${script}"
    The status should be failure
    The output should be present
    The error should include 're-run'
  End
End
