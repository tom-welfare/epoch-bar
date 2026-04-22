# EpochBar

A tiny macOS menu-bar utility that converts timestamp-bearing identifiers
on your clipboard to UTC ISO 8601 dates.

Copy any of the supported formats (plain Unix epochs, MongoDB ObjectIds,
ULIDs, UUIDv1/v6/v7, or Twitter-style snowflakes) and the menu bar title
changes to `⏱ 2025-01-01T00:00:00Z` within half a second. Left-click to
copy the ISO string; right-click for the app menu.

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

| Input                   | Interpretation                                         |
|-------------------------|--------------------------------------------------------|
| 10 digits               | Unix seconds                                           |
| 10 digits `.` fraction  | Unix seconds with fractional part                      |
| 13 digits               | Unix milliseconds                                      |
| 16 digits               | Unix microseconds                                      |
| 17–19 digits            | Twitter-epoch snowflake (`(v >> 22) + 1288834974657`)  |
| 24 hex chars            | MongoDB ObjectId (first 4 bytes = Unix seconds)        |
| 26 Crockford base32     | ULID (first 10 chars = 48-bit ms)                      |
| UUIDv1 (hyphenated)     | 60-bit 100ns intervals since 1582-10-15 UTC            |
| UUIDv6 (hyphenated)     | Same epoch as v1, re-ordered for sortability           |
| UUIDv7 (hyphenated)     | First 48 bits = Unix ms                                |

Values are accepted only if the resulting date falls between 2001-01-01
and 2099-12-31 UTC. This keeps random large integers from being
misinterpreted as epochs.

**Snowflakes** assume the Twitter epoch (2010-11-04). Discord, Instagram,
etc. use different epochs — if you paste a Discord snowflake you'll get a
date shifted by ~4 years and a few months. Open an issue if you need
multi-epoch support.

## Manual smoke test

```bash
echo -n 1735689600       | pbcopy  # → ⏱ 2025-01-01T00:00:00Z
echo -n 1735689600.5     | pbcopy  # → ⏱ 2025-01-01T00:00:00.500Z
echo -n 1735689600500    | pbcopy  # → ⏱ 2025-01-01T00:00:00.500Z
echo -n 1735689600500000 | pbcopy  # → ⏱ 2025-01-01T00:00:00.500Z
echo -n hello            | pbcopy  # → ⏱ (no ISO; not an epoch)
echo -n 9999999999       | pbcopy  # → ⏱ (out of range)
echo -n 507f1f77bcf86cd799439011           | pbcopy  # ObjectId → ⏱ 2012-10-17T21:13:27Z
echo -n 01ARZ3NDEKTSV4RRFFQ69G5FAV         | pbcopy  # ULID     → ⏱ 2016-07-30T23:54:10.259Z
echo -n e4eaaaf2-d142-11e1-b3e4-080027620cdd | pbcopy  # UUIDv1 → ⏱ 2012-07-19T01:41:43.645Z
echo -n 018d4fa3-4f8e-7890-abcd-ef0123456789 | pbcopy  # UUIDv7 → ⏱ 2024-01-28T10:35:19.310Z
echo -n 1800000000000000000                | pbcopy  # Snowflake → ⏱ 2024-06-10T03:00:17.039Z
```

Left-click the menu bar title while an ISO is showing to copy it; the
title briefly flashes `✓ copied`.
