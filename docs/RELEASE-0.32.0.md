# Hard Play 0.32.0

- PATCH sections are Audio, App, Playlists, Window. Audio opens first and contains Main/Preview routing and audition. Window contains separate Main, Mini and Nano tabs.
- Mini has a native close button. Closing a managed application window hides the workspace to the menu bar without stopping Main playback or quitting the application. Editor/menu audition stops. Quit remains explicit.
- Hover the Hard Play status icon for 0.3 seconds to reveal a compact controller. It does not hide Main/Mini. Clicking outside dismisses the transient panel. Leaving the status icon without entering the panel dismisses a hover-opened controller after 0.6 seconds.
- Menu Bar Controls is also available from the application menu (Command-3). Compact controls include transport, PATCH, return to Main and Preview.
- Menu Preview auditions the selected queue track through the explicit Preview output. It requires two available, different Core Audio device UIDs and refuses System Default for Preview. The destination name is displayed beside the button. Start validates the AVPlayer output UID; routing changes stop the audition before applying a new route. This is software device binding, not physical confirmation that a speaker is connected or emitting sound. Aggregate/virtual device UIDs may address overlapping hardware.
- Editor and menu audition stop one another when started. Main and preview volumes are independent.

After collapsing to the menu bar, activating the application again presents the compact controller. Choose Open Main Player there to restore Main. This keeps a routine reactivation from unexpectedly opening the large workspace.
