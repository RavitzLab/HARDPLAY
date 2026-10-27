import AVFoundation
import AppKit

/// Offline render: no PA output, no changes to the user's set, cue points or preferences.
func checkDJAudio()throws {
    let root=URL(fileURLWithPath:NSTemporaryDirectory()).appendingPathComponent("hardplay-dj-"+UUID().uuidString)
    try FileManager.default.createDirectory(at:root,withIntermediateDirectories:true)
    defer {try? FileManager.default.removeItem(at:root)}
    let suite="hardplay.dj-check."+UUID().uuidString
    let defaults=UserDefaults(suiteName:suite)!
    defer {defaults.removePersistentDomain(forName:suite)}
    let format=AVAudioFormat(standardFormatWithSampleRate:48000,channels:2)!
    func fixture(_ name:String,rate:Double)throws->URL {
        let url=root.appendingPathComponent(name+".wav"),fmt=AVAudioFormat(standardFormatWithSampleRate:rate,channels:2)!
        let file=try AVAudioFile(forWriting:url,settings:fmt.settings)
        let buffer=AVAudioPCMBuffer(pcmFormat:fmt,frameCapacity:AVAudioFrameCount(rate*4))!;buffer.frameLength=buffer.frameCapacity
        for c in 0..<2 {for i in 0..<Int(buffer.frameLength) {buffer.floatChannelData![c][i]=Float(sin(Double(i)*2*Double.pi*440/rate)*0.12)}}
        try file.write(from:buffer);return url
    }
    let first=try fixture("48k",rate:48000),second=try fixture("44k",rate:44100)
    let bytes=try Data(contentsOf:first)
    let engine=AVAudioEngine(),a=DJDeck("A",engine:engine,defaults:defaults,testing:true),b=DJDeck("B",engine:engine,defaults:defaults,testing:true)
    try engine.enableManualRenderingMode(.offline,format:format,maximumFrameCount:1024)
    a.prepareAudio={if !engine.isRunning {try engine.start()}};b.prepareAudio=a.prepareAudio
    a.load(Track(url:first));b.load(Track(url:second))
    precondition(a.track != nil && b.track != nil && abs(a.duration-4)<0.001)
    let output=AVAudioPCMBuffer(pcmFormat:engine.manualRenderingFormat,frameCapacity:1024)!
    func render(_ blocks:Int)throws->Float {
        var peak:Float=0
        for _ in 0..<blocks {
            let status=try engine.renderOffline(1024,to:output)
            precondition(status == .success)
            for c in 0..<Int(output.format.channelCount) {for i in 0..<Int(output.frameLength) {peak=max(peak,abs(output.floatChannelData![c][i]))}}
        }
        a.tick();b.tick();return peak
    }
    a.marks.cue=0.5;a.cueDown();let cuePeak=try render(16)
    precondition(a.playing && cuePeak>0.01 && a.elapsed>=0.5)
    b.load(Track(url:first));b.load(Track(url:second));_ = try render(8)
    a.cueUp();precondition(!a.playing && abs(a.elapsed-0.5)<0.001)
    a.hotDown(0);a.seek(1.2);a.hotDown(0);let hotPeak=try render(8)
    precondition(hotPeak>0.01 && a.marks.hot[0] != nil);a.hotDown(0,delete:true);precondition(a.marks.hot[0]==nil)
    a.pause();a.seek(0.5);a.marks.bpm=120;a.autoLoop(4)
    let loopPeak=try render(120)
    precondition(loopPeak>0.01 && a.looping && a.elapsed>=0.5 && a.elapsed<2.5)
    a.reloop();precondition(!a.looping)
    a.pitch=10;a.keyLock=true;precondition(abs(a.rate-1.1)<0.0001 && abs(a.timePitch.rate-1.1)<0.0001)
    a.keyLock=false;precondition(abs(a.varispeed.rate-1.1)<0.0001)
    a.pitchBend(0.025);precondition(a.rate>1.12);a.pitchBend(0)
    b.play();let mixedPeak=try render(16);precondition(mixedPeak>0.01 && b.playing)
    b.pause()
    for i in 0..<4 {try a.loadStem(i,url:first)}
    a.stems=true;a.play()
    let stemPeak=try render(16);precondition(stemPeak>0.01 && a.stemNames.count==4)
    for i in 0..<4 {a.toggleStem(i)}
    _ = try render(24);let mutedPeak=try render(16);precondition(mutedPeak<0.001)
    a.toggleStem(0,solo:true);precondition(a.mutedStems==Set([1,2,3]))
    let soloPeak=try render(16);precondition(soloPeak>0.01)
    a.stems=false;a.slip=true;a.hotDown(1);a.hotDown(1);_ = try render(8);a.hotUp()
    a.stopImmediately();b.stopImmediately();engine.stop()
    precondition(!a.playing && !b.playing)
    precondition(DJMath.clamp(-10,duration:4)==0 && DJMath.clamp(.nan,duration:4)==0)
    precondition(abs(DJMath.loopEnd(start:1,beats:4,bpm:120,duration:10)-3)<0.001)
    let phase=DJMath.phaseTarget(master:3.25,masterGrid:0,masterBPM:120,local:10.1,grid:0,bpm:120)
    precondition(abs(phase-10.25)<0.001)
    let originalAfter=try Data(contentsOf:first);precondition(originalAfter==bytes)
    a.unload();b.unload()
    print("PASS: DJ offline render 48/44.1 kHz; dual decks; held Cue return; Hot Cue set/play/delete; PCM loop; Key Lock/varispeed; Bend; aligned stem mix/mute/solo; Slip release; phase math; original unchanged")
}