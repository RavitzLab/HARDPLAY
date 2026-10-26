# Hard Play 0.28.8

- Main, Mini, Nano and menu-bar player presentations are mutually exclusive. Switching hides the previous player while playback continues.
- Main ↔ Mini toggle returns to Main on a second activation instead of leaving the app without a player.
- Utility panels form one editing context: opening another utility hides the previous one. Closing/minimizing the active player or switching its presentation hides utility windows without discarding editor models or interrupting exports.
- A visible docked playlist follows the Main/Mini presentation. Nano hides the playlist. Explicit separate-playlist placement remains available.
- Mini/menu-bar Lock is a compact 80 × 28 control at the top. Its color, state and three-second hold behavior match the main Lock control.
