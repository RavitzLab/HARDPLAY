import AVFoundation
import Foundation
import Combine

@MainActor func checkPlaylistPreviewAudio() async throws {
    checkPreviewInteraction()
    let suite="hardplay.preview-check."+UUID().uuidString,root=URL(fileURLWithPath:NSTemporaryDirectory()).appendingPathComponent("hardplay-preview-"+UUID().uuidString)
    let defaults=UserDefaults(suiteName:suite)!
    defer {defaults.removePersistentDomain(forName:suite);try? FileManager.default.removeItem(at:root)}
    let routing=AudioRouting(defaults:defaults)
    guard routing.outputs.count>=2 else {print("SKIP: physical preview transport requires two connected outputs; routing and gesture checks remain available");return}
    routing.mainUID=routing.outputs[0].id;routing.previewUID=routing.outputs[1].id
    try FileManager.default.createDirectory(at:root,withIntermediateDirectories:true)
    let url=root.appendingPathComponent("silence.wav"),format=AVAudioFormat(standardFormatWithSampleRate:48000,channels:2)!
    do {
        let file=try AVAudioFile(forWriting:url,settings:format.settings)
        let buffer=AVAudioPCMBuffer(pcmFormat:format,frameCapacity:96000)!;buffer.frameLength=96000
        for channel in 0..<2 {for frame in 0..<96000 {buffer.floatChannelData![channel][frame]=0}}
        try file.write(from:buffer)
    }
    let original=try Data(contentsOf:url),track=Track(url:url)
    let audition=MenuPreviewPlayer(routing:routing);audition.volume=0
    defer {audition.stop()}
    guard !ControlLock.shared.isLocked,!SetupLock.shared.playbackBlocked else {throw BackupFailure("Unlock controls for the transport test; no preferences were changed.")}
    audition.togglePlayback(track)
    for _ in 0..<60 {if audition.duration>1.9 && audition.elapsed>0.1 {break};try await Task.sleep(for:.milliseconds(50))}
    precondition(audition.trackID==track.id && audition.playing && audition.duration>1.9 && audition.elapsed>0.1)
    audition.togglePlayback(track);precondition(!audition.playing && audition.trackID==track.id)
    try await Task.sleep(for:.milliseconds(150));let paused=audition.elapsed
    try await Task.sleep(for:.milliseconds(200));precondition(abs(audition.elapsed-paused)<0.04)
    audition.seek(1.1,track:track);try await Task.sleep(for:.milliseconds(200))
    precondition(!audition.playing && abs(audition.elapsed-1.1)<0.05)
    audition.togglePlayback(track)
    var rowEvents=0,timelineEvents=0
    let rowWatch=audition.objectWillChange.sink {rowEvents+=1}
    let timeWatch=audition.timeline.objectWillChange.sink {timelineEvents+=1}
    try await Task.sleep(for:.milliseconds(200));precondition(audition.playing && audition.elapsed>1.2)
    precondition(rowEvents==0 && timelineEvents>0)
    rowWatch.cancel();timeWatch.cancel()
    audition.stop();precondition(audition.trackID==nil && !audition.playing && audition.duration==0 && audition.elapsed==0)
    audition.togglePlayback(track);routing.previewUID=routing.mainUID
    try await Task.sleep(for:.milliseconds(150));precondition(audition.trackID==nil && !audition.playing)
    audition.togglePlayback(track);precondition(audition.trackID==nil) // Never fall through to the Main output.
    let after=try Data(contentsOf:url);precondition(after==original)
    print("PASS: silent AVPlayer audition on separate connected output; Pause retains identity/position; paused seek; Resume; Stop reset; unsafe route change stops/refuses playback; source unchanged; progress does not broadcast playlist-row updates")
}
