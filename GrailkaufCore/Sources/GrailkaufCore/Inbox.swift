import Foundation

/// Text that the share extension received, kept for the app.
/// The extension cannot open the list, because the list is in the app's own folder.
public enum Inbox {
    /// The App Group that the app and the share extension both read.
    public static let group = "group.de.grails.grailkauf"
    private static let key = "inbox"

    /// Adds the text after the text that waits already.
    public static func put(_ text: String, in defaults: UserDefaults) {
        let waiting = defaults.string(forKey: key).map { $0 + "\n" } ?? ""
        defaults.set(waiting + text, forKey: key)
    }

    public static func text(in defaults: UserDefaults) -> String? { defaults.string(forKey: key) }

    /// Removes the text that the app added. Text that the extension put in meanwhile stays.
    public static func remove(_ text: String, from defaults: UserDefaults) {
        guard let waiting = defaults.string(forKey: key), waiting.hasPrefix(text) else { return }
        let rest = waiting.dropFirst(text.count).drop { $0 == "\n" }
        if rest.isEmpty { defaults.removeObject(forKey: key) } else { defaults.set(String(rest), forKey: key) }
    }
}
