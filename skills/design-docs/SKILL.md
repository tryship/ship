---
name: design-docs
description: Use when creating, editing, or reviewing design docs under docs/design/ — enforces frontmatter format, numbering, status lifecycle, and writing conventions
---

# Design Document Standard

All design documents live under `docs/design/`. Follow this standard when creating new docs or modifying existing ones.

## Frontmatter (Required)

Every design doc MUST start with YAML frontmatter:

```yaml
---
title: "Human-readable title"
description: "One sentence, under 120 chars — enough for an AI to decide whether to read the doc."
number: "029"
status: current | partially-outdated | superseded | draft | not-implemented
superseded_by: "034"        # only if status is superseded
related: ["001", "023"]     # other design doc numbers
services: [backend, agent-service]  # affected go-services/ directories or top-level dirs
last_verified: "2026-04-02" # date when doc was last checked against code
---
```

### Field Rules

- **title**: Match the `# heading` below the frontmatter. Use quotes if it contains special chars.
- **description**: One concise sentence. This gets injected into session context as an index — write it for an AI that needs to decide "should I read this doc?" without opening it. Max 120 chars.
- **number**: Unique across `docs/design/`. Sub-docs in a directory (e.g., `017-multi-instance-isolation/`) share the parent number. Agent docs use `"agents/001"` format.
- **status**: One of the 5 allowed values. See Status Lifecycle below.
- **superseded_by**: Required when status is `superseded`. Points to the replacement doc number.
- **related**: Array of doc numbers that cover related topics. Helps navigation.
- **services**: Array of directory names from `go-services/` (e.g., `backend`, `gateway-service`, `agent-service`) or top-level dirs (e.g., `agent`, `frontend`, `shipcli-ts`, `deploy`). Tells you which code this doc describes.
- **last_verified**: ISO date when someone last confirmed the doc matches the codebase.

## Status Lifecycle

```
draft → current → partially-outdated → superseded
                ↘ not-implemented (if design was never built)
```

| Status | Meaning |
|--------|---------|
| `draft` | Design proposed but not yet approved or implemented |
| `current` | Design matches production code |
| `partially-outdated` | Core design still applies but some details have drifted from code |
| `superseded` | Replaced by another doc — must set `superseded_by` |
| `not-implemented` | Design was approved but never built |

When changing status, also update `last_verified` to today's date.

## Numbering

- Next available number: check `ls docs/design/ | sort` and pick the next integer.
- No duplicate numbers. Each top-level doc or directory gets a unique number.
- Sub-documents inside a directory (e.g., `014-credentials-vault/plan-1-vault-service.md`) share the parent number.
- Agent-specific docs go under `docs/design/agents/` with their own numbering sequence.

## File Naming

```
{number}-{kebab-case-topic}.md
```

Examples:
- `029-prototype-v3-web-migration.md`
- `agents/008-coding-agent-core-executor.md`

Directories for multi-doc topics:
```
017-multi-instance-isolation/
├── helm-test-env-deployment-model.md
├── isolated-ingress-shared-alb-proposal.md
└── TBD.md
```

## Document Structure

```markdown
---
(frontmatter)
---

# {Number} — {Title}

## Status

{Status explanation with context — why it has this status, what changed}

## Summary

{2-3 sentences: what problem this solves and the key design decision}

## (Body sections — flexible per topic)

## References

- Related docs, external links, prior art
```

### Writing Rules

- Lead with the decision, not the analysis. Readers want to know "what did we choose" before "what did we consider."
- Use concrete file paths, struct names, and API endpoints — not abstractions.
- If the doc is in Chinese, keep it in Chinese. If in English, keep it in English. Don't mix.
- Mark superseded sections inline with strikethrough or a note, don't silently delete history.
- When a design changes, update the existing doc rather than creating a new one — unless the change is a complete replacement (then supersede).

## Cross-References

- Reference other design docs by number: "see 023-agent-broker-architecture"
- When renaming/renumbering, update ALL references. Use: `grep -r "old-name" docs/ AGENTS.md README.md deploy/`
- The `docs/README.md` index must include every design doc. Add your doc there when creating it.

## Updating docs/README.md

When creating a new doc, add it to the appropriate section in `docs/README.md`:
- Core Architecture, Agent, PTY And Terminal, Runtime, Platform, Channels, Guides, Desktop, Tooling, Historical

## Verification

Before marking a doc as `current`, verify key claims against code:
- Do referenced file paths exist?
- Do referenced struct/function names exist?
- Do referenced API endpoints exist?
- Does the described architecture match the actual service boundaries?

Update `last_verified` when you complete verification.
