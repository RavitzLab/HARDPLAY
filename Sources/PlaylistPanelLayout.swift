import AppKit

enum PlaylistPanelLayout {
    // Header, count, fixed bottom controls and enough room for a short scrolling queue.
    static func minimumContentHeight(hints:Bool)->CGFloat {400+(hints ? HintMetrics.totalHeight:0)}
    static func fittedFrame(current:NSRect,visible:NSRect,minimum:NSSize)->NSRect {
        let width=min(visible.width,max(current.width,minimum.width))
        let height=min(visible.height,max(current.height,minimum.height))
        let top=min(visible.maxY,max(visible.minY+height,current.maxY))
        return NSRect(x:min(max(current.minX,visible.minX),visible.maxX-width),y:top-height,width:width,height:height)
    }
}
