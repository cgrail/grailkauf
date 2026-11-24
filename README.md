# grailkauf
<img src="Shared/Assets.xcassets/AppIcon.appiconset/AppIcon.png" width="128" alt="App icon: a white shopping cart with bottles, an apple and a baguette on a blue background">

Smarte Einkaufsliste

A shared shopping list for one household, for iPhone and Apple Watch, with a Mac app to write the list.
The list learns the order in which you pick up your items, and sorts itself in that order.

## What the app does

### List mode (iPhone)
- Type an item and press Enter. The item goes to the end of the list. The text field and the microphone button are in one line, as in a chat app.
- A comma or a pasted text with many lines adds many items at once.
- While you type, the app suggests items that you added before.
- If the text field is empty, the app shows the items that are due again. "Fill with the usual" adds all of them.
- Below the items, "Suggestions" shows items from your past trips and lists that are not on the list. The items that were in the most lists come first. Tap an item to add it. The list stays where it is. Swipe an item to remove it, for example a thing that you bought once. It comes back if a later trip or list has it. Removed suggestions stay on this iPhone only.
- If you add an item that is on the list already, the app removes the older copy and keeps the new one. A notice shows the name for a few seconds. An item that you say or type twice at once goes on the list once.
- Tap the trash button of an item, or swipe the item, to delete it. Tap the text of an item to change it in place, as in a notes app. Press Enter or tap elsewhere to save. If you empty the text, the item goes away. A comma makes more items.
- Touch and hold an item, then drag it to a new place.
- Tap "Select" to select items. Slide a finger down the circles to select many items quickly, or tap "Select all". Tap the trash button at the bottom to delete the selected items. Tap the X to stop.
- The history keeps the items that you bought, also after you delete them from the list.
- Hold the microphone button to the right of the text field and say your items, for example "Milch, zwei Liter Apfelsaft und Brot". Let go to add the items to the list. With VoiceOver, double tap and hold.
- After each short pause, the screen shows the items of what you said. A spinner shows while the app splits them into single products. Filler words such as "ähm", "dann" or "noch" go away.
- The last line shows the words that the phone hears now, next to a moving waveform. A microphone shows while the phone waits for words.
- While you hold, a line above shows what the app does ("Listening", "Splitting", "Adding"). In place of the text field, a red waveform of your voice and the time show. The button turns red and glows, and rings around it grow when you speak.
- A spinner line above the button shows while the app checks new items. A new item can still split into more items then.

### Sections (iPhone)
- Tap "Sections" at the top to show the list as tiles, grouped by supermarket section such as "Fruit & vegetables".
- The sections follow the route through a typical supermarket, or the order that you set in Settings. Small sections fill the gaps in the rows above. Each row fills the full width of the screen: a section gets a share for each of its items.
- Within a section, the tiles are in the learned order, as in shop mode.
- Tap a tile to change its name, move the item to another section or delete it. Touch and hold a tile does the same from a menu. Later items of the same name go to the new section.
- If you type an item below the tiles and press Enter, the app adds it and goes to the list. You can then add more items.

### Menu and history (iPhone)
- Tap the menu button at the top left. The menu slides in from the left. Tap next to it to close it.
- Tap "New list" at the bottom of the menu to start an empty list. The app does not ask first. The menu closes and shows the empty list. The current list moves to the history as an archived list. It does not count as a purchase.
- "New list" also ends the shop in progress. The ticked items leave the list at once, and the app goes to list mode.
- The menu shows each past shopping trip and archived list below the title "History", newest first. "New list" and "Settings" stay at the bottom of the menu.
- Each trip shows its date and the items that are not on the list now. These are the items that your list can miss. A line below counts the items that are not on the list and the items that are already on it.
- Swipe an archived list to delete it. Its items no longer show in the suggestions. Shopping trips stay, because the order learns from them.
- Tap a trip or an archived list to open it. Tap + to add an item to the list again. Tap "Add all" at the top to add all items that are not on the list.
- Below the items, a line counts the items of that trip that are already on the list. Tap the line to show them.

### Add from another app (iPhone)
- Share a text, for example a note, and tap "Grailkauf" in the share sheet. Each line and each part between commas becomes one item. List marks such as "✓" or "•" at the start of a line go away. Grailkauf then opens on the list.
- If a note in Notes is shared with other people, select "Send Copy" at the top of the share sheet first.
- The items reach the list when Grailkauf opens on this iPhone, or when the app syncs in the background.

### Shop mode (iPhone)
- The list is in the learned order, grouped by supermarket section as on the Watch. The section of the current item is at the top. Tap an item to tick it.
- A ticked item fades and moves to "Done" after two seconds. "Done" is grouped by section too. Tap an item there to bring it back.
- An item that the order does not know yet is in the "New" group at the top, or at a guessed position with a sparkle mark.
- The top shows the progress and the time of the last sync.
- Tap the grid button at the top to see the items as tiles by section. Tap a tile to tick it. Ticked tiles move to "Done" below a line at the bottom, grouped by faded sections. Tap "Done" to show or hide them. Tap a tile there to bring it back. Within a section, the tiles are in the learned order. Shop mode keeps the view that you chose last.
- When you tick the last item, a big 🎉 and "All done." show above the list.
- While shop mode is open, the Lock Screen shows the progress, the current item and the next three items. The Smart Stack on the Apple Watch shows the progress and the current item.

### Apple Watch
- The Watch shows the current item at the top, below the name of its supermarket section. A ring with a count in the top left corner, in the size of the time and level with it, shows the progress.
- Each open item has an empty circle and a picture of the kind of item. A ticked item has a check mark.
- The items are in small text in low rows, with little space between the sections, so more than two fit on one screen. The current item is in bold.
- Tap the current item, or use the Double Tap gesture, to tick it.
- Swipe an item and tap "Later" to move it to the end of the trip.
- Below it, the rest of the list, grouped by supermarket section as in "Sections", then the ticked items, also by section.
- Tap "Info" at the end of the list for the info screen. It shows the time of the last sync, the version and the commit of the app. "Refresh" there gets the list from the iPhone.
- When you tick the last item, the Watch shows a big 🎉 and "All done.".
- The Watch and the iPhone sync over Bluetooth. This works with no internet.

### Settings (iPhone)
- **Order** shows the learned order with numbers. Drag an item to correct its position.
- Below, with a sparkle, are the items on the list that the order does not know yet. Drag one to its place, also before your first shop. Shop mode then sorts it there.
- **Sections** shows the supermarket sections. Drag a section to its place in your shop. "Sections", shop mode and the Watch then show the sections in this order. Shop mode goes through the sections in this order, and through the items of each section in the learned order. "Reset" goes back to the route of a typical supermarket. Everyone who shares the list gets the same order.
- **Show details** shows the position of each item in the order and the picture of its section, in the list, in shop mode and on the tiles. A sparkle marks a guessed position. "–" shows an item with no position, "?" an item with no section yet.
- **Export** sends the open items as text to Notes or another app, one item per line, in shop order. Switch off a section to leave its items out. In Notes, select the text and tap the checklist button to get a circle for each item.
- **Invite** sends a link. The person who opens the link joins your list.
- **Privacy Policy** opens the privacy policy on the web.
- **Upload iCloud schema** shows in Debug builds only. It sends every entity and field to the Development schema in iCloud.

### Mac
- The Mac app writes the list and puts it in order. You shop with the iPhone and the Watch.
- Sign in to the same iCloud account as on your iPhone. iCloud then syncs the list both ways.
- "List" shows the open items. Type an item at the bottom and press Enter. A comma or a pasted text with many lines adds many items at once.
- Click the text of an item to change it. Press Enter or click elsewhere to save. Click the trash button to delete an item. Drag an item to a new place.
- "Order" shows the learned order. Drag an item to correct its position, as in Settings on the iPhone. The items with a sparkle are on the list, but the order does not know them yet.
- "Sections" shows each supermarket section, with the items of the list below it in the learned order. Empty sections show too.
- Drag an item to a new place in its section. Drag it below another header to move it to that section. Later items of the same name go to that section.
- Drag a section header to put the section in its place in your shop. "Reset" goes back to the route of a typical supermarket. Everyone who shares the list gets the same order.
- Right-click an item to move it to another section or to delete it.
- The bottom of the sidebar shows the time of the last sync.

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

# Compile the Mac app
xcodebuild -project Grailkauf.xcodeproj -scheme GrailkaufMac \
  -destination 'generic/platform=macOS' CODE_SIGNING_ALLOWED=NO build
```

If `xcodebuild` reports that it needs Xcode, put `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer` before the command.

In the Watch simulator, the Watch starts with a sample list of 30 items, with each section filled, in English or German as the simulator's language. It goes away when the paired iPhone simulator sends a list with items sorted into sections. A list with no sorted items, as the iPhone simulator often has, does not replace it. Builds for a real Watch never show it.

GitHub Actions (`.github/workflows/build.yml`) runs the three checks on every pull request and every push to `main`. It runs them as three parallel jobs and builds with no code signing. It builds the iPhone apps for arm64 simulators only, and does not measure coverage.

## Project layout

| Folder | Content |
| --- | --- |
| `GrailkaufCore/` | Swift package with all logic and its unit tests: item names, order learning, list placement, suggestions |
| `Shared/` | Code for all apps: the store (Core Data with iCloud sync) and the Bluetooth link (not on the Mac). Also the asset catalog with the app icon |
| `Editing/` | Views to write the list and put it in order, for the iPhone and the Mac: the item row and the order |
| `Grailkauf/` | The iPhone app |
| `GrailkaufWatch/` | The Watch app |
| `GrailkaufMac/` | The Mac app: write the list, sort the items and sections, correct the order |
| `GrailkaufWidgets/`, `Activity/` | The Lock Screen Live Activity |
| `GrailkaufShare/` | The share extension: "Grailkauf" in the share sheet |
| `Strings/` | The texts in English and German |
| `Config/` | Info.plist files, entitlements, and `Version.xcconfig` with the version and build number of every target |
| `docs/` | The privacy policy, served by GitHub Pages |
| `scripts/` | `check-listing.py` checks the App Store texts in `APP-STORE.md` |

## Before the first run on a device
- Open the project in Xcode and select your team. Xcode then registers the app and the iCloud container `iCloud.de.grails.grailkauf`.
- If Xcode reports that the container is missing, add it under Signing & Capabilities.
- The Mac app has the bundle ID of the iPhone app, so both are one app in the App Store. Select your team for the `GrailkaufMac` target too.
- You cannot rename or delete this container later.
- Xcode also registers the App Group `group.de.grails.grailkauf`. The share extension gives the shared text to the app through this group.
- Before a public release, deploy the iCloud schema to production in the CloudKit Console. If the model changed, first tap "Upload iCloud schema" in Settings of a Debug build. The schema in the Development environment then has every new field.

## Limits
- The app cannot force an iCloud sync, because the system gives apps no command for that. The iPhone syncs when the app opens and when a change arrives. "Refresh" on the info screen of the Watch gets the list from the iPhone.
- The position guess for new items needs an iPhone with Apple Intelligence. On other iPhones, new items go to the "New" group.
- The position guess does not work in the simulator.
- A pause, "und", "and" and punctuation split a dictated list.
- With Apple Intelligence, the app splits an entry into the products that a shop sells on their own. "Milch Sprudel" becomes "Milch" and "Sprudel". "saure Sahne" stays one item. On other iPhones, the entry stays as you wrote it.
- The Mac app has no shop mode, dictation, history, suggestions or invite. Invite people on the iPhone.
- A new item from the Mac gets its section, and its split into single products, when the iPhone opens next.
- The share extension cannot write to the list, because the list is in the app's own folder. It keeps the text and opens the app with `grailkauf://list`. The app then adds the items.
