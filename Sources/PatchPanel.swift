import AppKit
import SwiftUI

/// This edge owns the press so a long hold never becomes a waveform seek or window drag.
struct PatchHoldEdge:NSViewRepresentable {
    var opened:()->Void
    final class EdgeView:NSView {
        var opened:(()->Void)?
        private var timer:Timer?
        private var started:TimeInterval?
        private var progress:Double=0
        override var mouseDownCanMoveWindow:Bool {false}
        override func draw(_ dirtyRect:NSRect) {
            guard progress>0 else {return}
            NSColor(calibratedRed:0.65,green:0.83,blue:1,alpha:0.8).setFill()
            NSBezierPath(roundedRect:NSRect(x:bounds.midX-2,y:bounds.minY,width:4,height:bounds.height*progress),xRadius:2,yRadius:2).fill()
        }
        override func mouseDown(with event:NSEvent) {
            cancel();started=ProcessInfo.processInfo.systemUptime;progress=0.01;needsDisplay=true
            let ticker=Timer(timeInterval:0.02,repeats:true) {[weak self] _ in
                guard let self,let start=self.started else {return}
                self.progress=min(1,(ProcessInfo.processInfo.systemUptime-start)/2);self.needsDisplay=true
                if self.progress>=1 {self.cancel();self.opened?()}
            };timer=ticker;RunLoop.main.add(ticker,forMode:.common)
        }
        override func mouseDragged(with event:NSEvent) {if !bounds.insetBy(dx:-4,dy:-4).contains(convert(event.locationInWindow,from:nil)) {cancel()}}
        override func mouseUp(with event:NSEvent) {cancel()}
        override func viewDidMoveToWindow() {super.viewDidMoveToWindow();if window==nil {cancel()}}
        override func accessibilityPerformPress()->Bool {opened?();return true}
        func cancel() {timer?.invalidate();timer=nil;started=nil;progress=0;needsDisplay=true}
    }
    func makeNSView(context:Context)->EdgeView {
        let view=EdgeView();view.opened=opened;view.setAccessibilityElement(true);view.setAccessibilityRole(.button)
        view.setAccessibilityLabel("Hold Right Edge for PATCH");view.setAccessibilityHelp("Hold this strip for two seconds to open the rear panel. Release early to cancel.");return view
    }
    func updateNSView(_ view:EdgeView,context:Context) {view.opened=opened}
    static func dismantleNSView(_ view:EdgeView,coordinator:()) {view.cancel()}
}
