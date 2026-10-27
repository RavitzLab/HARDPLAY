# Hard Play 0.37.0 — Sync timing and PATCH

## Playback controls

- Wider, matching Repeat and Shuffle buttons in Main, Mini and the menu-bar controller. Play remains centered; Nano keeps its wheel layout.
- Crossfade uses a small vector of two waveform banks with a dashed join, tinted by the selected theme. No large bitmap or animated texture is added.
- Sounding decks have a green waveform and speaker indicator. NEXT uses the neutral theme color; deck borders remain neutral.

## PATCH

Dedicated navigation for Audio, App, Themes & Appearance, Keyboard & MIDI, Timecode & Backup, Web Viewer, Playlists and Window.

Playlist actions now open a second Playlist Settings drawer containing placement, playback, crossfade and Undo. Hover hints remain available through the question button; the redundant hints preference is removed from App.

## Audio

Audio shows the selected device's actual nominal sample rate, supported rate ranges, buffer frame range, output channel count and reported device latency plus safety offset and one buffer. Writable hardware settings can be changed; a driver rejection is reported rather than shown as success.

The stereo channel controls change **the device-wide preferred stereo channels**, when supported by its driver. This is shared with other applications; it is not an independent per-player output matrix. Check routing in the interface's mixer. Main and Preview still choose separate devices independently.

Processing quality selects AVPlayer's speed-processing algorithm: Low latency (varispeed, slight pitch change when correcting speed), Balanced (time domain), High quality (spectral). It does not resample or improve the source file. Hardware changes may interrupt audio in other applications using the same device.

## Sync Timing

Install this version on both Macs for timing measurements. Older Linked Playback peers can still connect, but do not support timing probes.

1. Connect, synchronize/check the loaded sets, pause both Macs and enable Linked Playback on each.
2. Open Timecode & Backup → Sync Timing. Network probes start automatically; Measure Sync starts a fresh measurement burst.
3. Read round-trip delay, jitter range, and Backup B's position error. This is an estimate of the player timeline, not a measurement at the speakers.
4. On Backup B, optionally enable Auto Align. Small errors up to 250 ms are corrected by temporary speed changes limited to ±0.5%. A stale or unstable measurement restores normal speed.
5. Manual correction ranges from −250 to +250 ms. Positive advances B; negative delays B. Align Now explicitly permits an audible seek. Large continuous drift is displayed rather than silently sought by Auto Align. Explicit seek/track commands still follow Primary A.

The clock estimate uses four monotonic timestamps and favors low-RTT samples. Network path asymmetry and AVPlayer timeline sampling limit precision. Scheduled hardware starts, sample-accurate LTC/MTC, physical output calibration and automatic output failover are not implemented. Use an audio loopback/test signal to calibrate different USB interfaces. Disconnecting disarms correction and leaves each Mac playing locally.

## Validation boundary

The build and automated two-player loopback tests validate transport and timing arithmetic. Two physical Macs, USB channel routing and acoustic alignment require device testing. No third-party runtime dependencies were added.
