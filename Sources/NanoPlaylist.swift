import SwiftUI

struct NanoTransitionMenu:View {
    @ObservedObject private var player=Player.shared
    @ObservedObject private var setup=SetupLock.shared
    @ObservedObject private var lock=ControlLock.shared
    private var track:Track? {player.current ?? player.selectedTrack ?? player.tracks.first}
    private var title:String {
        if player.endMode == .stop {return player.stopBeforeEnd>0 ? "Stop · −\(Int(player.stopBeforeEnd))s":"Stop at end"}
        let mode=track.map {player.fadeMode(after:$0)} ?? .none
        return mode == .none ? "Next · Cut":"Next · \(String(format:"%g",mode.seconds))s"
    }
    var body:some View {
        Menu {
            ForEach(FadeMode.allCases,id:\.self) {mode in
                Button(mode == .none ? "Next · no crossfade":"Next · \(String(format:"%g",mode.seconds)) seconds") {
                    guard let track else {return}
                    player.endMode = .next;player.setFadeMode(mode,after:track)
                }.disabled(track == nil)
            }
            Divider()
            Button("Stop at end") {player.stopBeforeEnd=0;player.endMode = .stop}
        } label:{Label(title,systemImage:player.endMode == .stop ? "stop.fill":"arrow.right").font(.system(size:8,weight:.semibold))}
            .menuStyle(.borderlessButton).stageMenuInk().fixedSize().disabled(lock.isLocked || setup.isLocked)
            .accessibilityLabel("Next transition").accessibilityValue(title)
            .stageHint("Choose this track’s next transition: Cut, 3s, 6s or Stop")
    }
}
struct NanoPlaylist:View {
    @Binding var open:Bool
    @ObservedObject private var player=Player.shared
    @ObservedObject private var preview=MenuPreviewPlayer.shared
    @ObservedObject private var lock=ControlLock.shared
    @ObservedObject private var setup=SetupLock.shared
    @ObservedObject private var appearance=AppearancePreferences.shared
    var body:some View {
        VStack(spacing:8) {
            HStack {
                Text(player.playlistName).font(.stage(size:12)).lineLimit(1).frame(maxWidth:100,alignment:.leading).help(player.playlistName)
                Spacer()
                Text("\(player.tracks.count)").font(.system(size:10)).stageSecondary()
                playlistSettingsMenu
                Button {open=false} label:{Image(systemName:"xmark").frame(width:22,height:22)}.buttonStyle(.plain).accessibilityLabel("Close Nano Playlist")
            }.overlay {SuppliedHardPlayWordmark().frame(width:44,height:24).allowsHitTesting(false)}
            HStack {
                Text(player.endMode == .stop ? "Auto Stop":"Next track")
                Spacer()
                Text(player.current.map {"Fade · \(Int(player.fadeMode(after:$0).seconds))s"} ?? "")
            }.font(.system(size:9,weight:.medium)).stageSecondary()
            if player.tracks.isEmpty {Text("Drop audio into the player").font(.stage(size:11)).stageSecondary().padding(.vertical,12)}
            else {
                ScrollViewReader {proxy in
                ScrollView {
                    LazyVStack(spacing:3) {
                        ForEach(player.tracks) {track in
                            HStack(spacing:7) {
                                if player.currentID == track.id {Circle().fill(accent).frame(width:4,height:4)}
                                Text(player.queueNumber(track)).font(.system(size:10,design:.monospaced)).stageSecondary().frame(width:22)
                                if preview.trackID == track.id {PlaylistPreviewWaveform(track:track,compact:true)}else {
                                Button {player.selectInQueue(track)} label:{Text(track.title).font(.stage(size:12)).lineLimit(1).frame(maxWidth:.infinity,alignment:.leading)}
                                    .buttonStyle(.plain).disabled(setup.selectionBlocked).accessibilityLabel("Select Track: "+track.title)
                                }
                                PlaylistPreviewButton(track:track,compact:true)
                                Menu {
                                    ForEach(FadeMode.allCases,id:\.self) {mode in
                                        Button(mode == .none ? "No crossfade":"Crossfade · \(String(format:"%g",mode.seconds))s") {player.setFadeMode(mode,after:track)}
                                    }
                                } label:{Text(player.fadeMode(after:track) == .none ? "Cut":"\(String(format:"%g",player.fadeMode(after:track).seconds))s").font(.system(size:9))}
                                    .menuStyle(.borderlessButton).stageMenuInk().fixedSize().disabled(setup.editsBlocked)
                                    .accessibilityLabel("Transition after: "+track.title)
                                Button {player.playFromQueue(track)} label:{Image(systemName:player.currentID == track.id && player.playing ? "pause.fill":"play.fill").frame(width:26,height:26)}.buttonStyle(.plain).disabled(setup.selectionBlocked || setup.playbackBlocked).accessibilityLabel((player.currentID == track.id && player.playing ? "Pause Track: ":"Play Track: ")+track.title)
                            }.disabled(lock.isLocked).padding(5).background(accent.opacity(player.currentID == track.id ? 0.2:(player.selectedID == track.id ? 0.08:0)),in:RoundedRectangle(cornerRadius:7)).overlay(RoundedRectangle(cornerRadius:7).stroke(player.currentID == track.id ? accent.opacity(0.8):.clear,lineWidth:1)).id(track.id).contextMenu {Button("Show in Finder") {NSWorkspace.shared.activateFileViewerSelecting([track.url])};Button("Start at…") {player.requestStartAt(track)}.disabled(setup.selectionBlocked || setup.playbackBlocked || lock.isLocked)}
                        }
                    }
                }.frame(height:min(320,CGFloat(player.tracks.count)*44))
                    .onAppear {if let id=player.currentID {proxy.scrollTo(id,anchor:.center)}}
                    .onChange(of:player.currentID) {_,id in if let id {proxy.scrollTo(id,anchor:.center)}}
                }
            }
        }.padding(12).frame(width:352).foregroundStyle(Color(stageHex:appearance.theme.text))
            .preferredColorScheme(appearance.theme.isLight ? .light:.dark)

    }
    private var playlistSettingsMenu:some View {
        Menu {
            Menu("Sort Playlist") {ForEach(PlaylistSort.allCases,id:\.self) {order in Button(order.rawValue) {player.sortQueue(order)}.disabled(setup.editsBlocked)}}
            Divider()
            Button("Next track automatically") {player.endMode = .next}
            Button("Auto Stop at end") {player.stopBeforeEnd=0;player.endMode = .stop}
            Divider()
            ForEach(FadeMode.allCases,id:\.self) {mode in
                Button(mode == .none ? "All fades off":"All crossfades · \(String(format:"%g",mode.seconds))s") {player.endMode = .next;player.setFadeModeForAll(mode)}
            }
            Divider()
            Button("On Play: Restart") {player.startMode = .beginning}
            Button("On Play: Resume") {player.startMode = .resume}
        } label:{Image(systemName:"slider.horizontal.3").frame(width:22,height:22)}
            .menuStyle(.borderlessButton).stageMenuInk().fixedSize().disabled(lock.isLocked || setup.isLocked)
            .accessibilityLabel("Nano Playlist Settings").stageHint("Next track, Auto Stop, crossfades and start mode")
    }

}
