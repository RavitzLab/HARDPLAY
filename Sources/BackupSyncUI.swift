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

struct BackupConnectionButton:View {
    @ObservedObject private var link=BackupLink.shared
    private var color:Color {link.verified ? .green:link.syncing ? accent:link.connected ? .orange:.secondary}
    private var state:String {link.syncing ? "Synchronizing":link.verified ? "Sets match":link.connected ? "Connected · sets unchecked or different":link.listening ? "Waiting for peer":"Offline"}
    var body:some View {
        Button {AppDelegate.shared.showBackupWindow()} label:{
            HStack(spacing:5) {
                Image(systemName:link.verified ? "checkmark.circle":"arrow.triangle.2.circlepath").font(.system(size:14))
                VStack(spacing:2) {Text(link.role == .primary ? "A":"B").font(.system(size:10,weight:.bold));Circle().fill(color).frame(width:5,height:5)}
            }.frame(width:42,height:32)
        }.buttonStyle(PlayerControlStyle(active:link.connected)).accessibilityLabel("Backup Sync Settings")
            .accessibilityValue(link.role.rawValue+" · "+state+" · Timecode inactive")
            .stageHint(link.role.rawValue+" · "+state+". Open Timecode & Backup. Timecode is not active; this indicator reports connection and set matching.")
    }
}
