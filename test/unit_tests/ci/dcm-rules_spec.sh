# shellcheck shell=bash
# shellcheck disable=SC2154  # ShellSpec sets the SHELLSPEC_* variables

Describe 'ci/dcm-rules.sh'
  script="${SHELLSPEC_PROJECT_ROOT}/scripts/ci/dcm-rules.sh"

  setup() {
    dir="$(mktemp -d "${SHELLSPEC_TMPBASE}/dcm.XXXXXX")"
    options="${dir}/analysis_options.yaml"
    export PAGE='<script src="/assets/js/runtime~main.23aad84a.js" defer="defer"></script>'
    export RUNTIME='({17896441:"50b95980",72076:"common"}[e]||e)+"."
      +{17896441:"4c5d6e7f",72076:"f2a8759d"}[e]+".js"'
    # As dcm.dev ships it: free and paid Dart rules, a Flutter one described in markup, and a package's.
    export BUNDLE='(self.webpackChunk=self.webpackChunk||[]).push([["common"],{1(e,s,n){const t={
      common:{name:"Common",type:"common",rules:{
        "avoid-dynamic":{name:"avoid-dynamic",plans:["free","starter","pro"]},
        "no-empty-block":{name:"no-empty-block",plans:["free","starter","pro"]},
        "avoid-explicit-type-declaration":{name:"avoid-explicit-type-declaration",plans:["pro"]}}},
      flutter:{name:"Flutter",type:"flutter",rules:{
        "avoid-border-all":{name:"avoid-border-all",
          description:(0,r.jsxs)(r.Fragment,{children:["Use ",(0,r.jsx)("code",{children:"x"})]}),
          plans:["free","pro"]}}},
      bloc:{name:"Bloc",type:"bloc",link:"https://pub.dev/packages/bloc",rules:{
        "avoid-cubits":{name:"avoid-cubits",plans:["free","pro"]}}}}}}]);'
    decides avoid-dynamic no-empty-block avoid-border-all
  }
  BeforeEach 'setup'

  # Writes the options file with each named rule turned on.
  decides() {
    printf 'dart_code_metrics:\n  rules:\n' > "${options}"
    for rule; do printf '    - %s\n' "${rule}" >> "${options}"; done
  }

  Mock curl
    while [[ $# -gt 1 ]]; do
      if [[ $1 == --output ]]; then out="$2"; fi
      shift
    done
    case "$1" in
      */docs/rules/) printf '%s\n' "${PAGE}" ;;
      */assets/js/runtime~main.23aad84a.js) printf '%s\n' "${RUNTIME}" ;;
      */assets/js/common.f2a8759d.js) printf '%s\n' "${BUNDLE}" ;;
      *)
        echo "curl: (22) The requested URL returned error: 404" >&2
        exit 22
        ;;
    esac > "${out}"
  End

  It 'passes when the file decides every free Dart and Flutter rule, paid and package ones left out'
    When run script "${script}" "${options}"
    The status should be success
    The output should be present
  End

  It 'counts a rule turned off as decided'
    decides avoid-dynamic avoid-border-all
    printf '    - no-empty-block: false\n' >> "${options}"
    When run script "${script}" "${options}"
    The status should be success
    The output should be present
  End

  It "fails naming each free Dart and Flutter rule the file doesn't decide"
    decides avoid-dynamic
    When run script "${script}" "${options}"
    The status should be failure
    The error should include 'no-empty-block'
    The error should include 'avoid-border-all'
  End

  Describe "fails loudly when dcm.dev's layout changes"
    Parameters
      'the page names no runtime script' PAGE '<html></html>'
      'the runtime names no common bundle' RUNTIME '{17896441:"50b95980"}[e]'
      'the runtime has no hash for it' RUNTIME '{72076:"common"}[e]'
      'the bundle has no free rule' BUNDLE 'const t={common:{type:"common",rules:{}}};'
    End

    It "fails when $1"
      export "$2=$3"
      When run script "${script}" "${options}"
      The status should be failure
      The error should include 'layout has likely changed'
    End
  End
End
