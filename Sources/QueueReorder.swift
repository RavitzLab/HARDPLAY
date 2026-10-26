import SwiftUI
import UniformTypeIdentifiers

/// Private, in-process payload: never confused with audio files dropped from Finder.
enum QueueDrag {
    static let type=UTType(exportedAs:"local.hardplay.queue-item",conformingTo:.data)
    static func provider(_ id:String)->NSItemProvider {
        let provider=NSItemProvider()
        provider.registerDataRepresentation(forTypeIdentifier:type.identifier,visibility:.ownProcess) {completion in completion(Data(id.utf8),nil);return nil}
        return provider
    }
}
struct QueueRowDrop:DropDelegate {
    let player:Player
    let target:String
    @Binding var targeted:Bool
    @Binding var after:Bool
    var midpoint:CGFloat=26
    func validateDrop(info:DropInfo)->Bool {!SetupLock.shared.editsBlocked && !ControlLock.shared.isLocked && info.hasItemsConforming(to:[QueueDrag.type.identifier])}
    func dropEntered(info:DropInfo) {targeted=validateDrop(info:info);after=info.location.y>midpoint}
    func dropUpdated(info:DropInfo)->DropProposal? {after=info.location.y>midpoint;return DropProposal(operation:validateDrop(info:info) ? .move:.forbidden)}
    func dropExited(info:DropInfo) {targeted=false}
    func performDrop(info:DropInfo)->Bool {
        targeted=false
        guard validateDrop(info:info),let provider=info.itemProviders(for:[QueueDrag.type.identifier]).first else {return false}
        let insertAfter=info.location.y>midpoint
        provider.loadDataRepresentation(forTypeIdentifier:QueueDrag.type.identifier) {data,_ in
            guard let data,data.count<=4096,let id=String(data:data,encoding:.utf8) else {return}
            DispatchQueue.main.async {_ = player.moveTrack(id,relativeTo:target,after:insertAfter)}
        };return true
    }
}

final class QueueDragPosition:ObservableObject {
    static let shared=QueueDragPosition()
    @Published var target:String?
    @Published var after=false
    func clear(){target=nil;after=false}
}
/// Direct native handle tracking avoids nested SwiftUI drop targets swallowing a move.
struct QueueDragHandle:NSViewRepresentable {
    let id:String
    let title:String
    var enabled:Bool
    final class Handle:NSView {
        private static let handles=NSHashTable<Handle>.weakObjects()
        var id="",title="",enabled=true
        private var down:NSPoint?
        private var moved=false
        override init(frame:NSRect){super.init(frame:frame);Self.handles.add(self)}
        required init?(coder:NSCoder){fatalError("init(coder:) unsupported")}
        override var mouseDownCanMoveWindow:Bool {false}
        override func acceptsFirstMouse(for event:NSEvent?)->Bool {true}
        override func draw(_ dirtyRect:NSRect) {
            NSColor.secondaryLabelColor.withAlphaComponent(enabled ? 0.85:0.3).setStroke()
            let path=NSBezierPath();path.lineWidth=1.6
            for y in [-4.0,0,4] {path.move(to:NSPoint(x:bounds.midX-5,y:bounds.midY+y));path.line(to:NSPoint(x:bounds.midX+5,y:bounds.midY+y))};path.stroke()
        }
        override func mouseDown(with event:NSEvent){guard enabled else {return};down=event.locationInWindow;moved=false;QueueDragPosition.shared.clear()}
        private func locate(_ event:NSEvent) {
            guard let window else {return}
            let point=window.convertPoint(toScreen:event.locationInWindow)
            for handle in Self.handles.allObjects where handle.window === window && !handle.visibleRect.isEmpty {
                var rect=window.convertToScreen(handle.convert(handle.bounds,to:nil))
                let middle=rect.midY;rect=rect.insetBy(dx:0,dy:-12)
                rect.size.width=max(rect.width,window.frame.maxX-rect.minX-16)
                if rect.contains(point) {
                    QueueDragPosition.shared.after=point.y<middle
                    QueueDragPosition.shared.target=handle.id
                    return
                }
            }
            QueueDragPosition.shared.clear()
        }
        override func mouseDragged(with event:NSEvent) {
            guard enabled,let down else {return}
            if hypot(event.locationInWindow.x-down.x,event.locationInWindow.y-down.y)>3 {moved=true}
            guard moved else {return}
            _ = enclosingScrollView?.autoscroll(with:event)
            locate(event)
        }
        override func mouseUp(with event:NSEvent) {
            defer {down=nil;moved=false;QueueDragPosition.shared.clear()}
            guard enabled,moved else {return};locate(event)
            if let target=QueueDragPosition.shared.target {_ = Player.shared.moveTrack(id,relativeTo:target,after:QueueDragPosition.shared.after)}
        }
        override func resetCursorRects(){if enabled {addCursorRect(bounds,cursor:.openHand)}}
    }
    func makeNSView(context:Context)->Handle {let view=Handle(frame:.zero);view.setAccessibilityElement(true);view.setAccessibilityRole(.image);return view}
    func updateNSView(_ view:Handle,context:Context){view.id=id;view.title=title;view.enabled=enabled;view.needsDisplay=true;view.setAccessibilityLabel("Reorder Track: "+title);view.window?.invalidateCursorRects(for:view)}
}
