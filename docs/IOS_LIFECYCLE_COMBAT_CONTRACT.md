# iOS lifecycle / combat pause contract

## Scope

Shadowborn is iPhone-first. Leaving foreground focus, opening a system overlay, locking the device, or sending the app to the background must never advance combat invisibly.

This contract covers the current Checkpoint 01 runtime only. It does **not** yet provide kill/relaunch persistence.

## Platform facts

Godot exposes mobile application lifecycle notifications through `MainLoop.NOTIFICATION_APPLICATION_PAUSED` and `MainLoop.NOTIFICATION_APPLICATION_RESUMED`. Focus-in/out notifications are also available on mobile.

On iOS, work started from the application-paused notification has only a short completion window (Godot documents approximately five seconds). The pause handler therefore performs no heavy serialization, networking, asset work, or scene rebuild.

Apple's UIKit lifecycle guidance says games should pause ongoing work when the scene/app resigns active, and background apps should do minimal work.

## Shadowborn policy

Two independent blockers are tracked:

- application paused;
- application focus lost.

The SceneTree resumes only after **both** blockers are clear. This prevents an ordering race such as:

1. focus out;
2. application paused;
3. application resumed;
4. focus in.

A partial resume signal must not restart combat early.

## Timer rule

All semantic battle waits use `SceneTree.create_timer(..., process_always=false)`.

This is essential because `SceneTree.create_timer()` defaults to `process_always=true`, which means a default one-shot timer can keep processing while the tree is paused.

Battle wait bookkeeping also subtracts only the deliberately scheduled active-time slice. It never subtracts raw `Time.get_ticks_usec()` wall time across a suspension. Background wall time is not gameplay time.

## What is frozen

During lifecycle pause:

- Turn Meter scheduling is already semantically decided by the deterministic scheduler;
- pending windup cannot reach damage impact;
- recovery/death/control-skip delays stop;
- physics, animation processing and normal node processing follow SceneTree pause behavior.

After resume, the same pending action continues from its remaining active-time budget.

## Executable acceptance

Headless regression must prove:

1. focus-out pauses immediately;
2. focus-in does not resume while the OS-paused blocker remains;
3. only clearing both blockers resumes;
4. pause during Shadow A2 windup produces zero impacts for wall-clock time longer than the normal x2 windup;
5. resume produces exactly one Shadow A2 impact, preserving the already-authoritative actor/action.

## Open reliability gap

The Checkpoint 01 reboot currently has no active save manager. iOS may terminate a background/suspended app to reclaim resources, so pause/resume safety is not equivalent to crash/kill recovery.

Next persistence work must define an atomic checkpoint snapshot and schema/version policy before claiming lifecycle reliability across process death.

## Primary references

- https://docs.godotengine.org/en/latest/classes/class_mainloop.html
- https://docs.godotengine.org/en/4.7/classes/class_scenetree.html
- https://docs.godotengine.org/en/4.7/tutorials/scripting/pausing_games.html
- https://developer.apple.com/documentation/uikit/managing-your-app-s-life-cycle
- https://developer.apple.com/documentation/uikit/uiscene/willdeactivatenotification
