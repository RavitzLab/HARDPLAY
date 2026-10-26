import SwiftUI

enum PlaylistSort:String,CaseIterable {
    case number="Track number · low to high",numberDescending="Track number · high to low"
    case name="Name · A–Z",nameDescending="Name · Z–A"
    case newest="Added · newest first",oldest="Added · oldest first"
    case filename="Filename · A–Z",format="Audio format",reverse="Reverse order",random="Random order"
}
struct PlaylistSortMenu:View {
    @ObservedObject var player:Player
    @ObservedObject private var setup=SetupLock.shared
    @ObservedObject private var lock=ControlLock.shared
    var body:some View {
        Menu {ForEach(PlaylistSort.allCases,id:\.self) {order in Button(order.rawValue) {player.sortQueue(order)}}} label:{Image(systemName:"arrow.up.arrow.down").font(.system(size:17,weight:.medium)).frame(width:30,height:30)}
            .menuStyle(.borderlessButton).fixedSize().accessibilityLabel("Sort Playlist")
            .stageHint("Sort the queue · Undo restores the previous order")
            .disabled(setup.editsBlocked || lock.isLocked || player.tracks.count<2)
    }
}
