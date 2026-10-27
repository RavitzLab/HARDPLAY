import SwiftUI
import CoreAudio
import AVFoundation

struct DeviceAudioInfo {
    var id:AudioDeviceID=0
    var rate:Double=0
    var rates:[Double]=[]
    var frames:UInt32=0
    var buffers:[UInt32]=[]
    var channels:UInt32=0
    var pair:[UInt32]=[]
    var latency:Double=0
    var rateWritable=false,bufferWritable=false,pairWritable=false
}
enum AudioProcessingQuality:String,CaseIterable {case fast="Low latency",balanced="Balanced",high="High quality"
    var algorithm:AVAudioTimePitchAlgorithm {switch self {case .fast:return .varispeed;case .balanced:return .timeDomain;case .high:return .spectral}}
}
extension AudioRouting {
    func deviceInfo(_ role:AudioRoute)->DeviceAudioInfo {
        guard let uid=resolved(role),let output=outputs.first(where:{$0.id==uid}) else {return .init()}
        var address=AudioObjectPropertyAddress(mSelector:kAudioHardwarePropertyDevices,mScope:kAudioObjectPropertyScopeGlobal,mElement:0),size:UInt32=0
        guard AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject),&address,0,nil,&size)==noErr else {return .init()}
        var ids=[AudioDeviceID](repeating:0,count:Int(size)/4)
        _=ids.withUnsafeMutableBytes {AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject),&address,0,nil,&size,$0.baseAddress!)}
        guard let id=ids.first(where:{deviceString($0)==output.id}) else {return .init()}
        var info=DeviceAudioInfo();info.id=id
        func scalar<T>(_ selector:AudioObjectPropertySelector,_ initial:T,scope:AudioObjectPropertyScope=kAudioObjectPropertyScopeGlobal)->T {
            var a=AudioObjectPropertyAddress(mSelector:selector,mScope:scope,mElement:0),v=initial,n=UInt32(MemoryLayout<T>.size)
            _=withUnsafeMutableBytes(of:&v) {AudioObjectGetPropertyData(id,&a,0,nil,&n,$0.baseAddress!)};return v
        }
        func ranges(_ selector:AudioObjectPropertySelector)->[AudioValueRange] {
            var a=AudioObjectPropertyAddress(mSelector:selector,mScope:kAudioObjectPropertyScopeGlobal,mElement:0),n:UInt32=0
            guard AudioObjectGetPropertyDataSize(id,&a,0,nil,&n)==noErr,n>0 else {return []}
            var r=[AudioValueRange](repeating:AudioValueRange(mMinimum:0,mMaximum:0),count:Int(n)/MemoryLayout<AudioValueRange>.size)
            _=r.withUnsafeMutableBytes {AudioObjectGetPropertyData(id,&a,0,nil,&n,$0.baseAddress!)};return r
        }
        func writable(_ selector:AudioObjectPropertySelector,scope:AudioObjectPropertyScope=kAudioObjectPropertyScopeGlobal)->Bool {
            var a=AudioObjectPropertyAddress(mSelector:selector,mScope:scope,mElement:0),yes=DarwinBoolean(false)
            return AudioObjectIsPropertySettable(id,&a,&yes)==noErr && yes.boolValue
        }
        info.rate=scalar(kAudioDevicePropertyNominalSampleRate,0.0)
        let rr=ranges(kAudioDevicePropertyAvailableNominalSampleRates)
        let standardRates:[Double]=[22050,32000,44100,48000,88200,96000,176400,192000]
        let rangeEdges:[Double]=rr.flatMap {[$0.mMinimum,$0.mMaximum]}
        let supportedRates=(standardRates+rangeEdges).filter {rate in
            rr.contains {range in range.mMinimum<=rate && rate<=range.mMaximum}
        }
        let uniqueRates=Set(supportedRates+[info.rate])
        info.rates=uniqueRates.filter {$0>0}.sorted()
        info.frames=scalar(kAudioDevicePropertyBufferFrameSize,UInt32(0))
        let br=ranges(kAudioDevicePropertyBufferFrameSizeRange)
        let standardBuffers:[UInt32]=[32,64,128,256,512,1024,2048,4096]
        let boundaries:[UInt32]=br.flatMap {[UInt32(max(0,$0.mMinimum)),UInt32(max(0,$0.mMaximum))]}
        let supported=(standardBuffers+boundaries).filter {v in br.contains {$0.mMinimum<=Double(v) && Double(v)<=$0.mMaximum}}
        info.buffers=Array(Set(supported+[info.frames])).filter {$0>0}.sorted()
        var streams=AudioObjectPropertyAddress(mSelector:kAudioDevicePropertyStreamConfiguration,mScope:kAudioDevicePropertyScopeOutput,mElement:0),bytes:UInt32=0
        if AudioObjectGetPropertyDataSize(id,&streams,0,nil,&bytes)==noErr,bytes>0 {
            let data=UnsafeMutableRawPointer.allocate(byteCount:Int(bytes),alignment:MemoryLayout<AudioBufferList>.alignment);defer {data.deallocate()}
            if AudioObjectGetPropertyData(id,&streams,0,nil,&bytes,data)==noErr {info.channels=UnsafeMutableAudioBufferListPointer(data.assumingMemoryBound(to:AudioBufferList.self)).reduce(0) {$0+$1.mNumberChannels}}
        }
        var pair=[UInt32](repeating:0,count:2),pn:UInt32=8
        var pa=AudioObjectPropertyAddress(mSelector:kAudioDevicePropertyPreferredChannelsForStereo,mScope:kAudioDevicePropertyScopeOutput,mElement:0)
        if pair.withUnsafeMutableBytes({AudioObjectGetPropertyData(id,&pa,0,nil,&pn,$0.baseAddress!)})==noErr {info.pair=pair}
        info.rateWritable=writable(kAudioDevicePropertyNominalSampleRate);info.bufferWritable=writable(kAudioDevicePropertyBufferFrameSize)
        info.pairWritable=writable(kAudioDevicePropertyPreferredChannelsForStereo,scope:kAudioObjectPropertyScopeOutput)
        let latency=scalar(kAudioDevicePropertyLatency,UInt32(0),scope:kAudioObjectPropertyScopeOutput)
        let safety=scalar(kAudioDevicePropertySafetyOffset,UInt32(0),scope:kAudioObjectPropertyScopeOutput)
        info.latency=info.rate>0 ? Double(latency+safety+info.frames)/info.rate*1000:0
        return info
    }
    private func deviceString(_ id:AudioDeviceID)->String? {
        var a=AudioObjectPropertyAddress(mSelector:kAudioDevicePropertyDeviceUID,mScope:kAudioObjectPropertyScopeGlobal,mElement:0),v:Unmanaged<CFString>?,n=UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        guard AudioObjectGetPropertyData(id,&a,0,nil,&n,&v)==noErr else {return nil};return v?.takeRetainedValue() as String?
    }
    func setDeviceValue<T>(_ role:AudioRoute,selector:AudioObjectPropertySelector,value:T,output:Bool=false)->String {
        let info=deviceInfo(role);guard info.id != 0 else {return "Device unavailable."}
        var a=AudioObjectPropertyAddress(mSelector:selector,mScope:output ? kAudioObjectPropertyScopeOutput:kAudioObjectPropertyScopeGlobal,mElement:0),v=value
        let status=withUnsafeBytes(of:&v) {AudioObjectSetPropertyData(info.id,&a,0,nil,UInt32($0.count),$0.baseAddress!)}
        return status==noErr ? "Applied to hardware. This setting is shared by applications using this device.":"The driver rejected this setting (\(status)). Current hardware values are shown."
    }
    func setStereoPair(_ role:AudioRoute,left:UInt32,right:UInt32)->String {
        let info=deviceInfo(role);guard info.id != 0,left>0,right>0,left<=info.channels,right<=info.channels,left != right else {return "Choose two different available output channels."}
        var a=AudioObjectPropertyAddress(mSelector:kAudioDevicePropertyPreferredChannelsForStereo,mScope:kAudioObjectPropertyScopeOutput,mElement:0)
        var values=[left,right]
        let status=values.withUnsafeMutableBytes {AudioObjectSetPropertyData(info.id,&a,0,nil,8,$0.baseAddress!)}
        return status==noErr ? "Hardware stereo pair updated. Shared device preference; check your interface mixer routing.":"This driver does not allow stereo channel patching (\(status)). Use its control panel."
    }
}
final class AudioDeviceUI:ObservableObject {
    @Published var info=DeviceAudioInfo()
    @Published var message=""
    @Published var left:UInt32=1
    @Published var right:UInt32=2
}
struct AudioDeviceSettings:View {
    let role:AudioRoute
    @ObservedObject private var routing=AudioRouting.shared
    @StateObject private var ui=AudioDeviceUI()
    private func refresh(){ui.info=routing.deviceInfo(role);ui.left=ui.info.pair.first ?? 1;ui.right=ui.info.pair.last ?? min(2,ui.info.channels)}
    var body:some View {
        VStack(alignment:.leading,spacing:9) {
            Picker("Sample rate",selection:Binding(get:{ui.info.rate},set:{ui.message=routing.setDeviceValue(role,selector:kAudioDevicePropertyNominalSampleRate,value:$0);refresh()})) {ForEach(ui.info.rates,id:\.self) {rate in Text(String(format:"%g Hz",rate)).tag(rate)}}.disabled(!ui.info.rateWritable)
                .stageHint("Hardware sample rate. Changing it may briefly interrupt audio in all apps using this device")
            Picker("Buffer / latency",selection:Binding(get:{ui.info.frames},set:{ui.message=routing.setDeviceValue(role,selector:kAudioDevicePropertyBufferFrameSize,value:$0);refresh()})) {ForEach(ui.info.buffers,id:\.self) {n in Text("\(n) frames").tag(n)}}.disabled(!ui.info.bufferWritable)
                .stageHint("Smaller buffers reduce latency; larger buffers tolerate heavier system load")
            Text(String(format:"Reported device path: ≈ %.1f ms · %u output channels",ui.info.latency,ui.info.channels)).font(.stage(.caption)).stageSecondary()
            if ui.info.channels>=2 {
                HStack {Picker("Left",selection:$ui.left) {ForEach(1...ui.info.channels,id:\.self) {Text("\($0)").tag($0)}};Picker("Right",selection:$ui.right) {ForEach(1...ui.info.channels,id:\.self) {Text("\($0)").tag($0)}}}.disabled(!ui.info.pairWritable)
                Button("Apply hardware stereo pair") {ui.message=routing.setStereoPair(role,left:ui.left,right:ui.right);refresh()}.disabled(!ui.info.pairWritable || ui.left==ui.right)
                    .stageHint("Change the device-wide preferred stereo channels, not an independent per-app matrix")
            }
            Picker("Processing quality",selection:Binding(get:{routing.quality(role)},set:{routing.setQuality($0,role:role)})) {ForEach(AudioProcessingQuality.allCases,id:\.self) {Text($0.rawValue).tag($0)}}
                .stageHint("Speed-processing quality: Low latency uses varispeed (pitch changes slightly); Balanced and High preserve pitch. Original files are unchanged")
            Text("Hardware settings are shared. Channel patching depends on the driver; this is not a per-app multichannel mixer. Quality affects speed processing, not source bit depth.").font(.stage(.caption)).stageSecondary()
            if !ui.message.isEmpty {Text(ui.message).font(.stage(.caption)).foregroundStyle(accent)}
        }.padding(10).background(accent.opacity(0.05),in:RoundedRectangle(cornerRadius:8)).onAppear(perform:refresh).onChange(of:routing.uid(role)) {_,_ in refresh()}
    }
}
