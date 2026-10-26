# Hard Play 0.29.0

- Nano lock drawer reduced to 140 × 148 points, with only pin, lock, close and a short unlock hint.
- Bottom wheel button opens a compact playlist when unlocked. Track selection and explicit Play remain separate. Holding it for three seconds still unlocks locked controls.
- Nano display now shows an editable outgoing transition: Next/Cut, Next/3s, Next/6s or Stop. Existing early-stop offsets are reflected in the display; choosing Stop at end resets that offset to zero.
- Replace the permanent hint strip with optional native tooltips near controls, enabled by the question button. Hints reserve no player height.
- Small wordmark under the question button. Main toolbar retains Mini, Nano, help, PATCH and minimize; window sizing, full screen, menu-bar attachment and Undo remain in PATCH or existing menu/keyboard commands.
- Playback controls now open in a separate panel to the left of Main/Mini instead of consuming deck width. When there is room, the player moves as a whole to make space; its size stays unchanged. Closing restores its prior position if it has not been moved since. On displays too narrow for both windows, the panel remains within visible bounds and does not resize the player.
