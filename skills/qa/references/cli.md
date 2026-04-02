# Exploratory Testing: CLI

Terminal-based exploration for command-line applications. Test the CLI
as a real user would — from the shell, with real input, observing real output.

## Workflow

```
1. Discover     Find commands, subcommands, flags from help output and spec
2. Verify       Test each command against spec criteria
3. Explore      Beyond-spec testing: edge cases, error paths, interop
4. Document     Save evidence and write findings
```

## Setup

### Discover commands

```bash
# Get top-level help
<cli> --help 2>&1

# Get subcommand list (common patterns)
<cli> help 2>&1
<cli> commands 2>&1
<cli> list 2>&1

# Get help for each subcommand
<cli> <subcommand> --help 2>&1

# Check version
<cli> --version 2>&1
<cli> version 2>&1
```

If the CLI has a man page:
```bash
man <cli> 2>/dev/null | head -100
```

### Detect supported features

After discovering commands, probe which features the CLI supports.
**Only test features that exist.** Do not waste time on patterns the
CLI does not implement.

```bash
# Output formats
<cli> --help 2>&1 | grep -iE 'format|json|yaml|csv|table|output' && echo "HAS_OUTPUT_FORMATS"

# Auth
<cli> --help 2>&1 | grep -iE 'login|logout|auth|token|whoami' && echo "HAS_AUTH"
<cli> auth --help 2>&1 && echo "HAS_AUTH_SUBCOMMAND"
<cli> login --help 2>&1 && echo "HAS_LOGIN"

# Verbose / quiet
<cli> --help 2>&1 | grep -iE '\-v|verbose|debug|quiet|silent' && echo "HAS_VERBOSITY"

# Dry run
<cli> --help 2>&1 | grep -iE 'dry.run|whatif|no.op|simulate' && echo "HAS_DRY_RUN"

# Completion
<cli> completion --help 2>&1 && echo "HAS_COMPLETION"
<cli> --help 2>&1 | grep -iE 'completion|completions' && echo "HAS_COMPLETION"

# Recursive
<cli> --help 2>&1 | grep -iE 'recursive|depth' && echo "HAS_RECURSIVE"

# Config
<cli> --help 2>&1 | grep -iE 'config|configuration|settings' && echo "HAS_CONFIG"
<cli> config --help 2>&1 && echo "HAS_CONFIG_SUBCOMMAND"

# Network
<cli> --help 2>&1 | grep -iE 'timeout|retries|host|url|endpoint' && echo "HAS_NETWORK"

# Progress
<cli> --help 2>&1 | grep -iE 'progress|no.progress|quiet' && echo "HAS_PROGRESS_CONTROL"
```

Build a feature map from these probes. Then for each section below,
**skip it entirely if the feature is not detected.** For example:
- No `HAS_AUTH` → skip "Auth flows" section
- No `HAS_OUTPUT_FORMATS` → skip "Output format switching" section
- No `HAS_COMPLETION` → skip "Shell completion" section
- No `HAS_NETWORK` → skip "Network-dependent commands" section

### Detect install method

```bash
# Check if binary exists and is executable
which <cli> 2>/dev/null && echo "FOUND" || echo "NOT_FOUND"

# Check if it's a node CLI
[ -f package.json ] && grep -q '"bin"' package.json && echo "NODE_CLI"

# Check if it's a Python CLI
[ -f setup.py ] || [ -f pyproject.toml ] && echo "PYTHON_CLI"

# Check if it's a Go CLI
[ -f go.mod ] && echo "GO_CLI"

# Check if it's a Rust CLI
[ -f Cargo.toml ] && echo "RUST_CLI"
```

For local development CLIs, determine the run command:
```bash
# Node
npx <cli>
node ./bin/<cli>.js
./node_modules/.bin/<cli>

# Python
python -m <module>
python ./cli.py

# Go
go run ./cmd/<cli>

# Rust
cargo run --

# Or via Makefile
make run ARGS="<args>"
```

## Command Patterns

### Basic invocation

```bash
# Run command, capture stdout + stderr + exit code
OUTPUT=$(<cli> <subcommand> <args> 2>&1)
EXIT_CODE=$?
echo "Exit code: $EXIT_CODE"
echo "Output: $OUTPUT"
```

### With flags and options

```bash
# Short flags
<cli> -v -f input.txt

# Long flags
<cli> --verbose --file input.txt

# Combined short flags
<cli> -vf input.txt

# Flag with value (space-separated and = separated)
<cli> --output result.txt
<cli> --output=result.txt
```

### With stdin

```bash
# Pipe input
echo "input data" | <cli> process

# Here-doc
<cli> process <<EOF
line 1
line 2
EOF

# File redirect
<cli> process < input.txt
```

### With environment variables

```bash
# Set env for one command
ENV_VAR=value <cli> <subcommand>

# Export and run
export ENV_VAR=value
<cli> <subcommand>

# Verify missing env behavior
unset ENV_VAR
<cli> <subcommand> 2>&1
```

### Output format switching

```bash
# JSON
<cli> list --json 2>&1 | jq '.'
<cli> list --format json 2>&1 | jq '.'
<cli> list -o json 2>&1 | jq '.'

# Table (default for many CLIs)
<cli> list 2>&1
<cli> list --format table 2>&1

# YAML
<cli> get <resource> --format yaml 2>&1

# CSV
<cli> list --format csv 2>&1

# Plain / minimal (for scripting)
<cli> list --format plain 2>&1
<cli> list --no-headers 2>&1

# Output to file
<cli> export --output result.json 2>&1
[ -f result.json ] && echo "file created" || echo "file missing"
cat result.json | jq '.' 2>/dev/null || echo "not valid JSON"
```

### Interactive prompts

```bash
# Feed input to interactive prompts via pipe
echo "y" | <cli> delete <resource>

# Multiple prompts
printf "value1\nvalue2\n" | <cli> init

# Skip prompts with --yes / --force / --no-input
<cli> delete <resource> --yes
<cli> delete <resource> --force
<cli> init --no-input
```

### Verbose / debug / quiet modes

```bash
# Verbose levels
<cli> <subcommand> -v 2>&1
<cli> <subcommand> -vv 2>&1
<cli> <subcommand> -vvv 2>&1
<cli> <subcommand> --verbose 2>&1

# Debug mode (extra diagnostic info)
<cli> <subcommand> --debug 2>&1
DEBUG=1 <cli> <subcommand> 2>&1
<cli> <subcommand> --log-level debug 2>&1

# Quiet / silent mode (suppress non-essential output)
<cli> <subcommand> --quiet 2>&1
<cli> <subcommand> --silent 2>&1
<cli> <subcommand> -q 2>&1
# Expected: only errors (or nothing) on stderr, essential output on stdout

# Verify quiet mode actually suppresses
QUIET_OUT=$(<cli> <subcommand> --quiet 2>&1)
NORMAL_OUT=$(<cli> <subcommand> 2>&1)
[ ${#QUIET_OUT} -lt ${#NORMAL_OUT} ] && echo "quiet is quieter" || echo "quiet has no effect"
```

### Auth flows

```bash
# Login
<cli> login 2>&1
<cli> auth login 2>&1
<cli> login --token <token> 2>&1

# Check auth status
<cli> auth status 2>&1
<cli> whoami 2>&1

# Test with expired/invalid token
<cli> --token "expired-token" <subcommand> 2>&1
echo "Exit: $?"
# Expected: clear auth error, not a crash or misleading message

# Test without auth (when required)
<cli> <subcommand-that-needs-auth> 2>&1
echo "Exit: $?"
# Expected: clear "not logged in" error with instructions

# Logout
<cli> logout 2>&1
<cli> auth logout 2>&1

# Verify logout worked
<cli> auth status 2>&1
# Expected: "not logged in" or similar

# Token storage location
ls ~/.config/<cli>/ 2>/dev/null || ls ~/.<cli>/ 2>/dev/null
# Verify no tokens stored in plaintext in obvious locations after logout
```

### Dry run

```bash
# Dry run should show what WOULD happen without doing it
<cli> deploy --dry-run 2>&1
<cli> delete <resource> --dry-run 2>&1
<cli> migrate --whatif 2>&1

# Verify dry run has no side effects
BEFORE=$(md5sum <target-file> 2>/dev/null || echo "none")
<cli> <destructive-command> --dry-run 2>&1
AFTER=$(md5sum <target-file> 2>/dev/null || echo "none")
[ "$BEFORE" = "$AFTER" ] && echo "no side effects (correct)" || echo "DRY RUN MODIFIED FILES (bug)"
```

### Network-dependent commands

```bash
# Test with no network (if possible to simulate)
# On macOS, turn off wifi or use a firewall rule
# On Linux: unshare -n <cli> <subcommand> 2>&1

# Test connection timeout
<cli> <network-command> --timeout 1 2>&1
echo "Exit: $?"
# Expected: timeout error within a reasonable time, not hang forever

# Test with unreachable host
<cli> --host http://192.0.2.1 <subcommand> 2>&1
echo "Exit: $?"
# Expected: connection timeout error, not hang

# Test retry behavior
<cli> <network-command> --retries 0 2>&1  # no retries
<cli> <network-command> --retries 3 2>&1  # with retries

# Test with invalid URL
<cli> --url "not-a-url" <subcommand> 2>&1
echo "Exit: $?"
# Expected: clear URL validation error
```

### Timeout and hanging commands

```bash
# Test built-in timeout flag
<cli> <long-command> --timeout 5 2>&1
echo "Exit: $?"

# Force timeout on commands without built-in support
timeout 10 <cli> <potentially-hanging-command> 2>&1
EXIT_CODE=$?
echo "Exit: $EXIT_CODE"
# 124 = timed out (command was killed)
# Expected: command should either complete or have its own timeout

# Verify no zombies after timeout
sleep 1
pgrep -f "<cli>" 2>/dev/null && echo "ZOMBIE PROCESS" || echo "clean"
```

### Shell completion

```bash
# Check if completion script generation is supported
<cli> completion bash 2>&1 | head -5
<cli> completion zsh 2>&1 | head -5
<cli> completion fish 2>&1 | head -5
<cli> completions 2>&1

# Verify completion script is valid shell
<cli> completion bash 2>/dev/null | bash -n 2>&1
echo "Bash completion valid: exit $?"

<cli> completion zsh 2>/dev/null | zsh -n 2>&1
echo "Zsh completion valid: exit $?"

# Test completion output for a subcommand (if completions are sourceable)
eval "$(<cli> completion bash 2>/dev/null)"
# Then manually check: complete -p <cli> 2>/dev/null
```

### Recursive operations

```bash
# Create nested test structure
mkdir -p /tmp/cli-test/a/b/c
touch /tmp/cli-test/a/file1.txt /tmp/cli-test/a/b/file2.txt /tmp/cli-test/a/b/c/file3.txt

# Test recursive flag
<cli> process /tmp/cli-test/ --recursive 2>&1
<cli> process /tmp/cli-test/ -r 2>&1

# Test without recursive (should only process top level or error)
<cli> process /tmp/cli-test/ 2>&1

# Test recursive with symlink loops
ln -sf /tmp/cli-test /tmp/cli-test/a/loop 2>/dev/null
<cli> process /tmp/cli-test/ --recursive 2>&1
echo "Exit: $?"
# Expected: handles loop gracefully, not infinite recursion
rm -f /tmp/cli-test/a/loop

# Depth limit
<cli> process /tmp/cli-test/ --recursive --depth 1 2>&1

# Clean up
rm -rf /tmp/cli-test
```

### Progress output

```bash
# Progress bars / spinners should not pollute stdout when piped
<cli> <long-command> 2>&1 | cat -v | head -20
# Expected: no \r, no ANSI escape sequences, no spinner characters

# Progress should go to stderr (so stdout stays clean for piping)
<cli> <long-command> > /tmp/stdout.txt 2> /tmp/stderr.txt
cat /tmp/stdout.txt  # should be clean data
cat /tmp/stderr.txt  # progress info goes here

# --no-progress flag (if supported)
<cli> <long-command> --no-progress 2>&1
<cli> <long-command> --quiet 2>&1

# CI mode (some CLIs auto-detect non-interactive and suppress progress)
CI=true <cli> <long-command> 2>&1
```

## Functional Verification

### What to check per command

1. **Happy path** — correct input → expected output and exit code 0
2. **Output format** — is the output structured, parseable, and complete?
3. **Exit codes** — 0 for success, non-zero for failure (check specific codes if documented)
4. **Error messages** — clear, actionable, includes what went wrong and how to fix
5. **Side effects** — files created/modified/deleted as expected
6. **Idempotency** — running the same command twice produces the same result (where appropriate)

### CRUD end-to-end flow (for resource-managing CLIs)

```bash
# 1. CREATE
<cli> create --name "test-item" 2>&1
EXIT_CODE=$?
echo "Create exit code: $EXIT_CODE"

# 2. LIST — verify it exists
<cli> list 2>&1 | grep "test-item"

# 3. GET — verify details
<cli> get test-item 2>&1

# 4. UPDATE
<cli> update test-item --name "updated-item" 2>&1
EXIT_CODE=$?
echo "Update exit code: $EXIT_CODE"

# 5. GET — verify update applied
<cli> get updated-item 2>&1

# 6. DELETE
<cli> delete updated-item --yes 2>&1
EXIT_CODE=$?
echo "Delete exit code: $EXIT_CODE"

# 7. GET — verify it's gone
<cli> get updated-item 2>&1
EXIT_CODE=$?
echo "Get-after-delete exit code: $EXIT_CODE"
# Expected: non-zero exit code, error message
```

### Config file handling

```bash
# Default config location
<cli> config path 2>&1

# Create config
<cli> config set key value 2>&1

# Read config
<cli> config get key 2>&1

# Test with custom config path
<cli> --config /tmp/test-config.yml <subcommand> 2>&1

# Test with missing config
<cli> --config /nonexistent/path <subcommand> 2>&1
# Expected: clear error, not a crash

# Test with malformed config
echo "invalid: yaml: [" > /tmp/bad-config.yml
<cli> --config /tmp/bad-config.yml <subcommand> 2>&1
# Expected: parse error, not a crash
```

## Exploratory Testing

Beyond-spec exploration. Focus on areas touched by the diff.

### What to explore

1. **Help and usage** — `--help`, `-h`, no args, `help <subcommand>`. Is help complete and accurate?
2. **Invalid input** — missing required args, wrong types, empty strings
3. **Edge cases** — very long input, special characters, unicode, empty files, binary files
4. **Exit codes** — correct non-zero codes for different error types
5. **Error messages** — clear, actionable, no stack traces in production mode
6. **Pipes and redirection** — does stdout/stderr separation work correctly?
7. **Env variables** — documented env vars work, missing ones fail gracefully
8. **Destructive operations** — confirm prompts exist, `--force` skips them
9. **Concurrent usage** — two instances of the same command, lock files
10. **Signal handling** — Ctrl+C (SIGINT) cleans up properly
11. **Large input** — very large files, many items, deeply nested structures
12. **Permissions** — read-only file system, no write access to output dir
13. **Glob and wildcard handling** — `*`, `**`, `?` in arguments
14. **Verbose/debug/quiet modes** — do they work, does quiet actually suppress?
15. **Output formats** — json/yaml/csv/table switching, all valid and parseable?
16. **Auth** — login/logout, expired tokens, missing credentials
17. **Network resilience** — offline behavior, timeouts, unreachable hosts
18. **Dry run** — does `--dry-run` actually avoid side effects?
19. **Timeout** — commands that hang, `--timeout` flag behavior
20. **Shell completion** — bash/zsh/fish scripts generated, valid syntax?
21. **Recursive operations** — `--recursive`, depth limits, symlink loops
22. **Progress output** — suppressed when piped, goes to stderr not stdout

### Boundary value examples

```bash
# Empty string argument
<cli> create --name "" 2>&1
echo "Exit: $?"

# Very long string
<cli> create --name "$(python3 -c 'print("a"*10000)')" 2>&1
echo "Exit: $?"

# Special characters
<cli> create --name 'hello "world" & <foo> | bar; baz' 2>&1
echo "Exit: $?"

# Unicode
<cli> create --name "日本語テスト 🎉" 2>&1
echo "Exit: $?"

# Null bytes
printf 'hello\x00world' | <cli> process 2>&1
echo "Exit: $?"

# No arguments at all
<cli> 2>&1
echo "Exit: $?"
# Expected: help text or usage message, exit code 0 or 1

# Unknown subcommand
<cli> nonexistent-command 2>&1
echo "Exit: $?"
# Expected: "did you mean...?" or list of valid commands

# Unknown flag
<cli> <subcommand> --nonexistent-flag 2>&1
echo "Exit: $?"

# Duplicate flags
<cli> <subcommand> --name foo --name bar 2>&1
echo "Exit: $?"
# Expected: last wins, or error, not crash

# Flag without value
<cli> <subcommand> --name 2>&1
echo "Exit: $?"
```

### Pipe and redirection testing

```bash
# stdout vs stderr separation
<cli> <subcommand> > /tmp/stdout.txt 2> /tmp/stderr.txt
echo "stdout:" && cat /tmp/stdout.txt
echo "stderr:" && cat /tmp/stderr.txt
# Expected: data goes to stdout, errors/warnings go to stderr

# Pipe to another command
<cli> list --json | jq '.[] | .name' 2>&1
# Expected: valid JSON output that pipes cleanly

# No TTY (non-interactive mode)
echo "" | <cli> <subcommand> 2>&1
# Expected: no color codes, no interactive prompts, machine-readable output

# Check for color in non-TTY
<cli> <subcommand> 2>&1 | cat -v | grep -c '\^\[' || echo "no escape codes"
# Expected: no ANSI escape codes when piped
```

### Signal handling

```bash
# Start a long-running command and send SIGINT
<cli> <long-command> &
CLI_PID=$!
sleep 2
kill -INT $CLI_PID
wait $CLI_PID 2>/dev/null
EXIT_CODE=$?
echo "Exit after SIGINT: $EXIT_CODE"
# Expected: clean exit (130), no orphan processes, temp files cleaned up

# Check for orphan processes
pgrep -f "<cli>" 2>/dev/null && echo "ORPHAN PROCESSES FOUND" || echo "clean"
```

### File handling edge cases

```bash
# Empty file
touch /tmp/empty.txt
<cli> process /tmp/empty.txt 2>&1
echo "Exit: $?"

# Binary file
<cli> process /bin/ls 2>&1
echo "Exit: $?"
# Expected: error message, not garbled output or crash

# Non-existent file
<cli> process /nonexistent/file.txt 2>&1
echo "Exit: $?"
# Expected: clear error message

# No read permission
chmod 000 /tmp/noperm.txt 2>/dev/null
<cli> process /tmp/noperm.txt 2>&1
echo "Exit: $?"
chmod 644 /tmp/noperm.txt 2>/dev/null
# Expected: permission error, not crash

# Symlink
ln -sf /tmp/real-file.txt /tmp/link.txt 2>/dev/null
<cli> process /tmp/link.txt 2>&1
echo "Exit: $?"

# Directory instead of file
<cli> process /tmp/ 2>&1
echo "Exit: $?"
# Expected: "is a directory" error, not crash
```

### Concurrent usage

```bash
# Two instances at the same time
<cli> <subcommand> &
PID1=$!
<cli> <subcommand> &
PID2=$!
wait $PID1; EXIT1=$?
wait $PID2; EXIT2=$?
echo "Instance 1 exit: $EXIT1"
echo "Instance 2 exit: $EXIT2"
# Expected: both succeed, or second gets clear lock error

# Check for lock files
ls /tmp/<cli>*.lock 2>/dev/null || echo "no lock files"
```

## Evidence Collection

### Save full command output

```bash
# Capture stdout, stderr, and exit code in one evidence file
{
  echo "=== TEST: <test-name> ==="
  echo "Command: <cli> <args>"
  echo "Date: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "---"
  echo "STDOUT:"
  <cli> <args> 2>/tmp/cli-stderr.txt
  EXIT_CODE=$?
  echo ""
  echo "STDERR:"
  cat /tmp/cli-stderr.txt
  echo ""
  echo "EXIT CODE: $EXIT_CODE"
} > <qa_dir>/cli-<test-name>.txt 2>&1
```

### Organize evidence files

```
<qa_dir>/
  cli-help.txt                 — help output for all commands
  cli-create-happy.txt         — create happy path
  cli-crud-flow.txt            — full CRUD end-to-end
  cli-boundary-empty.txt       — empty string input
  cli-boundary-unicode.txt     — unicode input
  cli-boundary-long.txt        — very long input
  cli-pipe-stdout-stderr.txt   — pipe and redirection test
  cli-signal-sigint.txt        — SIGINT handling
  cli-concurrent.txt           — concurrent usage
  cli-report.md                — findings report
```

## Guidance

- **Exit codes matter.** A CLI that returns 0 on failure is a bug. A CLI that returns non-zero on success is a bug. Always check exit codes, not just output text.
- **Stderr is for errors, stdout is for data.** If error messages go to stdout, scripts that pipe the CLI will break. If data goes to stderr, it's lost when redirecting. Verify separation.
- **Test without a TTY.** Many CLIs behave differently when piped vs run interactively (colors, prompts, progress bars). Pipe through `cat` to simulate non-TTY and verify clean output.
- **Help text is a feature.** `--help` should be complete, accurate, and show examples. Missing or wrong help text is a real bug — users read it before anything else.
- **Error messages should be actionable.** "Error: failed" is useless. "Error: file 'input.txt' not found. Check the path and try again." is useful. Stack traces in production mode are a bug.
- **Destructive commands need guardrails.** Delete, overwrite, and reset commands should prompt for confirmation. `--force` or `--yes` should skip the prompt. Test both paths.
- **Test the whole lifecycle.** For resource-managing CLIs, always test create → read → update → delete → verify-deleted. Don't assume delete works because create works.
- **Clean up after yourself.** If the CLI creates temp files, lock files, or cache dirs, verify they're cleaned up on success AND on error/interrupt.
- **Document each issue immediately.** Don't batch findings for later. Write each one as you find it.
- **Verify side effects.** If a command claims to write a file, check the file exists and has the right content. If it claims to delete a resource, verify it's gone.
- **Test every output format.** If the CLI supports `--format json/yaml/csv/table`, test each one. Verify JSON is valid with `jq`, YAML with a parser, CSV has correct headers.
- **Test auth the full cycle.** Login → use → logout → verify token gone. Test expired tokens separately. Auth errors should say "not logged in", not crash.
- **Test network commands offline.** If a command hits the network, test what happens with no connectivity. Should fail fast with clear error, not hang.
- **Dry run must be safe.** After `--dry-run`, verify zero side effects. Checksum files before and after. If dry run modifies anything, that's a critical bug.

## Issue Severity

| Severity | Definition |
|----------|------------|
| **critical** | Blocks a core workflow, causes data loss, or crashes the app |
| **high** | Major feature broken or unusable, no workaround |
| **medium** | Feature works but with noticeable problems, workaround exists |
| **low** | Minor cosmetic or polish issue |

## Issue Categories

- **Functional** — command produces wrong output, wrong exit code, wrong side effects
- **Error handling** — crashes on bad input, unhelpful error messages, stack traces in production
- **UX** — confusing help text, inconsistent flag names, missing examples, bad defaults
- **Interop** — broken pipes, color codes in non-TTY, non-parseable JSON output
- **Concurrency** — race conditions, lock file issues, orphan processes
- **Config** — missing config error, malformed config crash, config path not respected
- **Signal handling** — no cleanup on SIGINT, orphan child processes, temp files left behind
- **Permissions** — no graceful handling of read-only filesystem or missing write access
- **Auth** — unclear login errors, tokens stored insecurely, no logout cleanup
- **Network** — hangs without timeout, no offline error, unclear connection errors
- **Output** — wrong format flag behavior, invalid JSON/YAML output, mixed formats
- **Progress** — progress pollutes stdout when piped, no way to suppress

## Output

Write findings to `<qa_dir>/cli-report.md` using the
shared template in `references/report.md` (CLI section).
