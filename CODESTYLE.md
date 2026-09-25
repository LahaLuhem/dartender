Style for the shell in `scripts/` and `test/`, the CI YAML, and the prose. The checks enforce most
of it, so this is mostly the part they can't see.

## Shell

- **ShellCheck runs with every optional check on.** [`.shellcheckrc`](.shellcheckrc) is the only
  place its rules get configured. Fix a finding before reaching for a disable, and give any disable
  its reason on the same line.
- **Anything with a branch or a loop goes in a script,** never a `run:` block, so it can have a
  spec.

## Specs

[ShellSpec](https://shellspec.info), one `*_spec.sh` per script. `test/` splits by kind of test
first, so specs live in `test/unit_tests/`, in the same spot as the script has under `scripts/`.

- **Specs start with `# shellcheck shell=bash`,** since they have no shebang. ShellCheck can't see
  that ShellSpec sets its `SHELLSPEC_*` variables, so a spec using them disables SC2154 on line 2.
- **A spec that can't fail isn't a spec.** Break the code it covers and watch it go red before
  trusting it.
- **Each `Parameters` block gets a `Describe` of its own.** Blocks in one group pile their rows up,
  and nested groups inherit them.

## CI YAML

- **One command per step, no `run: |` blocks,** so a run reads step by step in the log.

## Comments

- **Why, not what.** The line underneath already says what it does.
- **At the call site, one or two lines.** Anything longer is rationale and belongs in prose.
- **Delete by default.** Keep a comment only if a reader would get something wrong without it.

## Prose

Comments, READMEs, docs, commit and PR text. The voice reference is <https://noslopgrenade.com/>.

- **Answer first, then stop.** Keep it informal and plain, no buzzwords.
- **Tables, lists and `<details>` where they fit.** They should cut the word count, not add to it.
- **Point at the source instead of copying a value** that a file or command already holds.
