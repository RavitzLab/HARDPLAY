# Marker typography

The UI uses unmodified BalsamiqSans-Bold.ttf, copyright The Balsamiq Sans Project Authors, under the SIL Open Font License 1.1. BalsamiqSans-OFL.txt is copied into the native app and web offline shell.

Upstream: https://github.com/google/fonts/tree/main/ofl/balsamiqsans

PermanentMarker-Regular.ttf, by Font Diner under Apache License 2.0, is bundled for the dedicated mini hardplay marker label. It adds 74,632 uncompressed bytes; its original license is included in the native app. The rest of the interface keeps Balsamiq Sans for clear track names and controls.

Fonts are registered only inside the native process; there is no system installation. The clean UI face supports Cyrillic as well as Latin. Unsupported glyphs still use platform fallback.

## Hardplay families (0.39.0)

Concept themes now use renamed, modified OFL derivatives rather than commercial-font lookups:

- **Hardplay Sans** derives from IBM Plex Sans: 97.5% horizontal outline scale plus 14 font units of tracking.
- **Hardplay Grid** derives from Space Grotesk: 104% horizontal outline scale plus 8 units of tracking. Missing Cyrillic characters (194 codepoints) are supplied from the corresponding weight of IBM Plex Sans and transformed to the same proportions.
- **Hardplay Mono** derives from JetBrains Mono: outlines are narrowed to 95.5% and recentered while original fixed advances stay unchanged.

Each family has Regular (400), Medium (500) and Semibold (600), preserved original copyrights, renamed internal family/PostScript fields and its OFL text. These are derived typefaces, not independent outlines drawn from scratch. The modified fonts remain under SIL OFL 1.1; they may be bundled with the application, and are not relicensed as proprietary fonts. The original wordmark artwork is not generated from these fonts.

`HP-PlexSans.ttf`, `HP-SpaceGrotesk.ttf` and `HP-JetBrainsMono.ttf` are retained only as recipe inputs, with their original licenses. The native bundle contains the nine **Hardplay** faces (about 1.73 MiB), their three license files, and `Hardplay-fonts.json`; it does not contain the original HP-prefixed fonts. Legacy marker presets retain their existing Balsamiq Sans/Permanent Marker resources.

To reproduce, use a local build environment, install the pinned build-only requirement from `scripts/typography/requirements.txt`, then run `python scripts/typography/build-fonts.py`. FontTools is not included in the app and is not needed for ordinary app builds. The recipe preserves Latin/Cyrillic cmap coverage, checks fixed Mono advances and writes file hashes to `Hardplay-fonts.json`.

## OFL recipe sources

- IBM Plex Sans: https://github.com/google/fonts/tree/main/ofl/ibmplexsans
- Space Grotesk: https://github.com/google/fonts/tree/main/ofl/spacegrotesk
- JetBrains Mono: https://github.com/google/fonts/tree/main/ofl/jetbrainsmono
