# Shadowborn Turn Meter Combat Contract

## Goal
Act 1 combat uses a deterministic speed-driven turn timeline instead of a fixed "player action -> full enemy phase" loop. Act 0 remains compatibility-locked unless it is explicitly migrated later.

## Timeline
- Every combatant owns a Turn Meter from 0 to 10,000.
- Effective SPD fills that meter. Higher SPD therefore produces more turns over time, not faster animations.
- Overflow above 10,000 is preserved up to a bounded cap so fast actors and meter boosts are not silently discarded.
- Direct Turn Meter fill/cut is separate from SPD modification.
- Exact ties are deterministic: higher overflow, then higher effective SPD, then stable registration order.
- Extra Turns are a separate bounded queue and do not require natural meter fill.

## Owner-turn effects
Timed buffs/debuffs count down on the affected actor's own turns, including genuine Extra Turns.

Hard control:
- Stun: loses the turn.
- Freeze: loses the turn and takes 75% incoming damage while frozen.
- Sleep: loses the turn, but direct/active damage wakes the target. Periodic damage does not.
- A hard-controlled skipped turn does not refresh skill cooldowns.
- Silence does not remove the turn; it blocks active skills while leaving the default attack available.
- Provoke exposes a forced target contract for targeting/UI.

## Resolve — Shadowborn anti-lock rule
Repeated hard control should be strong without creating a permanent no-input lock.
- First consecutive skipped hard-control turn refunds 10% Turn Meter toward recovery.
- Second refunds 20%.
- Third and later are capped at 30%.
- Taking a real action clears Resolve.

This does not negate Stun/Sleep/Freeze: the controlled unit still loses the turn. It only shortens repeated lock chains.

## Act 1.1 tuning
Prototype SPD values:
- Shadow: 100
- Sewer Rat: 92
- Poison Rat: 96
- Pack Rat A: 98
- Pack Rat B: 92

The values intentionally preserve the authored tutorial flow while proving that each rat owns an independent timeline slot. Future enemies, gear, buffs and debuffs can create overtakes and multiple actions naturally.

## Cooldowns and Poison
- A2 cooldown counts only on later actionable Shadow turns.
- Enemy turns do not refresh Shadow cooldowns.
- Stun/Freeze/Sleep skipped turns do not refresh Shadow cooldowns.
- Poison ticks at the beginning of Shadow's turn before the player receives input.
- Poison still advances on a hard-controlled Shadow turn because the turn occurred even though the action was denied.

## Safety
- Turn state inside an active fight is transient for Act 1.1.
- iOS suspend/kill resumes from the last committed world checkpoint, never from a half-resolved animation/turn.
- Irreversible story transitions still save atomically before presentation.


## Reactions are not turns
Counterattacks, assists, follow-ups and interrupts use a separate bounded reaction queue.
- A Reaction never fills or consumes Turn Meter.
- A Reaction never advances owner-turn buff/debuff duration.
- A Reaction never refreshes skill cooldowns merely by occurring.
- Reactions resolve by explicit priority and stable insertion order.
- Duplicate actor/reaction identities are blocked inside one source-turn window.
- Reaction chains are depth-limited and the pending queue is capped to prevent passive loops.

An Extra Turn is different: it is a genuine owner turn and therefore participates in owner-turn durations and turn-based rules.
