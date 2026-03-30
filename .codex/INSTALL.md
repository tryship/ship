# Installing Ship for Codex

Enable Ship workflow skills in Codex via native skill discovery. Clone and symlink.

## Prerequisites

- Git
- OpenAI Codex CLI

## Installation

1. **Clone the Ship repository:**
   ```bash
   git clone https://github.com/tryship/ship.git ~/.codex/ship
   ```

2. **Create the skills symlink:**
   ```bash
   mkdir -p ~/.agents/skills
   ln -s ~/.codex/ship/skills ~/.agents/skills/ship
   ```

   **Windows (PowerShell):**
   ```powershell
   New-Item -ItemType Directory -Force -Path "$env:USERPROFILE\.agents\skills"
   cmd /c mklink /J "$env:USERPROFILE\.agents\skills\ship" "$env:USERPROFILE\.codex\ship\skills"
   ```

3. **Restart Codex** (quit and relaunch the CLI) to discover the skills.

## Optional: Enable advanced features

Add to `~/.codex/config.toml`:

```toml
[features]
multi_agent = true
codex_hooks = true
```

- `multi_agent` — enables subagent dispatch for skills like `implement` and `plan`
- `codex_hooks` — enables Ship's session and bash policy hooks (when available)

## Verify

```bash
ls -la ~/.agents/skills/ship
```

You should see a symlink pointing to your Ship skills directory.

## Updating

```bash
cd ~/.codex/ship && git pull
```

Skills update instantly through the symlink.

## Uninstalling

```bash
rm ~/.agents/skills/ship
```

Optionally delete the clone: `rm -rf ~/.codex/ship`
