# Hard Play 0.30.0

- Unlock controls by holding the same control for 1.5 seconds. Releasing early cancels. Nano uses its bottom wheel button while locked.
- PATCH keeps Main, Mini, Nano, Playlist and App tabs at the top. The settings below belong to the selected scope; shared application preferences live in App.
- Use the supplied H▶RD / PL▶Y wordmark throughout the app, application icon and menu bar. Playback turns the logo red; paused/idle uses its normal color. Idle menu-bar artwork follows the system appearance.
- My Set is the editable set name. Show Playlist toggles queue visibility, with a separate detach/embed button. Launch starts with the playlist visible inside Main. Remove the old separate-window message and redundant Show button.
- Nano Playlist has a compact settings menu, current next/stop and fade summary, and individual track transition menus. Global options include automatic next, Auto Stop, fades off, crossfades 3/6 seconds and Restart/Resume on Play.

## Validation

Release build, self-test, queue-test and style-check passed. Installed locally as version 0.30.0 (50), with a clean application-bundle replacement and verified code signature. UI verified early-release cancellation at 800 ms and unlock at 1700 ms, Show Playlist hide/show, detach/embed, PATCH Main/Playlist/Nano scoping and Nano Playlist settings. The playback position and queue were preserved during checks. Multi-display/full-screen combinations were not exhaustively tested. No GitHub publication in this task.
