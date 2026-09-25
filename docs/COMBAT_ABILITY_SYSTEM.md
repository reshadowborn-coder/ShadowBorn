# Shadowborn Ability, Passive and Talent Architecture

## Why this layer exists
The turn meter is only the scheduler. Skills, passives, talents, auras, gear and statuses must not each invent their own combat timing or mutate shared definitions.

Shadowborn separates:
1. static Skill Definition,
2. runtime Skill Spec,
3. Passive Definition,
4. Trigger Event + Passive Runtime,
5. Talent Definition + Talent Graph,
6. Effect Definition/Spec,
7. Turn Timeline,
8. Reaction Queue.

The goal is deterministic behavior, safe balance iteration and no passive recursion explosions.

## Skill contract
A character kit owns exactly one Default skill (A1), up to three Active skills, zero or more innate Passives, and at most one Aura slot.

The early Shadow tutorial remains intentionally small:
- A1 Default is available immediately.
- One Active skill is available immediately.
- The first innate Passive is reserved for level 10.
- Aura belongs to a later progression milestone and is not faked as a normal active skill.

Static CombatSkillDefinition stores identity, target rule, unlock level, base cooldown, semantic action tags and data-driven effect steps.

CombatSkillSpec is a battle-local copy. Rank upgrades patch the spec, never the static definition. Supported safe patch operations are deliberately small: add, basis-point multiply, set, cooldown delta and add semantic tag.

## Passive contract
Passives react to semantic CombatTriggerEvents, not to scene nodes or animation callbacks.

A passive declares:
- one trigger event,
- owner relation to the event (self source/target, ally source/target, enemy source/target, any),
- priority,
- Reaction kind,
- once-per-turn / once-per-battle guards,
- internal owner-turn cooldown,
- proc chance in basis points,
- required and blocked event tags,
- whether Block Passive Skills may suppress it,
- data-driven effect steps.

CombatPassiveRuntime owns trigger eligibility state. It does not directly apply damage or mutate the scene. Eligible passives become reactions that the normal Reaction Queue can resolve.

This makes recursion visible and bounded:
event -> passive eligibility -> reaction request -> bounded reaction queue -> semantic effect/application -> new event.

## Passive blocking
Block Passive Skills must be a first-class semantic rule. Ordinary passives are suppressed while blocked. A passive may be explicitly authored as unblockable, but that must be data, not a hidden exception in a controller.

## Talents
Talents are progression modifiers, not another combat scheduler.

CombatTalentDefinition contains:
- branch,
- tier,
- minimum level,
- max rank,
- point cost,
- prerequisite IDs,
- mutual-exclusion group,
- stat modifiers,
- skill patches,
- granted passive IDs.

CombatTalentGraph validates missing prerequisites and cycles and enforces a configurable active-branch cap. The default cap is two branches, but content can choose another value later.

The actual branch names and final talent content are intentionally not locked by this architecture. Content design can evolve without changing combat runtime.

## Skill upgrades
Skill ranks can improve damage coefficients, status chance, duration or cooldown. Rank application is deterministic and battle-local. It must never mutate the global definition because multiple heroes or encounters may share the same definition.

## Trigger vocabulary
The initial semantic event vocabulary includes:
Battle.Start, Turn.Start, Turn.Skipped, Action.Committed, Hit.Before, Hit.After, Damage.Active.Taken, Damage.Periodic.Taken, Hit.Critical, Actor.Kill, Actor.Death, Effect.Applied, Effect.Removed and Turn.End.

Future events should be added only when they describe a genuinely different semantic moment. Avoid one-off hero-specific event names.

## Reactions vs turns
A Passive triggering a counter, assist, follow-up or interrupt creates a Reaction. Reactions are not natural turns and do not advance cooldowns, buff duration or Turn Meter.

Extra Turn remains a genuine owner turn.

## Safety rules
- Static definitions are immutable during battle.
- Runtime specs own cooldowns and rank patches.
- Passive triggers are once-per-turn/internal-cooldown guarded when authored that way.
- Reaction queue depth and size remain bounded.
- Talent graph rejects cycles and missing prerequisites.
- IDs are semantic and stable; display names may change without save migration.
- Act 0 stays on compatibility behavior until explicitly migrated.
