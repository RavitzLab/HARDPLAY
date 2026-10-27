# Concept themes

Select a preset in **PATCH → Themes & Appearance**. Existing presets and saved custom themes remain available. The four additional presets share the existing controls and responsive layout; they do not add timecode, cue or playback capabilities.

| Preset | Background / panel / raised | Text / secondary | Accent / waveform | Grid | Radius / spacing | Fonts |
| --- | --- | --- | --- | --- | --- | --- |
| Studio Precision | #10151A / #1B242C / #25323C | #E4EBF0 / #A7BAC6 | #3D9DC8 / #70B7D9 | #33434D | 5 / 12 pt | Hardplay Sans; Hardplay Mono technical labels |
| Modular Grid | #0D1012 / #15191C / #202629 | #E9EBE8 / #9BA4A5 | #B7C848 / #B7C848 | #343C40 | 2 / 12 pt | Hardplay Grid; Hardplay Mono technical labels |
| Timecode Core | #0A0D11 / #171D23 / #222B34 | #EDF0F3 / #A0AAB4 | #E43A43 / #E43A43 | #303A44 | 4 / 10 pt | Hardplay Sans; Hardplay Mono technical labels |
| Shadow System | #07090B / #111416 / #1C2023 | #DCE1E4 / #8B939A | #889AA6 / #889AA6 | #292F34 | 10 / 16 pt | Hardplay Sans; Hardplay Mono technical labels |

The source's dim Modular Grid color #636B6C is reserved for disabled/decorative content; secondary readable labels use #9BA4A5. All four surfaces are opaque by default, and Main/Mini opacity remains user-adjustable. Panel, control-surface, waveform, grid and secondary-text colors can be customized and saved with the preset.

## Type and brand

Track titles use semibold where the existing component requests it; body labels retain regular/medium hierarchy. Timers use fixed-width digits, and controls preserve existing minimum sizes. Nine Hardplay font faces are bundled (about 1.73 MiB uncompressed); see [font sources, modifications and licenses](../assets/fonts/README.md). These are modified OFL derivatives, not renamed commercial fonts or a claim of independently drawn outlines. No Satoshi, Neue Montreal, Druk, DIN 2014, Eurostile or Neue Haas lookup remains in the concept-theme implementation. Characters outside supplied coverage may use the normal platform fallback.

The original supplied HARDPLAY artwork, its letters, Play geometry, aspect ratio and arrangement are unchanged. Only its existing template tint continues to follow the UI. New concepts use crisp system symbols where available and single-stroke cached custom icons otherwise; older marker themes keep their original icons.

## Shared window configurations

| Configuration | Theme behavior |
| --- | --- |
| Main wide | Two symmetric deck panels, centered Play, colored sounding waveform, neutral next deck, grid-aligned queue |
| Main medium | Existing responsive deck/queue layout and equal control groups retained |
| Mini / narrow | Same tokens and fonts; compact controls and row actions stay accessible |
| Nano floating vertical | The existing wheel remains; display and waveform use the theme's panel and accent |
| Menu-bar popover | Same opaque backdrop, typography, waveform and equal transport cells |

Layouts keep the existing responsive breakpoints. These are four styles for the existing application, not independent screen mockups or rewritten navigation flows.

## Interaction states

| State | Appearance / behavior |
| --- | --- |
| Play | Theme waveform and speaker status show the sounding deck; timer advances |
| Pause | Neutral status and static waveform position; playback position is preserved |
| Next | Neutral preview with existing NEXT label; never gains seek/play behavior from the theme |
| Locked | Existing safety lock and dimming; unlock duration and protection behavior unchanged |
| Selected | Existing queue selection fill/outline tinted by the theme; current cue retains its dot |
| Hover | Thin accent control outline; queue hover surface and existing tooltips retained |
| Disabled | Reduced contrast/opacity; action remains disabled |
| Active | Accent-tinted control surface and outline; pressed state uses a small opacity change |

Studio, Modular and Timecode use sparse, static vector grid marks; Shadow has no texture. Deck/control surfaces use flat fills and thin borders. There are no new raster backgrounds, shader effects, animation loops, external font services or runtime dependencies. Existing waveform/playback animation is unchanged. No formal CPU/GPU benchmark is claimed.

## Additional presets — 0.39.0

| Preset | Background / panel / surface | Text / secondary | Accent / waveform | Grid | Radius / spacing (pt) | Typeface implementation |
| --- | --- | --- | --- | --- | --- | --- |
| Hard Minimal | 0B0D0F / 15191D / 20262B | F5F6F7 / 929BA4 | DDE4E9 / DDE4E9 | 343A40 | 3 / 12 | Hardplay Sans + Hardplay Mono |
| Brutalist Play | 090909 / 171717 / 242424 | F5F5F1 / 929292 | E3443C / F5F5F1 | 4A4A4A | 0 / 10 | Hardplay Grid + Hardplay Mono; deck numbers 36 pt Main / 30 pt Mini |
| Premium Dark | 101316 / 1C2227 / 2A3239 | F1F3F4 / 9BA5AE | 91B4C7 / B8D1DE | 3A434B | 12 / 16 | Hardplay Sans + Hardplay Mono |
| Digital Underground | 10100D / 1B1B15 / 28271E | E5E1D3 / ABA58E | B5A163 / C0AF78 | 3D392B | 3 / 12 | Hardplay Grid + Hardplay Mono |
| Grid Motion | 0B1014 / 182027 / 25323C | EBF0F2 / A3B6C0 | 65B7D4 / A4DDEA | 354650 | 6 / 14 | Hardplay Grid + Hardplay Mono |
| Noir Vinyl | 08090B / 17191C / 222529 | F2F0EB / 999B9E | C4C7C8 / C4C7C8 | 373A3D | 14 / 16 | Hardplay Sans + Hardplay Mono |
| Rave Terminal | 040804 / 0B140B / 132010 | D8E7CE / 9BB690 | B9FF00 / B9FF00 | 24461E | 0 / 10 | Hardplay Mono |
| Steel Play | 141619 / 2A2E33 / 343B42 | ECEFF0 / B5BBC0 | FF8B2A / FF8B2A | 50575E | 5 / 12 | Hardplay Sans + Hardplay Mono |

These presets reuse the Hardplay families described above. Commercial reference faces are not redistributed or used as installed-font lookups. Steel's #656C72 metal tone is kept as a secondary/tape token instead of filling every button, to keep glare down. Low-contrast inactive greens/greys are reserved for nonessential graphics; secondary text uses the brighter values listed above.

All twelve concept themes use the existing responsive layouts, time labels (10 pt deck / 9 pt Nano baseline), 14–16 pt track titles and minimum transport sizes. Line wrapping remains two lines in decks and flexible in compact playlist rows. Borders are 0.5–1 pt; pressed/active/hover/disabled states share the earlier state table. Grid Motion uses existing short control reactions rather than a new animation loop. Noir/Steel add only two static Nano wheel rings. The underlying source logo is unchanged.

White now uses a grey-blue #DCE3E9 background and #D2DBE3 deck panels; retained legacy Signal White uses #DCDDD7 / #D0D4CE. Light decks no longer add a near-white gradient. Untouched old built-in White backgrounds migrate while preserving sizes/opacity and other adjustments; saved custom themes remain unchanged.

Main and Mini show the original centered wordmark. Its tint becomes #D63840 while the shared player is playing, and returns to the theme text color while paused. Minimize and Hints are in the left group, leaving the wordmark clear. The utility return control is an arrow-only Back button with a tooltip and accessibility label; it keeps the original return-to-player behavior.
