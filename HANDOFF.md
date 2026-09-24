# The Foundry — Claude Code Build Prompt

**For Nicholas (not part of the prompt):**
1. Clone the repo, then drop this file and the `docs/design-reference/` folder (from the zip) into the repo root.
2. In Terminal: `cd` into the repo, run `claude`, and say: **"Read HANDOFF.md and build it."**
3. Claude Code builds and checks everything it can on the Mac. Your hands are needed only for the short list in `SETUP.md` at the end (plug in the iPhone, allow Health, create two Shortcuts).

Everything below the line is the prompt.

---

# MISSION

Build **The Foundry** v1 completely, in one autonomous run: a Green Arrow–themed (Arrow, The CW) personal motivation/organizer/gym-coach app that feels like checking into a hideout, not doing chores. One SwiftUI codebase, two apps: **iPhone** and **Mac**, syncing through iCloud when signing allows. It also has a Mac menu bar popover.

"Done" means: builds clean on both platforms, tests pass, every screen in this spec exists and works with real data, nothing is stubbed, and you have looked at screenshots of your own work and fixed what doesn't match. Do not stop halfway to ask questions unless a rule in section 3 says to.

The design was prototyped as visual mockups. They are in `docs/design-reference/` (nine `.dc.html` files: Main = hub, List, Quiver, Train, Vitals, Rank, Island, Mac, MenuBar). Treat them as the visual source of truth for geometry, colors, spacing, and copy. They are plain HTML/SVG/CSS. Ignore the `<x-dc>`/`<helmet>` wrappers and `support.js`; `{{accent}}` means `#62c47f`. Where this spec and a mockup disagree, this spec wins. The online canvas (open it only if you have a browser tool; do not depend on it): https://claude.ai/artifact/MLtPXBaDvdT16Rxw4qH2SB

The mockups are 390×844 pt phone frames purely as reference proportions. **Do not hardcode screen sizes.** Layouts must adapt.

# 1. THE DEVELOPER AND HIS HARDWARE (exact)

| Item | Detail |
|---|---|
| Developer | Nicholas, Framingham, Massachusetts, USA. Self-taught, no formal coding background. Final explanations must be plain English. |
| Build machine | **MacBook Pro 14-inch (November 2023), Apple M3 Pro, 18 GB unified memory.** Apple silicon only; no Intel/Rosetta concerns. 18 GB: run one simulator at a time, avoid parallel heavy builds. |
| macOS / Xcode | Latest. As of Sept 24, 2026 that means **macOS 27 "Golden Gate"**, **Xcode 27** (Swift 6.4, SDKs iOS 27 / macOS 27). Verify with `sw_vers` and `xcodebuild -version`; use whatever is actually installed and note any mismatch. |
| Phone | **iPhone 18 Pro** running **iOS 27**. Portrait only. ProMotion 120 Hz: keep animations smooth. Use safe-area insets, never hardcoded notch/Dynamic Island sizes. |
| Watch | Apple Watch worn 24/7. It is the source of sleep, workout, and resting-heart-rate data in Apple Health. **No Watch app in v1.** |
| Other devices | iPad Air, Windows PC, NucBox, PS5 exist. **Out of scope. Do not target iPad or Windows.** |
| Locale | **U.S. context everywhere**: pounds (lb), °F if ever needed, MM/DD dates, 12-hour clock (`11:00 PM`), Monday-start weeks are fine but label days `M T W T F S S`. |

**Deployment targets:** build with the newest installed SDKs, set minimum deployment to **iOS 26.0 and macOS 26.0** (so it still runs if his Mac has not upgraded), and use no iOS 27-only API without an `#available` fallback. Swift language mode 6 if it compiles with zero warnings, otherwise mode 5 with complete concurrency checking and zero warnings.

# 2. THE PRODUCT IN ONE PARAGRAPH

Every day the user checks into **the Foundry** (a radar-style hub). Five stations orbit a central hood emblem: **List** (a notebook of "names" to strike, like Oliver's list), **Quiver** (daily habits fired as arrows into a target), **Train** (a salmon ladder that climbs as lifts get heavier), **Island** (a focus timer that turns on a Focus mode), and **Vitals** (sleep and workouts from Apple Health). Finishing things earns **XP**, ranks (Castaway → Vigilante → Hood → Green Arrow), and medals. Good sleep gives a Recovery bonus. It should feel like a game but be genuinely useful and never feel like a chore. **Screen names live in the bottom tab bar; the top of each screen shows only a hexagon symbol plus a small chip.**

# 3. WORKING RULES (from Nicholas's preferences; follow strictly)

1. **One-shot, complete, polished.** No TODO/FIXME, no placeholder UI, no dead buttons, no "coming soon", no broken elements. Every control does something real.
2. **Build exactly this spec. Do not add features.** He must be consulted before new features are added. Ideas go in `IDEAS.md` and the final report, nothing else. Section 16 lists things explicitly excluded.
3. **Be decisive.** When the spec is silent, pick the best option, record it in `DECISIONS.md` (one line: decision + why), and continue.
4. **Only stop and ask if:** (a) the project cannot be built or signed after real attempts, or (b) an action would be destructive (force-push, deleting existing repo content, changing Git history).
5. **Direct language.** Final report is short, plain, actionable, with no jargon dumps.
6. **Personal, private, local.** No analytics, no third-party SDKs, no network calls (other than iCloud via SwiftData). No secrets in Git.

# 4. REPOSITORY, GIT, TOOLING

- Repo: `https://github.com/Nicholas6719/The-Foundry.git`. If you are not already inside a clone, clone it to `~/Developer/The-Foundry`. If it already contains files, read them first and integrate; never overwrite existing work without reading it.
- Work on branch **`v1-build`** off the default branch. Small logical commits with clear messages (`Add HealthService`, not `wip`). At the end **push `v1-build`**. Never push to the default branch, never force-push, never rewrite history. If the push fails on auth, leave the commits local and tell him exactly which command fixes it (`gh auth login`).
- Verify tools first: `git --version`, `brew --version`, `xcodebuild -version`, `swift --version`, `xcrun simctl list devices available` (find **iPhone 18 Pro**; if absent use the newest iPhone Pro simulator and say so).
- Install **XcodeGen** with Homebrew if missing (`brew install xcodegen`). Do not install anything else without a stated reason.
- Generate the Xcode project from `project.yml` **and commit both** `project.yml` and the generated `Foundry.xcodeproj` (so he can open it in Xcode without XcodeGen).
- `.gitignore`: Xcode, DerivedData, `.DS_Store`, `xcuserdata`, `*.xcconfig` overrides named `*.local.xcconfig`, `.build/`.
- Bundle ID for both apps: `com.nicholas6719.foundry`. iCloud container: `iCloud.com.nicholas6719.foundry`. URL scheme: `foundry://`.
- Repo docs to write: `README.md` (what it is, how to build/run), `SETUP.md` (his manual steps, section 15), `DECISIONS.md`, `IDEAS.md`. README must include: *personal project, not affiliated with or endorsed by any rights holder; do not publish to the App Store under the show's names without review.*

## Signing and capabilities (make it work with or without a paid account)

You cannot know whether Nicholas has a paid Apple Developer Program membership or which capabilities his team allows. Design for both:

- `Config/Base.xcconfig` (committed) plus `Config/Signing.local.xcconfig` (gitignored) and `Config/Signing.local.xcconfig.example` (committed). The local file sets `DEVELOPMENT_TEAM`, `FOUNDRY_CLOUDKIT = YES|NO`, `FOUNDRY_HEALTHKIT = YES|NO`.
- Entitlements are selected through xcconfig variables so the same project builds in every combination. Provide the entitlement files needed: HealthKit (+ background delivery), iCloud/CloudKit container, and macOS App Sandbox (network client not required; user-selected files not required).
- Auto-detect a team if you can (`security find-identity -v -p codesigning`, existing Xcode team defaults). If none is found, build for **simulator and Mac "Sign to Run Locally"** with CloudKit off, verify everything you can, and finish with the exact steps in `SETUP.md` for enabling his team, CloudKit, and device install.
- `FOUNDRY_CLOUDKIT` off means `ModelConfiguration(cloudKitDatabase: .none)`; on means `.private("iCloud.com.nicholas6719.foundry")`. The app must behave correctly and look intentional in both states (see Vitals on Mac).

# 5. ARCHITECTURE

SwiftUI + SwiftData + `@Observable`. No third-party packages. No UIKit/AppKit unless required (haptics, dock/menu bar, idle timer).

```
The-Foundry/
  project.yml
  Config/            Base.xcconfig, Signing.local.xcconfig.example, *.entitlements
  FoundryKit/        local Swift package
    Sources/FoundryCore/   pure Swift rules, no Apple frameworks except Foundation
    Tests/FoundryCoreTests/
  Shared/            compiled into BOTH apps
    App/  DesignSystem/  Data/  Services/  Features/  Intents/  Resources/
  iOS/               iPhone-only code (custom tab bar, haptics, Info.plist keys)
  macOS/             Mac-only code (sidebar, dashboard, MenuBarExtra, Settings scene)
  Tests/FoundryTests/  SwiftData in-memory tests, service tests
  docs/design-reference/  the nine mockups (do not modify)  docs/screenshots/
```

- Targets: `Foundry` (iOS app), `FoundryMac` (macOS app), `FoundryTests`, and the `FoundryKit` package. Schemes: `Foundry`, `FoundryMac`.
- **FoundryCore** holds all game logic as pure functions/value types so it is fast to test: XP, ranks, streaks, recovery score, ladder progression, sleep-session building, mission text, medal rules, due-date labels, day keys. No SwiftData, no HealthKit, no UI.
- No Swift file over ~400 lines. Views small and composable. `os.Logger` for logging; no stray `print`.
- Dark-only: force dark appearance on both platforms.
- Strings in a String Catalog (`Localizable.xcstrings`), `en-US` only.
- App icon: generate a 1024×1024 PNG programmatically (a Swift/CoreGraphics script committed under `scripts/`): background `#08120d`, hexagon outline in `#62c47f`, solid `#62c47f` arrowhead inside. Add an `AccentColor` asset `#62c47f`.

# 6. DESIGN SYSTEM

## Colors (define once as `Color` tokens; never inline hex in views)

| Token | Hex | Use |
|---|---|---|
| bg | `#08120d` | screen background |
| bgDeep | `#050d09` | Island screen |
| surface | `#0f1d15` | cards |
| surface2 | `#16281d` | raised/selected cards, icon tiles |
| surfaceInset | `#13241a` | alternate target rings |
| tabBar | `#0b1810` | tab bar / Mac sidebar |
| line | `#1f3a2a` | hairlines, tracks |
| lineStrong | `#2b4536` | ladder rails, target ring strokes |
| lineDim | `#3a5646` | dashed/locked outlines |
| text | `#e9f1ea` | primary text |
| textMuted | `#93a89a` | secondary text |
| tabInactive | `#8fa596` | inactive tab |
| accent | `#62c47f` | arrow green (also `AccentColor`) |
| onAccent | `#07110c` | text/icons on accent fills |
| climbed | `#2c5a3f` | completed ladder rungs, past workout bars |
| inkRed | `#e0616d` | red ink on dark (bullseye dot, alerts, awake) |
| paper | `#e9e3cf` | notebook page |
| ink | `#1a2018` | ink on paper |
| inkFaded | `#6b6f60` | struck names |
| inkRedPaper | `#b3202e` | strike lines, circled name, due tag |
| inkMuted | `#4a5044` | small mono tags on paper |
| sleepDeep / Core / REM / Awake | `#1d5a3a` / `#3f9a62` / `#9be3b4` / `#e0616d` | sleep stages (differ in lightness) |

All text/background pairs must meet WCAG AA. The palette above already does; do not tint it.

## Typography (bundle these OFL fonts; register with CoreText at launch; fall back to system fonts if registration fails)

- **Barlow Condensed** 600/700: titles, big numerals, buttons (uppercase, tracking ≈ 0.04–0.08em).
- **Barlow** 400/500/600: body.
- **IBM Plex Mono** 400/500: small labels (11–13 pt, uppercase, tracking 0.06–0.12em), timers.
- **Caveat** 700: the notebook List names (36 pt phone, 30 pt Mac) and the Island target name.
- Download from the `google/fonts` repo (`ofl/barlowcondensed`, `ofl/barlow`, `ofl/ibmplexmono`, `ofl/caveat`) into `Shared/Resources/Fonts/` with each license file. **Read the real PostScript names from the files (CTFontManager) and log them; never guess names.** Caveat ships as a variable font: verify weight works, or make a static bold instance.
- Wrap in a `FoundryFont` helper with Dynamic Type via `relativeTo:` and `@ScaledMetric` for custom-drawn text.

## Shape language

Screen horizontal padding 24. Cards: radius 14–18, `surface` fill, 1 pt `line` border. Pills: fully rounded, 44 pt tall on iPhone. Primary buttons: 52 pt tall, radius 12, accent fill, `onAccent` text in Barlow Condensed 700 20 pt, tracking 0.08em. Secondary: 1 pt accent (or `lineDim`) outline. Minimum tap target 44×44 pt everywhere.

## Custom glyphs (build as SwiftUI `Shape`s on a 24×24 grid, stroke 1.75–2, round caps/joins)

Arrowhead emblem `M12 3l7 9h-4.5v9h-5v-9H5z`; notebook: rect (5,3,14×18, r2) + `M9 3v18M12 8h4M12 12h4`; quiver `M6 20L18 8M9 20L21 8M3 17L15 5`; ladder `M8 3v18M16 3v18M8 7h8M8 12h8M8 17h8`; crosshair: circle r7 at (12,12) + `M12 2v4M12 18v4M2 12h4M18 12h4`; pulse `M3 12h4l2-5 4 10 2-5h6`; chevrons `M6 11l6-6 6 6M6 18l6-6 6 6`; dumbbell `M6 8v8M18 8v8M3 10v4M21 10v4M6 12h12`; check `M5 12.5l4.5 4.5L19 7`. Hexagon badge on a 48 grid: points (24,2)(43,13)(43,35)(24,46)(5,35)(5,13), fill `surface`, 2 pt accent stroke, glyph centered at 24 pt. **Use SF Symbols for utilities**: `moon`, `heart`, `lock`, `bolt`, `phone`, `bell.slash`, `cellularbars`, `fork.knife`, `book`, `arrow.right`, `plus`, `chevron.left`, `gearshape`, `arrow.triangle.2.circlepath`.

# 7. DATA MODEL (SwiftData, CloudKit-compatible)

Rules so CloudKit sync works: every attribute has a default or is optional; no `@Attribute(.unique)`; relationships optional with explicit inverses; enums stored as raw `String`/`Int`. Ship a `VersionedSchema` v1 with an empty migration plan scaffold. **Day keys** are local-calendar strings `yyyy-MM-dd`.

| Model | Fields |
|---|---|
| `Profile` (singleton) | sleepGoalMinutes=480, weeklyWorkoutGoal=4, focusMinutes=25, focusSessionsGoal=4, hasOnboarded, healthEnabled, focusShortcutsConfigured, focusAutoStartFromFilter |
| `Target` | id, title (≤40 chars), createdAt, dueDate?, isPrimary, struckAt? |
| `Habit` | id, name, glyph (fixed set of 8), sortOrder, autoRule (`none`/`workout`/`sleepDuration`), autoThresholdMinutes, isArchived |
| `HabitLog` | habitID, dayKey, firedAt, source (`manual`/`auto`) |
| `DaySummary` | dayKey, habitsTotal, habitsDone, isBullseye (mutable for today, frozen afterward) |
| `WorkoutDay` | id, name, weekdayMask, sortOrder |
| `LiftDef` | id, workoutDayID, name, sortOrder, isLead, startWeightLb, stepLb (default 5), sets, reps, currentRung |
| `SetLog` | id, liftID, dayKey, setIndex, weightLb, repsDone, targetReps, completedAt |
| `FocusSession` | id, startedAt, endedAt?, plannedMinutes, completed |
| `DailyVitals` | dayKey, sleepMinutes, deepMin, coreMin, remMin, awakeMin, restingHR?, workoutMinutes, workoutCount, recovery?, updatedAt |
| `XPEvent` | id, dayKey, kind, refKey, base, multiplier, total, createdAt |
| `MedalUnlock` | medalID, unlockedAt |

Only **derived summaries** (`DailyVitals`) sync, never raw HealthKit samples.

# 8. GAME RULES (all constants in one `GameRules.swift` in FoundryCore)

| Event | Base XP | Rule |
|---|---|---|
| Bullseye day | +50 | all active habits fired on a day (needs ≥1 habit); once per day |
| Name struck | +30 | each target struck; reversed if un-struck |
| Focus | +20 per hour | `round(20 × minutes/60)` per **completed** session; abandoned = 0 |
| Lift record | +100 | a lift completes all prescribed sets at a weight higher than any previous completed weight for that lift |

- **Idempotency:** each event has a unique `(kind, refKey)`; re-triggering does not double-award; undoing removes the event. Totals always recompute from the ledger.
- **Recovery** (0–100) = `100 × (0.65·sleepScore + 0.25·stageScore + 0.10·(1 − min(awakeMin/60, 1)))`, where `sleepScore = min(asleep/goal, 1)` and `stageScore = min(1, (deep+REM)/(0.40·asleep))`.
- **Multiplier:** recovery ≥ 80 → **×1.2** on that day's XP (floored per event); otherwise ×1.0. Never a penalty. If vitals arrive after events were logged, recompute that day's multiplier.
- **Ranks:** Castaway 0, Vigilante 500, Hood 2,000, Green Arrow 5,000 XP.
- **Streak:** consecutive bullseye days ending today if today is a bullseye, otherwise ending yesterday. No freezes.
- **Ladder:** rung *r* weight = `startWeightLb + (r−1)·stepLb`. Completing every prescribed set at target reps at the current rung unlocks the next rung **for the next session**. Missing reps holds the rung. Never drops it.
- **Medals** (rule → title): first bullseye → *First Bullseye*; 7-day streak → *Seven Straight*; any lift reaches rung 4 → *Rung Four*; sleep goal met 5 nights in a row → *Iron Sleeper*; ≥4 completed focus sessions in one day → *Deep Focus*; 10 names struck lifetime → *Ten Struck*.
- **Mission line** (hub): compose from unmet items in this order, joined by `. `: open targets due today (`Strike one name` / `Strike N names`); habits left (`Fire one last arrow` when 1 left, else `Fire N arrows`); workout scheduled and not done (`Climb the ladder`); no focus session today (`Hold the Island`). Nothing left → `Bullseye. Hold the line.` Nothing configured yet → `Write your first name.`
- **Due tags:** `TODAY`; weekday abbreviation (`FRI`) within the next 6 days; else `MMM d`; overdue in red.

# 9. SCREENS (iPhone) — details

Common: top row = hexagon badge (left) with that screen's glyph + chip (right). Bottom = custom tab bar, 88 pt tall, `tabBar` fill, 1 pt `line` top border, five tabs: **Foundry, List, Quiver, Train, Vitals**, mono 11 pt uppercase labels, active tab in accent. Rank opens from the hub chip; Island from the hub Island node or the mission button. Portrait only; adaptive to any iPhone size; content scrolls if it does not fit.

## 9.1 Foundry hub (`Main.dc.html`)
- Chip (right): rank chevrons + total XP (`1,240`). Opens Rank.
- **Radar** (Canvas, see Appendix A): dotted orbit, faint rings, center emblem in a hexagon with a progress ring for **habits fired today**; five station nodes at 5 pentagon angles. Node rules:
  - **List:** outlined; red dot (top-right) when ≥1 open target is due today or overdue; filled accent when none open today.
  - **Quiver:** ring progress = habitsDone/habitsTotal; fully filled when bullseye.
  - **Train:** filled when today's session is complete; dashed muted "rest" style on an unscheduled day; outlined otherwise.
  - **Island:** filled once ≥1 session completed today; dashed muted otherwise.
  - **Vitals:** filled when last night's sleep is synced; dashed muted when no data or not authorized.
  - Each node is a button with a VoiceOver label + value (`List, 2 names left`). Tapping goes to that tab (Island opens the full-screen cover).
- Below: **Tonight's mission** card (mission line, section 8) with a round accent arrow button → starts an Island session. Then **streak**: big numeral + the week's seven arrow ticks (Mon–Sun): bullseye day = solid, today in progress = dashed accent, future = dim.
- Bullseye moment (last habit fired): center ring completes, emblem pulses once, `.success` haptic, one-time rank/medal toasts queue afterward.

## 9.2 The List (`List.dc.html`): a notebook page
- Paper card with spiral holes (r 6, 52 pt pitch), rows 76 pt, ruled hairlines, Caveat 700 names. Order: primary first, then open by due date, then struck (most recent first).
- **Primary** name is hand-circled in 3 pt red (slightly irregular ellipse, seeded per id; draw-on animation). Only one primary at a time.
- Tap a name to **strike** it: red 4 pt line draws left→right (0.35 s), `.success` haptic, +30 XP. Tap a struck name to restore. Swipe to delete. Long-press to edit. **Add** = round 64 pt accent button opens a sheet (text in Caveat, optional due date, "Make primary" toggle).
- Header chip: five pips (filled red = struck, hollow = open; `+N` if more than five).
- Empty state: blank page with `Write the first name.` in Caveat.

## 9.3 The Quiver (`Quiver.dc.html`): target and arrows
- Chip: `3 / 4` with arrow glyph. Target Canvas with one lodged arrow per fired habit (poses in Appendix A).
- Habit buttons (round 64 pt): fired = solid accent with dark glyph; pending = outline with soft glow; label mono 11 pt under it. Max 6 habits (row of up to 4, then wrap).
- **Fire** a pending habit: arrow flies into the target (spring ≈ 0.5 s), `.rigid` haptic; the last one triggers the bullseye moment. Tap a fired habit to undo (light haptic, XP reverses).
- **Auto rules** (per habit, optional, default off except seeded ones): `workout` fires when Health shows a workout ≥ 20 min today **or** a Foundry session is completed; `sleepDuration` fires when last night's sleep ≥ threshold (default 7 h). Auto-fired habits show `source = auto` and can still be undone.
- Week strip: seven small targets (bullseye = solid rings; today = partial arc; future = dashed). Seed habits on first run: Train, Eat, Read, Sleep.

## 9.4 Training (`Train.dc.html`): salmon ladder
- Chip: today's workout day name (`PUSH`) + dumbbell. Card: **ladder graphic** for the lead lift (window of 3 rungs above, the bar on the current rung, 2 below; Appendix A) + big weight numeral (Barlow Condensed 76 pt, accent), `LB · RUNG n`, three set dots, `NEXT {weight}` with up chevron.
- Below: 2×2 grid of lift tiles (name uppercase condensed 22 pt; set dots hollow → accent). Tap a tile → sheet with set logging: tap a dot = complete at target reps, long-press = adjust reps (0–20). Show last 5 sessions for that lift.
- Session complete: unlock animation (bar slides up one rung), `.success` haptic, record check (+100 XP if new max).
- Today's day is picked by weekday schedule; unscheduled day shows a **Rest day** state (with last night's Recovery if available) and lets him start any day. No lifts yet → guided "Build your first day" sheet (day name, weekdays, add lifts with start weight, step, sets × reps, lead lift).

## 9.5 Vitals (`Vitals.dc.html`): Apple Health
- Chip: `HEALTH SYNCED` (tap to refresh; shows time since last sync). **Sleep ring** (asleep / goal, 208 pt, 12 pt stroke) with duration in the middle; **stage bar** (deep/core/REM/awake with legend `DEEP 1:20`…); **Recovery pill** (`RECOVERY 82% · ×1.2 XP TODAY`); tiles for **resting heart rate** and **workouts this week `3 OF 4`** (goal from Profile); seven bars for workout minutes M–S (today in accent, past in `climbed`, none as a short dim stub).
- Empty/denied states designed like the rest of the app: not authorized → explanation + `Connect Health` button; denied → button that explains and opens Settings; no data yet → gentle `No sleep recorded yet` state.

## 9.6 Rank (`Rank.dc.html`)
- Back button + rank badge. Large emblem with XP progress ring, rank name in Barlow Condensed 44 pt, `1,240 / 2,000 XP`. Rank path (four nodes: done = solid, current = glow, locked = lock icon), then a 3×2 grid of medals (earned = accent ring; locked = dashed, dim). Gear button top-right opens Settings.
- Rank-up and medal unlocks show a brief full-width celebration (respect Reduce Motion).

## 9.7 The Island (`Island.dc.html`): focus
- Full-screen cover on `bgDeep`. Top: hexagon crosshair badge + `FOUNDRY FOCUS` pill (moon). Center: 264 pt ring timer (mono 56 pt time), session dots (goal from Profile), and the chosen target's name in Caveat with a hand-drawn red circle (pick from open targets; default primary). Bottom: three status rows (`Favorites can still call`, `Everything else muted`, `Signal stays on`) then `PAUSE` and `LEAVE ISLAND`.
- Timer uses an **end timestamp** (correct after backgrounding). Schedules one local notification at the end. While the Island is on screen, keep the screen awake. Completed → XP, session dot fills, `.success` haptic. Leave/abandon → no XP.
- Session length options in Settings: 15 / 25 / 45 / 60 min.

# 10. MAC APP

- `NavigationSplitView`: 232 pt sidebar (`tabBar` fill; wordmark `FOUNDRY` + hexagon emblem; items with glyphs: Foundry, The List, The Quiver, Training, Vitals, The Island, Rank; rank/XP card pinned at bottom). Window minimum ≈ 1200×760, default ≈ 1360×860.
- **Foundry (default detail) = the dashboard in `Mac.dc.html`:** header (date, streak pill, Focus status pill, `ENTER THE ISLAND` button), row 1 (hub | target + habits + week | notebook), row 2 (Vitals | ladder | Island start). Use flexible grid columns so it adapts to window width.
- Other sidebar items show larger, Mac-adapted versions of the same screens, sharing components with iPhone. The Island opens as a large focus view in the window.
- **MenuBarExtra** (`.window` style, 320×420, `MenuBar.dc.html`): emblem, focus pill, timer ring with the target name, four habit buttons, `PAUSE` / `LEAVE ISLAND`. When no session is running the ring shows the planned time and a `BEGIN FOCUS` button. Menu bar icon: the hexagon-arrowhead as a template image.
- Keyboard: `⌘1…⌘7` switch sections, `⌘N` new name, `⌘⇧I` enter the Island, `⌘,` Settings. Full VoiceOver and keyboard focus rings.
- **Health on Mac:** Health data is read on iPhone only. Expect `HKHealthStore.isHealthDataAvailable()` to be false on Mac (verify). The Mac reads `DailyVitals` synced from the iPhone. If sync is off or no data yet: show a designed empty state (`Health lives on your iPhone. Turn on iCloud sync to see it here.`).

# 11. HEALTHKIT (iPhone)

- Read-only: `sleepAnalysis`, workouts, `restingHeartRate`. Purpose string: *"Foundry reads your sleep, workouts, and resting heart rate to show your Vitals and power your Recovery bonus. Nothing leaves your devices except your own private iCloud."* No writes.
- Use `HKSampleQueryDescriptor` / `HKAnchoredObjectQueryDescriptor` (async). Refresh on foreground, on `HKObserverQuery`, and with background delivery enabled when the entitlement is present (handle failure quietly).
- **Sleep session builder (in FoundryCore, unit-tested):** window = previous day 6:00 PM → today 12:00 PM. Treat unspecified asleep as core. Samples from multiple sources overlap: group by source, choose the source with the most asleep minutes, and union its intervals per stage so nothing double counts. Output deep/core/REM/awake/asleep minutes.
- Workouts: sum durations per day for the week; count workouts. Resting HR: latest sample from today or yesterday.
- Write results into `DailyVitals`, recompute Recovery and the day's XP multiplier, auto-fire eligible habits.
- Simulator has no real data: in DEBUG only, **Settings → Load demo data** seeds targets, habits, a workout day with lifts, 14 days of vitals, XP history, and medals so every screen can be verified and screenshotted. Release builds ship with **no demo data**.

# 12. FOCUS (ISLAND) INTEGRATION — read carefully

**Fact:** iOS and macOS provide **no public API for an app to turn a Focus on or off directly** (Apple Developer Forums confirm this is still the case). Do not attempt private APIs. The supported approach is:

1. **Shortcuts do the switching.** Two Shortcuts in his library, named exactly `Foundry Focus On` and `Foundry Focus Off`, each using the *Set Focus* action on a custom Focus called **Foundry**. iCloud syncs them to the Mac.
2. `FocusService` (protocol + iOS/macOS implementations) runs them with `shortcuts://x-callback-url/run-shortcut?name=…&x-success=foundry://focus/on-ok&x-cancel=foundry://focus/cancelled&x-error=foundry://focus/error`. Handle the callbacks with `.onOpenURL`. Expect a brief hop to the Shortcuts app and back; explain that plainly in the setup screen.
3. **Focus Filter:** add a `SetFocusFilterIntent` ("Foundry behavior") with one parameter, `startIslandWhenOn` (default off). Conform it to `LiveActivityIntent` so it runs in the app process when the app is closed (a known workaround; verify on device). It records "Foundry Focus is active" and optionally starts an Island session. No app-extension target needed.
4. **Setup wizard** (Settings → Focus, also offered once after onboarding, skippable): three short steps with a live status check: (a) create a custom Focus named *Foundry* allowing calls from Favorites, Alarms, and Foundry's notifications, (b) create `Foundry Focus On` (Set Focus → Foundry → Turn On), (c) create `Foundry Focus Off`. Buttons open the Shortcuts app; a `Test` button runs On then Off and reports success. `SETUP.md` also documents the optional zero-hop route: Shortcuts personal automations that run immediately when the Foundry app opens/closes.
5. **Behavior:** starting a session runs On (if set up); ending, completing, or leaving runs Off. If Focus is not set up, the session still works and the pill reads `SET UP FOCUS` (muted, tappable). The pill states: **On** (accent outline), **Off**, **Set up**. Never block the timer on a Shortcut failure.
6. Airplane mode is never used: the three status rows on the Island are honest about that (`Signal stays on`).

# 13. SETTINGS AND ONBOARDING (required infrastructure, styled to match)

- **Onboarding** (first run): emblem welcome → pick starting habits (four prefilled, editable) → optional Connect Health → optional Focus setup → land on the hub. Skippable steps stay reachable in Settings.
- **Settings** (iPhone: gear on Rank; Mac: Settings scene): Habits (add, rename, reorder, archive, glyph, auto rule + threshold), Goals (sleep goal, weekly workouts, focus length, sessions per day), Health (status, Connect, iOS Settings hint), Focus (status, setup wizard, Test), Sync (iCloud on/off status, read-only), About (version, personal-use note), DEBUG only: Load demo data / Reset all data.
- Notification permission is requested only when the first Island session starts, with a one-line reason.

# 14. MOTION, HAPTICS, ACCESSIBILITY, PRIVACY

- Motion: arrow fire (spring), red strike draw-on, ladder bar slide, ring fills, bullseye pulse. Every animation has a Reduce Motion fallback (crossfade). Keep 120 Hz smooth: draw radar/target/ladder with `Canvas` or simple `Shape`s; avoid needless `drawingGroup`.
- Haptics (iPhone): `.rigid` on fire, `.success` on strike / bullseye / rung / session complete, `.light` on undo. Centralize in one `Haptics` helper; no-ops on Mac.
- Accessibility: Dynamic Type through xxxLarge on all real text (custom-drawn text scales with `@ScaledMetric`); every graphic has a label and value; Bold Text and Increase Contrast respected; 44 pt targets; full keyboard support on Mac.
- Privacy: `PrivacyInfo.xcprivacy` (no tracking, no collected data); HealthKit data never leaves the phone except as `DailyVitals` summaries in his own private iCloud.

# 15. TESTING AND DEFINITION OF DONE (you must do all of it)

1. `xcodegen generate` is clean and the committed project matches.
2. `swift test` (FoundryKit) passes. Tests must cover: XP ledger idempotency and reversal, rank thresholds, streak (today complete vs in progress, gaps), recovery formula and multiplier, ladder unlock/hold, sleep-session builder with overlapping sources, day-key edge cases (midnight, DST), target ordering, due-tag labels, mission-line composition, medal rules.
3. `xcodebuild` **build + test** for scheme `Foundry` on the **iPhone 18 Pro simulator** and build for `FoundryMac` (`platform=macOS`) both succeed with **zero warnings** in our code.
4. Launch on the simulator with demo data and capture every screen via `xcrun simctl io booted screenshot` into `docs/screenshots/`. Compare each against its mockup, fix mismatches (geometry, colors, spacing, copy), and re-capture. Launch the Mac app and do the same as far as the system allows (if screen capture is blocked by permissions, say so and skip).
5. Grep the tree: no `TODO`, `FIXME`, `fatalError` in UI paths, stray `print`, or hardcoded hex outside the token file.
6. Write `SETUP.md`: numbered, plain-language, for a non-developer, covering: open `Foundry.xcodeproj`, set his Team in Signing, enable iCloud/HealthKit (and the `Signing.local.xcconfig` toggles), plug in the iPhone 18 Pro, enable Developer Mode, trust the computer, choose the device, Run; allow Health when asked; create the Foundry Focus and the two Shortcuts (or use the wizard); turn on iCloud sync; a 10-item device QA checklist mirroring the spec.
7. Commit, push `v1-build`, and give the final report.

# 16. NOT IN V1: DO NOT BUILD (list in `IDEAS.md` and ask)

Apple Watch app · Live Activity / Dynamic Island timer · Home/Lock Screen widgets · extra Siri/App Shortcuts phrases · writing workouts to Health · iPad layout · notifications beyond the Island end alert · social/sharing · streak freezes · workout program libraries · App Store preparation · any analytics.

# 17. FINAL REPORT (short, plain English)

Give: what was built (one paragraph); what you verified and how (test counts, build results, screenshots list); what Nicholas must do by hand (link to `SETUP.md`, three bullets max); decisions you made that he might want to change (top 5 from `DECISIONS.md`); ideas parked in `IDEAS.md`; anything not verified and why.

---

# APPENDIX A: Reference geometry (design space → scale to fit; keep proportions)

**Hub (342×342 space, center 171,171).** Rings: r160 (`#16281d`, 1.5), r124 dotted (`#1f3a2a`, dash 2/7), r84 (`#16281d`). Crosshair ticks 22 long at the four sides. Spokes from center to each node (`#16281d`, 2). Center: solid `bg` disc r62; track r58 (`line`, 5); progress arc r58 (accent, 5, round, from top, clockwise); hexagon `M171 134l32 18.5v37L171 208l-32-18.5v-37z` (fill `surface`, accent 2); arrowhead `M171 148l15 20h-8v20h-14v-20h-8z` accent fill. Nodes (r28): **List** (171,47), **Quiver** (289,133), **Train** (244,271), **Island** (98,271), **Vitals** (53,133). Labels: mono 11 pt uppercase muted, centered 46 pt below each node center (List label at y=93). Red dot r7 at (192,27) on List. Quiver progress arc r28 stroke 4.

**Target (300×300, center 150,150).** Ring fills/radii: r140 `surface`, r105 `surfaceInset`, r70 `surface`, r35 `surfaceInset`, all 2 pt `lineStrong`; bull r12 `inkRed`. **Arrow** drawn along −y from its tip: shaft 96 long, 4 pt accent, round; fletching four strokes 3 pt: from (0,−84) and (0,−96), each `−9,−13` and `+9,−13`. Poses (tip x, tip y, rotation°) in fire order: (130,160,−30) (176,136,24) (148,186,150) (165,172,100) (136,142,−100) (158,150,60) (140,172,−140) (160,140,−10).

**Ladder (190×320 space).** Rails x=30 and x=120, y 8→316, 6 pt `lineStrong`, round. Rung y: 40, 90, 140, 190 (bar), 240, 290. Above the bar: rung 140 = next (accent 3 pt, chevron `M66 124l9-9 9 9` above it), rungs 90 and 40 = locked (`lineDim` dashed 3/5). Below: 240 and 290 = climbed (`climbed`, 4 pt). Bar: rect x12 y182 w148 h16 r8 accent; plates 12×36 at x6 and x154, y172, r4, `text` color. Weight labels mono 12 pt at x=138, baseline rungY+4 (next in accent, others muted; none for the bar).

**Notebook.** Paper `#e9e3cf`, radii 6 (left) / 16 (right), shadow 0 10 30 @50% black. Spiral holes r6 at x=11, y=20+52k, fill `bg`. Content padding 20/20/20/52. Row height 76, hairline `rgba(60,80,60,.25)`. Primary circle: 3 pt `inkRedPaper`, blob radii ≈ 46/40/44/38 over 34/38/32/36, name padded 16 h / 4 v.

**Rings (Island / Vitals).** Island: 264 space, r120 track 8 (`line`) + progress arc accent 8 round; inner guides r96, r72 (`#12241a`, 1.5); progress marker r11 at the arc end with a r18 halo at 30% opacity. Sleep ring: 208 space, r92, 12 pt stroke; inner guide r72.

**Tab bar.** 88 pt: 6 top / 8 side / 26 bottom padding; icon 24, mono 11 pt label, 4 gap.

# APPENDIX B: Copy (keep exactly)

Hub mission examples: `Strike two names. Fire one last arrow.` · Streak label `DAY STREAK` · Health chip `HEALTH SYNCED` · Recovery pill `RECOVERY 82% · ×1.2 XP TODAY` · Island rows `Favorites can still call` / `Everything else muted` / `Signal stays on` · Island buttons `PAUSE` / `LEAVE ISLAND` · Medals `FIRST BULLSEYE`, `SEVEN STRAIGHT`, `RUNG FOUR`, `IRON SLEEPER`, `DEEP FOCUS`, `TEN STRUCK` · Ranks `CASTAWAY`, `VIGILANTE`, `HOOD`, `GREEN ARROW` · Empty List `Write the first name.` · Mac Vitals empty `Health lives on your iPhone. Turn on iCloud sync to see it here.`
