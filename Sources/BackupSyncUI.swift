import SwiftUI

struct BackupSetSyncControls:View {
    @ObservedObject var link:BackupLink
    var blocked=false
    var body:some View {
        VStack(alignment:.leading,spacing:12) {
            Text("2 · Synchronize Set").font(.stage(.headline))
            Text("Load your audio on both Macs. Choose the source; order and settings are matched automatically by file contents.").font(.stage(.callout)).foregroundStyle(.secondary)
            Menu {
                Button("This Mac → Other Mac") {link.beginSync(.send)}
                Button("Other Mac → This Mac") {link.beginSync(.receive)}
            } label:{Label("Synchronize Set…",systemImage:"arrow.triangle.2.circlepath").font(.stage(size:14)).padding(8)}
                .buttonStyle(PlayerControlStyle(primary:true)).disabled(blocked || !link.canSync).accessibilityLabel("Synchronize Set")
            if !link.connected {Text("Connect the two Macs first.").font(.stage(.caption)).foregroundStyle(.secondary)}
            else if !link.peerSupportsSync {Text("Update Hard Play on both Macs to enable set sync.").font(.stage(.caption)).foregroundStyle(.secondary)}
            else if !link.syncing {Text("Both Macs must be paused and unlocked. Your audio outputs stay local.").font(.stage(.caption)).foregroundStyle(.secondary)}
            if link.syncing && link.syncReview == nil {ProgressView().controlSize(.small)}
            if let review=link.syncReview {
                VStack(alignment:.leading,spacing:8) {
                    Text(review.title).font(.stage(.headline)).fixedSize(horizontal:false,vertical:true)
                    Text("Replace the destination queue (\(review.plan.destination.entries.count) cues) with “\(review.plan.source.name)” (\(review.plan.source.entries.count) cues).")
                        .font(.stage(.callout)).fixedSize(horizontal:false,vertical:true)
                    Text("Order · names · crossfades · start points · saved positions · Next/Stop · Repeat · Shuffle. Local audio files and output routing are preserved.")
                        .font(.stage(.caption)).foregroundStyle(.secondary)
                    if review.plan.missing.isEmpty {
                        Text("All audio matched. No files need to be copied.").font(.stage(.callout)).foregroundStyle(accent)
                    } else {
                        Text("Missing audio on destination:").font(.stage(.callout)).foregroundStyle(.orange)
                        ForEach(Array(review.plan.missing.prefix(8).enumerated()),id:\.offset) {_,title in Text("• "+title).font(.stage(.caption)).lineLimit(2)}
                        if review.plan.missing.count>8 {Text("…and \(review.plan.missing.count-8) more cues").font(.stage(.caption))}
                        Text("Add the matching original files on the destination Mac, then synchronize again. No partial replacement is applied.").font(.stage(.caption)).foregroundStyle(.secondary)
                    }
                    HStack {
                        Button("Apply Sync") {link.applySync()}.buttonStyle(PlayerControlStyle(primary:true)).disabled(blocked || !review.plan.ready)
                        Button("Cancel") {link.cancelSync()}.buttonStyle(PlayerControlStyle())
                    }
                    Text("Apply stays paused. Undo on the destination restores its previous queue and playback settings; save the received set as a new playlist.").font(.stage(.caption)).foregroundStyle(.secondary)
                }.padding(12).background(accent.opacity(0.08),in:RoundedRectangle(cornerRadius:10))
            } else if link.syncing {Button("Cancel Sync") {link.cancelSync()}.font(.stage(.caption))}
            if !link.syncStatus.isEmpty {Text(link.syncStatus).font(.stage(.callout)).foregroundStyle(accent).fixedSize(horizontal:false,vertical:true)}
        }.padding(12).frame(maxWidth:.infinity,alignment:.leading).background(.white.opacity(0.035),in:RoundedRectangle(cornerRadius:12))
    }
}

struct BackupLinkedPlaybackControls:View {
    @ObservedObject var link:BackupLink
    var blocked=false
    var body:some View {
        VStack(alignment:.leading,spacing:10) {
            Text("3 · Linked Playback").font(.stage(.headline))
            Toggle("Link Play / Pause / Next",isOn:Binding(get:{link.playbackRequested},set:{link.setPlaybackLinked($0)}))
                .toggleStyle(.switch).disabled(blocked || (!link.playbackRequested && !link.canEnablePlayback))
                .accessibilityLabel("Linked Playback")
            Text(link.playbackStatus).font(.stage(.callout)).foregroundStyle(link.linkedPlayback ? .green:accent).fixedSize(horizontal:false,vertical:true)
            Text("Enable on both Macs while paused, after synchronizing the set. Primary A drives playback; buttons on either Mac control the pair. Seek, track changes, Repeat and Shuffle follow A. Each Mac keeps its own audio output and volume.")
                .font(.stage(.caption)).foregroundStyle(.secondary).fixedSize(horizontal:false,vertical:true)
            if !link.peerSupportsPlayback {Text("Both Macs need Hard Play 0.36.2 or newer.").font(.stage(.caption)).foregroundStyle(.orange)}
            else if !link.verified {Text("Synchronize or check both sets first.").font(.stage(.caption)).foregroundStyle(.secondary)}
            Text("Linked control over LAN, not sample-accurate timecode. A disconnect disables the link; local playback continues. Reconnect and enable the link again manually.")
                .font(.stage(.caption)).foregroundStyle(.secondary).fixedSize(horizontal:false,vertical:true)
        }.padding(12).frame(maxWidth:.infinity,alignment:.leading).background(accent.opacity(0.07),in:RoundedRectangle(cornerRadius:12))
    }
}

struct BackupConnectionButton:View {
    @ObservedObject private var link=BackupLink.shared
    private var color:Color {link.linkedPlayback ? .green:link.syncing ? accent:link.connected ? .orange:.secondary}
    private var state:String {link.linkedPlayback ? "Playback linked":link.playbackRequested ? "Waiting for playback link":link.syncing ? "Synchronizing":link.verified ? "Sets match · Playback OFF":link.connected ? "Connected · sets unchecked or different":link.listening ? "Waiting for peer":"Offline"}
    var body:some View {
        Button {AppDelegate.shared.showBackupWindow()} label:{
            HStack(spacing:5) {
                Image(systemName:link.linkedPlayback ? "play.circle":"arrow.triangle.2.circlepath").font(.system(size:14))
                VStack(spacing:2) {Text(link.role == .primary ? "A":"B").font(.system(size:10,weight:.bold));Circle().fill(color).frame(width:5,height:5)}
            }.frame(width:42,height:32)
        }.buttonStyle(PlayerControlStyle(active:link.connected)).accessibilityLabel("Backup Sync Settings")
            .accessibilityValue(link.role.rawValue+" · "+state+" · Timecode inactive")
            .stageHint(link.role.rawValue+" · "+state+". Open Timecode & Backup. Timecode is not active; this indicator reports connection, set matching and Linked Playback.")
    }
}
