import AppKit
import SwiftUI
import AVFoundation

final class ControlLock: ObservableObject {
    static let shared = ControlLock()
    static let unlockDuration:Double=1.5
    @Published private(set) var isLocked = false
    func lock() { isLocked = true }
    @discardableResult func unlock(swipe: Double) -> Bool {
        guard swipe >= 330 else { return false }
        isLocked = false; return true
    }
    @discardableResult func unlock(heldFor seconds: Double) -> Bool {
        guard seconds >= Self.unlockDuration else { return false }
        isLocked = false; return true
    }
}

/// Bounded peak envelopes derived from decoded PCM, never a generated waveform.
@MainActor final class Waveforms: ObservableObject {
    static let shared = Waveforms()
    struct Envelope { let peaks: [Double]; let duration: Double }
    @Published private(set) var cache: [String: Envelope] = [:]
    private var pending: [String: Task<Envelope, Never>] = [:]
    nonisolated static func key(_ track:Track)->String {track.id+"|"+track.url.path}
    func load(_ track: Track) async {
        let key=Self.key(track)
        if cache[key] != nil { return }
        let job: Task<Envelope, Never>
        if let existing = pending[key] { job = existing }
        else {
            job = Task.detached(priority: .utility) { await Self.decode(track.url) }
            pending[key] = job
        }
        let result = await job.value
        if cache.count >= 24, let key = cache.keys.first { cache.removeValue(forKey: key) }
        cache[key] = result; pending.removeValue(forKey:key)
    }
    nonisolated static func decode(_ url: URL) async -> Envelope {
        do {
            let asset = AVURLAsset(url: url)
            let seconds = try await asset.load(.duration).seconds
            guard seconds.isFinite, seconds > 0, let track = try await asset.loadTracks(withMediaType: .audio).first else { return Envelope(peaks: [], duration: 0) }
            let reader = try AVAssetReader(asset: asset)
            let output = AVAssetReaderAudioMixOutput(audioTracks: [track], audioSettings: [AVFormatIDKey: kAudioFormatLinearPCM, AVLinearPCMIsFloatKey: true, AVLinearPCMBitDepthKey: 32, AVLinearPCMIsBigEndianKey: false, AVLinearPCMIsNonInterleaved: false, AVNumberOfChannelsKey: 1, AVSampleRateKey: 8000])
            output.alwaysCopiesSampleData = false
            guard reader.canAdd(output) else { return Envelope(peaks: [], duration: seconds) }
            reader.add(output)
            guard reader.startReading() else { return Envelope(peaks: [], duration: seconds) }
            var peaks = [Double](repeating: 0, count: 160)
            while !Task.isCancelled, let sample = output.copyNextSampleBuffer() {
                guard let buffer = CMSampleBufferGetDataBuffer(sample) else { continue }
                var length = 0; var pointer: UnsafeMutablePointer<Int8>?
                guard CMBlockBufferGetDataPointer(buffer, atOffset: 0, lengthAtOffsetOut: nil, totalLengthOut: &length, dataPointerOut: &pointer) == kCMBlockBufferNoErr, let pointer else { continue }
                let count = length / MemoryLayout<Float>.size
                let start = CMSampleBufferGetPresentationTimeStamp(sample).seconds
                let sampleDuration = CMSampleBufferGetDuration(sample).seconds
                let span = sampleDuration.isFinite && sampleDuration > 0 ? sampleDuration : Double(count) / 8000
                guard start.isFinite, count > 0 else { continue }
                pointer.withMemoryRebound(to: Float.self, capacity: count) { floats in
                    for i in stride(from: 0, to: count, by: 4) {
                        let bin = min(159, max(0, Int((start + Double(i) / Double(count) * span) / seconds * 160)))
                        let amplitude = Double(abs(floats[i]))
                        if amplitude.isFinite { peaks[bin] = max(peaks[bin], amplitude) }
                    }
                }
            }
            guard reader.status == .completed else { reader.cancelReading(); return Envelope(peaks: [], duration: seconds) }
            let maximum = peaks.max() ?? 0
            return Envelope(peaks: maximum > 0 ? peaks.map { pow($0 / maximum, 0.65) } : peaks, duration: seconds)
        } catch { return Envelope(peaks: [], duration: 0) }
    }
}

struct TapeEdge: Shape {
    func path(in r: CGRect) -> Path {
        let points: [(Double, Double)] = [(0.018,0.012),(0.986,0),(1,0.1),(0.994,0.48),(1,0.9),(0.985,1),(0.012,0.988),(0,0.88),(0.006,0.5),(0,0.13)]
        var p = Path(); p.move(to: CGPoint(x: r.width * points[0].0, y: r.height * points[0].1))
        for point in points.dropFirst() { p.addLine(to: CGPoint(x: r.width * point.0, y: r.height * point.1)) }; p.closeSubpath(); return p
    }
}
var tapeB: Color { Color(stageHex:AppearancePreferences.shared.theme.tape) }
struct TapeLabel: View {
    @ObservedObject private var appearance=AppearancePreferences.shared
    var text: String
    var secondary = false
    var body: some View {
        Text(text).font(.custom(StageTypography.name, size: 14)).foregroundStyle(tapeInk)
            .padding(.horizontal, 12).padding(.vertical, 5).background(TapeSurface()).rotationEffect(.degrees(secondary ? 1 : -1))
    }
}

struct DeckWave: View {
    let peaks: [Double]
    let fraction: Double
    let color: Color
    let gain: Double
    var body: some View {
        Canvas { context, size in
            guard !peaks.isEmpty else { return }
            let bins = min(peaks.count, max(1, Int(size.width / 4)))
            for i in 0..<bins {
                let from = i * peaks.count / bins, end = max(from + 1, (i + 1) * peaks.count / bins)
                let amplitude = peaks[from..<min(end, peaks.count)].max() ?? 0
                let h = max(1, amplitude * (size.height - 4))
                let x = Double(i) / Double(bins) * size.width
                let rect = CGRect(x: x, y: (size.height - h) / 2, width: max(1.3, size.width / Double(bins) - 1.6), height: h)
                context.fill(Path(roundedRect: rect, cornerRadius: 1), with: .color(color.opacity((Double(i) / Double(bins) <= fraction ? 1 : 0.45) * (0.35 + gain * 0.65))))
            }
            let x = min(size.width - 1, max(0, fraction * size.width))
            var cursor = Path(); cursor.move(to: CGPoint(x: x, y: 0)); cursor.addLine(to: CGPoint(x: x, y: size.height))
            context.stroke(cursor, with: .color(.white.opacity(0.85)), lineWidth: 1)
        }.accessibilityLabel("Audio Waveform").allowsHitTesting(false)
    }
}

struct StageDeck: View {
    @StateObject private var seek=WaveformSeekPermission()
    @ObservedObject var appearance = AppearancePreferences.shared
    @ObservedObject var player: Player
    @ObservedObject var waves = Waveforms.shared
    let track: Track?
    let right: Bool
    let compact: Bool
    var nextRole:Bool {player.deckUsesNextRole(right:right)}
    var roleColor:Color {track == nil ? .gray:Color(stageHex:appearance.theme.isLight ? (player.deckIsCurrent(right:right) ? "1756A9":"526F96"):(player.deckIsCurrent(right:right) ? "78CBA5":"E49A9A"))}
    var actualDuration:Double {player.deckDuration(right:right)>0 ? player.deckDuration(right:right):(track.flatMap {waves.cache[Waveforms.key($0)]?.duration} ?? 0)}
    var elapsed:Double {player.deckTime(right:right)}
    var gain:Double {player.deckGain(right:right)}
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .firstTextBaseline) {
                Text(player.queueNumber(track)).font(.stage(size:compact ? 24:28,weight:.bold)).monospacedDigit()
                Spacer()
                HStack(spacing:5) {Circle().fill(roleColor).frame(width:5,height:5);Text(track != nil && player.deckIsCurrent(right:right) && !player.playing && !player.isCrossfading ? "PAUSED":player.deckLabel(right:right))}
                    .font(.stage(size: 9, weight: .semibold)).tracking(1).foregroundStyle(roleColor).padding(.horizontal,7).padding(.vertical,4).background(roleColor.opacity(0.12),in:Capsule())
            }
            Text(track?.title ?? (nextRole ? "End of Queue" : "Add your music"))
                .font(.stage(size: (compact ? 13 : 16) * AppearancePreferences.shared.theme.textScale, weight: .semibold)).lineLimit(2).frame(height:(compact ? 34 : 40) * AppearancePreferences.shared.theme.textScale,alignment:.topLeading).stageHint(track?.title ?? "No track selected")
            if track != nil {
                HStack(spacing:5) {
                    if player.deckIsCurrent(right:right) {
                        Label(player.endMode == .stop ? "Stop":"Next",systemImage:player.endMode == .stop ? "stop.fill":"arrow.right")
                    }else {Label(player.shuffle ? "Shuffle":"In order",systemImage:player.shuffle ? "shuffle":"list.number")}
                }.font(.system(size:compact ? 8:10,weight:.medium)).foregroundStyle(roleColor.opacity(0.85))
            }
            HStack { Text("\(timeLabel(elapsed)) / \(timeLabel(actualDuration))"); Spacer(); WaveformSeekLock(permission:seek,available:track != nil && (!nextRole || player.isCrossfading) && !ControlLock.shared.isLocked && !SetupLock.shared.playbackBlocked); Text("\(Int(gain * 100))%") }
                .font(.stage(size: 10, design: .monospaced)).foregroundStyle(Color(stageHex:AppearancePreferences.shared.theme.text).opacity(0.7))
            StageWaveform(identity:track?.id ?? "empty",peaks:track.flatMap { waves.cache[Waveforms.key($0)]?.peaks } ?? [],duration:actualDuration,elapsed:elapsed,gain:gain,color:roleColor,enabled:seek.unlocked && track != nil && (!nextRole || player.isCrossfading) && !ControlLock.shared.isLocked && !SetupLock.shared.playbackBlocked,onBegin:{seek.begin()},onFinish:{seek.lock()}) { seconds,play in
                if let track {player.waveformAction(track,seconds:seconds,duration:actualDuration,play:play)}
            }.frame(height:compact ? 42:50)
                .stageHint(nextRole && !player.isCrossfading ? "NEXT preview only · Use playlist → Start at… to choose a start time" : "Hover: time · Use the padlock to unlock one seek")
            GeometryReader { g in
                Rectangle().fill(.white.opacity(0.1)).overlay(alignment: .leading) {
                    Rectangle().fill(roleColor).frame(width: g.size.width * gain)
                }
            }.frame(height: 3)

        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(LinearGradient(colors:[Color.black.opacity(appearance.theme.isLight ? 0.015:0.24),Color.white.opacity(appearance.theme.isLight ? 0.9:0.035)],startPoint:.top,endPoint:.bottom),in:RoundedRectangle(cornerRadius:appearance.theme.radius))
        .overlay(RoundedRectangle(cornerRadius:appearance.theme.radius).stroke(roleColor.opacity(track == nil ? 0.15:0.55),lineWidth:1.5))
        .contextMenu {
            if let track {
                Button {AppDelegate.shared.showQuickEdit(track)} label: {MarkerLabel("Edit Audio…",systemImage:"scissors")}
                    .disabled(SetupLock.shared.editsBlocked || ControlLock.shared.isLocked)
            }
        }
        .onChange(of:track?.id) {_,_ in seek.lock()}
        .onChange(of:ControlLock.shared.isLocked) {_,_ in seek.lock()}
        .onChange(of:SetupLock.shared.playbackBlocked) {_,_ in seek.lock()}
        .onDisappear {seek.lock()}
        .task(id: track.map(Waveforms.key)) { if let track { await waves.load(track) } }
    }
}

/// Accumulates continuous clockwise movement; straight drags and jumps never unlock.
struct CircularUnlockProgress {
    private(set) var degrees:Double=0
    private var previous:Double?
    mutating func begin(_ point:CGPoint,center:CGPoint) {
        degrees=0;previous=angle(point,center:center)
    }
    private func angle(_ point:CGPoint,center:CGPoint)->Double? {
        let dx=point.x-center.x,dy=point.y-center.y,r=hypot(dx,dy)
        guard (36...84).contains(r) else {return nil}
        return atan2(dy,dx)*180 / .pi
    }
    mutating func move(_ point:CGPoint,center:CGPoint)->Bool {
        guard let next=angle(point,center:center),let prior=previous else {degrees=0;previous=nil;return false}
        var delta=prior-next
        if delta > 180 {delta-=360};if delta < -180 {delta+=360}
        guard abs(delta)<=65 else {degrees=0;previous=nil;return false}
        degrees=min(360,max(0,degrees+delta));previous=next
        return degrees>=330
    }
}
struct NativeUnlockControl:NSViewRepresentable {
    final class UnlockView:NSView {
        private var progress=CircularUnlockProgress()
        private var timer:Timer?
        private var heldAt:Date?
        private var holdProgress:Double=0
        override var acceptsFirstResponder:Bool {true}
        override var mouseDownCanMoveWindow:Bool {false}
        private var center:CGPoint {CGPoint(x:bounds.midX,y:bounds.midY)}
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if let window {window.makeFirstResponder(self)} else {cleanUp()}
        }
        override func draw(_ dirtyRect:NSRect) {
            let c=center,r:CGFloat=60
            let circle=NSBezierPath(ovalIn:NSRect(x:c.x-r,y:c.y-r,width:r*2,height:r*2))
            NSColor.white.withAlphaComponent(0.14).setStroke();circle.lineWidth=7;circle.stroke()
            let fraction=max(progress.degrees/330,holdProgress)
            let arc=NSBezierPath();arc.appendArc(withCenter:c,radius:r,startAngle:90,endAngle:90-CGFloat(fraction)*360,clockwise:true)
            NSColor(calibratedRed:0.60,green:0.81,blue:1,alpha:1).setStroke();arc.lineWidth=7;arc.lineCapStyle = .round;arc.stroke()
            let thumbAngle=(90-CGFloat(progress.degrees)) * .pi/180
            let thumb=NSRect(x:c.x+cos(thumbAngle)*r-9,y:c.y+sin(thumbAngle)*r-9,width:18,height:18)
            NSColor(calibratedRed:0.72,green:0.87,blue:1,alpha:1).setFill();NSBezierPath(ovalIn:thumb).fill()
            let face=NSRect(x:c.x-22,y:c.y-22,width:44,height:44)
            NSColor(calibratedRed:0.12,green:0.22,blue:0.32,alpha:1).setFill();NSBezierPath(roundedRect:face,xRadius:12,yRadius:12).fill()
            if let image=NSImage(systemSymbolName:"lock.fill",accessibilityDescription:nil)?.withSymbolConfiguration(.init(paletteColors:[.white])) {image.draw(in:NSRect(x:c.x-9,y:c.y-11,width:18,height:22))}
            setAccessibilityValue("\(Int(fraction*100)) percent")
        }
        override func mouseDown(with event:NSEvent) {
            window?.makeFirstResponder(self);progress.begin(convert(event.locationInWindow,from:nil),center:center);needsDisplay=true
        }
        override func mouseDragged(with event:NSEvent) {
            if progress.move(convert(event.locationInWindow,from:nil),center:center) {_ = ControlLock.shared.unlock(swipe:progress.degrees)}
            needsDisplay=true
        }
        override func mouseUp(with event:NSEvent) {progress=CircularUnlockProgress();needsDisplay=true}
        override func keyDown(with event:NSEvent) {
            guard !event.isARepeat,event.keyCode==49 || event.keyCode==36,heldAt==nil else {return}
            heldAt=Date()
            let ticker=Timer(timeInterval:0.04,repeats:true) {[weak self] _ in
                guard let self,let started=self.heldAt else {return}
                let seconds=Date().timeIntervalSince(started);self.holdProgress=min(1,seconds/ControlLock.unlockDuration);self.needsDisplay=true
                if seconds>=ControlLock.unlockDuration {self.cleanUp();_ = ControlLock.shared.unlock(heldFor:seconds)}
            };timer=ticker;RunLoop.main.add(ticker,forMode:.common)
        }
        override func keyUp(with event:NSEvent) {if event.keyCode==49 || event.keyCode==36 {cleanUp()}}
        override func resignFirstResponder()->Bool {cleanUp();return super.resignFirstResponder()}
        // VoiceOver focuses this control; Space/Return must still be held for three seconds.
        override func accessibilityPerformPress()->Bool {window?.makeFirstResponder(self);return true}
        func cleanUp() {timer?.invalidate();timer=nil;heldAt=nil;holdProgress=0;needsDisplay=true}
    }
    func makeNSView(context:Context)->UnlockView {
        let view=UnlockView();view.setAccessibilityElement(true);view.setAccessibilityRole(.button)
        view.setAccessibilityLabel("Unlock Controls");view.setAccessibilityHelp("Drag clockwise around the ring, or hold Space for 1.5 seconds")
        return view
    }
    func updateNSView(_ view:UnlockView,context:Context) {}
    static func dismantleNSView(_ view:UnlockView,coordinator:()) {view.cleanUp()}
}
struct UnlockShield:View {
    var body:some View {Color.black.opacity(0.12).allowsHitTesting(false)}
}

private struct PlayerFitHeightKey:PreferenceKey {
    static var defaultValue:CGFloat=0
    static func reduce(value:inout CGFloat,nextValue:()->CGFloat) {value=max(value,nextValue())}
}
private struct QueueFitHeightKey:PreferenceKey {
    static var defaultValue:CGFloat=0
    static func reduce(value:inout CGFloat,nextValue:()->CGFloat) {value=max(value,nextValue())}
}
struct PlayerView: View {
    @ObservedObject var player = Player.shared
    @ObservedObject var lock = ControlLock.shared
    @StateObject private var ui = PlayerViewState()
    @ObservedObject var setup = SetupLock.shared
    @ObservedObject var playlistWindow = PlaylistWindowState.shared
    @ObservedObject var hints = HintPreferences.shared
    @ObservedObject var placement = FloatingPlacement.shared
    @ObservedObject var windows = WindowPresentation.shared
    @ObservedObject var workspace=WorkspaceState.shared
    @ObservedObject var playbackDrawer=PlaybackDrawerState.shared
    var compact = false
    var settingsOnly = false
    var embedded = false
    @ObservedObject var appearance = AppearancePreferences.shared
    var playlistOnly = false
    var menuBar = false
    @ViewBuilder var body: some View {
        VStack(spacing:0) {
            if !embedded && playlistOnly {
                HStack {Spacer();HintToggleButton();ControlsLockButton(compact:compact).frame(width:compact ? 80:140,height:compact ? 28:44)}
                    .padding(.horizontal,compact ? 14:16).padding(.vertical,compact ? 5:8)
            }
            Group { if settingsOnly { settings } else if playlistOnly { detachedPlaylist } else { playerBody } }
                .overlay {if lock.isLocked && (settingsOnly || playlistOnly) {Color.black.opacity(0.14).contentShape(Rectangle())}}
        }
            .onChange(of:lock.isLocked) {_,locked in if locked {ui.patchOpen=false;ui.modesOpen=false;AppDelegate.shared.hidePlaybackDrawer()}}
            .audioFileDrop(enabled:!settingsOnly)
            .fixedControlHints(enabled:!embedded).font(.stage(.body))
    }
    @ViewBuilder private var playerBody: some View {
        if compact {ScrollView(.vertical) {stageBody(wide:false).background(GeometryReader {proxy in Color.clear.preference(key:PlayerFitHeightKey.self,value:proxy.size.height)})}.scrollIndicators(.hidden).frame(minWidth:380).onPreferenceChange(PlayerFitHeightKey.self) {AppDelegate.shared.measureMiniContent($0)}}
        else if let section=workspace.section {workspaceBody(section)}
        else {
            GeometryReader { geometry in
                let wide=geometry.size.width >= 840
                let required:CGFloat=playlistWindow.detached ? 660:(wide ? 720:820)
                if windows.autoFit {
                    ScrollView(.vertical) {
                        stageBody(wide:wide).fixedSize(horizontal:false,vertical:true)
                            .background(GeometryReader {proxy in Color.clear.preference(key:PlayerFitHeightKey.self,value:proxy.size.height)})
                    }.scrollIndicators(.hidden).onPreferenceChange(PlayerFitHeightKey.self) {windows.measure($0)}
                        .onChange(of:hints.enabled) {_,_ in windows.requestFit()}
                }else if geometry.size.height < required {
                    ScrollView(.vertical) {stageBody(wide:wide).frame(minHeight:required)}
                }else {stageBody(wide:wide)}
            }
                .frame(minWidth:600,minHeight:!playlistWindow.detached && playlistWindow.shown ? 420:320)
        }
    }
    private func workspaceBody(_ section:WorkspaceSection)->some View {
        VStack(spacing:10) {
            header
            ScrollView(.horizontal) {
                HStack(spacing:6) {
                    Button {workspace.player()} label:{MarkerLabel("Player",systemImage:"play.fill").font(.stage(size:11)).padding(7)}.buttonStyle(PlayerControlStyle())
                    ForEach(WorkspaceSection.allCases) {tab in
                        Button {workspace.open(tab,at:.inside)} label:{Text(tab.title).font(.stage(size:11)).padding(7)}
                            .buttonStyle(PlayerControlStyle(active:section == tab)).accessibilityLabel("Workspace: "+tab.title)
                    }
                }
            }.fixedSize(horizontal:false,vertical:true).disabled(lock.isLocked)
            WorkspacePane(section:section).disabled(lock.isLocked)
            HStack(spacing:10) {
                Button {player.toggle()} label:{MarkerIcon(systemName:player.playing ? "pause.fill":"play.fill",size:20).frame(width:38,height:34)}
                    .buttonStyle(PlayerControlStyle(primary:true)).accessibilityLabel(player.playing ? "Pause":"Play").disabled(setup.playbackBlocked || player.current == nil)
                Text(player.current?.title ?? "No track").font(.stage(size:13)).lineLimit(1)
                Spacer()
                Text("\(timeLabel(player.elapsed)) / \(timeLabel(player.duration))").font(.stage(size:12)).monospacedDigit()
                Button {workspace.player()} label:{MarkerIcon(systemName:"xmark").frame(width:30,height:30)}.buttonStyle(PlayerControlStyle()).accessibilityLabel("Return to Player")
            }.disabled(lock.isLocked)
        }.padding(16).frame(minWidth:660,minHeight:500).foregroundStyle(Color(stageHex:appearance.theme.text)).preferredColorScheme(AppearancePreferences.shared.theme.isLight ? .light:.dark)

    }
    private func stageBody(wide:Bool) -> some View {
        VStack(spacing:appearance.theme.spacing) {
            header
            QuickActionBar()
            BackupStatusStrip()
            let layout = wide && !playlistWindow.detached && playlistWindow.shown ? AnyLayout(HStackLayout(alignment:.top,spacing:22)) : AnyLayout(VStackLayout(spacing:10))
            layout {
                playbackPanel.disabled(lock.isLocked).opacity(lock.isLocked ? 0.78:1).frame(maxWidth:.infinity,alignment:.top)
                if !playlistWindow.detached && playlistWindow.shown {playlistPanel.disabled(lock.isLocked).frame(maxWidth:.infinity,maxHeight:compact || windows.autoFit ? nil:.infinity,alignment:.top)}
            }
        }
        .padding(compact ? 14 : 16).frame(maxWidth:.infinity,maxHeight:compact || windows.autoFit ? nil:.infinity,alignment:.top)
        .foregroundStyle(Color(stageHex:appearance.theme.text)).preferredColorScheme(AppearancePreferences.shared.theme.isLight ? .light:.dark).font(.stage(.body))

        .onChange(of:playlistWindow.detached) { _, detached in if detached { ui.playlist = false } }
        .onChange(of:lock.isLocked) { _, locked in if locked { ui.settings = false; ui.playlist = false; ui.protection = false } }
    }
    private var playbackPanel: some View {
        VStack(spacing:10) {
                HStack(alignment: .top, spacing: 10) {
                    StageDeck(player: player, track: player.deckTrack(right:false), right: false, compact: compact).disabled(lock.isLocked).allowsHitTesting(!lock.isLocked)
                    StageDeck(player: player, track: player.deckTrack(right:true), right: true, compact: compact).disabled(lock.isLocked).allowsHitTesting(!lock.isLocked)
                }.overlay(alignment:.trailing) {
                    PatchHoldEdge {AppDelegate.shared.toggleSettingsWindow()}.frame(width:10).offset(x:10).disabled(false)
                }
                transport
                if let error = player.error { Text(error).font(.stage(size: 11)).foregroundStyle(.orange).fixedSize(horizontal:false, vertical:true) }
        }
    }
    private var playlistPanel: some View {
        VStack(spacing:8) {
            GeometryReader {geometry in
                let narrow=compact || geometry.size.width<520
                HStack(spacing:8) {
                    HStack(spacing:8) {
                        PlaylistSortMenu(player:player)
                    }.fixedSize().frame(width:narrow ? 92:190,alignment:.leading)
                    Text(player.playlistName).font(.stage(size:compact ? 11:14,weight:.semibold)).lineLimit(1)
                        .frame(maxWidth:.infinity).help(player.playlistName).accessibilityLabel("Playlist Name").accessibilityValue(player.playlistName)
                    PlaylistActionsButton(player:player,fromMini:compact,compact:compact).frame(width:narrow ? 92:190,alignment:.trailing)
                }
            }.frame(height:38)
            if !playlistWindow.detached,playlistWindow.shown {if compact {queue.frame(height:200)}else {queue}}
        }
    }
    private var playlistManageMenu:some View {
        Menu {playlistActions} label:{
            HStack(spacing:6) {
                Image(systemName:player.playlistURL == nil ? "square.and.arrow.down":"folder")
                Text(player.playlistURL == nil ? "Save playlist":player.playlistName).font(.stage(size:11)).lineLimit(1)
            }.frame(maxWidth:compact ? 210:320,alignment:.leading).padding(7)
        }.menuStyle(.borderlessButton).fixedSize(horizontal:false,vertical:true)
            .accessibilityLabel("Playlist Files").help(player.playlistName)
    }
    @ViewBuilder private var playlistActions: some View {
        Button("Rename Playlist…") {player.requestRenamePlaylist()}.disabled(setup.editsBlocked)
        Button("New Playlist…") {ui.playlist=false;player.requestNewPlaylist()}.disabled(setup.editsBlocked)
        Button("Delete Playlist…",role:.destructive) {ui.playlist=false;player.requestDeletePlaylist()}.disabled(setup.editsBlocked || !player.canDeletePlaylist)
        Divider()
        Button("Save Playlist") { ui.playlist = false; player.savePlaylist() }
        Button("Save Playlist As…") { ui.playlist = false; player.savePlaylist(asNew:true) }
        Button("Open Playlist…") { ui.playlist = false; player.openPlaylist() }.disabled(setup.editsBlocked)
        if !player.recentPlaylists.isEmpty {
            Menu("Recent Playlists") { ForEach(player.recentPlaylists,id:\.path) { url in Button(url.deletingPathExtension().lastPathComponent) { ui.playlist = false; player.openPlaylist(url) } } }.disabled(setup.editsBlocked)
        }
    }
    private func playlistPresentationButton(toMini:Bool)->some View {
        Button {
            ui.playlist=false
            if playlistWindow.detached {playlistWindow.attach(toMini:toMini)}else {playlistWindow.detach(fromMini:toMini)}
        } label: {
            MarkerIcon(systemName:playlistWindow.detached ? "playlist.embed":"playlist.detach",size:21).frame(width:36,height:34)
        }.buttonStyle(PlayerControlStyle(active:playlistWindow.detached))
            .accessibilityLabel(playlistWindow.detached ? "Embed Playlist":"Separate Playlist")
            .accessibilityValue(playlistWindow.detached ? "Separate window":"Inside player")
            .stageHint(playlistWindow.detached ? "Bring the playlist back inside this player":"Move the playlist into its own window")
    }
    private var miniPlaylist: some View {
        VStack(alignment:.leading,spacing:10) {
            HStack {
                Text(player.playlistName).font(.stage(size:14,weight:.semibold)); Spacer()
                playlistPresentationButton(toMini:true)
            }
            if setup.isLocked { MarkerLabel("Setup locked",systemImage:"lock.fill").font(.stage(size:10)).foregroundStyle(accent) }
            queue.frame(height:min(300,max(100,CGFloat(player.tracks.count)*56)))
            Divider()
            HStack {
                playlistManageMenu
                Spacer()
                Button("Full Queue") { ui.playlist = false; AppDelegate.shared.showMain() }.buttonStyle(PlayerControlStyle()).padding(3)
            }
        }.padding(14).frame(width:340).foregroundStyle(Color(stageHex:appearance.theme.text)).preferredColorScheme(AppearancePreferences.shared.theme.isLight ? .light:.dark).font(.stage(.body))
    }
    private var detachedPlaylist: some View {
        VStack(spacing:12) {
            HStack {
                setupLockButton
                playlistManageMenu
                Spacer()
                Button { AppDelegate.shared.minimize(AppDelegate.shared.playlistWindow) } label: { MarkerIcon(systemName:"minus").frame(width:28,height:28) }
                    .buttonStyle(PlayerControlStyle()).accessibilityLabel("Minimize Playlist").stageHint("Minimize playlist · restore from menu bar")
                Button {AppDelegate.shared.showSettingsWindow()} label:{Image(systemName:"slider.horizontal.3").frame(width:30,height:30)}
                    .buttonStyle(PlayerControlStyle()).accessibilityLabel("PATCH Settings").stageHint("Playlist position and all settings")
            }.fixedSize(horizontal:false,vertical:true).layoutPriority(1)
            HStack {
                Text("\(player.tracks.count) tracks").font(.stage(size:11)).foregroundStyle(.secondary)
                Spacer()
                PlaylistSortMenu(player:player)
                if setup.isLocked { MarkerLabel("Setup locked",systemImage:"lock.fill").font(.stage(size:10)).foregroundStyle(accent) }
            }
            queue.layoutPriority(-1)
            Divider()
            HStack(spacing:8) {
                Spacer()
                Button { player.openFiles() } label: { MarkerIcon(systemName:"plus").frame(width:30,height:30) }.buttonStyle(PlayerControlStyle()).disabled(setup.editsBlocked).accessibilityLabel("Add Audio")
            }
            .fixedSize(horizontal:false,vertical:true).layoutPriority(1)
        }.padding(16).padding(.top,8).frame(minWidth:380)
            .foregroundStyle(Color(stageHex:appearance.theme.text)).preferredColorScheme(AppearancePreferences.shared.theme.isLight ? .light:.dark).font(.stage(.body))
            .disabled(lock.isLocked).allowsHitTesting(!lock.isLocked)

            .onChange(of:hints.enabled) {_,_ in AppDelegate.shared.ensurePlaylistControlsVisible()}
            .onChange(of:lock.isLocked) { _, locked in if locked { ui.protection = false } }
    }
    private var setupLockButton: some View {
        Button {
            if setup.isLocked { setup.unlock() } else { setup.lock(); ui.protection = false }
        } label: {
            MarkerIcon(systemName:setup.isLocked ? "lock.fill":"lock.open").font(.stage(size:13)).frame(width:30,height:30)
        }.buttonStyle(PlayerControlStyle(outline:.capsule,active:setup.isLocked))
            .accessibilityLabel(setup.isLocked ? "Unlock Setup":"Lock Setup")
            .stageHint(setup.isLocked ? "Unlock protected controls":"Protect your selected controls")
    }
    private func toolbarButton(_ title:String,_ icon:String,active:Bool=false,action:@escaping ()->Void)->some View {
        Button(action:action) {MarkerIcon(systemName:icon,size:18).frame(width:32,height:32)}
            .buttonStyle(PlayerControlStyle(active:active)).accessibilityLabel(title).stageHint(title)
    }
    private var modesButton:some View {
        Button {AppDelegate.shared.togglePlaybackDrawer(fromMini:compact)} label:{
            VStack(spacing:2) {MarkerIcon(systemName:"slider.horizontal.3",size:14);Text("MODES").font(.system(size:6,weight:.bold))}
                .frame(width:32,height:32)
        }.buttonStyle(PlayerControlStyle(active:playbackDrawer.open)).accessibilityLabel("Playback Modes")
            .accessibilityValue(playbackDrawer.open ? "Open":"Closed").stageHint("Show or hide playback modes").disabled(lock.isLocked)
    }
    private var header:some View {
        HStack(spacing:compact ? 6:8) {
            HStack(spacing:compact ? 6:8) {
            modesButton
            if !compact {
                Button {AppDelegate.shared.toggleMini()} label:{MarkerIcon(systemName:"pip",size:18).frame(width:32,height:32)}
                    .buttonStyle(PlayerControlStyle(active:windows.mini)).accessibilityLabel("Mini Player")
                    .stageHint("Switch to Mini player").mapAction("mini")
                toolbarButton("Nano Player","player.nano",active:windows.nano) {AppDelegate.shared.toggleNano()}
            }else {
                toolbarButton("Open Main Player","player.fullscreen") {AppDelegate.shared.showMain()}
                toolbarButton("Nano Player","player.nano",active:windows.nano) {AppDelegate.shared.toggleNano()}
            }
            Spacer(minLength:4)
            Spacer(minLength:4)
            Button {AppDelegate.shared.toggleSettingsWindow()} label:{
                if compact {MarkerIcon(systemName:"slider.horizontal.3",size:18).frame(width:32,height:32)}
                else {MarkerLabel("PATCH",systemImage:"slider.horizontal.3").font(.stage(size:12)).padding(.horizontal,9).frame(height:32).fixedSize(horizontal:true,vertical:false)}
            }
                .buttonStyle(PlayerControlStyle()).accessibilityLabel("PATCH Settings")
                .stageHint("PATCH · all settings, hints and playlist position")
            toolbarButton("Minimize Window","minus") {
                if menuBar {AppDelegate.shared.popover.performClose(nil)}else {AppDelegate.shared.minimize(compact ? AppDelegate.shared.miniWindow:AppDelegate.shared.mainWindow)}
            }
            }.disabled(lock.isLocked)
            HintToggleButton(small:compact).disabled(lock.isLocked)
            ControlsLockButton(compact:true,iconOnly:true).frame(width:32,height:32)
        }.overlay {if compact {SuppliedHardPlayWordmark().frame(width:48,height:28).foregroundStyle(player.playing ? Color(stageHex:"C22630"):Color(stageHex:appearance.theme.text)).allowsHitTesting(false)}}
    }
    private var transport: some View {
        GeometryReader { geometry in
            let side = compact ? CGFloat(96) : geometry.size.width / 3
            HStack(spacing:0) {
                HStack(spacing:compact ? 4:8) {
                    PlayerVolumeButton(player:player,compact:compact)
                    Spacer(minLength:0)
                    CrossfadeControl(player:player,iconOnly:true,small:compact)
                }.frame(width:side,alignment:.leading)
                HStack(spacing:0) {
                    transportCell {Button {player.previous()} label:{Image(systemName:"backward.end.fill").font(.system(size:compact ? 19:24)).frame(width:compact ? 34:50,height:compact ? 42:50)}.buttonStyle(PlayerControlStyle()).accessibilityLabel("Previous Track").disabled(setup.selectionBlocked || player.current == nil).stageHint("Previous track").mapAction("previous")}
                    transportCell {Button {player.toggle()} label:{HardPlayTransport(playing:player.playing,compact:compact,limit:compact ? 46:72)}.buttonStyle(HardPlayPressStyle()).accessibilityLabel(player.playing ? "Pause":"Play").disabled(setup.playbackBlocked || player.current == nil).stageHint(player.playing ? "Pause playback":"Play").mapAction("playPause")}
                    transportCell {Button {player.next()} label:{Image(systemName:"forward.end.fill").font(.system(size:compact ? 19:24)).frame(width:compact ? 34:50,height:compact ? 42:50)}.buttonStyle(PlayerControlStyle()).accessibilityLabel("Next Track").disabled(setup.selectionBlocked || player.current == nil).stageHint("Next track").mapAction("next")}
                }.frame(width:geometry.size.width - side * 2)
                HStack(spacing:0) {
                    RepeatControl(compact:true,small:compact)
                    ShuffleControl(small:compact)
                    Spacer(minLength:8)
                    Button {playlistWindow.toggleList(fromMini:compact)} label:{Image(systemName:"list.bullet").font(.system(size:compact ? 17:20,weight:.medium)).frame(width:compact ? 32:44,height:compact ? 34:38)}.buttonStyle(PlayerControlStyle(active:playlistWindow.isShown(fromMini:compact))).accessibilityLabel("Open Playlist").accessibilityValue(playlistWindow.isShown(fromMini:compact) ? "Shown":"Hidden").stageHint("Show or hide the playlist")
                }.frame(width:side)
            }.frame(height:compact ? 50:68)
        }.frame(height:compact ? 50:68).padding(.vertical,4).disabled(lock.isLocked)
    }
    private func transportCell<Content:View>(@ViewBuilder _ content:()->Content)->some View {
        content().frame(minWidth:0,maxWidth:.infinity,minHeight:compact ? 50:68)
    }
    private var restartButtons: some View {
        HStack(spacing:12) {
            RepeatControl()
        }.disabled(player.current == nil || setup.playbackBlocked || lock.isLocked)
    }
    private var settings: some View {PatchSettingsView()}
    private func fadeTitle(_ mode:FadeMode)->String { mode == .none ? "Off" : "\(mode.title) · \(String(format:"%g",mode.seconds)) s" }
    private var queue: some View {
        ScrollView {
            LazyVStack(spacing:3) {
                if player.tracks.isEmpty { Text("Drop your music here").font(.stage(size:12)).foregroundStyle(Color(stageHex:AppearancePreferences.shared.theme.text).opacity(0.65)).frame(maxWidth:.infinity).padding(.vertical,25) }
                ForEach(player.tracks) { track in
                    QueueTrackRow(player:player,track:track,compact:compact)
                }
            }.background(GeometryReader {proxy in Color.clear.preference(key:QueueFitHeightKey.self,value:proxy.size.height)})
        }.scrollIndicators(.hidden).frame(height:windows.autoFit && !compact && !playlistOnly ? min(360,max(54,ui.queueContentHeight>0 ? ui.queueContentHeight:CGFloat(player.tracks.count)*55)):nil)
            .frame(minHeight:windows.autoFit && !compact && !playlistOnly ? 54:(playlistOnly ? 0:(compact ? 100:160)),maxHeight:windows.autoFit && !compact && !playlistOnly ? nil:.infinity)
            .onPreferenceChange(QueueFitHeightKey.self) {height in if abs(ui.queueContentHeight-height)>0.5 {ui.queueContentHeight=height}}
    }
}
