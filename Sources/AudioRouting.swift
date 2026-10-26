import SwiftUI
import AVFoundation
import CoreAudio
import Combine

struct AudioOutput:Identifiable,Equatable {
    let id:String
    let name:String
}
enum AudioRoute:String {case main,preview}
private final class RoutedPlayer {
    weak var player:AVPlayer?
    let role:AudioRoute
    init(_ player:AVPlayer,_ role:AudioRoute){self.player=player;self.role=role}
}
final class AudioRouting:ObservableObject {
    static let shared=AudioRouting()
    @Published private(set) var outputs:[AudioOutput]=[]
    @Published private(set) var defaultUID:String?
    @Published var mainUID:String {didSet {changed(.main)}}
    @Published var previewUID:String {didSet {changed(.preview)}}
    private let defaults:UserDefaults
    private var players:[RoutedPlayer]=[]
    private var timer:AnyCancellable?
    init(defaults:UserDefaults = .standard,monitor:Bool=true) {
        self.defaults=defaults
        mainUID=defaults.string(forKey:"audio.mainOutput") ?? ""
        previewUID=defaults.string(forKey:"audio.previewOutput") ?? ""
        if monitor {
            refresh()
            timer=Timer.publish(every:1,on:.main,in:.common).autoconnect().sink {[weak self] _ in self?.refresh()}
        }
    }
    func uid(_ role:AudioRoute)->String {role == .main ? mainUID:previewUID}
    func resolved(_ role:AudioRoute)->String? {Self.resolve(uid(role),outputs:outputs,defaultUID:defaultUID)}
    static func resolve(_ selection:String,outputs:[AudioOutput],defaultUID:String?)->String? {
        let value=selection.isEmpty ? defaultUID:selection
        return outputs.first(where:{$0.id == value})?.id
    }
    static func previewIsSeparate(main:String,preview:String,outputs:[AudioOutput],defaultUID:String?)->Bool {
        guard !preview.isEmpty,let a=resolve(main,outputs:outputs,defaultUID:defaultUID),let b=resolve(preview,outputs:outputs,defaultUID:defaultUID) else {return false}
        return a != b
    }
    var cueAvailable:Bool {Self.previewIsSeparate(main:mainUID,preview:previewUID,outputs:outputs,defaultUID:defaultUID)}
    var separateOutputs:Bool {guard let a=resolved(.main),let b=resolved(.preview) else {return false};return a != b}
    func available(_ role:AudioRoute)->Bool {resolved(role) != nil}
    func register(_ player:AVPlayer,role:AudioRoute) {
        players.removeAll {$0.player == nil || $0.player === player}
        players.append(RoutedPlayer(player,role));apply(player,role)
    }
    private func changed(_ role:AudioRoute) {
        defaults.set(uid(role),forKey:role == .main ? "audio.mainOutput":"audio.previewOutput")
        applyAll()
    }
    private func apply(_ player:AVPlayer,_ role:AudioRoute) {
        // A missing explicitly selected device must not leak preview audio into the default PA output.
        player.isMuted = !available(role)
        player.audioOutputDeviceUniqueID=uid(role).isEmpty ? nil:uid(role)
    }
    private func applyAll(){players.removeAll {$0.player == nil};for item in players {if let player=item.player {apply(player,item.role)}}}
    func refresh() {
        var address=AudioObjectPropertyAddress(mSelector:kAudioHardwarePropertyDevices,mScope:kAudioObjectPropertyScopeGlobal,mElement:kAudioObjectPropertyElementMain)
        var size:UInt32=0
        guard AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject),&address,0,nil,&size)==noErr,size>0 else {return}
        var ids=[AudioDeviceID](repeating:0,count:Int(size)/MemoryLayout<AudioDeviceID>.size)
        let status=ids.withUnsafeMutableBytes {AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject),&address,0,nil,&size,$0.baseAddress!)}
        guard status==noErr else {return}
        let next=ids.compactMap {id->AudioOutput? in
            var streams=AudioObjectPropertyAddress(mSelector:kAudioDevicePropertyStreams,mScope:kAudioDevicePropertyScopeOutput,mElement:kAudioObjectPropertyElementMain)
            var bytes:UInt32=0
            guard AudioObjectGetPropertyDataSize(id,&streams,0,nil,&bytes)==noErr,bytes>0,
                  let uid=Self.string(id,kAudioDevicePropertyDeviceUID),let name=Self.string(id,kAudioObjectPropertyName) else {return nil}
            return AudioOutput(id:uid,name:name)
        }.sorted {$0.name.localizedStandardCompare($1.name) == .orderedAscending}
        var device=AudioDeviceID(0);size=UInt32(MemoryLayout<AudioDeviceID>.size)
        address.mSelector=kAudioHardwarePropertyDefaultOutputDevice
        let defaultStatus=AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject),&address,0,nil,&size,&device)
        let newDefault=defaultStatus == noErr ? Self.string(device,kAudioDevicePropertyDeviceUID):nil
        if next != outputs || newDefault != defaultUID {outputs=next;defaultUID=newDefault;applyAll()}
    }
    private static func string(_ id:AudioObjectID,_ selector:AudioObjectPropertySelector)->String? {
        var address=AudioObjectPropertyAddress(mSelector:selector,mScope:kAudioObjectPropertyScopeGlobal,mElement:kAudioObjectPropertyElementMain)
        var value:Unmanaged<CFString>?;var size=UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        guard AudioObjectGetPropertyData(id,&address,0,nil,&size,&value)==noErr else {return nil}
        return value?.takeRetainedValue() as String?
    }
}
struct AudioOutputPicker:View {
    let role:AudioRoute
    @ObservedObject private var routing=AudioRouting.shared
    var body:some View {
        VStack(alignment:.leading,spacing:4) {
            Picker(role == .main ? "Main Output":"Preview Output",selection:Binding(get:{routing.uid(role)},set:{if role == .main {routing.mainUID=$0}else {routing.previewUID=$0}})) {
                Text("System Default").tag("")
                ForEach(routing.outputs){Text($0.name).tag($0.id)}
                if !routing.uid(role).isEmpty,!routing.outputs.contains(where:{$0.id == routing.uid(role)}) {Text("Unavailable device").tag(routing.uid(role))}
            }.accessibilityLabel(role == .main ? "Main Audio Output":"Editor Preview Output")
            if !routing.available(role) {Text("Output unavailable · audio muted until reconnected").font(.stage(.caption)).foregroundStyle(.orange)}
        }
    }
}
