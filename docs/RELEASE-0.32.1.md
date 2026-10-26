# Hard Play 0.32.1

- Playlist handles use native AppKit dragging with a larger three-line target. A short drag starts a move rather than moving the floating window or waiting for a long press. Existing row insertion, edit protection and Undo are preserved.
- Lock controls use native mouse events in Main, Mini, Nano drawer and Nano bottom-wheel unlock. Click locks; hold 1.5 seconds unlocks. Early release, moving away or losing key-window focus cancels the hold.
- Remove the full-control/settings lock buttons from PATCH; protection preferences remain. Queue setup protection remains available outside PATCH.
- Simplify the menu-bar controller to the track title, Previous, Play/Pause, Next and Repeat. Use the stage transport/button styles; remove Preview, routing prompts, PATCH and extra time/header rows. Click the track title to restore Main.
- Repeat cycles Off → One track → Whole playlist → Off. A context menu selects a mode directly. One-track repeat restarts at the end and suppresses automatic crossfade; manual Next still advances. Active repeat selects automatic Next behavior. Repeat is saved in app preferences and playlist files, with legacy file compatibility.
