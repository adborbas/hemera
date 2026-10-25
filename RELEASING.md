# Release Process

Hemera uses release branches to allow development to continue on `main` while a release stabilizes (e.g., during Apple review).

## The short version

Trigger **Release Train** from the **Actions** tab, with no inputs. It cuts the release branch,
advances `main`, uploads to TestFlight and prepares the App Store version with the build attached.
Then you do the one thing Apple requires a human for: press **Submit for Review**.

Once Apple releases the version, the hourly **Auto-publish When Live** workflow tags it, creates the
GitHub release, back-merges into `main` and deletes the release branch. Nothing else to trigger.

So a normal release is: *dispatch the train → submit for review → done.*

## The individual steps

The train is built from the lanes below, each of which is still a `workflow_dispatch` workflow in
its own right. Use them to re-run a single stage when the train fails partway, or for a one-off
manual release:

| Step | Lane | Workflow |
|---|---|---|
| Cut a release | `bundle exec fastlane cut_release` | **1 · Cut Release** |
| Upload to TestFlight | `bundle exec fastlane beta` | **2 · Upload to TestFlight** |
| Prepare App Store release | `bundle exec fastlane prepare_release version:3.0` | **3 · Prepare App Store Release** |
| Complete release | `bundle exec fastlane publish version:3.0` | **4 · Complete Release** |
| Publish only if live | `bundle exec fastlane publish_if_live` | **Auto-publish When Live** |

Re-running the whole train after a failure is safe: `cut_release` leaves the release branch alone
when it finds it already cut. `version:` is optional everywhere — cutting defaults to the next
release number derived from the `v*` tags, and the later steps default to the `MARKETING_VERSION`
on the checked-out branch.

**Prepare App Store Release** creates/updates the App Store version, waits for the TestFlight build
to finish processing, attaches it, sets the release notes (from
`fastlane/metadata/en-US/release_notes.txt`), and marks it for automatic release once approved. It
stops short of submitting — you click **Submit for Review** in App Store Connect.

Two details worth knowing, both learned the hard way on 1.7.0:

- `deliver` attaches a build only as part of submitting for review, which this lane deliberately
  does not do. The lane therefore selects the build itself via Spaceship. Passing `build_number:`
  to `deliver` does *not* attach anything — it only suppresses a binary upload.
- The lane waits for that exact build rather than using pilot's wait, which polls the oldest
  processing build and is the hang the `beta` lane avoids by never waiting.

Release notes and promotional text are fixed strings in `fastlane/metadata/en-US/`; edit those
files (or override in ASC) to change them. Screenshots and every other field are managed manually
in App Store Connect and the lane leaves them untouched, so anything with no file under
`fastlane/metadata/` is still yours to fill in.

The manual git/`gh` steps below are what each lane does under the hood, kept for reference and for one-off manual releases.

### Secrets

`main` is a protected branch (changes must go through a PR, and a review plus the "Unit Tests" check are required). Publishing a release **admin-merges** the back-merge PR into `main`, which the default `GITHUB_TOKEN` cannot do (it is write-only and cannot bypass protection). **Complete Release** and **Auto-publish When Live** therefore use a `RELEASE_PAT` repository secret:

- A personal access token owned by a repo admin, with **contents: write** and **pull requests: write** on this repo (a classic token with `repo` scope also works).
- Admin bypass relies on the branch's `enforce_admins` being **off**, so the admin-merge skips the review and "Unit Tests" requirements for commits that have already shipped.

Cutting a release needs no PAT: it only pushes a branch, which the checkout token can do.

The `release` environment must have **no required reviewers**. The unattended workflows would
otherwise stall on an approval that nobody is watching for — the scheduled publish indefinitely.
Who may start a release is controlled by `if: github.actor == 'adborbas'` on the dispatch instead.

The repository's default workflow permissions are **read**, so every workflow that pushes
anything declares `permissions: contents: write` for itself. Note that this governs the checkout
token only — `gh` commands authenticated with `RELEASE_PAT` are unaffected by it.

The other release workflows use the App Store Connect API key (`ASC_KEY_ID`, `ASC_ISSUER_ID`,
`ASC_KEY_P8`) and match (`MATCH_PASSWORD`, `MATCH_DEPLOY_KEY`); see the workflow files for which
step needs which.

## Versioning model

Hemera is **not** versioned with semver. The version is a plain release counter:
each release is one higher than the last, and the second component counts
hotfixes against that release.

- `2.0` → `3.0` → `4.0` …, with `2.1` if `2.0` needs a fix after it has shipped.

Semver's major/minor/patch distinction describes API compatibility, which only
matters to code that depends on you. Nothing depends on an app, so the
distinction bought nothing but a judgement call every release. A counter removes
it: there is no third component, and nothing to decide.

(The local SPM packages are a different matter. If `Mortar` or `TileGridEngine`
are ever published for other projects to consume, they should use semver — a
resolver reads those numbers.)

`cut_release` derives the next version from the tags, so it needs no input:
the highest `v*` tag is the last release, and the next one is a major higher.
`main` is not bumped ahead of time — it picks the new version up through the
back-merge when the release is published. Before the first counter release,
`main` sat at `1.8.0`, a semver version that was never shipped; it is now `2.0`.

## Cutting a release

1. Branch from `main` and push it (the release branch is not protected):
   ```bash
   git checkout -b release/3.0 main
   git push origin release/3.0
   ```
2. Set `MARKETING_VERSION` in `Config/Shared.xcconfig` to the new version and commit it on the branch.
3. Submit the release branch to Apple for review.

`main` needs no bump: publishing back-merges the release branch, which carries
the version commit with it.

### Hotfixing a shipped release

`cut_release` always branches from `main`, so a hotfix branch has to be made by
hand from the tag — going through the lane would pull in unshipped work:

```bash
git checkout -b release/2.1 v2.0
# set MARKETING_VERSION = 2.1 in Config/Shared.xcconfig
git commit -am "Prepare release 2.1"
git push origin release/2.1
```

Then run **Release Train** with `version` set to `2.1`. Cutting finds the branch
already on origin and leaves it untouched, and the TestFlight and App Store
stages run against it as usual.

## Fixing issues during review

1. Create a fix branch from `release/3.0` (not from `main`)
2. Open a PR targeting `release/3.0`
3. If re-uploading to App Store Connect, bump `CURRENT_PROJECT_VERSION` in `Config/Shared.xcconfig` — the build number must be unique per marketing version.

## Shipping

Once Apple approves:

1. Tag the HEAD of the release branch:
   ```bash
   git tag v3.0
   git push origin v3.0
   ```
2. Create a GitHub release from the tag:
   ```bash
   gh release create v3.0 --title "3.0" --notes "Release 3.0"
   ```

## Merging back to main

```bash
git checkout main
git merge release/3.0 --no-ff -m "Merge release/3.0 back to main"
```

Then delete the release branch:

```bash
git branch -d release/3.0
git push origin --delete release/3.0
```

The tag `v3.0` permanently marks the exact commit that was shipped.

## Naming conventions

- **Branches**: `release/3.0` (no `v` prefix)
- **Tags**: `v3.0` (with `v` prefix)
