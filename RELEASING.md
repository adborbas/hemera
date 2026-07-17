# Release Process

Hemera uses release branches to allow development to continue on `main` while a release stabilizes (e.g., during Apple review).

The release is automated with [fastlane](fastlane/Fastfile) and GitHub Actions. Each step below has a matching lane you can run locally and a `workflow_dispatch` workflow you can trigger from the GitHub **Actions** tab:

| Step | Lane | Workflow |
|---|---|---|
| Cut a release | `bundle exec fastlane cut_release version:1.3.0` | **1 · Cut Release** |
| Upload to TestFlight | `bundle exec fastlane beta` | **2 · Upload to TestFlight** |
| Prepare App Store release | `bundle exec fastlane prepare_release version:1.3.0` | **3 · Prepare App Store Release** |
| Complete release | `bundle exec fastlane publish version:1.3.0` | **4 · Complete Release** |

**Prepare App Store Release** creates/updates the App Store version, attaches a TestFlight build (the latest processed one by default, or a specific build via the `build` input), sets the release notes (from `fastlane/metadata/en-US/release_notes.txt`), and marks it for automatic release once approved. It stops short of submitting — you click **Submit for Review** in App Store Connect. Release notes are a fixed string; edit that file (or override in ASC) to change them. Screenshots and all other metadata are managed manually in App Store Connect (the lane leaves them untouched).

The manual git/`gh` steps below are what each lane does under the hood, kept for reference and for one-off manual releases.

### Secrets

`main` is a protected branch (changes must go through a PR, and a review plus the "Unit Tests" check are required). **Cut Release** advances `main` by opening a PR and **admin-merging** it, which the default `GITHUB_TOKEN` cannot do (it is write-only and cannot bypass protection). The **Cut Release** workflow therefore uses a `RELEASE_PAT` repository secret:

- A personal access token owned by a repo admin, with **contents: write** and **pull requests: write** on this repo (a classic token with `repo` scope also works).
- Admin bypass relies on the branch's `enforce_admins` being **off**, so the admin-merge skips the review and "Unit Tests" requirements for the trivial one-line version bump.

The other release workflows use the App Store Connect API key (`ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_KEY_P8`) and match (`MATCH_PASSWORD`, `MATCH_DEPLOY_KEY`); see the workflow files for which step needs which.

## Versioning model

`main` always holds the **next in-development version**, so it never sits on a
version that's already released. When you cut a release, the branch pins that
version and `main` advances to the next minor:

- `main` is at `1.4.0` → cut `release/1.4.0` (pinned at `1.4.0`) → `main` advances to `1.5.0`.

Because the release branch inherits its version from `main`, the version is
pinned by *branching* rather than by a commit, so the back-merge to `main` never
conflicts on `MARKETING_VERSION` (a clean release with no review fixes has
nothing to merge back at all).

## Cutting a release

1. Branch from `main` and push it (the release branch is not protected):
   ```bash
   git checkout -b release/1.4.0 main
   git push origin release/1.4.0
   ```
2. `MARKETING_VERSION` in `Config/Shared.xcconfig` already matches (it's what `main` held); only change it if you're cutting a different version.
3. Advance `main` **via a PR** — `main` is protected, so it can't be pushed directly. Put the bump on a branch, open a PR, and merge it:
   ```bash
   git checkout -b chore/bump-main-1.5.0 main
   # bump MARKETING_VERSION to the next minor (e.g. 1.5.0) in Config/Shared.xcconfig
   git commit -am "Bump main to 1.5.0 for development"
   git push origin chore/bump-main-1.5.0
   gh pr create --base main --head chore/bump-main-1.5.0 --title "Bump main to 1.5.0 for development" --body "Advance main after cutting release/1.4.0."
   gh pr merge chore/bump-main-1.5.0 --squash --admin --delete-branch
   ```
4. Submit the release branch to Apple for review.

## Fixing issues during review

1. Create a fix branch from `release/1.0.0` (not from `main`)
2. Open a PR targeting `release/1.0.0`
3. If re-uploading to App Store Connect, bump `CURRENT_PROJECT_VERSION` in `Config/Shared.xcconfig` — the build number must be unique per marketing version.

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
