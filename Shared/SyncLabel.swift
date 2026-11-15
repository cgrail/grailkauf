import SwiftUI

/// "Updated 5 min ago": when this device's copy of the list last matched iCloud.
struct SyncLabel: View {
    let lastSync: Date?

    var body: some View {
        if let lastSync {
            Text("Updated \(Text(lastSync, style: .relative)) ago")
        } else {
            Text("Not synced with iCloud yet")
        }
    }
}
