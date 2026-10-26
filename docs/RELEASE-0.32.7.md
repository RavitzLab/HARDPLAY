# Hard Play 0.32.7

- Main transport (Previous, Play/Pause, Next) is centered. Its redundant seek/time strip is removed; deck waveform seeking remains available. Mini keeps its seek strip.
- Modes offers Next/Stop, Repeat Off/One/Playlist, Order/Shuffle, and crossfade Off/3s/6s with Apply to All. Restart/Resume choices are removed from this drawer.
- Enabling Shuffle from Modes selects automatic Next and exits Repeat One; selecting Repeat One exits Shuffle so the active policy is clear.
- Regression coverage checks stable random NEXT selection and automatic advancement from the final queue entry with Repeat Off; ordered playback still ends at the final entry.
