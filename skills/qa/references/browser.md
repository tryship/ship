# Exploratory Testing: Browser

Browser-based exploration of web UI. Detect available tools in Phase 1
and use the best option:

| Tool | Capability |
|------|-----------|
| **agent-browser** (CLI) | Screenshots, video recording, interaction, snapshots |
| **Playwright/Puppeteer** (via Bash) | Screenshots, interaction, no video |
| **curl only** (fallback) | Page content verification only, interactive criteria → SKIP |

## Setup

Only the **Target URL** is required. Everything else has sensible defaults -- use them unless the user explicitly provides an override.

| Parameter | Default | Example override |
|-----------|---------|-----------------|
| **Target URL** | _(required)_ | `vercel.com`, `http://localhost:3000` |
| **Session name** | Slugified domain (e.g., `vercel.com` -> `vercel-com`) | `--session my-session` |
| **Output directory** | `<qa_dir>/` | `Output directory: /tmp/qa` |
| **Scope** | Full app | `Focus on the billing page` |
| **Authentication** | None | `Sign in to user@example.com` |

Always use `agent-browser` directly -- never `npx agent-browser`. The direct binary uses the fast Rust client. `npx` routes through Node.js and is significantly slower.

## Workflow

```
1. Initialize    Set up session, output dirs, report file
2. Authenticate  Sign in if needed, save state
3. Orient        Navigate to starting point, take initial snapshot
4. Explore       Systematically visit pages and test features
5. Document      Screenshot + record each issue as found
6. Wrap up       Update summary counts, close session
```

### 1. Initialize

```bash
mkdir -p {OUTPUT_DIR}/screenshots {OUTPUT_DIR}/videos
```

Start a named session:

```bash
agent-browser --session {SESSION} open {TARGET_URL}
agent-browser --session {SESSION} wait --load networkidle
```

### 2. Authenticate

If the app requires login:

```bash
agent-browser --session {SESSION} snapshot -i
# Identify login form refs, fill credentials
agent-browser --session {SESSION} fill @e1 "{EMAIL}"
agent-browser --session {SESSION} fill @e2 "{PASSWORD}"
agent-browser --session {SESSION} click @e3
agent-browser --session {SESSION} wait --load networkidle
```

For OTP/email codes: ask the user, wait for their response, then enter the code.

After successful login, save state for potential reuse:

```bash
agent-browser --session {SESSION} state save {OUTPUT_DIR}/auth-state.json
```

### 3. Orient

Take an initial annotated screenshot and snapshot to understand the app structure:

```bash
agent-browser --session {SESSION} screenshot --annotate {OUTPUT_DIR}/screenshots/initial.png
agent-browser --session {SESSION} snapshot -i
```

Identify the main navigation elements and map out the sections to visit.

### 4. Explore

**Strategy -- work through the app systematically:**

- Start from the main navigation. Visit each top-level section.
- Within each section, test interactive elements: click buttons, fill forms, open dropdowns/modals.
- Check edge cases: empty states, error handling, boundary inputs.
- Try realistic end-to-end workflows (create, edit, delete flows).
- Check the browser console for errors periodically.

**At each page:**

```bash
agent-browser --session {SESSION} snapshot -i
agent-browser --session {SESSION} screenshot --annotate {OUTPUT_DIR}/screenshots/{page-name}.png
agent-browser --session {SESSION} errors
agent-browser --session {SESSION} console
```

Use your judgment on how deep to go. Spend more time on core features and less on peripheral pages. If you find a cluster of issues in one area, investigate deeper.

### 5. Document Issues (Repro-First)

Steps 4 and 5 happen together -- explore and document in a single pass. When you find an issue, stop exploring and document it immediately before moving on. Do not explore the whole app first and document later.

Every issue must be reproducible. When you find something wrong, do not just note it -- prove it with evidence. The goal is that someone reading the report can see exactly what happened and replay it.

**Choose the right level of evidence for the issue:**

#### Interactive / behavioral issues (functional, ux, console errors on action)

These require user interaction to reproduce -- use full repro with video and step-by-step screenshots:

1. **Start a repro video** _before_ reproducing:

```bash
agent-browser --session {SESSION} record start {OUTPUT_DIR}/videos/issue-{NNN}-repro.webm
```

2. **Walk through the steps at human pace.** Pause 1-2 seconds between actions so the video is watchable. Take a screenshot at each step:

```bash
agent-browser --session {SESSION} screenshot {OUTPUT_DIR}/screenshots/issue-{NNN}-step-1.png
sleep 1
# Perform action (click, fill, etc.)
sleep 1
agent-browser --session {SESSION} screenshot {OUTPUT_DIR}/screenshots/issue-{NNN}-step-2.png
sleep 1
# ...continue until the issue manifests
```

3. **Capture the broken state.** Pause so the viewer can see it, then take an annotated screenshot:

```bash
sleep 2
agent-browser --session {SESSION} screenshot --annotate {OUTPUT_DIR}/screenshots/issue-{NNN}-result.png
```

4. **Stop the video:**

```bash
agent-browser --session {SESSION} record stop
```

5. Write numbered repro steps in the report, each referencing its screenshot.

#### Static / visible-on-load issues (typos, placeholder text, clipped text, misalignment, console errors on load)

These are visible without interaction -- a single annotated screenshot is sufficient. No video, no multi-step repro:

```bash
agent-browser --session {SESSION} screenshot --annotate {OUTPUT_DIR}/screenshots/issue-{NNN}.png
```

Write a brief description and reference the screenshot in the report. Set **Repro Video** to `N/A`.

---

**For all issues:**

1. **Append to the report immediately.** Do not batch issues for later. Write each one as you find it so nothing is lost if the session is interrupted.

2. **Increment the issue counter** (ISSUE-001, ISSUE-002, ...).

### 6. Wrap Up

Aim to find **5-10 well-documented issues**, then wrap up. Depth of evidence matters more than total count -- 5 issues with full repro beats 20 with vague descriptions.

After exploring:

1. Re-read the report and update the summary severity counts so they match the actual issues. Every `### ISSUE-` block must be reflected in the totals.
2. Close the session:

```bash
agent-browser --session {SESSION} close
```

## Exploration Checklist

Use this as a guide for what to test on each page/feature:

1. **Visual scan** -- Take an annotated screenshot. Look for layout, alignment, and rendering issues.
2. **Interactive elements** -- Click every button, link, and control. Do they work? Is there feedback?
3. **Forms** -- Fill and submit. Test empty submission, invalid input, and edge cases.
4. **Navigation** -- Follow all navigation paths. Check breadcrumbs, back button, deep links.
5. **States** -- Check empty states, loading states, error states, and full/overflow states.
6. **Console** -- Check for JS errors, failed requests, and warnings.
7. **Responsiveness** -- If relevant, test at different viewport sizes.
8. **Auth boundaries** -- Test what happens when not logged in, with different roles if applicable.

## Guidance

- **Repro is everything.** Every issue needs proof -- but match the evidence to the issue. Interactive bugs need video and step-by-step screenshots. Static bugs (typos, placeholder text, visual glitches visible on load) only need a single annotated screenshot.
- **Verify reproducibility before collecting evidence.** Before recording video or taking screenshots, verify the issue is reproducible with at least one retry. If it can't be reproduced consistently, it's not a valid issue.
- **Don't record video for static issues.** A typo or clipped text doesn't benefit from a video. Save video for issues that involve user interaction, timing, or state changes.
- **For interactive issues, screenshot each step.** Capture the before, the action, and the after -- so someone can see the full sequence.
- **Write repro steps that map to screenshots.** Each numbered step in the report should reference its corresponding screenshot. A reader should be able to follow the steps visually without touching a browser.
- **Use the right snapshot command.**
  - `snapshot -i` — for finding clickable/fillable elements (buttons, inputs, links)
  - `snapshot` (no flag) — for reading page content (text, headings, data lists)
- **Be thorough but use judgment.** You are not following a test script -- you are exploring like a real user would. If something feels off, investigate.
- **Write findings incrementally.** Append each issue to the report as you discover it. If the session is interrupted, findings are preserved. Never batch all issues for the end.
- **Never delete output files.** Do not `rm` screenshots, videos, or the report mid-session. Do not close the session and restart. Work forward, not backward.
- **Never read the target app's source code.** You are testing as a user, not auditing code. Do not read HTML, JS, or config files of the app under test. All findings must come from what you observe in the browser.
- **Check the console.** Many issues are invisible in the UI but show up as JS errors or failed requests.
- **Test like a user, not a robot.** Try common workflows end-to-end. Click things a real user would click. Enter realistic data.
- **Type like a human.** When filling form fields during video recording, use `type` instead of `fill` -- it types character-by-character. Use `fill` only outside of video recording when speed matters.
- **Pace repro videos for humans.** Add `sleep 1` between actions and `sleep 2` before the final result screenshot. Videos should be watchable at 1x speed -- a human reviewing the report needs to see what happened, not a blur of instant state changes.
- **Be efficient with commands.** Batch multiple `agent-browser` commands in a single shell call when they are independent (e.g., `agent-browser ... screenshot ... && agent-browser ... console`). Use `agent-browser --session {SESSION} scroll down 300` for scrolling -- do not use `key` or `evaluate` to scroll.

## Issue Severity

| Severity | Definition |
|----------|------------|
| **critical** | Blocks a core workflow, causes data loss, or crashes the app |
| **high** | Major feature broken or unusable, no workaround |
| **medium** | Feature works but with noticeable problems, workaround exists |
| **low** | Minor cosmetic or polish issue |

## Issue Categories

### Visual / UI

- Layout broken or misaligned elements
- Overlapping or clipped text
- Inconsistent spacing, padding, or margins
- Missing or broken icons/images
- Dark mode / light mode rendering issues
- Responsive layout problems (viewport sizes)
- Z-index stacking issues (elements hidden behind others)
- Font rendering issues (wrong font, size, weight)
- Color contrast problems
- Animation glitches or jank

### Functional

- Broken links (404, wrong destination)
- Buttons or controls that do nothing on click
- Form validation that rejects valid input or accepts invalid input
- Incorrect redirects
- Features that fail silently
- State not persisted when expected (lost on refresh, navigation)
- Race conditions (double-submit, stale data)
- Broken search or filtering
- Pagination issues
- File upload/download failures

### UX

- Confusing or unclear navigation
- Missing loading indicators or feedback after actions
- Slow or unresponsive interactions (>300ms perceived delay)
- Unclear error messages
- Missing confirmation for destructive actions
- Dead ends (no way to go back or proceed)
- Inconsistent patterns across similar features
- Missing keyboard shortcuts or focus management
- Unintuitive defaults
- Missing empty states or unhelpful empty states

### Content

- Typos or grammatical errors
- Outdated or incorrect text
- Placeholder or lorem ipsum content left in
- Truncated text without tooltip or expansion
- Missing or wrong labels
- Inconsistent terminology

### Performance

- Slow page loads (>3s)
- Janky scrolling or animations
- Large layout shifts (content jumping)
- Excessive network requests (check via console/network)
- Memory leaks (page slows over time)
- Unoptimized images (large file sizes)

### Console / Errors

- JavaScript exceptions in console
- Failed network requests (4xx, 5xx)
- Deprecation warnings
- CORS errors
- Mixed content warnings
- Unhandled promise rejections

### Accessibility

- Missing alt text on images
- Unlabeled form inputs
- Poor keyboard navigation (can't tab to elements)
- Focus traps
- Insufficient color contrast
- Missing ARIA attributes on dynamic content
- Screen reader incompatible patterns

## Output

Write findings to `<qa_dir>/browser-report.md` using the
shared template in `references/report.md` (Browser section).
