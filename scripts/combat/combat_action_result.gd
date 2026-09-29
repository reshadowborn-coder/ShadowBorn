class_name CombatActionResult
extends RefCounted

var attacker_id: StringName
var target_id: StringName
var skill_id: StringName
var skill_index: int

var raw_damage: int
var damage_applied: int
var target_hp_before: int
var target_hp_after: int

var attacker_cooldowns_before: Array
var attacker_cooldowns_after: Array

var target_gauge_delta_bp: int = 0
var effect_text: String = ""

func target_died() -> bool:
	return target_hp_before > 0 and target_hp_after <= 0
