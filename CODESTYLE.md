Style for the shell in `scripts/` and `test/`, the CI YAML, and the prose. The checks enforce most
of it, so this is mostly the part they can't see.

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
- **Fixtures come from the tool that makes real packages** (`flutter create`, `dart create`), and
  change only where a job needs it, so CI gets tested on what a package repo actually has.

## CI YAML

- **One command per step, no `run: |` blocks,** so a run reads step by step in the log.
- **Write out every input we rely on, defaults included,** so a new major that changes a default
  can't quietly change what runs. The input check catches one that got renamed.

## Comments

- **Why, not what.** The line underneath already says what it does.
- **At the call site, one or two lines.** Anything longer is rationale and belongs in prose.
- **Delete by default.** Keep a comment only if a reader would get something wrong without it.

## Prose

Comments, READMEs, docs, commit and PR text. The voice reference is <https://noslopgrenade.com/>.

- **Answer first, then stop.** Keep it informal and plain, no buzzwords.
- **Tables, lists and `<details>` where they fit.** They should cut the word count, not add to it.
- **Point at the source instead of copying a value** that a file or command already holds.
