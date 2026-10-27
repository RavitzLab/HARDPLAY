import Foundation
import Network
import Security
import CryptoKit
import Combine

/// Encrypted set metadata and explicitly armed linked transport. Never switches audio outputs.
final class BackupLink:ObservableObject {
    static let shared=BackupLink(defaults:.standard)
    enum Role:String,CaseIterable,Codable {case primary="Primary A",backup="Backup B"}
    struct Peer:Identifiable {let id:String;let endpoint:NWEndpoint;let name:String}
    struct Packet:Codable {let version:Int;let kind:String;let role:Role;let name:String;let manifest:BackupManifest?;var sync:BackupSyncMessage? = nil;var capabilities:[String]? = nil;var playback:BackupPlayMessage? = nil;var probe:SyncProbe? = nil}
    @Published private(set) var role:Role = .primary
    @Published private(set) var peers:[Peer]=[]
    @Published private(set) var code=""
    @Published private(set) var status="Disconnected"
    @Published private(set) var peerName=""
    @Published private(set) var connected=false
    @Published private(set) var listening=false
    @Published private(set) var scanning=false
    @Published private(set) var progress=""
    @Published private(set) var local:BackupManifest?
    @Published private(set) var remote:BackupManifest?
    @Published private(set) var issues:[String]=[]
    @Published private(set) var peerSupportsSync=false
    @Published private(set) var syncing=false
    @Published private(set) var syncStatus=""
    @Published private(set) var syncReview:BackupSyncReview?
    @Published private(set) var peerSupportsPlayback=false
    @Published private(set) var playbackRequested=false
    @Published private(set) var linkedPlayback=false
    @Published private(set) var playbackStatus="Linked Playback is off."
    @Published private(set) var peerSupportsTiming=false
    @Published private(set) var timingRTT:Double=0
    @Published private(set) var timingJitter:Double=0
    @Published private(set) var timingDriftMS:Double?=nil
    @Published private(set) var timingStatus="Not measured"
    @Published var autoAlign=false {didSet {if !autoAlign {source?.resetLinkedRate()}}}
    @Published var manualOffsetMS:Double=0 {didSet {
        let clipped=manualOffsetMS.isFinite ? min(250,max(-250,manualOffsetMS)):0
        if manualOffsetMS != clipped {manualOffsetMS=clipped}
    }}
    private var clock=SyncClockEstimate()
    private var pendingProbes:[UUID:Double]=[:]
    private var lastRemoteState:BackupPlayState?
    private var lastRemoteAt=0.0
    var timingReady:Bool {connected && peerSupportsTiming && clock.ready(at:ProcessInfo.processInfo.systemUptime)}
    func measureSync() {
        guard connected,peerSupportsTiming else {timingStatus="Update both Macs to measure sync";return}
        clock=SyncClockEstimate();pendingProbes=[:];timingDriftMS=nil;timingStatus="Measuring…"
        let session=epoch
        for step in 0..<6 {DispatchQueue.main.asyncAfter(deadline:.now()+Double(step)*0.12) {[weak self] in guard let self,self.epoch==session,self.connected else {return};self.sendProbe()}}
    }
    private func sendProbe() {
        guard connected,peerSupportsTiming else {return}
        let now=ProcessInfo.processInfo.systemUptime,id=UUID()
        pendingProbes=pendingProbes.filter {now-$0.value<3};pendingProbes[id]=now
        send("clock-ping",probe:.init(id:id,sent:now))
    }
    private func handleProbe(_ packet:Packet) {
        guard peerSupportsTiming,let probe=packet.probe else {return}
        let now=ProcessInfo.processInfo.systemUptime
        if packet.kind=="clock-ping" {send("clock-pong",probe:.init(id:probe.id,sent:probe.sent,received:now,replied:ProcessInfo.processInfo.systemUptime));return}
        if packet.kind=="clock-pong",let sent=pendingProbes.removeValue(forKey:probe.id),sent==probe.sent,let received=probe.received,let replied=probe.replied,let sample=SyncClockSample(sent:sent,received:received,replied:replied,arrived:now) {
            clock.add(sample);timingRTT=clock.rtt*1000;timingJitter=clock.jitter*1000
            if !timingReady {timingStatus=clock.samples.count<4 ? "Measuring…":"Unstable link"}
            else if !linkedPlayback {timingStatus="Network measured · link playback to compare positions"}
        }
        if packet.kind=="clock-report",role == .primary,linkedPlayback {timingDriftMS=probe.driftMS;timingStatus=probe.status ?? "Measuring…"}
    }
    private var peerPlaybackRequested=false
    private var playbackToken:UUID?
    private var peerPlaybackToken:UUID?
    private var playbackConfiguration:String?
    private var peerPlaybackFingerprint:String?
    private var playSequence:UInt64=0
    private var receivedPlaySequence:UInt64=0
    private var lastPlaySent=0.0
    private var lastPlaySeconds=0.0
    private var lastPlayKey=""
    private var syncID:UUID?
    private var incomingSyncID:UUID?
    private var syncDirection:BackupSyncDirection?
    private var syncInventory:BackupSyncInventory?
    private var remoteInventory:(manifest:BackupManifest,token:UUID)?
    private var syncTask:Task<Void,Never>?
    private var incomingSyncTask:Task<Void,Never>?
    private var syncBaseline:String?
    private let defaults:UserDefaults?
    private var listener:NWListener?
    private var browser:NWBrowser?
    private var connection:NWConnection?
    private var incoming=Data()
    private var timer:Timer?
    private var lastReceive=ProcessInfo.processInfo.systemUptime
    private var scanTask:Task<Void,Never>?
    private var signature:String?
    private var verifiedPlaybackConfiguration:String?
    private var epoch=UUID()
    private var scanEpoch=UUID()
    private var updates:AnyCancellable?
    private var source:Player?
    private var fileWatch:AnyCancellable?
    private var fileStamp:String?
    private func stamps(_ input:BackupSetInput)->String {
        input.items.map {item in
            let a=try? FileManager.default.attributesOfItem(atPath:item.url.path)
            return "\(item.url.path):\((a?[.size] as? NSNumber)?.int64Value ?? -1):\((a?[.modificationDate] as? Date)?.timeIntervalSince1970 ?? -1)"
        }.joined(separator:"\n")
    }

    private let canConfigure:()->Bool
    let name:String
    var port:NWEndpoint.Port? {guard let port=listener?.port,port.rawValue>0 else {return nil};return port}
    var verified:Bool {connected && local != nil && remote != nil && issues.isEmpty}
    var summary:String {
        if !connected {return status}
        if syncing {return syncReview == nil ? "Synchronizing set…":"Review set sync"}
        if linkedPlayback {return role == .primary ? "Linked Playback · Primary A":"Linked Playback · following A"}
        if playbackRequested {return "Enable Linked Playback on the other Mac"}
        if scanning {return "Checking set…"}
        if local == nil || remote == nil {return "Connected · Ready to sync set"}
        return issues.isEmpty ? "Sets match · playback independent":"Set mismatch · \(issues.count) issues"
    }
    init(name:String=Host.current().localizedName ?? "HARDPLAY Mac",canConfigure:@escaping ()->Bool = { !SetupLock.shared.settingsBlocked && !ControlLock.shared.isLocked },defaults:UserDefaults? = nil) {self.name=String(name.prefix(100));self.canConfigure=canConfigure;self.defaults=defaults;role=Role(rawValue:defaults?.string(forKey:"backupRole") ?? "") ?? .primary}
    func observe(_ player:Player) {
        guard updates == nil else {return};source=player
        player.linkedAction={ [weak self] action in self?.forwardPlaybackAction(action) ?? false }
        player.linkedStateDidChange={ [weak self] in self?.broadcastPlayback() }
        updates=player.objectWillChange.throttle(for:.seconds(1),scheduler:RunLoop.main,latest:true).sink { [weak self,weak player] _ in
            DispatchQueue.main.async {guard let self,let player else {return};let input=player.backupInput();if self.playbackRequested {if input.playbackConfiguration != self.playbackConfiguration {self.invalidate()};return};let now=input.signature;if let baseline=self.syncBaseline,now != baseline {self.invalidate();return};if let signature=self.signature,now != signature {self.invalidate()}}
        }
    }
    static func normalizedCode(_ value:String)->String {value.uppercased().filter {"ABCDEFGHJKLMNPQRSTUVWXYZ23456789".contains($0)}}
    static func parameters(_ code:String)->NWParameters {
        let tls=NWProtocolTLS.Options()
        let key=Data(SHA256.hash(data:Data(("HARDPLAY pairing v1:"+code).utf8)))
        let identity=Data("HARDPLAY-backup-v1".utf8)
        key.withUnsafeBytes {keyBytes in identity.withUnsafeBytes {identityBytes in
            sec_protocol_options_add_pre_shared_key(tls.securityProtocolOptions,DispatchData(bytes:keyBytes) as __DispatchData,DispatchData(bytes:identityBytes) as __DispatchData)
        }}
        // Network.framework external PSK is supported with TLS 1.2, not TLS 1.3.
        sec_protocol_options_append_tls_ciphersuite(tls.securityProtocolOptions,tls_ciphersuite_t(rawValue:0x00A8)!)
        sec_protocol_options_set_min_tls_protocol_version(tls.securityProtocolOptions,.TLSv12)
        sec_protocol_options_set_max_tls_protocol_version(tls.securityProtocolOptions,.TLSv12)
        let tcp=NWProtocolTCP.Options();tcp.noDelay=true
        let params=NWParameters(tls:tls,tcp:tcp);params.includePeerToPeer=false
        return params
    }
    func host(_ newRole:Role = .primary,advertise:Bool=true)throws {
        guard canConfigure() else {return};disconnect();setRole(newRole)
        let alphabet=Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")
        let raw=String((0..<12).map {_ in alphabet.randomElement()!})
        code=stride(from:0,to:12,by:4).map {String(Array(raw)[$0..<$0+4])}.joined(separator:"-")
        let server=try NWListener(using:Self.parameters(raw),on:.any);listener=server;listening=true;status="Waiting for the other Mac"
        if advertise {server.service=NWListener.Service(name:name,type:"_hardplay-bk._tcp")}
        let session=epoch
        server.stateUpdateHandler={ [weak self] state in if CommandLine.arguments.contains("--backup-link-test") {print("SERVER: \(state)");fflush(stdout)};guard let self,self.epoch == session else {return};if case .ready=state {self.status="Waiting for the other Mac"};if case .failed(let error)=state {self.status="Listener: \(error.localizedDescription)";self.listening=false} }
        server.newConnectionHandler={ [weak self] candidate in
            guard let self,self.epoch == session,self.connection == nil else {candidate.cancel();return}
            if CommandLine.arguments.contains("--backup-link-test") {print("ACCEPTED connection");fflush(stdout)}
            self.attach(candidate,session:session)
        }
        server.start(queue:.main)
        // Pairing is deliberately ephemeral and cannot stay open unattended forever.
        DispatchQueue.main.asyncAfter(deadline:.now()+300) { [weak self] in guard let self,self.epoch == session,!self.connected else {return};self.disconnect();self.status="Pairing expired · create a new code" }
    }
    func browse(_ newRole:Role = .backup) {
        guard canConfigure() else {return};disconnect();setRole(newRole);status="Looking for HARDPLAY Macs…"
        let search=NWBrowser(for:.bonjour(type:"_hardplay-bk._tcp",domain:nil),using:.tcp);browser=search;let session=epoch
        search.browseResultsChangedHandler={ [weak self] results,_ in guard let self,self.epoch == session else {return};self.peers=results.map {result in let label:String;if case .service(let n,_,_,_)=result.endpoint {label=n}else {label=result.endpoint.debugDescription};return Peer(id:result.endpoint.debugDescription,endpoint:result.endpoint,name:label)}.sorted {$0.name<$1.name} }
        search.stateUpdateHandler={ [weak self] state in guard let self,self.epoch == session else {return};if case .failed(let e)=state {self.status="Discovery: \(e.localizedDescription)"};if case .waiting(let e)=state {self.status="Allow Local Network access · \(e.localizedDescription)"} }
        search.start(queue:.main)
    }
    func connect(_ endpoint:NWEndpoint,code entered:String,role newRole:Role? = nil) {
        guard canConfigure() else {return};let normalized=Self.normalizedCode(entered)
        guard normalized.count == 12 else {status="Enter all 12 characters of the pairing code";return}
        // Stop browsing but retain the chosen role. A new explicit connect replaces old sessions.
        let selected=newRole ?? role;disconnect();setRole(selected);status="Connecting securely…"
        attach(NWConnection(to:endpoint,using:Self.parameters(normalized)),session:epoch)
    }
    private func attach(_ candidate:NWConnection,session:UUID) {
        connection=candidate;incoming.removeAll();remote=nil;peerName=""
        candidate.stateUpdateHandler={ [weak self,weak candidate] state in
            guard let self,let candidate,self.epoch == session,self.connection === candidate else {return}
            if CommandLine.arguments.contains("--backup-link-test") {print("\(self.name) CONNECTION: \(state)");fflush(stdout)}
            switch state {
            case .ready:
                self.lastReceive=ProcessInfo.processInfo.systemUptime;self.status="Authenticating peer…"
                self.send("hello");self.receive(candidate,session:session)
                self.timer=Timer.scheduledTimer(withTimeInterval:1,repeats:true) { [weak self] _ in
                    guard let self,self.connection === candidate else {return}
                    if ProcessInfo.processInfo.systemUptime-self.lastReceive>4 {self.drop("Peer offline · audio unchanged");return}
                    self.send("heartbeat")
                    if self.peerSupportsTiming {self.sendProbe();if !self.timingReady {self.timingStatus="Unstable link";self.source?.resetLinkedRate()}}
                }
            case .waiting(let error):self.status="Waiting for network: \(error.localizedDescription)"
            case .failed(let error):self.drop("Connection failed · check code / network: \(error.localizedDescription)")
            case .cancelled:break
            default:break
            }
        }
        candidate.start(queue:.main)
        DispatchQueue.main.asyncAfter(deadline:.now()+8) { [weak self,weak candidate] in guard let self,let candidate,self.connection === candidate,!self.connected else {return};self.drop("Pairing timed out · check the code and network") }
    }
    private func send(_ kind:String,manifest:BackupManifest? = nil,sync:BackupSyncMessage? = nil,playback:BackupPlayMessage? = nil,probe:SyncProbe? = nil) {
        guard let connection else {return}
        let packet=Packet(version:1,kind:kind,role:role,name:name,manifest:manifest ?? (kind == "manifest" ? local:nil),sync:sync,capabilities:kind == "hello" ? ["set-sync-v1","linked-playback-v2","sync-timing-v1"]:nil,playback:playback,probe:probe)
        guard let payload=try? JSONEncoder().encode(packet),payload.count<=Self.maxFrame else {return}
        var length=UInt32(payload.count).bigEndian;var frame=withUnsafeBytes(of:&length) {Data($0)};frame.append(payload)
        connection.send(content:frame,completion:.contentProcessed { [weak self,weak connection] error in if let error,let connection {DispatchQueue.main.async {guard let self,self.connection === connection else {return};self.drop("Send failed: \(error.localizedDescription)")}} })
    }
    static let maxFrame=8_000_000
    static func extract(_ buffer:inout Data)throws->[Packet] {
        var packets:[Packet]=[]
        while buffer.count>=4 {
            let size=buffer.prefix(4).reduce(UInt32(0)) {($0<<8)|UInt32($1)}
            guard size>0,size<=maxFrame else {throw BackupFailure("Invalid backup message length")}
            guard buffer.count>=4+Int(size) else {break}
            let packet=try JSONDecoder().decode(Packet.self,from:Data(buffer.dropFirst(4).prefix(Int(size))))
            guard packet.version == 1,["hello","heartbeat","manifest","invalidate","sync-request","sync-snapshot","sync-apply","sync-result","sync-cancel","transport-arm","transport-request","transport-state","clock-ping","clock-pong","clock-report"].contains(packet.kind),packet.name.utf8.count<=1000,(packet.manifest == nil || (["manifest","sync-snapshot","sync-apply","sync-result"].contains(packet.kind) && packet.manifest!.valid)),
                  (packet.capabilities?.count ?? 0)<=8,(packet.capabilities?.allSatisfy {$0.utf8.count<=80} ?? true),
                  (!packet.kind.hasPrefix("sync-") || packet.sync?.valid == true),
                  (packet.kind != "sync-snapshot" && packet.kind != "sync-apply" || (packet.manifest != nil && packet.sync?.token != nil)),
                  (packet.kind != "sync-result" || packet.sync?.accepted != nil),
                  (!packet.kind.hasPrefix("transport-") || packet.playback?.valid == true),
                  (packet.kind != "transport-arm" || packet.playback?.enabled != nil),
                  (packet.kind != "transport-request" || packet.playback?.action != nil),
                  (packet.kind != "transport-state" || packet.playback?.state != nil),
                  (!packet.kind.hasPrefix("clock-") || packet.probe?.valid == true) else {throw BackupFailure("Unsupported backup protocol")}
            packets.append(packet);buffer=Data(buffer.dropFirst(4+Int(size)))
        }
        guard buffer.count<=maxFrame+4 else {throw BackupFailure("Backup message too large")};return packets
    }
    private func receive(_ candidate:NWConnection,session:UUID) {
        candidate.receive(minimumIncompleteLength:1,maximumLength:65536) { [weak self,weak candidate] data,_,complete,error in
            guard let self,let candidate,self.epoch == session,self.connection === candidate else {return}
            if let data {self.incoming.append(data)}
            do {
                for packet in try Self.extract(&self.incoming) {
                    guard packet.role != self.role else {throw BackupFailure("Choose opposite roles: Primary A and Backup B")}
                    self.lastReceive=ProcessInfo.processInfo.systemUptime
                    if packet.kind == "hello" {self.connected=true;self.peerSupportsSync=packet.capabilities?.contains("set-sync-v1") == true;self.peerSupportsPlayback=packet.capabilities?.contains("linked-playback-v2") == true;self.peerSupportsTiming=packet.capabilities?.contains("sync-timing-v1") == true;self.peerName=packet.name;self.code="";self.status="Connected · TLS";if self.local != nil {self.send("manifest")}}
                    else {guard self.connected else {throw BackupFailure("Expected peer hello first")}}
                    if packet.kind == "manifest" {self.remote=packet.manifest;self.compare()}
                    if packet.kind == "invalidate" {self.disablePlayback("Other set changed. Synchronize and enable Linked Playback again.",notify:false);self.remote=nil;self.compare();self.cancelSync(message:"Other set changed. Synchronize again.")}
                    if packet.kind.hasPrefix("sync-") {self.handleSync(packet)}
                    if packet.kind.hasPrefix("transport-") {self.handlePlayback(packet)}
                    if packet.kind.hasPrefix("clock-") {self.handleProbe(packet)}
                    if packet.kind=="hello",self.peerSupportsTiming {self.measureSync()}
                }
            } catch {self.drop(error.localizedDescription);return}
            if complete || error != nil {self.drop("Peer disconnected · audio unchanged");return}
            self.receive(candidate,session:session)
        }
    }
    private func compare() {issues=(local != nil && remote != nil) ? local!.differences(from:remote!):[]}
    func invalidate() {disablePlayback("Set changed. Synchronize and enable Linked Playback again.");cancelSync(message:"Set changed. Synchronize again.");fileWatch?.cancel();fileWatch=nil;fileStamp=nil;scanTask?.cancel();scanEpoch=UUID();scanning=false;local=nil;signature=nil;verifiedPlaybackConfiguration=nil;issues=[];progress="Set changed · check again";if connected {send("invalidate")}}
    func matches(_ input:BackupSetInput)->Bool {local != nil && signature == input.signature && fileStamp == stamps(input)}
    func check(_ input:BackupSetInput) {
        guard canConfigure() else {return};invalidate();scanning=true;progress="Reading audio…";let checkID=UUID();scanEpoch=checkID
        let initialStamp=stamps(input)
        scanTask=Task { @MainActor [weak self] in
            let worker=Task.detached(priority:.utility) {try await BackupManifest.build(input)}
            do {
                let manifest=try await withTaskCancellationHandler(operation:{try await worker.value},onCancel:{worker.cancel()})
                guard let self,!Task.isCancelled,self.scanEpoch == checkID else {return}
                if CommandLine.arguments.contains("--backup-link-test"),self.stamps(input) != initialStamp {print("FILE STAMP CHANGED: \(initialStamp) -> \(self.stamps(input))");fflush(stdout)}
                guard self.stamps(input) == initialStamp,self.source.map({$0.backupInput().signature == input.signature}) ?? true else {self.invalidate();return}
                self.fileStamp=initialStamp
                self.fileWatch=Timer.publish(every:2,on:.main,in:.common).autoconnect().sink { [weak self] _ in guard let self else {return};if self.stamps(input) != self.fileStamp {self.invalidate()} }
                self.local=manifest;self.signature=input.signature;self.verifiedPlaybackConfiguration=input.playbackConfiguration;self.scanning=false;self.progress="\(manifest.entries.count) tracks checked · SHA-256 + decode probe";self.compare();if self.connected {self.send("manifest")}
            } catch {guard let self,self.scanEpoch == checkID else {return};self.scanning=false;self.progress=error.localizedDescription}
        }
    }
    private func setRole(_ value:Role) {role=value;defaults?.set(value.rawValue,forKey:"backupRole")}
    var canSync:Bool {connected && peerSupportsSync && !playbackRequested && !syncing && incomingSyncID == nil && !scanning && canConfigure() && source?.canSynchronizeSet == true}
    private func publishInventory(_ inventory:BackupSyncInventory) {
        fileWatch?.cancel();local=inventory.manifest;signature=inventory.input.signature;verifiedPlaybackConfiguration=inventory.input.playbackConfiguration;fileStamp=inventory.stamp
        let input=inventory.input
        fileWatch=Timer.publish(every:2,on:.main,in:.common).autoconnect().sink { [weak self] _ in guard let self else {return};if self.stamps(input) != self.fileStamp {self.invalidate()} }
        compare();if connected {send("manifest")}
    }
    private func freshInventory() async throws->BackupSyncInventory {
        guard let player=source,player.canSynchronizeSet,canConfigure() else {throw BackupFailure("Pause this Mac and unlock setup before syncing.")}
        let input=player.backupInput(),stamp=stamps(player.backupInput())
        syncBaseline=input.signature
        let worker=Task.detached(priority:.utility) {try await BackupManifest.build(input)}
        let manifest=try await withTaskCancellationHandler(operation:{try await worker.value},onCancel:{worker.cancel()})
        try Task.checkCancellation()
        guard player.canSynchronizeSet,player.backupInput().signature == input.signature,stamps(input) == stamp,canConfigure() else {throw BackupFailure("The set changed during scanning. Try again while both Macs are paused.")}
        return .init(input:input,manifest:manifest,token:UUID(),stamp:stamp)
    }
    private func inventoryIsCurrent(_ inventory:BackupSyncInventory)->Bool {
        canConfigure() && source?.canSynchronizeSet == true && source?.backupInput().signature == inventory.input.signature && stamps(inventory.input) == inventory.stamp
    }
    func beginSync(_ direction:BackupSyncDirection) {
        guard canSync else {syncStatus=peerSupportsSync ? "Pause both Macs and unlock setup before syncing.":"Update Hard Play on both Macs to synchronize sets.";return}
        let id=UUID();syncID=id;syncDirection=direction;syncing=true;syncReview=nil;syncInventory=nil;remoteInventory=nil
        syncStatus="Reading the loaded tracks on both Macs…"
        send("sync-request",sync:.init(id:id,direction:direction))
        syncTask=Task { @MainActor [weak self] in
            guard let self else {return}
            do {let inventory=try await self.freshInventory();guard self.syncID == id else {return};self.syncInventory=inventory;self.publishInventory(inventory);self.prepareSyncReview()}
            catch {guard self.syncID == id else {return};self.cancelSync(message:error.localizedDescription)}
        }
        DispatchQueue.main.asyncAfter(deadline:.now()+300) { [weak self] in guard let self,self.syncID == id else {return};self.cancelSync(message:"Sync expired. No pending changes were applied.") }
    }
    private func prepareSyncReview() {
        guard let id=syncID,let direction=syncDirection,let inventory=syncInventory,let remote=remoteInventory else {return}
        do {
            let plan=try BackupSyncPlan.make(source:direction == .send ? inventory.manifest:remote.manifest,destination:direction == .send ? remote.manifest:inventory.manifest)
            syncReview = .init(id:id,direction:direction,plan:plan,sourceName:direction == .send ? name:peerName,destinationName:direction == .send ? peerName:name)
            syncStatus=plan.ready ? "Ready · \(plan.source.entries.count) cues matched. Review and apply.":"Missing audio on destination · \(plan.missing.count) cues. Nothing changed."
        } catch {cancelSync(message:error.localizedDescription)}
    }
    func applySync() {
        guard let review=syncReview,let id=syncID,id == review.id,review.plan.ready,let inventory=syncInventory,inventoryIsCurrent(inventory),let remote=remoteInventory else {cancelSync(message:"The set changed or audio is missing. Scan again.");return}
        syncReview=nil;syncStatus="Applying set metadata…"
        send("sync-apply",manifest:review.plan.source,sync:.init(id:id,direction:review.direction,token:remote.token))
    }
    func cancelSync(message:String="Sync cancelled. No pending changes applied.",notify:Bool=true) {
        let active=syncID != nil || incomingSyncID != nil
        if notify,let id=syncID ?? incomingSyncID,let direction=syncDirection {send("sync-cancel",sync:.init(id:id,direction:direction))}
        syncTask?.cancel();incomingSyncTask?.cancel();syncTask=nil;incomingSyncTask=nil
        syncID=nil;incomingSyncID=nil;syncDirection=nil;syncReview=nil;syncInventory=nil;remoteInventory=nil;syncBaseline=nil;syncing=false
        if active {syncStatus=message}
    }
    private func finishSync(_ count:Int) {
        cancelSync(notify:false);syncStatus="Synchronized · \(count) cues · playback remains paused. Save the received set when ready."
    }
    private func handleSync(_ packet:Packet) {
        guard peerSupportsSync,let message=packet.sync else {return}
        switch packet.kind {
        case "sync-request":
            guard incomingSyncID == nil,syncID == nil,!scanning,canConfigure(),source?.canSynchronizeSet == true else {
                send("sync-result",sync:.init(id:message.id,direction:message.direction,message:"Other Mac is playing, locked, or busy. Pause it and try again.",accepted:false));return
            }
            let id=message.id;incomingSyncID=id;syncDirection=message.direction;syncing=true;syncStatus="Preparing a set sync requested by \(peerName)…"
            incomingSyncTask=Task { @MainActor [weak self] in
                guard let self else {return}
                do {
                    let inventory=try await self.freshInventory();guard self.incomingSyncID == id else {return}
                    self.syncInventory=inventory;self.publishInventory(inventory)
                    self.send("sync-snapshot",manifest:inventory.manifest,sync:.init(id:id,direction:message.direction,token:inventory.token))
                    self.syncStatus="Tracks matched for review on the other Mac. No changes applied yet."
                } catch {guard self.incomingSyncID == id else {return};self.send("sync-result",sync:.init(id:id,direction:message.direction,message:error.localizedDescription,accepted:false));self.cancelSync(message:error.localizedDescription,notify:false)}
            }
            DispatchQueue.main.asyncAfter(deadline:.now()+300) { [weak self] in guard let self,self.incomingSyncID == id else {return};self.cancelSync(message:"Sync request expired.") }
        case "sync-snapshot":
            guard syncID == message.id,syncDirection == message.direction,let manifest=packet.manifest,let token=message.token else {return}
            remoteInventory=(manifest,token);prepareSyncReview()
        case "sync-apply":
            guard incomingSyncID == message.id,syncDirection == message.direction,let inventory=syncInventory,message.token == inventory.token,let manifest=packet.manifest else {return}
            do {
                guard inventoryIsCurrent(inventory) else {throw BackupFailure("Other set changed, started playback, or was locked. Nothing applied.")}
                if message.direction == .send {
                    let plan=try BackupSyncPlan.make(source:manifest,destination:inventory.manifest)
                    guard let player=source else {throw BackupFailure("No local player.")}
                    try player.applySynchronizedSet(plan,inventory:inventory.input)
                    let updated=BackupSyncInventory(input:player.backupInput(),manifest:manifest,token:UUID(),stamp:stamps(player.backupInput()))
                    syncBaseline=updated.input.signature;publishInventory(updated);remote=manifest;compare()
                } else {guard manifest == inventory.manifest else {throw BackupFailure("Source snapshot changed. Synchronize again.")}}
                send("sync-result",manifest:manifest,sync:.init(id:message.id,direction:message.direction,accepted:true))
                finishSync(manifest.entries.count)
            } catch {send("sync-result",sync:.init(id:message.id,direction:message.direction,message:error.localizedDescription,accepted:false));cancelSync(message:error.localizedDescription,notify:false)}
        case "sync-result":
            guard syncID == message.id,syncDirection == message.direction else {return}
            guard message.accepted == true,let manifest=packet.manifest,let inventory=syncInventory else {cancelSync(message:message.message ?? "The other Mac could not apply this set.",notify:false);return}
            do {
                guard inventoryIsCurrent(inventory) else {throw BackupFailure("Local set changed. Check both sets before continuing.")}
                if message.direction == .receive {
                    guard let player=source,remoteInventory?.manifest == manifest else {throw BackupFailure("Remote snapshot changed.")}
                    let plan=try BackupSyncPlan.make(source:manifest,destination:inventory.manifest)
                    try player.applySynchronizedSet(plan,inventory:inventory.input)
                    let updated=BackupSyncInventory(input:player.backupInput(),manifest:manifest,token:UUID(),stamp:stamps(player.backupInput()))
                    syncBaseline=updated.input.signature;publishInventory(updated)
                } else {guard manifest == inventory.manifest else {throw BackupFailure("Received an unexpected sync result.")}}
                remote=manifest;compare();finishSync(manifest.entries.count)
            } catch {cancelSync(message:error.localizedDescription)}
        case "sync-cancel":
            guard syncID == message.id || incomingSyncID == message.id else {return};cancelSync(message:"Other Mac cancelled or changed its set.",notify:false)
        default:break
        }
    }
    private var playbackSetIsCurrent:Bool {
        guard let source else {return false};let input=source.backupInput()
        return input.playbackConfiguration == verifiedPlaybackConfiguration && fileStamp == stamps(input)
    }
    var canEnablePlayback:Bool {canSync && verified && peerSupportsPlayback && playbackSetIsCurrent && source?.acceptsLinkedPlayback == true}
    func setPlaybackLinked(_ enabled:Bool) {
        guard enabled else {disablePlayback("Linked Playback is off. Audio continues locally.");return}
        guard canEnablePlayback,let player=source else {playbackStatus="Update both Macs, synchronize the set, pause and unlock both players first.";return}
        playbackToken=UUID();playSequence=0;receivedPlaySequence=0
        playbackConfiguration=player.backupInput().playbackConfiguration;playbackRequested=true
        sendPlaybackArm();updatePlaybackActivation()
    }
    private func sendPlaybackArm() {
        guard let token=playbackToken,let manifest=local else {return}
        send("transport-arm",playback:.init(token:token,sequence:0,enabled:true,fingerprint:manifest.playbackFingerprint))
    }
    private func updatePlaybackActivation() {
        guard playbackRequested,peerPlaybackRequested,let local,local.playbackFingerprint == peerPlaybackFingerprint,connected else {
            playbackStatus=playbackRequested ? "Waiting: enable Linked Playback on the other Mac while paused.":"Linked Playback is off.";return
        }
        let wasActive=linkedPlayback;linkedPlayback=true;source?.linkedFollower = role == .backup
        playbackStatus=role == .primary ? "Linked · Primary A controls both Macs":"Linked · Backup B follows A; your buttons control the pair"
        if !wasActive {lastPlayKey="";lastPlaySent=0;broadcastPlayback(force:true)}
    }
    private func disablePlayback(_ message:String,notify:Bool=true) {
        let hadLink=playbackRequested || linkedPlayback || peerPlaybackRequested
        if notify,hadLink {send("transport-arm",playback:.init(token:playbackToken ?? UUID(),sequence:0,enabled:false))}
        playbackRequested=false;linkedPlayback=false;peerPlaybackRequested=false;playbackToken=nil;peerPlaybackToken=nil
        playbackConfiguration=nil;peerPlaybackFingerprint=nil;source?.linkedFollower=false;source?.resetLinkedRate();autoAlign=false;timingDriftMS=nil;lastRemoteState=nil;receivedPlaySequence=0
        if hadLink {playbackStatus=message}
    }
    private func playbackIsCurrent()->Bool {
        guard linkedPlayback,let player=source else {return false}
        guard player.acceptsLinkedPlayback,player.error == nil,player.backupInput().playbackConfiguration == playbackConfiguration else {
            disablePlayback("Controls locked, audio error or set changed. Linked Playback disabled; audio unchanged.");return false
        }
        return true
    }
    private func forwardPlaybackAction(_ action:BackupPlayAction)->Bool {
        guard playbackIsCurrent(),role == .backup,let token=peerPlaybackToken,let manifest=local,action.valid else {return false}
        playSequence += 1
        send("transport-request",playback:.init(token:token,sequence:playSequence,fingerprint:manifest.playbackFingerprint,action:action))
        return true
    }
    private func broadcastPlayback(force:Bool=false) {
        guard role == .primary,linkedPlayback,let player=source else {return}
        if player.error != nil {disablePlayback("Audio error on Primary A. Linked Playback disabled.");return}
        guard let state=player.linkedPlaybackState,let token=peerPlaybackToken,let manifest=local else {return}
        let key="\(state.index):\(state.playing):\(state.crossfading)"
        let now=ProcessInfo.processInfo.systemUptime
        let expected=lastPlaySeconds+(state.playing ? now-lastPlaySent:0)
        guard force || key != lastPlayKey || now-lastPlaySent>=0.5 || abs(state.seconds-expected)>0.2 else {return}
        guard playbackIsCurrent() else {return}
        lastPlayKey=key;lastPlaySent=now;lastPlaySeconds=state.seconds;playSequence += 1
        send("transport-state",playback:.init(token:token,sequence:playSequence,fingerprint:manifest.playbackFingerprint,state:state,sentAt:now,positionJump:abs(state.seconds-expected)>0.2))
    }
    private func handlePlayback(_ packet:Packet) {
        guard peerSupportsPlayback,let message=packet.playback else {return}
        if packet.kind == "transport-arm" {
            guard message.enabled == true else {disablePlayback("Other Mac turned Linked Playback off. Audio continues locally.",notify:false);return}
            guard verified,playbackSetIsCurrent,!syncing,!scanning,let player=source,player.canSynchronizeSet,player.acceptsLinkedPlayback,
                  message.fingerprint == local?.playbackFingerprint else {
                send("transport-arm",playback:.init(token:UUID(),sequence:0,enabled:false));playbackStatus="Pause both Macs and synchronize matching sets before linking playback.";return
            }
            peerPlaybackRequested=true;peerPlaybackToken=message.token;peerPlaybackFingerprint=message.fingerprint;updatePlaybackActivation();return
        }
        guard playbackIsCurrent(),message.token == playbackToken,message.sequence>receivedPlaySequence,
              message.fingerprint == local?.playbackFingerprint,let player=source else {return}
        receivedPlaySequence=message.sequence
        if packet.kind == "transport-request",role == .primary,let action=message.action {
            player.performLinkedAction(action);broadcastPlayback(force:true)
        }else if packet.kind == "transport-state",role == .backup,let state=message.state,
                  let manifest=local,manifest.entries.indices.contains(state.index),state.seconds<=Double(manifest.entries[state.index].durationMS)/1000+1 {
            let now=ProcessInfo.processInfo.systemUptime
            let age=message.sentAt.map {now-($0-clock.offset)} ?? 0
            let validClock=timingReady && message.sentAt != nil && age>=(-0.02) && age<1
            let target=min(Double(manifest.entries[state.index].durationMS)/1000,max(0,state.seconds+(state.playing && validClock ? max(0,age):0)+(state.playing ? manualOffsetMS/1000:0)))
            let drift=(target-player.linkedPosition)*1000
            let sameCue=lastRemoteState?.index==state.index && player.currentID==player.tracks[state.index].id
            let discontinuity=message.positionJump == true || lastRemoteState == nil
            let smooth=autoAlign && validClock && sameCue && !discontinuity && state.playing && player.playing && !state.crossfading
            if sameCue {timingDriftMS=drift}
            if !validClock {timingStatus="Unstable link"}
            else if abs(drift)>250 && smooth {timingStatus="Large offset · Align Now required"}
            else {timingStatus=abs(drift)<=15 ? "Synced":smooth ? "Correcting":"Offset detected"}
            let adjusted=BackupPlayState(index:state.index,seconds:target,playing:state.playing,crossfading:state.crossfading)
            player.followLinkedPlayback(adjusted,allowPositionJump:!autoAlign || !sameCue || discontinuity || !state.playing)
            if smooth,abs(drift)<=250 {
                player.correctLinkedRate(errorSeconds:drift/1000)
            }else {player.resetLinkedRate()}
            lastRemoteState=state;lastRemoteAt=now
            if peerSupportsTiming {send("clock-report",probe:.init(id:UUID(),sent:now,driftMS:sameCue ? drift:nil,status:timingStatus))}
        }
    }
    func alignNow() {
        guard role == .backup,linkedPlayback,timingReady,let state=lastRemoteState,let player=source,player.acceptsLinkedPlayback else {return}
        let age=ProcessInfo.processInfo.systemUptime-lastRemoteAt
        guard age<2 else {return}
        player.resetLinkedRate()
        player.followLinkedPlayback(.init(index:state.index,seconds:max(0,state.seconds+(state.playing ? age:0)+manualOffsetMS/1000),playing:state.playing,crossfading:state.crossfading))
    }
    private func drop(_ message:String) {
        peerSupportsTiming=false;clock=SyncClockEstimate();pendingProbes=[:];timingRTT=0;timingJitter=0;timingStatus="Not measured"
disablePlayback("Link lost · local audio continues independently.",notify:false);peerSupportsPlayback=false;cancelSync(message:"Connection closed. No pending sync will be applied.",notify:false);peerSupportsSync=false;connection?.stateUpdateHandler=nil;connection?.cancel();connection=nil;timer?.invalidate();timer=nil;connected=false;remote=nil;incoming.removeAll();issues=[];peerName="";status=message}
    func shutdownPlayer() {disconnect();source?.pause()}
    func disconnect() {epoch=UUID();drop("Disconnected");listener?.cancel();listener=nil;browser?.cancel();browser=nil;peers=[];code="";listening=false}
}
