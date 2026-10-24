# Hard Play 0.28.5 — Playlist Window Controls

The separate playlist window now reserves space for its header and bottom controls. The scrolling queue yields height first, so Playlist, Edit, Lock and Add remain visible. Removed full-size titlebar content for this panel to keep native chrome outside its content layout.

Minimum content height accounts for the fixed hint strip. Opening the window grows a previously undersized saved frame within the display bounds. Docked playlist sizes use the same minimum plus native window chrome instead of a hard-coded 300px height. Toggling hints updates minimum height too.

Build/self/queue/style checks pass, including added geometry checks for growth, width/top-edge preservation and small-display bounds. Installed 0.28.5 in Applications, verified codesign and visually confirmed the full bottom toolbar with hints enabled and a 22-track queue. Playback position was retained; the updated player starts paused. GitHub publishing remains unchanged.
