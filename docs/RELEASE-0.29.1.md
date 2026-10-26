# Hard Play 0.29.1

- Replace Nano's unlocked bottom wheel gesture with a regular PLAYLIST button, styled like OPEN. It toggles a dedicated compact child playlist panel. The locked state still uses the continuous three-second unlock control in the same place.
- Increase the Mini left Playback target to a visible 36 × 74 control with an icon and PLAY label.
- Header PATCH opens the complete settings window directly; remove the intermediary drawer and Open PATCH Settings step. The same header button closes PATCH on a second activation.
- Move playlist placement controls into PATCH as flat choices: Inside, Separate, Below, Left, Right and Above. Mini/Nano pinning, hints, Auto Fit and playback options live in the same pane. File operations remain in the playlist file menu.
- Remove the header question button. Enable optional anchored hover hints in PATCH. Tooltips draw above controls in a window overlay so scroll views do not clip them; near the top edge they appear below the control to stay visible. Hints reserve no layout space and do not intercept input.
- Nano lock and playlist panels are mutually exclusive and follow the player. Main/Mini top lock and Nano's three-second bottom-wheel unlock remain available.
- PATCH also includes per-track/global crossfade settings and all setup protection flags. Remove the second Protect your setup popover from the player/playlist toolbar.
