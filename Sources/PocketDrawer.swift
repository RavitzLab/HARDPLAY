import AppKit
import SwiftUI

final class PocketDrawerState:ObservableObject {
    static let shared=PocketDrawerState()
    @Published var open=false
}
enum PocketDrawerLayout {
    static let width:CGFloat=140
    static let height:CGFloat=270
    static func frame(owner:NSRect,visible:NSRect,faceInset:CGFloat=158)->NSRect {
        let width=min(self.width,visible.width),height=min(self.height,visible.height)
        return NSRect(x:min(max(owner.minX+faceInset-width-8,visible.minX),visible.maxX-width),
                      y:min(max(owner.maxY-38-height,visible.minY),visible.maxY-height),width:width,height:height)
    }
}
struct PocketLocksPanel:View {
    @ObservedObject private var sizes=WindowSizes.shared
    @ObservedObject private var setup=SetupLock.shared
    @ObservedObject private var lock=ControlLock.shared
    @ObservedObject private var placement=FloatingPlacement.shared
    @ObservedObject private var appearance=AppearancePreferences.shared
    var body:some View {
        VStack(alignment:.leading,spacing:7) {
            HStack {
                Text("NANO").font(.system(size:9,weight:.semibold)).tracking(1)
                Spacer()
                Button {AppDelegate.shared.hidePocketDrawer()} label:{Image(systemName:"chevron.right").frame(width:18,height:18)}
                    .buttonStyle(.plain).accessibilityLabel("Hide Widget Lock Panel")
            }
            Button {placement.pocketLocked.toggle()} label:{
                Label(placement.pocketLocked ? "Pinned":"Pin position",systemImage:placement.pocketLocked ? "pin.fill":"pin")
                    .font(.stage(size:10)).frame(maxWidth:.infinity,alignment:.leading).padding(6)
            }.buttonStyle(PlayerControlStyle(active:placement.pocketLocked)).accessibilityLabel(placement.pocketLocked ? "Unlock Widget Position":"Lock Widget Position")
            HStack(spacing:6) {HintToggleButton(small:true);ControlsLockButton(compact:true).frame(height:30).disabled(lock.isLocked)}
            Text("Hold ↓ 1.5s to unlock").font(.stage(size:9)).stageSecondary()
            Divider().overlay(Color(stageHex:appearance.theme.text).opacity(0.12))
            Text("WINDOW SIZE").font(.system(size:8,weight:.semibold)).tracking(0.6).stageSecondary()
            ForEach(WindowSizeChoice.allCases) {choice in
                Button {sizes.set(choice,for:.nano);AppDelegate.shared.positionPocketDrawer()} label:{
                    HStack {Text(choice.rawValue);Spacer();if sizes.choice(.nano)==choice {Image(systemName:"checkmark")}}
                        .font(.system(size:10,weight:.medium)).padding(.horizontal,7).frame(height:24)
                }.buttonStyle(PlayerControlStyle(active:sizes.choice(.nano)==choice))
                    .accessibilityLabel("Nano Size · "+choice.rawValue)
                    .accessibilityValue(sizes.choice(.nano)==choice ? "Selected":"")
                    .disabled(lock.isLocked || setup.settingsBlocked)
            }
        }.padding(10).frame(maxWidth:.infinity,maxHeight:.infinity)
            .foregroundStyle(Color(stageHex:appearance.theme.text))
            .background(appearance.theme.paint(.panel),in:RoundedRectangle(cornerRadius:12))
            .overlay(RoundedRectangle(cornerRadius:12).stroke(Color(stageHex:appearance.theme.text).opacity(0.16),lineWidth:1))
            .padding(3)
    }
}

/// Separate from the global toolbar: Nano controls have their own saved assignments.
final class NanoControlsState:ObservableObject {
    static let shared=NanoControlsState()
    @Published var open=false
    let actions=QuickActions(key:"nanoQuickActionButtons")
}
struct NanoControlsPanel:View {
    @ObservedObject private var state=NanoControlsState.shared
    @ObservedObject private var actions=NanoControlsState.shared.actions
    @ObservedObject private var appearance=AppearancePreferences.shared
    @ObservedObject private var lock=ControlLock.shared
    @ObservedObject private var setup=SetupLock.shared
    @ObservedObject private var mappings=ControlMappings.shared
    var body:some View {
        VStack(alignment:.leading,spacing:8) {
            HStack {Text("CONTROLS").font(.system(size:9,weight:.bold,design:.monospaced));Spacer();Button {AppDelegate.shared.hideNanoControls()} label:{Image(systemName:"chevron.left")}.buttonStyle(.plain).accessibilityLabel("Hide Player Controls")}
            ForEach(actions.buttons) {button in
                HStack(spacing:4) {
                    Button {mappings.trigger(button.action,behavior:button.behavior)} label:{Text(button.action.title).font(.stage(size:11)).lineLimit(2).frame(maxWidth:.infinity,alignment:.leading).padding(7)}.buttonStyle(PlayerControlStyle(active:mappings.isOn(button.action) ?? false)).disabled(lock.isLocked)
                    Menu {NanoActionMenu(button:button)} label:{Image(systemName:"ellipsis").frame(width:20,height:24)}.menuStyle(.borderlessButton).stageMenuInk().disabled(lock.isLocked || setup.settingsBlocked)
                }
            }
            Menu {ActionChoices {actions.add($0)}} label:{Label("Add Control",systemImage:"plus").font(.stage(size:11))}.disabled(actions.buttons.count>=4 || lock.isLocked || setup.settingsBlocked)
            if actions.buttons.isEmpty {Text("Choose up to four controls. Assign Trigger or Toggle in ⋯.").font(.stage(size:10)).stageSecondary()}
        }.padding(12).foregroundStyle(Color(stageHex:appearance.theme.text)).frame(width:200)
            .background(appearance.theme.paint(.panel),in:RoundedRectangle(cornerRadius:12))
            .overlay(RoundedRectangle(cornerRadius:12).stroke(Color(stageHex:appearance.theme.text).opacity(0.18))).padding(3).stageColorScheme()
    }
}
struct NanoActionMenu:View {
    let button:QuickActionButton
    @ObservedObject private var actions=NanoControlsState.shared.actions
    var body:some View {
        Menu("Assign action") {ActionChoices {actions.assign($0,to:button.id)}}
        if button.action.supportsToggle {ForEach(ButtonBehavior.allCases,id:\.self) {mode in Button((mode==button.behavior ? "✓ ":"")+mode.rawValue) {actions.behavior(mode,id:button.id)}}}
        Button("Remove Control",role:.destructive) {actions.remove(button.id)}
    }
}

/// Uses the actual hosting window, so Main, Mini and DJ never attach to Nano by mistake.
struct PlayerControlsEdge:NSViewRepresentable {
    final class Edge:NSView {
        override var mouseDownCanMoveWindow:Bool {false}
        override func acceptsFirstMouse(for event:NSEvent?)->Bool {true}
        override func mouseUp(with event:NSEvent) {if bounds.contains(convert(event.locationInWindow,from:nil)),let window {AppDelegate.shared.toggleNanoControls(from:window)}}
        override func accessibilityPerformPress()->Bool {guard let window else {return false};AppDelegate.shared.toggleNanoControls(from:window);return true}
    }
    func makeNSView(context:Context)->Edge {let view=Edge();view.setAccessibilityElement(true);view.setAccessibilityRole(.button);view.setAccessibilityLabel("Toggle Player Controls Panel");view.setAccessibilityHelp("Tap the right edge to show or hide your shared custom controls");return view}
    func updateNSView(_ view:Edge,context:Context) {}
}
