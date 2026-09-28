# Checkpoint 01 cooldown / control opportunity contract

## Working semantic

For the reboot combat, a cooldown value `N` means:

> the skill is blocked for the next N **actionable owner opportunities** after it is used.

Example for Shadow A2 with CD3:

- S0: use A2 -> cooldown becomes 3;
- S1: A2 blocked; Shadow performs another legal action -> cooldown 2;
- S2: A2 blocked; legal action -> cooldown 1;
- S3: A2 blocked; legal action -> cooldown 0;
- S4: A2 is ready.

This closes the prior start-of-turn off-by-one where CD3 effectively blocked only two later choices.

## Hard control

Current hard-control tags are Stun, Freeze and Sleep.

A hard-controlled owner opportunity is consumed, but it is **not actionable**:

- the control duration decreases;
- the actor does not receive Manual/AUTO skill selection;
- skill cooldowns do not advance.

This matches the RAID comparator behavior documented by Plarium for Stun, Freeze and Sleep: the affected Champion cannot act and cooldowns do not refresh while those control debuffs are active.

The user-authoritative Shadowborn requirement remains the broader RAID-like rule that Stun/Sleep/Freeze skip turns. This document freezes the current implementation rule for cooldown interaction; it does not silently promote every RAID secondary rider into Shadowborn canon.

## Non-goals in this slice

Not promoted by this change:

- Freeze incoming-damage reduction;
- Sleep break-on-active-damage;
- Resolve/anti-lock refunds;
- Extra Turns;
- Provoke/Silence;
- live Poison timing.

Those are separate semantic gates.

## Authority boundaries

- `BattleTurnScheduler` decides which actor owns the next opportunity.
- `BattleRules.consume_control()` decides whether hard control steals that opportunity.
- `BattleRules.resolve_action_cooldowns()` advances cooldowns only after a real committed action.
- Manual and AUTO read the same cooldown state through `BattleRules.cooldown_ready()`.
- UI displays authoritative cooldown state; UI never decrements it.

## Acceptance

Executable gates:

1. CD3 must produce exactly 3 -> 2 -> 1 -> 0 across three later legal actions.
2. A one-turn Stun with A2 at CD3 must consume the owner opportunity and Stun duration while leaving A2 at CD3.
3. Manual and AUTO continue sharing the same action authority path.
4. 30/60 FPS and x1/x2 must not alter the semantic trace.

## Provenance

- Current Shadowborn reboot BattleController/BattleRules.
- Historical pre-reboot Shadowborn turn contract used as project archaeology, not copied wholesale.
- Plarium official RAID buff/debuff guide as comparator behavior:
  https://forum.plarium.com/raid-shadow-legends/673_guides-and-tutorials/1700953_list-of-buffs-and-debuffs/
