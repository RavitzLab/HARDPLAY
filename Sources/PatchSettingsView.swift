import SwiftUI

enum PatchWindow:String,CaseIterable,Identifiable {
    case audio="Audio",app="App",themes="Themes & Appearance",mappings="Keyboard & MIDI",backup="Timecode & Backup",web="Web Viewer",playlist="Playlists",window="Window"
    var id:String {rawValue}
}
typealias PatchPlayerWindow = SizedWindow
final class PatchWindowState:ObservableObject {
    static let shared=PatchWindowState()
    @Published var selected:PatchWindow = .audio
    @Published var window:PatchPlayerWindow = .main
}
struct PatchSettingsView:View {
    @ObservedObject private var conceptAppearance=AppearancePreferences.shared
    @ObservedObject private var context=PatchWindowState.shared
    @ObservedObject private var player=Player.shared
    @ObservedObject private var hints=HintPreferences.shared
    @ObservedObject private var setup=SetupLock.shared
    @ObservedObject private var sizes=WindowSizes.shared
    @ObservedObject private var windows=WindowPresentation.shared
    @ObservedObject private var placement=FloatingPlacement.shared
    @ObservedObject private var playlist=PlaylistWindowState.shared
    @ObservedObject private var workspace=WorkspaceState.shared
    private var transitionTrack:Track? {player.current ?? player.selectedTrack ?? player.tracks.first}
    private var location:String {playlist.detached ? (playlist.edge?.rawValue ?? "separate"):"inside"}
    var body:some View {
        HStack(alignment:.top,spacing:18) {
            VStack(alignment:.leading,spacing:7) {
                Text("PATCH").font(.stage(size:22)).padding(.bottom,10)
                ForEach(PatchWindow.allCases) {item in
                    Button {context.selected=item} label:{Text(item.rawValue).font(.stage(size:12)).frame(maxWidth:.infinity,alignment:.leading).padding(9)}
                        .buttonStyle(PlayerControlStyle(active:context.selected==item)).accessibilityLabel("PATCH · "+item.rawValue).stageHint("Open "+item.rawValue+" settings")
                }
            }.frame(width:156)
            Divider()
            selectedContent.frame(maxWidth:.infinity,maxHeight:.infinity,alignment:.topLeading)
        }.font(.stage(size:12)).padding(.vertical,4).frame(minWidth:660)
            .onChange(of:context.selected) {old,new in if old == .mappings && new != .mappings {ControlMappings.shared.mapping=false}}
            .onDisappear {if context.selected == .mappings {ControlMappings.shared.mapping=false}}
    }
    private var playlistSettings:some View {
        VStack(alignment:.leading,spacing:16) {
            section("PLAYLIST POSITION") {
                Picker("Placement",selection:Binding(get:{location},set:setLocation)) {
                    Text("Inside player").tag("inside");Text("Separate window").tag("separate")
                    Text("Below player").tag("bottom");Text("Left of player").tag("left")
                    Text("Right of player").tag("right");Text("Above player").tag("top")
                }.pickerStyle(.radioGroup).labelsHidden().accessibilityLabel("Playlist Placement")
            }
            Text("Playback, crossfades and Undo are in the playlist actions drawer → Playlist Settings.").font(.stage(.callout)).stageSecondary()
        }
    }
    private var audioSettings:some View {
        VStack(alignment:.leading,spacing:16) {
            section("AUDIO OUTPUTS") {
                AudioOutputPicker(role:.main)
                AudioDeviceSettings(role:.main)
                AudioOutputPicker(role:.preview)
                AudioDeviceSettings(role:.preview)
                Text("Main: playlist and both crossfade decks. Preview: editor selection and Option-hover audition.").font(.stage(.caption)).stageSecondary()
            }
            MenuPreviewControl()
            HStack {Text("Main volume");Slider(value:$player.volume,in:0...1).accessibilityLabel("Main Volume")}
        }
    }
    private var appSettings:some View {
        VStack(alignment:.leading,spacing:16) {
            section("DJ MODE") {
                Button("Open DJ · Two Decks") {AppDelegate.shared.showDJ()}
                Text("Independent decks, Cue, tempo, loops and Hot Cues. The playlist player pauses when DJ opens.").font(.stage(.caption)).stageSecondary()
            }
            section("APP") {
                Button("Workspace: "+workspace.title) {workspace.toggle()}.stageHint("Choose a single workspace or separate utility windows")
                WindowDestinationSettings();QuickActionSettings()
            }
            section("PROTECTION") {
                Toggle("Playlist edits & fades",isOn:$setup.protectEdits).stageHint("When setup is locked, protect queue edits and crossfade changes").disabled(setup.isLocked)
                Toggle("Track selection & skip",isOn:$setup.protectSelection).stageHint("When setup is locked, prevent selection and Previous/Next changes").disabled(setup.isLocked)
                Toggle("Playback & seeking",isOn:$setup.protectPlayback).stageHint("When setup is locked, protect Play/Pause and seeking").disabled(setup.isLocked)
                Toggle("Settings & mappings",isOn:$setup.protectSettings).stageHint("When setup is locked, protect settings and control assignments").disabled(setup.isLocked)
            }
        }
    }
    @ViewBuilder private var selectedContent:some View {
        switch context.selected {
        case .themes:ThemeEditorView(embedded:true)
        case .mappings:MappingView(embedded:true)
        case .backup:BackupView(embedded:true)
        case .web:WebViewerView(embedded:true)
        default:
            ScrollView {
                VStack(alignment:.leading,spacing:16) {
                    Group {
                        switch context.selected {
                        case .audio:audioSettings
                        case .themes,.mappings,.backup,.web:EmptyView()
                        case .window:
                            Picker("Player window",selection:$context.window) {
                                ForEach(SizedWindow.allCases) {role in Text(role.rawValue).tag(role)}
                            }.pickerStyle(.menu).accessibilityLabel("Window Settings Target")
                            WindowSizePicker(role:context.window)
                            switch context.window {
                        case .main:
                            section("MAIN WINDOW") {
                                Toggle("Side-by-side playlist",isOn:$sizes.wide).stageHint("Switch between compact vertical layout and a fixed wide layout")
                                Toggle("Nano when minimizing",isOn:$windows.nanoOnMinimize).stageHint("Show the Nano companion when the player is minimized")
                                Button("Full screen") {AppDelegate.shared.toggleStageFullScreen()}.buttonStyle(.bordered)
                            }
                        case .mini:
                            section("MINI WINDOW") {
                                Toggle("Pin Mini position",isOn:$placement.miniLocked).stageHint("Prevent accidental dragging of the Mini window")
                                Toggle("Nano when minimizing",isOn:$windows.nanoOnMinimize).stageHint("Show the Nano companion when the player is minimized")
                                Button("Attach Mini to menu bar") {AppDelegate.shared.attachMiniToMenuBar(hideMain:true)}.buttonStyle(.bordered)
                                Button("Detach from menu bar") {AppDelegate.shared.detachMiniFromMenuBar()}.buttonStyle(.bordered)
                            }
                        case .nano:
                            section("NANO WINDOW") {
                                Toggle("Pin Nano position",isOn:$placement.pocketLocked).stageHint("Prevent accidental dragging of Nano")
                                Text("Drag the logo to move Nano. Use Small / Optimal / Large for its size.").font(.stage(size:11)).stageSecondary()
                                Text("Hold the bottom wheel button for 1.5 seconds to unlock controls.").font(.stage(size:11)).stageSecondary()
                            }
                            default:Text("Size is saved independently for this window.").font(.stage(.caption)).stageSecondary()
                            }
                        case .playlist:playlistSettings
                        case .app:appSettings
                        }
                    }.disabled(setup.settingsBlocked)
                }.frame(maxWidth:.infinity,alignment:.leading).padding(.vertical,4)
            }
        }
    }
    private func section<Content:View>(_ title:String,@ViewBuilder content:()->Content)->some View {
        VStack(alignment:.leading,spacing:10) {Text(title).font(.system(size:10,weight:.semibold)).tracking(0.8).foregroundStyle(accent);content()}
            .frame(maxWidth:.infinity,alignment:.leading)
    }
    private func setLocation(_ value:String) {
        let mini=windows.mini
        if value=="inside" {playlist.attach(toMini:mini,activatePlayer:false)}
        else if value=="separate" {playlist.detach(fromMini:mini)}
        else if let edge=PlaylistDockEdge(rawValue:value) {playlist.dock(edge,fromMini:mini)}
        let selected=context.selected
        AppDelegate.shared.showSettingsWindow();context.selected=selected
    }
}
