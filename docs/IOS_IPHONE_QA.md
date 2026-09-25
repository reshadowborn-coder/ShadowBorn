# Shadowborn Act 0 — iPhone QA Contract

Target for the current mobile slice: iPhone, landscape, Godot 4.4.1 Mobile renderer over native Metal.

## Fixed iPhone runtime policy

- iPhone-only export target (application/targeted_device_family=0).
- arm64 only.
- Minimum iOS 16.0.
- Native Metal rendering.
- Sensor-landscape orientation: both landscape directions are supported.
- Authored performance modes remain 60 FPS Smooth and 30 FPS Battery.
- ProMotion 120 Hz is intentionally disabled for Act 0 so timing, thermals and battery behavior stay bounded by the authored 60 FPS ceiling.
- Status bar and home indicator are hidden during gameplay.
- Native iOS launch and the engine boot transition use the same dark Shadowborn background; the default Godot splash is not shown.
- iOS edge-system gestures are suppressed so an accidental first swipe does not steal gameplay input.
- HUD and movement controls use DisplayServer.get_display_safe_area() and are re-laid out after viewport changes/resume.
- Covenant weapon choices use enlarged touch targets.
- On iOS suspension the game writes only the last committed save snapshot. Tentative combat/forge/Room 5 state is never promoted because the app moved to the background.
- On iOS memory warning only rebuildable runtime caches are dropped; progression is not changed.

## Signing boundary

export_presets.cfg deliberately keeps application/app_store_team_id empty.

Do not commit an Apple Team ID, provisioning profile, certificate or private signing key to this repository. The GitHub macOS QA job injects a fake 10-character Team ID only to prove that Godot can generate the iPhone Xcode project. That artifact is not signed and cannot be installed as-is.

For a physical iPhone build, use a Mac with Xcode and a real Apple Developer Team:
1. set the Team in the generated Xcode project or the local Godot iPhone preset;
2. let Xcode manage the development provisioning profile for the QA bundle identifier;
3. select the connected iPhone as the run destination;
4. build and run from Xcode.

## Physical iPhone Act 0 pass

Run the complete Act 0 once without intentionally interrupting it. Then repeat the checkpoints below with interruption/resume.

1. Launch -> New Game -> choose Shadow form.
2. Exterior: Hound -> residual absorption -> Armless -> Temple reveal -> Shield -> Silver -> Faded Sigil -> Temple.
3. Confirm that neither landscape direction places touch controls, Settings, story text or combat buttons under the Dynamic Island/notch or home edge.
4. Keeper -> Forgotten Covenant. Tap every weapon-family row once before committing the intended family; each row must be easy to hit and must preview the matching family.
5. Confirm one weapon family. The choice must remain irreversible after confirmation and after relaunch.
6. Smith first forge. The +0 item must be equipped and the Catacomb passage must open.
7. Catacombs Rooms 1-4. Verify target/action buttons remain inside Safe Area and movement never sticks after opening/closing Settings.
8. Room 5 solo-limit 1v2 -> forced return -> Keeper -> story companion/team slot -> Room 5 rematch -> Act 0 complete.
9. Repeat with 30 FPS Battery and 60 FPS Smooth. Combat results must remain identical.

## iOS interruption matrix

At each point below, send the app to background, wait a moment, then resume. Also perform one test where the app is terminated while backgrounded and relaunched with Continue.

- Exterior before Hound.
- Immediately after Hound.
- During an active 1v1 fight.
- Immediately after Temple reveal.
- At Faded Sigil / Temple threshold.
- Covenant menu before confirming a family.
- Immediately after weapon confirmation.
- Immediately after first forge.
- Catacomb Room 2 or 3.
- During the Room 5 solo-limit fight.
- Immediately after forced Temple return.
- Immediately after companion unlock.
- During Room 5 rematch.
- Immediately after Act 0 completion.

Expected rule: Continue must resume from the last committed checkpoint. No duplicate Silver, Covenant choice, forge, story companion, Room 5 completion or outward story event is allowed.

## Device observations to record

For every physical-device run, record:
- exact iPhone model and iOS version;
- git SHA/Xcode artifact SHA;
- landscape direction;
- performance mode;
- any Safe Area overlap;
- any stuck touch direction after a system gesture or modal;
- frame pacing/visible hitch during combat;
- abnormal heat/battery drain;
- interruption point and resumed checkpoint;
- screenshot or short screen recording for every failure.

CI generates the iPhone-only Xcode project on macOS, resolves its build settings, compiles an unsigned `iphoneos` app, verifies the bundle contract, launch storyboard and privacy manifest, then uploads the source-bound QA artifact.\n\nPhysical-device QA is the final evidence layer. Automated Xcode compilation cannot prove real touch ergonomics, thermal behavior, system-gesture behavior, or device-specific Metal performance.
