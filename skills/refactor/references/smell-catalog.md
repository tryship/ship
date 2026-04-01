# Smell-to-Technique Catalog

When the refactor skill detects a code smell, apply the corresponding technique.
Techniques are ordered by LLM reliability (best first).

## Surgical Smells (within-file, apply directly)

| Smell | How to detect | Technique | Notes |
|-------|--------------|-----------|-------|
| Long Method (>30 lines) | Line count + multiple responsibilities | Extract Method | Split at logical boundaries, name by intent |
| Complex Conditional | Nested if/else >3 levels, long boolean chains | Decompose Conditional / Replace with Guard Clauses | Prefer early returns |
| Duplicated Code (same file) | Near-identical blocks | Extract Method / Consolidate Fragments | Extract shared logic, parameterize differences |
| Magic Numbers/Strings | Literal values in logic | Replace with Named Constant | Group related constants |
| Dead Code | Unused functions/exports/variables | Remove Dead Code | Grep all importers first — check for dynamic usage |
| Bad Names | Unclear abbreviations, misleading names | Rename Variable/Method/Function | Name by what it does, not how |
| Unnecessary Wrapper | One-line function that just calls another | Inline Function | Only if the wrapper adds no clarity |
| Complex Expression | Long expressions inline in conditions/args | Extract Variable | Name the intermediate result |
| Temp Variable Overuse | Variable assigned once, used once nearby | Inline Variable | Only if the expression is clear without the name |
| Long Parameter List (>4) | Function signature too wide | Introduce Parameter Object | Group related params into an object |
| Mixed Concerns in Function | One function doing two unrelated things | Split Phase | Separate into prepare + execute |
| Flag Arguments | Boolean param that changes function behavior | Remove Flag Argument / Split into two functions | Each function does one thing |

**Safety rule for signature-changing techniques** (Introduce Parameter Object, Remove Flag Argument, Split into two functions, Move Function): these change the function's calling interface. Only apply when the function is internal/private AND every caller is within the files you are editing. If the function is exported or has callers outside your scope, preserve the original signature — or skip the technique entirely.

## Structural Smells (cross-file, require execution card)

| Smell | How to detect | Technique | Risk |
|-------|--------------|-----------|------|
| God File (>300 lines, 3+ concerns) | Line count + mixed imports from different domains | Extract Module | Medium — many importers to update |
| Duplicated Logic (across files) | Same pattern in 2+ files | Extract shared function/module | Medium — must verify identical semantics |
| Circular Dependency | A imports B, B imports A | Break cycle — extract shared dep or invert direction | High — easy to change behavior |
| Feature Envy | Function uses another module's data more than its own | Move Function | High — LLM weak point, needs careful verification |
| Dependency Direction Violation | Low-level module imports from high-level | Invert dependency, extract interface | High |
| Shotgun Surgery | One change requires editing 3+ files | Consolidate into single owner | Medium |
| Catch-all Module | utils/helpers/common serving unrelated domains | Split by concern | Low — mechanical but wide blast radius |

## When NOT to refactor

| Signal | Why | Redirect to |
|--------|-----|-------------|
| "This is slow" | Performance, not structure | /fix or /auto |
| "This crashes on X input" | Bug, not structure | /fix or /investigate |
| "Add feature X" | Feature work, not refactor | /auto |
| Code is already clean but unfamiliar | Learning, not refactoring | Ask questions, read docs |
