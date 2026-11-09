# shellcheck shell=bash
# shellcheck disable=SC2154  # ShellSpec sets the SHELLSPEC_* variables

Describe 'ci/codegen-plan.sh'
  script="${SHELLSPEC_PROJECT_ROOT}/scripts/ci/codegen-plan.sh"

  setup() {
    export EVENT=workflow_run REPO=owner/repo RUN_ID=7 DEFAULT_BRANCH=main \
      MARKER='Codegen regen' GH_TOKEN=job-token
    # What the run looks like unless an example says otherwise.
    export CONCLUSION=failure HEAD_REPO=owner/repo MESSAGE='build(deps): bump pigeon' \
      HEAD_BRANCH=dependabot/pub/pigeon JOBS='ci / Codegen:failure'
  }
  BeforeEach 'setup'

  Mock gh
    case "$*" in
      'api repos/owner/repo/actions/runs/7')
        jq -n --arg c "${CONCLUSION}" --arg r "${HEAD_REPO}" --arg m "${MESSAGE}" \
          --arg b "${HEAD_BRANCH}" '{conclusion: $c, head_branch: $b,
            head_repository: {full_name: $r}, head_commit: {message: $m}}'
        ;;
      'api --paginate repos/owner/repo/actions/runs/7/jobs')
        jq -n --arg jobs "${JOBS}" '{jobs: [$jobs | split(" ")[] | select(. != "")
          | split(":") | {name: (.[0] | gsub("_"; " ")), conclusion: .[1]}]}'
        ;;
      *)
        echo "unexpected call: gh $*" >&2
        exit 9
        ;;
    esac
  End

  It 'repairs the branch a failed Codegen job ran on'
    When run script "${script}"
    The status should be success
    The line 1 of output should equal 'go=true'
    The line 2 of output should equal 'mode=repair'
    The line 3 of output should equal 'branch=dependabot/pub/pigeon'
  End

  It 'takes the weekly run as a bump off the default branch, without looking at any run'
    export EVENT=schedule RUN_ID=''
    When run script "${script}"
    The status should be success
    The line 1 of output should equal 'go=true'
    The line 2 of output should equal 'mode=bump'
    The line 3 of output should equal 'branch=main'
  End

  It 'treats a manual run as a bump too'
    export EVENT=workflow_dispatch RUN_ID=''
    When run script "${script}"
    The status should be success
    The line 2 of output should equal 'mode=bump'
  End

  It 'stays out of a run that passed'
    export CONCLUSION=success
    When run script "${script}"
    The status should be success
    The output should equal 'go=false'
    The stderr should include 'nothing to repair'
  End

  It "stays out of a fork's branch, which this installation cannot push to"
    export HEAD_REPO=someone/repo
    When run script "${script}"
    The status should be success
    The output should equal 'go=false'
    The stderr should include 'fork'
  End

  It 'stays out of its own commit, which would otherwise loop'
    export MESSAGE='Codegen regen'
    When run script "${script}"
    The status should be success
    The output should equal 'go=false'
    The stderr should include 'loop'
  End

  Describe 'a run where Codegen is not what failed'
    Parameters
      'another job failed' 'ci_/_Analyze:failure ci_/_Codegen:success'
      'Codegen was skipped' 'ci_/_Codegen:skipped'
      'nothing failed at all' 'ci_/_Codegen:success'
    End

    It "stays out when $1"
      export JOBS="$2"
      When run script "${script}"
      The status should be success
      The output should equal 'go=false'
      The stderr should include 'other than Codegen'
    End
  End

  Describe 'the job name the caller gives it'
    Parameters
      'a package repo' 'ci_/_Codegen:failure'
      "dartender's own fixtures" 'fixtures_(dart_package)_/_Codegen:failure'
      'a workflow that calls it directly' 'Codegen:failure'
    End

    It "finds the failed job in $1"
      export JOBS="$2"
      When run script "${script}"
      The status should be success
      The line 2 of output should equal 'mode=repair'
    End
  End

  It 'is not fooled by a job whose name merely ends in Codegen'
    export JOBS='ci_/_Recodegen:failure'
    When run script "${script}"
    The status should be success
    The output should equal 'go=false'
    The stderr should include 'other than Codegen'
  End
End
