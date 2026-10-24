# Hard Play 0.28.3 — Remaining Track Time

The strip below the waveforms displays Remaining M:SS, calculated from the current track's duration minus its playback position, clamped at zero. Queue-number pairs are removed from this strip entirely. The same player layout is used by Main and Mini. Existing waveform timers and seek inspection are retained.

Build/self/queue/style checks pass. Build is ready locally; applying to the running app awaits a playback-safe restart approved by the user.
