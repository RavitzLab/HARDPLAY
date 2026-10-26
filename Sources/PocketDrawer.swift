import AppKit
import SwiftUI

final class PocketDrawerState:ObservableObject {
    static let shared=PocketDrawerState()
    @Published var open=false
}
enum PocketDrawerLayout {
    static let width:CGFloat=140
    static let height:CGFloat=148
    static func frame(owner:NSRect,visible:NSRect)->NSRect {
        let width=min(self.width,visible.width),height=min(self.height,visible.height)
        return NSRect(x:min(max(owner.minX+158-width-8,visible.minX),visible.maxX-width),
                      y:min(max(owner.maxY-38-height,visible.minY),visible.maxY-height),width:width,height:height)
    }
}
struct PocketLocksPanel:View {
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
            Text("Hold ↓ 1.5s to unlock").font(.stage(size:9)).foregroundStyle(.secondary)
        }.padding(10).frame(maxWidth:.infinity,maxHeight:.infinity)
            .foregroundStyle(Color(stageHex:appearance.theme.text))
            .background(Color(stageHex:appearance.theme.isLight ? "FFFFFF":"121C2B"),in:RoundedRectangle(cornerRadius:12))
            .overlay(RoundedRectangle(cornerRadius:12).stroke(Color(stageHex:appearance.theme.text).opacity(0.16),lineWidth:1))
            .padding(3)
    }
}
