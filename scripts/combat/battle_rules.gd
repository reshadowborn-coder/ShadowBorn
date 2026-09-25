class_name BattleRules
extends RefCounted

const CONTROL_STATUSES := ["stun", "freeze", "sleep"]

static func can_take_turn(statuses: Dictionary) -> bool:
	for key in CONTROL_STATUSES:
		if int(statuses.get(key, 0)) > 0:
			return false
	return true

static func consume_control(statuses: Dictionary) -> String:
	for key in CONTROL_STATUSES:
		var turns := int(statuses.get(key, 0))
		if turns > 0:
			statuses[key] = max(0, turns - 1)
			return key
	return ""

static func compute_damage(power: float, multiplier: float, defense: float) -> int:
	return maxi(1, int(round(power * multiplier - defense * 0.32)))

static func apply_damage(unit: Dictionary, damage: int) -> int:
	var actual := mini(maxi(damage, 0), int(unit.get("hp", 0)))
	unit["hp"] = maxi(0, int(unit.get("hp", 0)) - actual)
	return actual

static func poison_tick(unit: Dictionary) -> int:
	var statuses: Dictionary = unit.get("statuses", {})
	var turns := int(statuses.get("poison", 0))
	if turns <= 0 or int(unit.get("hp", 0)) <= 0:
		return 0
	var damage := maxi(1, int(round(float(unit.get("max_hp", 1)) * 0.06)))
	apply_damage(unit, damage)
	statuses["poison"] = max(0, turns - 1)
	unit["statuses"] = statuses
	return damage

static func choose_first_alive(units: Array, team: String) -> int:
	for i in range(units.size()):
		var unit: Dictionary = units[i]
		if str(unit.get("team", "")) == team and int(unit.get("hp", 0)) > 0:
			return i
	return -1

static func living_count(units: Array, team: String) -> int:
	var count := 0
	for unit_variant in units:
		var unit: Dictionary = unit_variant
		if str(unit.get("team", "")) == team and int(unit.get("hp", 0)) > 0:
			count += 1
	return count
