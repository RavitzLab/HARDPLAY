# Hard Play

<img src="assets/branding/hardplay-wordmark-source.png" width="180" alt="Hard Play logo">

A lightweight stage audio player for macOS by **RavitzLab**, with an offline web edition. Main, Mini, Nano and menu-bar controls keep playback accessible while working in other apps.

## Download for Mac

Download the **DMG or ZIP** from [the latest release](https://github.com/RavitzLab/HARDPLAY/releases/latest). Open the DMG and drag **HARDPLAY.app** into **Applications**, or unzip and move the app there.

- macOS 14 Sonoma or newer. Published packages target **Apple Silicon (arm64)**. Intel users can build from source; the downloadable package is not universal.
- Builds are **ad-hoc signed, not Apple notarized**. If macOS blocks the first launch, use System Settings → Privacy & Security → Open Anyway. Do not disable Gatekeeper.
- Local audio playback works offline. Download cloud-only audio before a show.
- Closing windows leaves the app in the menu bar. **Command-Q** quits.

## Playback

- Two alternating decks show the playing and next tracks, waveform, elapsed time and gain.
- Select tracks without autoplay; use Play separately. Drag the row handle to reorder. Right-click for duplicate, rename, edit, remove and explicit start-time controls.
- Crossfade has a **0–30 second** slider with **0.1 second** precision; the initial value is **2 seconds** for an unconfigured transition. Existing transitions keep their durations. Apply to one transition or the whole playlist.
- Next, auto-stop, Repeat One / Playlist / Off and continuous Shuffle are available. Volume and preview audio can use separate outputs.
- Waveforms show time on hover. Click the small padlock beside the gain percentage to unlock **one seek**; release to lock again. An unused unlock expires after five seconds. NEXT is inspection-only; set its start position through the playlist.
- Main and Mini share controls. The menu-bar controller uses evenly spaced buttons with Play centered. Nano retains its circular control layout.

## Playlists and editing

Use the playlist actions menu for **Save, Save As, Open, Rename, New, Delete, Add Tracks** and separate/inline presentation. Playlist files store references and settings, not audio. Keep the source audio available on the Mac. Duplicate queue entries have independent names, transitions and start points.

**Quick Edit** supports waveform zoom, precise in/out points, splitting, Command-selection of multiple regions, joining selected regions, and Preview Selection. Option-hover auditions through the configured Preview output. Export a new WAV as a copy or replace the playlist entry; the original file remains unchanged.

**Detect Edge Silence** scans only the beginning/end of a track in the background. Default threshold: **−60 dB**, adjustable from −90 to −20 dB. Edges shorter than 100ms are retained, with a 20ms sound guard. Use **Select Trimmed Audio**, preview, then Save as Copy or Replace in Playlist. Pauses inside the song are retained. Fully silent files are reported without automatic removal. Adjust the threshold when quiet music or noise reaches the edges.

## PATCH and appearance

**PATCH** (or **Command-comma**) contains Audio, App, Playlists and Window settings. Main, Mini and Nano have their own window options. Themes include Blue & White, stage/flightcase styles, Mono Console, Crew Tape and Signal White. Main and Mini window opacity can be adjusted separately in Themes & Appearance.

The control lock protects live operation; hold its unlock control for **1.5 seconds**. The waveform seek padlock is separate. Keyboard/MIDI mapping, Undo/Redo, read-only web viewing and backup-set tools are available. Hardware timecode and failover compatibility require equipment-specific validation; see [the stage/backup plan](docs/TIMECODE-BACKUP-PLAN.ru.md).

## Build from source

Requirements: macOS 14+, Xcode Command Line Tools (Swift), Python 3 and Node.js for web tooling. No third-party Swift dependencies are required.

```sh
zsh scripts/build.sh
open build/HARDPLAY.app
```

Package a DMG and ZIP:

```sh
zsh scripts/release.sh
```

Artifacts appear under `build/release/`. Builds use the checkout's local Swift cache. Bundled font license notices are in `assets/fonts/`.

Core checks:

```sh
build/HARDPLAY.app/Contents/MacOS/HARDPLAY --self-test
build/HARDPLAY.app/Contents/MacOS/HARDPLAY --queue-test
build/HARDPLAY.app/Contents/MacOS/HARDPLAY --clip-test
build/HARDPLAY.app/Contents/MacOS/HARDPLAY --backup-test
build/HARDPLAY.app/Contents/MacOS/HARDPLAY --waveform-test
```

Audio tests require access to macOS audio decoders; a restricted sandbox may block them.

## Offline web edition

The `web/` directory contains the installable browser edition and its own [instructions](web/README.md). Source publication does not automatically deploy the hosted website. The existing [hosted edition](https://hardplay-offline-stage.hardmute.chatgpt.site/) may require separate access.

```sh
cd web
node scripts/build.mjs
node --test tests/*.test.mjs
node scripts/validate-artifact.mjs
```

Import audio and wait for offline caching before disconnecting. Browser storage belongs to the browser profile and can be cleared by the browser. The web and native editions do not automatically share their audio library.

## Project layout

- `Sources/` — native SwiftUI/AppKit player, audio tools and regression checks.
- `web/` — offline browser player.
- `assets/` — branding and licensed fonts.
- `scripts/` — build, package and source export.
- `docs/` — install instructions, release notes and stage roadmap.
- `.github/workflows/` — build verification.

Current release: **0.35.2**. See [release notes](docs/RELEASE-0.35.2.md) and [validation](VALIDATION.md).
