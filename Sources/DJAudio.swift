import AppKit
import AVFoundation
import CoreAudio
import Combine

/// Streaming decks; PCM is cached only for an active loop (at most 60 seconds).
enum DJMath {
    static func clamp(_ seconds:Double,duration:Double)->Double {seconds.isFinite ? min(max(0,seconds),max(0,duration-0.001)):0}
    static func loopEnd(start:Double,beats:Int,bpm:Double,duration:Double)->Double {min(duration,start+Double(beats)*60/max(40,bpm))}
    static func phaseTarget(master:Double,masterGrid:Double,masterBPM:Double,local:Double,grid:Double,bpm:Double)->Double {
        let masterBeat=(master-masterGrid)*masterBPM/60
        let localBeat=(local-grid)*bpm/60
        let nearest=(localBeat-masterBeat).rounded()+masterBeat
        return grid+nearest*60/bpm
    }
}
struct DJMarks:Codable {
    var cue:Double=0
    var grid:Double=0
    var bpm:Double=120
    var hot:[Int:Double]=[:]
}
final class DJDeck:ObservableObject {
    let name:String
    let node=AVAudioPlayerNode(),mixer=AVAudioMixerNode(),varispeed=AVAudioUnitVarispeed(),timePitch=AVAudioUnitTimePitch()
    private let stemNodes=(0..<4).map {_ in AVAudioPlayerNode()}
    private let engine:AVAudioEngine
    private let defaults:UserDefaults
    private let testing:Bool
    var prepareAudio:(()throws->Void)?
    private var file:AVAudioFile?
    private var stemFiles:[Int:AVAudioFile]=[:]
    private var scoped:[URL]=[]
    private var anchor:Double=0
    private var activeLoop:(Double,Double)?
    private var loopBuffers:[AVAudioPCMBuffer]=[]
    private var slipOrigin:(position:Double,wall:Double,rate:Double)?
    private var cueAudition=false
    @Published private(set) var track:Track?
    @Published private(set) var playing=false
    @Published private(set) var elapsed:Double=0
    @Published private(set) var duration:Double=0
    @Published var marks=DJMarks() {didSet {saveMarks()}}
    @Published var pitch:Double=0 {didSet {applyRate()}}
    @Published var pitchRange:Double=10
    @Published var keyLock=true {didSet {applyRate()}}
    @Published var slip=false
    @Published var synced=false
    @Published var loopIn:Double?
    @Published var loopOut:Double?
    @Published private(set) var looping=false
    @Published private(set) var stemNames:[Int:String]=[:]
    @Published private(set) var mutedStems:Set<Int>=[]
    @Published var stems=false {didSet {applyStemMix()}}
    @Published var error:String?
    var gain:Float=1 {didSet {mixer.outputVolume=gain}}
    private var bend:Double=0
    private var loading=false
    private var shiftMonitor:Any?
    var rate:Double {max(0.25,min(2,1+pitch/100+bend))}
    var effectiveBPM:Double {marks.bpm*rate}
    var canControl:Bool {testing || (!ControlLock.shared.isLocked && !SetupLock.shared.playbackBlocked)}
    init(_ name:String,engine:AVAudioEngine,defaults:UserDefaults = .standard,testing:Bool=false) {
        self.name=name;self.engine=engine;self.defaults=defaults;self.testing=testing
        engine.attach(node);engine.attach(mixer);engine.attach(varispeed);engine.attach(timePitch)
        engine.connect(node,to:mixer,format:nil)
        for stem in stemNodes {engine.attach(stem);engine.connect(stem,to:mixer,format:nil)}
        engine.connect(mixer,to:varispeed,format:nil);engine.connect(varispeed,to:timePitch,format:nil)
        engine.connect(timePitch,to:engine.mainMixerNode,format:nil)
        applyRate()
    }
    private var marksKey:String? {track.map {"dj.marks.v1."+$0.url.path}}
    private func saveMarks() {guard !loading,let key=marksKey else {return};defaults.set(try? JSONEncoder().encode(marks),forKey:key)}
    func load(_ track:Track) {
        guard canControl,testing || !SetupLock.shared.selectionBlocked else {return}
        do {
            let acquired=track.url.startAccessingSecurityScopedResource()
            let next:AVAudioFile
            do {next=try AVAudioFile(forReading:track.url)} catch {if acquired {track.url.stopAccessingSecurityScopedResource()};throw error}
            pauseInternal();releaseFiles()
            file=next;engine.connect(node,to:mixer,format:next.processingFormat);self.track=track;if acquired {scoped.append(track.url)}
            duration=Double(next.length)/next.processingFormat.sampleRate
            loading=true;marks=defaults.data(forKey:marksKey!).flatMap {try? JSONDecoder().decode(DJMarks.self,from:$0)} ?? DJMarks();loading=false
            marks.cue=DJMath.clamp(marks.cue,duration:duration);marks.grid=DJMath.clamp(marks.grid,duration:duration);marks.bpm=min(300,max(40,marks.bpm))
            marks.hot=marks.hot.filter {$0.key>=0 && $0.key<8 && $0.value.isFinite && $0.value>=0 && $0.value<duration}
            pitch=0;synced=false;loopIn=nil;loopOut=nil;activeLoop=nil;looping=false;stems=false;slipOrigin=nil
            anchor=marks.cue;elapsed=anchor;error=nil
        } catch {self.error="Cannot load this file in DJ mode. Convert it to WAV, AIFF or AAC first. "+error.localizedDescription}
    }
    private func releaseFiles() {file=nil;stemFiles=[:];stemNames=[:];mutedStems=[];loopBuffers=[];for url in scoped {url.stopAccessingSecurityScopedResource()};scoped=[]}
    func stopImmediately() {pauseInternal();slipOrigin=nil;bend=0;cueAudition=false;applyRate()}
    func unload() {pauseInternal();releaseFiles();track=nil;duration=0;elapsed=0;anchor=0}
    private func position()->Double {
        guard playing,let stamp=node.lastRenderTime,let time=node.playerTime(forNodeTime:stamp),time.sampleRate>0 else {return anchor}
        let delta=max(0,Double(time.sampleTime)/time.sampleRate)
        if let (start,end)=activeLoop {return start+delta.truncatingRemainder(dividingBy:end-start)}
        return min(duration,anchor+delta)
    }
    func tick() {
        if playing {elapsed=position();if activeLoop == nil,elapsed>=duration-0.002 {pauseInternal();elapsed=duration;anchor=duration}}
    }
    private func pauseInternal() {
        let current=position();node.stop();stemNodes.forEach {$0.stop()};playing=false;anchor=current;elapsed=current
    }
    func pause() {guard canControl else {return};pauseInternal();slipOrigin=nil}
    func toggle() {guard canControl else {return};if playing {pause()}else {play()}}
    func play() {
        guard canControl,file != nil else {return}
        if anchor>=duration-0.002 {anchor=marks.cue}
        do {try prepareAudio?();try schedule(at:anchor);error=nil} catch {pauseInternal();self.error=error.localizedDescription}
    }
    private func readLoop(_ file:AVAudioFile,start:Double,end:Double)throws->AVAudioPCMBuffer {
        let rate=file.processingFormat.sampleRate
        let frames=AVAudioFrameCount(max(1,min(Double(UInt32.max),((end-start)*rate).rounded())))
        guard let buffer=AVAudioPCMBuffer(pcmFormat:file.processingFormat,frameCapacity:frames) else {throw NSError(domain:"DJ",code:1,userInfo:[NSLocalizedDescriptionKey:"Unable to allocate loop buffer"])}
        file.framePosition=AVAudioFramePosition(start*rate);try file.read(into:buffer,frameCount:frames)
        return buffer
    }
    private func schedule(at seconds:Double)throws {
        guard let file else {return}
        node.stop();stemNodes.forEach {$0.stop()};loopBuffers=[]
        anchor=DJMath.clamp(seconds,duration:duration);elapsed=anchor
        let sources:[(AVAudioPlayerNode,AVAudioFile)]=[(node,file)]+stemFiles.sorted {$0.key<$1.key}.map {(stemNodes[$0.key],$0.value)}
        for (source,audio) in sources {
            if let (start,end)=activeLoop {
                let buffer=try readLoop(audio,start:start,end:end);loopBuffers.append(buffer)
                source.scheduleBuffer(buffer,at:nil,options:.loops)
                anchor=start;elapsed=start
            } else {
                let start=AVAudioFramePosition(anchor*audio.processingFormat.sampleRate)
                let count=AVAudioFrameCount(min(Int64(UInt32.max),max(0,audio.length-start)))
                if count>0 {source.scheduleSegment(audio,startingFrame:start,frameCount:count,at:nil)}
            }
        }
        let when:AVAudioTime?=engine.isInManualRenderingMode ? nil:AVAudioTime(hostTime:mach_absolute_time()+AVAudioTime.hostTime(forSeconds:0.015))
        for (source,_) in sources {source.play(at:when)}
        playing=true;applyStemMix()
    }
    func seek(_ seconds:Double) {
        guard canControl,file != nil else {return}
        let resume=playing;pauseInternal();activeLoop=nil;looping=false;anchor=DJMath.clamp(seconds,duration:duration);elapsed=anchor
        if resume {play()}
    }
    func setCue() {guard canControl else {return};marks.cue=position();marks.grid=marks.cue}
    func cueDown() {
        guard canControl,file != nil else {return}
        activeLoop=nil;looping=false
        if playing {pauseInternal();anchor=marks.cue;elapsed=anchor;cueAudition=false}
        else {anchor=marks.cue;elapsed=anchor;cueAudition=true;activeLoop=nil;looping=false;play()}
    }
    func cueUp() {guard cueAudition else {return};pauseInternal();anchor=marks.cue;elapsed=anchor;cueAudition=false}
    private func beginSlip() {if slip,playing,slipOrigin==nil {slipOrigin=(position(),ProcessInfo.processInfo.systemUptime,rate)}}
    private func endSlip() {
        guard let origin=slipOrigin else {return};slipOrigin=nil
        let target=origin.position+(ProcessInfo.processInfo.systemUptime-origin.wall)*origin.rate
        seek(target)
    }
    func hotDown(_ index:Int,delete:Bool=false) {
        guard canControl else {return}
        if delete {marks.hot.removeValue(forKey:index);return}
        guard let point=marks.hot[index] else {marks.hot[index]=position();return}
        beginSlip();seek(point);if !playing {play()}
    }
    func hotUp() {if slipOrigin != nil {endSlip()}}
    func pitchBend(_ amount:Double) {guard amount==0 || canControl else {return};bend=amount;applyRate()}
    private func applyRate() {
        if keyLock {varispeed.rate=1;timePitch.rate=Float(rate)}else {varispeed.rate=Float(rate);timePitch.rate=1}
    }
    func markIn() {guard canControl else {return};loopIn=position();loopOut=nil}
    func markOut() {guard canControl,let start=loopIn else {return};let end=position();if end-start>=0.05 {loopOut=end;activateLoop(start,end)}}
    func autoLoop(_ beats:Int) {
        guard canControl else {return};let beat=60/max(40,marks.bpm)
        let start=max(0,marks.grid+floor((position()-marks.grid)/beat)*beat),end=DJMath.loopEnd(start:start,beats:beats,bpm:marks.bpm,duration:duration)
        loopIn=start;loopOut=end;activateLoop(start,end)
    }
    private func activateLoop(_ start:Double,_ end:Double) {
        guard end-start>=0.05,end-start<=60 else {error="Loop must be between 50 ms and 60 seconds.";return}
        beginSlip();activeLoop=(start,end);looping=true;anchor=start
        play()
    }
    func reloop() {
        guard canControl else {return}
        if looping {let current=position();activeLoop=nil;looping=false;if slipOrigin != nil {endSlip()}else {seek(current)}}
        else if let start=loopIn,let end=loopOut {activateLoop(start,end)}
    }
    func trimLoop(_ delta:Double) {guard canControl,let start=loopIn,let end=loopOut else {return};loopOut=min(duration,max(start+0.05,end+delta));if looping {activateLoop(start,loopOut!)}}
    func jog(_ fraction:Double) {guard canControl else {return};seek(position()+fraction*8)}
    func importStem(_ index:Int) {
        guard canControl,!SetupLock.shared.editsBlocked,file != nil else {return}
        let panel=NSOpenPanel();panel.allowedContentTypes=[.audio];panel.message="Choose an aligned stem exported from the same start as this track."
        guard panel.runModal() == .OK,let url=panel.url else {return}
        do {try loadStem(index,url:url)} catch {self.error=error.localizedDescription}
    }
    func loadStem(_ index:Int,url:URL)throws {
        guard canControl,(0..<4).contains(index),file != nil else {return}
        let acquired=url.startAccessingSecurityScopedResource()
        do {
            let audio=try AVAudioFile(forReading:url)
            guard abs(Double(audio.length)/audio.processingFormat.sampleRate-duration)<0.15 else {throw NSError(domain:"DJ",code:2,userInfo:[NSLocalizedDescriptionKey:"Stem length must match the deck track (within 150 ms)."])}
            let resume=playing;pauseInternal();engine.connect(stemNodes[index],to:mixer,format:audio.processingFormat);stemFiles[index]=audio;stemNames[index]=url.lastPathComponent;if acquired {scoped.append(url)}
            if resume {play()};error=nil
        } catch {if acquired {url.stopAccessingSecurityScopedResource()};throw error}
    }
    func toggleStem(_ index:Int,solo:Bool=false) {
        guard canControl,stems,stemFiles.count==4 else {return}
        if solo {mutedStems=Set(0..<4).subtracting([index])}else if mutedStems.contains(index) {mutedStems.remove(index)}else {mutedStems.insert(index)}
        applyStemMix()
    }
    private func applyStemMix() {let enabled=stems && stemFiles.count==4;node.volume=enabled ? 0:1;for i in 0..<4 {stemNodes[i].volume=enabled && !mutedStems.contains(i) ? 1:0}}
}
final class DJSession:ObservableObject {
    static let shared=DJSession()
    let engine=AVAudioEngine()
    let a:DJDeck,b:DJDeck
    @Published var master="A"
    @Published var crossfade:Double=0 {didSet {updateGains()}}
    @Published var volume:Double=0.8 {didSet {updateGains()}}
    @Published var shift=false
    @Published var error:String?
    private var timer:AnyCancellable?
    private var routeMonitor:AnyCancellable?
    private var routeUID:String?
    private var shiftMonitor:Any?
    init() {
        a=DJDeck("A",engine:engine);b=DJDeck("B",engine:engine)
        a.prepareAudio={ [weak self] in try self?.startEngine() };b.prepareAudio={ [weak self] in try self?.startEngine() }
        shiftMonitor=NSEvent.addLocalMonitorForEvents(matching:.flagsChanged) { [weak self] event in
            if NSApp.keyWindow?.title == "Hard Play DJ" {self?.shift=event.modifierFlags.contains(.shift)}
            return event
        }
        routeMonitor=AudioRouting.shared.objectWillChange.sink {[weak self] in DispatchQueue.main.async {self?.checkRoute()}}
        updateGains()
    }
    func startEngine()throws {
        if timer==nil {timer=Timer.publish(every:1.0/30,on:.main,in:.common).autoconnect().sink {[weak self] _ in guard let self else {return};self.a.tick();self.b.tick();if !self.a.playing && !self.b.playing {self.timer=nil}}}

        guard let uid=AudioRouting.shared.resolved(.main) else {throw NSError(domain:"DJ",code:3,userInfo:[NSLocalizedDescriptionKey:"Main output unavailable. Choose an output in PATCH → Audio."])}
        if routeUID != uid {engine.stop();try route(uid);routeUID=uid}
        if !engine.isRunning {engine.prepare();try engine.start()}
    }
    private func route(_ uid:String)throws {
        var address=AudioObjectPropertyAddress(mSelector:kAudioHardwarePropertyTranslateUIDToDevice,mScope:kAudioObjectPropertyScopeGlobal,mElement:kAudioObjectPropertyElementMain)
        var text:CFString=uid as CFString;var device=AudioDeviceID(0);var size=UInt32(MemoryLayout<AudioDeviceID>.size)
        let status=withUnsafePointer(to:&text) {AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject),&address,UInt32(MemoryLayout<CFString>.size),$0,&size,&device)}
        guard status==noErr,let unit=engine.outputNode.audioUnit,AudioUnitSetProperty(unit,kAudioOutputUnitProperty_CurrentDevice,kAudioUnitScope_Global,0,&device,size)==noErr else {throw NSError(domain:"DJ",code:4,userInfo:[NSLocalizedDescriptionKey:"Could not patch DJ output to the selected device."])}
    }
    private func checkRoute() {if routeUID != nil,routeUID != AudioRouting.shared.resolved(.main) {a.stopImmediately();b.stopImmediately();engine.stop();routeUID=nil;error="Output changed. Decks paused; check PATCH → Audio before resuming."}}
    func stop() {a.stopImmediately();b.stopImmediately();shift=false;timer=nil;engine.stop()}
    func updateGains() {a.gain=Float(volume*cos((crossfade+1)*Double.pi/4));b.gain=Float(volume*sin((crossfade+1)*Double.pi/4))}
    func sync(_ deck:DJDeck) {
        guard deck.canControl,deck.track != nil else {return}
        let source=master=="A" ? a:b
        guard source !== deck,source.track != nil else {return}
        let pitch=(source.effectiveBPM/deck.marks.bpm-1)*100
        guard abs(pitch)<=deck.pitchRange else {deck.error="Tempo is outside the selected pitch range.";return}
        deck.pitch=pitch
        let target=DJMath.phaseTarget(master:source.elapsed,masterGrid:source.marks.grid,masterBPM:source.marks.bpm,local:deck.elapsed,grid:deck.marks.grid,bpm:deck.marks.bpm)
        deck.seek(target);deck.synced=true
    }
}
