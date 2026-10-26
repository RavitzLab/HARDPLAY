import Foundation

/// Portable metadata only. A remote path is never trusted or used to open a file.
struct BackupSyncMessage:Codable {
    let id:UUID
    let direction:BackupSyncDirection
    var token:UUID? = nil
    var message:String? = nil
    var accepted:Bool? = nil
    var valid:Bool {(message?.utf8.count ?? 0)<=4096}
}
enum BackupSyncDirection:String,Codable {case send,receive}
struct BackupSyncPlan {
    let source:BackupManifest
    let destination:BackupManifest
    /// Source cue -> index in the destination's already loaded queue.
    let localIndices:[Int?]
    let missing:[String]
    let removedCount:Int
    var ready:Bool {source.valid && destination.valid && missing.isEmpty && localIndices.count == source.entries.count}
    static func make(source:BackupManifest,destination:BackupManifest)throws->Self {
        guard source.valid,destination.valid else {throw BackupFailure("Invalid set metadata.")}
        var audio:[String:Int]=[:]
        for (index,entry) in destination.entries.enumerated() {audio[entry.sha256+":"+String(entry.bytes)] = audio[entry.sha256+":"+String(entry.bytes)] ?? index}
        var missing:[String]=[]
        let indices=source.entries.map {entry -> Int? in
            let index=audio[entry.sha256+":"+String(entry.bytes)]
            if index == nil {missing.append(entry.title)}
            return index
        }
        let sourceKeys=Set(source.entries.map {$0.sha256+":"+String($0.bytes)})
        let removed=destination.entries.filter {!sourceKeys.contains($0.sha256+":"+String($0.bytes))}.count
        return .init(source:source,destination:destination,localIndices:indices,missing:missing,removedCount:removed)
    }
}
struct BackupSyncReview:Identifiable {
    let id:UUID
    let direction:BackupSyncDirection
    let plan:BackupSyncPlan
    let sourceName:String
    let destinationName:String
    var title:String {sourceName+" → "+destinationName}
}
struct BackupSyncInventory {
    let input:BackupSetInput
    let manifest:BackupManifest
    let token:UUID
    let stamp:String
}
