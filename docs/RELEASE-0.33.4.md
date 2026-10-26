# Hard Play 0.33.4

- Main and Mini transport: Volume on the left; Previous/Play/Next centered; Repeat, Shuffle and Playlist Actions on the right, with Actions at the far edge.
- Removed Playlist Actions from the lower playlist toolbar. The menu-bar controller follows the same Previous/Play/Next/Repeat/Shuffle/Actions order. Nano wheel layout is unchanged as requested.
- Playback waveforms require a stationary 1.5-second hold before seeking. Short clicks and double-clicks do not seek or start playback. After arming, dragging scrubs; releasing, exiting, changing track, losing focus or locking controls resets protection.
- Hover still shows time. Hold progress and the armed Seek state are shown in the waveform tooltip.
- Playlist Actions remains available without a loaded track, so a new/empty playlist can still be managed.
