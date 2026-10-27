import SwiftUI
struct PlaylistSettingsDrawer:View {
    @ObservedObject var player:Player
    @ObservedObject private var setup=SetupLock.shared
    @ObservedObject private var list=PlaylistWindowState.shared
    var body:some View {
        ScrollView {
            VStack(alignment:.leading,spacing:14) {
                Text("PLAYLIST SETTINGS").font(.stage(size:17))
                Text("Changes apply to this set. Save the playlist to keep them.").font(.stage(.caption)).stageSecondary()
                Button("Undo playlist edit · ⌘Z") {player.undoEdit()}.disabled(!player.canUndoEdit)
                    .stageHint("Restore the previous queue order, track edits or playback settings")
                Divider()
                Picker("At end",selection:$player.endMode) {Text("Next track").tag(EndMode.next);Text("Auto Stop").tag(EndMode.stop)}
                    .stageHint("Continue with the next cue or stop automatically")
                if player.endMode == .stop {Picker("Stop early",selection:$player.stopBeforeEnd) {ForEach([0.0,1,2,3,5,10,15,30],id:\.self) {Text("\(Int($0)) s").tag($0)}}}
                Toggle("Shuffle",isOn:$player.shuffle).stageHint("Choose the next cue randomly")
                Picker("Repeat",selection:Binding(get:{player.repeatMode},set:{player.setRepeat($0)})) {ForEach(RepeatMode.allCases,id:\.self) {mode in Text(mode == .off ? "Off":mode == .one ? "One track":"Playlist").tag(mode)}}
                CrossfadeControl(player:player).stageHint("Set a crossfade for this transition or all tracks")
                Divider()
                Text("PLACEMENT").font(.stage(size:12))
                Button(list.detached ? "Bring playlist inside":"Separate playlist window") {if list.detached {list.attach(toMini:WindowPresentation.shared.mini)}else {list.detach(fromMini:WindowPresentation.shared.mini)}}
                ForEach([PlaylistDockEdge.bottom,.left,.right,.top],id:\.self) {edge in Button("Dock · "+edge.rawValue.capitalized) {list.dock(edge,fromMini:WindowPresentation.shared.mini)}}
            }.padding(16).disabled(setup.settingsBlocked || ControlLock.shared.isLocked)
        }.frame(width:310,height:540).background(ThemedBackdrop()).font(.stage(size:12))
    }
}
