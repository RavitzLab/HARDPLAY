import SwiftUI
import AppKit

/// Native press/release control: Cue and Bend are momentary, not click toggles.
struct DJHoldButton:NSViewRepresentable {
    let title:String
    var down:()->Void
    var up:()->Void
    var enabled:Bool=true
    final class Pad:NSView {
        var title="" {didSet {caption.stringValue=title}}
        private let caption=NSTextField(labelWithString:"")
        override init(frame:NSRect) {
            super.init(frame:frame)
            caption.font=NSFont(name:"Menlo-Bold",size:12) ?? .systemFont(ofSize:12,weight:.semibold)
            caption.alignment = .center;caption.isSelectable=false
            addSubview(caption)
        }
        required init?(coder:NSCoder) {fatalError("init(coder:) is not supported")}
        override func layout() {super.layout();caption.frame=NSRect(x:2,y:(bounds.height-18)/2,width:max(0,bounds.width-4),height:18)}
        var down:(()->Void)?,up:(()->Void)?,enabled=true,held=false
        var ink=NSColor.labelColor,fill=NSColor.controlBackgroundColor
        override var mouseDownCanMoveWindow:Bool {false}
        override func hitTest(_ point:NSPoint)->NSView? {super.hitTest(point) == nil ? nil:self}
        override func draw(_ dirtyRect:NSRect) {
            (held ? ink.withAlphaComponent(0.24):fill).setFill();let path=NSBezierPath(roundedRect:bounds.insetBy(dx:1,dy:1),xRadius:8,yRadius:8);path.fill()
            ink.withAlphaComponent(0.3).setStroke();path.stroke()
            // Keep text layout out of draw(_:): CoreText aborted in size(withAttributes:) on macOS 27.
            caption.textColor=(ink.usingColorSpace(.sRGB) ?? .labelColor).withAlphaComponent(enabled ? 1:0.4)
        }
        override func mouseDown(with event:NSEvent) {guard enabled else {return};held=true;down?();needsDisplay=true}
        override func mouseUp(with event:NSEvent) {release()}
        func release() {if held {held=false;up?();needsDisplay=true}}
        override func viewDidMoveToWindow() {if window==nil {release()}}
        override func accessibilityPerformPress()->Bool {guard enabled else {return false};down?();up?();return true}
    }
    @ObservedObject private var appearance=AppearancePreferences.shared
    @Environment(\.isEnabled) private var environmentEnabled
    func makeNSView(context:Context)->Pad {let pad=Pad();pad.setAccessibilityElement(true);pad.setAccessibilityRole(.button);return pad}
    func updateNSView(_ pad:Pad,context:Context) {pad.title=title;pad.down=down;pad.up=up;pad.enabled=enabled && environmentEnabled;pad.setAccessibilityEnabled(pad.enabled);pad.ink=NSColor(Color(stageHex:appearance.theme.text)).usingColorSpace(.sRGB) ?? .labelColor;pad.fill=NSColor(Color(stageHex:appearance.theme.surfaceColor)).usingColorSpace(.sRGB) ?? .controlBackgroundColor;pad.setAccessibilityLabel(title);if !pad.enabled {pad.release()};pad.needsDisplay=true}
    static func dismantleNSView(_ view:Pad,coordinator:()) {view.release()}
}
final class DJDeckUI:ObservableObject {
    @Published var browsing=false
    @Published var chosen:String?
    var tapTimes:[TimeInterval]=[]
    var jogX:CGFloat?
}
struct DJDeckView:View {
    @ObservedObject var deck:DJDeck
    @ObservedObject var session=DJSession.shared
    @ObservedObject var queue=Player.shared
    @ObservedObject var lock=ControlLock.shared
    @ObservedObject var setup=SetupLock.shared
    @ObservedObject var appearance=AppearancePreferences.shared
    @ObservedObject var waves=Waveforms.shared
    @StateObject private var ui=DJDeckUI()
    private var allowed:Bool {deck.canControl}
    var body:some View {
        VStack(alignment:.leading,spacing:12) {
            header
            Text(deck.track?.title ?? "Load a track").font(.stage(size:19,weight:.semibold)).lineLimit(2).frame(height:48,alignment:.topLeading).help(deck.track?.title ?? "")
            HStack {Text(timeLabel(deck.elapsed));Spacer();Text("−"+timeLabel(max(0,deck.duration-deck.elapsed)))}.font(.system(size:15,design:.monospaced)).monospacedDigit()
            waveform
            HStack(spacing:20) {jog;tempo}.frame(height:180)
            HStack(spacing:10) {
                Button {search(-1)} label:{Image(systemName:"backward.end.fill").frame(width:34,height:40)}.help("Previous track in the playlist")
                DJHoldButton(title:"CUE",down:{if session.shift {deck.setCue()}else {deck.cueDown()}},up:{deck.cueUp()},enabled:allowed).frame(width:66,height:48).help("Hold to audition from Cue; release to return. SHIFT sets Cue and first beat.")
                Button {deck.toggle()} label:{Image(systemName:deck.playing ? "pause.fill":"play.fill").font(.system(size:23)).frame(width:64,height:48)}.accessibilityLabel("Deck "+deck.name+" Play Pause")
                Button {search(1)} label:{Image(systemName:"forward.end.fill").frame(width:34,height:40)}.help("Next track in the playlist")
                Spacer(minLength:0)
                Toggle("SLIP",isOn:$deck.slip).toggleStyle(.button).help("Hot cues and loops return to the uninterrupted timeline on release or Exit")
            }.buttonStyle(DJButtonStyle(active:deck.playing)).disabled(!allowed || deck.track==nil)
            loopControls
            HStack(spacing:6) {ForEach(0..<8,id:\.self) {index in
                DJHoldButton(title:String(index+1)+(deck.marks.hot[index] == nil ? " +":" ●"),down:{deck.hotDown(index,delete:session.shift)},up:{deck.hotUp()},enabled:allowed && deck.track != nil).frame(height:38)
                    .help("Empty: save Hot Cue. Assigned: play here. SHIFT: delete. Slip: release to return.")
            }}
            stemControls
            if let error=deck.error {Text(error).font(.stage(size:11)).foregroundStyle(.orange).fixedSize(horizontal:false,vertical:true)}
        }.padding(18).frame(maxWidth:.infinity,maxHeight:.infinity,alignment:.top)
            .background(appearance.theme.paint(.panel),in:RoundedRectangle(cornerRadius:16))
            .overlay(RoundedRectangle(cornerRadius:16).stroke(Color(stageHex:appearance.theme.text).opacity(0.14)))
            .popover(isPresented:$ui.browsing) {browser}
            .onChange(of:lock.isLocked) {_,locked in if locked {deck.cueUp();deck.pitchBend(0)}}
            .onChange(of:setup.playbackBlocked) {_,blocked in if blocked {deck.cueUp();deck.pitchBend(0)}}
    }
    private var header:some View {
        HStack {
            Text("DECK "+deck.name).font(.system(size:13,weight:.bold,design:.monospaced))
            Circle().fill(deck.playing ? Color.green:.gray).frame(width:7,height:7)
            Spacer()
            Button("MASTER") {session.master=deck.name}.buttonStyle(DJButtonStyle(active:session.master==deck.name)).help("Use this deck's manually set BPM as the sync reference")
            Button("SYNC") {session.sync(deck)}.buttonStyle(DJButtonStyle(active:deck.synced)).disabled(!allowed || session.master==deck.name).help("Match tempo and phase to Master using the BPM and Cue / first beat you set")
            Button {ui.chosen=deck.track?.id ?? queue.selectedTrack?.id ?? queue.tracks.first?.id;ui.browsing=true} label:{Label("Load",systemImage:"folder")}.buttonStyle(DJButtonStyle()).disabled(!allowed || setup.selectionBlocked)
        }.font(.system(size:10,weight:.semibold)).controlSize(.small)
    }
    private var waveform:some View {
        StageWaveform(identity:deck.track?.id ?? "dj-empty",peaks:deck.track.flatMap {waves.cache[Waveforms.key($0)]?.peaks} ?? [],duration:deck.duration,elapsed:deck.elapsed,gain:1,color:Color(stageHex:appearance.theme.waveColor),enabled:allowed && deck.track != nil,onBegin:{},onFinish:{}) {seconds,_ in deck.seek(seconds)}
            .frame(height:46).accessibilityLabel("DJ Deck "+deck.name+" Waveform").help("Click to seek within this deck")
            .task(id:deck.track.map(Waveforms.key)) {if let track=deck.track {await waves.load(track)}}
    }
    private var jog:some View {
        ZStack {
            Circle().fill(Color(stageHex:appearance.theme.surfaceColor)).overlay(Circle().stroke(Color(stageHex:appearance.theme.text).opacity(0.18),lineWidth:2))
            Circle().stroke(Color(stageHex:appearance.theme.text).opacity(0.12),lineWidth:1).padding(12)
            VStack(spacing:5) {Image(systemName:"waveform").font(.system(size:28));Text(deck.playing ? "PLAYING":"READY").font(.system(size:9,weight:.bold,design:.monospaced));Text("JOG / SEEK").font(.system(size:8,design:.monospaced)).opacity(0.5)}
        }.frame(width:174,height:174).contentShape(Circle())
            .gesture(DragGesture(minimumDistance:2).onChanged {value in guard allowed else {return};let previous=ui.jogX ?? 0;let delta=value.translation.width-previous;ui.jogX=value.translation.width;deck.jog(Double(delta/174))}.onEnded {_ in ui.jogX=nil})
            .help("Drag horizontally to seek. Software jog; no vinyl scratch emulation.")
    }
    private var tempo:some View {
        VStack(alignment:.leading,spacing:8) {
            HStack {Text("BPM");TextField("BPM",value:$deck.marks.bpm,format:.number.precision(.fractionLength(1))).frame(width:58).onSubmit {deck.marks.bpm=min(300,max(40,deck.marks.bpm))};Button("TAP") {tap()}}
            Text(String(format:"%.1f BPM · %+.2f%%",deck.effectiveBPM,deck.pitch)).font(.system(size:11,design:.monospaced))
            Slider(value:$deck.pitch,in:-deck.pitchRange...deck.pitchRange).accessibilityLabel("Deck "+deck.name+" Pitch")
            HStack {Button("0") {if session.shift {let ranges:[Double]=[6,10,16,100];deck.pitchRange=ranges[((ranges.firstIndex(of:deck.pitchRange) ?? 0)+1)%ranges.count]}else {deck.pitch=0}}.help("Reset pitch to zero");Picker("Range",selection:$deck.pitchRange) {Text("±6%").tag(6.0);Text("±10%").tag(10.0);Text("±16%").tag(16.0);Text("±100%").tag(100.0)}.labelsHidden().onChange(of:deck.pitchRange) {_,range in deck.pitch=min(range,max(-range,deck.pitch))}}
            HStack {DJHoldButton(title:"BEND −",down:{deck.pitchBend(-0.025)},up:{deck.pitchBend(0)},enabled:allowed);DJHoldButton(title:"BEND +",down:{deck.pitchBend(0.025)},up:{deck.pitchBend(0)},enabled:allowed)}.frame(height:30)
            Toggle("KEY LOCK",isOn:$deck.keyLock).toggleStyle(.checkbox).help("Preserve pitch when changing tempo. Off uses varispeed.")
        }.font(.system(size:11)).controlSize(.small).disabled(!allowed || deck.track==nil)
    }
    private var loopControls:some View {
        VStack(alignment:.leading,spacing:8) {
            HStack(spacing:8) {
                Button("IN") {deck.markIn()};Button("OUT") {deck.markOut()}
                Button(deck.looping ? "EXIT":"RELOOP") {deck.reloop()}.buttonStyle(DJButtonStyle(active:deck.looping))
                Spacer();Button("−10 ms") {deck.trimLoop(-0.01)};Button("+10 ms") {deck.trimLoop(0.01)}
            }
            HStack(spacing:8) {Text("BEATS").font(.system(size:9,design:.monospaced));ForEach([4,8,16,32],id:\.self) {beats in Button(String(beats)) {deck.autoLoop(beats)}};Spacer();Text(deck.looping ? "LOOP ACTIVE":"").font(.system(size:9,weight:.bold)).foregroundStyle(.green)}
        }.font(.system(size:10,weight:.semibold)).buttonStyle(DJButtonStyle()).disabled(!allowed || deck.track==nil)
    }
    private var stemControls:some View {
        VStack(alignment:.leading,spacing:5) {
            HStack {Toggle("STEMS",isOn:$deck.stems).toggleStyle(.button).disabled(deck.stemNames.count != 4 || !allowed);Text("Load aligned stem files · right-click a pad").font(.system(size:9)).stageSecondary()}
            HStack(spacing:6) {ForEach(Array(["Vocals","Instruments","Drums","Bass"].enumerated()),id:\.offset) {i,title in
                Button(title) {deck.toggleStem(i,solo:session.shift)}.buttonStyle(DJButtonStyle(active:deck.stems && !deck.mutedStems.contains(i))).font(.system(size:10))
                    .contextMenu {Button("Load "+title+" Stem…") {deck.importStem(i)}}
                    .help(deck.stemNames[i] ?? "Right-click to import an aligned stem. No AI separation is bundled.")
                    .disabled(!allowed || deck.track==nil)
            }}
        }
    }
    private var browser:some View {
        VStack(alignment:.leading,spacing:10) {
            HStack {Button("Back") {ui.browsing=false};Text("PLAYLIST → DECK "+deck.name).font(.headline);Spacer()}
            ScrollViewReader {proxy in
                List(selection:$ui.chosen) {ForEach(queue.tracks) {track in Text(track.title).tag(track.id).id(track.id).help(track.title)}}.frame(width:380,height:300)
                    .onChange(of:ui.chosen) {_,id in if let id {proxy.scrollTo(id)}}
            }
            HStack {Button("Previous") {browse(-1)};Button("Next") {browse(1)};Spacer();Button("Load Selected") {if let track=queue.tracks.first(where:{$0.id==ui.chosen}) {deck.load(track);ui.browsing=false}}.disabled(ui.chosen==nil)}
        }.padding(16).stageColorScheme()
    }
    private func browse(_ delta:Int) {guard !queue.tracks.isEmpty else {return};let i=queue.tracks.firstIndex(where:{$0.id==ui.chosen}) ?? 0;ui.chosen=queue.tracks[min(queue.tracks.count-1,max(0,i+delta))].id}
    private func search(_ delta:Int) {guard !queue.tracks.isEmpty else {return};let i=queue.tracks.firstIndex(where:{$0.id==deck.track?.id}) ?? 0;deck.load(queue.tracks[min(queue.tracks.count-1,max(0,i+delta))])}
    private func tap() {let now=ProcessInfo.processInfo.systemUptime;if let last=ui.tapTimes.last,now-last>2 {ui.tapTimes=[]};ui.tapTimes.append(now);ui.tapTimes=Array(ui.tapTimes.suffix(8));if ui.tapTimes.count>1 {deck.marks.bpm=min(300,max(40,60*Double(ui.tapTimes.count-1)/(now-ui.tapTimes[0])))}}
}
struct DJWindowView:View {
    @ObservedObject private var session=DJSession.shared
    @ObservedObject private var appearance=AppearancePreferences.shared
    @ObservedObject private var lock=ControlLock.shared
    @ObservedObject private var setup=SetupLock.shared
    var body:some View {
        VStack(spacing:14) {
            HStack {Text("DJ MODE").font(.system(size:18,weight:.bold,design:.monospaced));Text("Independent decks · Main output").font(.stage(size:11)).stageSecondary();Spacer();Button("Back to Player") {AppDelegate.shared.closeDJ()}.buttonStyle(DJButtonStyle());HintToggleButton(small:true);ControlsLockButton(compact:true,iconOnly:true).frame(width:36,height:36)}.frame(height:40)
            HStack(spacing:16) {DJDeckView(deck:session.a);DJDeckView(deck:session.b)}.opacity(lock.isLocked ? 0.6:1)
            HStack(spacing:14) {
                DJHoldButton(title:"SHIFT",down:{session.shift=true},up:{session.shift=false},enabled:!lock.isLocked).frame(width:70,height:36).help("Hold: Cue sets start / grid, Hot Cue deletes, Stem solos")
                Text("A");Slider(value:$session.crossfade,in:-1...1).frame(maxWidth:340).accessibilityLabel("DJ Crossfader");Text("B")
                Button("Center") {session.crossfade=0};Spacer();Image(systemName:"speaker.wave.2");Slider(value:$session.volume,in:0...1).frame(width:140).accessibilityLabel("DJ Master Volume")
            }.font(.system(size:11)).disabled(lock.isLocked || setup.playbackBlocked)
            Text(session.error ?? "Set BPM and the first beat with SHIFT + CUE before using Sync. Stems use your separate, aligned files. Closing DJ stops both decks.")
                .font(.stage(size:10)).stageSecondary().frame(maxWidth:.infinity,alignment:.leading)
        }.padding(18).foregroundStyle(Color(stageHex:appearance.theme.text)).background(appearance.theme.paint(.background)).stageColorScheme()
            .overlay(alignment:.topTrailing) {PlayerControlsEdge().frame(width:12,height:180).padding(.top,66)}
    }
}

struct DJButtonStyle:ButtonStyle {
    var active=false
    @ObservedObject private var appearance=AppearancePreferences.shared
    @Environment(\.isEnabled) private var enabled
    func makeBody(configuration:Configuration)->some View {
        configuration.label.padding(.horizontal,8).padding(.vertical,6)
            .foregroundStyle(Color(stageHex:appearance.theme.text).opacity(enabled ? 1:0.4))
            .background(appearance.theme.paint(active ? .tape:.surface),in:RoundedRectangle(cornerRadius:7))
            .overlay(RoundedRectangle(cornerRadius:7).stroke(Color(stageHex:appearance.theme.text).opacity(active ? 0.45:0.12)))
            .opacity(configuration.isPressed ? 0.7:1)
    }
}

/// Exercise the native text-rendering path that crashed, across themes and button states.
func checkDJButtonRendering() {
    for name in StageTheme.names {
        let theme=StageTheme.named(name)
        for title in ["CUE","−","+","1 +","8 ●"] {
            for enabled in [false,true] {
                let pad=DJHoldButton.Pad(frame:NSRect(x:0,y:0,width:66,height:48))
                pad.title=title;pad.enabled=enabled;pad.held=enabled
                pad.ink=NSColor(Color(stageHex:theme.text)).usingColorSpace(.sRGB) ?? .labelColor
                pad.fill=NSColor(Color(stageHex:theme.surfaceColor)).usingColorSpace(.sRGB) ?? .controlBackgroundColor
                pad.layoutSubtreeIfNeeded()
                guard let bitmap=pad.bitmapImageRepForCachingDisplay(in:pad.bounds) else {preconditionFailure("DJ button bitmap unavailable")}
                pad.cacheDisplay(in:pad.bounds,to:bitmap)
            }
        }
    }
    print("PASS: DJ native captions render across all themes, enabled/disabled and held states")
}
