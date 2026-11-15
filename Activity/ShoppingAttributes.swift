import ActivityKit

/// What the Lock Screen shows while a shop is in progress.
struct ShoppingAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var done: Int
        var total: Int
        /// The item to pick up now, as typed. Nil when everything is bought.
        var current: String?
        /// The cleaned names of the next few items.
        var next: [String]
    }
}
