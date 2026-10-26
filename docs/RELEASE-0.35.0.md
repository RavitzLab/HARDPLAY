# Hard Play 0.35.0

- Crossfade duration slider: 0–30 seconds, 0.1-second increments, default 2 seconds for an unconfigured/off transition; existing active fade durations remain displayed. Quick Off / 2 / 3 / 6 shortcuts and themed Apply to This Transition / Apply to Entire Playlist buttons.
- Variable durations persist per queue occurrence, duplicate/copy and playlist save/load; legacy none/short/long settings decode unchanged. Backup manifests accept validated variable durations.
- Quick Edit → Detect Edge Silence streams decoded samples off the UI thread, scanning all channels. Default threshold −60 dB, adjustable −90 to −20 dB. Only start/end silence of at least 100ms is selected for trimming, with 20ms safety margins; internal pauses remain intact.
- Select Trimmed Audio sets visible editor in/out selection. Preview then Save as Copy or Replace in Playlist using the existing WAV export. Original audio is preserved. Fully silent files are reported without destructive trimming.
