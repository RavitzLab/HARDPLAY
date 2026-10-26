import Foundation
import AVFoundation

@MainActor func runMediaImportTests() async throws {
    let fm=FileManager.default
    let folder=URL(fileURLWithPath:NSTemporaryDirectory()).appendingPathComponent("hardplay-import-test-\(UUID())")
    try fm.createDirectory(at:folder,withIntermediateDirectories:true)
    defer {try? fm.removeItem(at:folder)}
    let source=folder.appendingPathComponent("tone.wav")
    let format=AVAudioFormat(standardFormatWithSampleRate:48000,channels:2)!
    do {
        let file=try AVAudioFile(forWriting:source,settings:[AVFormatIDKey:kAudioFormatLinearPCM,AVSampleRateKey:48000,AVNumberOfChannelsKey:2,AVLinearPCMBitDepthKey:16,AVLinearPCMIsFloatKey:false])
        let buffer=AVAudioPCMBuffer(pcmFormat:format,frameCapacity:48000)!;buffer.frameLength=48000
        for i in 0..<48000 {for channel in 0..<2 {buffer.floatChannelData![channel][i]=Float(sin(Double(i)*0.04)*0.2)}}
        try file.write(from:buffer)
    }
    let original=try Data(contentsOf:source)
    let importer=MediaImport()
    let direct=try await importer.prepare(source,directory:folder)
    precondition(direct == source)
    print("IMPORT TEST: direct WAV passed")
    let picture=folder.appendingPathComponent("silent-video.mov")
    let writer=try AVAssetWriter(outputURL:picture,fileType:.mov)
    let input=AVAssetWriterInput(mediaType:.video,outputSettings:[AVVideoCodecKey:AVVideoCodecType.h264,AVVideoWidthKey:32,AVVideoHeightKey:32])
    let adaptor=AVAssetWriterInputPixelBufferAdaptor(assetWriterInput:input,sourcePixelBufferAttributes:[kCVPixelBufferPixelFormatTypeKey as String:kCVPixelFormatType_32ARGB,kCVPixelBufferWidthKey as String:32,kCVPixelBufferHeightKey as String:32])
    writer.add(input);guard writer.startWriting() else {throw writer.error!};writer.startSession(atSourceTime:.zero)
    for frame in 0..<2 {
        while !input.isReadyForMoreMediaData {try await Task.sleep(for:.milliseconds(10))}
        var pixel:CVPixelBuffer?;CVPixelBufferCreate(nil,32,32,kCVPixelFormatType_32ARGB,nil,&pixel)
        guard let pixel else {throw BackupFailure("Cannot create video frame")}
        CVPixelBufferLockBaseAddress(pixel,[]);memset(CVPixelBufferGetBaseAddress(pixel),0,CVPixelBufferGetDataSize(pixel));CVPixelBufferUnlockBaseAddress(pixel,[])
        guard adaptor.append(pixel,withPresentationTime:CMTime(value:Int64(frame),timescale:2)) else {throw writer.error ?? BackupFailure("Cannot append video frame")}
    }
    writer.endSession(atSourceTime:CMTime(seconds:1,preferredTimescale:48000));input.markAsFinished();await writer.finishWriting()
    guard writer.status == .completed else {throw writer.error ?? BackupFailure("Cannot finish video fixture")}
    print("IMPORT TEST: silent H264 MOV fixture created")
    let composition=AVMutableComposition()
    let inputs:[(AVURLAsset,AVMediaType)]=[(AVURLAsset(url:source),.audio),(AVURLAsset(url:picture),.video)]
    for (asset,type) in inputs {
        let track=try await asset.loadTracks(withMediaType:type).first!
        let range=try await track.load(.timeRange)
        try composition.addMutableTrack(withMediaType:type,preferredTrackID:kCMPersistentTrackID_Invalid)!.insertTimeRange(range,of:track,at:.zero)
    }
    let movie=folder.appendingPathComponent("video-with-audio.mov")
    let exporter=AVAssetExportSession(asset:composition,presetName:AVAssetExportPresetHighestQuality)!
    exporter.outputURL=movie;exporter.outputFileType = .mov
    print("IMPORT TEST: exporting movie")
    await exporter.export()
    guard exporter.status == .completed else {throw exporter.error ?? BackupFailure("Cannot generate movie fixture")}
    print("IMPORT TEST: combined movie created")
    let movieBytes=try Data(contentsOf:movie)
    let result=try await importer.prepare(movie,directory:folder)
    precondition(result != movie && result.pathExtension == "m4a")
    let asset=AVURLAsset(url:result)
    let audio=try await asset.loadTracks(withMediaType:.audio),video=try await asset.loadTracks(withMediaType:.video)
    let duration=try await asset.load(.duration).seconds
    precondition(audio.count == 1 && video.isEmpty && abs(duration-1)<0.1)
    print("IMPORT TEST: Auto extraction passed")
    let aac=try await importer.prepare(movie,directory:folder,format:.aac)
    let aacDuration=try await AVURLAsset(url:aac).load(.duration).seconds;precondition(abs(aacDuration-1)<0.1)
    let wave=try await importer.prepare(movie,directory:folder,format:.wav)
    let waveFile=try AVAudioFile(forReading:wave)
    precondition(wave.pathExtension == "wav" && abs(Double(waveFile.length)/waveFile.processingFormat.sampleRate-1)<0.01)
    do {_ = try await importer.prepare(picture,directory:folder);throw BackupFailure("Silent video accepted")} catch let failure as BackupFailure {precondition(failure.message != "Silent video accepted")}
    let afterSource=try Data(contentsOf:source);precondition(afterSource == original)
    let afterMovie=try Data(contentsOf:movie);precondition(afterMovie == movieBytes)
    let broken=folder.appendingPathComponent("broken.mp4");try Data("not media".utf8).write(to:broken)
    do {_ = try await importer.prepare(broken,directory:folder);throw BackupFailure("Broken media accepted")} catch let failure as BackupFailure {precondition(failure.message != "Broken media accepted")}
    let beforeCancel=try fm.contentsOfDirectory(atPath:folder.path).sorted()
    importer.cancelImport()
    do {_ = try await importer.prepare(movie,directory:folder,format:.wav);throw BackupFailure("Cancelled export completed")} catch is CancellationError {} 
    let afterCancel=try fm.contentsOfDirectory(atPath:folder.path).sorted();precondition(beforeCancel == afterCancel)
    precondition(MediaImport.accepts(URL(fileURLWithPath:"/tmp/sample.mkv")))
    precondition(!MediaImport.accepts(URL(fileURLWithPath:"/tmp/readme.txt")))
    print("PASS: direct audio preserved; MOV to Auto/AAC/WAV; duration verified; originals unchanged; corrupt/silent video rejected; cancellation cleans partial output")
}
