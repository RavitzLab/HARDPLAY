import Foundation
import AVFoundation

@MainActor func runClipTests() async throws {
    precondition(ClipRange.parse("1:02.125") == 62.125 && ClipRange.parse("0:00,250") == 0.25)
    for bad in ["", "NaN", "-1", "1:99", "1::2", "0:60", "Infinity"] {precondition(ClipRange.parse(bad) == nil)}
    let fm=FileManager.default,folder=URL(fileURLWithPath:NSTemporaryDirectory()).appendingPathComponent("hardplay-clip-\(UUID().uuidString)",isDirectory:true)
    try fm.createDirectory(at:folder,withIntermediateDirectories:true);defer {try? fm.removeItem(at:folder)}
    let source=folder.appendingPathComponent("source.wav"),clip=folder.appendingPathComponent("clip.wav")
    let format=AVAudioFormat(standardFormatWithSampleRate:48000,channels:2)!
    do {
        let out=try AVAudioFile(forWriting:source,settings:[AVFormatIDKey:kAudioFormatLinearPCM,AVSampleRateKey:48000,AVNumberOfChannelsKey:2,AVLinearPCMBitDepthKey:32,AVLinearPCMIsFloatKey:true])
        let buffer=AVAudioPCMBuffer(pcmFormat:format,frameCapacity:48000)!
        buffer.frameLength=48000
        for i in 0..<48000 {buffer.floatChannelData![0][i]=Float(i)/96000;buffer.floatChannelData![1][i] = -Float(i)/96000}
        try out.write(from:buffer)
    }
    let silentEdges=folder.appendingPathComponent("silence-edges.wav")
    do {
        let out=try AVAudioFile(forWriting:silentEdges,settings:format.settings)
        let b=AVAudioPCMBuffer(pcmFormat:format,frameCapacity:48000)!;b.frameLength=48000
        for i in 0..<48000 {b.floatChannelData![0][i]=0;b.floatChannelData![1][i]=(i>=9600 && i<38400 && !(i>=18000 && i<24000)) ? 0.25:0}
        try out.write(from:b)
    }
    let edges=try EdgeSilence.detect(silentEdges)
    precondition(edges.removable && abs(edges.leading-0.18)<0.00001 && abs(edges.trailing-0.18)<0.00001)
    let edgeCopy=folder.appendingPathComponent("trimmed-edges.wav");try ClipExport.write(source:silentEdges,range:edges.keep!,to:edgeCopy)
    let edgeFile=try AVAudioFile(forReading:edgeCopy);precondition(edgeFile.length == 30720)
    let silent=folder.appendingPathComponent("silent.wav")
    do {let out=try AVAudioFile(forWriting:silent,settings:format.settings);let b=AVAudioPCMBuffer(pcmFormat:format,frameCapacity:4800)!;b.frameLength=4800;for i in 0..<4800 {b.floatChannelData![0][i]=0;b.floatChannelData![1][i]=0};try out.write(from:b)}
    let empty=try EdgeSilence.detect(silent);precondition(empty.keep == nil && !empty.removable)
    let noEdges=try EdgeSilence.detect(source);precondition(!noEdges.removable)
    let customFade=FadeMode.duration(4.7),encodedFade=try JSONEncoder().encode(customFade)
    precondition(customFade.seconds == 4.7 && FadeMode.duration(0) == .none && FadeMode.standard.seconds == 2)
    let decodedFade=try JSONDecoder().decode(FadeMode.self,from:encodedFade);precondition(decodedFade == customFade)
    let oldFade=try JSONDecoder().decode(FadeMode.self,from:Data("\"short\"".utf8));precondition(oldFade == .short)
    precondition(FadeMode(rawValue:"seconds:nan") == nil && FadeMode(rawValue:"seconds:31") == nil)
    var pieces=EditorClipSelection(clips:[EditorClip(range:.init(start:0,end:1))])
    pieces.select(.init(start:0.125,end:0.25),add:false);pieces.select(.init(start:0.5,end:0.625),add:true)
    precondition(pieces.ranges == [.init(start:0.125,end:0.25),.init(start:0.5,end:0.625)])
    let joined=folder.appendingPathComponent("joined.wav")
    try ClipExport.write(source:source,ranges:pieces.ranges,to:joined)
    let joinedFile=try AVAudioFile(forReading:joined),joinedBuffer=AVAudioPCMBuffer(pcmFormat:format,frameCapacity:12000)!
    try joinedFile.read(into:joinedBuffer)
    precondition(joinedFile.length == 12000 && abs(joinedBuffer.floatChannelData![0][6000]-0.25)<0.000001)
    precondition(abs(joinedBuffer.floatChannelData![1][11999]+Float(29999)/96000)<0.000001)
    _=pieces.choose(at:0.18,add:true);precondition(pieces.ranges == [.init(start:0.5,end:0.625)])
    _=pieces.choose(at:1,add:false);precondition(pieces.ranges.last?.end == 1)
    var viewport=TimelineViewport(duration:120)
    viewport.setZoom(4,anchorFraction:0.25);precondition(viewport.length == 30 && viewport.time(at:0.25) == 30)
    viewport.pan(999);precondition(viewport.start == 90);viewport.pan(-5);precondition(viewport.start == 0)
    viewport.setZoom(999);precondition(viewport.zoom == 256);viewport.setZoom(0);precondition(viewport.zoom == 1 && viewport.start == 0)
    let envelope=try EditorWaveform.peaks(url:source,range:.init(start:0.125,end:0.375),bins:256)
    precondition(envelope.count == 256 && envelope.max()!>0 && envelope.max()!<=1)
    var mainPlaying=false
    let audition=QuickEditModel(Track(url:source),mainIsPlaying:{mainPlaying});audition.previewVolume=0;await audition.prepare()
    audition.setStart(0.1);let preservedRange=audition.range;await audition.prepare();precondition(audition.range == preservedRange)
    audition.hover(0.2);audition.tickPreview(option:true,focused:true,active:true);precondition(audition.auditioning)
    audition.tickPreview(option:false,focused:true,active:true);precondition(!audition.playing)
    audition.tickPreview(option:true,focused:false,active:true);precondition(!audition.playing)
    audition.tickPreview(option:true,focused:true,active:true);mainPlaying=true;audition.tickPreview(option:true,focused:true,active:true);precondition(!audition.playing)
    mainPlaying=false;audition.hover(nil);audition.tickPreview(option:true,focused:true,active:true);precondition(!audition.playing);audition.close()
    let original=try BackupManifest.hashFile(source)
    let range=ClipRange(start:0.125,end:0.375)
    try ClipExport.write(source:source,range:range,to:clip)
    let file=try AVAudioFile(forReading:clip)
    precondition(file.length == 12000 && file.processingFormat.channelCount == 2 && file.processingFormat.sampleRate == 48000)
    let buffer=AVAudioPCMBuffer(pcmFormat:file.processingFormat,frameCapacity:12000)!
    try file.read(into:buffer)
    precondition(abs(buffer.floatChannelData![0][0]-0.0625)<0.000001)
    precondition(abs(buffer.floatChannelData![1][11999]+Float(17999)/96000)<0.000001)
    precondition(tryHash(source) == original.0)
    func mustFail(_ block:()throws->Void)throws {do {try block()}catch{return};throw BackupFailure("Invalid edit unexpectedly succeeded")}
    try mustFail {try ClipExport.write(source:source,range:range,to:source)}
    try mustFail {try ClipExport.write(source:source,range:range,to:clip)}
    try mustFail {try ClipExport.write(source:source,range:ClipRange(start:0.8,end:0.2),to:folder.appendingPathComponent("bad.wav"))}
    try mustFail {try ClipExport.write(source:source,range:ClipRange(start:0,end:99),to:folder.appendingPathComponent("bad.wav"))}
    let cancelled=folder.appendingPathComponent("cancelled.wav")
    let job=Task.detached {while !Task.isCancelled {await Task.yield()};try ClipExport.write(source:source,range:range,to:cancelled,progress:{_ in})};job.cancel()
    do {try await job.value;throw BackupFailure("Cancelled edit unexpectedly succeeded")}catch is CancellationError {}
    precondition(!fm.fileExists(atPath:cancelled.path))
    let suite="local.hardplay.clip-test.\(UUID().uuidString)",prefs=UserDefaults(suiteName:suite)!
    defer {prefs.removePersistentDomain(forName:suite)}
    let protection=SetupLock(defaults:prefs),player=Player(defaults:prefs,remoteCommands:false,setupLock:protection)
    player.addPrepared([source]);let track=player.tracks[0];player.setFadeMode(.long,after:track)
    let copy=try player.applyEditedClip(track,file:clip,replace:false)
    precondition(player.tracks.count == 2 && copy.id != track.id && player.currentID == track.id && !player.playing && player.fadeMode(after:copy) == .long)
    precondition(MappedAction(rawValue:"track:"+copy.id).valid)
    let replacement=try player.applyEditedClip(track,file:clip,replace:true)
    precondition(replacement.id == track.id && replacement.url == clip && !player.playing)
    let set=folder.appendingPathComponent("Edited.hardplay");try player.writePlaylist(to:set)
    let saved=try SavedPlaylist.read(from:set);precondition(saved.tracks[0].identity == track.id)
    let isolated=UserDefaults(suiteName:suite+".restore")!;defer {isolated.removePersistentDomain(forName:suite+".restore")}
    let restored=Player(defaults:isolated,remoteCommands:false);try restored.readPlaylist(from:set)
    precondition(restored.tracks[0].id == track.id && restored.tracks[0].url == clip)
    player.undoEdit();precondition(player.tracks[0].url == source && player.tracks[0].id == track.id)
    player.redoEdit();precondition(player.tracks[0].url == clip && player.tracks[0].id == track.id)
    protection.lock();try mustFail {_ = try player.applyEditedClip(replacement,file:source,replace:true)};protection.unlock()
    let title=QuickEditModel(track);title.duration=1.00049;title.end=1.00049;title.updateText();precondition(title.commitText() && title.end == 1.00049)
    title.duration=1.0/48000;title.end=title.duration;title.updateText();precondition(title.commitText() && title.end == title.duration)
    title.duration=1;title.end=1;title.updateText()
    title.inText="0:00.200";title.outText="0:00.800";precondition(title.commitText() && title.range == ClipRange(start:0.2,end:0.8))
    player.setFadeModeForAll(customFade);try player.writePlaylist(to:set);try restored.readPlaylist(from:set)
    precondition(restored.tracks.allSatisfy {restored.fadeMode(after:$0) == customFade})
    print("PASS: edge-silence streaming scan, stereo sound, internal silence preserved, all-silent/no-edge cases, trimmed WAV, custom crossfade/legacy decoding and playlist roundtrip")
    print("PASS: exact stereo sample trim, sample rate, WAV length, original hash unchanged, overwrite protection, invalid ranges, cancellation cleanup, copy/replace identities, fade, Undo/Redo, playlist persistence, setup lock precise time fields, noncontiguous join samples, clip selection/splitting, zoom/pan bounds, detailed waveform and Option audition safety")
}
private func tryHash(_ url:URL)->String {(try? BackupManifest.hashFile(url).0) ?? ""}
