# Hard Play 0.36.2 — Linked Playback

**Fix for “Play starts only one Mac”:** version 0.36.0 synchronized playlist metadata but did not transmit transport commands. This release adds a separate **Linked Playback** mode.

## Use it on two Macs

1. Install **0.36.2 or newer on both Macs**. Connect Primary A and Backup B.
2. Synchronize the set and pause both players.
3. Open **Timecode & Backup → 3 · Linked Playback** and enable **Link Play / Pause / Next on both Macs**.
4. Wait for **Linked**, then press Play on either Mac.

Primary A drives the pair. Play/Pause, Next/Previous and seeks on either Mac control both. Backup B follows A's cue index and position, including duplicate cues, automatic transitions and Shuffle choices. Audio routing and volume remain local.

Turning the mode off on either Mac unlinks the pair. A disconnect leaves local playback running; reconnect and re-enable manually. Changed sets, locks and audio errors disarm linking rather than bypassing protection. “Sets match · Playback OFF” is distinct from the green Linked status.

**Limits:** this is LAN transport and position following, not sample-accurate audio clock synchronization, LTC/MTC output or automatic hardware failover. Startup offset depends on network and decoder latency. Two physical Macs and the intended audio interfaces still need on-site validation.

## Exit protection

Quitting either Mac disconnects the link before pausing its local engine, leaving the other Mac playing. Internal local pauses are separate from explicit transport requests. Both Macs must use 0.36.2 or newer; the updated capability handshake prevents linking with the earlier implementation. Real muted AVPlayer/TLS regression tests cover exiting both Primary A and Backup B.

## Install

**macOS 14+ · Apple Silicon (arm64)**. Open the DMG and drag HARDPLAY.app into Applications, or extract the ZIP. This build is ad-hoc signed and not Apple notarized. SHA-256 checksums are included.

[Русская инструкция по подключению](https://github.com/RavitzLab/HARDPLAY/blob/main/docs/BACKUP-SETUP.ru.md)
