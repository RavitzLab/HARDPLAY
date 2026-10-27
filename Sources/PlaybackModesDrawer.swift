import SwiftUI

final class PlaybackDrawerState:ObservableObject {
    static let shared=PlaybackDrawerState()
    @Published var open=false
}

/// Editing these policies never triggers a clip. The explicit transport owns playback.
struct PlaybackModesDrawer:View {
    @ObservedObject var player:Player
    @Binding var open:Bool
    @ObservedObject private var setup=SetupLock.shared
    @ObservedObject private var lock=ControlLock.shared
    @ObservedObject private var appearance=AppearancePreferences.shared
    private var blocked:Bool {setup.isLocked || lock.isLocked}
    private var transitionTrack:Track? {player.current ?? player.selectedTrack ?? player.tracks.first}
    var body:some View {
        VStack(alignment:.leading,spacing:16) {
            HStack {Text("PLAYBACK").font(.stage(size:16,weight:.bold));Spacer();Button {withAnimation(.easeInOut(duration:0.22)) {open=false}} label:{Image(systemName:"xmark").frame(width:28,height:28)}.buttonStyle(PlayerControlStyle()).accessibilityLabel("Close Playback")}
            ScrollView {
                VStack(alignment:.leading,spacing:17) {
                    group("At End") {
                        choice("Next",icon:"arrow.right",active:player.endMode == .next,hint:"At track end · automatically play the next queued track") {player.endMode = .next}
                        choice("Stop",icon:"stop.fill",active:player.endMode == .stop,hint:"At track end · stop without starting the next track") {player.endMode = .stop}
                    }
                    if player.endMode == .stop {
                        Picker("Stop Before End",selection:$player.stopBeforeEnd) {ForEach([0.0,1,2,3,5,10,15,30],id:\.self) {Text("\(Int($0)) s").tag($0)}}.disabled(blocked)
                    }
                    group("Repeat") {
                        ForEach(RepeatMode.allCases,id:\.self) {mode in
                            choice(mode == .off ? "Off":mode == .one ? "One":"Playlist",icon:mode == .one ? "repeat.1":"repeat",active:player.repeatMode == mode,hint:mode == .off ? "Repeat off":mode == .one ? "Repeat this track":"Repeat the whole playlist") {
                                if mode == .one {player.shuffle=false}
                                player.setRepeat(mode)
                            }
                        }
                    }
                    group("Order") {
                        choice("In order",icon:"list.number",active:!player.shuffle,hint:"Follow the playlist order") {player.shuffle=false}
                        choice("Shuffle",icon:"shuffle",active:player.shuffle,hint:"Keep choosing a random different track, including after the last playlist entry") {
                            if player.repeatOne {player.setRepeat(.off)}
                            player.endMode = .next;player.shuffle=true
                        }
                    }
                    VStack(alignment:.leading,spacing:8) {
                        Text("Crossfade · \(player.queueNumber(transitionTrack)) → next").font(.stage(size:11)).stageSecondary()
                        HStack(spacing:6) {ForEach(FadeMode.allCases,id:\.self) {mode in
                            choice(mode == .none ? "Off":"\(String(format:"%g",mode.seconds)) s",icon:mode == .none ? "arrow.right.to.line":"circle.lefthalf.filled",active:transitionTrack.map {player.fadeMode(after:$0)==mode} ?? false,hint:mode == .none ? "This transition · no overlap":"This transition · overlap for \(String(format:"%g",mode.seconds)) seconds") {if let track=transitionTrack {player.setFadeMode(mode,after:track)}}
                        }}.disabled(transitionTrack == nil)
                        Button {if let track=transitionTrack {player.setFadeModeForAll(player.fadeMode(after:track))}} label:{Label("Apply to All",systemImage:"square.stack").font(.stage(size:11)).frame(maxWidth:.infinity).padding(9)}.buttonStyle(PlayerControlStyle()).disabled(blocked || transitionTrack == nil).stageHint("Apply this fade duration to every transition in the playlist · Undo is available")
                    }

                }
            }.frame(maxHeight:460)
            Divider()
            Text(blocked ? "Setup protected":"Setup editable").font(.stage(size:11)).foregroundStyle(accent)
            Button {if setup.isLocked {setup.unlock()}else {setup.lock()}} label:{Label(setup.isLocked ? "Unlock Setup":"Lock Setup",systemImage:setup.isLocked ? "lock.fill":"lock.open").font(.stage(size:12)).frame(maxWidth:.infinity).padding(10)}.buttonStyle(PlayerControlStyle(active:setup.isLocked)).disabled(lock.isLocked).accessibilityLabel(setup.isLocked ? "Unlock Modes Setup":"Lock Modes Setup")
        }.padding(14).background(Color(stageHex:appearance.theme.isLight ? "FFFFFF":"242B34"),in:RoundedRectangle(cornerRadius:12))
            .overlay(RoundedRectangle(cornerRadius:12).stroke(accent.opacity(0.22),lineWidth:1)).foregroundStyle(Color(stageHex:appearance.theme.text))
    }
    private func group<Content:View>(_ title:String,@ViewBuilder content:()->Content)->some View {VStack(alignment:.leading,spacing:8) {Text(title).font(.stage(size:11)).stageSecondary();HStack(spacing:6,content:content)}}
    private func choice(_ title:String,icon:String,active:Bool,hint:String,action:@escaping ()->Void)->some View {
        Button {guard !blocked else{return};action()} label:{VStack(spacing:6) {Image(systemName:icon).font(.system(size:15,weight:.medium));Text(title).font(.stage(size:11))}.frame(maxWidth:.infinity).padding(.vertical,10)}.buttonStyle(PlayerControlStyle(active:active)).disabled(blocked).accessibilityLabel("\(title) mode").accessibilityValue(active ? "Selected":"Not selected").stageHint(hint)
    }
}
