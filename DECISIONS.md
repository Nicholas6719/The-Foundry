# Decisions

Choices made where the spec was silent or had to bend. One line each: decision, then why.

## Build and project
- No signing certificate was found on this Mac, so the committed defaults sign locally with iCloud off; team `GVCGVNM4PS` (from Xcode's template project) is suggested in SETUP.md. Why: builds work today; turning on sync needs your account.
- The Xcode starter template from the first commit (`The Foundry.xcodeproj` and its folders) was removed at your request; `Foundry.xcodeproj` is the only project.
- Swift 6 language mode with main-actor default isolation. Why: it compiled with zero warnings, so the stricter mode won.
- Git remote `origin` was added (the local repo had none) and work is on `v1-build`.
- Caveat ships only as a variable font, so `scripts/make-caveat-bold.py` bakes a static Bold (wght 700) instance. Why: reliable weight on both platforms.
- String catalog is filled from the compiler's extracted strings with `scripts/update-strings.py`. Why: command-line builds don't sync the catalog the way the Xcode editor does.

## iCloud sync safety
- When sync produces two copies of the profile, every device keeps the oldest one (then the lowest id) and merges the on/off flags into it. Why: devices must agree on the winner, or each deletes the other's copy.
- Synced copies of a day summary or a day's vitals are all updated together, never deleted. Why: deleting "extras" on two devices at once could wipe history.
- If two devices both seeded the starting habits, identical copies (same name and icon) are archived, keeping the lowest id. Why: stops the Quiver doubling to eight arrows.
- With iCloud on, first-run onboarding waits up to 8 seconds for another device's data. Why: a second device shouldn't re-onboard or re-seed.
- Screens refresh when iCloud delivers changes from the other device.

## Game rules
- The workout auto rule needs one workout of 20+ minutes; several short ones don't add up. Why: spec says "a workout ≥ 20 min".
- "Strike N names" in the mission counts names due today only; overdue names still light the List's red dot.
- The bullseye moment (pulse, haptic, toasts held back) plays whether the last arrow was fired by hand or by an auto rule.
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
- Quiver redesigned at your request (habit rows merged with a quiver rack): pending habits sit "in the quiver" as arrows with a FIRE button; fired ones move to "in the target" with the time and tap-to-undo; the week strip sits in a card with the streak. The round habit buttons remain on the Mac dashboard and menu bar, where space is tight.
- The Island clock dims and shows PAUSED while paused; its digits roll instead of crossfading.
- At large text sizes open List names wrap to two lines, and the sleep-stage legend wraps to two rows.
- Health permission uses SwiftUI's `healthDataAccessRequest`, which presents from the current screen. Asking HealthKit directly left the sheet invisible behind onboarding and Settings.
- The mission arrow opens the Island and starts a session; the Island node opens it without starting.
- On an unscheduled day with no session logged, Train shows a Rest day card with "START {DAY}" buttons for each day.
- Train has small "EDIT {DAY}" and "NEW DAY" buttons so lifts can be changed after the first build.
- Vitals shows data whenever data exists (synced or demo), and only shows the Connect/denied screens when there is none. iOS never reveals whether read access was denied, so "no data after asking" is treated as the denied case with a "Check Health access" explainer.
- The Island's target name is a menu of open names (default: primary).
- The menu bar popover shows the first four habits (the mockup's four slots).
- The Mac dashboard scrolls if the window is shorter than both rows.
- The Focus Filter only acts when its "Start the Island" switch is on: then it marks the pill On and starts a session without re-running the On shortcut. The system's "off" call arrives with default values, so with the switch off the two calls can't be told apart and the filter does nothing.
- Wizard step A (create the Focus) is marked done by you, since apps can't see Focus settings. Steps B and C are confirmed by the Test.
- Menu bar "Begin focus" on the very first session opens the Island window so the one-line notification reason is shown before the system prompt.
