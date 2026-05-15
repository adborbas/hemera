# Contributing to Hemera

Thanks for your interest in contributing to Hemera! This guide will help you get started.

## Getting Started

### Local Development Setup

1. Clone the repository and navigate to the project directory
2. Copy the signing config template:
   ```bash
   cp Config/Local.xcconfig.template Config/Local.xcconfig
   ```
3. Edit `Config/Local.xcconfig` and set your Apple Development Team ID (see the README for details)
4. Open `Hemera.xcodeproj` in Xcode and build

### Running Tests

```bash
# Run all unit tests
xcodebuild test -project Hemera.xcodeproj -scheme Hemera \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  -only-testing:HemeraTests

# Run SPM package tests
swift test --package-path Packages/TileGridEngine
swift test --package-path Packages/AppStoreScreenshots
```

## Code Standards

This project follows specific conventions for architecture, style, and testing. See `.claude/rules/` for detailed guides:

- **Architecture** (`.claude/rules/architecture.md`) — MVVM + Coordinator pattern, Service Locator DI, Entity pattern
- **Swift Style** (`.claude/rules/swift-style.md`) — Naming, types, observation, SwiftUI patterns, design tokens
- **Testing** (`.claude/rules/testing.md`) — Swift Testing, mock patterns, test structure

**Quick highlights:**
- Use `@Observable` view models (not `ObservableObject`/Combine)
- All view models and managers are `@MainActor` + `final class`
- No inheritance — use protocols instead
- Always test behavior via unit tests, not UI tests
- Hand-written mocks, never mocking frameworks

## Reporting Bugs

Found a bug? Open a GitHub issue using the bug report template.

## Proposing Features

Have an idea? Open a GitHub issue with the feature request template. Include:
- What problem it solves
- How it would work (proposed UI/API)
- Why it fits within Hemera's scope

## Submitting Changes

1. Create a branch from `main` using the naming convention `<your-handle>/<brief-description>`
2. Make your changes and add tests (new features and bug fixes should include tests)
3. Update the **Unreleased** section of `CHANGELOG.md` with your changes
4. Push and open a pull request against `main`

### PR Expectations

- **Title**: Brief and descriptive (under 70 characters)
- **Description**: Explain *why* the change matters, not just *what* changed
- **Tests**: Include unit tests for behavior changes
- **Changelog**: Update `CHANGELOG.md` under the **[Unreleased]** section
- **No force-pushing** to avoid losing context

### Code Review

PRs will be reviewed for:
- Adherence to project conventions
- Test coverage
- Architecture fit (patterns, DI, isolation boundaries)
- UX consistency with existing design
- Performance and concurrency safety

## Architecture Overview

New to the codebase? Start with:

1. **`.claude/rules/architecture.md`** — dependency flow, MVVM structure, entity pattern
2. **Adding a new entity type** — see the "Common Workflows" section in `CLAUDE.md`

The codebase uses:
- **MVVM + Coordinator** — each screen has a view + observable view model
- **Service Locator** — session-scoped dependencies configured at app start
- **Protocol-based DI** — controlling protocols (LightControlling, CoverControlling, etc.) with production/demo/test implementations
- **Entity Registry** — type-agnostic upserts for heterogeneous collections
- **SwiftData** — persistent storage with `@Model` entities

## Questions?

- Start a GitHub Discussion for questions or ideas
- Check `.claude/rules/` for conventions
- Look at existing entity modules (e.g., `Hemera/Entities/Light/`) for patterns

Thank you for contributing!
