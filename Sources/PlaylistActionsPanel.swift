import SwiftUI
import AppKit

final class PlaylistActionsState:ObservableObject {@Published var open=false}
struct PlaylistActionsButton:View {
    @ObservedObject var player:Player
    let fromMini:Bool
    var compact=false
    @ObservedObject private var lock=ControlLock.shared
    @StateObject private var ui=PlaylistActionsState()
    var body:some View {
        Button {ui.open.toggle()} label:{HStack(spacing:5) {Image(systemName:"ellipsis");Image(systemName:"chevron.down").font(.system(size:9,weight:.semibold))}.frame(width:compact ? 32:44,height:34)}
            .buttonStyle(PlayerControlStyle(active:ui.open)).accessibilityLabel("Playlist Actions")
            .accessibilityValue(ui.open ? "Open":"Closed").stageHint("Open playlist actions to the right")
            .background(AttachedControlPanelAnchor(open:$ui.open,content:AnyView(PlaylistActionsContent(player:player,fromMini:fromMini,close:{ui.open=false})),size:NSSize(width:260,height:440),rightSide:true))
            .disabled(lock.isLocked).onChange(of:lock.isLocked) {_,locked in if locked {ui.open=false}}
    }
}
private final class PlaylistSecondaryState:ObservableObject {@Published var open=false}
private struct PlaylistActionsContent:View {
    @ObservedObject var player:Player
    let fromMini:Bool
    let close:()->Void
    @ObservedObject private var setup=SetupLock.shared
    @ObservedObject private var lock=ControlLock.shared
    @ObservedObject private var appearance=AppearancePreferences.shared
    @StateObject private var secondary=PlaylistSecondaryState()
    private func run(_ action:@escaping ()->Void){close();DispatchQueue.main.async(execute:action)}
    private func explanation(_ title:String)->String {
        switch title {
        case "Save playlist":return "Save track references, order, names and transitions. Source audio is not copied"
        case "Rename playlist":return "Change the set name without renaming its audio files"
        case "New playlist":return "Create a new empty set; you can save your current set first"
        case "Delete playlist":return "Delete the saved playlist document; audio files remain unchanged"
        case "Add tracks":return "Add audio or video files to this queue"
        case "Open playlist…":return "Load a saved Hard Play playlist"
        case "Save as…":return "Save this set as another playlist document"
        default:return title
        }
    }
    private func action(_ title:String,_ icon:String,blocked:Bool=false,_ work:@escaping ()->Void)->some View {
        Button {run(work)} label:{Label(title,systemImage:icon).font(.stage(size:11)).frame(maxWidth:.infinity,alignment:.leading).padding(.vertical,5).padding(.horizontal,7)}
            .buttonStyle(PlayerControlStyle()).disabled(blocked || lock.isLocked).stageHint(explanation(title))
    }
    var body:some View {
        VStack(alignment:.leading,spacing:6) {
            HStack {Text("PLAYLIST").font(.stage(size:13));Spacer();Button(action:close) {Image(systemName:"xmark").frame(width:24,height:24)}.buttonStyle(.plain).accessibilityLabel("Close Playlist Actions")}
            Text(player.playlistName).font(.stage(size:11)).lineLimit(1).help(player.playlistName)
            action("Save playlist","square.and.arrow.down") {player.savePlaylist()}
            action("Rename playlist","pencil",blocked:setup.editsBlocked) {player.requestRenamePlaylist()}
            action("New playlist","folder.badge.plus",blocked:setup.editsBlocked) {player.requestNewPlaylist()}
            action("Delete playlist","trash",blocked:setup.editsBlocked || !player.canDeletePlaylist) {player.requestDeletePlaylist()}
            action("Add tracks","plus",blocked:setup.editsBlocked) {player.openFiles()}
            Divider()
            action("Open playlist…","folder",blocked:setup.editsBlocked) {player.openPlaylist()}
            action("Save as…","square.and.arrow.down.on.square") {player.savePlaylist(asNew:true)}
            if !player.recentPlaylists.isEmpty {
                Menu("Recent playlists") {ForEach(player.recentPlaylists,id:\.path) {url in Button(url.deletingPathExtension().lastPathComponent) {run {player.openPlaylist(url)}}}}
                    .font(.stage(size:11)).disabled(setup.editsBlocked)
            }
            Divider()
            action(PlaylistWindowState.shared.detached ? "Playlist inside player":"Playlist in separate window","rectangle.on.rectangle") {
                if PlaylistWindowState.shared.detached {PlaylistWindowState.shared.attach(toMini:fromMini)}else {PlaylistWindowState.shared.detach(fromMini:fromMini)}
            }
            action(setup.isLocked ? "Unlock setup":"Lock setup",setup.isLocked ? "lock.fill":"lock.open") {if setup.isLocked {setup.unlock()}else {setup.lock()}}
            Button {secondary.open.toggle()} label:{Label("Playlist Settings",systemImage:"slider.horizontal.3").font(.stage(size:11)).frame(maxWidth:.infinity,alignment:.leading).padding(7)}
                .buttonStyle(PlayerControlStyle(active:secondary.open)).stageHint("Placement, fades, playback and Undo")
                .background(AttachedControlPanelAnchor(open:$secondary.open,content:AnyView(PlaylistSettingsDrawer(player:player)),size:NSSize(width:310,height:540),rightSide:true))
            Spacer(minLength:0)
        }.padding(12).frame(width:260,height:440)
            .foregroundStyle(Color(stageHex:appearance.theme.text))
            .background(appearance.theme.paint(.background),in:RoundedRectangle(cornerRadius:12))
            .overlay(RoundedRectangle(cornerRadius:12).stroke(accent.opacity(0.4),lineWidth:1))
            .preferredColorScheme(appearance.theme.isLight ? .light:.dark)
    }
}
