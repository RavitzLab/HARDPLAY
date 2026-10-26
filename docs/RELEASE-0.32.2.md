# Hard Play 0.32.2

- Remove the transition menu and its hint from the Nano display. Transition controls remain in the playlist.
- Nano displays the actual decoded waveform, played position and hover time. Click/drag seeks; double-click plays from that point. Playback/setup protection still applies.
- Current tracks have a stronger fill, border and position indicator in both the regular and Nano playlists. Nano scrolls to the current track on opening and track changes; selecting another item does not remove the current-track marker or start playback.
- Mini can render its playlist inline. Show Playlist toggles inline visibility rather than implicitly creating a docked window. Bring playlist back inside returns the queue to Mini; the window grows within screen bounds and its content scrolls on smaller screens. Explicit detach remains available.
- Each regular/Nano playlist row has a headphones Preview button. It auditions that row through the explicit separate Preview device and turns into Stop for the auditioned track. It does not select/play the track on Main. The existing distinct-output checks, route-change stop, lock protection and independent preview volume remain in force. Hover reveals the destination; unavailable/same-output preview is disabled.
