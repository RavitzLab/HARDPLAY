import Foundation
import Network

private func linkedWave(_ marker:UInt16)->Data {
    var data=Data()
    func txt(_ s:String){data.append(Data(s.utf8))}
    func u16(_ value:UInt16){var v=value.littleEndian;withUnsafeBytes(of:&v){data.append(contentsOf:$0)}}
    func u32(_ value:UInt32){var v=value.littleEndian;withUnsafeBytes(of:&v){data.append(contentsOf:$0)}}
    txt("RIFF");u32(36+320000);txt("WAVEfmt ");u32(16);u16(1);u16(1);u32(16000);u32(32000);u16(2);u16(16);txt("data");u32(320000)
    var samples=Data(count:320000);samples[samples.count-2]=UInt8(marker);data.append(samples);return data
}
@MainActor func runLinkedPlaybackTests() async throws {
    func wait(_ label:String,_ condition:()->Bool) async throws {
        for _ in 0..<300 {if condition(){return};try await Task.sleep(for:.milliseconds(30))}
        throw BackupFailure("Linked Playback timeout: "+label)
    }
    var clock=SyncClockEstimate()
    for i in 0..<8 {let t=Double(i);clock.add(SyncClockSample(sent:t,received:t+10.01,replied:t+10.012,arrived:t+0.022)!)}
    precondition(abs(clock.offset-10)<0.000001 && abs(clock.rtt-0.02)<0.000001 && clock.ready(at:7.1))
    clock.add(SyncClockSample(sent:8,received:18.5,replied:18.502,arrived:9.002)!)
    precondition(abs(clock.offset-10)<0.000001 && !clock.ready(at:9.1) && !clock.ready(at:20))
    precondition(SyncClockSample(sent:3,received:1,replied:0,arrived:4)==nil)
    precondition(SyncClockSample(sent:.nan,received:1,replied:1,arrived:2)==nil)
    print("PASS: monotonic clock offset, RTT, jitter outlier and stale measurement guards")
    let fm=FileManager.default,folder=URL(fileURLWithPath:NSTemporaryDirectory()).appendingPathComponent("hardplay-linked-\(UUID())")
    try fm.createDirectory(at:folder,withIntermediateDirectories:true);defer {try? fm.removeItem(at:folder)}
    let a1=folder.appendingPathComponent("A-1.wav"),a2=folder.appendingPathComponent("A-2.wav"),b1=folder.appendingPathComponent("B-1.wav"),b2=folder.appendingPathComponent("B-2.wav")
    try linkedWave(1).write(to:a1);try linkedWave(2).write(to:a2);try linkedWave(1).write(to:b1);try linkedWave(2).write(to:b2)
    let sa="hardplay.linked.A.\(UUID())",sb="hardplay.linked.B.\(UUID())",da=UserDefaults(suiteName:sa)!,db=UserDefaults(suiteName:sb)!
    defer {da.removePersistentDomain(forName:sa);db.removePersistentDomain(forName:sb)}
    let lockA=SetupLock(defaults:da),lockB=SetupLock(defaults:db)
    let a=Player(defaults:da,remoteCommands:false,setupLock:lockA),b=Player(defaults:db,remoteCommands:false,setupLock:lockB)
    a.volume=0;b.volume=0;a.addPrepared([a1,a2]);b.addPrepared([b1,b2])
    let la=BackupLink(name:"Playback A",canConfigure:{true}),lb=BackupLink(name:"Playback B",canConfigure:{true})
    la.observe(a);lb.observe(b)
    defer {la.disconnect();lb.disconnect();a.pause();b.pause()}
    try await wait("load") {a.canSynchronizeSet && b.canSynchronizeSet}
    try la.host(.primary,advertise:false);try await wait("listen") {la.port != nil}
    lb.connect(.hostPort(host:"127.0.0.1",port:la.port!),code:la.code,role:.backup)
    try await wait("pair") {la.connected && lb.connected && la.peerSupportsPlayback && lb.peerSupportsPlayback}
    try await wait("network timing measured") {la.timingReady && lb.timingReady}
    precondition(la.timingRTT>0 && lb.timingRTT>0)
    // Synchronization alone must retain the default independent playback behavior.
    la.beginSync(.send);try await wait("review") {la.syncReview?.plan.ready == true};la.applySync()
    try await wait("sets ready") {la.verified && lb.verified && a.canSynchronizeSet && b.canSynchronizeSet && !la.syncing && !lb.syncing}
    a.toggle();try await wait("independent A play") {a.playing};try await Task.sleep(for:.milliseconds(250));precondition(!b.playing)
    a.pause();try await Task.sleep(for:.seconds(1.2))
    // Recheck runtime positions after independent playback, then arm both explicitly.
    la.check(a.backupInput());lb.check(b.backupInput())
    try await wait("checks complete") {!la.scanning && !lb.scanning}
    la.beginSync(.send);try await wait("resync review") {la.syncReview?.plan.ready == true};la.applySync()
    try await wait("resync") {la.canEnablePlayback && lb.canEnablePlayback}
    la.setPlaybackLinked(true);try await Task.sleep(for:.milliseconds(100));precondition(!la.linkedPlayback && !lb.linkedPlayback && !a.playing && !b.playing)
    lb.setPlaybackLinked(true);try await wait("both armed") {la.linkedPlayback && lb.linkedPlayback}
    a.toggle();try await wait("Play on A starts both") {a.playing && b.playing && a.elapsed>0.3 && b.elapsed>0.1}
    precondition(abs(a.elapsed-b.elapsed)<0.75)
    lb.autoAlign=true
    try await wait("live position measurements") {lb.timingDriftMS != nil && la.timingDriftMS != nil}
    precondition(lb.timingDriftMS!.isFinite)
    let position=b.elapsed
    b.followLinkedPlayback(.init(index:b.tracks.firstIndex(where:{$0.id==b.currentID})!,seconds:position+1,playing:true,crossfading:false),allowPositionJump:false)
    precondition(abs(b.elapsed-position)<0.15)
    b.correctLinkedRate(errorSeconds:0.1)
    precondition(b.crossfadeDiagnostics.incomingRate>1 && b.crossfadeDiagnostics.incomingRate<=1.0051)
    b.resetLinkedRate();precondition(b.crossfadeDiagnostics.incomingRate==1)
    print("PASS: Auto Align bounds rate correction and never seeks a large offset")
    lb.manualOffsetMS=999;precondition(lb.manualOffsetMS==250);lb.manualOffsetMS=0
    b.toggle();try await wait("Pause on B pauses both") {!a.playing && !b.playing}
    b.toggle();try await wait("Play on B starts both") {a.playing && b.playing}
    b.seek(4);try await wait("seek follows") {a.elapsed>=4 && b.elapsed>=3.7}
    a.next();try await wait("Next on A follows") {a.current?.url == a2 && b.current?.url == b2 && a.playing && b.playing}
    b.previous();try await wait("Previous on B follows") {a.current?.url == a1 && b.current?.url == b1 && a.playing && b.playing}
    try await wait("crossfades complete") {!a.isCrossfading && !b.isCrossfading}
    a.pause();try await wait("pause for B selection") {!b.playing}
    b.selectInQueue(b.tracks[1]);precondition(!a.playing && !b.playing)
    b.toggle();try await wait("B selected cue on explicit Play") {a.current?.url == a2 && b.current?.url == b2 && a.playing && b.playing}
    try await wait("selection fade completes") {!a.isCrossfading && !b.isCrossfading}
    // The follower must use A's shuffle choice, including automatic transitions.
    a.pause();try await wait("pause before mode change") {!b.playing}
    la.setPlaybackLinked(false);try await wait("unlink") {!lb.linkedPlayback}
    a.shuffle=true;a.repeatAll=true;a.setFadeModeForAll(.none)
    try await Task.sleep(for:.seconds(1.2))
    la.beginSync(.send);try await wait("shuffle review") {la.syncReview?.plan.ready == true};la.applySync()
    try await wait("shuffle sync") {la.canEnablePlayback && lb.canEnablePlayback}
    la.setPlaybackLinked(true);lb.setPlaybackLinked(true);try await wait("relink") {la.linkedPlayback && lb.linkedPlayback}
    a.toggle();try await wait("play shuffle") {a.playing && b.playing}
    let previous=a.currentID;a.seek(9.7)
    try await wait("automatic shuffle switch") {a.currentID != previous && a.playing && b.playing && a.tracks.firstIndex(where:{$0.id == a.currentID}) == b.tracks.firstIndex(where:{$0.id == b.currentID})}
    // Locking rejects remote control and disarms rather than bypassing local protection.
    lockB.lock();a.pause();try await wait("lock disarm") {!la.linkedPlayback && !lb.linkedPlayback};lockB.unlock()
    b.pause();try await Task.sleep(for:.seconds(1.2))
    la.check(a.backupInput());lb.check(b.backupInput());try await wait("recheck") {!la.scanning && !lb.scanning}
    la.beginSync(.send);try await wait("final review") {la.syncReview?.plan.ready == true};la.applySync();try await wait("final sync") {la.canEnablePlayback && lb.canEnablePlayback}
    let originalTitle=a.tracks[0].title;a.rename(a.tracks[0],to:"Unverified edit");precondition(!la.canEnablePlayback);a.rename(a.tracks[0],to:originalTitle)
    la.setPlaybackLinked(true);lb.setPlaybackLinked(true);try await wait("final arm") {la.linkedPlayback && lb.linkedPlayback}
    a.toggle();try await wait("playing before disconnect") {a.playing && b.playing}
    lb.disconnect();try await wait("disconnect disables") {!la.connected && !la.linkedPlayback && !lb.linkedPlayback}
    precondition(a.playing && b.playing && !b.linkedFollower && !lb.autoAlign && !lb.timingReady && lb.timingDriftMS==nil)
    // Normal exit must sever the link before pausing the local engine.
    func rearm() async throws {
        a.pause();b.pause();try la.host(.primary,advertise:false);try await wait("exit-test listener") {la.port != nil}
        lb.connect(.hostPort(host:"127.0.0.1",port:la.port!),code:la.code,role:.backup)
        try await wait("exit-test pair") {la.connected && lb.connected}
        try await Task.sleep(for:.seconds(1.2))
        la.beginSync(.send);try await wait("exit-test review") {la.syncReview?.plan.ready == true};la.applySync()
        try await wait("exit-test sync") {la.canEnablePlayback && lb.canEnablePlayback}
        la.setPlaybackLinked(true);lb.setPlaybackLinked(true);try await wait("exit-test armed") {la.linkedPlayback && lb.linkedPlayback}
        a.toggle();try await wait("exit-test playing") {a.playing && b.playing}
    }
    try await rearm();lb.shutdownPlayer();try await wait("Backup exit") {!la.connected && !b.playing};precondition(a.playing)
    try await rearm();la.shutdownPlayer();try await wait("Primary exit") {!lb.connected && !a.playing};precondition(b.playing && !lb.linkedPlayback)
    precondition(!BackupPlayAction(kind:"seek",seconds:.infinity).valid && !BackupPlayAction(kind:"play",index:-1).valid)
    precondition(!BackupPlayState(index:0,seconds:-1,playing:true,crossfading:false).valid)
    print("PASS: real muted AVPlayer/TLS linked Play/Pause from either Mac, seek, Next/Previous, authoritative automatic Shuffle, explicit two-sided arming, locks, no transport on set-sync alone, drift under 750ms on localhost, disconnect preserves local audio; normal exit of either Mac leaves the peer playing; no hardware timecode claim")
}
