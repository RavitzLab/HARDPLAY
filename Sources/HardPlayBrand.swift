import AppKit
import SwiftUI
import CoreImage

/// Shared front-facing artwork; the transport keeps its real Play/Pause action.
enum HardPlayBrand {
    static let artwork:NSImage? = wordmark
    // Derive a clean template directly from the supplied artwork, preserving its geometry.
    static let stackedWordmark: NSImage? = {
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
    static let wordmark:NSImage? = stackedWordmark
    private static let logoCache:NSCache<NSString,NSImage> = {let cache=NSCache<NSString,NSImage>();cache.countLimit=64;return cache}()
    static func logo(color:NSColor,size:NSSize,playing:Bool=false,preview:Bool=false)->NSImage {
        let rgb=color.usingColorSpace(.sRGB) ?? color
        let key="\(rgb)-\(size.width)-\(size.height)-\(playing)-\(preview)" as NSString
        if let image=logoCache.object(forKey:key) {return image}
        let image=NSImage(size:size,flipped:false) {_ in
            let bounds=NSRect(origin:.zero,size:size)
            NSColor.clear.setFill();bounds.fill(using:.copy)
            guard let source=wordmark?.copy() as? NSImage else {return false}
            source.isTemplate=false
            let scale=min(size.width/source.size.width,size.height/source.size.height)
            let target=NSRect(x:(size.width-source.size.width*scale)/2,y:(size.height-source.size.height*scale)/2,width:source.size.width*scale,height:source.size.height*scale)
            source.draw(in:target);color.setFill();bounds.fill(using:.sourceIn)
            if playing || preview {
                // The upper Play has clear separation; the lower Play overlaps Y's bounding box.
                for upper in [true,false] {
                    if upper ? !preview:!playing {continue}
                    NSGraphicsContext.saveGraphicsState()
                    let clip=NSBezierPath()
                    if upper {
                        clip.appendRect(NSRect(x:target.minX+252*scale,y:target.minY+230*scale,width:180*scale,height:260*scale))
                    }else {
                        for (index,point) in [(438.0,-36.0),(438.0,236.0),(650.0,106.0)].enumerated() {
                            let p=NSPoint(x:target.minX+point.0*scale,y:target.minY+point.1*scale)
                            if index==0 {clip.move(to:p)}else {clip.line(to:p)}
                        }
                        clip.close()
                    }
                    clip.addClip()
                    source.draw(in:target)
                    NSColor(srgbRed:0.90,green:0.19,blue:0.21,alpha:1).setFill();bounds.fill(using:.sourceIn)
                    NSGraphicsContext.restoreGraphicsState()
                }
            }
            return true
        }
        image.isTemplate=false;logoCache.setObject(image,forKey:key);return image
    }
    static func checkPlayTint() {
        let size=NSSize(width:436,height:239)
        func sample(_ bitmap:NSBitmapImageRep,_ point:(Int,Int))->NSColor {
            bitmap.colorAt(x:Int(Double(point.0)*Double(bitmap.pixelsWide)/436),y:Int(Double(point.1)*Double(bitmap.pixelsHigh)/239))!.usingColorSpace(.sRGB)!
        }
        for main in [false,true] {for preview in [false,true] {
            let image=logo(color:.white,size:size,playing:main,preview:preview)
            let pixels=NSBitmapImageRep(cgImage:image.cgImage(forProposedRect:nil,context:nil,hints:nil)!)
            for (points,active) in [([(150,60),(143,106)],preview), ([(250,179),(300,189)],main)] {
                for point in points {
                    let color=sample(pixels,point)
                    precondition(active ? color.redComponent>0.7 && color.greenComponent<0.4:color.greenComponent>0.8,"Wrong Main / Preview triangle tint")
                }
            }
            for point in [(25,60),(355,210),(225,114)] {let color=sample(pixels,point);precondition(color.alphaComponent>0.8 && color.greenComponent>0.8,"Non-Play letter changed color")}
        }}
        print("PASS: four independent Main / Preview logo states; PLAY triangle follows Main, HARD triangle follows Preview; other letters unchanged")
    }
    static func stackedLogo(color:NSColor,size:NSSize)->NSImage {
        NSImage(size:size,flipped:false) {_ in
            let bounds=NSRect(origin:.zero,size:size)
            NSColor.clear.setFill();bounds.fill(using:.copy)
            guard let source=stackedWordmark?.copy() as? NSImage else {return false}
            source.isTemplate=false
            let scale=min(size.width/source.size.width,size.height/source.size.height)
            let target=NSRect(x:(size.width-source.size.width*scale)/2,y:(size.height-source.size.height*scale)/2,width:source.size.width*scale,height:source.size.height*scale)
            source.draw(in:target)
            color.setFill();bounds.fill(using:.sourceIn)
            return true
        }
    }
    static func appIcon(playing:Bool,preview:Bool=false)->NSImage {
        NSImage(size:NSSize(width:1024,height:1024),flipped:false) {_ in
            let rect=NSRect(x:64,y:64,width:896,height:896)
            NSColor(calibratedWhite:0.96,alpha:1).setFill()
            let caseShape=NSBezierPath(roundedRect:rect,xRadius:196,yRadius:196);caseShape.fill()
            NSColor(calibratedWhite:0.82,alpha:1).setStroke();caseShape.lineWidth=4;caseShape.stroke()
            let ink=NSColor(calibratedRed:0.09,green:0.17,blue:0.30,alpha:1)
            logo(color:ink,size:NSSize(width:704,height:386),playing:playing,preview:preview).draw(in:NSRect(x:160,y:319,width:704,height:386))
            return true
        }
    }
    static let idleIcon=appIcon(playing:false)
    static let playingIcon=appIcon(playing:true)
    static let previewIcon=appIcon(playing:false,preview:true)
    static let bothIcon=appIcon(playing:true,preview:true)
    static func statusIcon(playing:Bool,preview:Bool)->NSImage {playing ? (preview ? bothIcon:playingIcon):(preview ? previewIcon:idleIcon)}
    static func menuIcon(playing:Bool,preview:Bool=false)->NSImage {
        let ink=NSColor.labelColor.usingColorSpace(.sRGB) ?? .black
        let image=logo(color:ink,size:NSSize(width:38,height:22),playing:playing,preview:preview)
        image.isTemplate = !playing && !preview
        image.accessibilityDescription="Main: \(playing ? "Playing":"Paused") · Preview: \(preview ? "Playing":"Paused")"
        return image
    }

}
struct SuppliedHardPlayWordmark: View {
    @ObservedObject private var appearance=AppearancePreferences.shared
    @ObservedObject private var player=Player.shared
    @ObservedObject private var preview=MenuPreviewPlayer.shared
    var body: some View {
        Image(nsImage:HardPlayBrand.logo(color:NSColor(Color(stageHex:appearance.theme.text)),size:NSSize(width:160,height:88),playing:player.playing,preview:preview.playing))
            .renderingMode(.original).resizable().interpolation(.high).aspectRatio(contentMode:.fit)
            .accessibilityLabel("Hard Play logo").accessibilityValue("Main: \(player.playing ? "Playing":"Paused") · Preview: \(preview.playing ? "Playing":"Paused")")
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
        let size = min(AppearancePreferences.shared.theme.layoutButtonSize,limit ?? .greatestFiniteMagnitude)
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
