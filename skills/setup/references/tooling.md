# Module: Install Missing Tools

Purpose: Install tools that Phase 1 marked as `missing`. Skip `ready` and `broken`.

## Process

### 1. Iterate Missing Tools

- Work only from the Phase 1 detection results.
- For each tool marked `missing`, look up its install command in [toolchain-matrix.md](toolchain-matrix.md).
- Use the project's package manager or build tool. Never install globally. Never use `sudo`.
- Run the install command, then verify the tool with `--version` or the tool-specific verification command from the matrix.
- If install or verification fails:
  - report the error to the user
  - do not retry with `sudo`
  - skip that tool and continue with the next one
  - include the failure in the completion summary
- Skip tools already marked `ready`.
- Skip tools marked `broken`; those need manual repair, not automatic install.

### 2. Record newly installed tools

After successful installs, record the newly available tools and their
commands in working memory for the completion summary.

### 3. Update .gitignore (tool artifacts only)

Add gitignore entries for newly installed tools only (e.g., `.ruff_cache/`
if ruff was installed). The comprehensive .gitignore generation happens
later in Phase 7 Step D — do not duplicate that work here.

- Only add entries that are not already present.
- Only add entries specific to tools installed in this step.

### 4. Commit

- Commit with a conventional commit message:

```text
feat(tooling): install <list of tools>
```

## Install Commands

Use the project package manager that matches the detected repo.

| Package manager / tool | Install dev dependency |
|---|---|
| npm | `npm install -D <pkg>` |
| yarn | `yarn add -D <pkg>` |
| pnpm | `pnpm add -D <pkg>` |
| pip | `pip install <pkg>` |
| uv | `uv add --dev <pkg>` |
| go | `go install <module>@latest` |
| composer | `composer require --dev <pkg>` |
| bundle | `bundle add <gem> --group development` |
| brew (Swift tooling) | `brew install <pkg>` |
| Elixir | add package to `mix.exs` deps, then run `mix deps.get` |
| Scala | add plugin or dependency to `plugins.sbt` |

## Permission Errors

- Do not use `sudo`.
- Do not fall back to global installs.
- If the environment blocks install access, recommend a version manager such as `nvm` or `pyenv`.
- For missing runtimes or PATH issues, refer to [runtime-install-guide.md](runtime-install-guide.md).
