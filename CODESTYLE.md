Style for the shell in `scripts/` and `test/`, the CI YAML, the brick templates, and the prose. The
checks enforce most of it, so this is mostly the part they can't see.

## Shell

- **ShellCheck runs with every optional check on.** [`.shellcheckrc`](.shellcheckrc) is the only
  place its rules get configured. Fix a finding before reaching for a disable, and give any disable
  its reason on the same line.
- **Anything with a branch or a loop goes in a script,** never a `run:` block, so it can have a
  spec.
- **Bash 5, with no workarounds for macOS's 3.2.** CI and the spec image run 5, and
  [`scripts/setup/common.sh`](scripts/setup/common.sh) stops anything older on a laptop.
- **Setup scripts talk through `common.sh`'s `info`, `success` and `error`,** so they all read the
  same and their errors land on stderr.
- **Setup scripts leave alone what's already set, and say so,** so running them again is always
  safe.

## Specs

[ShellSpec](https://shellspec.info), one `*_spec.sh` per script. `test/` splits by kind of test
first, so specs live in `test/unit_tests/`, in the same spot as the script has under `scripts/`.
The packages the self-test runs `ci.yml` against live in `test/workflow_tests/`, each laid out like
a real package repo.

- **Specs start with `# shellcheck shell=bash`,** since they have no shebang. ShellCheck can't see
  that ShellSpec sets its `SHELLSPEC_*` variables, so a spec using them disables SC2154 on line 2.
- **A spec that can't fail isn't a spec.** Break the code it covers and watch it go red before
  trusting it.
- **Each `Parameters` block gets a `Describe` of its own.** Blocks in one group pile their rows up,
  and nested groups inherit them.
- **A setup script's spec covers each thing it sets three ways:** missing, different, and already
  set. The last one catches a write that didn't need to happen.
- **Fixtures come from the tool that makes real packages** (`flutter create`, `dart create`,
  `uv init`), and change only where a job needs it, so CI gets tested on what a package repo has.
  That includes the [shared lints](README.md#the-analyzer), taken by path so a PR's run analyzes
  with its own version, and `dart fix` for what they flag.

## CI YAML

- **One command per step, no `run: |` blocks,** so a run reads step by step in the log.
- **Write out every input we rely on, defaults included,** so a new major that changes a default
  can't quietly change what runs. The input check catches one that got renamed.

## Brick templates

The callers in [`bricks/callers/`](bricks/callers/), which [mason](https://github.com/felangel/mason)
fills in.

- **`{{{ }}}` for strings.** `{{ }}` escapes them for HTML, so `lib/a` would come out as
  `lib&#x2F;a`.
- **A template that needs `${{ }}` switches its tags.** mason takes `${{ github.ref }}` for one of
  its own and leaves only `$`. So `{{=<% %>=}}` goes at the end of the header line, where it leaves
  no trace, and strings become `<%&name%>`, like in the changelog caller.
- **A template that switches needs a `${{ }}` without `=`, `,` or `;` in it.** mason only renders
  a file holding a tag like that, and the switch has an `=`, so without one the file gets copied
  as it is, `<% %>` tags and all.
- **An optional block gets a boolean of its own, with its tags inline.** A section renders for any
  string, the empty one too, and a line holding only a tag comes out blank instead of going away.
- **A list goes in as a JSON array, and comes out one item per line.** mason takes
  `--packages '["a","b"]'` as a list, and anything else as one item, a comma-separated string too.
  A `[a, b]` flow list of a workspace's packages can run past ryl's line length.
- **`callers.sh` passes every variable.** mason asks for a missing one, which fails without a
  terminal, and it doesn't check a value against its type.

## Comments

- **Why, not what.** The line underneath already says what it does.
- **At the call site, one or two lines.** Anything longer is rationale and belongs in prose.
- **Delete by default.** Keep a comment only if a reader would get something wrong without it.

## Prose

Comments, READMEs, docs, commit and PR text. The voice reference is <https://noslopgrenade.com/>.

- **Answer first, then stop.** Keep it informal and plain, no buzzwords.
- **Tables, lists and `<details>` where they fit.** They should cut the word count, not add to it.
- **Point at the source instead of copying a value** that a file or command already holds.
