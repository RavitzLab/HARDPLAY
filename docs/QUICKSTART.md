# HARDPLAY for Mac - Quick start

**HARDPLAY Beta 5 (0.45.0)** requires **macOS 14 or later and Apple Silicon**. Intel installers are not available.

## Install

1. [Download the DMG](https://github.com/RavitzLab/HARDPLAY/releases/download/v0.45.0-beta.5/HARDPLAY-0.45.0-macOS-arm64.dmg).
2. Open it and drag **HARDPLAY.app** into **Applications**.
3. Open the app. If you are updating, quit the previous version with **Command-Q** before replacing it.

This beta is ad-hoc signed and not notarized by Apple. If macOS blocks the first launch, verify the source and use **System Settings > Privacy & Security > Open Anyway**. Do not disable Gatekeeper. Release files include SHA256 checksums.

## Play your first set

1. Drop audio files into the player or playlist.
2. Open **PATCH > Audio** and choose **Main Output**.
3. Choose a **different, available Preview Output** to audition tracks independently. Click the headphones button to play/pause Preview; hold it for **0.5 seconds** to stop.
4. Arrange your queue and set crossfades for individual transitions or the entire playlist.
5. Use **Playlist Actions > Save Playlist**. Selecting a track alone does not play it: press **Play**.

Main gives you the full workspace, Mini is a compact player, and Nano stays within reach on the desktop. All three share the same player. Menu-bar controls show Main and Preview status. Closing a player window keeps the app running; **Command-Q quits**.

## Edit a track

Open a track's context menu and choose **Quick Edit**. Zoom into the waveform, select and trim regions, join sections, or detect silence at the edges. Export a new WAV or replace the queue entry. The source file is preserved.

## Link a second Mac

1. Install the same version and load the same audio files on both Macs.
2. Connect both to the same local network; Ethernet is preferred for live use.
3. Open **PATCH > Timecode & Backup**. On Primary A choose **Create Pair**. On Backup B choose **Find Mac**, enter A's pairing code, then **Connect**.
4. Pause both players. Choose **Synchronize Set**, review the transfer direction and file match, then apply it.
5. Enable **Linked Playback on both Macs**. Play/Pause, track changes and seeks are shared. Synchronizing a set by itself does not start playback.

Set synchronization transfers playlist metadata, not audio. Main/Preview outputs and volume remain local. Test the pair with your own files and hardware: linked control is not sample-accurate output clocking, and automatic audio-output failover is not implemented.

## Before a live session

Save your set, confirm Main/Preview routing, check transitions, and test the complete playlist and linked Mac setup. Keep your original audio and a separate playlist backup. A playlist file stores references and settings, not copies of the audio.

**Mac only:** browser playback and DJ Gear are unavailable. The Mac app's Web Viewer is a read-only live status page.
