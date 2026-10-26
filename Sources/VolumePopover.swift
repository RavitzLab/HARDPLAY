import SwiftUI
import AppKit

final class VolumePopoverState:ObservableObject {@Published var open=false}
struct PlayerVolumeButton:View {
    @ObservedObject var player:Player
    var compact=false
    @ObservedObject private var setup=SetupLock.shared
    @ObservedObject private var lock=ControlLock.shared
    @StateObject private var panel=VolumePopoverState()
    var body:some View {
        Button {panel.open.toggle()} label:{MarkerIcon(systemName:player.volume == 0 ? "speaker.slash":"speaker.wave.2",size:19).frame(width:compact ? 28:36,height:compact ? 32:38)}
            .buttonStyle(PlayerControlStyle(active:panel.open)).accessibilityLabel("Volume")
            .accessibilityValue("\(Int(player.volume*100)) percent").stageHint("Open vertical volume control")
            .background(AttachedControlPanelAnchor(open:$panel.open,content:AnyView(VolumePanelContent(player:player)),size:NSSize(width:86,height:230),rightSide:false))
            .disabled(setup.playbackBlocked || lock.isLocked).mapAction("volume")
            .onChange(of:lock.isLocked) {_,locked in if locked {panel.open=false}}
    }
}
private struct VolumePanelContent:View {
    @ObservedObject var player:Player
    @ObservedObject private var appearance=AppearancePreferences.shared
    var body:some View {
        VStack(spacing:10) {
            Text("VOLUME").font(.stage(size:10))
            NativeVerticalVolume(value:Binding(get:{player.volume},set:{player.volume=$0}),enabled:!SetupLock.shared.playbackBlocked && !ControlLock.shared.isLocked).frame(width:26,height:150)
            Text("\(Int(player.volume*100))%").font(.system(size:12,weight:.semibold,design:.monospaced))
        }.padding(14).frame(width:86,height:230)
            .foregroundStyle(Color(stageHex:appearance.theme.text))
            .background(LinearGradient(colors:[Color(stageHex:appearance.theme.background),Color(stageHex:appearance.theme.background).opacity(0.94)],startPoint:.top,endPoint:.bottom),in:RoundedRectangle(cornerRadius:12))
            .overlay(RoundedRectangle(cornerRadius:12).stroke(accent.opacity(0.4),lineWidth:1))
            .preferredColorScheme(appearance.theme.isLight ? .light:.dark)
    }
}
struct AttachedControlPanelAnchor:NSViewRepresentable {
    @Binding var open:Bool
    let content:AnyView
    let size:NSSize
    var rightSide=false
    final class Anchor:NSView {
        var wantsOpen=false,onClose:(()->Void)?
        var content:AnyView?
        var size=NSSize(width:86,height:230),rightSide=false
        private var panel:NSPanel?,monitor:Any?,observers:[NSObjectProtocol]=[]
        override func viewDidMoveToWindow(){super.viewDidMoveToWindow();sync()}
        func position() {
            guard let owner=window,let panel,let visible=owner.screen?.visibleFrame else {return}
            let rect=owner.convertToScreen(convert(bounds,to:nil))
            panel.setFrameOrigin(NSPoint(x:rightSide ? max(visible.minX,min(visible.maxX-size.width,owner.frame.maxX+8)):max(visible.minX,owner.frame.minX-size.width-8),y:min(max(visible.minY,rect.midY-size.height/2),visible.maxY-size.height)))
        }
        func sync() {
            guard wantsOpen,let owner=window,let content else {hide();return}
            if panel == nil {
                let window=FloatingPanel(contentRect:NSRect(origin:.zero,size:size),styleMask:[.borderless,.nonactivatingPanel],backing:.buffered,defer:false)
                window.isOpaque=false;window.backgroundColor = .clear;window.hasShadow=true;window.hidesOnDeactivate=true
                window.contentView=NSHostingView(rootView:content);window.level=owner.level
                panel=window;owner.addChildWindow(window,ordered:.above)
                for name in [NSWindow.didMoveNotification,NSWindow.didResizeNotification] {
                    observers.append(NotificationCenter.default.addObserver(forName:name,object:owner,queue:.main) {[weak self] _ in self?.position()})
                }
                for name in [NSWindow.willCloseNotification,NSWindow.didMiniaturizeNotification] {
                    observers.append(NotificationCenter.default.addObserver(forName:name,object:owner,queue:.main) {[weak self] _ in self?.dismiss()})
                }
                observers.append(NotificationCenter.default.addObserver(forName:NSApplication.didResignActiveNotification,object:nil,queue:.main) {[weak self] _ in self?.dismiss()})
                monitor=NSEvent.addLocalMonitorForEvents(matching:[.leftMouseDown,.rightMouseDown]) {[weak self] event in
                    guard let self else {return event}
                    if event.window !== self.panel {
                        if event.window === self.window,self.bounds.contains(self.convert(event.locationInWindow,from:nil)) {return event}
                        self.dismiss()
                    }
                    return event
                }
            }
            position();if rightSide {panel?.makeKeyAndOrderFront(nil)}else {panel?.orderFront(nil)}
        }
        func dismiss(){wantsOpen=false;hide();onClose?()}
        func hide(){if let panel {panel.parent?.removeChildWindow(panel);panel.orderOut(nil)};panel=nil;if let monitor {NSEvent.removeMonitor(monitor)};monitor=nil;observers.forEach {NotificationCenter.default.removeObserver($0)};observers=[]}
        deinit {hide()}
    }
    func makeNSView(context:Context)->Anchor {Anchor()}
    func updateNSView(_ view:Anchor,context:Context){view.content=content;view.size=size;view.rightSide=rightSide;view.wantsOpen=open;view.onClose={DispatchQueue.main.async {self.open=false}};view.sync()}
    static func dismantleNSView(_ view:Anchor,coordinator:()){view.hide()}
}
struct NativeVerticalVolume:NSViewRepresentable {
    @Binding var value:Double
    let enabled:Bool
    final class Coordinator:NSObject {
        var owner:NativeVerticalVolume
        init(_ owner:NativeVerticalVolume){self.owner=owner}
        @objc func change(_ sender:NSSlider) {guard owner.enabled,!ControlLock.shared.isLocked,!SetupLock.shared.playbackBlocked else {return};owner.value=min(1,max(0,sender.doubleValue))}
    }
    func makeCoordinator()->Coordinator {Coordinator(self)}
    func makeNSView(context:Context)->NSSlider {
        let slider=NSSlider(frame:NSRect(x:0,y:0,width:26,height:150))
        slider.minValue=0;slider.maxValue=1;slider.isContinuous=true
        slider.target=context.coordinator;slider.action=#selector(Coordinator.change(_:))
        slider.setAccessibilityLabel("Master Volume");return slider
    }
    func updateNSView(_ slider:NSSlider,context:Context){context.coordinator.owner=self;slider.doubleValue=value;slider.isEnabled=enabled}
}
