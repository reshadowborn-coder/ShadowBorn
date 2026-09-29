class_name CombatResolver
extends RefCounted

const ResultClass = preload("res://scripts/combat/combat_action_result.gd")

static func resolve(attacker: Dictionary,target: Dictionary,skill_index: int,skill: CombatSkillDefinition) -> CombatActionResult:
	var result := ResultClass.new()
	result.attacker_id = StringName(str(attacker.get("id","")))
	result.target_id = StringName(str(target.get("id","")))
	result.skill_id = skill.skill_id
	result.skill_index = skill_index

	result.target_hp_before = maxi(0,int(target.get("hp",0)))
	result.raw_damage = BattleRules.compute_damage(
		float(attacker.get("power",0.0)),
		skill.multiplier,
		float(target.get("defense",0.0))
	)
	result.damage_applied = mini(maxi(result.raw_damage,0),result.target_hp_before)
	result.target_hp_after = maxi(0,result.target_hp_before-result.damage_applied)

	result.attacker_cooldowns_before = (attacker.get("cooldowns",[]) as Array).duplicate()
	result.attacker_cooldowns_after = BattleRules.resolve_action_cooldowns(
		result.attacker_cooldowns_before,
		skill_index,
		skill.cooldown_opportunities
	)

	if skill.effect_id == &"turn_cut" and result.target_hp_after > 0:
		result.target_gauge_delta_bp = -3000
		result.effect_text = "TURN METER -30"

	return result
