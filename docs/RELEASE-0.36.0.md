# Hard Play 0.36.0

Lightweight offline audio player for macOS by **RavitzLab**. Main, Mini, Nano and menu-bar controls share one queue.

## What's new

- **Synchronize Set:** connect two Macs, choose “This Mac → Other Mac” or the reverse, review and apply. Locally loaded audio is matched by SHA-256 despite different paths and queue order. Transfer cue order, names, duplicates, crossfades, Start at points, saved positions and playback options. Received sets stay paused and support Undo/Redo. Missing files or changed/locked/playing peers prevent pending replacement.
- **A/B status beside PATCH:** Primary A / Backup B, connection and checked-set status; click to open Timecode & Backup.
- **Show in Finder** in track context menus.
- **Audio/video import:** keep original audio or extract video audio using Auto, AAC or WAV. Optional locally installed FFmpeg provides extra decoding; it is not bundled. Original media remains unchanged.
- **Appearance and navigation:** nine curated themes, saved custom themes, Back to Player in utility windows and return to the player when closing settings.

## Download & install

**macOS 14+ · Apple Silicon (arm64)**

- Download the **DMG**, open it and drag **HARDPLAY.app** into **Applications**. Alternatively extract the ZIP and move the app there.
- This build is ad-hoc signed, **not Apple notarized**. If blocked, use macOS System Settings → Privacy & Security → Open Anyway after checking the source. Do not disable Gatekeeper.
- Check **PATCH → Audio → Main Output** before playing. Configure a separate Preview Output for auditioning.
- SHA-256 checksums are supplied in the `.sha256` asset.

[Русская инструкция](https://github.com/RavitzLab/HARDPLAY/blob/main/docs/USER_GUIDE.ru.md) · [Два Mac: синхронизация сета](https://github.com/RavitzLab/HARDPLAY/blob/main/docs/BACKUP-SETUP.ru.md)

## Validation & limits

Release/model/queue/style, playlist round-trip, media import and backup tests passed locally. Two isolated players were tested over real TLS on localhost, including push/pull, Undo/Redo, missing audio, stale snapshots, locks and disconnects. The installed A/B control and Finder action were checked in the Mac interface.

Set sync transfers metadata; it does **not** synchronize playback clocks, output LTC/MTC or enable automatic hardware failover. Two physical Macs, audio interfaces, MIDI and live PA use require equipment-specific validation. Codec support depends on macOS and the optional local FFmpeg installation.

The source includes native Mac and offline web editions. This release does not redeploy the hosted web app. Saved playlists reference audio files; keep the media with your set.
