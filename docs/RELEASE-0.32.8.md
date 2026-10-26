# Hard Play 0.32.8

- Track start-time dialog now has Save, Cancel and Start immediately, with Next playback only / Every playback scope. Saving never starts audio.
- Start points are stored per queue occurrence and in saved playlists, restored across launches, preserved by duplication and backup packaging, and applied to manual/automatic playback, Shuffle and crossfades. One-shot points are consumed when playback starts, not during paused loading or decoder preparation. Clear start time removes the setting; Undo restores it.
- Mini playlist rows prioritize the track name, wrap long names and show the full name on hover. A compact ellipsis button opens Play, Preview, crossfade and track settings.
