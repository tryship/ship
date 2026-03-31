# Changelog

## [2.1.0] - 2026-03-31

### Harness v2 Redesign

The harness system has been completely redesigned. The old approach generated
shell scripts for structural rule checking. The new approach uses AI-driven
semantic enforcement only, delegating deterministic checks to existing linters.

#### Added

- **setup-harness skill** (new): reads the codebase, discovers conventions
  linters can't cover, generates AGENTS.md (prevention) + CONVENTIONS.md
  (enforcement), registers a semantic check hook
- **setup-infra skill** (new): pure infrastructure setup split from the old
  monolithic setup skill. Installs tools, configures CI/CD, pre-commit hooks
- **scripts/check-conventions.sh**: plugin-level convention checker that calls
  `claude -p` (Haiku, print mode) for semantic judgment on every Write/Edit
- **AGENTS.md template** (references/agents-md.md): structure guide for
  AI-generated AGENTS.md, informed by OpenAI and Claude best practices
- **.mcp.json**: Codex MCP server registration for skills that use codex tools
- **Monorepo support**: setup-harness detects monorepos, investigates active
  sub-projects by git activity, updates each sub-project's local AGENTS.md
- **Hook location choice**: users choose where to register the enforcement hook
  (project shared, project local, user global, or skip)

#### Changed

- **Harness/unharness skills**: rewritten for the new semantic-only model.
  Harness checks for CONVENTIONS.md (not rules.json), registers
  check-conventions.sh (not enforce-structural.sh)
- **bin/ renamed to scripts/**: follows plugin structure convention. All
  references updated across hooks.json, AGENTS.md, and skill files
- **stop-gate.sh**: removed rules.json dependency, uses built-in defaults.
  QA and simplify phases are now optional by default
- **AGENTS.md**: updated architecture section to reflect semantic-only model,
  fixed repo map paths

#### Removed

- **skills/setup/**: replaced by setup-harness + setup-infra
- **skills/test/**: stub skill removed
- **Structural shell scripts**: no more generated .sh rule scripts, router
  script, or rules.json. Deterministic checks belong in linters/pre-commit
- **enforce-structural.sh**: replaced by check-conventions.sh
- **.ship/rules/structural/**: directory no longer generated
- **.ship/rules/rules.json**: no longer generated or consumed

### Migration from 2.0.0

If you used `/ship:setup` before:
1. Run `/ship:setup-infra` to configure tooling and CI/CD
2. Run `/ship:setup-harness` to discover conventions and generate AGENTS.md

## [2.0.0] - 2026-03-31

Initial release of Ship v2 with harness architecture.
