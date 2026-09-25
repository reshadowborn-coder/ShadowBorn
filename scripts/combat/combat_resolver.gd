class_name CombatResolver
extends RefCounted

const MAX_SAFE_DAMAGE:=1000000.0

static func _finite(value:float)->bool:
	return value==value and not is_inf(value)

static func damage(atk: float, coeff: float, defense: float, state_mult: float = 1.0) -> float:
	if not _finite(atk) or not _finite(coeff) or not _finite(defense) or not _finite(state_mult):
		return 0.0
	if atk<0.0 or coeff<0.0 or state_mult<0.0:
		return 0.0
	var result:=atk*coeff*(100.0/(100.0+maxf(defense,0.0)))*state_mult
	if result!=result:
		return 0.0
	if is_inf(result):
		return MAX_SAFE_DAMAGE
	return clampf(result,0.0,MAX_SAFE_DAMAGE)

static func resolve_a1(attacker: Dictionary, defender: Dictionary) -> Dictionary:
	var dmg := damage(attacker.atk, 1.0, defender.def)
	return {"damage": dmg, "apply_fray": true}

static func resolve_a2(attacker: Dictionary, defender: Dictionary) -> Dictionary:
	var mult := 1.0
	if defender.get("guard", false): mult = 0.55
	var dmg := damage(attacker.atk, 1.30, defender.def, mult)
	return {"damage": dmg, "veil": 0.15, "cooldown": 3}
