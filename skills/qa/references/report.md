# Report Template

Shared report structure for all testing references (browser, API, CLI).
Each reference writes its report to `<qa_dir>/` using this template
with type-specific metadata fields.

## Report structure

```markdown
# {Type} Exploratory Report

| Field | Value |
|-------|-------|
| **Date** | {YYYY-MM-DD HH:MM UTC} |
{type-specific metadata fields — see below}

## Summary

| Severity | Count |
|----------|-------|
| Critical | 0 |
| High | 0 |
| Medium | 0 |
| Low | 0 |
| **Total** | **0** |

## Issues

### ISSUE-001: {Short title}

| Field | Value |
|-------|-------|
| **Severity** | critical / high / medium / low |
| **Category** | {from the reference's category list} |
{type-specific issue fields — see below}

**Expected**

{What should happen}

**Observed**

{What actually happened}

**Evidence**

{Screenshots, videos, curl output, command output — linked by relative path}

---
```

## Type-specific fields

### Browser (`browser-report.md`)

Metadata:
- **App URL** | {URL}
- **Session** | {SESSION_NAME}
- **Scope** | {what was explored}

Issue fields:
- **URL** | {page URL where issue was found}
- **Repro Video** | {path to video, or N/A for static issues}

Evidence format: numbered repro steps with screenshot at each step,
repro video for interactive issues.

### API (`api-report.md`)

Metadata:
- **Base URL** | http://localhost:{PORT}
- **Scope** | {endpoints tested}

Issue fields:
- **Endpoint** | {METHOD /path}
- **Evidence** | [api-{test-name}.txt](api-{test-name}.txt)

Evidence format: full curl request/response captured with `curl -sv`.

### CLI (`cli-report.md`)

Metadata:
- **CLI** | {command name and version}
- **Scope** | {commands/subcommands tested}

Issue fields:
- **Command** | {full command that triggers the issue}
- **Evidence** | [cli-{test-name}.txt](cli-{test-name}.txt)
- **Exit code** | {actual} (expected: {expected})

Evidence format: stdout + stderr + exit code captured to file.

## Rules

- Increment issue counter: ISSUE-001, ISSUE-002, ...
- Append each issue immediately as found — do not batch
- Update summary severity counts after all issues are documented
- Every `### ISSUE-` block must be reflected in the summary totals
- Link evidence files by relative path
