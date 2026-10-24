# Hard Play 0.28.4 — Auto Fit on Separate Playlist

Entering a separate playlist presentation now enables Auto Fit automatically. This applies to independent Detach and each Dock direction, including entry from Mini; restoring a saved separate playlist on launch also enables it. Existing fitted-layout measurement then resizes the main player to its content, preserving width/top edge and display bounds. Returning inside does not disable Auto Fit; the user can still toggle it manually.

Includes the 0.28.3 remaining-track-time strip. Build/self/queue/style and waveform/layout checks pass. Applying to the active app is pending a playback-safe restart; no current transport interruption is performed.
