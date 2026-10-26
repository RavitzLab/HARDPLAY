import AppKit
import SwiftUI

/// The status item always remains available; this preference chooses its player presentation.
final class MenuBarPresentation: ObservableObject {
    static let shared = MenuBarPresentation()
    @Published private(set) var attached: Bool
    private let defaults: UserDefaults
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        attached = defaults.object(forKey: "miniAttachedToMenuBar") == nil || defaults.bool(forKey: "miniAttachedToMenuBar")
    }
    func setAttached(_ value: Bool) { attached = value; defaults.set(value, forKey: "miniAttachedToMenuBar") }
}

enum MenuBarBadge: String {
    case empty, paused, playing, crossfade, error
    static func state(hasTrack: Bool, playing: Bool, crossfading: Bool, error: String?) -> Self {
        if playing { return crossfading ? .crossfade : .playing }
        if let error, !error.isEmpty { return .error }
        return hasTrack ? .paused : .empty
    }
    var title: String {
        switch self { case .empty: return "Ready"; case .paused: return "Paused"; case .playing: return "Playing"; case .crossfade: return "Crossfade"; case .error: return "Playback error" }
    }
    func image() -> NSImage {
        let image=HardPlayBrand.menuIcon(playing:self == .playing || self == .crossfade)
        image.accessibilityDescription="Hard Play — \(title)";return image
    }
}
