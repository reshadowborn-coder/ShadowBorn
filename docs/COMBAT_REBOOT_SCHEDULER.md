# Checkpoint 01 deterministic Turn Meter scheduler

## Why this exists

The Checkpoint 01 reboot intentionally replaced the pre-reboot combat stack with a small playable slice. The current `BattleController` still fills Turn Meter in variable-rate `_process(delta)` and chooses the READY actor from sampled post-frame meter.

Multiplying by delta preserves approximate fill speed, but it does **not** preserve threshold-crossing order when two actors cross inside the same coarse frame. A slower actor can reach 100% first in real simulation time and still lose because a faster actor overshoots farther before the frame is sampled.

The reboot therefore needs a deterministic scheduling core before more combat systems are layered onto it.

## Scope

`BattleTurnScheduler` owns only:

- actor registration;
- integer Speed;
- integer Turn Meter (0..10,000 with bounded overflow);
- direct meter adjustment;
- exact next-READY advancement;
- stable ties;
- conversion from abstract scheduler ticks to presentation wait seconds.

It intentionally does **not** yet own:

- cooldown semantics;
- Stun / Freeze / Sleep;
- Resolve;
- Provoke / Silence;
- Extra Turns;
- reactions;
- target selection;
- damage.

Those were implemented before the reboot, but bringing them back wholesale would silently re-authorize removed behavior. They must be migrated one contract at a time.

## Deterministic reference

The current reboot values map cleanly:

- Shadow SPD 53, initial meter 18% -> 1,800 bp.
- Grave Hound SPD 45, initial meter 0.
- 110 abstract ticks per second reproduces the existing 1.10 meter-fill coefficient.

The scheduler advances directly to the next threshold rather than asking render frames to decide the winner.

## Migration seam

This PR only restores and tests deterministic scheduling. It does not replace live `BattleController` timing yet.

The safe integration order is:

1. keep the current playable presentation unchanged;
2. instantiate `BattleTurnScheduler` inside `BattleController`;
3. make scheduler tickets authoritative;
4. use `ticks_to_seconds()` only as presentation pacing;
5. keep Manual and AUTO on the same legality path;
6. add golden traces for cooldown and hard-control semantics before migrating those systems;
7. only then consider restoring pre-reboot reactions/effects.

## Source provenance

The algorithm is a narrowed reimplementation of principles already developed in Shadowborn's own pre-reboot `CombatTurnTimeline`, adapted to the smaller Checkpoint 01 scope. No proprietary external code is used.
