# Harness Audit

Verify existing harness files against the current codebase. Only used
when setup detects that harness files already exist (Phase 3.5).

## Step 1: Read harness files

Read each file that exists:
- `AGENTS.md`
- `.ship/rules/CONVENTIONS.md`
- `DEVELOPMENT.md`
- `README.md`

## Step 2: Extract and verify claims

For each harness file, extract concrete claims and verify them:

### File path claims
Any path mentioned in the doc (e.g., `src/services/`, `config/app.yaml`).
Verify: `ls <path>` — does it still exist?

### Command claims
Any command mentioned (e.g., `pnpm test`, `cargo build`, `make lint`).
Verify: does the command exist in package.json scripts, Makefile, etc.?

### Architecture claims
Descriptions of module responsibilities, layer boundaries, directory
purposes (e.g., "src/services/ handles business logic").
Verify: does the directory exist? Do the files in it match the description?

### Tool claims
References to specific tools (e.g., "we use ESLint for linting").
Verify: is the tool still in dependencies? Is it still configured?

### Convention/rule claims (CONVENTIONS.md only)
Each rule's `Scope:` glob pattern.
Verify: do files matching the scope still exist?

## Step 3: Classify findings

For each claim:
- `stale`: referenced path/command/tool no longer exists
- `contradicted`: code does something different from what docs say
- `accurate`: claim still holds

## Step 4: Present results

```
Your project already has harness files. I audited them against
the current code:

AGENTS.md: <N> claims checked
  ✗ [stale] References src/renderer/ — directory moved to src/contexts/workspace/
  ✗ [stale] Says "run pnpm lint" — actual command is "pnpm lint:fix"
  ✓ [accurate] Architecture description of Main/Preload/Renderer boundaries
  ...

CONVENTIONS.md: <N> rules checked
  ✗ [stale] Rule scoped to src/payments/v1/ — directory deleted
  ✓ [accurate] Auth flow constraint still holds
  ...

<M> stale claims found, <K> still accurate.
```
