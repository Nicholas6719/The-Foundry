# Setting up The Foundry on your iPhone and Mac

Everything that could be done on the Mac without you is done. These are the steps that need your hands. About 20 minutes.

## 1. Tell Xcode who you are

1. Open `Foundry.xcodeproj` in Xcode.
2. Xcode › Settings › Accounts. Make sure your Apple ID is listed. Click it and note the **Team ID** (10 letters/numbers, for example `GVCGVNM4PS`).
3. In Finder, open the `Config` folder. Duplicate `Signing.local.xcconfig.example` and rename the copy to `Signing.local.xcconfig`.
4. Open it in TextEdit and set:
   - `DEVELOPMENT_TEAM = ` your Team ID.
   - `FOUNDRY_HEALTHKIT = YES` (lets the iPhone read Apple Health; works with a free account).
   - `FOUNDRY_CLOUDKIT = YES` **only if you pay for the Apple Developer Program** ($99/year). This turns on iCloud sync between iPhone and Mac. With a free account leave it `NO`; both apps still work, they just don't share data.
5. Close and reopen the project so Xcode picks up the file.
6. Click the blue **Foundry** project icon › target **Foundry** › **Signing & Capabilities**. "Automatically manage signing" should be on and your team selected. If Xcode shows a red error, click **Try Again**. Do the same for the **FoundryMac** target.

## 2. Put it on your iPhone 18 Pro

1. Plug the iPhone into the Mac with a cable. Unlock it. Tap **Trust** on the phone if asked.
2. On the iPhone: Settings › Privacy & Security › **Developer Mode** › On. The phone restarts; confirm when it asks.
3. In Xcode's top bar, choose the **Foundry** scheme and your iPhone as the destination.
4. Press **Run** (▶). The first time, the phone may say the developer isn't trusted: Settings › General › VPN & Device Management › your Apple ID › **Trust**. Then run again.
5. When Foundry asks to **Connect Health**, allow Sleep, Workouts and Resting Heart Rate.

With a free account the app stops opening after 7 days; just press Run again from Xcode to refresh it.

## 3. Put it on your Mac

1. Choose the **FoundryMac** scheme and **My Mac**, press Run.
2. Look for the hexagon-arrow icon in the menu bar: that's the Island popover.

## 4. Make the Island switch on a Focus (optional, recommended)

Apple doesn't let apps flip a Focus on directly, so two tiny Shortcuts do it. Foundry has a guided version of this in **Rank › ⚙ › Focus › Set Up Foundry Focus** (it also has a Test button).

1. iPhone Settings › **Focus** › **+** › **Custom**. Name it **Foundry**. Pick an icon.
   - People: allow calls from **Favorites**.
   - Apps: allow **Foundry** (and anything else you want).
   - Optional: scroll to **Focus Filters** › Add › Foundry › **Foundry behavior**, and turn on "Start the Island when this Focus turns on" if you want turning on the Focus by hand to start a session.
2. Open **Shortcuts** › **+**. Add the action **Set Focus**, choose **Foundry**, **Turn On**. Name the shortcut exactly **`Foundry Focus On`**.
3. New shortcut again: **Set Focus** › **Foundry** › **Turn Off**. Name it exactly **`Foundry Focus Off`**.
4. Back in Foundry's setup screen, press **Test**. You'll bounce to Shortcuts and back twice; it should say both shortcuts ran.

Shortcuts sync to the Mac through iCloud, so the Mac app uses the same two shortcuts.

**Zero-hop option:** instead of the quick trip to Shortcuts, you can make Shortcuts › Automation › **App** › Foundry › "Is Opened" › Run Immediately › Set Focus Foundry On (and "Is Closed" › Off). This turns Focus on whenever Foundry is open, not only during Island sessions.

## 5. iCloud sync (paid account only)

1. Set `FOUNDRY_CLOUDKIT = YES` (step 1.4) and run both apps once from Xcode.
2. Make sure both devices are signed into the same iCloud account with iCloud Drive on.
3. Settings › Sync inside Foundry should say **On**. Vitals then appear on the Mac a minute or so after the iPhone reads them.

## Device checklist (10 checks)

1. Hub: the five station nodes open their screens; the Island node opens the Island.
2. List: add a name with a due date; tap it to strike (red line draws, +30 XP on the rank chip); tap again to restore; swipe left to delete; long-press to edit.
3. Quiver: fire each habit (arrow flies in, firm tap feel); firing the last one pulses the hub emblem and adds +50 XP.
4. Train: build a day, log all sets on the lead lift; the bar climbs one rung and "RUNG UNLOCKED" appears.
5. Vitals: after allowing Health, last night's sleep, stages and Recovery show; the chip refreshes when tapped.
6. Recovery ≥ 80% shows "×1.2 XP TODAY" and XP earned that day is boosted.
7. Island: start a session, lock the phone, come back later: the time is still right. A notification arrives at the end.
8. Island with Focus set up: starting turns the Foundry Focus on (moon in the status bar); Leave turns it off.
9. Rank: medals unlock with a banner; the gear opens Settings.
10. Mac: ⌘1–⌘7 switch sections, ⌘N adds a name, ⌘⇧I enters the Island, the menu bar popover fires habits.
