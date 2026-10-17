#!/usr/bin/env bash
set -euo pipefail
options="$1"

# The only list of which plan has which rule, kept in a bundle whose name changes with each deploy.
site=https://dcm.dev
dir="$(mktemp -d)"
trap 'rm -rf "${dir}"' EXIT
fetch() {
  curl --fail --silent --show-error --location --output "${dir}/$2" "${site}$1"
}
need() {
  if [[ -z $1 ]]; then
    echo "::error::$2, so its layout has likely changed." >&2
    exit 1
  fi
}

fetch /docs/rules/ rules.html
runtime="$(grep -o -E '/assets/js/runtime~main\.[0-9a-f]+\.js' "${dir}/rules.html" \
  | head -n 1 || true)"
need "${runtime}" "dcm.dev's rules page names no runtime script"
fetch "${runtime}" runtime.js
# The runtime maps a bundle's id to its name, and the same id to its hash.
id="$(grep -o -E '[0-9]+:"common"' "${dir}/runtime.js" | head -n 1 | cut -d: -f1 || true)"
need "${id}" "dcm.dev's runtime names no common bundle"
hash="$(grep -o -E "(^|[^0-9])${id}:\"[0-9a-f]+\"" "${dir}/runtime.js" | head -n 1 | cut -d'"' -f2 \
  || true)"
need "${hash}" "dcm.dev's runtime has no hash for its common bundle"
fetch "/assets/js/common.${hash}.js" bundle.js

# acorn parses the bundle without running it.
# shellcheck disable=SC2016  # a jq program, whose $name is a jq variable
free="$(acorn --ecma2025 --compact "${dir}/bundle.js" | jq -r '
  def prop($name): .properties[] | select(.key.name == $name or .key.value == $name) | .value;
  .. | objects | select(.type == "ObjectExpression")
  | select(any(.properties[]; .key.name == "type") and any(.properties[]; .key.name == "rules"))
  | select(prop("type").value | IN("common", "flutter"))
  | prop("rules").properties[] | select(.value.type == "ObjectExpression")
  | select(.value | [prop("plans").elements[].value] | index("free")) | .key.value // .key.name')"
need "${free}" "dcm.dev's rules data has no free Dart or Flutter rule"
# Brackets around the two branches, since yq, unlike jq, would run the second on the whole file.
decided="$(yq -o=json -I=0 '[.dart_code_metrics.rules // [] | .[]
  | (select(tag == "!!str"), (select(tag == "!!map") | keys | .[]))]' "${options}")"

# shellcheck disable=SC2016  # a jq program, whose $name is a jq variable
undecided="$(jq -r -R --argjson decided "${decided}" \
  'select(. as $name | $decided | any(. == $name) | not)' <<< "${free}")"
if [[ -n ${undecided} ]]; then
  while IFS= read -r name; do
    echo "::error::DCM has the free rule ${name}, which ${options} neither turns on nor off." >&2
  done <<< "${undecided}"
  exit 1
fi
echo "${options} decides every free Dart and Flutter rule DCM has."
