# Hard Play 0.33.3

- Open Playlist moves to the top toolbar in Main and Mini. When the inline playlist is hidden, the complete playlist toolbar/name/actions/Fade row is hidden too.
- Toggling the inline playlist enables content fitting. Main removes the old fit-height padding; Mini measures actual content instead of fixed 800/580px heights.
- Decks and player content have symmetric margins. Scroll indicators no longer reserve an extra visible right gutter in the player/queue.
- Repeat and Shuffle move left of transport; Volume follows Shuffle. Previous/Next have larger Main targets and Play remains centered. Compact controls fit Mini's minimum width.
- Playlist toolbar uses three non-overlapping regions: left controls, centered title, right actions. Narrow layouts use an icon-only Fade and keep window/setup options in Playlist Actions.
- Bundle startup explicitly references HardPlayWordmark.icns. Legacy AppIcon/HardPlayIcon resources are removed, and the runtime icon is initialized before the application event loop.
