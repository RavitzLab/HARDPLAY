import SwiftUI
import AppKit

/// Explicit per-waveform permission; never persisted across tracks or app launches.
final class WaveformSeekPermission:ObservableObject {
    @Published private(set) var unlocked=false
    private var expiry:DispatchWorkItem?
    func toggle() {if unlocked {lock()}else {unlocked=true;let item=DispatchWorkItem {[weak self] in self?.lock()};expiry=item;DispatchQueue.main.asyncAfter(deadline:.now()+5,execute:item)}}
    func begin(){expiry?.cancel();expiry=nil}
    func lock(){expiry?.cancel();expiry=nil;if unlocked {unlocked=false}}
    deinit {expiry?.cancel()}
}
struct WaveformSeekLock:View {
    @ObservedObject var permission:WaveformSeekPermission
    var available=true
    var body:some View {
        Button {permission.toggle()} label:{Image(systemName:permission.unlocked ? "lock.open":"lock.fill").font(.system(size:11,weight:.medium)).frame(width:22,height:22)}
            .buttonStyle(PlayerControlStyle(active:permission.unlocked))
            .accessibilityLabel("Waveform Seek Lock").accessibilityValue(permission.unlocked ? "Unlocked":"Locked")
            .stageHint("Unlock one seek · locks again on release or after 5 seconds unused")
            .disabled(!available)
    }
}
struct WaveformSeekGate {
    private(set) var identity:String?
    var armed:Bool {identity != nil}
    mutating func begin(_ id:String,enabled:Bool){identity=enabled ? id:nil}
    mutating func advance(_ id:String,enabled:Bool,inside:Bool)->Bool {guard enabled,inside,identity == id else {cancel();return false};return true}
    mutating func cancel(){identity=nil}
}

/// Owns pointer gestures so scrubbing never drags the player window.
struct StageWaveform:NSViewRepresentable {
    let identity:String
    let peaks:[Double]
    let duration:Double
    let elapsed:Double
    let gain:Double
    let color:Color
    let enabled:Bool
    var onBegin:()->Void = {}
    var onFinish:()->Void = {}
    let action:(Double,Bool)->Void
    final class WaveView:NSView {
        var identity="",peaks:[Double]=[],duration=0.0,elapsed=0.0,gain=0.0
        var ink=NSColor.white,enabled=false
        var action:((Double,Bool)->Void)?
        private var tracking:NSTrackingArea?
        private var pointer:CGFloat?
        private var gate=WaveformSeekGate()
        var onBegin:(()->Void)?
        var onFinish:(()->Void)?
        private var observers:[NSObjectProtocol]=[]
        private var lastDrag:TimeInterval=0
        override var mouseDownCanMoveWindow:Bool {false}
        override var acceptsFirstResponder:Bool {true}
        override func acceptsFirstMouse(for event:NSEvent?)->Bool {true}
        override func updateTrackingAreas(){super.updateTrackingAreas();if let tracking {removeTrackingArea(tracking)};tracking=NSTrackingArea(rect:bounds,options:[.mouseMoved,.mouseEnteredAndExited,.activeAlways,.inVisibleRect],owner:self);addTrackingArea(tracking!)}
        private func target(_ event:NSEvent)->Double {let x=convert(event.locationInWindow,from:nil).x;return Self.time(x:x,width:bounds.width,duration:duration)}
        static func time(x:CGFloat,width:CGFloat,duration:Double)->Double {guard duration.isFinite,duration>0,width>0 else {return 0};return min(1,max(0,Double(x/width)))*duration}
        override func draw(_ dirty:NSRect) {
            let area=NSRect(x:0,y:0,width:bounds.width,height:max(1,bounds.height-18))
            if !peaks.isEmpty {
                let count=min(peaks.count,max(1,Int(bounds.width/4)))
                for i in 0..<count {
                    let from=i*peaks.count/count,to=max(from+1,(i+1)*peaks.count/count)
                    let peak=peaks[from..<min(peaks.count,to)].max() ?? 0
                    let height=max(1,peak*(area.height-4)),x=Double(i)/Double(count)*bounds.width
                    let progress=duration>0 ? min(1,max(0,elapsed/duration)):0
                    ink.withAlphaComponent((Double(i)/Double(count)<=progress ? 1:0.45)*(0.35+min(1,max(0,gain))*0.65)).setFill()
                    NSBezierPath(roundedRect:NSRect(x:x,y:(area.height-height)/2,width:max(1.3,bounds.width/Double(count)-1.6),height:height),xRadius:1,yRadius:1).fill()
                }
            }else {NSColor.white.withAlphaComponent(0.12).setFill();NSRect(x:0,y:area.midY,width:area.width,height:1).fill()}
            if duration>0,let x=pointer {
                ink.withAlphaComponent(0.75).setFill();NSRect(x:x,y:0,width:1,height:area.height).fill()
                let text=timeLabel(Self.time(x:x,width:bounds.width,duration:duration))+(enabled ? " · Seek":"")
                let attrs:[NSAttributedString.Key:Any]=[.font:StageTypography.native(11),.foregroundColor:NSColor.white]
                let textSize=(text as NSString).size(withAttributes:attrs)
                let box=NSRect(x:min(max(0,x-textSize.width/2-6),max(0,bounds.width-textSize.width-12)),y:bounds.height-18,width:textSize.width+12,height:18)
                NSColor(calibratedRed:0.06,green:0.09,blue:0.14,alpha:0.96).setFill();NSBezierPath(roundedRect:box,xRadius:4,yRadius:4).fill()
                (text as NSString).draw(at:.init(x:box.minX+6,y:box.minY+2),withAttributes:attrs)
            }
        }
        func cancelGesture(){gate.cancel();needsDisplay=true}
        func finishGesture(){cancelGesture();if enabled {enabled=false;onFinish?()}}
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow();observers.forEach {NotificationCenter.default.removeObserver($0)};observers=[];cancelGesture()
            if let window {
                observers.append(NotificationCenter.default.addObserver(forName:NSWindow.didResignKeyNotification,object:window,queue:.main) {[weak self] _ in self?.finishGesture()})
                observers.append(NotificationCenter.default.addObserver(forName:NSApplication.didResignActiveNotification,object:nil,queue:.main) {[weak self] _ in self?.finishGesture()})
            }
        }
        deinit {observers.forEach {NotificationCenter.default.removeObserver($0)}}
        override func mouseEntered(with event:NSEvent){mouseMoved(with:event)}
        override func mouseMoved(with event:NSEvent){pointer=min(bounds.width,max(0,convert(event.locationInWindow,from:nil).x));needsDisplay=true}
        override func mouseExited(with event:NSEvent){pointer=nil;finishGesture()}
        override func mouseDown(with event:NSEvent) {
            cancelGesture();guard enabled,duration>0 else {return}
            window?.makeFirstResponder(self);mouseMoved(with:event)
            gate.begin(identity,enabled:enabled);onBegin?()
            action?(target(event),false)
        }
        override func mouseDragged(with event:NSEvent) {
            let point=convert(event.locationInWindow,from:nil)
            guard gate.advance(identity,enabled:enabled,inside:bounds.contains(point)) else {finishGesture();return}
            mouseMoved(with:event);let now=ProcessInfo.processInfo.systemUptime
            if now-lastDrag>=0.04 {lastDrag=now;action?(target(event),false)}
        }
        override func mouseUp(with event:NSEvent) {
            let point=convert(event.locationInWindow,from:nil)
            if gate.advance(identity,enabled:enabled,inside:bounds.contains(point)) {action?(target(event),false)}
            finishGesture()
        }
        override func keyDown(with event:NSEvent){guard enabled,duration>0 else {super.keyDown(with:event);return};if event.keyCode == 123 || event.keyCode == 124 {action?(min(duration,max(0,elapsed+(event.keyCode == 123 ? -1:1))),false);finishGesture()}else {super.keyDown(with:event)}}
        override func resetCursorRects(){addCursorRect(bounds,cursor:enabled ? .crosshair:.arrow)}
    }
    func makeNSView(context:Context)->WaveView {let view=WaveView();view.setAccessibilityElement(true);view.setAccessibilityRole(.image);view.setAccessibilityLabel("Interactive Audio Waveform");view.setAccessibilityHelp("Hover to inspect time. Unlock with the padlock, then click or drag to seek. Release to lock again.");return view}
    func updateNSView(_ view:WaveView,context:Context){if view.identity != identity || !enabled {view.cancelGesture()};view.identity=identity;view.peaks=peaks;view.duration=duration;view.elapsed=elapsed;view.gain=gain;view.ink=NSColor(color);view.enabled=enabled;view.onBegin=onBegin;view.onFinish=onFinish;view.action=action;view.needsDisplay=true;view.window?.invalidateCursorRects(for:view);view.setAccessibilityHelp(enabled ? "Hover to inspect time. Unlock with the padlock, then click or drag to seek. Release to lock again.":"Seeking is locked. Use the padlock next to the percentage. NEXT remains preview only.");view.setAccessibilityValue("\(timeLabel(elapsed)) / \(timeLabel(duration))")}
}
