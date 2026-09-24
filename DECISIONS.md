# Decisions

Choices made where the spec was silent or had to bend. One line each: decision, then why.

## Build and project
- No signing certificate was found on this Mac, so the committed defaults sign locally with iCloud off; team `GVCGVNM4PS` (from Xcode's template project) is suggested in SETUP.md. Why: builds work today; turning on sync needs your account.
- The Xcode starter template (`The Foundry.xcodeproj`, `The Foundry/`, test folders) from the first commit was left untouched, not deleted. Why: deleting existing repo content needs your OK.
- Swift 6 language mode with main-actor default isolation. Why: it compiled with zero warnings, so the stricter mode won.
- Git remote `origin` was added (the local repo had none) and work is on `v1-build`.
- Caveat ships only as a variable font, so `scripts/make-caveat-bold.py` bakes a static Bold (wght 700) instance. Why: reliable weight on both platforms.
- String catalog is filled from the compiler's extracted strings with `scripts/update-strings.py`. Why: command-line builds don't sync the catalog the way the Xcode editor does.

## Game rules
- Any undo of a habit (manual or auto) stops auto rules re-firing it that day. Why: otherwise undo would be pointless for auto habits.
- A lift that climbs shows the new rung straight away ("CLIMBED FROM 155") while today's sets stay logged at the old weight. Why: the spec's "bar slides up one rung" animation needs the new rung on screen.
- Undoing a set on the same day that broke a climb steps the rung back and removes the record XP. Why: fixes mis-taps; missing reps still never drops a rung.
- A "lift record" is keyed per lift per day, and the very first clean session counts as a record. Why: "higher than any previous completed weight" is true when there is none.
- A struck name keeps its primary flag but loses the red circle; deleting a struck name keeps the XP. Why: XP only reverses on un-strike, per spec.
- "Ten Struck" counts strike XP events, so deleting struck names doesn't take the medal away.
- The primary name's due tag is red (as in the mockup), as are overdue tags.
- Recovery below 80 shows "RECOVERY 64% · NO BONUS" (the mockup only showed the boosted copy).
- Resting heart rate for a day uses that day's latest reading, else the day before.
- Sleep counts toward the day you wake up (6 PM to noon window), so "today's" Vitals are last night.

## Screens
- The mission arrow opens the Island and starts a session; the Island node opens it without starting.
- On an unscheduled day with no session logged, Train shows a Rest day card with "START {DAY}" buttons for each day.
- Train has small "EDIT {DAY}" and "NEW DAY" buttons so lifts can be changed after the first build.
- Vitals shows data whenever data exists (synced or demo), and only shows the Connect/denied screens when there is none. iOS never reveals whether read access was denied, so "no data after asking" is treated as the denied case with a "Check Health access" explainer.
- The Island's target name is a menu of open names (default: primary).
- The menu bar popover shows the first four habits (the mockup's four slots).
- The Mac dashboard scrolls if the window is shorter than both rows.
- The Focus Filter only acts on its "on" call (the "off" call arrives with default values, so it can't be told apart). It sets the pill to On and, if its switch is on, starts a session.
- Wizard step A (create the Focus) is marked done by you, since apps can't see Focus settings. Steps B and C are confirmed by the Test.
- Menu bar "Begin focus" on the very first session opens the Island window so the one-line notification reason is shown before the system prompt.
