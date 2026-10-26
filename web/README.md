# Hard Play Web

An offline-capable browser audio player. This is a separate edition: native Mac windows, themes, audio routing and keyboard behavior are documented in the [main README](../README.md), and are not all reproduced in the browser.

## Start and prepare for offline use

1. Open your deployed app through **HTTPS** (or localhost during development). Wait for **App saved**.
2. Use **+ → From Mac / Direct link / Google Drive / Dropbox**, or drop audio into the player or detached playlist.
3. For cloud files, wait for **Saved offline** on every track. The footer offers **Download all cloud tracks** and **Keep offline storage**.
4. Test the full queue with the connection disabled before relying on it for a set.
5. Keep the same browser profile and device. Clearing site data, private browsing or browser storage eviction can remove saved audio. Persistent storage is requested, not guaranteed.

Install with the browser's app menu when available. Safari on macOS 14+ offers **File → Add to Dock**. Installing the browser edition does not grant native menu-bar access or global macOS shortcuts. Keep the host app/page running for audio.

## Playback and playlists

- Select a row without autoplay; use its separate Play button. The main transport controls the same queue.
- Set fades per outgoing item: Off, 3 seconds or 6 seconds. Apply to All copies the setting across the queue. Two decks show overlap and gains.
- Next/Auto Stop, Restart/Resume, stop-before-end, master volume, Repeat and Shuffle are available in this edition's playback settings.
- Right-click a row for Duplicate, Play, Rename and Timing. Copies are independent queue entries; removing one leaves the others playable.
- Timing accepts Full Track, seconds or `m:ss`. It is an end point from the beginning of the item, capped to the source length. The total includes copies and crossfade overlap; Shuffle is an estimate and Repeat has no fixed end.
- Save/Open Playlist stores metadata, links and settings, **not the audio**. Local files must be added again on another device; cloud files must be cached there separately.
- Undo/Redo retains up to 30 edits in the current session. Reloading resets history. Exported files and transport actions are not undone.

## Windows and appearance

Wide Layout places playback and playlist side by side in a wide browser window. My Set toggles the queue; Below/Right/Left/Above and Separate Window change its placement. Keep the original player page open when using a detached queue.

Mini Player uses Document Picture-in-Picture where available, with an in-page fallback. Pocket Player is a draggable companion **inside the page**. It cannot float independently on the macOS desktop or survive quitting its browser.

Settings and Themes offer a live preview of colors, opacity, button/text size, spacing, corners and scenic texture. These preferences belong to this browser profile. The browser theme catalog differs from the Mac app.

Enable control hints in settings. Setup protection blocks selected groups; full Lock protects transport while audio continues. For the web Pocket Player, tap the left bezel for Position/Controls and hold the unlock control for about one second. This differs from the native app's 1.5-second unlock.

## Keyboard and MIDI

Open Settings → Keyboard / MIDI (Shift-M), enable Map, select an action and send a key or MIDI signal. Trigger fires once; Toggle switches a supported state. Save/Open control sets. Continuous MIDI CC can control volume.

Keyboard shortcuts need browser focus and are not global macOS shortcuts. MIDI depends on browser support, permissions and the attached controller. Check mappings with the intended hardware before live use.

## Cloud and storage boundaries

- Local audio is not uploaded. Files are cached as IndexedDB blobs after the complete download succeeds.
- Direct links need server CORS permission. Drive/Dropbox public downloads use a restricted proxy, which does not store files or bypass authentication, passwords or download restrictions.
- There is no OAuth/private cloud account browsing, cloud upload or cross-device library sync.
- A file is limited to 1 GB. Unsupported codecs, login HTML and partial downloads are not marked ready. Codec support comes from the browser.
- Signed source URLs may contain access tokens: keep exported playlists private.
- Service-worker updates wait for existing app windows to close. Reopen online to obtain an update. If an older worker serves an earlier interface, `/app/` is an alternative entrypoint on the same origin; clearing site data is not needed.

## Build, test and run locally

Requires **Node.js 22+**. No third-party dependencies or global installation:

```sh
cd web
node scripts/build.mjs
node --test tests/*.test.mjs
node scripts/validate-artifact.mjs
node scripts/dev-server.mjs
```

The development URL is **http://localhost:4173**; `PORT` overrides it. Only the dev server supplies generated silent WAV fixtures under `/qa/`. No personal recordings are included or deployed.

The build creates `dist/server/index.js`, a self-contained ESM worker serving the app and allowlisted `/api/cloud` route. A source checkout builds without hosting credentials or a project identity. A local ignored `.openai/hosting.json` may configure an existing deployment; otherwise generated metadata is empty. Publishing source to GitHub does not deploy a website.

The cached artwork and font under `public/` are runtime assets; retain their license notice. Native and web audio libraries remain separate.
