import Foundation
import CryptoKit

struct BackupPlayAction:Codable {
    let kind:String
    var index:Int? = nil
    var seconds:Double? = nil
    var valid:Bool {
        ["toggle","pause","play","next","previous","seek"].contains(kind) &&
        (index.map {(0..<10000).contains($0)} ?? true) &&
        (seconds.map {$0.isFinite && (0...604800).contains($0)} ?? true) &&
        (kind != "play" || index != nil) && (kind != "seek" || seconds != nil)
    }
}
struct BackupPlayState:Codable {
    let index:Int
    let seconds:Double
    let playing:Bool
    let crossfading:Bool
    var valid:Bool {(0..<10000).contains(index) && seconds.isFinite && (0...604800).contains(seconds)}
}
struct BackupPlayMessage:Codable {
    let token:UUID
    let sequence:UInt64
    var enabled:Bool? = nil
    var fingerprint:String? = nil
    var action:BackupPlayAction? = nil
    var state:BackupPlayState? = nil
    var sentAt:Double? = nil
    var positionJump:Bool? = nil
    var valid:Bool {(sentAt.map {$0.isFinite && $0>=0} ?? true) && (fingerprint.map {$0.count == 64 && $0.allSatisfy {"0123456789abcdef".contains($0)}} ?? true) && (action?.valid ?? true) && (state?.valid ?? true)}
}
extension BackupSetInput {
    // Runtime positions and selection change during playback. One-shot start points are consumed by playback.
    var playbackConfiguration:String {
        let rows=items.map {[$0.url.path,$0.title,$0.occurrenceID ?? "",$0.fade.rawValue,$0.startPoint.flatMap {$0.once ? nil:String($0.seconds)} ?? ""].joined(separator:"\u{0}")}
        return ([name,options.startMode.rawValue,options.endMode.rawValue,String(options.stopBeforeEnd),String(options.shuffle),String(options.repeatAll),String(options.repeatOne ?? false)]+rows).joined(separator:"\u{1}")
    }
}
extension BackupManifest {
    var playbackFingerprint:String {
        // The manifest was verified before arming; positions must not form part of the live identity.
        let rows=entries.map {[$0.sha256,String($0.bytes),$0.title,$0.fade,$0.startPoint.flatMap {$0.once ? nil:String($0.seconds)} ?? ""].joined(separator:"\u{0}")}
        let data=Data(([name,start,end,String(stopBeforeMS),String(shuffle),String(repeatAll),String(repeatOne ?? false)]+rows).joined(separator:"\u{1}").utf8)
        return SHA256.hash(data:data).map {String(format:"%02x",$0)}.joined()
    }
}
