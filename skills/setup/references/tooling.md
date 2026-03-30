# Module: Install Missing Tools

Purpose: Install tools that Phase 1 marked as `missing`. Skip `ready` and `broken`. After install, update `policy.json` and `AGENTS.md`.

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

### 2. Update Policy

- After successful installs, update `.ship/ship.policy.json`.
- Use `jq` to add new `quality.pre_commit` entries for the newly installed tools.
- Use the actual detected command, not the package name and not a hardcoded default if the repo uses a different invocation.
- Preserve existing entries and avoid duplicates.

Example:

```bash
tmp=$(mktemp) && \
jq '.quality.pre_commit += ["ruff check .", "ruff format --check ."] | .quality.pre_commit |= unique' \
  .ship/ship.policy.json > "$tmp" && \
mv "$tmp" .ship/ship.policy.json
```

### 3. Update AGENTS.md

- Update the `Commands` table in `AGENTS.md` to include the newly installed tools.
- Use the Edit tool so only the relevant command rows change.
- Add real commands the repo can run, for example lint, format, typecheck, or test commands that now exist because the tool was installed.
- Do not rewrite unrelated sections.

### 4. Update .gitignore

- Add install artifacts only for the languages involved in this repo.
- Only add entries that are not already present.

Language-specific additions:

| Language | Entries |
|---|---|
| Python | `__pycache__/`, `*.pyc`, `.ruff_cache/`, `.venv/` |
| TypeScript | `node_modules/`, `dist/`, `coverage/` |
| Go | `/bin/`, `/vendor/` |
| PHP | `vendor/` |
| Ruby | `.bundle/` |
| General | `.DS_Store`, `*.log` |

### 5. Commit

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
