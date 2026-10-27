# Validation — HARDPLAY Beta 5 (0.44.0)

- macOS arm64 release build, model self-test, queue and style checks passed.
- Clip tests cover exact sample trim/join, original-file preservation, export cancellation, Undo/Redo, stereo edge-silence detection, internal silence retention, silent/no-edge cases, and custom fade persistence.
- Backup tests cover hashing, packages, mismatches, invalid/missing audio and variable fade durations. Network/hardware readiness is not implied by these local tests.
- Waveform checks cover deck alternation, queue starts, protection, continuous shuffle, saved start points and playlist sizing.
- Installed Main, Mini, editor and menu-bar UI were inspected. The menu-bar player uses seven equal control cells, full margins and centered Play. Crossfade slider and themed apply buttons were visually checked.
- Real-device MIDI, separate physical output routing, failover and live PA operation require testing with the intended hardware. No CPU/GPU performance benchmark was performed.
- Builds are ad-hoc signed, not Apple notarized.

- Nine curated themes and custom save/reload/update/copy/delete passed isolated preference checks.
- Back to Player and utility close navigation were checked in the installed app, including returning to Mini. Return button placement was visually checked in PATCH and Themes.
- This is validation of current local source, not a claim that every source version has a published installer or successful hosted CI run.

- Media import tests generate H.264 video with audio and check Auto extraction, AAC conversion, WAV duration, unchanged source bytes, rejection of corrupt/audio-less media and cleanup on cancellation. Optional FFmpeg fallback is implemented but was not exercised on this Mac because FFmpeg is not installed.

## Set sync — 26 October 2026

- Release build and required self/queue/style checks passed. Playlist round-trip and media import regression checks passed.
- `--set-sync-test` passed using two isolated Player instances and a real TLS-PSK localhost connection. Push and pull match files despite different paths/order, reconstruct duplicate cues, transfer titles/fades/start points/options, remain paused and support Undo/Redo.
- Missing audio, destination locking, edits after review, a playing peer and disconnect prevent pending replacement. Original audio bytes remain unchanged. Legacy hello packets decode without enabling set-sync writes.
- Existing `--backup-test` and `--backup-link-test` passed: packages, hashes, malformed/bounded frames, wrong pairing codes, role conflicts, file invalidation and heartbeat timeout.
- This is metadata synchronization. Physical two-Mac networking, synchronized playback clocks, LTC/MTC and hardware failover have not been validated or enabled by this change.
- Installed 0.36.0 UI: A/B indicator is directly left of PATCH and opens Timecode & Backup; Verify/Export is collapsed initially. Track right-click → Show in Finder opened Finder with the exact source WAV selected. The existing user queue and paused position survived the update.

## Linked Playback — 27 October 2026

- `--linked-playback-test` uses two real, muted AVPlayers and a TLS localhost pair. Play/Pause from either Mac, seek, Next/Previous, primary-driven automatic Shuffle, explicit arming on both Macs, lock rejection and disconnect continuation passed.
- Set sync remains independent by default; one-sided arming never starts audio. A configuration edit before the throttled observer runs prevents arming immediately.
- Required build/model/queue/style checks and set-sync regression passed. This is LAN transport/state following, not a sample-accurate audio clock or measured physical two-Mac synchronization guarantee.

- Installed 0.36.1 verified by codesign and Info.plist; Timecode & Backup shows the separate Linked Playback switch, current status and both-Mac version requirement. The existing paused queue and position were preserved.

## Exit isolation — 0.36.2

- Real muted AVPlayer/TLS tests passed for normal exit of Backup B and Primary A: the other player keeps playing. Network disconnect independently preserves both local players.
- Explicit UI and MIDI toggles are separate from internal pause/lifecycle calls. The linked-playback-v2 capability requires both peers to support exit protection.
- Final release/model/queue/style and linked-playback tests passed locally. Physical two-Mac clock accuracy is still unmeasured.

## Sync timing, audio controls and PATCH — 0.37.0

- Release build and required model/queue/style checks passed. Real muted AVPlayer/TLS linked-playback tests pass with clock offset/RTT arithmetic, jitter outliers, stale measurements, bounded correction, explicit jump suppression, finite manual-offset clamping, and disconnect/exit isolation.
- Set-sync and encrypted-link regressions passed: push/pull, original-file preservation, malformed messages, wrong pairing codes, role conflicts and heartbeat timeout.
- Audio routing checks passed for independent outputs, persisted quality choice, AVPlayer algorithm binding and read-only hardware capability queries. The built-in output reported 48 kHz, a 512-frame buffer and two channels. No sample rate, buffer or channel setting was changed by tests. USB driver writes and independent per-app channel matrices are not validated or claimed.
- Installed UI inspection confirmed wider controls and neutral paused/NEXT decks, PATCH category navigation, actual audio settings, and the Sync Timing section. The saved narrow PATCH geometry was identified and explicitly enlarged on opening.
- Clock timing is an estimate of player timelines assuming similar network travel in both directions. Two physical Macs, hardware output latency, scheduled common hardware starts and acoustic alignment remain unverified/unimplemented as described in the release notes. No new runtime dependencies or large raster controls were added; no formal CPU/GPU benchmark was performed.

## Direct PATCH navigation — 0.37.1

- Required release build/model/queue/style checks passed.
- Installed app UI verified: selecting Themes & Appearance immediately shows theme presets and color/size controls in the same Hard Play PATCH window; Keyboard & MIDI shows assignments directly, Backup shows Connect/Linked Playback/Measure Sync, and Web Viewer shows its sharing controls. The PATCH sidebar and Back to Player remain present; no intermediate Open page or extra utility window is invoked by section selection.
- Theme, mappings, network connection and Web Viewer sharing settings were not changed during navigation checks. The user's paused cue remained at 0:38.

## Concept themes — 0.38.0

- Release/model/queue/style checks passed with thirteen built-in presets. Each of the four new presets round-trips its semantic panel, waveform, grid and secondary-text colors through JSON and saved custom-theme preferences in an isolated defaults suite.
- All six bundled concept fonts register successfully within the process. The supplied logo's bytes match the prior source checkout.
- Installed 0.38.0: the four new presets are visible in PATCH → Themes & Appearance. Studio Precision was applied and inspected in Main with the existing two decks, controls and queue. A screenshot is retained locally outside the public source export. No user audio was started during this appearance check.
- Main/Mini/Nano/menu-bar use the shared theme tokens; this turn did not manually exercise every combination of all five window layouts and eight interaction states for each of the four themes. No CPU/GPU benchmark was run. Typography substitutions and shared safety colors are described in CONCEPT-THEMES.md.

## Additional themes, header and Hardplay fonts — 0.39.0

- Release/model/queue/style checks passed for twenty-one presets. All twelve concept presets round-trip semantic colors; nine Hardplay faces register successfully in macOS across Regular/Medium/Semibold.
- FontTools verifies renamed family/PostScript metadata, file hashes, Latin/Cyrillic cmap coverage and fixed Mono advances. Grid adds 194 missing Cyrillic codepoints from the corresponding OFL source. The fonts are modified OFL derivatives; source copyrights and licenses are retained. No commercial-font lookup remains in concept typography.
- The final app bundle contains the nine Hardplay font files, three derivative licenses and hash manifest, without old HP-prefixed font resources. A clean bundle replacement was required to remove those old resources; installed codesign verification then passed.
- Installed Main and Mini inspected: original logo centered without overlap; Minimize/Hints on the left. PATCH uses an arrow-only Back action; eight additional presets are present in the model and theme picker. Paused screenshots retained locally outside public source. Red playback tint follows shared Player.playing in both headers; this turn did not run user audio solely for a color test.
- White/Signal White definitions use darker grey panel/background values, and light decks no longer overlay a near-white gradient. Existing custom themes are not rewritten. No performance benchmark or all-state/all-layout screenshot matrix is claimed.


## Color editing and Mini header — 0.40.0

- Twenty stock presets; FOH removed from the picker. Custom theme entries remain available.
- Adjacent color popovers expose all semantic colors in every preset. Background, panels, surfaces and playlist tape support two-stop gradients with angle control; text, waveform and border colors remain solid for legibility.
- Persistence checks cover every color slot, gradient custom-theme reload, gradient removal and legacy themes without gradient fields. Model, queue and style checks run with the release build.
- Nano shell/display and secondary labels follow theme tokens. Native drag-handle branding observes playback and theme changes. Fixed safety/status colors remain intentional.
- Gradients use native static SwiftUI fills. No additional runtime dependencies or animated textures were introduced; no performance benchmark was run.

- Installed 0.40.0 (87) in /Applications. Strict code signature verification passed and the installed executable matches the release build. Visual QA confirmed the Mini header layout and an anchored Playlist tape editor, including gradient stops/angle and live tape-color application. Screenshot: local QA artifact, excluded from source export.
- Nano logo repaint is connected to the shared playback publisher; active playback tint was not manually exercised in this pass. User changed themes during QA, so the latest selected theme was retained.


## Theme curation — 0.40.1

- Fifteen built-in presets remain. Tape Blue, Tape Black, Stage, Cables and Minimal are hidden; a stock retired selection migrates to Studio Precision. Named custom themes are preserved. The reset control also selects Studio Precision.
- Digital Underground uses subdued warm yellow/sand accents with dark warm charcoal panels, replacing acid green. Migration replaces only matching old factory colors and retains user overrides. Regression checks cover retired stock selection fallback and preserving an overridden tape color during Digital Underground migration.

- 0.40.1 (88) installed and launched after user-approved restart. Strict signing and installed/build executable comparison passed. Release/model/queue/style checks passed. UI was actively changing during verification; the latest user-selected theme was left in place.


## Nano sizing — 0.40.2

- Minimum Nano shell width increases from 344 to 384 points (visible face 180 → 220). The existing size clamp expands older narrow saved frames at launch; larger manual sizes remain intact.
- Nano playlist panel width increases to 360 points, list viewport to 320 points, track titles to 12 points. Screen-bound placement remains clamped to the current display and opens on the available side of Nano.
- Existing model self-test covers the updated minimum and unchanged maximum Nano sizes; release build also runs model, queue and appearance checks.

- Installed and launched 0.40.2 (89) after explicit restart approval. Strict signature verification and executable comparison passed. Visual QA confirmed the wider Nano face and larger adjacent playlist with visible controls and current-track highlight.


## Live control contrast — 0.40.3

- Reproduced black sorting, Fade/action menus and reorder handles on a dark main window. Main hosting content retained a light preferred scheme captured during initial creation; native borderless menus and native reorder views relied on system label ink.
- Hosting boundaries now observe appearance changes. Borderless menu labels/tints use explicit theme text, while native reorder handles observe the shared theme and use secondary ink. Applies to Main, Mini, Nano, menu-bar and utility windows.
- Style checks enforce at least 4.5:1 contrast for control/menu text and 3:1 for reorder ink against each preset background, panel and control surface across all fifteen presets. Disabled controls intentionally remain muted; arbitrary user-created gradients/transparent backgrounds are not guaranteed by these stock-palette checks.
- Offline gallery command: `HARDPLAY --theme-controls-gallery /path/to/output`. Renders shared control styles using isolated appearance preferences; this is not a substitute for testing native popup menus in the running app.

- 0.40.3 (90) installed after explicit restart approval; strict signature validation and installed/build executable comparison passed. Release, model, queue and all-preset contrast/style checks passed. All fifteen shared-style gallery images were visually inspected.
- Live macOS verification on Brutalist Play confirmed restored sort icon, native reorder handles, Fade labels/chevrons and action icons; the native Fade popup is readable. Main, Mini and Nano controls were visually checked. Main and Nano screenshots are retained locally outside the source export. No user theme/queue/audio settings were changed during verification.


## Horizontal wordmark — 0.41.0

- Added the approved horizontal wordmark as a separate bundled source, retaining original stacked artwork for the app/status icons. A static alpha mask preserves glyph geometry; only the two Play silhouettes receive red during playback. Theme text ink remains on other letters.
- Shared live branding is used by Main, Mini, Nano, menu-bar player, separate playlists and utility navigation. Main/Mini wordmarks are sized for available header space; no transport actions were replaced.
- Native images are cached by ink/size/playback state with a 64-entry limit. Nano drag-handle drawing invalidates only when ink or playback state changes.
- Style checks include wordmark proportions and pixel probes for both red triangles, unchanged H and the adjacent Y. Pixel probes scale for Retina rendering. Standalone render commands: `--render-wordmark` and `--render-wordmark-active`, followed by an output PNG path.

- Installed 0.41.0 (91) after explicit restart approval. Strict signing and installed/build executable comparison passed. Model, queue, all-preset contrast/style and logo pixel checks passed.
- Live playback visually verified horizontal lettering with only red Play symbols in Main, Mini, Nano and menu-bar player. Main/Mini/Nano headers fit without overlap. Playlist and utility headers use the same shared view; these were not all separately exercised during this pass. User actively switched tracks/themes during QA; no playback commands or settings changes were made by QA after restart.


## Stacked wordmark restoration — 0.41.1

- Restored supplied HARD-above-PLAY artwork in the shared window wordmark, retaining independent red Play silhouettes during playback and theme ink while paused.
- Main/Mini return to the earlier 62×34 / 44×26 header frames. Nano uses a 46×24 stacked mark; playlist and utility headers use corresponding compact proportions.
- Adapted raster probes for both stacked Play symbols and unchanged H/Y ink. Removed the unused horizontal PNG from the app bundle and public-source export; the original approved preview remains local.

- Installed 0.41.1 (92) after explicit restart approval. Strict signature validation and executable comparison passed. Release/model/queue/style tests passed, including both triangle centers/edges and unchanged H/R/Y samples. Main and Nano stacked layout visually verified while paused; active colors verified by native raster tests. Audio and playback settings were retained.


## Coordinated window sizes — 0.42.0

- Each player/playlist/utility role has independent Small (0.84), Optimal (1.0), Large (1.18) sizing. A fixed logical canvas is uniformly scaled, keeping font/control proportions together. Large is reduced uniformly if needed to fit the current display. Full-screen presentation remains separate from normal window sizing.
- Main has bounded vertical/wide layouts; hiding the inline playlist switches to a shorter canvas. Removed the old measured-content resizing path and theme-specific text/button/spacing controls; legacy custom values remain persisted, with stable layout metrics used for rendering.
- PATCH → Window chooses the target role and size; Nano also has a size menu in its lower corner. Existing Auto Fit mappings now cycle Small/Optimal/Large for the active player.
- Geometry regression checks cover twelve roles × three sizes × three display bounds × both playlist/wide states (432 cases), preserving aspect ratio and screen bounds. Independent preference reload is checked in an isolated defaults suite. Model, queue, theme contrast and branding tests remain part of the build.
- Attached short-lived control/color popovers retain intrinsic layouts. Real utility windows can overlap if several windows cannot fit the physical display; uniform scaling does not promise simultaneous tiling of every window. No hardware timing or audio changes are part of this work.


## DJ and Nano controls — 27 October 2026

- Experimental independent DJ engine: offline PCM render covers 48/44.1 kHz decks, held Cue return, Hot Cue set/play/delete, PCM looping, pitch units, Bend, four aligned stem files with Mute/Solo, Slip release, and phase arithmetic. Fixture bytes are unchanged and test preferences are isolated.
- Nano custom controls have their own persisted assignments and reuse validated Trigger / Toggle actions. DJ opens from the right drawer, PATCH → App, or the macOS Hard Play menu.
- Sync requires manually entered/tapped BPM and a user-set first beat; it aligns once. No automatic beat analysis, AI stem separation, vinyl scratch, DJ HID / MIDI mapping, separate DJ headphone mix, or DJ backup following is claimed.
- Hardware latency, physical stem alignment, seamless live loading, long performance stability and CPU/GPU/memory benchmarks remain unverified. DJ is not equivalent to hardware CDJ-3000 transport.

- Installed 0.43.0 UI: right-edge Nano panel opens, Add Control creates a button, its menu exposes Trigger / Toggle and removal, and DJ opens from the drawer. The temporary test button was removed. Final DJ header, both decks and bottom mixer controls were visually inspected; a real playlist track was observed running on deck A. No long live-performance or external-hardware certification is implied.

## Shared player controls — 0.43.1

- The right-edge drawer is available in Main, Mini, Nano and DJ. A weak hosting-window reference controls attachment and following; switching player surfaces detaches and closes the panel. Existing saved Nano assignments remain shared without migration.
- Release/model/queue/style and offline DJ audio checks passed. Installed Main drawer and its assignment menu were observed. Mini and DJ use the same native hosting-window edge implementation; their individual interaction paths were not manually exercised in this pass.


## Inline playlist audition — 0.43.2

- Release/model/queue/style and DJ offline render checks passed. Preview gesture checks cover short tap, 0.5-second hold, one Stop without an extra tap, cancellation, and finite bounded seek.
- `--playlist-preview-test` passed with a silent 48 kHz WAV and zero preview volume, separate connected Mac/Scarlett outputs, isolated route preferences: Pause retains track/position, paused seek does not start playback, Resume advances, Stop clears the audition, an unsafe same-output route change stops/refuses playback, and original file bytes remain unchanged. No hardware sample-rate/buffer/channel settings were changed.
- Installed Main UI showed the title replaced by Preview output/time and a waveform; paused audition retained the waveform at a sought position. A 650 ms native button hold restored the title and headphones. Main transport remained separate. Mini, detached and Nano queues share this component; those layouts were not individually exercised during this pass.


## Preview UI performance — 0.43.3

- Live 0.43.2 samples showed the main thread repeatedly running NSHostingView content-size constraints, NSWindow frame changes and WindowPresentation.requestFit → WindowSizes.applyAll. A three-second process CPU delta measured 80.6% of one core; this also affected paused UI.
- Profile-sized hosting views/controllers now disable automatic sizing constraints. Window size application is idempotent and resize notifications no longer enqueue another Auto Fit. Regression: 100 unchanged fits produce zero resize events.
- Preview progress publishes separately from row state; native waveform/time updates do not re-evaluate SwiftUI playlist layout. Identical played-bar pixels are not redrawn between bar changes. Unchanged main waveforms do not invalidate cursor rectangles.
- Release/model/queue/style, fixed-layout and offline DJ checks passed. Silent separate-output Preview tests also passed and assert no playlist-row state broadcasts while progress advances. Play/Pause, paused seek, Resume, Stop and unsafe route refusal are retained.
- Installed build 99 was observed playing Preview on Scarlett. A short three-second CPU delta measured 10.9% of one core. Interactive state and cold/warm caches vary; this is a local diagnostic comparison, not a general performance benchmark or latency guarantee. No hardware settings or user playlist were changed by the tests.


## Native controls and branding — 0.43.5

- Crash report for 0.43.4 (102) points to DJHoldButton.Pad.draw → NSString.size(withAttributes:) → CoreText ApplyFont, ending in a nil dictionary-object exception. DJ captions now use native text fields and concrete sRGB theme colors; the old measurement/drawing path is removed. The precise CoreText internal trigger is not established by the report.
- A native bitmap regression check exercises DJ captions across every stock theme and enabled/disabled/held states.
- Main and Preview logo triangles have independent pixel checks in all four combinations. Preview buttons retain a headphones outline with a playing/paused/stopped glyph. The 0.5-second hold-stop interaction is unchanged.
- Header drag targets cover the empty Main/Mini header and Nano top row, respecting position locks. Live CUA drags changed the Main and Mini header targets to their new window positions; Nano uses the existing manual drag path.

- Installed 0.43.5 (103) in /Applications; strict codesign passed and installed executable matches the built artifact. DJ opened with both decks and native Cue/Bend/Hot Cue captions, with no crash during this check.
- Live playlist Preview on the configured Scarlett output: one click played, second click paused retaining the waveform, 650 ms held click stopped and restored the title. Main stayed paused at its existing cue; HARD triangle lit for Preview and returned to normal on pause. No user routing or queue entries were changed.


## Nano left drawer — 0.43.6

- Mandatory release/model/queue/style/fixed-layout/DJ checks passed. Installed 0.43.6 (104), strict signature verified and installed executable compared against the build.
- Live Nano: the bottom size menu is absent; tapping the left display edge opens the adjacent panel. Small, Optimal and Large each update the selected state; Large was restored to the user's original choice. The drawer and player render without cropped controls. Closing the drawer leaves Nano open. Main and Preview remained paused at the existing cue.
- No new assets, dependencies or continuous timers were added. DJ feature development is deferred.


## Beta 5 publication preparation

- Release label: HARDPLAY Beta 5; macOS version 0.44.0, build 105; prerelease tag v0.44.0-beta.5.
- Web edition: build, all 28 Node tests and ESM/offline routing validation passed. Curated source audit covers 166 allowed files.
- GitHub source publication and installer availability must be verified separately from these local checks.

- Beta 5 extended native checks passed: playlist, media import, backup manifest, TLS pairing, metadata push/pull, timing diagnostics and linked Play/Pause/seek/skip on local loopback. These do not establish physical-output synchronization accuracy.
- Release DMG and ZIP SHA256 checks passed; bundle release title HARDPLAY Beta 5 and tag v0.44.0-beta.5 were read back from Info.plist.
