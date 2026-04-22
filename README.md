# EpochBar

A tiny macOS menu-bar utility that converts Unix epoch timestamps (and
MongoDB ObjectIds) on your clipboard to UTC ISO 8601 dates.

Copy `1735689600` (or `1735689600.5`, or `1735689600500`, or
`1735689600500000`, or a 24-char hex ObjectId like
`507f1f77bcf86cd799439011`) to the clipboard; the menu bar title changes
to `⏱ 2025-01-01T00:00:00Z` within half a second. Left-click to copy the
ISO string; right-click for the app menu.

## Requirements

- macOS 13 or later
- Swift 6 (ships with Xcode or the Xcode Command Line Tools)

No full Xcode install needed — Command Line Tools are enough.

## Build

```bash
./build.sh
```

This runs `swift build -c release`, assembles `.build/EpochBar.app`, and
ad-hoc signs it (required for `SMAppService`).

## Run (development)

```bash
open .build/EpochBar.app
```

## Install

Copy the bundle into `/Applications`:

```bash
killall EpochBar 2>/dev/null || true
cp -R .build/EpochBar.app /Applications/EpochBar.app
open /Applications/EpochBar.app
```

The "Launch at login" menu item only works reliably when the app is
installed in `/Applications`.

## Package as a DMG

```bash
./make-dmg.sh
```

Produces `.build/EpochBar.dmg` containing `EpochBar.app` and an
`Applications` drag-target. Hand the DMG to anyone else who wants the app.

The app is ad-hoc signed only, not notarized, so recipients will see a
Gatekeeper warning the first time they launch it:

> "EpochBar" can't be opened because Apple cannot check it for malicious
> software.

Tell them to **right-click EpochBar → Open**, then click **Open** in the
confirmation dialog. macOS remembers the choice and won't prompt again.

(Alternatively they can strip the quarantine flag in a terminal:
`xattr -dr com.apple.quarantine /Applications/EpochBar.app`.)

## Tests

```bash
swift test
```

Covers `EpochParser` — parsing of 10-/13-/16-digit and fractional-second
inputs, range validation, whitespace trimming, and ISO formatting with
millisecond truncation.

## Supported input formats

| Input                   | Interpretation                              |
|-------------------------|---------------------------------------------|
| 10 digits               | seconds                                     |
| 10 digits `.` fraction  | fractional seconds                          |
| 13 digits               | milliseconds                                |
| 16 digits               | microseconds                                |
| 24 hex chars            | MongoDB ObjectId (first 4 bytes = seconds)  |

Values are accepted only if the resulting date falls between 2001-01-01
and 2099-12-31 UTC. This keeps random large integers from being
misinterpreted as epochs.

## Manual smoke test

```bash
echo -n 1735689600       | pbcopy  # → ⏱ 2025-01-01T00:00:00Z
echo -n 1735689600.5     | pbcopy  # → ⏱ 2025-01-01T00:00:00.500Z
echo -n 1735689600500    | pbcopy  # → ⏱ 2025-01-01T00:00:00.500Z
echo -n 1735689600500000 | pbcopy  # → ⏱ 2025-01-01T00:00:00.500Z
echo -n hello            | pbcopy  # → ⏱ (no ISO; not an epoch)
echo -n 9999999999       | pbcopy  # → ⏱ (out of range)
echo -n 507f1f77bcf86cd799439011 | pbcopy  # → ⏱ 2012-10-17T21:13:27Z
```

Left-click the menu bar title while an ISO is showing to copy it; the
title briefly flashes `✓ copied`.
