# Changelog

## Beta 5 - 0.44.0

- Consolidated working beta of Main, Mini, Nano and menu-bar playback, including all changes through 0.43.6.
- Independent Main/Preview logo indicators, headphones transport states, native header dragging and Nano size controls in the left drawer.
- DJ remains experimental and its further development is deferred.


## 0.43.6

- Nano size selection moves from the bottom corner into the left display-edge drawer, alongside position and control protection. Small, Optimal and Large scale the whole player together.
- DJ development is deferred; this update focuses on the everyday player prototype.


## 0.43.5

- Fix DJ hold-button text rendering crash on macOS 27 using native captions and resolved theme colors.
- Preview controls retain headphones and show playing, paused or stopped status inside; short click toggles, hold 0.5 s stops.


## 0.43.4

- Logo: Main playback lights only the PLAY triangle; Preview lights only the HARD triangle. Both can be active independently, including Nano, Dock and menu-bar icons.
- Drag Main / Mini by the logo or empty header space; Nano also accepts the empty top area, respecting position locks. Preview headphones retain single-click Play/Pause and 0.5-second held Stop.

## 0.43.3

- Stop the NSHostingView / fixed window size / Auto Fit layout feedback loop. Fixed profile windows no longer have competing automatic size constraints; applying unchanged sizes is idempotent.
- Preview progress updates only its waveform instead of invalidating every playlist row. Unchanged waveforms no longer redraw or invalidate cursor rectangles.

## 0.43.2

- Playlist preview replaces the track title with a seekable waveform and Preview output / time indicator in Main, Mini, detached and Nano queues.
- Preview button becomes Play/Pause; a 0.5-second hold stops audition and restores the title. Pausing retains the waveform and position. Preview routing stays separate from Main.

## 0.43.1

- Shared right-edge Controls drawer in Main, Mini, Nano and DJ player windows. Assignments are shared, the panel follows its owner, and switching players closes it.

## 0.43.0

- Nano: right-edge custom control drawer, up to four independently saved Trigger / Toggle buttons.
- Experimental DJ window: independent A/B streaming decks, held Cue, tempo and key lock, Bend, manual BPM / grid Sync, loops, eight Hot Cues, Slip, aligned stem-file mixing and equal-power crossfader.
- DJ has its own Small / Optimal / Large size profile and uses the selected Main output.
- No AI stem-separation model or automatic beat analysis is bundled. See `docs/DJ-MODE.ru.md` for operation and limitations.

## 0.42.0

- Independent Small / Optimal / Large presets for player, playlist and utility windows. Text, icons and controls scale uniformly within fixed logical layouts; oversized choices fit the display.
- Removed free size/font/spacing combinations from appearance controls. Old custom-theme values remain stored, while fixed layouts use stable base metrics.
- Removed redundant top padding above the Main toolbar.
- Main uses bounded portrait/wide layouts; hidden inline playlists no longer reserve an empty panel. Playlist scrolling stays inside the available area.

## 0.41.1

- Restored the original stacked HARD / PLAY layout in all shared window wordmarks. Only the two Play symbols turn red during playback; pause restores theme ink.
- Restored compact header proportions while retaining cached native rendering and tint checks.

## 0.41.0

- Horizontal HARDPLAY wordmark across Main, Mini, Nano, playlist panels, menu-bar player and utility-window headers.
- Only the two Play triangles turn red during playback; the remaining lettering keeps theme ink. Cached native artwork avoids per-tick raster generation.

## 0.40.3

- Live theme scheme propagation at native hosting boundaries fixes dark native menus after changing from a light preset. Borderless menu labels and indicators use explicit theme ink.
- Native playlist reorder handles observe theme changes and draw with the theme secondary color. Covers Main, Mini, Nano, menu-bar player and utility windows.
- Added contrast checks for all fifteen presets and an isolated offline control-gallery renderer for visual QA.

## 0.40.2

- Nano face widened from 180 to 220 points; existing narrow saved windows expand to the new minimum.
- Nano playlist widened from 268 to 360 points with a taller list viewport (320 points) and slightly larger track names. Existing screen-edge placement and resizing remain available.

## 0.40.1

- Removed Tape Blue, Tape Black, Stage, Cables and Minimal from the built-in picker. Studio Precision is the reset/fallback preset; saved custom themes remain available.
- Digital Underground now uses muted warm sand/yellow accents and charcoal/olive surfaces. Unchanged factory colors migrate while user color overrides remain intact.

## 0.40.0

- Anchored compact color editors with RGB/HEX controls and optional gradients for background, panels, control surfaces and playlist tape. Changes preview live and persist in custom themes.
- Connected previously fixed Nano shell/display and secondary text colors to theme tokens; playlist names use the chosen tape fill. Removed FOH from built-in presets.
- Mini: larger Hints button immediately before PATCH, no Minimize button. Nano logo now refreshes red while playing.

## 0.39.0

- Added eight more lightweight concept themes; twenty-one built-in presets total.
- Centered the original wordmark in Main/Mini; it turns red during playback. Moved Minimize/Hints left.
- Arrow-only utility Back control and softer White/Signal White surfaces.

## 0.38.0

- Added Studio Precision, Modular Grid, Timecode Core and Shadow System across the native player windows.
- Semantic panel/surface/waveform/grid colors, crisp concept icons, bundled OFL typography and flat lightweight surfaces.
- New concept tokens persist with custom themes; existing themes and original logo artwork stay intact. See docs/CONCEPT-THEMES.md for specification and font substitutions.

## 0.37.1

- PATCH opens Themes & Appearance, Keyboard & MIDI, Timecode & Backup and Web Viewer directly in its content area, without launch pages or extra windows.
- Each embedded tool retains its own scrolling; embedded mappings omit the separate-window minimize button and stop learning when leaving the section.
- PATCH restores a width suitable for its sidebar and embedded controls.

## 0.37.0

- Wider aligned Repeat/Shuffle, theme-tinted waveform crossfade icon, neutral deck borders and green sounding-wave indicator.
- PATCH categories and a second playlist settings drawer with Undo.
- Driver-supported sample rate/buffer controls, reported latency, shared hardware stereo-pair patching and speed-processing quality.
- Automatic network probes, RTT/jitter/clock estimates, position error, manual offset, bounded opt-in Auto Align and explicit Align Now. See release notes for hardware and timing limits.

## 0.36.2

- Normal app exit disconnects the pair before pausing the local player, so quitting either Mac leaves its peer playing.
- Internal pauses during local lifecycle operations are not forwarded as user transport requests. Explicit Play/Pause buttons and MIDI toggles still control the pair.
- Added real TLS/AVPlayer regression checks for exiting Primary A and Backup B.

## 0.36.1

- Added explicitly armed Linked Playback: Play/Pause, Next/Previous and seeks from either Mac control the pair; Primary A drives state and Shuffle choices.
- Backup B follows the actual queue index and position, including duplicate cues and automatic transitions. Local volume and outputs remain independent.
- Set sync and live transport now have distinct status labels. Both Macs must enable Linked Playback while paused after verifying the same set.
- Locks, changed sets, audio errors and disconnects disable linking; network loss leaves local audio playing. LAN transport is not sample-accurate hardware timecode or failover.

## 0.36.0

- One-button push/pull set synchronization between paired Macs, with direction selection and review before applying.
- Match already loaded local files by SHA-256; transfer order, cue names, duplicates, fades, start points, saved positions and playback options without copying audio.
- Missing media, stale snapshots, playback, locks and disconnects prevent pending changes; received sets remain paused and support Undo/Redo.
- Primary A / Backup B connection and set-status button beside PATCH in Main; hardware timecode and automatic failover remain inactive.
- Show in Finder in track context menus, including the Nano playlist.

## 0.35.6

- Shared audio/video import queue, extraction to Auto/M4A, AAC or WAV, progress and cancellation.
- Optional local FFmpeg fallback to 24-bit PCM WAV for extra codecs; no bundled FFmpeg or network conversion.
- Original files remain unchanged; imported copies persist independently of the video.


Source versions after 0.35.2 are not automatically available as downloadable installers. Check Releases for package availability.

## 0.35.5
- Back to Player moved into a dedicated themed content row, below the native window title bar, to prevent clipping.

## 0.35.4
- Utility panels return to the originating player when closed.
- Back to Player navigation added to PATCH, Themes, MIDI, Backup, Web Viewer and Quick Edit.

## 0.35.3
- Built-in themes reduced to nine selected looks, including White.
- Named custom themes can be saved, selected, updated, copied and deleted.

## 0.35.2
- Adjustable crossfade duration from 0 to 30 seconds, with per-transition and whole-playlist application.
- Edge-silence detection in Quick Edit.
- Centered transport controls, one-gesture seek locks and separate Main/Mini opacity.

Earlier development history remains in Git commits and existing release tags. The current user guide describes current behavior rather than every intermediate UI experiment.
