import AppKit
import SwiftUI
import Combine

/// No tap is dispatched after a stop, cancelled drag, or cancelled window gesture.
struct PreviewInteraction {
    static let holdDuration:TimeInterval=0.5
    private(set) var began:TimeInterval?
    private(set) var stopped=false
    mutating func begin(at time:TimeInterval) {began=time;stopped=false}
    mutating func advance(at time:TimeInterval)->Bool {
        guard let began,!stopped,time-began>=Self.holdDuration else {return false}
        stopped=true;return true
    }
    mutating func finish()->Bool {let tap=began != nil && !stopped;cancel();return tap}
    mutating func cancel(){began=nil;stopped=false}
    static func seek(_ seconds:Double,duration:Double)->Double {guard seconds.isFinite,duration.isFinite,duration>0 else {return 0};return min(max(0,seconds),max(0,duration-1/600))}
}
struct PreviewPressControl:NSViewRepresentable {
    let identity:String,symbol:String
    let active:Bool,enabled:Bool
    let tap:()->Void,stop:()->Void
    @ObservedObject private var appearance=AppearancePreferences.shared
    @Environment(\.isEnabled) private var environmentEnabled
    final class Pad:NSView {
        var identity="",symbol="headphones",active=false,enabled=false
        var tap:(()->Void)?,stop:(()->Void)?
        var ink=NSColor.white,fill=NSColor.darkGray
        private var gesture=PreviewInteraction()
        private var timer:Timer?
        private var progress:Double=0
        private var observers:[NSObjectProtocol]=[]
        override var mouseDownCanMoveWindow:Bool {false}
        override func acceptsFirstMouse(for event:NSEvent?)->Bool {true}
        override func draw(_ dirty:NSRect) {
            let shape=NSBezierPath(roundedRect:bounds.insetBy(dx:0.5,dy:0.5),xRadius:6,yRadius:6)
            (active ? ink.withAlphaComponent(0.13):fill).setFill();shape.fill()
            ink.withAlphaComponent(0.14).setStroke();shape.stroke()
            if progress>0 {NSGraphicsContext.saveGraphicsState();shape.addClip();NSColor.systemRed.withAlphaComponent(0.35).setFill();NSRect(x:0,y:0,width:bounds.width*progress,height:bounds.height).fill();NSGraphicsContext.restoreGraphicsState()}
            let name=gesture.stopped ? "stop.fill":symbol
            // Permanent headphones with a status glyph inside; native paths need no image allocation.
            ink.withAlphaComponent(enabled ? 1:0.35).setStroke()
            ink.withAlphaComponent(enabled ? 1:0.35).setFill()
            let x=bounds.midX,y=bounds.midY-2
            let phones=NSBezierPath();phones.lineWidth=1.6;phones.lineCapStyle = .round
            phones.appendArc(withCenter:NSPoint(x:x,y:y+1),radius:8,startAngle:0,endAngle:180)
            phones.stroke()
            for dx:CGFloat in [-9,6] {NSBezierPath(roundedRect:NSRect(x:x+dx,y:y-6,width:3,height:8),xRadius:1,yRadius:1).fill()}
            if name=="play.fill" {
                let glyph=NSBezierPath();glyph.move(to:NSPoint(x:x-2,y:y-4));glyph.line(to:NSPoint(x:x+4,y:y));glyph.line(to:NSPoint(x:x-2,y:y+4));glyph.close();glyph.fill()
            } else if name=="pause.fill" {
                NSRect(x:x-3,y:y-3.5,width:2,height:7).fill();NSRect(x:x+1,y:y-3.5,width:2,height:7).fill()
            } else {NSBezierPath(roundedRect:NSRect(x:x-3,y:y-3,width:6,height:6),xRadius:0.5,yRadius:0.5).fill()}

        }
        override func mouseDown(with event:NSEvent) {
            cancel();guard enabled else {return};gesture.begin(at:ProcessInfo.processInfo.systemUptime)
            // Hold only applies to an existing audition; never start a new preview after a long hold.
            let ticker=Timer(timeInterval:0.02,repeats:true) {[weak self] _ in self?.advance()};timer=ticker;RunLoop.main.add(ticker,forMode:.common)
        }
        private func advance() {
            guard let began=gesture.began else {return}
            let now=ProcessInfo.processInfo.systemUptime;progress=min(1,(now-began)/PreviewInteraction.holdDuration)
            if gesture.advance(at:now) {timer?.invalidate();timer=nil;if active {stop?()}}
            needsDisplay=true
        }
        override func mouseDragged(with event:NSEvent) {if !bounds.contains(convert(event.locationInWindow,from:nil)) {cancel()}}
        override func mouseUp(with event:NSEvent) {
            advance();let inside=bounds.contains(convert(event.locationInWindow,from:nil)),tap=gesture.finish();timer?.invalidate();timer=nil;progress=0;needsDisplay=true
            if enabled,inside,tap {self.tap?()}
        }
        override func accessibilityPerformPress()->Bool {guard enabled else {return false};tap?();return true}
        func cancel(){timer?.invalidate();timer=nil;gesture.cancel();progress=0;needsDisplay=true}
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow();cancel();observers.forEach {NotificationCenter.default.removeObserver($0)};observers=[]
            if let window {observers.append(NotificationCenter.default.addObserver(forName:NSWindow.didResignKeyNotification,object:window,queue:.main) {[weak self] _ in self?.cancel()})}
            observers.append(NotificationCenter.default.addObserver(forName:NSApplication.didResignActiveNotification,object:nil,queue:.main) {[weak self] _ in self?.cancel()})
        }
        deinit {timer?.invalidate();observers.forEach {NotificationCenter.default.removeObserver($0)}}
    }
    func makeNSView(context:Context)->Pad {let pad=Pad();pad.setAccessibilityElement(true);pad.setAccessibilityRole(.button);return pad}
    func updateNSView(_ pad:Pad,context:Context) {
        if pad.identity != identity {pad.cancel()};pad.identity=identity;pad.symbol=symbol;pad.active=active;pad.enabled=enabled && environmentEnabled
        pad.tap=tap;pad.stop=stop;pad.ink=NSColor(Color(stageHex:appearance.theme.text));pad.fill=NSColor(Color(stageHex:appearance.theme.surfaceColor))
        pad.setAccessibilityValue(active ? (symbol=="play.fill" ? "Preview Playing":"Preview Paused"):"Preview Stopped")
        pad.setAccessibilityEnabled(pad.enabled);pad.setAccessibilityLabel(active ? "Preview Play / Pause · hold 0.5s to stop":"Preview Track");pad.needsDisplay=true
        if !pad.enabled {pad.cancel()}
    }
    static func dismantleNSView(_ view:Pad,coordinator:()) {view.cancel()}
}
/// Progress updates the native waveform in place; SwiftUI layout runs only on state/theme changes.
struct PreviewWaveCanvas:NSViewRepresentable {
    let track:Track
    let peaks:[Double]
    let ink:NSColor,secondary:NSColor
    let output:String
    let enabled:Bool
    let preview:MenuPreviewPlayer
    final class Canvas:NSView {
        let wave=StageWaveform.WaveView()
        let label=NSTextField(labelWithString:"")
        private var subscription:AnyCancellable?
        private var source:PreviewTimeline?
        var title="",output="",enabled=false
        override init(frame:NSRect) {
            super.init(frame:frame);label.font = .monospacedSystemFont(ofSize:8,weight:.medium);label.lineBreakMode = .byTruncatingMiddle
            addSubview(label);addSubview(wave)
            wave.onFinish={ [weak self] in DispatchQueue.main.async {guard let self else {return};self.wave.enabled=self.enabled} }
        }
        required init?(coder:NSCoder) {fatalError("init(coder:) is not supported")}
        override func layout() {
            super.layout();label.frame=NSRect(x:0,y:max(0,bounds.height-11),width:bounds.width,height:11)
            wave.frame=NSRect(x:0,y:0,width:bounds.width,height:max(1,bounds.height-12))
        }
        func bind(_ timeline:PreviewTimeline) {
            guard source !== timeline else {return};source=timeline
            subscription=timeline.$elapsed.combineLatest(timeline.$duration).sink { [weak self] elapsed,duration in self?.updateProgress(elapsed,duration) }
        }
        func updateProgress(_ elapsed:Double,_ duration:Double) {
            let value="PREVIEW → "+output+"   "+timeLabel(elapsed)+" / "+timeLabel(duration)
            if label.stringValue != value {label.stringValue=value}
            let bins=max(1,min(wave.peaks.count,Int(max(1,wave.bounds.width/4))))
            let previous=wave.duration>0 ? Int(min(1,max(0,wave.elapsed/wave.duration))*Double(bins)):0
            let next=duration>0 ? Int(min(1,max(0,elapsed/duration))*Double(bins)):0
            let durationChanged=wave.duration != duration
            wave.elapsed=elapsed;wave.duration=duration
            // Peaks are fixed bars: until the played-bar index changes, the pixels are identical.
            if previous != next || durationChanged {wave.needsDisplay=true}
            let accessibilityValue=timeLabel(elapsed)+" / "+timeLabel(duration)
            if wave.accessibilityValue() as? String != accessibilityValue {wave.setAccessibilityValue(accessibilityValue)}
        }
    }
    func makeNSView(context:Context)->Canvas {Canvas(frame:.zero)}
    func updateNSView(_ view:Canvas,context:Context) {
        view.title=track.title;view.output=output;view.enabled=enabled;view.label.textColor=secondary
        let changed=view.wave.peaks != peaks || view.wave.ink != ink
        if view.wave.identity != track.id {view.wave.cancelGesture()};view.wave.identity=track.id;view.wave.peaks=peaks;view.wave.ink=ink;view.wave.gain=1
        if view.wave.enabled != enabled {view.wave.enabled=enabled;view.window?.invalidateCursorRects(for:view.wave)}
        view.wave.action={seconds,_ in preview.seek(seconds,track:track)}
        view.wave.setAccessibilityElement(true);view.wave.setAccessibilityRole(.image);view.wave.setAccessibilityLabel("Preview Waveform: "+track.title)
        view.wave.setAccessibilityHelp("Preview only · click or drag to seek")
        view.bind(preview.timeline);view.updateProgress(preview.elapsed,preview.duration)
        if changed {view.wave.needsDisplay=true}
    }
}
struct PlaylistPreviewWaveform:View {
    let track:Track
    var compact=false
    @ObservedObject private var preview=MenuPreviewPlayer.shared
    @ObservedObject private var waves=Waveforms.shared
    @ObservedObject private var appearance=AppearancePreferences.shared
    @ObservedObject private var lock=ControlLock.shared
    @ObservedObject private var setup=SetupLock.shared
    var body:some View {
        PreviewWaveCanvas(track:track,peaks:waves.cache[Waveforms.key(track)]?.peaks ?? [],ink:NSColor(Color(stageHex:appearance.theme.waveColor)),secondary:NSColor(Color(stageHex:appearance.theme.secondaryColor)),output:preview.outputName,enabled:preview.trackID==track.id && preview.safe && !lock.isLocked && !setup.playbackBlocked,preview:preview)
            .frame(maxWidth:.infinity).frame(height:compact ? 40:46)
            .help(track.title+" · Preview only · click or drag to seek")
            .task(id:Waveforms.key(track)) {await waves.load(track)}
    }
}
func checkPreviewInteraction() {
    var gesture=PreviewInteraction();gesture.begin(at:10);precondition(!gesture.advance(at:10.49));precondition(gesture.finish())
    gesture.begin(at:20);precondition(gesture.advance(at:20.5));precondition(!gesture.advance(at:21));precondition(!gesture.finish())
    gesture.begin(at:30);gesture.cancel();precondition(!gesture.finish() && !gesture.advance(at:31))
    precondition(PreviewInteraction.seek(-10,duration:120)==0)
    precondition(PreviewInteraction.seek(.nan,duration:120)==0)
    precondition(PreviewInteraction.seek(500,duration:120)<120)
    precondition(PreviewInteraction.seek(47,duration:120)==47)
    print("PASS: preview tap vs 0.5s hold; stop fires once without extra tap; cancellation; finite bounded seek")
}
