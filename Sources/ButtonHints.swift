import SwiftUI
import AppKit

final class HintPreferences:ObservableObject {
    static let shared=HintPreferences()
    @Published var enabled:Bool {didSet {UserDefaults.standard.set(enabled,forKey:"showButtonHints")}}
    init() {
        let defaults=UserDefaults.standard
        enabled=defaults.object(forKey:"showButtonHints") as? Bool ?? true
        if !defaults.bool(forKey:"anchoredHints.v1") {
            enabled=true;defaults.set(true,forKey:"showButtonHints");defaults.set(true,forKey:"anchoredHints.v1")
        }
    }
}
private final class HoverHintState:ObservableObject {let id=UUID();@Published var active=false}
private final class HintChannel:ObservableObject {
    @Published var owner:UUID?
    var text=""
    func show(_ text:String,id:UUID) {self.text=text;owner=id}
    func hide(_ id:UUID) {if owner==id {owner=nil}}
}
private struct HintChannelKey:EnvironmentKey {static let defaultValue:HintChannel?=nil}
private extension EnvironmentValues {
    var hintChannel:HintChannel? {get {self[HintChannelKey.self]}set {self[HintChannelKey.self]=newValue}}
}
private struct HintAnchors:PreferenceKey {
    static var defaultValue:[UUID:Anchor<CGRect>]=[:]
    static func reduce(value:inout [UUID:Anchor<CGRect>],nextValue:()->[UUID:Anchor<CGRect>]) {value.merge(nextValue(),uniquingKeysWith:{$1})}
}
struct StageHint:ViewModifier {
    @ObservedObject private var preferences=HintPreferences.shared
    @ObservedObject private var lock=ControlLock.shared
    @StateObject private var hover=HoverHintState()
    @Environment(\.hintChannel) private var channel
    var text:String
    func body(content:Content)->some View {
        content.anchorPreference(key:HintAnchors.self,value:.bounds) {hover.active ? [hover.id:$0]:[:]}
            .onHover {inside in
                hover.active=inside
                if inside && preferences.enabled && !lock.isLocked {channel?.show(text,id:hover.id)}else {channel?.hide(hover.id)}
            }
            .onChange(of:text) {_,value in if hover.active && preferences.enabled && !lock.isLocked {channel?.show(value,id:hover.id)}}
            .onDisappear {channel?.hide(hover.id)}
            .help(channel == nil && preferences.enabled ? text:"")
    }
}
private struct HintScope:ViewModifier {
    @StateObject private var channel=HintChannel()
    @ObservedObject private var preferences=HintPreferences.shared
    @ObservedObject private var lock=ControlLock.shared
    @ObservedObject private var appearance=AppearancePreferences.shared
    func body(content:Content)->some View {
        content.environment(\.hintChannel,channel)
            .overlayPreferenceValue(HintAnchors.self) {anchors in
                GeometryReader {proxy in
                    if preferences.enabled,!lock.isLocked,let id=channel.owner,let anchor=anchors[id] {
                        let rect=proxy[anchor]
                        let measured=(channel.text as NSString).size(withAttributes:[.font:NSFont.systemFont(ofSize:11,weight:.medium)]).width+18
                        let width=min(max(40,proxy.size.width-12),min(220,max(72,measured)))
                        let height:CGFloat=measured>width ? 40:28
                        Text(channel.text).font(.system(size:11,weight:.medium)).lineLimit(2)
                            .multilineTextAlignment(.center).padding(.horizontal,8)
                            .frame(width:width,height:height)
                            .foregroundStyle(Color(stageHex:appearance.theme.text))
                            .background(.regularMaterial,in:RoundedRectangle(cornerRadius:8))
                            .overlay(RoundedRectangle(cornerRadius:8).stroke(accent.opacity(0.3),lineWidth:1))
                            .shadow(color:.black.opacity(0.18),radius:4,y:2)
                            .position(x:min(max(rect.midX,width/2+6),max(width/2+6,proxy.size.width-width/2-6)),y:rect.minY>=height+8 ? rect.minY-height/2-6:rect.maxY+height/2+6)
                            .accessibilityLabel("Control hint").accessibilityValue(channel.text)
                    }
                }.allowsHitTesting(false)
            }
            .onChange(of:preferences.enabled) {_,_ in channel.owner=nil}
            .onChange(of:lock.isLocked) {_,_ in channel.owner=nil}
            .onReceive(NotificationCenter.default.publisher(for:NSApplication.didResignActiveNotification)) {_ in channel.owner=nil}
    }
}
enum HintMetrics {static let height:CGFloat=0;static let totalHeight:CGFloat=0}
extension View {
    func stageHint(_ text:String,below:Bool=false)->some View {modifier(StageHint(text:text))}
    @ViewBuilder func fixedControlHints(enabled:Bool=true)->some View {
        if enabled {modifier(HintScope())}else {self}
    }
}
