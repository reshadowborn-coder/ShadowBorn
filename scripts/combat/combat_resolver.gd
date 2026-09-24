class_name CombatResolver
extends RefCounted

static func damage(atk: float, coeff: float, defense: float, state_mult: float = 1.0) -> float:
	return atk * coeff * (100.0 / (100.0 + maxf(defense, 0.0))) * state_mult

static func resolve_a1(attacker: Dictionary, defender: Dictionary) -> Dictionary:
	var dmg := damage(attacker.atk, 1.0, defender.def)
	return {"damage": dmg, "apply_fray": true}

static func resolve_a2(attacker: Dictionary, defender: Dictionary) -> Dictionary:
	var mult := 1.0
	if defender.get("guard", false): mult = 0.55
	var dmg := damage(attacker.atk, 1.30, defender.def, mult)
	return {"damage": dmg, "veil": 0.15, "cooldown": 3}
