import AppKit
import SwiftUI

final class NanoPlaylistState:ObservableObject {
    static let shared=NanoPlaylistState()
    @Published var open=false
}
final class NanoPlaylistController {
    private var panel:NSPanel?
    func toggle() {
        if NanoPlaylistState.shared.open {hide();return}
        guard !ControlLock.shared.isLocked,let owner=AppDelegate.shared?.pocketWindow,owner.isVisible else {return}
        if panel == nil {
            let window=FloatingPanel(contentRect:NSRect(x:0,y:0,width:360,height:406),styleMask:[.borderless,.nonactivatingPanel],backing:.buffered,defer:false)
            window.title="Hard Play Nano Playlist";window.isOpaque=false;window.backgroundColor = .clear
            window.level = .floating;window.hasShadow=true;window.hidesOnDeactivate=false;window.isReleasedWhenClosed=false
            window.collectionBehavior=[.canJoinAllSpaces,.fullScreenAuxiliary]
            let binding=Binding<Bool>(get:{NanoPlaylistState.shared.open},set:{[weak self] value in if !value {self?.hide()}})
            window.contentView=ProfileHostingView(rootView:NanoPlaylist(open:binding).padding(4).background(ThemedBackdrop()).clipShape(RoundedRectangle(cornerRadius:12)).fixedControlHints().windowSizeCanvas(.nanoPlaylist))
            panel=window
        }
        NanoPlaylistState.shared.open=true;position()
        guard let panel else {return}
        owner.addChildWindow(panel,ordered:.above);panel.makeKeyAndOrderFront(nil)
    }
    func position() {
        guard NanoPlaylistState.shared.open,let panel,let owner=AppDelegate.shared?.pocketWindow,
              let screen=owner.screen?.visibleFrame ?? NSScreen.main?.visibleFrame else {return}
        let base=WindowSizes.shared.base(.nanoPlaylist),scale=WindowSizes.shared.scale(.nanoPlaylist)
        let width=(base.width*scale).rounded(),height=(base.height*scale).rounded()
        let right=owner.frame.maxX+8
        let preferred=right+width<=screen.maxX ? right:owner.frame.minX+158*WindowSizes.shared.scale(.nano)-width-8
        panel.setFrame(NSRect(x:min(max(preferred,screen.minX),screen.maxX-width),y:min(max(owner.frame.minY+12,screen.minY),screen.maxY-height),width:width,height:height),display:true)
    }
    func hide() {
        NanoPlaylistState.shared.open=false
        if let panel {panel.orderOut(nil);panel.parent?.removeChildWindow(panel)}
    }
}
