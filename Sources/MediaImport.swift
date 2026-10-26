import AppKit
import AVFoundation
import UniformTypeIdentifiers

/// One shared import queue for Finder, file dialogs and every playlist window.
final class MediaImport: NSObject {
    static let shared = MediaImport()
    static let extensions: Set<String> = ["mp3","m4a","aac","wav","wave","aif","aiff","aifc","flac","alac","caf","ogg","oga","opus","wma","ape","wv","mka","ac3","eac3","dts","amr","au","snd","mp2","mp4","m4v","mov","mkv","webm","avi","wmv","mpeg","mpg","mts","m2ts","3gp","3g2","vob","ts"]
    static func accepts(_ url: URL) -> Bool {
        extensions.contains(url.pathExtension.lowercased()) || UTType(filenameExtension:url.pathExtension).map { $0.conforms(to:.audio) || $0.conforms(to:.movie) } == true
    }
    enum Quality {case auto, aac, wav}
    private var quality:Quality = .auto
    private var pending: [URL] = []
    private var task: Task<Void,Never>?
    private var cancelled = false
    private var session: AVAssetExportSession?
    private var process: Process?
    private var panel: NSPanel?
    private var label: NSTextField?
    private var progress: NSProgressIndicator?
    private var timer: Timer?
    static var ffmpeg: URL? {
        [Bundle.main.resourceURL?.appendingPathComponent("ffmpeg"), URL(fileURLWithPath:"/opt/homebrew/bin/ffmpeg"), URL(fileURLWithPath:"/usr/local/bin/ffmpeg")].compactMap {$0}.first {FileManager.default.isExecutableFile(atPath:$0.path)}
    }
    func enqueue(_ urls: [URL]) {
        if task == nil, urls.contains(where: {UTType(filenameExtension:$0.pathExtension)?.conforms(to:.movie) == true || ["mkv","webm","avi","wmv","mts","m2ts","vob","ts"].contains($0.pathExtension.lowercased())}) {
            let alert=NSAlert();alert.messageText="Extract audio from video";alert.informativeText="Auto preserves compatible compressed audio; otherwise it uses high-quality AAC. Choose WAV for uncompressed audio. Original files are never changed."
            for title in ["Auto", "AAC · Compact", "WAV · Uncompressed", "Cancel"] {alert.addButton(withTitle:title)}
            let response=alert.runModal()
            if response.rawValue == 1003 {return}
            quality=response.rawValue == 1002 ? .wav : response.rawValue == 1001 ? .aac : .auto
        } else if task == nil {quality = .auto}
        pending += urls
        guard task == nil else { return }
        cancelled = false
        task = Task { @MainActor in self.showPanel(); await self.run() }
    }
    @objc func cancelImport() {
        cancelled = true; pending.removeAll(); session?.cancelExport()
        if let process, process.isRunning { process.terminate() }
        label?.stringValue = "Cancelling…"
    }
    private func showPanel() {
        let window = NSPanel(contentRect:NSRect(x:0,y:0,width:420,height:140),styleMask:[.titled],backing:.buffered,defer:false)
        window.title = "Import Audio / Video"
        let text = NSTextField(labelWithString:"Preparing media…");text.frame=NSRect(x:20,y:94,width:380,height:22);text.lineBreakMode = .byTruncatingMiddle
        let bar=NSProgressIndicator(frame:NSRect(x:20,y:67,width:380,height:16));bar.minValue=0;bar.maxValue=100;bar.isIndeterminate=true;bar.startAnimation(nil)
        let button=NSButton(title:"Cancel Import",target:self,action:#selector(cancelImport));button.frame=NSRect(x:270,y:18,width:130,height:30)
        window.contentView?.addSubview(text);window.contentView?.addSubview(bar);window.contentView?.addSubview(button)
        panel=window;label=text;progress=bar;window.center();window.orderFront(nil)
        timer=Timer.scheduledTimer(withTimeInterval:0.2,repeats:true) { [weak self] _ in
            Task { @MainActor in
                guard let self, let session=self.session else {return}
                self.progress?.isIndeterminate=false;self.progress?.doubleValue=Double(session.progress)*100
            }
        }
    }
    @MainActor private func run() async {
        var failures:[String]=[]
        defer {timer?.invalidate();timer=nil;panel?.orderOut(nil);panel=nil;session=nil;process=nil;task=nil}
        while !pending.isEmpty && !cancelled {
            let source=pending.removeFirst()
            let scoped=source.startAccessingSecurityScopedResource()
            do {
                label?.stringValue=source.lastPathComponent;progress?.isIndeterminate=true;progress?.startAnimation(nil)
                let result=try await prepare(source)
                if cancelled || SetupLock.shared.editsBlocked || ControlLock.shared.isLocked {
                    if result != source {try? FileManager.default.removeItem(at:result)}
                } else {Player.shared.addPrepared([result],importedTitle:result == source ? nil : source.deletingPathExtension().lastPathComponent)}
            } catch {if !cancelled {failures.append("\(source.lastPathComponent): \(error.localizedDescription)")}}
            if scoped {source.stopAccessingSecurityScopedResource()}
        }
        if !failures.isEmpty {Player.shared.error=failures.joined(separator:"\n")}
    }
    @MainActor func prepare(_ source:URL, directory:URL? = nil, format:Quality? = nil) async throws -> URL {
        let selected=format ?? quality
        let asset=AVURLAsset(url:source)
        let audio=(try? await asset.loadTracks(withMediaType:.audio)) ?? []
        let video=(try? await asset.loadTracks(withMediaType:.video)) ?? []
        if selected == .auto, video.isEmpty, UTType(filenameExtension:source.pathExtension)?.conforms(to:.movie) != true, !audio.isEmpty, (try? await asset.load(.isPlayable)) == true {return source}
        let folder=try directory ?? FileManager.default.url(for:.applicationSupportDirectory,in:.userDomainMask,appropriateFor:nil,create:true).appendingPathComponent("HardPlay/Imported Audio",isDirectory:true)
        try FileManager.default.createDirectory(at:folder,withIntermediateDirectories:true)
        let stem=source.deletingPathExtension().lastPathComponent + "-" + UUID().uuidString
        let output=folder.appendingPathComponent(stem).appendingPathExtension("m4a")
        var completed=false
        defer {session=nil;if !completed {try? FileManager.default.removeItem(at:output)}}
        if selected == .wav, !audio.isEmpty {
            let wav=folder.appendingPathComponent(stem).appendingPathExtension("wav")
            do {try await writeWAV(asset:asset,to:wav);return wav}
            catch {try? FileManager.default.removeItem(at:wav);if cancelled {throw error}}
        }
        if selected != .wav, let first=audio.first {
            let composition=AVMutableComposition()
            guard let track=composition.addMutableTrack(withMediaType:.audio,preferredTrackID:kCMPersistentTrackID_Invalid) else {throw BackupFailure("Cannot create an audio track.")}
            try track.insertTimeRange(try await first.load(.timeRange),of:first,at:.zero)
            // Rewrap compatible compressed audio first; otherwise use Apple's high-quality AAC preset.
            for preset in (selected == .aac ? [AVAssetExportPresetAppleM4A] : [AVAssetExportPresetPassthrough,AVAssetExportPresetAppleM4A]) {
                guard !cancelled else {throw CancellationError()}
                try? FileManager.default.removeItem(at:output)
                guard let exporter=AVAssetExportSession(asset:composition,presetName:preset),exporter.supportedFileTypes.contains(.m4a) else {continue}
                session=exporter;exporter.outputURL=output;exporter.outputFileType = .m4a
                await exporter.export()
                if exporter.status == .completed {completed=true;return output}
            }
        }
        guard !cancelled else {throw CancellationError()}
        guard let executable=Self.ffmpeg else {throw BackupFailure(audio.isEmpty && !video.isEmpty ? "This video has no readable audio track. For additional codecs, install FFmpeg and retry." : "macOS cannot convert this format. Install FFmpeg for additional codecs, then retry.")}
        // No shell and no network input. Decode only the first audio stream to 24-bit PCM WAV.
        let wav=folder.appendingPathComponent(stem).appendingPathExtension(selected == .aac ? "m4a" : "wav")
        let encoding=selected == .aac ? ["-c:a","aac","-b:a","256k"] : ["-c:a","pcm_s24le"]
        let job=Process();job.executableURL=executable;job.arguments=["-nostdin","-v","error","-protocol_whitelist","file,pipe,crypto,data","-i",source.path,"-map","0:a:0","-vn"] + encoding + ["-n",wav.path]
        job.standardOutput=FileHandle.nullDevice;job.standardError=FileHandle.nullDevice
        process=job;session=nil;progress?.isIndeterminate=true;progress?.startAnimation(nil)
        do {
            let status:Int32=try await withCheckedThrowingContinuation { continuation in
                job.terminationHandler={continuation.resume(returning:$0.terminationStatus)}
                do {try job.run()} catch {job.terminationHandler=nil;continuation.resume(throwing:error)}
            }
            guard !cancelled,status == 0,(try? AVAudioFile(forReading:wav).length) ?? 0 > 0 else {throw BackupFailure("Conversion failed: no decodable audio stream, a protected file, or a damaged file.")}
            process=nil;return wav
        } catch {process=nil;try? FileManager.default.removeItem(at:wav);throw error}
    }
    @MainActor private func writeWAV(asset:AVAsset,to destination:URL) async throws {
        guard let track=try await asset.loadTracks(withMediaType:.audio).first else {throw BackupFailure("No audio track found.")}
        let reader=try AVAssetReader(asset:asset)
        let output=AVAssetReaderTrackOutput(track:track,outputSettings:[AVFormatIDKey:kAudioFormatLinearPCM,AVLinearPCMBitDepthKey:32,AVLinearPCMIsFloatKey:true,AVLinearPCMIsBigEndianKey:false,AVLinearPCMIsNonInterleaved:false])
        guard reader.canAdd(output) else {throw BackupFailure("Cannot decode this audio stream to WAV.")}
        reader.add(output);guard reader.startReading() else {throw reader.error ?? BackupFailure("Cannot start audio decoder.")}
        defer {reader.cancelReading()}
        var file:AVAudioFile?
        var written:Int64=0
        let duration=try await asset.load(.duration).seconds
        while let sample=output.copyNextSampleBuffer() {
            guard !cancelled else {throw CancellationError()}
            guard let description=CMSampleBufferGetFormatDescription(sample),let asbd=CMAudioFormatDescriptionGetStreamBasicDescription(description),let format=AVAudioFormat(streamDescription:asbd),let block=CMSampleBufferGetDataBuffer(sample) else {throw BackupFailure("Invalid decoded audio buffer.")}
            if file == nil {file=try AVAudioFile(forWriting:destination,settings:format.settings,commonFormat:.pcmFormatFloat32,interleaved:true)}
            let frames=CMSampleBufferGetNumSamples(sample)
            guard frames>0,let buffer=AVAudioPCMBuffer(pcmFormat:format,frameCapacity:AVAudioFrameCount(frames)) else {continue}
            buffer.frameLength=AVAudioFrameCount(frames)
            let target=buffer.mutableAudioBufferList.pointee.mBuffers
            let size=CMBlockBufferGetDataLength(block)
            guard size<=Int(target.mDataByteSize),let pointer=target.mData,CMBlockBufferCopyDataBytes(block,atOffset:0,dataLength:size,destination:pointer) == noErr else {throw BackupFailure("Cannot copy decoded audio.")}
            try file?.write(from:buffer);written += Int64(frames)
            progress?.isIndeterminate=false
            if duration>0 {progress?.doubleValue=min(100,Double(written)/format.sampleRate/duration*100)}
            await Task.yield()
        }
        guard reader.status == .completed,written>0 else {throw reader.error ?? BackupFailure("No audio samples could be decoded.")}
    }

}
