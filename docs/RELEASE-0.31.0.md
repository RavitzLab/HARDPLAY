# Hard Play 0.31.0

## Independent Main and editor Preview outputs

Open PATCH → App → Audio Outputs. Main Output routes the playlist and both crossfade decks. Preview Output routes Preview Selection and Option-hover audition in Editing; the same Preview Output picker is also next to the preview controls in the editor.

Choose a USB audio interface for Main and Mac speakers or another interface for Preview. Choices persist by Core Audio device UID. System Default follows the macOS default output. Device enumeration refreshes every second. An unavailable selected device remains selected, shows a warning and is muted when detected; it is not intentionally replaced with another device. Reconnecting restores that route.

Editor preview can run alongside Main when both routes resolve to different available devices. On the same device, pause Main first. Volume controls remain independent. This selects output devices, not individual channel pairs on a multichannel interface.

Uses AVPlayer.audioOutputDeviceUniqueID, documented by Apple: https://developer.apple.com/documentation/avfoundation/avplayer/audiooutputdeviceuniqueid
