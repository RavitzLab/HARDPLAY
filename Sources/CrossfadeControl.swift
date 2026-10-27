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
        Button {ui.seconds=track.map {player.fadeMode(after:$0).seconds}.flatMap {$0>0 ? $0:nil} ?? 2;ui.open.toggle()} label:{Group {if iconOnly {CrossfadeArrows().fill(.foreground).frame(width:18,height:18).frame(width:small ? 24:32,height:small ? 32:34)}else {HStack(spacing:5) {CrossfadeArrows().fill(.foreground).frame(width:18,height:18);Text("Fade")}.font(.stage(size:11)).padding(7)}}}
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

/// Two waveform banks and a dashed join, drawn as a tiny theme-tinted vector.
struct CrossfadeArrows:Shape {
    func path(in rect:CGRect)->Path {
        var p=Path()
        let heights:[CGFloat]=[5,10,18,11,6,6,11,18,10,5]
        for (i,h) in heights.enumerated() {
            let x=CGFloat(i)*2.25+(i>=5 ? 1.5:0)
            p.addRoundedRect(in:CGRect(x:rect.minX+x*rect.width/24,y:rect.midY-h*rect.height/48,width:1.5*rect.width/24,height:h*rect.height/24),cornerSize:CGSize(width:0.6,height:0.6))
        }
        for y in stride(from:CGFloat(0),through:22,by:4) {p.addRoundedRect(in:CGRect(x:rect.midX-rect.width/48,y:rect.minY+y*rect.height/24,width:rect.width/24,height:rect.height/12),cornerSize:CGSize(width:0.4,height:0.4))}
        return p
    }
}
