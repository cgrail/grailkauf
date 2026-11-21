# grailkauf
<img src="Shared/Assets.xcassets/AppIcon.appiconset/AppIcon.png" width="128" alt="App icon: a white shopping cart with bottles, an apple and a baguette on a blue background">

Smarte Einkaufsliste

A shared shopping list for one household, for iPhone and Apple Watch.
The list learns the order in which you pick up your items, and sorts itself in that order.

## What the app does

### List mode (iPhone)
- Type an item and press Enter. The item goes to the end of the list.
- A comma or a pasted text with many lines adds many items at once.
- While you type, the app suggests items that you added before.
- If the text field is empty, the app shows the items that are due again. "Fill with the usual" adds all of them.
- If you add an item that is on the list already, the app removes the older copy and keeps the new one. A notice shows the name for a few seconds.
- Tap the trash button of an item, or swipe the item, to delete it. Tap an item to change its text.
- Touch and hold an item, then drag it to a new place.
- Tap "Select" to select items. Slide a finger down the circles to select many items quickly, or tap "Select all". Tap the trash button at the bottom to delete the selected items. Tap the X to stop.
- The history keeps the items that you bought, also after you delete them from the list.
- Tap "Start dictation" above the text field and say your items, for example "Milch, zwei Liter Apfelsaft und Brot". The screen shows each item on its own line. To finish, say "fertig" or "done", or tap the stop button. Each item goes to the list.

### Menu and history (iPhone)
- Tap the menu button at the top left. The menu slides in from the left. Tap next to it to close it.
- The menu opens the settings and shows each past shopping trip, newest first.
- Each trip shows its date, its first items and how many of its items are not on the list now.
- Tap a trip to open it. Tap + to add an item to the list again.
- Below the items, a line counts the items of that trip that are already on the list. Tap the line to show them.

### Add from another app (iPhone)
- Share a text, for example a note, and tap "Grailkauf" in the share sheet. Each line becomes one item. List marks such as "✓" or "•" at the start of a line go away.
- If a note in Notes is shared with other people, select "Send Copy" at the top of the share sheet first.
- The items reach the list when Grailkauf opens on this iPhone, or when the app syncs in the background.

### Shop mode (iPhone)
- The list is in the learned order. Tap an item to tick it.
- A ticked item fades and moves to "Done" after two seconds. Tap it there to bring it back.
- An item that the order does not know yet is in the "New" group at the top, or at a guessed position with a sparkle mark.
- The top shows the progress and the time of the last sync.
- While shop mode is open, the Lock Screen shows the progress, the current item and the next three items.

### Apple Watch
- The Watch shows the progress, the current item and the next three items.
- Tap the current item, or use the Double Tap gesture, to tick it.
- Swipe an item and tap "Later" to move it to the end of the trip.
- Scroll down for the full list, the ticked items and "Refresh".
- The Watch and the iPhone sync over Bluetooth. This works with no internet.

### Settings (iPhone)
- **Order** shows the learned order with numbers. Drag an item to correct its position.
- **Invite** sends a link. The person who opens the link joins your list.

## How the order learns
- A trip is a run of ticks with no gap longer than four hours. Four hours after the last tick, the ticked items leave the list.
- The order comes from the last five trips that contain an item. One chaotic trip changes nothing.
- A drag on the order screen applies at once. Later trips can move the item again.
- An item that you moved back with "Later" does not count for that trip.

## Build and test

You need Xcode 27 or later.

```sh
# Unit tests of the logic package, with coverage
cd GrailkaufCore && swift test --enable-code-coverage

# Compile the iPhone app, the Watch app, the Lock Screen extension and the share extension
xcodebuild -project Grailkauf.xcodeproj -scheme Grailkauf \
  -destination 'generic/platform=iOS Simulator' build
```

If `xcodebuild` reports that it needs Xcode, put `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer` before the command.

GitHub Actions (`.github/workflows/build.yml`) runs both checks on every pull request and every push to `main`. It builds with no code signing and does not measure coverage.

## Project layout

| Folder | Content |
| --- | --- |
| `GrailkaufCore/` | Swift package with all logic and its unit tests: item names, order learning, list placement, suggestions |
| `Shared/` | Code for both apps: the store (Core Data with iCloud sync) and the Bluetooth link. Also the asset catalog with the app icon |
| `Grailkauf/` | The iPhone app |
| `GrailkaufWatch/` | The Watch app |
| `GrailkaufWidgets/`, `Activity/` | The Lock Screen Live Activity |
| `GrailkaufShare/` | The share extension: "Grailkauf" in the share sheet |
| `Strings/` | The texts in English and German |
| `Config/` | Info.plist files and entitlements |

## Before the first run on a device
- Open the project in Xcode and select your team. Xcode then registers the app and the iCloud container `iCloud.de.grails.grailkauf`.
- If Xcode reports that the container is missing, add it under Signing & Capabilities.
- You cannot rename or delete this container later.
- Xcode also registers the App Group `group.de.grails.grailkauf`. The share extension gives the shared text to the app through this group.
- Before a public release, deploy the iCloud schema to production in the CloudKit Console.

## Limits
- The app cannot force an iCloud sync, because the system gives apps no command for that. The iPhone syncs when the app opens and when a change arrives. "Refresh" on the Watch gets the list from the iPhone.
- The position guess for new items needs an iPhone with Apple Intelligence. On other iPhones, new items go to the "New" group.
- The position guess does not work in the simulator.
- To split a dictated list, the app also needs Apple Intelligence. On other iPhones, only "und", "and" and the punctuation split it.
- The share extension cannot write to the list, because the list is in the app's own folder. It keeps the text, and the app adds the items when it runs next.
