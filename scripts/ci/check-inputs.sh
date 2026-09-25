#!/usr/bin/env bash
# Fails on any `with:` key that the action or reusable workflow behind `uses:` doesn't declare. The
# runner only warns about those, so a renamed input would quietly fall back to its default.
set -euo pipefail
shopt -s nullglob
cd "${1:-.}"

cache="$(mktemp -d)"
trap 'rm -rf "${cache}"' EXIT

# Prints what `uses` $1 points at, a reusable workflow or an action's metadata, or nothing when
# that can't be read.
metadata() {
  local uses="$1" repo="" ref="" path candidate content
  case "${uses}" in
    # `$/` means this repo at the running commit, which is the checkout here.
    ./* | '$/'*)
      path="${uses#./}"
      path="${path#\$/}"
      ;;
    *)
      # owner/repo[/path]@ref
      [[ "${uses}" =~ ^([^/]+/[^/@]+)/?([^@]*)@(.+)$ ]] || return 0
      repo="${BASH_REMATCH[1]}"
      path="${BASH_REMATCH[2]}"
      ref="${BASH_REMATCH[3]}"
      ;;
  esac

  local candidates=("${path}")
  # Some actions ship action.yaml instead of action.yml, bats-core/bats-action for one.
  if [[ "${path}" != *.yml && "${path}" != *.yaml ]]; then
    candidates=("${path:+${path}/}action.yml" "${path:+${path}/}action.yaml")
  fi
  for candidate in "${candidates[@]}"; do
    if [[ -z "${repo}" ]]; then
      if [[ -f "${candidate}" ]]; then
        cat "${candidate}"
        return
      fi
    # gh prints the error body to stdout on a 404, so only a success gets passed on.
    elif content="$(gh api -H 'Accept: application/vnd.github.raw+json' \
      "repos/${repo}/contents/${candidate}?ref=${ref}" 2>/dev/null)"; then
      printf '%s\n' "${content}"
      return
    fi
  done
}

# yq still emits an empty object when nothing matched, hence the last select.
query='.. | select(tag == "!!map" and has("uses") and has("with"))
  | {"uses": .uses, "keys": [(.with // {}) | keys | .[] | {"key": ., "line": line}]}
  | select(has("uses"))'

failed=0
checked=0
declare -A known
for file in .github/workflows/*.{yml,yaml} .github/actions/*/action.{yml,yaml} \
  actions/*/action.{yml,yaml}; do
  calls="$(yq -o=json -I=0 "${query}" "${file}")"
  while IFS= read -r call; do
    [[ -n "${call}" ]] || continue
    uses="$(jq -r .uses <<< "${call}")"
    # Nothing to look up for container images or refs built at run time.
    if [[ "${uses}" == docker://* || "${uses}" == *"\${{"* ]]; then continue; fi
    checked=$((checked + 1))

    meta="${cache}/${uses//[^A-Za-z0-9._-]/_}"
    if [[ ! -e "${meta}" ]]; then metadata "${uses}" > "${meta}"; fi
    if [[ ! -s "${meta}" ]]; then
      echo "::error file=${file}::Couldn't read what ${uses} accepts."
      failed=1
      continue
    fi

    names="$(yq '(.inputs // .on.workflow_call.inputs // {}) | keys | .[]' "${meta}")"
    using="$(yq '.runs.using // ""' "${meta}")"
    accepted=()
    if [[ -n "${names}" ]]; then mapfile -t accepted <<< "${names}"; fi
    # Container actions take these two without declaring them.
    if [[ "${using}" == docker ]]; then accepted+=(args entrypoint); fi
    known=()
    for name in "${accepted[@]}"; do known["${name}"]=1; done
    printf -v takes '%s, ' "${accepted[@]}"
    takes="${takes%, }"

    keys="$(jq -r '.keys[] | [.key, .line] | @tsv' <<< "${call}")"
    while IFS=$'\t' read -r key line; do
      if [[ -z "${known[${key}]:-}" ]]; then
        echo "::error file=${file},line=${line}::\"${key}\" isn't an input of ${uses}." \
          "It takes: ${takes:-nothing}."
        failed=1
      fi
    done <<< "${keys}"
  done <<< "${calls}"
done

echo "Calls checked: ${checked}."
exit "${failed}"
