import SwiftUI
import AppKit

/// Observe preferences at the hosting boundary: a captured preferred scheme can outlive the theme.
struct StageColorScheme:ViewModifier {
    @ObservedObject private var appearance=AppearancePreferences.shared
    func body(content:Content)->some View {
        let scheme:ColorScheme=appearance.theme.isLight ? .light:.dark
        content.environment(\.colorScheme,scheme).preferredColorScheme(scheme)
    }
}
struct StageMenuInk:ViewModifier {
    @ObservedObject private var appearance=AppearancePreferences.shared
    func body(content:Content)->some View {
        let ink=Color(stageHex:appearance.theme.text)
        content.foregroundColor(ink).tint(ink).stageColorScheme()
    }
}
extension View {
    func stageColorScheme()->some View {modifier(StageColorScheme())}
    func stageMenuInk()->some View {modifier(StageMenuInk())}
}
func themeContrast(_ a:String,_ b:String)->Double {
    func luminance(_ hex:String)->Double {
        let c=ThemeColorSlot.rgb(hex).map {v -> Double in let s=v/255;return s<=0.04045 ? s/12.92:pow((s+0.055)/1.055,2.4)}
        return c[0]*0.2126+c[1]*0.7152+c[2]*0.0722
    }
    let x=luminance(a),y=luminance(b);return (max(x,y)+0.05)/(min(x,y)+0.05)
}
func checkThemeControlContrast() {
    for name in StageTheme.names {
        let t=StageTheme.named(name)
        for background in [t.background,t.panelColor,t.surfaceColor] {
            precondition(themeContrast(t.text,background)>=4.5,"Low control contrast in "+name)
            precondition(themeContrast(t.secondaryColor,background)>=3,"Low reorder contrast in "+name)
        }
    }
    print("PASS: control/menu text and reorder contrast in all \(StageTheme.names.count) presets")
}
/// Offline QA artwork uses the actual shared styles, not a separate mockup.
struct ThemeControlSample:View {
    let name:String
    var body:some View {
        VStack(alignment:.leading,spacing:12) {
            Text(name).font(.system(size:16,weight:.semibold))
            HStack(spacing:12) {
                ForEach(["speaker.wave.2","backward.end.fill","play.fill","forward.end.fill","repeat","shuffle"],id:\.self) {symbol in
                    Button {} label:{Group {if ["repeat","shuffle"].contains(symbol) {Image(systemName:symbol).font(.system(size:20))}else {MarkerIcon(systemName:symbol,size:20)}}.frame(width:44,height:40)}.buttonStyle(PlayerControlStyle())
                }
                HStack {Image(systemName:"arrow.up.arrow.down");Text("2 s");Image(systemName:"slider.horizontal.3");Image(systemName:"chevron.down")}.stageMenuInk()
            }
        }.padding(18).frame(width:620,height:116).foregroundStyle(Color(stageHex:AppearancePreferences.shared.theme.text))
            .background(Color(stageHex:AppearancePreferences.shared.theme.background)).stageColorScheme()
    }
}
@MainActor func renderThemeControlSamples(to directory:String)throws {
    defer {UserDefaults(suiteName:AppearancePreferences.gallerySuite)?.removePersistentDomain(forName:AppearancePreferences.gallerySuite)}
    let root=URL(fileURLWithPath:directory,isDirectory:true)
    try FileManager.default.createDirectory(at:root,withIntermediateDirectories:true)
    for name in StageTheme.names {
        AppearancePreferences.shared.theme = .named(name)
        let renderer=ImageRenderer(content:ThemeControlSample(name:name));renderer.scale=2
        guard let cg=renderer.cgImage,let data=NSBitmapImageRep(cgImage:cg).representation(using:.png,properties:[:]) else {fatalError("Unable to render "+name)}
        try data.write(to:root.appendingPathComponent(name+".png"))
    }
    checkThemeControlContrast()
    print("Rendered all preset control samples: "+directory)
}
