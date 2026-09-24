# The Foundry

A personal motivation, organizer and gym-coach app for iPhone and Mac, themed after the hideout from *Arrow*. Every day you check into the Foundry hub:

- **The List**: a notebook of names to strike off (tasks), one circled as primary.
- **The Quiver**: daily habits fired as arrows into a target. Fire them all for a bullseye.
- **Training**: a salmon ladder. Finish every set cleanly and the next rung (weight) unlocks.
- **The Island**: a focus timer that can switch on a "Foundry" Focus through Shortcuts.
- **Vitals**: sleep, workouts and resting heart rate from Apple Health, plus a Recovery score.

Finishing things earns XP, ranks (Castaway → Vigilante → Hood → Green Arrow) and medals. Good sleep gives a ×1.2 XP bonus.

> Personal project, not affiliated with or endorsed by any rights holder. Do not publish to the App Store under the show's names without review.

## Build and run

Requirements: Xcode 27 (Swift 6.4). Runs on iOS 26+ and macOS 26+.

1. Open `Foundry.xcodeproj`.
2. Pick the **Foundry** scheme and an iPhone simulator (or your iPhone), or **FoundryMac** and "My Mac".
3. Press Run.

Signing, iCloud and Health switches live in `Config/Signing.local.xcconfig` (see `SETUP.md`). Without it the project signs to run locally with iCloud sync off.

### Tests

```bash
cd FoundryKit && swift test
```

```bash
xcodebuild -project Foundry.xcodeproj -scheme Foundry -destination 'platform=iOS Simulator,name=iPhone 18 Pro' test
```

### Regenerating the project

`Foundry.xcodeproj` is generated from `project.yml` with [XcodeGen](https://github.com/yonaskolb/XcodeGen) and committed, so you don't need XcodeGen to build. After changing `project.yml`: `xcodegen generate`.

### Debug helpers (debug builds only)

- Settings › Debug › **Load Demo Data** fills every screen with two weeks of sample history.
- Launch arguments: `-FoundryDemoData`, `-FoundryTab list|quiver|train|vitals|rank|island|settings`, `-FoundryInMemory` (fresh, throwaway store).

## Layout

| Folder | What's in it |
|---|---|
| `FoundryKit/` | `FoundryCore`: every game rule as plain, unit-tested Swift (XP, ranks, streaks, Recovery, ladder, sleep builder, mission line, medals, due tags). |
| `Shared/` | Code both apps use: design system, SwiftData models, the store, services (Health, Focus, Island timer), all screens. |
| `iOS/` | iPhone app entry, root view and custom tab bar. |
| `macOS/` | Mac app entry, sidebar, dashboard, menu bar popover, keyboard commands. |
| `Tests/FoundryTests/` | Store tests on an in-memory SwiftData container. |
| `Config/` | xcconfig and entitlement files. |
| `scripts/` | Icon generator, Caveat Bold instancer, string-catalog updater. |
| `docs/` | Design mockups (`design-reference/`) and screenshots. |

Fonts (Barlow, Barlow Condensed, IBM Plex Mono, Caveat) are bundled under the SIL Open Font License; licenses sit next to the font files.
