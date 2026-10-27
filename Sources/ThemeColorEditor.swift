import SwiftUI

enum ThemeColorSlot:String,CaseIterable,Identifiable {
    case accent,background,text,tape,panel,surface,waveform,grid,secondary
    var id:String {rawValue}
    var title:String {switch self {case .accent:return "Accent";case .background:return "Background";case .text:return "Text";case .tape:return "Playlist tape";case .panel:return "Panels";case .surface:return "Control surfaces";case .waveform:return "Waveform";case .grid:return "Grid / borders";case .secondary:return "Secondary text"}}
    var supportsGradient:Bool {[.background,.tape,.panel,.surface].contains(self)}
    static func normalized(_ input:String)->String? {let value=input.trimmingCharacters(in:.whitespacesAndNewlines).replacingOccurrences(of:"#",with:"").uppercased();return value.count==6 && value.allSatisfy {"0123456789ABCDEF".contains($0)} ? value:nil}
    static func rgb(_ hex:String)->[Double] {let n=UInt64(hex,radix:16) ?? 0;return [Double((n>>16)&255),Double((n>>8)&255),Double(n&255)]}
}
struct ThemeFillGradient:Codable,Equatable {var end:String;var angle:Double=90}
extension StageTheme {
    func hex(_ slot:ThemeColorSlot)->String {switch slot {case .accent:return accent;case .background:return background;case .text:return text;case .tape:return tape;case .panel:return panelColor;case .surface:return surfaceColor;case .waveform:return waveColor;case .grid:return gridColor;case .secondary:return secondaryColor}}
    mutating func setHex(_ value:String,for slot:ThemeColorSlot) {
        guard let value=ThemeColorSlot.normalized(value) else {return}
        switch slot {case .accent:accent=value;case .background:background=value;case .text:text=value;case .tape:tape=value;case .panel:panel=value;case .surface:raisedSurface=value;case .waveform:waveform=value;case .grid:grid=value;case .secondary:secondaryText=value}
    }
    func paint(_ slot:ThemeColorSlot)->AnyShapeStyle {
        if slot.supportsGradient,let g=gradients?[slot.rawValue] {
            let a=g.angle * .pi / 180,x=cos(a)*0.5,y=sin(a)*0.5
            return AnyShapeStyle(LinearGradient(colors:[Color(stageHex:hex(slot)),Color(stageHex:g.end)],startPoint:UnitPoint(x:0.5-x,y:0.5-y),endPoint:UnitPoint(x:0.5+x,y:0.5+y)))
        }
        return AnyShapeStyle(Color(stageHex:hex(slot)))
    }
}
extension AppearancePreferences {
    func setColor(_ value:String,for slot:ThemeColorSlot){theme.setHex(value,for:slot)}
    func setGradient(_ enabled:Bool,for slot:ThemeColorSlot) {
        guard slot.supportsGradient else {return}
        var values=theme.gradients ?? [:]
        if enabled {
            if values[slot.rawValue]==nil {let rgb=ThemeColorSlot.rgb(theme.hex(slot)).map {Int(min(255,$0*1.15+20))};values[slot.rawValue]=ThemeFillGradient(end:String(format:"%02X%02X%02X",rgb[0],rgb[1],rgb[2]))}
        }else {values.removeValue(forKey:slot.rawValue)}
        theme.gradients=values.isEmpty ? nil:values
    }
}
final class ThemeColorEditorState:ObservableObject {@Published var open=false;@Published var second=false;@Published var hexDraft=""}
struct ThemeColorButton:View {
    let slot:ThemeColorSlot
    @ObservedObject private var appearance=AppearancePreferences.shared
    @StateObject private var state=ThemeColorEditorState()
    var body:some View {
        HStack {
            Text(slot.title);Spacer()
            Button {state.open.toggle()} label:{
                HStack(spacing:7) {RoundedRectangle(cornerRadius:5).fill(appearance.theme.paint(slot)).overlay(RoundedRectangle(cornerRadius:5).stroke(.primary.opacity(0.25),lineWidth:0.6)).frame(width:48,height:24);Image(systemName:"slider.horizontal.3").font(.system(size:11))}.padding(4)
            }.buttonStyle(PlayerControlStyle(active:state.open)).accessibilityLabel("Edit "+slot.title+" Color").stageHint("Edit "+slot.title+" beside this control")
                .popover(isPresented:$state.open,arrowEdge:.trailing) {ThemeColorPopover(slot:slot,state:state)}
        }
    }
}
private struct ThemeColorPopover:View {
    let slot:ThemeColorSlot
    @ObservedObject var state:ThemeColorEditorState
    @ObservedObject private var appearance=AppearancePreferences.shared
    private var gradient:ThemeFillGradient? {appearance.theme.gradients?[slot.rawValue]}
    private var hex:String {state.second ? (gradient?.end ?? appearance.theme.hex(slot)):appearance.theme.hex(slot)}
    private func update(_ input:String) {
        guard let value=ThemeColorSlot.normalized(input) else {return}
        if state.second,var g=gradient {g.end=value;var values=appearance.theme.gradients ?? [:];values[slot.rawValue]=g;appearance.theme.gradients=values}
        else {appearance.setColor(value,for:slot)}
    }
    private func channel(_ index:Int)->Binding<Double> {Binding(get:{ThemeColorSlot.rgb(hex)[index]},set:{v in var rgb=ThemeColorSlot.rgb(hex).map {Int($0)};rgb[index]=Int(v.rounded());update(String(format:"%02X%02X%02X",rgb[0],rgb[1],rgb[2]))})}
    var body:some View {
        VStack(alignment:.leading,spacing:12) {
            HStack {Text(slot.title).font(.system(size:14,weight:.semibold));Spacer();Button {state.open=false} label:{Image(systemName:"xmark")}.buttonStyle(.plain).accessibilityLabel("Close Color Editor")}
            if slot.supportsGradient {
                Picker("Fill",selection:Binding(get:{gradient != nil},set:{appearance.setGradient($0,for:slot);state.second=false})) {Text("Solid").tag(false);Text("Gradient").tag(true)}.pickerStyle(.segmented).accessibilityLabel(slot.title+" Fill Mode")
            }
            RoundedRectangle(cornerRadius:8).fill(appearance.theme.paint(slot)).frame(height:44).overlay(RoundedRectangle(cornerRadius:8).stroke(.primary.opacity(0.2),lineWidth:0.6))
            if gradient != nil {Picker("Color stop",selection:$state.second) {Text("First color").tag(false);Text("Second color").tag(true)}.pickerStyle(.segmented).accessibilityLabel("Gradient Color Stop")}
            ForEach(0..<3,id:\.self) {index in
                HStack {Text(["R","G","B"][index]).font(.system(size:12,weight:.medium,design:.monospaced));Slider(value:channel(index),in:0...255,step:1).accessibilityLabel(slot.title+" "+["Red","Green","Blue"][index]);Text(String(Int(ThemeColorSlot.rgb(hex)[index]))).monospacedDigit().frame(width:28,alignment:.trailing)}
            }
            HStack {Text("HEX");TextField("RRGGBB",text:$state.hexDraft).textFieldStyle(.roundedBorder).onSubmit {update(state.hexDraft)}.accessibilityLabel(slot.title+" Hex Color");Button("Apply") {update(state.hexDraft)}.disabled(ThemeColorSlot.normalized(state.hexDraft)==nil)}
            if let g=gradient {
                HStack {Text("Angle");Slider(value:Binding(get:{g.angle},set:{v in var values=appearance.theme.gradients ?? [:];values[slot.rawValue]?.angle=v;appearance.theme.gradients=values}),in:0...360,step:1).accessibilityLabel("Gradient Angle");Text("\(Int(g.angle))°").monospacedDigit().frame(width:38)}
            }
            Text("Live preview · save in My Themes to keep a named copy.").font(.system(size:10)).foregroundStyle(.secondary)
        }.font(.system(size:12)).foregroundStyle(.primary).padding(14).frame(width:280)
            .background(Color(nsColor:.windowBackgroundColor)).onAppear {state.hexDraft=hex}.onChange(of:hex) {_,v in state.hexDraft=v}
    }
}
struct ThemeSecondaryStyle:ViewModifier {
    @ObservedObject private var appearance=AppearancePreferences.shared
    func body(content:Content)->some View {content.foregroundStyle(Color(stageHex:appearance.theme.secondaryColor).opacity(appearance.theme.secondaryText == nil ? 0.65:1))}
}
extension View {func stageSecondary()->some View {modifier(ThemeSecondaryStyle())}}
struct PlaylistNameSurface:View {
    @ObservedObject private var appearance=AppearancePreferences.shared
    var body:some View {if appearance.theme.isConcept {RoundedRectangle(cornerRadius:4).fill(appearance.theme.paint(.tape))}else {TapeSurface()}}
}
