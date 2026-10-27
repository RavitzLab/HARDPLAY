import SwiftUI
import AVFoundation
import Combine

/// High-frequency progress is observed only by the active waveform, never the playlist rows.
final class PreviewTimeline:ObservableObject {
    @Published var elapsed:Double=0
    @Published var duration:Double=0
}

/// Audition is always bound to the explicitly chosen Preview device, never Main.
final class MenuPreviewPlayer:ObservableObject {
    static let shared=MenuPreviewPlayer()
    @Published private(set) var playing=false
    let timeline=PreviewTimeline()
    var elapsed:Double {get {timeline.elapsed} set {timeline.elapsed=newValue}}
    var duration:Double {get {timeline.duration} set {timeline.duration=newValue}}
    @Published private(set) var title=""
    @Published private(set) var trackID:String?
    @Published private(set) var message=""
    @Published var volume:Double=0.5 {didSet {engine.volume=Float(volume)}}
    private let engine=AVPlayer()
    private let routing:AudioRouting
    private var routeUID:String?
    private var clock:AnyCancellable?
    private var routeEvents:AnyCancellable?
    init(routing:AudioRouting = .shared) {
        self.routing=routing
        routing.register(engine,role:.preview)
        routeEvents=routing.objectWillChange.sink {[weak self] _ in self?.stop()}
        clock=Timer.publish(every:0.1,on:.main,in:.common).autoconnect().sink {[weak self] _ in self?.tick()}
    }
    var safe:Bool {
        let routes=routing
        return routes.cueAvailable
    }
    var outputName:String {
        let routes=routing
        return routes.outputs.first(where:{$0.id == routes.resolved(.preview)})?.name ?? "Unavailable"
    }
    func toggle(_ requested:Track?=nil) {
        if trackID != nil && (requested == nil || requested?.id == trackID) {stop();return}
        stop()
        guard safe,!ControlLock.shared.isLocked,!SetupLock.shared.playbackBlocked,
              let track=requested ?? Player.shared.selectedTrack ?? Player.shared.current else {return}
        AppDelegate.shared?.quickEditModel?.stopPreview()
        let routes=routing
        engine.replaceCurrentItem(with:AVPlayerItem(url:track.url))
        routes.register(engine,role:.preview)
        routeUID=routes.resolved(.preview)
        guard engine.audioOutputDeviceUniqueID == routeUID,routeUID != routes.resolved(.main),!engine.isMuted else {message="Preview output not confirmed";return}
        trackID=track.id;title=track.title;message="";engine.volume=Float(volume);playing=true;engine.play()
    }
    func togglePlayback(_ track:Track) {
        guard safe,!ControlLock.shared.isLocked,!SetupLock.shared.playbackBlocked else {return}
        guard trackID == track.id else {toggle(track);return}
        guard routeUID == routing.resolved(.preview),routeUID != routing.resolved(.main),!engine.isMuted else {stop();return}
        if playing {engine.pause();playing=false}else {engine.play();playing=true}
    }
    func seek(_ seconds:Double,track:Track) {
        guard trackID == track.id,safe,routeUID == routing.resolved(.preview),
              !ControlLock.shared.isLocked,!SetupLock.shared.playbackBlocked,duration>0,seconds.isFinite else {return}
        let target=PreviewInteraction.seek(seconds,duration:duration)
        engine.seek(to:CMTime(seconds:target,preferredTimescale:600),toleranceBefore:.zero,toleranceAfter:.zero)
        elapsed=target
    }
    func stop(){engine.pause();engine.replaceCurrentItem(with:nil);playing=false;routeUID=nil;trackID=nil;elapsed=0;duration=0;title=""}

    private func tick() {
        guard trackID != nil else {return}
        guard safe,routeUID == routing.resolved(.preview),!ControlLock.shared.isLocked,!SetupLock.shared.playbackBlocked else {stop();return}
        if engine.currentItem?.status == .failed {message="Unable to preview this track";stop()}
        let seconds=engine.currentTime().seconds,total=engine.currentItem?.duration.seconds ?? 0
        if total.isFinite,total>0,abs(total-duration)>0.01 {duration=total}
        if seconds.isFinite,abs(seconds-elapsed)>0.02 {elapsed=max(0,seconds)}
        if playing,duration>0,elapsed>=duration {stop()}
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
            Button {preview.toggle()} label:{Label(preview.trackID != nil ? "Stop Preview":"Preview",systemImage:preview.trackID != nil ? "stop.fill":"headphones")}
                .buttonStyle(.bordered).disabled(preview.trackID == nil && (!preview.safe || lock.isLocked || setup.playbackBlocked || (player.selectedTrack ?? player.current) == nil))
                .accessibilityLabel(preview.trackID != nil ? "Stop Menu Preview":"Preview on Second Output")
            Text(preview.safe ? (preview.trackID != nil ? "PREVIEW ONLY → ":"Preview Output → ")+preview.outputName:"Choose a separate Preview Output in Audio")
                .font(.system(size:10,weight:.semibold)).foregroundStyle(preview.safe ? Color.blue:Color.secondary).fixedSize(horizontal:false,vertical:true)
            if preview.trackID != nil {
                Text(preview.title).font(.stage(size:11)).lineLimit(1)
                Slider(value:$preview.volume,in:0...1).accessibilityLabel("Menu Preview Volume")
            }
            if !preview.message.isEmpty {Text(preview.message).font(.stage(.caption)).foregroundStyle(.orange)}
        }
    }
}
struct MenuBarPlayerView:View {
    @ObservedObject private var conceptAppearance=AppearancePreferences.shared
    @ObservedObject private var waves=Waveforms.shared
    @ObservedObject private var setup=SetupLock.shared
    @ObservedObject private var player=Player.shared
    @ObservedObject private var lock=ControlLock.shared
    @StateObject private var seek=WaveformSeekPermission()
    var body:some View {
        VStack(alignment:.leading,spacing:16) {
            SuppliedHardPlayWordmark().frame(width:62,height:34).frame(maxWidth:.infinity)
            HStack(alignment:.top,spacing:8) {
                Text(player.current?.title ?? "No track").font(.stage(size:17)).lineLimit(2).frame(maxWidth:.infinity,alignment:.leading)
                Button {AppDelegate.shared.showMain()} label:{MarkerIcon(systemName:"arrow.up.left.and.arrow.down.right",size:15).frame(width:28,height:30)}.buttonStyle(PlayerControlStyle()).accessibilityLabel("Open Main Player").stageHint("Open main player")
            }
            StageWaveform(identity:player.current?.id ?? "empty",peaks:player.current.flatMap {waves.cache[Waveforms.key($0)]?.peaks} ?? [],duration:player.duration,elapsed:player.elapsed,gain:1,color:Color(stageHex:AppearancePreferences.shared.theme.waveColor),enabled:seek.unlocked && player.current != nil && !lock.isLocked && !setup.playbackBlocked,onBegin:{seek.begin()},onFinish:{seek.lock()}) {seconds,play in
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
                Text("NEXT").font(.system(size:9,weight:.semibold)).stageSecondary()
                Text((player.repeatOne ? player.current:player.nextTrack)?.title ?? "End of playlist").font(.stage(size:11)).lineLimit(2).frame(maxWidth:.infinity,alignment:.leading)
            }.accessibilityElement(children:.ignore).accessibilityLabel("Next Track Title").accessibilityValue((player.repeatOne ? player.current:player.nextTrack)?.title ?? "End of playlist")
        }.frame(width:336).padding(18).fixedSize(horizontal:true,vertical:true).background(ThemedBackdrop()).foregroundStyle(Color(stageHex:AppearancePreferences.shared.theme.text)).fixedControlHints().stageColorScheme()
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
    private var active:Bool {preview.trackID == track.id}
    var body:some View {
        PreviewPressControl(identity:track.id,symbol:active ? (preview.playing ? "play.fill":"pause.fill"):"stop.fill",active:active,enabled:!lock.isLocked && !setup.playbackBlocked && preview.safe,
            tap:{preview.togglePlayback(track)},stop:{if preview.trackID == track.id {preview.stop()}})
            .frame(width:compact ? 24:30,height:compact ? 28:32)
            .accessibilityLabel((active ? (preview.playing ? "Pause Preview: ":"Resume Preview: "):"Preview Track: ")+track.title)
            .accessibilityAction(named:Text("Stop Preview")) {if active {preview.stop()}}
            .help(preview.safe ? "Preview → "+preview.outputName+" · click Play/Pause · hold 0.5s to stop":"Choose a separate Preview output in PATCH → Audio")
    }
}
