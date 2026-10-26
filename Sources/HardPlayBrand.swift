import AppKit
import SwiftUI
import CoreImage

/// Shared front-facing artwork; the transport keeps its real Play/Pause action.
enum HardPlayBrand {
    static let artwork:NSImage? = wordmark
    // Derive a clean template directly from the supplied artwork, preserving its geometry.
    static let wordmark: NSImage? = {
        guard let url=Bundle.main.url(forResource:"HardPlayWordmark",withExtension:"png"),
              let source=CIImage(contentsOf:url) else {return nil}
        let bounds=source.extent
        let crop=CGRect(x:bounds.width * 0.148,y:bounds.height * 0.322,
                        width:bounds.width * 0.695,height:bounds.height * 0.381)
        let mask=source.cropped(to:crop).applyingFilter("CIMaskToAlpha")
        guard let cg=CIContext().createCGImage(mask,from:crop) else {return nil}
        let image=NSImage(cgImage:cg,size:crop.size)
        image.isTemplate=true
        return image
    }()
    static func logo(color:NSColor,size:NSSize)->NSImage {
        NSImage(size:size,flipped:false) {_ in
            let bounds=NSRect(origin:.zero,size:size)
            NSColor.clear.setFill();bounds.fill(using:.copy)
            guard let source=wordmark?.copy() as? NSImage else {return false}
            source.isTemplate=false
            let scale=min(size.width/source.size.width,size.height/source.size.height)
            let target=NSRect(x:(size.width-source.size.width*scale)/2,y:(size.height-source.size.height*scale)/2,width:source.size.width*scale,height:source.size.height*scale)
            source.draw(in:target)
            color.setFill();bounds.fill(using:.sourceIn)
            return true
        }
    }
    static func appIcon(playing:Bool)->NSImage {
        NSImage(size:NSSize(width:1024,height:1024),flipped:false) {_ in
            let rect=NSRect(x:64,y:64,width:896,height:896)
            NSColor(calibratedWhite:0.96,alpha:1).setFill()
            let caseShape=NSBezierPath(roundedRect:rect,xRadius:196,yRadius:196);caseShape.fill()
            NSColor(calibratedWhite:0.82,alpha:1).setStroke();caseShape.lineWidth=4;caseShape.stroke()
            let ink=playing ? NSColor(calibratedRed:0.76,green:0.15,blue:0.19,alpha:1):NSColor(calibratedRed:0.09,green:0.17,blue:0.30,alpha:1)
            logo(color:ink,size:NSSize(width:704,height:386)).draw(in:NSRect(x:160,y:319,width:704,height:386))
            return true
        }
    }
    static let idleIcon=appIcon(playing:false)
    static let playingIcon=appIcon(playing:true)
    static func menuIcon(playing:Bool)->NSImage {
        let image=logo(color:playing ? .systemRed:.black,size:NSSize(width:38,height:22))
        image.isTemplate = !playing
        image.accessibilityDescription=playing ? "Hard Play — Playing":"Hard Play — Paused"
        return image
    }

}
struct SuppliedHardPlayWordmark: View {
    var body: some View {
        if let image=HardPlayBrand.wordmark {
            Image(nsImage:image).renderingMode(.template).resizable()
                .interpolation(.high).aspectRatio(contentMode:.fit)
                .accessibilityLabel("Hard Play logo")
        }
    }
}
struct HardPlayArtwork: View {
    var body: some View {
        if let artwork = HardPlayBrand.artwork {
            Image(nsImage:artwork).resizable().interpolation(.high).aspectRatio(contentMode:.fit).accessibilityHidden(true)
        } else {
            VStack(spacing:0) { Text("Hard"); Text("Play") }.font(.stage(size:15,weight:.black)).foregroundStyle(.white)
                .frame(maxWidth:.infinity,maxHeight:.infinity).background(accent,in:RoundedRectangle(cornerRadius:10))
        }
    }
}
struct HardPlayTransport: View {
    @ObservedObject var appearance = AppearancePreferences.shared
    let playing: Bool
    let compact: Bool
    var limit:CGFloat? = nil
    var body: some View {
        let size = min(AppearancePreferences.shared.theme.buttonSize,limit ?? .greatestFiniteMagnitude)
        MarkerIcon(systemName:playing ? "pause.fill":"play.fill",size:size*0.42)
            .font(.stage(size:size * 0.4,weight:.bold)).foregroundStyle(Color(stageHex:AppearancePreferences.shared.theme.text))
            .offset(x:playing ? 0:1)
            .frame(width:size,height:size)
            .background(accent.opacity(playing ? 0.14:0.075),in:Circle())
            .overlay(Circle().stroke(accent.opacity(0.42),lineWidth:1))
            .shadow(color:.black.opacity(0.10),radius:1,y:0.5)
            .accessibilityHidden(true)
    }
}
struct HardPlayPressStyle: ButtonStyle {
    func makeBody(configuration:Configuration) -> some View {
        configuration.label.contentShape(RoundedRectangle(cornerRadius:16))
            .scaleEffect(configuration.isPressed ? 0.98:1)
            .brightness(configuration.isPressed ? -0.08:0)
            .animation(.easeOut(duration:0.1),value:configuration.isPressed)
    }
}
