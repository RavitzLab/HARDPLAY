import AppKit
import SwiftUI

enum PlaybackPanelLayout {
    static let width:CGFloat=244
    static func ownerFrame(_ original:NSRect,visible:NSRect)->NSRect {
        guard original.width+width+8<=visible.width else {return original}
        var result=original
        result.origin.x=min(max(original.minX,visible.minX+width+8),visible.maxX-original.width)
        return result
    }
    static func panelFrame(owner:NSRect,visible:NSRect)->NSRect {
        let w=min(width,visible.width),h=min(462,visible.height)
        return NSRect(x:min(max(owner.minX-w-8,visible.minX),visible.maxX-w),
                      y:min(max(owner.maxY-100-h,visible.minY),visible.maxY-h),width:w,height:h)
    }
}
final class PlaybackPanelController {
    private var panel:NSPanel?
    private weak var owner:NSWindow?
    private var returnFrame:(original:NSRect,placed:NSRect)?
    private var positioning=false
    private var revision=0
    func toggle(fromMini:Bool) {
        guard !ControlLock.shared.isLocked,let app=AppDelegate.shared else {return}
        let target:NSWindow? = fromMini ? (app.popover.isShown ? app.popover.contentViewController?.view.window:app.miniWindow):app.mainWindow
        guard let target else {return}
        if PlaybackDrawerState.shared.open,owner === target {hide();return}
        hide(animated:false)
        if panel == nil {
            let window=FloatingPanel(contentRect:NSRect(x:0,y:0,width:244,height:462),styleMask:[.borderless,.nonactivatingPanel],backing:.buffered,defer:false)
            window.title="Hard Play Playback";window.isOpaque=false;window.backgroundColor = .clear
            window.level = .floating;window.hasShadow=true;window.hidesOnDeactivate=false
            window.isReleasedWhenClosed=false;window.collectionBehavior=[.canJoinAllSpaces,.fullScreenAuxiliary]
            window.contentView=NSHostingView(rootView:PlaybackModesDrawer(player:Player.shared,open:Binding(get:{PlaybackDrawerState.shared.open},set:{[weak self] value in if !value {self?.hide()}})).padding(3).fixedControlHints())
            panel=window
        }
        guard let panel else {return}
        owner=target;revision+=1;PlaybackDrawerState.shared.open=true
        position()
        let frame=panel.frame
        panel.setFrame(frame.offsetBy(dx:20,dy:0),display:false);panel.alphaValue=0
        target.addChildWindow(panel,ordered:.above);panel.makeKeyAndOrderFront(nil)
        NSAnimationContext.runAnimationGroup {context in
            context.duration=0.18;panel.animator().setFrame(frame,display:true);panel.animator().alphaValue=1
        }
    }
    func position() {
        guard !positioning,PlaybackDrawerState.shared.open,let owner,let panel,
              let visible=owner.screen?.visibleFrame ?? NSScreen.main?.visibleFrame else {return}
        positioning=true;defer {positioning=false}
        let original=owner.frame
        let placed=PlaybackPanelLayout.ownerFrame(original,visible:visible)
        if placed != original {returnFrame=(original,placed);owner.setFrame(placed,display:true)}
        panel.setFrame(PlaybackPanelLayout.panelFrame(owner:owner.frame,visible:visible),display:true)
    }
    func hide(animated:Bool=true) {
        guard PlaybackDrawerState.shared.open else {return}
        PlaybackDrawerState.shared.open=false;revision+=1
        let current=revision
        guard let panel else {return}
        let finish={ [weak self,weak panel] in
            guard let self,let panel,self.revision==current else {return}
            panel.orderOut(nil);panel.parent?.removeChildWindow(panel);panel.alphaValue=1
            if let saved=self.returnFrame,let owner=self.owner,owner.frame==saved.placed {owner.setFrame(saved.original,display:true)}
            self.returnFrame=nil;self.owner=nil
        }
        if animated {
            NSAnimationContext.runAnimationGroup({context in
                context.duration=0.16;panel.animator().alphaValue=0
                panel.animator().setFrame(panel.frame.offsetBy(dx:20,dy:0),display:true)
            },completionHandler:finish)
        }else {finish()}
    }
}
