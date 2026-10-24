# Hard Play 0.28.2 — Queue Direction Label

The compact strip below the deck waveforms shows current → next queue numbers (02 → 03), rather than physical left/right deck order (03 · 02 when the right deck is current). During a crossfade it shows outgoing → incoming. A clear system monospaced font and a Track transition accessibility label distinguish this from a clock. Alternating deck positions are unchanged.

Build/self/queue/style checks pass. Installed app verified by native accessibility: Track transition: 02 to 03 while the current track remained paused on the right at 0:28. Local update; GitHub publishing unchanged.
