import SwiftUI
final class CrossfadeControlState:ObservableObject {@Published var open=false;@Published var seconds:Double = 2}
struct CrossfadeControl:View {
    @ObservedObject var player:Player
    var iconOnly=false
    var small=false
    @ObservedObject private var setup=SetupLock.shared
    @ObservedObject private var lock=ControlLock.shared
    @StateObject private var ui=CrossfadeControlState()
    private var track:Track? {player.current ?? player.selectedTrack ?? player.tracks.first}
    var body:some View {
        Button {ui.seconds=track.map {player.fadeMode(after:$0).seconds}.flatMap {$0>0 ? $0:nil} ?? 2;ui.open.toggle()} label:{Group {if iconOnly {CrossfadeArrows().stroke(style:StrokeStyle(lineWidth:1.8,lineCap:.round,lineJoin:.round)).frame(width:18,height:18).frame(width:small ? 24:32,height:small ? 32:34)}else {HStack(spacing:5) {CrossfadeArrows().stroke(style:StrokeStyle(lineWidth:1.8,lineCap:.round,lineJoin:.round)).frame(width:18,height:18);Text("Fade")}.font(.stage(size:11)).padding(7)}}}
            .buttonStyle(PlayerControlStyle(active:ui.open)).accessibilityLabel("Crossfade Settings")
            .stageHint("Choose 0–30 seconds · apply to this transition or the whole playlist")
            .popover(isPresented:$ui.open) {
                VStack(alignment:.leading,spacing:12) {
                    Text("CROSSFADE").font(.stage(size:14))
                    HStack {Text("Duration").font(.stage(size:12));Spacer();Text(ui.seconds == 0 ? "Off":String(format:"%.1f s",ui.seconds)).font(.system(size:22,weight:.semibold,design:.monospaced)).foregroundStyle(accent)}
                    Slider(value:Binding(get:{ui.seconds},set:{ui.seconds=($0*10).rounded()/10}),in:0...30).tint(accent).accessibilityLabel("Crossfade Duration Seconds")
                    HStack(spacing:8) {ForEach([0.0,2,3,6],id:\.self) {seconds in
                        Button {ui.seconds=seconds} label:{Text(seconds == 0 ? "Off":String(format:"%g s",seconds)).font(.stage(size:12)).frame(maxWidth:.infinity).padding(.vertical,8)}.buttonStyle(PlayerControlStyle(active:ui.seconds == seconds))
                    }}
                    Button {if let track {player.setFadeMode(.duration(ui.seconds),after:track)};ui.open=false} label:{Label("Apply to This Transition",systemImage:"arrow.right").font(.stage(size:12)).frame(maxWidth:.infinity,alignment:.leading).padding(10)}.buttonStyle(PlayerControlStyle(primary:true)).disabled(track == nil)
                    Button {player.setFadeModeForAll(.duration(ui.seconds));ui.open=false} label:{Label("Apply to Entire Playlist",systemImage:"square.stack").font(.stage(size:12)).frame(maxWidth:.infinity,alignment:.leading).padding(10)}.buttonStyle(PlayerControlStyle()).disabled(player.tracks.isEmpty)

                }.padding(16).frame(width:280).background(ThemedBackdrop())
            }.disabled(setup.editsBlocked || lock.isLocked)
            .onChange(of:lock.isLocked) {_,locked in if locked {ui.open=false}}
    }
}

/// Shuffle-like crossing routes with opposing arrow directions.
struct CrossfadeArrows:Shape {
    func path(in rect:CGRect)->Path {
        var p=Path()
        func point(_ x:CGFloat,_ y:CGFloat)->CGPoint {CGPoint(x:rect.minX+x*rect.width/24,y:rect.minY+y*rect.height/24)}
        p.move(to:point(3,5));p.addCurve(to:point(21,19),control1:point(10,5),control2:point(14,19))
        p.move(to:point(17,15));p.addLine(to:point(21,19));p.addLine(to:point(17,23))
        p.move(to:point(21,5));p.addCurve(to:point(3,19),control1:point(14,5),control2:point(10,19))
        p.move(to:point(7,15));p.addLine(to:point(3,19));p.addLine(to:point(7,23))
        return p
    }
}
