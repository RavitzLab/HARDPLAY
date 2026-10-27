import SwiftUI
import AppKit

/// A small companion player with its own silhouette, not a copy of a branded device.
final class PocketUIState: ObservableObject { @Published var scrub:Double=0;@Published var scrubbing=false }

struct PocketPlayerView: View {
    @StateObject private var ui = PocketUIState()
    @ObservedObject var placement = FloatingPlacement.shared
    @ObservedObject var drawer = PocketDrawerState.shared
    @ObservedObject var player = Player.shared
    @ObservedObject var lock = ControlLock.shared
    @ObservedObject var setup = SetupLock.shared
    @ObservedObject var appearance = AppearancePreferences.shared
    @ObservedObject private var waves=Waveforms.shared
    @StateObject private var seek=WaveformSeekPermission()
    var body: some View {
        GeometryReader { geometry in
            HStack(spacing:0) {
                Color.clear.frame(width:152).allowsHitTesting(false)
                pocketBody(width:max(220,geometry.size.width-164),height:max(368,geometry.size.height-12))
            }.frame(width:geometry.size.width,height:geometry.size.height)
        }.frame(minWidth:384,minHeight:380).audioFileDrop().fixedControlHints().stageColorScheme()
        .onChange(of:lock.isLocked) {_,value in if value {ui.scrubbing=false;AppDelegate.shared.hideNanoPlaylist()}}
        .onChange(of:setup.playbackBlocked) {_,value in if value {ui.scrubbing=false}}
        .onChange(of:player.currentID) {_,_ in ui.scrubbing=false}
    }
    private func pocketBody(width:CGFloat,height:CGFloat)->some View {
        let scale=min(1.3,width/180)
        let wheel=min(168,max(124,min(width-28,height-238*scale)))
        return VStack(spacing:8) {
            HStack {
                Color.clear.frame(width:16,height:18)
                PlayerHeaderDragRegion().frame(maxWidth:.infinity).frame(height:24)
                PocketDragHandle().frame(width:64,height:24).help(placement.pocketLocked ? "Position fixed · unlock in the side panel":"Drag here to move the player anywhere")
                PlayerHeaderDragRegion().frame(maxWidth:.infinity).frame(height:24)
                Button { AppDelegate.shared.showMain();AppDelegate.shared.pocketWindow.orderOut(nil) } label: { MarkerIcon(systemName:"arrow.up.left.and.arrow.down.right").font(.stage(size:10)).frame(width:16,height:18) }.buttonStyle(.plain).accessibilityLabel("Restore Player")
            }.background(PlayerHeaderDragRegion()).foregroundStyle(Color(stageHex:appearance.theme.text).opacity(0.7))
            VStack(alignment:.leading,spacing:6) {
                HStack { Circle().fill(player.playing ? accent : .gray).frame(width:5,height:5);Text(lock.isLocked ? "CONTROLS LOCKED":player.playing ? "PLAYING":"PAUSED").font(.stage(size:7,weight:.bold,design:.monospaced));Spacer();Text(player.queueNumber(player.current)).font(.stage(size:8,design:.monospaced)) }
                Text(player.current?.title ?? "Your music, ready").font(.stage(size:11*scale,weight:.semibold)).lineLimit(2).frame(maxWidth:.infinity,minHeight:28*scale,alignment:.leading)
                HStack {Text("+"+timeLabel(player.elapsed)).accessibilityLabel("Elapsed "+timeLabel(player.elapsed));Spacer();WaveformSeekLock(permission:seek,available:player.current != nil && !lock.isLocked && !setup.playbackBlocked);Text("−"+timeLabel(max(0,player.duration-player.elapsed))).accessibilityLabel("Remaining "+timeLabel(max(0,player.duration-player.elapsed)))}.font(.system(size:9,weight:.medium,design:.monospaced)).monospacedDigit()
                HStack {Text("Total "+timeLabel(player.duration));Spacer();Text("Tracks \(player.tracks.count)")}.font(.system(size:8,design:.monospaced)).accessibilityElement(children:.ignore).accessibilityLabel("Total "+timeLabel(player.duration)+", Tracks "+String(player.tracks.count))
                    StageWaveform(identity:player.current?.id ?? "empty",peaks:player.current.flatMap {waves.cache[Waveforms.key($0)]?.peaks} ?? [],duration:player.duration,elapsed:player.elapsed,gain:1,color:Color(stageHex:AppearancePreferences.shared.theme.waveColor),enabled:seek.unlocked && player.current != nil && !lock.isLocked && !setup.playbackBlocked,onBegin:{seek.begin()},onFinish:{seek.lock()}) {seconds,play in
                    if let track=player.current {player.waveformAction(track,seconds:seconds,duration:player.duration,play:play)}
                }.frame(height:32).accessibilityLabel("Nano Audio Waveform").stageHint("Use the padlock to unlock one seek")
                    .onChange(of:player.currentID) {_,_ in seek.lock()}.onChange(of:lock.isLocked) {_,_ in seek.lock()}.onChange(of:setup.playbackBlocked) {_,_ in seek.lock()}.onDisappear {seek.lock()}
                    .task(id:player.current.map(Waveforms.key)) {if let track=player.current {await waves.load(track)}}
                HStack(spacing:5) {
                    Image(systemName:player.volume == 0 ? "speaker.slash":"speaker.wave.2").font(.system(size:9))
                    Slider(value:$player.volume,in:0...1).controlSize(.mini).tint(accent).accessibilityLabel("Nano Volume")
                    RepeatControl(compact:true).scaleEffect(0.6).frame(width:24,height:23)
                    ShuffleControl(small:true).scaleEffect(0.7).frame(width:22,height:23)
                }.disabled(lock.isLocked || setup.playbackBlocked)

            }.padding(10).foregroundStyle(accent).background(appearance.theme.paint(.panel),in:RoundedRectangle(cornerRadius:10))
            Spacer(minLength:0)
            ZStack {
                if ["Noir Vinyl","Steel Play"].contains(appearance.theme.preset) {
                    Circle().stroke(Color(stageHex:appearance.theme.gridColor).opacity(0.6),lineWidth:1).padding(3)
                    Circle().stroke(accent.opacity(0.2),lineWidth:0.5).padding(7)
                }
                Circle().fill(Color(stageHex:appearance.theme.text).opacity(0.07)).overlay(Circle().stroke(Color(stageHex:appearance.theme.text).opacity(0.14),lineWidth:1))
                Button {player.toggle()} label:{Image(systemName:player.playing ? "pause.fill":"play.fill").font(.system(size:18,weight:.medium)).frame(width:38,height:38).background(accent.opacity(0.18),in:Circle())}
                    .buttonStyle(.plain).accessibilityLabel(player.playing ? "Pause":"Play").disabled(player.current == nil || setup.playbackBlocked || lock.isLocked)
                Button("OPEN") {AppDelegate.shared.showMain();AppDelegate.shared.pocketWindow.orderOut(nil)}
                    .font(.stage(size:8,weight:.heavy)).frame(width:66,height:24).offset(y:-wheel*0.35).buttonStyle(.plain).accessibilityLabel("Open Main Player").disabled(lock.isLocked)
                Button {player.previous()} label:{Image(systemName:"backward.end.fill").font(.system(size:13)).frame(width:26,height:26)}
                    .offset(x:-wheel*0.35).buttonStyle(.plain).accessibilityLabel("Previous Track").disabled(setup.selectionBlocked || lock.isLocked)
                Button {player.next()} label:{Image(systemName:"forward.end.fill").font(.system(size:13)).frame(width:26,height:26)}
                    .offset(x:wheel*0.35).buttonStyle(.plain).accessibilityLabel("Next Track").disabled(setup.selectionBlocked || lock.isLocked)
                Group {
                    if lock.isLocked {ControlsLockButton(compact:true,unlockOnly:true,wheel:true)}
                    else {Button {AppDelegate.shared.toggleNanoPlaylist()} label:{Image(systemName:"list.bullet").font(.system(size:13)).frame(width:66,height:24)}.buttonStyle(.plain).accessibilityLabel("Nano Playlist")}
                }.frame(width:66,height:24).offset(y:wheel*0.35)
            }.frame(width:wheel,height:wheel).foregroundStyle(Color(stageHex:appearance.theme.text))
            Spacer(minLength:0)
        }.padding(14).frame(width:width,height:height).background(appearance.theme.paint(.background),in:RoundedRectangle(cornerRadius:25))
            .overlay(RoundedRectangle(cornerRadius:25).stroke(Color(stageHex:appearance.theme.text).opacity(0.25),lineWidth:1))
            .overlay(alignment:.topLeading) {
                Button { AppDelegate.shared.togglePocketDrawer() } label: {
                    Color.clear.frame(width:16,height:126).contentShape(Rectangle())
                }.buttonStyle(.plain).offset(x:0,y:30).accessibilityLabel(drawer.open ? "Hide Widget Lock Panel":"Show Widget Lock Panel").help("Tap the left edge of the display for locks and window size")
            }
            .overlay(alignment:.topTrailing) {
                Button {AppDelegate.shared.toggleNanoControls()} label:{Color.clear.frame(width:16,height:126).contentShape(Rectangle())}
                    .buttonStyle(.plain).offset(x:0,y:30).accessibilityLabel("Toggle Nano Controls Panel").help("Tap the right edge of the display to show custom controls")
            }
            .padding(6)
    }
}
