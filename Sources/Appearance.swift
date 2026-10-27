import SwiftUI
import AppKit

struct StageTheme: Codable {
    var preset = "Tape Blue"
    var customThemeID: UUID?
    var accent = "93C5F4"
    var background = "20252D"
    var text = "F2F3F6"
    var tape = "ADC9E4"
    var opacity = 0.88
    var mainWindowOpacity:Double?
    var miniWindowOpacity:Double?
    var buttonSize = 60.0
    var textScale = 1.0
    var spacing = 14.0
    var radius = 12.0
    var layoutTextScale:Double {1}
    var layoutButtonSize:Double {60}
    var layoutSpacing:Double {12}
    var texture = true
    // Optional semantic colors keep existing saved themes decodable.
    var panel:String?
    var raisedSurface:String?
    var grid:String?
    var waveform:String?
    var secondaryText:String?
    var gradients:[String:ThemeFillGradient]?
    static let conceptNames=["Studio Precision","Modular Grid","Timecode Core","Shadow System","Hard Minimal","Brutalist Play","Premium Dark","Digital Underground","Grid Motion","Noir Vinyl","Rave Terminal","Steel Play"]
    var isConcept:Bool {Self.conceptNames.contains(preset)}
    var panelColor:String {panel ?? background}
    var surfaceColor:String {raisedSurface ?? panelColor}
    var gridColor:String {grid ?? text}
    var waveColor:String {waveform ?? accent}
    var secondaryColor:String {secondaryText ?? text}
    var isLight:Bool {
        let rgb = UInt64(background, radix:16) ?? 0x20252D
        let red = Double((rgb >> 16) & 255)
        let green = Double((rgb >> 8) & 255)
        let blue = Double(rgb & 255)
        let luminance = red * 0.2126 + green * 0.7152 + blue * 0.0722
        return luminance > 160
    }
    var usesMono:Bool {preset == "Mono Console" || preset == "Signal White"}
    var flatBackdrop:Bool {isLight || isConcept || ["Mono Console","Crew Tape","Signal White"].contains(preset)}
    static let names = ["Mono Console", "Crew Tape", "White"]+conceptNames
    static func named(_ name: String) -> StageTheme {
        var t = StageTheme(); t.preset = name
        switch name {
        case "Hard Minimal":
            t.background="0B0D0F";t.panel="15191D";t.raisedSurface="20262B";t.text="F5F6F7";t.secondaryText="929BA4";t.accent="DDE4E9";t.waveform="DDE4E9";t.grid="343A40";t.tape="20262B";t.radius=3;t.spacing=12;t.opacity=1;t.texture=false
        case "Brutalist Play":
            t.background="090909";t.panel="171717";t.raisedSurface="242424";t.text="F5F5F1";t.secondaryText="929292";t.accent="E3443C";t.waveform="F5F5F1";t.grid="4A4A4A";t.tape="171717";t.radius=0;t.spacing=10;t.opacity=1;t.texture=false
        case "Premium Dark":
            t.background="101316";t.panel="1C2227";t.raisedSurface="2A3239";t.text="F1F3F4";t.secondaryText="9BA5AE";t.accent="91B4C7";t.waveform="B8D1DE";t.grid="3A434B";t.tape="2A3239";t.radius=12;t.spacing=16;t.opacity=1;t.texture=false
        case "Digital Underground":
            t.background="10100D";t.panel="1B1B15";t.raisedSurface="28271E";t.text="E5E1D3";t.secondaryText="ABA58E";t.accent="B5A163";t.waveform="C0AF78";t.grid="3D392B";t.tape="28271E";t.radius=3;t.spacing=12;t.opacity=1;t.texture=true
        case "Grid Motion":
            t.background="0B1014";t.panel="182027";t.raisedSurface="25323C";t.text="EBF0F2";t.secondaryText="A3B6C0";t.accent="65B7D4";t.waveform="A4DDEA";t.grid="354650";t.tape="182027";t.radius=6;t.spacing=14;t.opacity=1;t.texture=true
        case "Noir Vinyl":
            t.background="08090B";t.panel="17191C";t.raisedSurface="222529";t.text="F2F0EB";t.secondaryText="999B9E";t.accent="C4C7C8";t.waveform="C4C7C8";t.grid="373A3D";t.tape="222529";t.radius=14;t.spacing=16;t.opacity=1;t.texture=false
        case "Rave Terminal":
            t.background="040804";t.panel="0B140B";t.raisedSurface="132010";t.text="D8E7CE";t.secondaryText="9BB690";t.accent="B9FF00";t.waveform="B9FF00";t.grid="24461E";t.tape="0B140B";t.radius=0;t.spacing=10;t.opacity=1;t.texture=true
        case "Steel Play":
            t.background="141619";t.panel="2A2E33";t.raisedSurface="343B42";t.text="ECEFF0";t.secondaryText="B5BBC0";t.accent="FF8B2A";t.waveform="FF8B2A";t.grid="50575E";t.tape="656C72";t.radius=5;t.spacing=12;t.opacity=1;t.texture=false
        case "Studio Precision":
            t.background="10151A";t.panel="1B242C";t.raisedSurface="25323C";t.text="E4EBF0";t.accent="3D9DC8";t.waveform="70B7D9";t.grid="33434D";t.secondaryText="A7BAC6";t.tape="25323C";t.radius=5;t.spacing=12;t.texture=true;t.opacity=1
        case "Modular Grid":
            t.background="0D1012";t.panel="15191C";t.raisedSurface="202629";t.text="E9EBE8";t.accent="B7C848";t.waveform="B7C848";t.grid="343C40";t.secondaryText="9BA4A5";t.tape="15191C";t.radius=2;t.spacing=12;t.texture=true;t.opacity=1
        case "Timecode Core":
            t.background="0A0D11";t.panel="171D23";t.raisedSurface="222B34";t.text="EDF0F3";t.accent="E43A43";t.waveform="E43A43";t.grid="303A44";t.secondaryText="A0AAB4";t.tape="171D23";t.radius=4;t.spacing=10;t.texture=true;t.opacity=1
        case "Shadow System":
            t.background="07090B";t.panel="111416";t.raisedSurface="1C2023";t.text="DCE1E4";t.accent="889AA6";t.waveform="889AA6";t.grid="292F34";t.secondaryText="8B939A";t.tape="1C2023";t.radius=10;t.spacing=16;t.texture=false;t.opacity=1
        case "White", "Blue & White": t.background="DCE3E9";t.panel="D2DBE3";t.raisedSurface="CDD7E0";t.text="172C4D";t.accent="1756A9";t.tape="C4D2E0";t.opacity=1;t.texture=false;t.radius=10;t.spacing=14
        case "Mono Console": t.background="111820";t.text="E5EDF2";t.accent="8EC9DB";t.tape="DAE7E9";t.opacity=1;t.radius=4;t.spacing=14;t.texture=true
        case "Crew Tape": t.background="20211F";t.text="F1EEE5";t.accent="DEC283";t.tape="E6D4A4";t.opacity=1;t.radius=5;t.spacing=14;t.texture=true
        case "Signal White": t.background="DCDDD7";t.panel="D0D4CE";t.text="202B33";t.accent="245F73";t.tape="E7D59F";t.opacity=1;t.radius=6;t.spacing=14;t.texture=true
        case "Tape Blue": t.tape="ADC9E4";t.accent="ADC9E4";t.radius=6
        case "Tape White": t.tape="E9E5D9";t.accent="E9E5D9";t.radius=6
        case "Tape Black": t.tape="15181D";t.accent="C5D2E2";t.radius=6
        case "FOH": t.background="141A21";t.accent="A8CADF";t.tape="B9D3DF";t.radius=5;t.opacity=0.96;t.spacing=16
        case "Stage Crew": t.background="202124";t.accent="D9C69B";t.tape="DACAA6";t.radius=5;t.opacity=0.96;t.spacing=16
        case "Stagehand": t.background="1A1D26";t.accent="B8BCD9";t.tape="E2E0D7";t.radius=6;t.opacity=0.96;t.spacing=16
        case "Speaker Grille": t.background="171D24";t.accent="9EBED6";t.tape="B7CAD4";t.radius=5;t.opacity=0.97;t.spacing=12
        case "Road Case": t.background="20252B";t.accent="BFCCD9";t.tape="D7C79E";t.radius=4;t.opacity=0.96;t.spacing=12
        case "Stage": t.background="27374B";t.tape="C8C8FB"
        case "Flightcase": t.background = "252C35"; t.accent = "BDD9ED"; t.tape = "EBCB89"; t.radius = 5
        case "Cables": t.background = "122C38"; t.accent = "7DDAEB"; t.tape = "E8BC95"; t.radius = 18
        case "Cinema": t.background = "151925"; t.accent = "E6BD83"; t.tape = "C4CBDD"; t.radius = 8
        case "Theatre": t.background = "381F32"; t.accent = "E6B6B7"; t.tape = "E6CEA2"; t.radius = 16
        case "Minimal": t.background = "1D293A"; t.accent = "A9CFF7"; t.texture = false; t.opacity = 0.82
        default: break
        }
        return t
    }
}
struct SavedStageTheme: Codable, Identifiable {
    var id: UUID
    var name: String
    var theme: StageTheme
}
final class AppearancePreferences: ObservableObject {
    static let gallerySuite="local.hardplay.gallery.\(UUID().uuidString)"
    static let shared = AppearancePreferences(defaults:CommandLine.arguments.contains("--theme-controls-gallery") ? UserDefaults(suiteName:gallerySuite)!:.standard)
    private let defaults: UserDefaults
    @Published private(set) var customThemes: [SavedStageTheme] = [] {
        didSet { if let data = try? JSONEncoder().encode(customThemes) { defaults.set(data,forKey:"stageCustomThemes.v1") } }
    }
    @Published var theme: StageTheme { didSet { for window in NSApp?.windows ?? [] {window.appearance=NSAppearance(named:theme.isLight ? .aqua:.darkAqua)};if let data = try? JSONEncoder().encode(theme) { defaults.set(data, forKey:"stageAppearance.v1") } } }
    init(defaults: UserDefaults = .standard) {
        self.defaults=defaults
        if !defaults.bool(forKey:"blueWhiteModes.v1") {
            if let previous=defaults.data(forKey:"stageAppearance.v1") {defaults.set(previous,forKey:"stageAppearance.beforeBlueWhite.v1")}
            defaults.set(try? JSONEncoder().encode(StageTheme.named("Blue & White")),forKey:"stageAppearance.v1");defaults.set(true,forKey:"blueWhiteModes.v1");defaults.set(true,forKey:"markerStyle.v1")
        }
        let prior=defaults.data(forKey:"stageAppearance.v1")
        if !defaults.bool(forKey:"markerStyle.v1") {
            if let prior {defaults.set(prior,forKey:"stageAppearance.beforeMarker.v1")}
            theme = .named("Modular Grid");defaults.set(true,forKey:"markerStyle.v1")
            if let data=try? JSONEncoder().encode(theme) {defaults.set(data,forKey:"stageAppearance.v1")}
        } else {theme=prior.flatMap {try? JSONDecoder().decode(StageTheme.self,from:$0)} ?? .named("Modular Grid")}
        customThemes = defaults.data(forKey:"stageCustomThemes.v1").flatMap {try? JSONDecoder().decode([SavedStageTheme].self,from:$0)} ?? []
        if theme.preset == "Blue & White" {theme.preset = "White"}
        if ["FOH","Tape Blue","Tape Black","Stage","Cables","Minimal"].contains(theme.preset),theme.customThemeID == nil {theme = .named("Modular Grid")}
        // Update only unchanged factory colors, preserving user overrides and named custom themes.
        if theme.preset == "Digital Underground",theme.customThemeID == nil {
            let updated=StageTheme.named("Digital Underground")
            let old:[ThemeColorSlot:String]=[.background:"050907",.panel:"101610",.surface:"1A2417",.text:"E0E9DC",.secondary:"A1B197",.accent:"C4FF00",.waveform:"C4FF00",.grid:"28411D",.tape:"101610"]
            for (slot,value) in old where theme.hex(slot)==value {theme.setHex(updated.hex(slot),for:slot)}
        }
        // Only migrate untouched legacy light backgrounds; retain custom saved themes and other adjustments.
        if theme.customThemeID == nil,theme.preset == "White",theme.background == "F5F8FD" {
            theme.background="DCE3E9";theme.panel=theme.panel ?? "D2DBE3";theme.raisedSurface=theme.raisedSurface ?? "CDD7E0"
            if theme.tape == "DBE8FA" {theme.tape="C4D2E0"}
        }
        if theme.customThemeID == nil,theme.preset == "Signal White",theme.background == "F2F1EC" {theme.background="DCDDD7";theme.panel=theme.panel ?? "D0D4CE"}
        if !defaults.bool(forKey:"curatedThemes.v1"), !StageTheme.names.contains(theme.preset), theme.customThemeID == nil {
            // Retain any existing customized appearance before hiding retired presets.
            let previous = theme
            let id = UUID()
            var snapshot = previous; snapshot.customThemeID = id
            customThemes.append(SavedStageTheme(id:id,name:"Imported \(previous.preset)",theme:snapshot))
            theme = snapshot
        }
        if !defaults.bool(forKey:"modularGridDefault.v1") {
            defaults.set(try? JSONEncoder().encode(theme),forKey:"stageAppearance.beforeModularGrid.v1")
            theme = .named("Modular Grid")
            defaults.set(true,forKey:"modularGridDefault.v1")
        }
        defaults.set(true,forKey:"curatedThemes.v1")
        if let data = try? JSONEncoder().encode(customThemes) {defaults.set(data,forKey:"stageCustomThemes.v1")}
        if let data = try? JSONEncoder().encode(theme) {defaults.set(data,forKey:"stageAppearance.v1")}
    }
    var currentThemeName: String {
        customThemes.first(where:{$0.id == theme.customThemeID})?.name ?? theme.preset
    }
    @discardableResult
    func saveCustom(named name: String) -> Bool {
        let name = name.trimmingCharacters(in:.whitespacesAndNewlines)
        guard !name.isEmpty else { return false }
        let index = customThemes.firstIndex(where:{$0.name.caseInsensitiveCompare(name) == .orderedSame})
        let id = index.map { customThemes[$0].id } ?? UUID()
        var snapshot = theme
        snapshot.customThemeID = id
        let saved = SavedStageTheme(id:id,name:name,theme:snapshot)
        if let index {customThemes[index] = saved} else {customThemes.append(saved)}
        theme = snapshot
        return true
    }
    func removeCustom(_ id: UUID) {
        customThemes.removeAll {$0.id == id}
        if theme.customThemeID == id { theme.customThemeID = nil }
    }
    func semanticColor(_ key:WritableKeyPath<StageTheme,String?>,fallback:String)->Binding<Color> {
        Binding(get:{Color(stageHex:self.theme[keyPath:key] ?? fallback)},set:{color in
            guard let c=NSColor(color).usingColorSpace(.sRGB) else {return}
            self.theme[keyPath:key]=String(format:"%02X%02X%02X",Int(c.redComponent*255),Int(c.greenComponent*255),Int(c.blueComponent*255))
        })
    }
    func color(_ key: WritableKeyPath<StageTheme,String>) -> Binding<Color> {
        Binding(get:{ Color(stageHex:self.theme[keyPath:key]) },set:{ color in
            guard let c = NSColor(color).usingColorSpace(.sRGB) else { return }
            self.theme[keyPath:key] = String(format:"%02X%02X%02X",Int(c.redComponent*255),Int(c.greenComponent*255),Int(c.blueComponent*255))
        })
    }
}
extension Color {
    init(stageHex: String) {
        let value = UInt64(stageHex,radix:16) ?? 0x93C5F4
        self.init(red:Double((value>>16)&255)/255,green:Double((value>>8)&255)/255,blue:Double(value&255)/255)
    }
}
struct ThemedBackdrop: View {
    var playerWindow:String?=nil
    @ObservedObject var appearance = AppearancePreferences.shared
    var body: some View {
        let t = appearance.theme
        let windowOpacity = playerWindow == "main" ? (t.mainWindowOpacity ?? 1) : playerWindow == "mini" ? (t.miniWindowOpacity ?? 1) : 1
        Group {if t.gradients?["background"] != nil {Rectangle().fill(t.paint(.background)).opacity(windowOpacity)}else if windowOpacity < 1 {Color(stageHex:t.background).opacity(windowOpacity)}else if t.flatBackdrop {Color(stageHex:t.background)}else {GlassBackdrop().overlay(Color(stageHex:t.background).opacity(t.opacity))}}
            .overlay {
                if t.texture {
                    Canvas { ctx,size in
                        let color = Color(stageHex:t.accent).opacity(0.025)
                        switch t.preset {
                        case "Studio Precision","Modular Grid","Timecode Core","Digital Underground","Grid Motion","Rave Terminal":
                            // Sparse static layout marks only: no raster texture or running animation.
                            let ink=Color(stageHex:t.gridColor).opacity(t.preset == "Modular Grid" ? 0.38:0.22)
                            let step:CGFloat=t.preset == "Modular Grid" ? 64:96
                            var lines=Path()
                            for x in stride(from:CGFloat(16),to:size.width,by:step) {lines.move(to:.init(x:x,y:12));lines.addLine(to:.init(x:x,y:size.height-12))}
                            for y in stride(from:CGFloat(12),to:size.height,by:step) {lines.move(to:.init(x:16,y:y));lines.addLine(to:.init(x:size.width-16,y:y))}
                            ctx.stroke(lines,with:.color(ink),lineWidth:0.5)
                        case "Mono Console", "Signal White":
                            // A fixed number of registration marks; no images or continuous animation.
                            let ink=Color(stageHex:t.text).opacity(0.12)
                            let inset=10.0,arm=14.0
                            for point in [CGPoint(x:inset,y:inset),CGPoint(x:size.width-inset,y:inset),CGPoint(x:inset,y:size.height-inset),CGPoint(x:size.width-inset,y:size.height-inset)] {
                                let dx=point.x<size.width/2 ? arm:-arm,dy=point.y<size.height/2 ? arm:-arm
                                var mark=Path();mark.move(to:CGPoint(x:point.x+dx,y:point.y));mark.addLine(to:point);mark.addLine(to:CGPoint(x:point.x,y:point.y+dy));ctx.stroke(mark,with:.color(ink),lineWidth:1)
                            }
                            for i in 0..<12 {ctx.fill(Path(CGRect(x:20+Double(i)*6,y:size.height-8,width:1,height:i%3==0 ? 5:2)),with:.color(ink))}
                        case "Crew Tape":
                            let ink=Color(stageHex:t.tape)
                            for x in [8.0,size.width-34] {
                                var tape=Path();tape.addLines([CGPoint(x:x,y:8),CGPoint(x:x+28,y:10),CGPoint(x:x+25,y:15),CGPoint(x:x-1,y:13)]);tape.closeSubpath();ctx.fill(tape,with:.color(ink.opacity(0.45)))
                            }
                            var seam=Path();seam.addRect(CGRect(x:6,y:6,width:max(0,size.width-12),height:max(0,size.height-12)))
                            ctx.stroke(seam,with:.color(ink.opacity(0.10)),style:StrokeStyle(lineWidth:0.8,dash:[3,7]))
                        case "FOH", "Stage Crew", "Stagehand":
                            // Sparse tolex lines and case hardware; static paths, no texture images.
                            var grain=Path()
                            for y in stride(from:16.0,to:size.height,by:36) {grain.move(to:.init(x:12,y:y));grain.addLine(to:.init(x:size.width-12,y:y+8))}
                            ctx.stroke(grain,with:.color(.white.opacity(0.025)),lineWidth:0.5)
                            let shell=CGRect(x:5,y:5,width:max(0,size.width-10),height:max(0,size.height-10))
                            ctx.stroke(Path(roundedRect:shell,cornerRadius:12),with:.color(Color(stageHex:"76818A").opacity(0.48)),lineWidth:5)
                            ctx.stroke(Path(roundedRect:shell.insetBy(dx:3,dy:3),cornerRadius:10),with:.color(.black.opacity(0.8)),lineWidth:1)
                            for x in [10.0,size.width-10] {for y in [10.0,size.height-10] {
                                let plate=CGRect(x:x-6,y:y-6,width:12,height:12)
                                ctx.fill(Path(roundedRect:plate,cornerRadius:3),with:.color(Color(stageHex:"8C959B").opacity(0.65)))
                                ctx.fill(Path(ellipseIn:plate.insetBy(dx:4,dy:4)),with:.color(.black.opacity(0.6)))
                            }}
                            // A small inventory barcode, decorative only, outside the controls.
                            for i in 0..<16 {
                                ctx.fill(Path(CGRect(x:size.width-70+Double(i)*3,y:size.height-12,width:i%3==0 ? 2:1,height:5)),with:.color(.white.opacity(0.16)))
                            }
                        case "Speaker Grille":
                            for row in 0...Int(size.height/9) {
                                for x in stride(from:row%2 == 0 ? 3.0:7.5,to:size.width,by:9) {
                                    let y=CGFloat(row)*9
                                    ctx.fill(Path(ellipseIn:CGRect(x:x,y:y+0.7,width:4.6,height:4.6)),with:.color(.white.opacity(0.065)))
                                    ctx.fill(Path(ellipseIn:CGRect(x:x,y:y,width:4.6,height:4.6)),with:.color(.black.opacity(0.5)))
                                }
                            }
                        case "Road Case", "Flightcase":
                            for y in stride(from:0.0,to:size.height,by:7) {
                                var p=Path();p.move(to:.init(x:0,y:y));p.addLine(to:.init(x:size.width,y:y+size.width*0.12));ctx.stroke(p,with:.color(.white.opacity(0.025)),lineWidth:0.6)
                            }
                            let rail=CGRect(x:6,y:6,width:max(0,size.width-12),height:max(0,size.height-12))
                            ctx.stroke(Path(roundedRect:rail,cornerRadius:11),with:.color(Color(stageHex:"7F8993").opacity(0.55)),lineWidth:7)
                            ctx.stroke(Path(roundedRect:rail.insetBy(dx:4,dy:4),cornerRadius:8),with:.color(.black.opacity(0.7)),lineWidth:1)
                            for x in [12.0,size.width-12] {for y in [12.0,size.height-12] {
                                ctx.fill(Path(ellipseIn:CGRect(x:x-2.2,y:y-2.2,width:4.4,height:4.4)),with:.color(.white.opacity(0.5)))
                                var screw=Path();screw.move(to:.init(x:x-1,y:y));screw.addLine(to:.init(x:x+1,y:y));ctx.stroke(screw,with:.color(.black.opacity(0.7)),lineWidth:0.7)
                            }}
                        case "Tape Blue", "Tape White", "Tape Black":
                            for x in stride(from:8.0,to:size.width,by:24) { for y in stride(from:8.0,to:size.height,by:24) { ctx.fill(Path(ellipseIn:CGRect(x:x,y:y,width:2,height:2)),with:.color(color)) } }
                        case "Cables":
                            for i in 0..<7 { var p=Path(); let y=CGFloat(i)*110; p.move(to:CGPoint(x:0,y:y)); p.addCurve(to:CGPoint(x:size.width,y:y+90),control1:CGPoint(x:size.width*0.65,y:y-80),control2:CGPoint(x:size.width*0.3,y:y+190)); ctx.stroke(p,with:.color(color),lineWidth:3) }
                        case "Cinema":
                            for y in stride(from:14.0,to:size.height,by:28) { for x in [5.0,size.width-12] { ctx.fill(Path(roundedRect:CGRect(x:x,y:y,width:7,height:12),cornerRadius:2),with:.color(color)) } }
                        case "Theatre":
                            for x in stride(from:0.0,to:size.width,by:20) { ctx.fill(Path(CGRect(x:x,y:0,width:8,height:size.height)),with:.color(color)) }
                        case "Stage":
                            var p=Path(); for y in stride(from:0.0,to:size.height,by:70) { p.move(to:CGPoint(x:0,y:y));p.addLine(to:CGPoint(x:size.width,y:y)) };ctx.stroke(p,with:.color(color),lineWidth:1)
                        default: break
                        }
                    }.allowsHitTesting(false)
                }
            }
    }
}
final class ThemeNameDraft: ObservableObject {
    @Published var name = ""
}
struct ThemeEditorView: View {
    var embedded=false
    @StateObject private var draft = ThemeNameDraft()
    @ObservedObject var appearance = AppearancePreferences.shared
    @ObservedObject var setup = SetupLock.shared
    @ObservedObject var lock = ControlLock.shared
    var body: some View {
        ScrollView {
            VStack(alignment:.leading,spacing:16) {
                Text("Themes & Appearance").font(.stage(.title2).bold())
                Text("Lightweight native themes · mono console · crew tape · stage markings. Live preview stays in the player.").font(.stage(.callout)).stageSecondary()
                presetGrid
                savedThemes
                Divider()
                Text("Customize · \(appearance.currentThemeName)").font(.stage(.headline))
                ForEach(ThemeColorSlot.allCases) {slot in ThemeColorButton(slot:slot)}
                adjustment("Main window opacity",value:Binding(get:{appearance.theme.mainWindowOpacity ?? 1},set:{appearance.theme.mainWindowOpacity=($0 * 100).rounded()/100}),range:0.3...1,suffix:"%",factor:100)
                adjustment("Mini window opacity",value:Binding(get:{appearance.theme.miniWindowOpacity ?? 1},set:{appearance.theme.miniWindowOpacity=($0 * 100).rounded()/100}),range:0.3...1,suffix:"%",factor:100)
                adjustment("Background opacity",value:$appearance.theme.opacity,range:0.25...1,suffix:"%",factor:100)
                Text("Window, text and button sizes: PATCH → Window → Small / Optimal / Large.").font(.stage(.caption)).stageSecondary()
                adjustment("Corner radius",value:$appearance.theme.radius,range:0...24,suffix:" px")
                Toggle("Scenic texture",isOn:$appearance.theme.texture)
                HStack {
                    TextField("Theme name",text:$draft.name).textFieldStyle(.roundedBorder)
                        .onSubmit {appearance.saveCustom(named:draft.name)}
                    Button("Save Theme") {appearance.saveCustom(named:draft.name)}
                        .buttonStyle(.borderedProminent)
                        .disabled(draft.name.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty)
                }
                Text("Save a new name to create a theme. Use an existing name to update it.").font(.stage(.caption)).stageSecondary()
                Button("Reset to Modular Grid") { appearance.theme = .named("Modular Grid") }.buttonStyle(.bordered)
                Text("Current appearance is saved automatically on this Mac. Named themes stay in My Themes.").font(.stage(.caption)).stageSecondary()
            }.padding(22).disabled(setup.settingsBlocked || lock.isLocked)
        }.frame(minWidth:360,minHeight:embedded ? 300:500).foregroundStyle(Color(stageHex:appearance.theme.text))
    }
    private var presetGrid: some View {
                LazyVGrid(columns:[GridItem(.flexible()),GridItem(.flexible())],spacing:8) {
                    ForEach(StageTheme.names,id:\.self) { name in
                        Button { appearance.theme = .named(name); draft.name = "" } label: {
                            HStack { Circle().fill(Color(stageHex:StageTheme.named(name).accent)).frame(width:12,height:12);Text(name);Spacer();if appearance.theme.customThemeID == nil && appearance.theme.preset == name { MarkerIcon(systemName:"checkmark") } }.padding(9)
                        }.buttonStyle(PlayerControlStyle(active:appearance.theme.customThemeID == nil && appearance.theme.preset == name))
                    }
                }
    }
    @ViewBuilder private var savedThemes: some View {
                if !appearance.customThemes.isEmpty {
                    Text("My Themes").font(.stage(.headline))
                    ForEach(appearance.customThemes) { saved in
                        HStack(spacing:8) {
                            Button { appearance.theme = saved.theme; draft.name = saved.name } label: {
                                HStack { Circle().fill(Color(stageHex:saved.theme.accent)).frame(width:12,height:12);Text(saved.name);Spacer();if appearance.theme.customThemeID == saved.id {MarkerIcon(systemName:"checkmark")} }.padding(9)
                            }.buttonStyle(PlayerControlStyle(active:appearance.theme.customThemeID == saved.id))
                            Button { appearance.removeCustom(saved.id) } label: {MarkerIcon(systemName:"trash")}
                                .buttonStyle(.bordered).help("Delete saved theme").accessibilityLabel("Delete theme: \(saved.name)")
                        }
                    }
                }
    }
    private func adjustment(_ title:String,value:Binding<Double>,range:ClosedRange<Double>,suffix:String,factor:Double=1)->some View {
        VStack(spacing:5) { HStack { Text(title);Spacer();Text("\(Int(value.wrappedValue*factor))\(suffix)").monospacedDigit().stageSecondary() };Slider(value:value,in:range).tint(accent).accessibilityLabel(title) }
    }
}
