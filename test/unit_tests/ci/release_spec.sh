# shellcheck shell=bash
# shellcheck disable=SC2154  # ShellSpec sets the SHELLSPEC_* variables

Describe 'ci/release.sh'
  script="${SHELLSPEC_PROJECT_ROOT}/scripts/ci/release.sh"

  setup() {
    root="$(mktemp -d "${SHELLSPEC_TMPBASE}/repo.XXXXXX")"
    # Not pub_lists, which would put its dart ahead of the mock below that hands it the listing.
    export ROOT="${root}" ORIGIN="${root}.origin" CALLS="${root}.calls" \
      LISTER="${SHELLSPEC_PROJECT_ROOT}/test/utils/pub/dart" LISTED='' PUB_FAILS='' \
      BUMP=minor PACKAGE='' REPO=owner/repo BRANCH=main REF=refs/heads/main DRY_RUN=false \
      TITLES='' PUSH_TOKEN=app-token GH_TOKEN=job-token ACTOR=a-person ACTOR_ID=7 NEXT=1.1.0 \
      PUBLISH_RC=0 GITHUB_STEP_SUMMARY="${root}.summary"
    : > "${CALLS}"
    : > "${GITHUB_STEP_SUMMARY}"
    git init -q -b main "${root}"
    cd "${root}" || return
  }
  BeforeEach 'setup'

  # Writes folder $1's package $2 at 1.0.0, with the notes in $3 waiting and the lines in $4 after
  # its version. Unreleased goes last, where the cider stand-in adds its lines.
  package() {
    mkdir -p "$1"
    printf 'name: %s\nversion: 1.0.0\n%s' "$2" "${4-}" > "$1/pubspec.yaml"
    printf '## 1.0.0 - 2026-09-01\n- First.\n\n## Unreleased\n%s' "${3-}" > "$1/CHANGELOG.md"
  }

  commit() {
    git add -A
    git -c user.name=spec -c user.email=spec@example.com commit -q -m "$1"
  }

  # Commits it all as the last release, tagged $1 unless that's empty, and pushes main to origin.
  released() {
    commit 'Last release'
    last="$(git rev-parse HEAD)"
    if [[ -n $1 ]]; then git tag "$1"; fi
    git init -q --bare -b main "${ORIGIN}"
    git remote add origin "${ORIGIN}"
    git push -q origin main
  }

  # Nothing if the run made no commit. Otherwise main, if origin's main is that commit, then
  # origin's tags on it.
  pushed() {
    local theirs ours
    theirs="$(git -C "${ORIGIN}" rev-parse main)"
    ours="$(git rev-parse HEAD)"
    if [[ ${ours} == "${last}" ]]; then return; fi
    if [[ ${theirs} == "${ours}" ]]; then echo main; fi
    git -C "${ORIGIN}" tag --points-at "${ours}"
  }

  author() { git log -1 --format='%an <%ae>'; }
  committed() { git show --name-only --format= HEAD; }
  cider_calls() { grep ': cider ' "${CALLS}"; }

  Mock cider
    dir="${PWD#"${ROOT}"}" dir="${dir#/}" dir="${dir:-.}"
    echo "${dir}: cider $*" >> "${CALLS}"
    case "$1" in
      log) printf -- '- %s\n' "$3" >> CHANGELOG.md ;;
      describe) awk 'unreleased && /^- /; /^## Unreleased$/ {unreleased = 1}' CHANGELOG.md ;;
      bump) sed -i "s/^version: .*/version: ${NEXT}/" pubspec.yaml ;;
      release) sed -i "s/^## Unreleased$/## ${NEXT} - 2026-10-03/" CHANGELOG.md ;;
      *) exit 64 ;;
    esac
  End

  # Like pub, the dry run refuses a tree with changes nobody committed.
  Mock dart
    if [[ $* != 'pub publish --dry-run' ]]; then exec "${LISTER}" "$@"; fi
    dir="${PWD#"${ROOT}"}" dir="${dir#/}" dir="${dir:-.}"
    echo "${dir}: dart $*" >> "${CALLS}"
    changes="$(git status --porcelain --untracked-files=no)"
    if [[ -n ${changes} ]]; then exit 65; fi
    (exit "${PUBLISH_RC}")
  End

  Mock flutter
    dir="${PWD#"${ROOT}"}" dir="${dir#/}" dir="${dir:-.}"
    echo "${dir}: flutter $*" >> "${CALLS}"
    sed -i "s/^    version: .*/    version: \"${NEXT}\"/" pubspec.lock
  End

  # gh api repos/owner/repo/commits/<sha>/pulls --jq <filter>, with a Dependabot PR every time.
  Mock gh
    jq -r "$4" <<< '[{"number": 9, "title": "Bump http to 2", "user": {"login": "dependabot[bot]"}}]'
  End

  It "releases a repo's only package as whoever started the run, pushing commit and tag together"
    package . p $'- A fix.\n'
    export LISTED=p:.
    released 1.0.0
    When run script "${script}"
    The status should be success
    The output should be present
    The result of function pushed should equal $'main\n1.1.0'
    The result of function author should equal 'a-person <7+a-person@users.noreply.github.com>'
    The contents of file "${GITHUB_STEP_SUMMARY}" should include '- A fix.'
  End

  It "tags a workspace member's release with its name"
    package . w '' $'publish_to: none\n'
    package packages/a a
    package packages/b b $'- A fix.\n'
    export LISTED='w:. a:packages/a b:packages/b' PACKAGE=b
    released b-1.0.0
    When run script "${script}"
    The status should be success
    The output should be present
    The result of function pushed should equal $'main\nb-1.1.0'
    The contents of file "${CALLS}" should include 'packages/b: cider release'
  End

  It "adds a line under Changed for each Dependabot title, then bumps the part picked and dates the notes"
    package . p
    export LISTED=p:. TITLES=$'Bump http to 2\nBump meta to 2'
    released 1.0.0
    When run script "${script}"
    The status should be success
    The output should be present
    The result of function cider_calls should equal \
      $'.: cider log changed Bump http to 2\n.: cider log changed Bump meta to 2\n.: cider describe --only-body\n.: cider bump minor\n.: cider release'
  End

  It "finds Dependabot's PRs from the tag of the current version"
    package . p '' $'dependencies:\n  http: ^1.0.0\n'
    export LISTED=p:.
    released 1.0.0
    sed -i 's/\^1.0.0/^2.0.0/' pubspec.yaml
    commit 'Bump http to 2'
    git push -q origin main
    When run script "${script}"
    The status should be success
    The output should be present
    The error should include '#9'
    The contents of file "${CALLS}" should include '.: cider log changed Bump http to 2'
  End

  It "fails when the current version has no tag, rather than guess where the last release was"
    package . p $'- A fix.\n'
    export LISTED=p:.
    released ''
    When run script "${script}"
    The status should be failure
    The error should include 'tag'
    The contents of file "${CALLS}" should not include 'bump'
    The result of function pushed should be blank
  End

  It "fails when there's nothing to release"
    package . p
    export LISTED=p:.
    released 1.0.0
    When run script "${script}"
    The status should be failure
    The error should be present
    The contents of file "${CALLS}" should not include 'bump'
    The result of function pushed should be blank
  End

  It "raises dependents' bounds in the same commit"
    package . w '' $'publish_to: none\n'
    package packages/a a '' $'dependencies:\n  b: ^1.0.0\n'
    package packages/b b $'- A fix.\n'
    export LISTED='w:. a:packages/a b:packages/b' PACKAGE=b
    released b-1.0.0
    When run script "${script}"
    The status should be success
    The output should be present
    The result of function committed should include 'packages/a/pubspec.yaml'
    The result of function pushed should equal $'main\nb-1.1.0'
  End

  It "resyncs a tracked example lockfile, which pins the package's version, in the same commit"
    package . p $'- A fix.\n'
    mkdir example
    printf 'packages:\n  p:\n    source: path\n    version: "1.0.0"\n' > example/pubspec.lock
    export LISTED=p:.
    released 1.0.0
    When run script "${script}"
    The status should be success
    The output should be present
    The contents of file "${CALLS}" should include 'example: flutter pub get'
    The result of function committed should include 'example/pubspec.lock'
  End

  It 'pushes nothing when the publish dry run fails'
    package . p $'- A fix.\n'
    export LISTED=p:. PUBLISH_RC=65
    released 1.0.0
    When run script "${script}"
    The status should be failure
    The output should be present
    The result of function pushed should be blank
  End

  It 'pushes nothing on a dry run, which can start on any branch and puts the notes in the summary'
    package . p $'- A fix.\n'
    export LISTED=p:. DRY_RUN=true REF=refs/pull/3/merge
    released 1.0.0
    When run script "${script}"
    The status should be success
    The output should be present
    The result of function pushed should be blank
    The contents of file "${GITHUB_STEP_SUMMARY}" should include '- A fix.'
  End

  It 'refuses a real release started on another branch, before changing anything'
    package . p $'- A fix.\n'
    export LISTED=p:. REF=refs/heads/feature
    released 1.0.0
    When run script "${script}"
    The status should be failure
    The error should include 'feature'
    The contents of file "${CALLS}" should equal ''
  End

  It 'pushes neither commit nor tag when the branch moved during the run'
    package . p $'- A fix.\n'
    export LISTED=p:.
    released 1.0.0
    git clone -q "${ORIGIN}" "${ROOT}.other"
    git -C "${ROOT}.other" -c user.name=spec -c user.email=spec@example.com commit -q --allow-empty \
      -m 'Merged meanwhile'
    git -C "${ROOT}.other" push -q origin main
    When run script "${script}"
    The status should be failure
    The output should be present
    The error should include 'again'
    The result of function pushed should be blank
  End
End
