import Foundation
import Network

private func syncFixture(_ sample:UInt8)->Data {
    var d=Data()
    func txt(_ s:String){d.append(Data(s.utf8))}
    func u16(_ v:UInt16){var n=v.littleEndian;withUnsafeBytes(of:&n){d.append(contentsOf:$0)}}
    func u32(_ v:UInt32){var n=v.littleEndian;withUnsafeBytes(of:&n){d.append(contentsOf:$0)}}
    txt("RIFF");u32(36+96000);txt("WAVEfmt ");u32(16);u16(1);u16(1);u32(48000);u32(96000);u16(2);u16(16);txt("data");u32(96000)
    var samples=Data(count:96000);samples[samples.count-2]=sample;d.append(samples);return d
}
@MainActor func runSetSyncTests() async throws {
    func wait(_ message:String,_ check:()->Bool) async throws {
        for _ in 0..<200 {if check(){return};try await Task.sleep(for:.milliseconds(50))}
        throw BackupFailure("Timed out: "+message)
    }
    let fm=FileManager.default,folder=URL(fileURLWithPath:NSTemporaryDirectory()).appendingPathComponent("hardplay-set-sync-\(UUID())")
    try fm.createDirectory(at:folder,withIntermediateDirectories:true);defer {try? fm.removeItem(at:folder)}
    let a1=folder.appendingPathComponent("A-local-one.wav"),a2=folder.appendingPathComponent("A-local-two.wav")
    let b1=folder.appendingPathComponent("B-renamed-one.wav"),b2=folder.appendingPathComponent("B-renamed-two.wav"),extra=folder.appendingPathComponent("A-missing-on-B.wav")
    try syncFixture(1).write(to:a1);try syncFixture(2).write(to:a2);try syncFixture(1).write(to:b1);try syncFixture(2).write(to:b2);try syncFixture(3).write(to:extra)
    let aSuite="hardplay.sync.A.\(UUID())",bSuite="hardplay.sync.B.\(UUID())"
    let da=UserDefaults(suiteName:aSuite)!,db=UserDefaults(suiteName:bSuite)!
    defer {da.removePersistentDomain(forName:aSuite);db.removePersistentDomain(forName:bSuite)}
    let setupA=SetupLock(defaults:da),setupB=SetupLock(defaults:db)
    let pa=Player(defaults:da,remoteCommands:false,setupLock:setupA),pb=Player(defaults:db,remoteCommands:false,setupLock:setupB)
    pa.addPrepared([a1,a2]);pb.addPrepared([b2,b1])
    try await wait("initial audio loading") {pa.canSynchronizeSet && pb.canSynchronizeSet}
    let duplicated=pa.duplicate(pa.tracks[0])!;pa.rename(duplicated,to:"Opening copy")
    pa.rename(pa.tracks[0],to:"Opening");pa.rename(pa.tracks[2],to:"Finale")
    pa.setFadeMode(.duration(4.7),after:pa.tracks[0]);pa.setFadeMode(.short,after:pa.tracks[1]);pa.setFadeMode(.none,after:pa.tracks[2])
    precondition(pa.setStartPoint(pa.tracks[1],seconds:0.2,once:false))
    pa.renameSet(to:"A SHOW");pa.startMode = .resume;pa.endMode = .stop;pa.stopBeforeEnd=0.2;pa.shuffle=true
    pb.renameSet(to:"B ORIGINAL");pb.repeatAll=true
    let originalB=pb.backupInput();let originalBTracks=pb.tracks
    let sourceManifest=try await BackupManifest.build(pa.backupInput()),destManifest=try await BackupManifest.build(pb.backupInput())
    let plan=try BackupSyncPlan.make(source:sourceManifest,destination:destManifest)
    precondition(plan.ready && plan.localIndices == [1,1,0] && plan.missing.isEmpty)
    var missingManifest=sourceManifest
    let absent=BackupManifest.Entry(title:"Missing",sha256:String(repeating:"a",count:64),bytes:123,durationMS:1000,fade:"none",positionMS:0)
    missingManifest = .init(version:1,name:"Missing",entries:[absent],start:"beginning",end:"next",stopBeforeMS:0,shuffle:false,repeatAll:false)
    let missingPlan=try BackupSyncPlan.make(source:missingManifest,destination:destManifest);precondition(!missingPlan.ready)
    // Legacy protocol and manifest remain readable, but cannot silently opt into writes.
    let legacy=BackupLink.Packet(version:1,kind:"hello",role:.primary,name:"Old Mac",manifest:nil)
    let legacyDecoded=try JSONDecoder().decode(BackupLink.Packet.self,from:JSONEncoder().encode(legacy));precondition(legacyDecoded.capabilities == nil)
    let la=BackupLink(name:"Mac A",canConfigure:{true}),lb=BackupLink(name:"Mac B",canConfigure:{true})
    la.observe(pa);lb.observe(pb);defer {la.disconnect();lb.disconnect();pa.pause();pb.pause()}
    try la.host(.primary,advertise:false);try await wait("listener") {la.port != nil}
    lb.connect(.hostPort(host:"127.0.0.1",port:la.port!),code:la.code,role:.backup)
    try await wait("TLS pairing") {la.connected && lb.connected && la.peerSupportsSync && lb.peerSupportsSync}
    la.beginSync(.send);try await wait("push review") {la.syncReview != nil}
    precondition(la.syncReview!.plan.ready && pb.backupInput().signature == originalB.signature)
    la.applySync();try await wait("push result") {!la.syncing && !lb.syncing && pb.tracks.count == 3}
    try await wait("destination remains paused") {pb.canSynchronizeSet}
    precondition(pb.playlistName == "A SHOW" && pb.tracks.map(\.title) == pa.tracks.map(\.title))
    precondition(pb.tracks.map(\.url) == [b1,b1,b2] && pb.tracks[0].id != pb.tracks[1].id)
    precondition(pb.fadeMode(after:pb.tracks[0]).seconds == 4.7 && pb.tracks[1].startPoint == pa.tracks[1].startPoint)
    precondition(pb.startMode == .resume && pb.endMode == .stop && pb.stopBeforeEnd == 0.2 && pb.shuffle && !pb.playing)
    try await wait("verified manifests") {la.verified && lb.verified}
    pb.undoEdit();try await wait("undo loading") {pb.canSynchronizeSet}
    precondition(pb.tracks == originalBTracks && pb.playlistName == "B ORIGINAL" && pb.repeatAll && !pb.shuffle && pb.startMode == originalB.options.startMode && pb.endMode == originalB.options.endMode)
    pb.redoEdit();try await wait("redo loading") {pb.canSynchronizeSet};precondition(pb.playlistName == "A SHOW" && pb.tracks.count == 3)
    pb.undoEdit();try await wait("second undo") {pb.canSynchronizeSet}
    pb.renameSet(to:"B IS SOURCE");pb.repeatAll=false;pb.repeatOne=true;pb.rename(pb.tracks[0],to:"B FIRST")
    // Allow edit invalidations to finish before starting another transaction.
    try await Task.sleep(for:.seconds(1.2))
    la.beginSync(.receive);try await wait("pull review") {la.syncReview != nil}
    precondition(la.syncReview!.direction == .receive && la.syncReview!.plan.ready)
    la.applySync();try await wait("pull result") {!la.syncing && !lb.syncing && pa.playlistName == "B IS SOURCE"}
    try await wait("pull paused") {pa.canSynchronizeSet}
    precondition(pa.tracks.map(\.url) == [a2,a1] && pa.repeatOne && !pa.repeatAll && !pa.playing)
    precondition(pa.tracks.map(\.title) == pb.tracks.map(\.title))
    // A destination with missing audio is never partially replaced.
    pa.addPrepared([extra]);try await Task.sleep(for:.seconds(1.2))
    let beforeMissing=pb.backupInput().signature
    la.beginSync(.send);try await wait("missing-audio review") {la.syncReview != nil}
    precondition(!la.syncReview!.plan.ready && la.syncReview!.plan.missing.count == 1)
    la.cancelSync();try await wait("cancel peer") {!lb.syncing}
    precondition(pb.backupInput().signature == beforeMissing)
    // Fill missing media, then lock the destination after review. Commit must reject.
    let b3=folder.appendingPathComponent("B-third.wav");try syncFixture(3).write(to:b3);pb.addPrepared([b3]);try await Task.sleep(for:.seconds(1.2))
    la.beginSync(.send);try await wait("lock review") {la.syncReview?.plan.ready == true}
    let beforeLock=pb.backupInput().signature;setupB.lock();la.applySync()
    try await wait("locked rejection") {!la.syncing && !lb.syncing};precondition(pb.backupInput().signature == beforeLock);setupB.unlock()
    la.beginSync(.send);try await wait("stale review") {la.syncReview?.plan.ready == true}
    pb.rename(pb.tracks[0],to:"Changed after review");let changedSignature=pb.backupInput().signature
    la.applySync();try await wait("stale rejection") {!la.syncing && !lb.syncing};precondition(pb.backupInput().signature == changedSignature)
    // Model-only playing flag: this test never sends actual audio to a device.
    try await Task.sleep(for:.seconds(1.2));pb.playing=true
    la.beginSync(.send);try await wait("playing rejection") {!la.syncing};precondition(la.syncReview == nil);pb.playing=false
    try await Task.sleep(for:.seconds(1.2))
    la.beginSync(.send);try await wait("disconnect review") {la.syncReview?.plan.ready == true}
    let beforeDisconnect=pb.backupInput().signature;lb.disconnect();try await wait("disconnect") {!la.connected}
    precondition(pb.backupInput().signature == beforeDisconnect && !la.syncing)
    let aBytes=try Data(contentsOf:a1),bBytes=try Data(contentsOf:b1);precondition(aBytes == syncFixture(1) && bBytes == syncFixture(1))
    print("PASS: TLS push/pull metadata sync; renamed/reordered local file matching; duplicate cues; titles/fades/start points/Repeat/Shuffle; Undo/Redo; missing audio, lock, stale snapshot, playing peer and disconnect reject without partial writes; original audio preserved; no autoplay")
}
