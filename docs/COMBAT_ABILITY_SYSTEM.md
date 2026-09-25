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


## Status application pipeline
Hostile status placement is explicitly two-stage:
1. the authored effect chance succeeds,
2. the target may resist based on source Accuracy versus target Resistance.

Shadowborn intentionally has no hidden mandatory 3% failure floor. The current provisional curve uses 15% resistance at equal ACC/RES and 0.25 percentage points per stat difference, clamped from 0% to 95%. These constants are balance data and can be retuned without changing call sites.

A sufficiently accurate build can therefore guarantee an ordinary debuff unless the target has an explicit immunity/block rule. Boss protection should be readable through immunity tags, Stagger/Resolve, encounter rules or control diminishing returns rather than invisible dice.

Unresistable effects must be explicitly authored. Immunity/blocking is resolved before chance/resistance.

A multi-hit skill should call status placement once per authored effect/target unless the skill explicitly declares per-hit application. This avoids accidental multiplication of proc chance.

## Deterministic combat RNG
CombatDeterministicRng provides a small platform-stable integer roll stream with snapshot/restore. Random decisions should use this stream rather than ad-hoc randf() calls inside hero scripts.

This supports deterministic tests, future combat replays and exact reproduction of a reported battle.

## Auras
Aura is a dedicated kit slot, not a passive disguised as an active skill.

Only one team aura is active through CombatAuraRuntime. An aura declares:
- team-wide stat modifiers,
- required battle-mode tags,
- blocked battle-rule tags,
- whether it persists after its owner dies.

The Aura unlock milestone remains content/progression data; the runtime does not hard-code a level.

## Talent compilation
Talents do not mutate static skill definitions. CombatBuildCompiler builds battle-local CombatSkillSpecs, aggregates talent stat modifiers, applies whitelisted skill patches and exposes any granted passive IDs.

This keeps respecs and balance changes safe: static content remains immutable while the battle receives a compiled build.


## Event routing and proc commit
Passive eligibility and passive activation are separate phases.

The runtime first produces eligible candidates. The CombatEventRouter then:
1. rolls the passive proc chance from deterministic combat RNG,
2. applies chain-depth and queue guards,
3. queues the Reaction,
4. only then commits once-per-turn/once-per-battle/internal-cooldown state.

A failed chance roll therefore does not silently consume the passive.

Each natural turn window has a hard event-processing budget and the Reaction Queue has independent size/depth caps. These guards are intentionally redundant so a future combination of passives, gear and talents cannot create an infinite event loop.


## Effect-step vocabulary
Skills and passives may not invent arbitrary operation names. CombatAbilityOps validates a deliberately bounded vocabulary for damage, healing, statuses, cleanse/dispel, Turn Meter, speed, cooldowns, Extra Turns, resources and semantic tags.

Each operation has structural safety checks. For example, an Extra Turn step cannot request more turns than the global timeline cap, status chance cannot exceed 100%, and Turn Meter/speed modifiers have hard data bounds.

New mechanics should extend this shared vocabulary only when they represent a reusable game rule. One hero should not receive a bespoke hidden executor branch merely because its description is unusual.


## Action transactions and reaction origin
Every semantic hit/effect event may carry a transaction_id representing the originating skill use. Multi-hit attacks keep the same transaction ID across all hits.

Passives can therefore use once_per_action independently from once_per_turn. This prevents a three-hit skill from activating a passive three times when the design says "after this skill hits".

Events also carry semantic origin tags for Natural Turn, Extra Turn and Reaction. Reaction-origin events are blocked from triggering ordinary passives by default. A passive must explicitly opt into allow_reaction_trigger to react to a counter, assist or follow-up.

This default is intentionally conservative: turns may create reactions, but reactions do not recursively create new reaction trees unless content explicitly asks for it and still passes the global chain and event budgets.

Status application steps default to one proc roll per action and target. Per-hit rolling must be explicitly authored with roll_scope=per_hit.
