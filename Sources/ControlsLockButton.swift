import AppKit
import SwiftUI

/// Native event handling avoids competing SwiftUI tap/long-press recognizers in floating panels.
struct ControlsLockButton:NSViewRepresentable {
    var compact=false
    var iconOnly=false
    var unlockOnly=false
    var wheel=false
    var onTap:(()->Void)?=nil
    @ObservedObject private var lock=ControlLock.shared
    @Environment(\.isEnabled) private var enabled
    final class Control:NSView {
        var compact=false,iconOnly=false,unlockOnly=false,wheel=false,enabled=true
        var onTap:(()->Void)?
        private var beganLocked=false
        private var began=false
        private var started:TimeInterval?
        private var timer:Timer?
        private var progress:Double=0
        private var resignObserver:NSObjectProtocol?
        override var mouseDownCanMoveWindow:Bool {false}
        override func acceptsFirstMouse(for event:NSEvent?)->Bool {true}
        override func draw(_ dirtyRect:NSRect) {
            let locked=ControlLock.shared.isLocked
            let ink=NSColor(Color(stageHex:AppearancePreferences.shared.theme.text))
            let shape=NSBezierPath(roundedRect:bounds.insetBy(dx:0.5,dy:0.5),xRadius:compact ? 9:12,yRadius:compact ? 9:12)
            (wheel ? ink.withAlphaComponent(locked ? 0.14:0.035):(locked ? NSColor.systemRed:NSColor.white)).setFill();shape.fill()
            NSGraphicsContext.saveGraphicsState();shape.addClip()
            if progress>0 {NSColor.white.withAlphaComponent(0.24).setFill();NSRect(x:0,y:0,width:bounds.width*progress,height:bounds.height).fill()}
            NSGraphicsContext.restoreGraphicsState()
            NSColor.black.withAlphaComponent(wheel ? 0:0.15).setStroke();shape.lineWidth=1;shape.stroke()
            let color=wheel ? ink:(locked ? NSColor.white:NSColor(Color(stageHex:"172C4D")))
            let text=iconOnly ? "":locked ? (progress>0 ? String(format:"%.1fs",max(0,ControlLock.unlockDuration*(1-progress))):"1.5s"):(wheel ? "":"LOCK")
            let font=NSFont.systemFont(ofSize:compact ? 10:13,weight:.bold)
            let attributes:[NSAttributedString.Key:Any]=[.font:font,.foregroundColor:color]
            let size=(text as NSString).size(withAttributes:attributes)
            let iconSize:CGFloat=iconOnly ? 18:14
            let width:CGFloat=iconSize+(text.isEmpty ? 0:5+size.width),left=(bounds.width-width)/2
            if let symbol=NSImage(systemSymbolName:locked ? "lock.fill":(wheel ? "chevron.down":"lock.open"),accessibilityDescription:nil)?.copy() as? NSImage {
                symbol.isTemplate=false;symbol.lockFocus();color.setFill();NSRect(origin:.zero,size:symbol.size).fill(using:.sourceIn);symbol.unlockFocus()
                symbol.draw(in:NSRect(x:left,y:(bounds.height-iconSize)/2,width:iconSize,height:iconSize))
            }
            (text as NSString).draw(at:NSPoint(x:left+19,y:(bounds.height-size.height)/2),withAttributes:attributes)
        }
        override func mouseDown(with event:NSEvent) {
            guard enabled else {return}
            cancel();began=true;beganLocked=ControlLock.shared.isLocked
            guard beganLocked else {return}
            started=ProcessInfo.processInfo.systemUptime
            let task=Timer(timeInterval:0.02,repeats:true) {[weak self] _ in
                guard let self,let start=self.started else {return}
                let seconds=ProcessInfo.processInfo.systemUptime-start
                self.progress=min(1,seconds/ControlLock.unlockDuration);self.needsDisplay=true
                if seconds>=ControlLock.unlockDuration {self.cancel();_ = ControlLock.shared.unlock(heldFor:seconds)}
            };timer=task;RunLoop.main.add(task,forMode:.common)
        }
        override func mouseDragged(with event:NSEvent) {if !bounds.insetBy(dx:-12,dy:-12).contains(convert(event.locationInWindow,from:nil)) {cancel()}}
        override func mouseUp(with event:NSEvent) {
            let tap=began && !beganLocked && bounds.contains(convert(event.locationInWindow,from:nil))
            cancel();if tap {activate()}
        }
        private func activate(){if enabled && !ControlLock.shared.isLocked {if unlockOnly {onTap?()}else {ControlLock.shared.lock()}}}
        override func accessibilityPerformPress()->Bool {activate();return true}
        func cancel(){timer?.invalidate();timer=nil;started=nil;began=false;progress=0;needsDisplay=true}
        override func viewDidMoveToWindow(){
            super.viewDidMoveToWindow()
            if let resignObserver {NotificationCenter.default.removeObserver(resignObserver)}
            if let window {resignObserver=NotificationCenter.default.addObserver(forName:NSWindow.didResignKeyNotification,object:window,queue:.main) {[weak self] _ in self?.cancel()}}else {resignObserver=nil;cancel()}
        }
        deinit {if let resignObserver {NotificationCenter.default.removeObserver(resignObserver)};timer?.invalidate()}
    }
    func makeNSView(context:Context)->Control {let view=Control();view.setAccessibilityElement(true);view.setAccessibilityRole(.button);return view}
    func updateNSView(_ view:Control,context:Context) {
        view.enabled=enabled;view.compact=compact;view.iconOnly=iconOnly;view.unlockOnly=unlockOnly;view.wheel=wheel;view.onTap=onTap;view.needsDisplay=true
        view.setAccessibilityLabel(lock.isLocked ? "Hold to Unlock Controls":"Lock Controls")
        view.setAccessibilityValue(lock.isLocked ? "Locked":"Unlocked")
        view.setAccessibilityHelp(lock.isLocked ? "Hold for 1.5 seconds to unlock. Release early to cancel.":"Click to lock controls. Music continues.")
    }
    static func dismantleNSView(_ view:Control,coordinator:()){view.cancel()}
}
