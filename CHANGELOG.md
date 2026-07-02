# Changelog

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Undo and redo buttons in Home edit mode for stepping through layout changes.

### Changed
- The Cancel button is gone from edit mode: tap Done or anywhere outside the grid to keep your changes, and use undo to revert individual edits.
- The resize badge now appears on every tile in edit mode, not just the selected one.
- Tiles wiggle uniformly and out of phase in edit mode, like the iOS Home Screen.

### Fixed
- Tiles did not wiggle when entering edit mode.
- Tiles now glide smoothly into place while drag-reordering instead of jumping.
- Layout edits are kept when leaving the Home tab mid-edit instead of being silently discarded.
- The tile resize button is easier to tap and is now labeled for VoiceOver.

## [1.1] - 2026-05-15

Initial release.
