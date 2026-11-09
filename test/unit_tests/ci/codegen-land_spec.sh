# shellcheck shell=bash
# shellcheck disable=SC2154  # ShellSpec sets the SHELLSPEC_* variables

Describe 'ci/codegen-land.sh'
  script="${SHELLSPEC_PROJECT_ROOT}/scripts/ci/codegen-land.sh"

  setup() {
    local dir
    dir="$(mktemp -d "${SHELLSPEC_TMPBASE}/land.XXXXXX")"
    remote="${dir}/remote.git"
    checkout="${dir}/checkout"
    export PR="${dir}/pr"
    : > "${PR}"
    git init -q --bare "${remote}"
    git init -q -b main "${checkout}"
    git -C "${checkout}" remote add origin "${remote}"
    printf 'first\n' > "${checkout}/README.md"
    git -C "${checkout}" add README.md
    git -C "${checkout}" -c user.name=spec -c user.email=spec@example.com commit -qm First
    git -C "${checkout}" push -q origin main
    cd "${checkout}" || return
    export MODE=repair BRANCH=main BUMP_BRANCH=codegen/generator-bumps REPO=owner/repo \
      MARKER='Codegen regen' AUTHOR_NAME='app[bot]' AUTHOR_EMAIL='app[bot]@example.com' \
      GH_TOKEN=app-token DRY_RUN=false OPEN=0
  }
  BeforeEach 'setup'

  Mock gh
    case "$*" in
      'pr list --repo owner/repo --head codegen/generator-bumps '*)
        echo "${OPEN}"
        ;;
      'pr create '*)
        echo "$*" >> "${PR}"
        echo https://github.com/owner/repo/pull/1
        ;;
      *)
        echo "unexpected call: gh $*" >&2
        exit 9
        ;;
    esac
  End

  drifted() { printf 'regenerated\n' > generated.g.dart; }
  tip() { git -C "${remote}" log -1 --format="$2" "refs/heads/$1" 2>/dev/null; }
  subject() { tip main %s; }
  author() { tip main '%an <%ae>'; }
  bump_subject() { tip codegen/generator-bumps %s; }
  pr_branch_subject() { tip dependabot/pub/pigeon %s; }
  opened() { cat "${PR}"; }

  It 'lands nothing when the generators changed nothing'
    When run script "${script}"
    The status should be success
    The output should include 'nothing to land'
    The result of function opened should be blank
  End

  It 'pushes the regen onto the branch it came from'
    drifted
    When run script "${script}"
    The status should be success
    The output should include 'Pushed the regen onto main.'
    The result of function subject should equal 'Codegen regen'
    The result of function author should equal 'app[bot] <app[bot]@example.com>'
  End

  It "pushes onto the PR's own branch, not the default one"
    drifted
    export BRANCH=dependabot/pub/pigeon
    When run script "${script}"
    The status should be success
    The output should include 'dependabot/pub/pigeon'
    The result of function pr_branch_subject should equal 'Codegen regen'
    The result of function subject should equal 'First'
  End

  It 'leaves a marker in the commit, so the run it starts is skipped instead of looping'
    drifted
    When run script "${script}"
    The status should be success
    The result of function subject should include "${MARKER}"
  End

  It 'lets the checks run again, unlike the changelog, so the commit asks for no skip'
    drifted
    When run script "${script}"
    The status should be success
    The result of function subject should not include 'skip ci'
  End

  It 'shows what would land on a dry run and pushes none of it'
    drifted
    export DRY_RUN=true
    When run script "${script}"
    The status should be success
    The output should include 'generated.g.dart'
    The output should include 'nothing gets pushed'
    # Still the first commit, so nothing landed.
    The result of function subject should equal 'First'
  End

  Describe 'the weekly bump'
    bumping() { export MODE=bump; drifted; }

    It 'pushes to its own branch and opens a PR onto the default one'
      bumping
      When run script "${script}"
      The status should be success
      The output should be present
      The result of function bump_subject should equal 'Codegen regen'
      The result of function opened should include '--base main --head codegen/generator-bumps'
    End

    It 'leaves the branch it targets alone'
      bumping
      When run script "${script}"
      The status should be success
      The output should be present
      The result of function subject should equal 'First'
    End

    It 'adds no second PR when last week is still open'
      bumping
      export OPEN=1
      When run script "${script}"
      The status should be success
      The output should include 'already open'
      The result of function opened should be blank
    End
  End
End
