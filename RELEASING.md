# Release Process

Hemera uses release branches to allow development to continue on `main` while a release stabilizes (e.g., during Apple review).

## Cutting a release

1. Branch from `main`:
   ```bash
   git checkout -b release/1.0.0 main
   ```
2. Bump the marketing version in Xcode project settings if needed
3. Commit: `"Prepare release 1.0.0"`
4. Push and submit to Apple for review

## Fixing issues during review

1. Create a fix branch from `release/1.0.0` (not from `main`)
2. Open a PR targeting `release/1.0.0`

## Shipping

Once Apple approves:

1. Tag the HEAD of the release branch:
   ```bash
   git tag v1.0.0
   git push origin v1.0.0
   ```
2. Create a GitHub release from the tag:
   ```bash
   gh release create v1.0.0 --title "1.0.0" --notes "Release 1.0.0"
   ```

## Merging back to main

```bash
git checkout main
git merge release/1.0.0 --no-ff -m "Merge release/1.0.0 back to main"
```

Then delete the release branch:

```bash
git branch -d release/1.0.0
git push origin --delete release/1.0.0
```

The tag `v1.0.0` permanently marks the exact commit that was shipped.

## Naming conventions

- **Branches**: `release/1.0.0` (no `v` prefix)
- **Tags**: `v1.0.0` (with `v` prefix)
