# Module: Install Missing Tools

Purpose: Install tools that Phase 1 marked as `missing`. Skip `ready` and `broken`. Do NOT update `ship.policy.json` or `AGENTS.md` here — Phase 4 Core owns those files.

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
commands in working memory. Phase 4 Core will use this to populate
`ship.policy.json` and `AGENTS.md`. Do NOT write to those files here.

### 3. Update .gitignore

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
