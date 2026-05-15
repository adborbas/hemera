# Code Review

Review the current workspace diff. Use `GetWorkspaceDiff` (stat first, then per-file diffs) to understand all changes.

## Review Checklist

Work through each category below. For each finding, cite the file and line number.

### 1. Code Style Consistency

Compare new/changed code against existing patterns in the codebase. Check:
- Does it follow the conventions in `.claude/rules/swift-style.md`?
- Are `@Observable @MainActor final class` used for view models (not `ObservableObject`)?
- Are Mortar tokens used instead of raw values for spacing, animation, radii, shadows?
- Is the localization pattern followed (`String(localized:comment:)` in `private enum Localization`)?
- Are `// MARK: -` sections consistent with surrounding code?
- Is access control appropriate (`private`, `private(set)`, etc.)?

### 2. Architecture & SOLID Principles

Check against `.claude/rules/architecture.md`. Focus on:
- **Single Responsibility**: Does each type have one clear purpose? Are view models doing too much?
- **Open/Closed**: Can the change be extended without modifying existing code? Is the Entity pattern followed for new entity types?
- **Liskov Substitution**: Do protocol conformances fulfill the contract? Can implementations be swapped (production/demo/test)?
- **Interface Segregation**: Are protocols focused? Does any type depend on methods it doesn't use?
- **Dependency Inversion**: Are dependencies injected as protocols? Is `ServiceLocator` accessed only in convenience inits, not throughout the code?

Also check:
- Is the concurrency model correct (`@MainActor`, `nonisolated`, no GCD)?
- Is the data flow following the established pattern (HA → Sync → SwiftData → ViewModel → View)?
- Are new protocols needed, or can existing ones be reused?

### 3. Code Smells

Flag any code smells in the changed code:
- **Long methods** — functions doing too many things or exceeding ~30 lines of logic.
- **Large types** — classes/structs accumulating too many responsibilities.
- **Primitive obsession** — using raw strings/ints where a dedicated type would be clearer.
- **Feature envy** — a method that uses another object's data more than its own.
- **Duplicated logic** — similar code appearing in multiple places that should be extracted.
- **Deep nesting** — excessive `if`/`switch`/closure nesting (prefer early returns or extraction).
- **Magic values** — hardcoded numbers or strings that should be named constants or Mortar tokens.
- **Retained closures** — missing `[weak self]` where retain cycles are possible.
- **Force unwraps** — `!` usage outside of test setup or `preconditionFailure` contexts.

### 4. Broader Observations (Out of Scope)

Look beyond the immediate diff for things worth mentioning:
- Patterns that could be improved elsewhere in the codebase (not just in this PR).
- Potential performance concerns or SwiftData pitfalls.
- Naming inconsistencies between new code and existing conventions.
- Opportunities to simplify or reuse existing utilities (Mortar components, `StoredEntity` defaults, etc.).

Flag these clearly as "out of scope" observations — they're informational, not blockers.

### 5. Test Coverage

- Are there new or updated tests for the changed behavior?
- Do tests follow `.claude/rules/testing.md`? (Swift Testing, `@MainActor struct`, hand-written mocks, `#expect`)
- Is the test naming consistent (`func method_scenario_expected()`)?
- For new entity types: is `MockController` updated? Are card VM tests added?
- For new view models: are the key transformations and interactions tested?
- Flag untested logic paths that should have coverage.

### 6. Claude Configuration

Check if the changes warrant updates to the `.claude/` configuration:
- Does `CLAUDE.md` need updating? (new dependencies, new directories, changed build commands, new workflows)
- Do any rules files need updating? (new architectural patterns, new conventions introduced)
- Does `settings.json` need new allowed/denied commands?

## Output Format

Organize findings by severity:

**Must Fix** — Bugs, broken patterns, missing tests for critical logic.

**Should Fix** — Style violations, SOLID principle concerns, missing test coverage for non-critical paths.

**Consider** — Suggestions, out-of-scope observations, minor improvements.

For each finding, include:
- File path and line number
- What the issue is
- What the fix should be (with a code snippet if helpful)
