import SwiftUI

struct RepeatControl:View {
    var compact=false
    var small=false
    @ObservedObject private var player=Player.shared
    @ObservedObject private var setup=SetupLock.shared
    @ObservedObject private var lock=ControlLock.shared
    private var title:String {switch player.repeatMode {case .off:return "Repeat Off";case .one:return "Repeat One Track";case .all:return "Repeat Playlist"}}
    private var caption:String {switch player.repeatMode {case .off:return "Off";case .one:return "One";case .all:return "All"}}
    var body:some View {
        Button {let modes=RepeatMode.allCases;player.setRepeat(modes[(modes.firstIndex(of:player.repeatMode)!+1)%modes.count])} label:{
            if compact {
                VStack(spacing:2) {Image(systemName:player.repeatOne ? "repeat.1":"repeat").font(.system(size:small ? 13:17));Text(player.repeatOne ? "1":caption.uppercased()).font(.system(size:7,weight:.bold))}.frame(width:small ? 32:48,height:small ? 32:38)
            }else {
                HStack(spacing:6) {Image(systemName:player.repeatOne ? "repeat.1":"repeat");Text("Repeat · "+caption).font(.stage(size:11))}.padding(.horizontal,9).frame(height:34)
            }
        }.buttonStyle(PlayerControlStyle(active:player.repeatMode != .off))
            .accessibilityLabel(title).accessibilityValue(caption).stageHint(title+" · click to cycle Off, One, All")
            .contextMenu {ForEach(RepeatMode.allCases,id:\.self) {mode in Button(mode == .off ? "Off":mode == .one ? "One track":"Whole playlist") {player.setRepeat(mode)}}}
            .disabled(setup.settingsBlocked || lock.isLocked || player.current == nil)
    }
}
struct HintToggleButton:View {
    var small=false
    @ObservedObject private var hints=HintPreferences.shared
    var body:some View {
        Button {hints.enabled.toggle()} label:{Image(systemName:"questionmark").font(.system(size:small ? 10:14,weight:.semibold)).frame(width:small ? 18:28,height:small ? 18:30)}
            .buttonStyle(PlayerControlStyle(active:hints.enabled)).accessibilityLabel("Toggle Control Hints").accessibilityValue(hints.enabled ? "On":"Off")
            .help(hints.enabled ? "Turn off hover hints":"Turn on hover hints")
    }
}

struct ShuffleControl:View {
    var small=false
    @ObservedObject private var player=Player.shared
    @ObservedObject private var setup=SetupLock.shared
    @ObservedObject private var lock=ControlLock.shared
    var body:some View {
        Button {guard !setup.settingsBlocked,!lock.isLocked else {return};if !player.shuffle {if player.repeatOne {player.setRepeat(.off)};player.endMode = .next};player.shuffle.toggle()} label:{Image(systemName:"shuffle").font(.system(size:small ? 14:17,weight:.medium)).frame(width:small ? 32:48,height:small ? 32:38)}
            .buttonStyle(PlayerControlStyle(active:player.shuffle)).accessibilityLabel("Shuffle")
            .accessibilityValue(player.shuffle ? "On":"Off").stageHint("Shuffle · choose random tracks continuously")
            .disabled(setup.settingsBlocked || lock.isLocked)
    }
}
