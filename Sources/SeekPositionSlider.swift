import SwiftUI

/// Pointer inspection is read-only; only the slider's editing callback seeks.
final class SeekHoverState: ObservableObject { @Published var x: CGFloat?;@Published var editing=false }
enum SeekTime {
    static func seconds(x:CGFloat,width:CGFloat,duration:Double)->Double {
        guard duration.isFinite,duration>0 else{return 0}
        return Double(min(1,max(0,(x-6)/max(1,width-12))))*duration
    }
    static func label(_ seconds:Double)->String {
        let n=Int(min(Double(Int.max/2),max(0,seconds.isFinite ? seconds:0)))
        return String(format:"%02d:%02d",n/60,n%60)
    }
}

struct SeekPositionSlider: View {
    @ObservedObject var appearance = AppearancePreferences.shared
    @Binding var value: Double
    let duration: Double
    var onEditingChanged: (Bool) -> Void
    @Environment(\.isEnabled) private var enabled
    @StateObject private var hover = SeekHoverState()
    private var validDuration: Bool { duration.isFinite && duration > 0 }
    var body: some View {
        GeometryReader { geometry in
            Slider(value:$value,in:0...max(validDuration ? duration:0,1),onEditingChanged:{editing in
                hover.editing=editing
                if !editing {hover.x=nil}
                onEditingChanged(editing)
            })
                .controlSize(.mini).tint(accent).accessibilityLabel("Playback Position")
                .overlay(alignment:.topLeading) {
                    if enabled,validDuration,hover.editing || hover.x != nil {
                        let x=hover.editing ? 6+CGFloat(min(1,max(0,value/duration)))*max(1,geometry.size.width-12):(hover.x ?? 6)
                        let seconds=hover.editing ? value:SeekTime.seconds(x:x,width:geometry.size.width,duration:duration)
                        VStack(spacing:2) {
                            Text("SEEK TO · MIN:SEC").font(.system(size:8,weight:.medium))
                            Text(SeekTime.label(seconds)).font(.system(size:12,weight:.semibold,design:.monospaced)).monospacedDigit()
                        }.foregroundStyle(.white)
                            .padding(.horizontal,8).padding(.vertical,5)
                            .background(Color(red:0.08,green:0.14,blue:0.22).opacity(0.98),in:RoundedRectangle(cornerRadius:6))
                            .overlay(RoundedRectangle(cornerRadius:6).stroke(accent.opacity(0.5),lineWidth:1))
                            .fixedSize().position(x:min(max(57,x),max(57,geometry.size.width-57)),y:-22)
                            .allowsHitTesting(false).accessibilityHidden(true)
                    }
                }
                .onContinuousHover { phase in
                    switch phase {
                    case .active(let point): hover.x=point.x
                    case .ended: hover.x=nil
                    }
                }
                .onChange(of:enabled) { _,active in if !active { hover.x=nil;hover.editing=false } }
                .onChange(of:duration) {_,_ in hover.x=nil;hover.editing=false}
        }.frame(height:16)
    }
}
