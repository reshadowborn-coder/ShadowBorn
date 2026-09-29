class_name Checkpoint01CombatCatalog
extends RefCounted

const BASIC_SLASH: CombatSkillDefinition = preload("res://assets/combat/checkpoint01/basic_slash.tres")
const SHADOW_LUNGE: CombatSkillDefinition = preload("res://assets/combat/checkpoint01/shadow_lunge.tres")
const HOUND_BITE: CombatSkillDefinition = preload("res://assets/combat/checkpoint01/hound_bite.tres")
const HOUND_REND: CombatSkillDefinition = preload("res://assets/combat/checkpoint01/hound_rend.tres")

static func skill_for(actor_id: StringName, skill_index: int) -> CombatSkillDefinition:
	match actor_id:
		&"shadow":
			return SHADOW_LUNGE if skill_index == 1 else BASIC_SLASH
		&"grave_hound":
			return HOUND_REND if skill_index == 1 else HOUND_BITE
		_:
			return null

static func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	for skill in [BASIC_SLASH, SHADOW_LUNGE, HOUND_BITE, HOUND_REND]:
		errors.append_array(skill.validate())
	return errors
