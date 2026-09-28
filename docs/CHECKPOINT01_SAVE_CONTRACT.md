# Checkpoint 01 save / process-death contract

## Goal

Checkpoint 01 must survive iOS process death without serializing half-finished combat presentation.

The current reboot has only three durable semantic boundaries:

- `title`;
- `awakening`;
- `first_battle`.

A process killed during battle restarts that encounter from its stable start. It does **not** restore windup, impact, recovery, animation time, VFX, tween state or an in-flight Turn Meter presentation.

## Why this is deliberately small

The pre-reboot project had a much larger `SaveManager` with bounded schema normalization, tmp/backup promotion and migration logic. That implementation was removed by the Checkpoint 01 reboot because most of its fields belonged to the old Act 0/Act 1 runtime.

This implementation reuses only the durable principles:

- bounded/versioned schema;
- write to a temporary candidate;
- flush;
- read/validate candidate before touching the primary;
- rotate primary to previous-good backup;
- promote tmp to primary;
- recover a valid tmp if a crash happened in the primary→backup / tmp→primary window;
- fall back to previous-good backup on corruption.

No old story/progression fields are silently restored.

## Envelope

The on-disk envelope contains:

- format id;
- JSON payload string;
- SHA-256 of that exact payload string.

The inner v1 payload contains only:

- `version`;
- monotonically increasing `generation`;
- `checkpoint`.

Unknown fields are not propagated.

This checksum is corruption/tamper detection, not an anti-cheat security mechanism.

## iOS lifecycle rule

The pause notification remains lightweight. Stable checkpoints are committed when the game crosses semantic boundaries, not because iOS is already suspending the app.

This avoids relying on a termination callback and avoids doing heavy persistence work inside the short background transition window.

## Current resume behavior

- no valid save / `title` -> title screen;
- `awakening` -> restart AwakeningStage from its beginning;
- `first_battle` -> rebuild the first battle from its deterministic initial state;
- defeat -> persist `first_battle`;
- Checkpoint 01 victory -> persist `title` because no post-battle progression/reward transaction exists in the reboot yet.

When the next real progression state lands, it must become a new explicit stable checkpoint before victory can resume forward.

## Failure injection

CI covers:

- first and second generations;
- corrupt/truncated newest primary -> previous-good backup;
- interrupted promotion with missing primary + valid tmp -> tmp recovery;
- syntactically valid payload tamper with stale SHA-256 -> rejection + backup recovery;
- invalid presentation checkpoint -> rejection;
- real GameRoot route reconstruction for title, awakening and first battle.

## Open gates

Headless atomic recovery is necessary but not equivalent to physical-device durability.

iPhone 13 Pro validation still needs:

1. write checkpoint;
2. background app;
3. terminate from Xcode / OS process;
4. relaunch;
5. confirm the intended stable route;
6. repeat during Awakening and multiple battle phases;
7. inject truncated/corrupt newest generation in a QA build where feasible.

## Primary references

- Godot 4.7 FileAccess / DirAccess documentation;
- Apple Foundation atomic-write behavior;
- Apple UIKit lifecycle guidance;
- historical Shadowborn pre-reboot SaveManager as project provenance only.
