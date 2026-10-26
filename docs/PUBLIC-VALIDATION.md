# Validation — Hard Play 0.36.2

- macOS arm64 release build, model self-test, queue and style checks passed.
- Clip tests cover exact sample trim/join, original-file preservation, export cancellation, Undo/Redo, stereo edge-silence detection, internal silence retention, silent/no-edge cases, and custom fade persistence.
- Backup tests cover hashing, packages, mismatches, invalid/missing audio and variable fade durations. Network/hardware readiness is not implied by these local tests.
- Waveform checks cover deck alternation, queue starts, protection, continuous shuffle, saved start points and playlist sizing.
- Installed Main, Mini, editor and menu-bar UI were inspected. The menu-bar player uses seven equal control cells, full margins and centered Play. Crossfade slider and themed apply buttons were visually checked.
- Real-device MIDI, separate physical output routing, failover and live PA operation require testing with the intended hardware. No CPU/GPU performance benchmark was performed.
- Builds are ad-hoc signed, not Apple notarized.

- Nine curated themes and custom save/reload/update/copy/delete passed isolated preference checks.
- Back to Player and utility close navigation were checked in the installed app, including returning to Mini. Return button placement was visually checked in PATCH and Themes.
- This is validation of current local source, not a claim that every source version has a published installer or successful hosted CI run.

- Media import tests generate H.264 video with audio and check Auto extraction, AAC conversion, WAV duration, unchanged source bytes, rejection of corrupt/audio-less media and cleanup on cancellation. Optional FFmpeg fallback is implemented but was not exercised on this Mac because FFmpeg is not installed.

## Set sync — 26 October 2026

- Release build and required self/queue/style checks passed. Playlist round-trip and media import regression checks passed.
- `--set-sync-test` passed using two isolated Player instances and a real TLS-PSK localhost connection. Push and pull match files despite different paths/order, reconstruct duplicate cues, transfer titles/fades/start points/options, remain paused and support Undo/Redo.
- Missing audio, destination locking, edits after review, a playing peer and disconnect prevent pending replacement. Original audio bytes remain unchanged. Legacy hello packets decode without enabling set-sync writes.
- Existing `--backup-test` and `--backup-link-test` passed: packages, hashes, malformed/bounded frames, wrong pairing codes, role conflicts, file invalidation and heartbeat timeout.
- This is metadata synchronization. Physical two-Mac networking, synchronized playback clocks, LTC/MTC and hardware failover have not been validated or enabled by this change.
- Installed 0.36.0 UI: A/B indicator is directly left of PATCH and opens Timecode & Backup; Verify/Export is collapsed initially. Track right-click → Show in Finder opened Finder with the exact source WAV selected. The existing user queue and paused position survived the update.

## Linked Playback — 27 October 2026

- `--linked-playback-test` uses two real, muted AVPlayers and a TLS localhost pair. Play/Pause from either Mac, seek, Next/Previous, primary-driven automatic Shuffle, explicit arming on both Macs, lock rejection and disconnect continuation passed.
- Set sync remains independent by default; one-sided arming never starts audio. A configuration edit before the throttled observer runs prevents arming immediately.
- Required build/model/queue/style checks and set-sync regression passed. This is LAN transport/state following, not a sample-accurate audio clock or measured physical two-Mac synchronization guarantee.

- Installed 0.36.1 verified by codesign and Info.plist; Timecode & Backup shows the separate Linked Playback switch, current status and both-Mac version requirement. The existing paused queue and position were preserved.

## Exit isolation — 0.36.2

- Real muted AVPlayer/TLS tests passed for normal exit of Backup B and Primary A: the other player keeps playing. Network disconnect independently preserves both local players.
- Explicit UI and MIDI toggles are separate from internal pause/lifecycle calls. The linked-playback-v2 capability requires both peers to support exit protection.
- Final release/model/queue/style and linked-playback tests passed locally. Physical two-Mac clock accuracy is still unmeasured.
