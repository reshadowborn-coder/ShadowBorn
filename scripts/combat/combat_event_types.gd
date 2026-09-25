class_name CombatEventTypes
extends RefCounted

const BATTLE_START:=&"Battle.Start"
const TURN_START:=&"Turn.Start"
const TURN_SKIPPED:=&"Turn.Skipped"
const ACTION_COMMITTED:=&"Action.Committed"
const BEFORE_HIT:=&"Hit.Before"
const AFTER_HIT:=&"Hit.After"
const ACTIVE_DAMAGE_TAKEN:=&"Damage.Active.Taken"
const PERIODIC_DAMAGE_TAKEN:=&"Damage.Periodic.Taken"
const CRITICAL_HIT:=&"Hit.Critical"
const KILL:=&"Actor.Kill"
const DEATH:=&"Actor.Death"
const EFFECT_APPLIED:=&"Effect.Applied"
const EFFECT_REMOVED:=&"Effect.Removed"
const TURN_END:=&"Turn.End"

static func all()->Array[StringName]:
	return [
		BATTLE_START,
		TURN_START,
		TURN_SKIPPED,
		ACTION_COMMITTED,
		BEFORE_HIT,
		AFTER_HIT,
		ACTIVE_DAMAGE_TAKEN,
		PERIODIC_DAMAGE_TAKEN,
		CRITICAL_HIT,
		KILL,
		DEATH,
		EFFECT_APPLIED,
		EFFECT_REMOVED,
		TURN_END
	]
