class_name CombatSkillDefinition
extends Resource

@export var skill_id: StringName = &""
@export var multiplier: float = 1.0
@export_range(0, 99, 1) var cooldown_opportunities: int = 0
@export_range(0.0, 10.0, 0.01) var windup_seconds: float = 0.0
@export_range(0.0, 10.0, 0.01) var recover_seconds: float = 0.0
@export var effect_id: StringName = &""
@export var presentation_action_id: StringName = &""

func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if skill_id.is_empty():
		errors.append("skill_id is required")
	if multiplier <= 0.0:
		errors.append("%s multiplier must be > 0" % skill_id)
	if cooldown_opportunities < 0:
		errors.append("%s cooldown must be >= 0" % skill_id)
	if windup_seconds < 0.0 or recover_seconds < 0.0:
		errors.append("%s phase durations must be >= 0" % skill_id)
	if presentation_action_id.is_empty():
		errors.append("%s presentation_action_id is required" % skill_id)
	return errors
