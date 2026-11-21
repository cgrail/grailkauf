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
- Below the items, "Suggestions" shows items from your past trips and lists that are not on the list. The items that were in the most lists come first. Tap an item to add it. The list stays where it is. Swipe an item to remove it, for example a thing that you bought once. It comes back if a later trip or list has it. Removed suggestions stay on this iPhone only.
- If you add an item that is on the list already, the app removes the older copy and keeps the new one. A notice shows the name for a few seconds. An item that you say or type twice at once goes on the list once.
- Tap the trash button of an item, or swipe the item, to delete it. Tap the text of an item to change it in place, as in a notes app. Press Enter or tap elsewhere to save. If you empty the text, the item goes away. A comma makes more items.
- Touch and hold an item, then drag it to a new place.
- Tap "Select" to select items. Slide a finger down the circles to select many items quickly, or tap "Select all". Tap the trash button at the bottom to delete the selected items. Tap the X to stop.
- The history keeps the items that you bought, also after you delete them from the list.
- Hold "Hold to dictate" above the text field and say your items, for example "Milch, zwei Liter Apfelsaft und Brot". Let go to add the items to the list. With VoiceOver, double tap and hold.
- After each short pause, the screen shows the items of what you said. A spinner shows while the app splits them into single products. Filler words such as "ähm", "dann" or "noch" go away.
- The last line shows the words that the phone hears now, next to a moving waveform. A microphone shows while the phone waits for words.
- While you hold, a bar above the button shows what the app does ("Listening", "Splitting", "Adding"), a red waveform of your voice and the time. Rings around the button grow when you speak.
- A spinner line above the button shows while the app checks new items. A new item can still split into more items then.

### Sections (iPhone)
- Tap "Sections" at the top to show the list as tiles, grouped by supermarket section such as "Fruit & vegetables".
- The sections follow the route through a typical supermarket. Small sections fill the gaps in the rows above.
- Within a section, the tiles are in the learned order, as in shop mode.
- Tap a tile to change its name, move the item to another section or delete it. Touch and hold a tile does the same from a menu. Later items of the same name go to the new section.
- If you type an item below the tiles and press Enter, the app adds it and goes to the list. You can then add more items.

### Menu and history (iPhone)
- Tap the menu button at the top left. The menu slides in from the left. Tap next to it to close it.
- Tap "New list" at the top of the menu to start an empty list. The current list moves to the history as an archived list. It does not count as a purchase.
- "New list" also ends the shop in progress. The ticked items leave the list at once, and the app goes to list mode.
- The menu shows each past shopping trip and archived list, newest first. "Settings" is at the bottom of the menu.
- Each trip shows its date and the items that are not on the list now. These are the items that your list can miss. A line below counts the items that are not on the list and the items that are already on it.
- Tap a trip or an archived list to open it. Tap + to add an item to the list again.
- Below the items, a line counts the items of that trip that are already on the list. Tap the line to show them.

### Add from another app (iPhone)
- Share a text, for example a note, and tap "Grailkauf" in the share sheet. Each line and each part between commas becomes one item. List marks such as "✓" or "•" at the start of a line go away. Grailkauf then opens on the list.
- If a note in Notes is shared with other people, select "Send Copy" at the top of the share sheet first.
- The items reach the list when Grailkauf opens on this iPhone, or when the app syncs in the background.

### Shop mode (iPhone)
- The list is in the learned order. Tap an item to tick it.
- A ticked item fades and moves to "Done" after two seconds. Tap it there to bring it back.
- An item that the order does not know yet is in the "New" group at the top, or at a guessed position with a sparkle mark.
- The top shows the progress and the time of the last sync.
- Tap the grid button at the top to see the items as tiles by section. Tap a tile to tick it. Ticked tiles move to "Done" below a line at the bottom, grouped by faded sections. Tap "Done" to show or hide them. Tap a tile there to bring it back. Within a section, the tiles are in the learned order. Shop mode keeps the view that you chose last.
- While shop mode is open, the Lock Screen shows the progress, the current item and the next three items.

### Apple Watch
- The Watch shows the current item and the next three items. A small ring with a count in the top left corner shows the progress.
- Each open item has an empty circle and a picture of the kind of item. A ticked item has a check mark.
- Tap the current item, or use the Double Tap gesture, to tick it.
- Swipe an item and tap "Later" to move it to the end of the trip.
- Scroll down for the full list, grouped by supermarket section as in "Sections", then the ticked items and "Refresh".
- The Watch and the iPhone sync over Bluetooth. This works with no internet.

### Settings (iPhone)
- **Order** shows the learned order with numbers. Drag an item to correct its position.
- **Invite** sends a link. The person who opens the link joins your list.
- **Privacy Policy** opens the privacy policy on the web.

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

In the Watch simulator, the Watch starts with a sample list, in English or German as the simulator's language. It goes away when the paired iPhone simulator sends its list. Builds for a real Watch never show it.

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
| `docs/` | The privacy policy, served by GitHub Pages |
| `scripts/` | `check-listing.py` checks the App Store texts in `APP-STORE.md` |

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
- A pause, "und", "and" and punctuation split a dictated list.
- With Apple Intelligence, the app splits an entry into the products that a shop sells on their own. "Milch Sprudel" becomes "Milch" and "Sprudel". "saure Sahne" stays one item. On other iPhones, the entry stays as you wrote it.
- The share extension cannot write to the list, because the list is in the app's own folder. It keeps the text and opens the app with `grailkauf://list`. The app then adds the items.
