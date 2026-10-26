import SwiftUI

enum PatchWindow:String,CaseIterable,Identifiable {
    case audio="Audio",app="App",playlist="Playlists",window="Window"
    var id:String {rawValue}
}
enum PatchPlayerWindow:String {case main="Main",mini="Mini",nano="Nano"}
final class PatchWindowState:ObservableObject {
    static let shared=PatchWindowState()
    @Published var selected:PatchWindow = .audio
    @Published var window:PatchPlayerWindow = .main
}
struct PatchSettingsView:View {
    @ObservedObject private var context=PatchWindowState.shared
    @ObservedObject private var player=Player.shared
    @ObservedObject private var hints=HintPreferences.shared
    @ObservedObject private var setup=SetupLock.shared
    @ObservedObject private var windows=WindowPresentation.shared
    @ObservedObject private var placement=FloatingPlacement.shared
    @ObservedObject private var playlist=PlaylistWindowState.shared
    @ObservedObject private var workspace=WorkspaceState.shared
    private var transitionTrack:Track? {player.current ?? player.selectedTrack ?? player.tracks.first}
    private var location:String {playlist.detached ? (playlist.edge?.rawValue ?? "separate"):"inside"}
    var body:some View {
        VStack(alignment:.leading,spacing:12) {
            HStack {
                Text("PATCH").font(.stage(size:22));Spacer()

            }
            Picker("Section",selection:$context.selected) {ForEach(PatchWindow.allCases) {Text($0.rawValue).tag($0)}}
                .pickerStyle(.segmented).accessibilityLabel("PATCH Section")
            Divider()
            ScrollView {
                VStack(alignment:.leading,spacing:16) {
                    Group {
                        switch context.selected {
                        case .audio:audioSettings
                        case .window:
                            Picker("Player window",selection:$context.window) {
                                Text("Main").tag(PatchPlayerWindow.main);Text("Mini").tag(PatchPlayerWindow.mini);Text("Nano").tag(PatchPlayerWindow.nano)
                            }.pickerStyle(.segmented).accessibilityLabel("Window Settings Target")
                            switch context.window {
                        case .main:
                            section("MAIN WINDOW") {
                                Toggle("Auto Fit player",isOn:$windows.autoFit)
                                Toggle("Nano when minimizing",isOn:$windows.nanoOnMinimize)
                                HStack {Button("Wide layout") {AppDelegate.shared.toggleWideLayout()};Button("Full screen") {AppDelegate.shared.toggleStageFullScreen()}}.buttonStyle(.bordered)
                            }
                        case .mini:
                            section("MINI WINDOW") {
                                Toggle("Pin Mini position",isOn:$placement.miniLocked)
                                Toggle("Nano when minimizing",isOn:$windows.nanoOnMinimize)
                                Button("Attach Mini to menu bar") {AppDelegate.shared.attachMiniToMenuBar(hideMain:true)}.buttonStyle(.bordered)
                                Button("Detach from menu bar") {AppDelegate.shared.detachMiniFromMenuBar()}.buttonStyle(.bordered)
                            }
                        case .nano:
                            section("NANO WINDOW") {
                                Toggle("Pin Nano position",isOn:$placement.pocketLocked)
                                Text("Drag the logo to move Nano. Drag its bottom corner to resize.").font(.stage(size:11)).foregroundStyle(.secondary)
                                Text("Hold the bottom wheel button for 1.5 seconds to unlock controls.").font(.stage(size:11)).foregroundStyle(.secondary)
                            }
                            }
                        case .playlist:playlistSettings
                        case .app:appSettings
                        }
                    }.disabled(setup.settingsBlocked)
                }.frame(maxWidth:.infinity,alignment:.leading).padding(.vertical,4)
            }
        }.font(.stage(size:12)).padding(.vertical,4)
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
            section("PLAYLIST PLAYBACK") {
                Toggle("Shuffle",isOn:$player.shuffle);Toggle("Repeat queue",isOn:$player.repeatAll)
                Picker("Crossfade after current",selection:Binding(get:{transitionTrack.map {player.fadeMode(after:$0)} ?? .none},set:{mode in if let track=transitionTrack {player.setFadeMode(mode,after:track)}})) {
                    ForEach(Array(Set(FadeMode.allCases+[transitionTrack.map {player.fadeMode(after:$0)} ?? .none])).sorted {$0.seconds<$1.seconds},id:\.self) {mode in Text(mode.title).tag(mode)}
                }.disabled(transitionTrack == nil || setup.editsBlocked)
                Button("Apply fade to all tracks") {if let track=transitionTrack {player.setFadeModeForAll(player.fadeMode(after:track))}}.disabled(transitionTrack == nil || setup.editsBlocked)
                Picker("On Play",selection:$player.startMode) {Text("Restart").tag(StartMode.beginning);Text("Resume").tag(StartMode.resume)}
                Picker("At End",selection:$player.endMode) {Text("Next track").tag(EndMode.next);Text("Auto Stop").tag(EndMode.stop)}
                if player.endMode == .stop {Picker("Stop before end",selection:$player.stopBeforeEnd) {ForEach([0.0,1,2,3,5,10,15,30],id:\.self) {Text("\(Int($0)) s").tag($0)}}}
            }
        }
    }
    private var audioSettings:some View {
        VStack(alignment:.leading,spacing:16) {
            section("AUDIO OUTPUTS") {
                AudioOutputPicker(role:.main)
                AudioOutputPicker(role:.preview)
                Text("Main: playlist and both crossfade decks. Preview: editor selection and Option-hover audition.").font(.stage(.caption)).foregroundStyle(.secondary)
            }
            MenuPreviewControl()
            HStack {Text("Main volume");Slider(value:$player.volume,in:0...1).accessibilityLabel("Main Volume")}
        }
    }
    private var appSettings:some View {
        VStack(alignment:.leading,spacing:16) {
            section("APP") {
                Toggle("Hover hints above controls",isOn:$hints.enabled).stageHint("Show small hints above controls when you hover")
                Button("Themes & Appearance") {AppDelegate.shared.showThemesWindow()}.windowDestinationMenu(.themes)
                Button("Keyboard / MIDI") {AppDelegate.shared.showMappings()}.windowDestinationMenu(.mappings)
                Button("Timecode & Backup") {AppDelegate.shared.showBackupWindow()}.windowDestinationMenu(.backup)
                Button("Web Viewer") {AppDelegate.shared.showWebViewer()}.windowDestinationMenu(.viewer)
                Button("Undo playlist edit · ⌘Z") {player.undoEdit()}.disabled(!player.canUndoEdit || setup.editsBlocked)
                Button("Workspace: "+workspace.title) {workspace.toggle()}
                WindowDestinationSettings();QuickActionSettings()
            }
            section("PROTECTION") {
                Toggle("Playlist edits & fades",isOn:$setup.protectEdits).disabled(setup.isLocked)
                Toggle("Track selection & skip",isOn:$setup.protectSelection).disabled(setup.isLocked)
                Toggle("Playback & seeking",isOn:$setup.protectPlayback).disabled(setup.isLocked)
                Toggle("Settings & mappings",isOn:$setup.protectSettings).disabled(setup.isLocked)
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
