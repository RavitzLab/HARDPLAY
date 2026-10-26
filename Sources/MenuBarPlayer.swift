import SwiftUI
import AVFoundation
import Combine

/// Audition is always bound to the explicitly chosen Preview device, never Main.
final class MenuPreviewPlayer:ObservableObject {
    static let shared=MenuPreviewPlayer()
    @Published private(set) var playing=false
    @Published private(set) var title=""
    @Published private(set) var trackID:String?
    @Published private(set) var message=""
    @Published var volume:Double=0.5 {didSet {engine.volume=Float(volume)}}
    private let engine=AVPlayer()
    private var routeUID:String?
    private var clock:AnyCancellable?
    private var routeEvents:AnyCancellable?
    private init() {
        AudioRouting.shared.register(engine,role:.preview)
        routeEvents=AudioRouting.shared.objectWillChange.sink {[weak self] _ in self?.stop()}
        clock=Timer.publish(every:0.1,on:.main,in:.common).autoconnect().sink {[weak self] _ in self?.tick()}
    }
    var safe:Bool {
        let routes=AudioRouting.shared
        return routes.cueAvailable
    }
    var outputName:String {
        let routes=AudioRouting.shared
        return routes.outputs.first(where:{$0.id == routes.resolved(.preview)})?.name ?? "Unavailable"
    }
    func toggle(_ requested:Track?=nil) {
        if playing && (requested == nil || requested?.id == trackID) {stop();return}
        stop()
        guard safe,!ControlLock.shared.isLocked,!SetupLock.shared.playbackBlocked,
              let track=requested ?? Player.shared.selectedTrack ?? Player.shared.current else {return}
        AppDelegate.shared?.quickEditModel?.stopPreview()
        let routes=AudioRouting.shared
        engine.replaceCurrentItem(with:AVPlayerItem(url:track.url))
        routes.register(engine,role:.preview)
        routeUID=routes.resolved(.preview)
        guard engine.audioOutputDeviceUniqueID == routeUID,routeUID != routes.resolved(.main),!engine.isMuted else {message="Preview output not confirmed";return}
        trackID=track.id;title=track.title;message="";engine.volume=Float(volume);playing=true;engine.play()
    }
    func stop(){engine.pause();playing=false;routeUID=nil;trackID=nil}
    private func tick() {
        guard playing else {return}
        guard safe,routeUID == AudioRouting.shared.resolved(.preview),!ControlLock.shared.isLocked,!SetupLock.shared.playbackBlocked else {stop();return}
        if engine.currentItem?.status == .failed {message="Unable to preview this track";stop()}
        if let duration=engine.currentItem?.duration.seconds,duration.isFinite,engine.currentTime().seconds>=duration {stop()}
    }
}
struct MenuPreviewControl:View {
    @ObservedObject private var preview=MenuPreviewPlayer.shared
    @ObservedObject private var routes=AudioRouting.shared
    @ObservedObject private var player=Player.shared
    @ObservedObject private var lock=ControlLock.shared
    @ObservedObject private var setup=SetupLock.shared
    var body:some View {
        VStack(alignment:.leading,spacing:6) {
            Button {preview.toggle()} label:{Label(preview.playing ? "Stop Preview":"Preview",systemImage:preview.playing ? "stop.fill":"headphones")}
                .buttonStyle(.bordered).disabled(!preview.playing && (!preview.safe || lock.isLocked || setup.playbackBlocked || (player.selectedTrack ?? player.current) == nil))
                .accessibilityLabel(preview.playing ? "Stop Menu Preview":"Preview on Second Output")
            Text(preview.safe ? (preview.playing ? "PREVIEW ONLY → ":"Preview Output → ")+preview.outputName:"Choose a separate Preview Output in Audio")
                .font(.system(size:10,weight:.semibold)).foregroundStyle(preview.safe ? Color.blue:Color.secondary).fixedSize(horizontal:false,vertical:true)
            if preview.playing {
                Text(preview.title).font(.stage(size:11)).lineLimit(1)
                Slider(value:$preview.volume,in:0...1).accessibilityLabel("Menu Preview Volume")
            }
            if !preview.message.isEmpty {Text(preview.message).font(.stage(.caption)).foregroundStyle(.orange)}
        }
    }
}
struct MenuBarPlayerView:View {
    @ObservedObject private var waves=Waveforms.shared
    @ObservedObject private var setup=SetupLock.shared
    @ObservedObject private var player=Player.shared
    @ObservedObject private var lock=ControlLock.shared
    @StateObject private var seek=WaveformSeekPermission()
    var body:some View {
        VStack(alignment:.leading,spacing:16) {
            HStack(alignment:.top,spacing:8) {
                Text(player.current?.title ?? "No track").font(.stage(size:17)).lineLimit(2).frame(maxWidth:.infinity,alignment:.leading)
                Button {AppDelegate.shared.showMain()} label:{MarkerIcon(systemName:"arrow.up.left.and.arrow.down.right",size:15).frame(width:28,height:30)}.buttonStyle(PlayerControlStyle()).accessibilityLabel("Open Main Player").stageHint("Open main player")
            }
            StageWaveform(identity:player.current?.id ?? "empty",peaks:player.current.flatMap {waves.cache[Waveforms.key($0)]?.peaks} ?? [],duration:player.duration,elapsed:player.elapsed,gain:1,color:accent,enabled:seek.unlocked && player.current != nil && !lock.isLocked && !setup.playbackBlocked,onBegin:{seek.begin()},onFinish:{seek.lock()}) {seconds,play in
                if let track=player.current {player.waveformAction(track,seconds:seconds,duration:player.duration,play:play)}
            }.frame(height:42).accessibilityLabel("Menu Bar Audio Waveform").stageHint("Use the padlock to unlock one seek")
                .onChange(of:player.currentID) {_,_ in seek.lock()}.onChange(of:lock.isLocked) {_,_ in seek.lock()}.onChange(of:setup.playbackBlocked) {_,_ in seek.lock()}.onDisappear {seek.lock()}
                    .task(id:player.current.map(Waveforms.key)) {if let track=player.current {await waves.load(track)}}
            HStack {
                Text("+"+timeLabel(player.elapsed)).accessibilityLabel("Elapsed "+timeLabel(player.elapsed))
                Spacer()
                WaveformSeekLock(permission:seek,available:player.current != nil && !lock.isLocked && !setup.playbackBlocked)
                Text("−"+timeLabel(max(0,player.duration-player.elapsed))).accessibilityLabel("Remaining "+timeLabel(max(0,player.duration-player.elapsed)))
            }.font(.system(size:11,weight:.medium,design:.monospaced)).monospacedDigit()
            HStack {Text("Total "+timeLabel(player.duration));Spacer();Text("Tracks \(player.tracks.count)")}.font(.system(size:10,design:.monospaced))
            HStack(spacing:0) {
                controlCell {PlayerVolumeButton(player:player)}
                controlCell {CrossfadeControl(player:player,iconOnly:true)}
                controlCell {Button {player.previous()} label:{Image(systemName:"backward.end.fill").font(.system(size:20)).frame(width:38,height:38)}.buttonStyle(PlayerControlStyle()).accessibilityLabel("Previous Track").disabled(setup.selectionBlocked || player.current == nil)}
                controlCell {Button {player.toggle()} label:{HardPlayTransport(playing:player.playing,compact:true,limit:48)}.buttonStyle(HardPlayPressStyle()).accessibilityLabel(player.playing ? "Pause":"Play").disabled(setup.playbackBlocked || player.current == nil)}
                controlCell {Button {player.next()} label:{Image(systemName:"forward.end.fill").font(.system(size:20)).frame(width:38,height:38)}.buttonStyle(PlayerControlStyle()).accessibilityLabel("Next Track").disabled(setup.selectionBlocked || player.current == nil)}
                controlCell {RepeatControl(compact:true)}
                controlCell {ShuffleControl()}
            }.frame(height:52).disabled(lock.isLocked)
            Divider()
            HStack(alignment:.top,spacing:8) {
                Text("NEXT").font(.system(size:9,weight:.semibold)).foregroundStyle(.secondary)
                Text((player.repeatOne ? player.current:player.nextTrack)?.title ?? "End of playlist").font(.stage(size:11)).lineLimit(2).frame(maxWidth:.infinity,alignment:.leading)
            }.accessibilityElement(children:.ignore).accessibilityLabel("Next Track Title").accessibilityValue((player.repeatOne ? player.current:player.nextTrack)?.title ?? "End of playlist")
        }.frame(width:336).padding(18).fixedSize(horizontal:true,vertical:true).background(ThemedBackdrop()).foregroundStyle(Color(stageHex:AppearancePreferences.shared.theme.text)).fixedControlHints()
    }
    private func controlCell<Content:View>(@ViewBuilder _ content:()->Content)->some View {
        content().frame(width:48,height:52)
    }

}

struct PlaylistPreviewButton:View {
    let track:Track
    var compact=false
    @ObservedObject private var preview=MenuPreviewPlayer.shared
    @ObservedObject private var routes=AudioRouting.shared
    @ObservedObject private var lock=ControlLock.shared
    @ObservedObject private var setup=SetupLock.shared
    private var active:Bool {preview.playing && preview.trackID == track.id}
    var body:some View {
        Button {preview.toggle(track)} label:{
            Image(systemName:active ? "stop.fill":"headphones").font(.system(size:compact ? 11:13)).frame(width:compact ? 22:28,height:compact ? 26:30)
        }.buttonStyle(PlayerControlStyle(active:active))
            .disabled(lock.isLocked || setup.playbackBlocked || (!active && !preview.safe))
            .accessibilityLabel((active ? "Stop Preview: ":"Preview Track: ")+track.title)
            .stageHint(preview.safe ? "Preview → "+preview.outputName+" · separate from Main":"Choose a separate Preview output in PATCH → Audio")
    }
}
