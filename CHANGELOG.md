# Changelog

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
