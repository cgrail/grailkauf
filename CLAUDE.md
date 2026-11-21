# Grailkauf

A shared shopping list for iPhone and Apple Watch that learns the order of a shop. [README.md](README.md) holds the features, the build and test commands, and the project layout. Read it before a change.

## Working rules

- Work on a branch, push it, and open a pull request. Commit nothing to `main`.
- The checks in README "Build and test" must be green before each commit.
- A change a user would notice gets an entry in [CHANGELOG.md](CHANGELOG.md) under `## <MARKETING_VERSION> (current)`, in the same commit. Say what the app does now.
- A new or changed feature, control or setting updates the README in the same commit.
- UI text is in English and German. Add each new string with its German text to `Strings/Localizable.xcstrings`.

## Data that must keep loading

Devices update at different times, and an older App Store build must read what a newer one syncs.

- The Core Data model (`makeModel()` in `Shared/Model.swift`) only grows: add entities and optional attributes. Rename, retype or delete nothing. CloudKit's Production schema cannot drop a field.
- These saved keys keep their names and meaning: `UserDefaults` `lastSync`, `mode`, `grid`, `removedSuggestions` (iPhone), `phone` (Watch), and `inbox` in the App Group `group.de.grails.grailkauf` (share extension to app).
- `mode` holds `list`, `sections` or `shop`. An older build reads `sections` as `list`. `grid` is the list or grid view of shop mode only.

## Privacy

Three things must agree, or App Review rejects the build: what the app does, `docs/privacy-policy.html`, and the App Privacy answers in [APP-STORE.md](APP-STORE.md).

- If a change touches new data, a new framework, or a network call, update the privacy policy and its "Last updated" date in the same change.
- Each target that runs code has its own `PrivacyInfo.xcprivacy` (`Grailkauf/`, `GrailkaufWatch/`, `GrailkaufShare/`). If a target starts to use a required-reason API (`UserDefaults`, file timestamps, disk space, system boot time), declare it in that target's manifest. `UserDefaults.standard` is `CA92.1`; the App Group suite is `1C8F.1`.
- `ITSAppUsesNonExemptEncryption` is `NO` in `Config/Grailkauf-Info.plist`. That holds while the app uses only Apple's encryption (HTTPS, CloudKit). Encryption of our own means revisiting it.
- GitHub Pages serves `docs/` from `main` at https://grails.de/grailkauf/. Settings links to the privacy policy there.

## Release

A push to `main` releases nothing. The user decides when a version ships. When the user asks to prepare a release, do these steps in order. The release is ready when every step is done and its check is green.

1. Create the branch `release-<version>` from an up-to-date `main`.
2. Run the checks in README "Build and test". Done when both pass.
3. Set the version in `Grailkauf.xcodeproj/project.pbxproj`. `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` are set once at project level (Debug and Release), so all targets share them. The Watch app's version must match the iPhone app's.
   - Each upload needs a higher `CURRENT_PROJECT_VERSION`. Always add 1.
   - For a new version, raise `MARKETING_VERSION`. Close the top changelog section: drop `(current)` from it, and open a new `## <new version> (current)` above it.
4. For every version after 1.0, write `WHATS-NEW.md`: the user-facing cut of the changelog section, in English and German. Write only the changes a user notices. App Store Connect rejects bullets, emoji and typographic dashes or quotes there.
5. Compare APP-STORE.md with the changelog section. If a feature is new or changed, update the description in both languages. Run `scripts/check-listing.py`. Done when it exits 0.
6. Check privacy (see Privacy above). Done when every target's manifest matches `grep -rnE "UserDefaults|@AppStorage|modificationDate|creationDate|systemUptime|volumeAvailableCapacity" --include='*.swift'`, and the policy describes every framework that handles user data.
7. Commit, push, and open the pull request.
8. End with the list of steps for the user below, and mark the ones this release needs.

### Steps only the user can do

- If the Core Data model changed: run a Debug build on a device, create a record of each new entity and attribute so they reach the Development schema, then deploy the schema to Production in the CloudKit Console. Without this, App Store builds cannot send changes to iCloud. Before submitting, check that "Deploy Schema Changes" lists nothing.
- Merge the pull request. If GitHub Pages is off, switch it on: repository Settings, Pages, branch `main`, folder `/docs`.
- In Xcode, select Product, Archive with the Grailkauf scheme, then Distribute App, App Store Connect.
- In App Store Connect, paste the texts from APP-STORE.md (and WHATS-NEW.md), and add screenshots: 6.9-inch iPhone and Apple Watch, each in English and German. Then select the build and submit for review.
- Test on a device before submitting: dictation, Apple Intelligence split, invite with a second iCloud account, Watch over Bluetooth with no internet, sharing a note, the Live Activity, and the privacy policy link in Settings.
