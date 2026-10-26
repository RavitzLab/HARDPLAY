# Validation — Hard Play 0.35.5

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
