import AppKit
import AVFoundation

@MainActor func runWaveformTests() async throws {
    precondition(StageWaveform.WaveView.time(x:-5,width:100,duration:12) == 0)
    precondition(StageWaveform.WaveView.time(x:50,width:100,duration:12) == 6)
    precondition(StageWaveform.WaveView.time(x:120,width:100,duration:12) == 12)
    precondition(StageWaveform.WaveView.time(x:20,width:0,duration:.nan) == 0)
    var gate=WaveformSeekGate()
    gate.begin("one",enabled:false);precondition(!gate.armed)
    gate.begin("one",enabled:true);precondition(gate.advance("one",enabled:true,inside:true))
    gate.cancel();precondition(!gate.armed)
    gate.begin("one",enabled:true);precondition(!gate.advance("two",enabled:true,inside:true))
    gate.begin("one",enabled:true);precondition(!gate.advance("one",enabled:false,inside:true))
    gate.begin("one",enabled:true);precondition(!gate.advance("one",enabled:true,inside:false))
    let permission=WaveformSeekPermission();precondition(!permission.unlocked)
    permission.toggle();precondition(permission.unlocked);permission.begin();permission.lock();precondition(!permission.unlocked)
    permission.toggle();try await Task.sleep(nanoseconds:5_100_000_000);precondition(!permission.unlocked)
    let screen=NSRect(x:0,y:0,width:1440,height:900)
    let frame=EmbeddedPlaylistLayout.frame(current:.init(x:100,y:100,width:520,height:680),visible:screen,tracks:2)
    precondition(frame.width>=600 && frame.height>=824 && screen.contains(frame))
    let large=NSRect(x:0,y:0,width:1000,height:880)
    precondition(EmbeddedPlaylistLayout.frame(current:large,visible:screen,tracks:2) == large)
    let snug=EmbeddedPlaylistLayout.fittedFrame(current:large,visible:screen,height:650)
    precondition(snug.height == 650 && snug.width == large.width && snug.maxY == large.maxY)
    precondition(EmbeddedPlaylistLayout.fittedFrame(current:snug,visible:screen,height:2000).height == screen.height)
    let workspaceScreen=NSRect(x:0,y:0,width:1800,height:1100),owner=NSRect(x:100,y:200,width:600,height:800)
    let neighbors=WorkspaceLayout.frames(main:owner,screen:workspaceScreen,sizes:[.init(width:400,height:600),.init(width:500,height:600)])
    precondition(neighbors.count == 2 && neighbors.allSatisfy {workspaceScreen.contains($0) && !$0.intersects(owner)} && !neighbors[0].intersects(neighbors[1]))
    let cascade=WorkspaceLayout.frames(main:owner,screen:NSRect(x:0,y:0,width:900,height:700),sizes:[.init(width:500,height:600),.init(width:500,height:600)])
    precondition(cascade.allSatisfy {NSRect(x:0,y:0,width:900,height:700).contains($0)})
    let small=NSRect(x:0,y:0,width:1280,height:720)
    let fit=EmbeddedPlaylistLayout.frame(current:frame,visible:small,tracks:2)
    precondition(fit.width>=840 && small.contains(fit))
    let suite="local.hardplay.waveform.\(UUID().uuidString)"
    let defaults=UserDefaults(suiteName:suite)!
    defer {defaults.removePersistentDomain(forName:suite)}
    let protection=SetupLock(defaults:defaults),player=Player(defaults:defaults,remoteCommands:false,setupLock:protection)
    let file=FileManager.default.temporaryDirectory.appendingPathComponent("hardplay-waveform-\(UUID().uuidString).wav")
    defer {try? FileManager.default.removeItem(at:file)}
    let format=AVAudioFormat(standardFormatWithSampleRate:48000,channels:1)!
    do {
        let out=try AVAudioFile(forWriting:file,settings:format.settings)
        let buffer=AVAudioPCMBuffer(pcmFormat:format,frameCapacity:576000)!;buffer.frameLength=576000
        memset(buffer.floatChannelData![0],0,576000*MemoryLayout<Float>.size)
        try out.write(from:buffer)
    }
    let first=Track(url:file,occurrenceID:UUID().uuidString),second=Track(url:file,occurrenceID:UUID().uuidString),third=Track(url:file,occurrenceID:UUID().uuidString)
    player.tracks=[first,second,third];player.volume=0
    func waitLoaded() async throws {
        for _ in 0..<200 {if !player.isLoading {break};try await Task.sleep(nanoseconds:20_000_000)}
        precondition(!player.isLoading && player.error == nil)
    }
    player.load(first,autoplay:false);try await waitLoaded()
    precondition(!player.activeDeckRight && player.deckTrack(right:false)?.id == first.id && player.deckTrack(right:true)?.id == second.id)
    player.selectInQueue(third);precondition(!player.activeDeckRight && player.currentID == first.id)
    player.waveformAction(first,seconds:4,duration:12,play:false)
    precondition(abs(player.elapsed-4)<0.05 && !player.playing)
    player.waveformAction(second,seconds:7,duration:12,play:false)
    precondition(player.currentID == first.id && !player.playing && player.stageRightTime == 0)
    player.waveformAction(second,seconds:9,duration:12,play:true)
    precondition(player.currentID == first.id && !player.playing && player.stageRightTime == 0)
    precondition(Player.startTime("0:47") == 47 && Player.startTime("47") == 47 && Player.startTime("2:03") == 123)
    precondition(Player.startTime("-47") == nil && Player.startTime("1:60") == nil && Player.startTime("nan") == nil)
    protection.protectPlayback=true;protection.lock()
    player.waveformAction(first,seconds:8,duration:12,play:false)
    player.waveformAction(second,seconds:9,duration:12,play:true)
    precondition(player.currentID == first.id && player.stageRightTime == 0)
    protection.unlock()
    player.next(automatic:true);try await waitLoaded();player.pause()
    precondition(player.currentID == second.id && player.elapsed<0.3)
    precondition(player.activeDeckRight && player.deckTrack(right:true)?.id == second.id && player.deckTrack(right:false)?.id == third.id)
    precondition(player.deckLabel(right:false)=="NEXT" && player.deckLabel(right:true)=="NOW")
    player.startTrack(first,at:3);try await waitLoaded()
    precondition(player.currentID == first.id && abs(player.elapsed-3)<0.3)
    player.pause()
    player.load(first,autoplay:false,position:1);try await waitLoaded()
    player.setFadeMode(.short,after:first)
    player.waveformAction(second,seconds:5,duration:12,play:false)
    player.toggle();player.play(second)
    for _ in 0..<200 {if player.isCrossfading {break};try await Task.sleep(nanoseconds:20_000_000)}
    precondition(player.isCrossfading && player.currentID == second.id && player.elapsed<0.5)
    precondition(player.activeDeckRight && player.deckTrack(right:false)?.id == first.id && player.deckTrack(right:true)?.id == second.id)
    precondition(player.deckLabel(right:false)=="OUTGOING" && player.deckLabel(right:true)=="INCOMING")
    precondition(player.deckGain(right:false)>0 && player.deckDuration(right:true)>0)
    precondition(player.moveTrack(third.id,to:0))
    precondition(player.isCrossfading && player.currentID==second.id && player.crossfadeDiagnostics.incomingRate>0)
    player.undoEdit();precondition(player.isCrossfading && player.tracks.map(\.id)==[first.id,second.id,third.id] && player.currentID==second.id)
    player.redoEdit();precondition(player.isCrossfading && player.tracks.first?.id==third.id)
    player.undoEdit();precondition(player.isCrossfading)
    player.waveformAction(first,seconds:2,duration:12,play:false)
    precondition(player.isCrossfading && player.currentID == second.id)
    player.waveformAction(second,seconds:8,duration:12,play:false)
    precondition(!player.isCrossfading && abs(player.elapsed-8)<0.05)
    player.pause()
    player.waveformAction(first,seconds:.nan,duration:12,play:true)
    precondition(!player.isLoading)
    player.play(third);try await waitLoaded();player.pause()
    precondition(!player.activeDeckRight && player.deckTrack(right:false)?.id == third.id && player.deckTrack(right:true)==nil)
    player.load(third,autoplay:false);try await waitLoaded();precondition(!player.activeDeckRight)
    player.repeatAll=true;player.next(automatic:true);try await waitLoaded();player.pause()
    precondition(player.activeDeckRight && player.deckTrack(right:true)?.id == first.id && player.deckTrack(right:false)?.id == second.id)
    let restoredRight=Player(defaults:defaults,remoteCommands:false,setupLock:protection)
    precondition(restoredRight.activeDeckRight && restoredRight.currentID == first.id)
    // Reverse-direction crossfade: the next incoming track must occupy the left deck.
    player.setFadeMode(.short,after:first);player.toggle();player.play(second)
    for _ in 0..<200 {if player.isCrossfading {break};try await Task.sleep(nanoseconds:20_000_000)}
    precondition(player.isCrossfading && !player.activeDeckRight && player.deckTrack(right:false)?.id == second.id && player.deckTrack(right:true)?.id == first.id)
    precondition(player.deckLabel(right:false)=="INCOMING" && player.deckLabel(right:true)=="OUTGOING")
    player.waveformAction(second,seconds:8,duration:12,play:false);player.pause()
    precondition(!player.isCrossfading && !player.activeDeckRight && player.deckTrack(right:true)?.id == third.id)
    let restored=Player(defaults:defaults,remoteCommands:false,setupLock:protection)
    precondition(!restored.activeDeckRight && restored.currentID == second.id)
    // Shuffle must advance from the final queue entry even with Repeat Off.
    player.setRepeat(.off);player.shuffle=true;player.endMode = .next
    for _ in 0..<8 {
        player.load(third,autoplay:false);try await waitLoaded()
        guard let expected=player.nextTrack else {preconditionFailure("Shuffle stopped at last entry")}
        precondition(expected.id != third.id)
        precondition(player.nextTrack?.id == expected.id)
        player.next(automatic:true);try await waitLoaded()
        precondition(player.currentID == expected.id && player.playing)
        player.pause()
    }
    player.shuffle=false
    player.load(third,autoplay:false);try await waitLoaded()
    precondition(player.nextTrack == nil)
    // Saved start points apply to automatic Shuffle and crossfades, not paused preload.
    player.startMode = .beginning
    precondition(player.setStartPoint(second,seconds:4,once:true))
    player.load(second,autoplay:false);try await waitLoaded()
    precondition(player.startPoint(for:second)?.once == true)
    player.play(second);try await waitLoaded();player.pause()
    precondition(abs(player.elapsed-4)<0.3 && player.startPoint(for:second) == nil)
    player.play(second);try await waitLoaded();player.pause();precondition(player.elapsed<0.3)
    for track in player.tracks {precondition(player.setStartPoint(track,seconds:2,once:false))}
    player.shuffle=true
    for _ in 0..<5 {
        player.next(automatic:true);try await waitLoaded();player.pause()
        precondition(abs(player.elapsed-2)<0.3 && player.current.flatMap {player.startPoint(for:$0)}?.once == false)
    }
    player.shuffle=false
    player.load(first,autoplay:false,position:1);try await waitLoaded()
    player.setFadeMode(.short,after:first);player.toggle();try await waitLoaded();player.play(second)
    for _ in 0..<200 {if player.isCrossfading {break};try await Task.sleep(nanoseconds:20_000_000)}
    precondition(player.isCrossfading && abs(player.elapsed-2)<0.5 && player.startPoint(for:second)?.seconds == 2)
    player.pause()
    player.seek(6);player.toggle()
    precondition(player.elapsed>=5.9 && !player.isLoading)
    player.pause()
    let cueSet=file.deletingLastPathComponent().appendingPathComponent("cue-\(UUID().uuidString).hardplay")
    defer {try? FileManager.default.removeItem(at:cueSet)}
    try player.writePlaylist(to:cueSet)
    let savedCues=try SavedPlaylist.read(from:cueSet)
    precondition(savedCues.tracks.allSatisfy {$0.startPoint == TrackStartPoint(seconds:2,once:false)})
    let cueRestored=Player(defaults:defaults,remoteCommands:false,setupLock:protection)
    precondition(cueRestored.tracks.allSatisfy {$0.startPoint?.seconds == 2})
    player.shuffle=true
    let shuffleRestored=Player(defaults:defaults,remoteCommands:false,setupLock:protection)
    precondition(shuffleRestored.shuffle)
    player.shuffle=false
    player.clearStartPoint(second);precondition(player.startPoint(for:second) == nil)
    player.undoEdit();precondition(player.startPoint(for:second)?.seconds == 2)
    print("PASS: alternating physical decks, stable restart/selection, both crossfade directions, NEXT inspection, persistence, waveform time mapping, seek, ignored NEXT clicks and double-clicks, zero-offset automatic/crossfade start, explicit playlist start, protection, continuous shuffle from last entry with Repeat Off, persistent/one-shot start points, saved playlist roundtrip, and embedded playlist sizing")
}
