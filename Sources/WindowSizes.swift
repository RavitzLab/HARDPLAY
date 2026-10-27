import AppKit
import SwiftUI

enum WindowSizeChoice:String,CaseIterable,Identifiable {
    case small="Small",optimal="Optimal",large="Large"
    var id:String {rawValue}
    var scale:CGFloat {switch self {case .small:return 0.84;case .optimal:return 1;case .large:return 1.18}}
}
enum SizedWindow:String,CaseIterable,Identifiable {
    case dj="DJ",main="Main",mini="Mini",nano="Nano",playlist="Playlist",nanoPlaylist="Nano Playlist",patch="PATCH",themes="Themes",editor="Audio Editor",mappings="Keyboard / MIDI",backup="Timecode & Backup",web="Web Viewer",menuBar="Menu-bar Player"
    var id:String {rawValue}
    var title:String {switch self {case .dj:return "Hard Play DJ";case .main:return "Hard Play";case .mini:return "Hard Play Mini";case .nano:return "Hard Play Pocket";case .playlist:return "Hard Play Playlist";case .nanoPlaylist:return "Hard Play Nano Playlist";case .patch:return "Hard Play PATCH";case .themes:return "Hard Play Themes";case .editor:return "Hard Play Quick Edit";case .mappings:return "Hard Play Keyboard / MIDI";case .backup:return "Hard Play Timecode & Backup";case .web:return "Hard Play Web Viewer";case .menuBar:return ""}}
    static func identify(_ window:NSWindow)->Self? {allCases.first {$0 != .menuBar && $0.title == window.title}}
    func canvas(inline:Bool,wide:Bool,workspace:Bool,tracks:Int=8)->NSSize {
        switch self {
        case .dj:return NSSize(width:1160,height:810)
        case .main:if workspace {return NSSize(width:840,height:760)};return wide ? NSSize(width:1200,height:610):NSSize(width:700,height:inline ? 700:470)
        case .mini:return NSSize(width:440,height:inline ? 690:430)
        case .nano:return NSSize(width:384,height:380)
        case .playlist:return NSSize(width:520,height:620)
        case .nanoPlaylist:return NSSize(width:360,height:max(92,86+min(320,CGFloat(tracks)*44)))
        case .patch:return NSSize(width:800,height:750)
        case .themes:return NSSize(width:520,height:760)
        case .editor:return NSSize(width:880,height:780)
        case .mappings:return NSSize(width:700,height:740)
        case .backup:return NSSize(width:620,height:740)
        case .web:return NSSize(width:520,height:700)
        case .menuBar:return NSSize(width:372,height:420)
        }
    }
}
final class WindowSizes:ObservableObject {
    static let shared=WindowSizes()
    private let defaults:UserDefaults
    @Published private(set) var choices:[String:String]
    @Published var wide:Bool {didSet {defaults.set(wide,forKey:"fixedWindowWide");applyAll()}}
    private var applying=false
    init(defaults:UserDefaults = .standard) {self.defaults=defaults;choices=defaults.dictionary(forKey:"windowSizes.v1") as? [String:String] ?? [:];wide=defaults.bool(forKey:"fixedWindowWide")}
    func choice(_ role:SizedWindow)->WindowSizeChoice {choices[role.rawValue].flatMap(WindowSizeChoice.init(rawValue:)) ?? .optimal}
    func set(_ value:WindowSizeChoice,for role:SizedWindow) {
        guard !ControlLock.shared.isLocked,!SetupLock.shared.settingsBlocked else {return}
        choices[role.rawValue]=value.rawValue;defaults.set(choices,forKey:"windowSizes.v1");applyAll()
    }
    func base(_ role:SizedWindow)->NSSize {
        role.canvas(inline:PlaylistWindowState.shared.shown && !PlaylistWindowState.shared.detached,wide:wide,workspace:WorkspaceState.shared.section != nil,tracks:role == .nanoPlaylist ? Player.shared.tracks.count:8)
    }
    static func fittedScale(choice:WindowSizeChoice,canvas:NSSize,visible:NSSize,chrome:CGFloat)->CGFloat {
        min(choice.scale,max(0.1,(visible.width-12)/canvas.width),max(0.1,(visible.height-chrome-12)/canvas.height))
    }
    func scale(_ role:SizedWindow)->CGFloat {
        let window=NSApp?.windows.first {SizedWindow.identify($0)==role}
        let visible=window?.screen?.visibleFrame.size ?? NSScreen.main?.visibleFrame.size ?? NSSize(width:1440,height:900)
        let chrome=window.map {max(0,$0.frame.height-$0.contentLayoutRect.height)} ?? (role == .nano || role == .nanoPlaylist || role == .menuBar ? 0:28)
        return Self.fittedScale(choice:choice(role),canvas:base(role),visible:visible,chrome:chrome)
    }
    func apply(_ window:NSWindow) {
        guard !applying,let role=SizedWindow.identify(window),!window.styleMask.contains(.fullScreen) else {return}
        applying=true;defer {applying=false}
        let base=base(role),scale=scale(role)
        let size=NSSize(width:(base.width*scale).rounded(),height:(base.height*scale).rounded())
        let current=window.frame,visible=window.screen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? current
        // Window profiles own sizing. SwiftUI must not write competing min/max constraints.
        if let host=window.contentView as? any FixedCanvasHosting {host.disableAutomaticSizing()}
        if role != .main,window.styleMask.contains(.resizable) {window.styleMask.remove(.resizable)}
        let full=window.frameRect(forContentRect:NSRect(origin:.zero,size:size)).size
        let target=NSRect(x:min(max(current.minX,visible.minX),visible.maxX-full.width),y:min(max(current.maxY-full.height,visible.minY),visible.maxY-full.height),width:full.width,height:full.height)
        let sizeChanged=abs(current.width-full.width)>1 || abs(current.height-full.height)>1
        let limitsChanged=window.minSize != full || window.maxSize != full
        // Idempotent: do not reset limits on every fit request or layout notification.
        guard sizeChanged || limitsChanged || !visible.contains(current) else {return}
        if limitsChanged || sizeChanged {window.minSize=NSSize(width:1,height:1);window.maxSize=NSSize(width:10000,height:10000)}
        if sizeChanged || !visible.contains(current) {window.setFrame(target,display:true)}
        if window.minSize != full {window.minSize=full};if window.maxSize != full {window.maxSize=full}
    }
    func cycle(_ role:SizedWindow) {let all=WindowSizeChoice.allCases;set(all[(all.firstIndex(of:choice(role))!+1)%all.count],for:role)}
    func applyAll() {for window in NSApp?.windows ?? [] {apply(window)}}
}
struct SizedWindowCanvas:ViewModifier {
    let role:SizedWindow
    @ObservedObject private var sizes=WindowSizes.shared
    @ObservedObject private var playlist=PlaylistWindowState.shared
    @ObservedObject private var workspace=WorkspaceState.shared
    func body(content:Content)->some View {
        let base=sizes.base(role),scale=sizes.scale(role)
        content.frame(width:base.width,height:base.height,alignment:.topLeading)
            .scaleEffect(scale,anchor:.topLeading).frame(width:(base.width*scale).rounded(),height:(base.height*scale).rounded(),alignment:.topLeading)
            .onAppear {DispatchQueue.main.async {sizes.applyAll()}}
            .onChange(of:sizes.choices) {_,_ in sizes.applyAll()}.onChange(of:sizes.wide) {_,_ in sizes.applyAll()}
            .onChange(of:playlist.shown) {_,_ in sizes.applyAll()}.onChange(of:playlist.detached) {_,_ in sizes.applyAll()}
            .onChange(of:workspace.section) {_,_ in sizes.applyAll()}
    }
}
extension View {func windowSizeCanvas(_ role:SizedWindow)->some View {modifier(SizedWindowCanvas(role:role))}}
struct WindowSizePicker:View {
    let role:SizedWindow
    @ObservedObject private var sizes=WindowSizes.shared
    var body:some View {
        VStack(alignment:.leading,spacing:8) {
            HStack(spacing:8) {ForEach(WindowSizeChoice.allCases) {choice in
                Button {sizes.set(choice,for:role)} label:{Text(choice.rawValue).font(.system(size:12,weight:.semibold)).frame(minWidth:58).padding(8)}
                    .buttonStyle(PlayerControlStyle(active:sizes.choice(role)==choice)).accessibilityLabel(role.rawValue+" Size · "+choice.rawValue)
            }}
            Text("Window, text and controls scale together. Large fits the available screen.").font(.system(size:11)).stageSecondary().fixedSize(horizontal:false,vertical:true)
        }
    }
}
struct WindowSizeMenu:View {
    let role:SizedWindow
    @ObservedObject private var sizes=WindowSizes.shared
    var body:some View {
        Menu {ForEach(WindowSizeChoice.allCases) {choice in Button((sizes.choice(role)==choice ? "✓ ":"")+choice.rawValue) {sizes.set(choice,for:role)}}} label:{Image(systemName:"textformat.size").frame(width:22,height:22)}
            .menuStyle(.borderlessButton).stageMenuInk().accessibilityLabel(role.rawValue+" Window Size").stageHint("Small · Optimal · Large")
    }
}
func checkWindowSizes() {
    for role in SizedWindow.allCases {for choice in WindowSizeChoice.allCases {for visible in [NSSize(width:1280,height:760),NSSize(width:1440,height:860),NSSize(width:1920,height:1040)] {
        for inline in [true,false] {for wide in [true,false] {
            let base=role.canvas(inline:inline,wide:wide,workspace:false,tracks:26)
            let scale=WindowSizes.fittedScale(choice:choice,canvas:base,visible:visible,chrome:28)
            precondition(scale>0 && scale<=choice.scale)
            precondition(base.width*scale<=visible.width-11 && base.height*scale+28<=visible.height-11)
            precondition(abs((base.width*scale)/(base.height*scale)-base.width/base.height)<0.00001)
        }}
    }}}
    let suite="local.hardplay.window-sizing.\(UUID().uuidString)"
    let defaults=UserDefaults(suiteName:suite)!
    defaults.set(["Main":"Small","Mini":"Large"],forKey:"windowSizes.v1")
    let restored=WindowSizes(defaults:defaults);precondition(restored.choice(.main) == .small && restored.choice(.mini) == .large && restored.choice(.nano) == .optimal)
    defaults.removePersistentDomain(forName:suite)
    print("PASS: three independent window sizes; all window roles fit three screen sizes without aspect distortion")
}

/// Fixed profile canvases already have explicit bounds; don't ask SwiftUI to resize their NSWindow.
protocol FixedCanvasHosting {func disableAutomaticSizing()}
final class ProfileHostingView<Content:View>:NSHostingView<Content>,FixedCanvasHosting {
    required init(rootView:Content) {super.init(rootView:rootView);sizingOptions=[]}
    @available(*,unavailable) required init?(coder:NSCoder) {fatalError("init(coder:) is not supported")}
    func disableAutomaticSizing() {if !sizingOptions.isEmpty {sizingOptions=[]}}
}

@MainActor func checkFixedWindowLayout() {
    _ = NSApplication.shared
    let suite="hardplay.fixed-layout."+UUID().uuidString
    let defaults=UserDefaults(suiteName:suite)!
    let sizes=WindowSizes(defaults:defaults)
    let window=NSWindow(contentRect:NSRect(x:200,y:200,width:700,height:700),styleMask:[.titled,.closable],backing:.buffered,defer:false)
    window.title="Hard Play";window.isReleasedWhenClosed=false
    let host=ProfileHostingView(rootView:Text("Layout regression").frame(width:700,height:700));window.contentView=host
    sizes.apply(window);let frame=window.frame
    var resized=0
    let observer=NotificationCenter.default.addObserver(forName:NSWindow.didResizeNotification,object:window,queue:.main) {_ in resized+=1}
    for _ in 0..<100 {sizes.apply(window);host.layoutSubtreeIfNeeded()}
    precondition(host.sizingOptions.isEmpty && window.frame==frame && resized==0)
    NotificationCenter.default.removeObserver(observer);window.close();defaults.removePersistentDomain(forName:suite)
    print("PASS: fixed hosting disables competing auto-size constraints; 100 unchanged fits produce zero resize events")
}
