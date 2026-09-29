class_name CombatPresentationProfile
extends Resource

@export var skill_id: StringName = &""
@export var presentation_action_id: StringName = &""
@export var choreography_id: StringName = &""

@export var backstep_distance: float = 0.0
@export var backstep_vertical: float = 0.0
@export var backstep_seconds: float = 0.0
@export var approach_distance: float = 0.0
@export var approach_vertical: float = 0.0
@export var approach_seconds: float = 0.0
@export var prep_delay_seconds: float = 0.0

@export var reaction_distance: float = 0.0
@export var reaction_lift: float = 0.0
@export var reaction_out_seconds: float = 0.0
@export var reaction_return_seconds: float = 0.0

@export var recover_delay_seconds: float = 0.0
@export var recover_seconds: float = 0.0
@export var impact_vfx_family: StringName = &""
@export var camera_profile: StringName = &"none"

func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if skill_id.is_empty():
		errors.append("skill_id is required")
	if presentation_action_id.is_empty():
		errors.append("%s presentation_action_id is required" % skill_id)
	if choreography_id.is_empty():
		errors.append("%s choreography_id is required" % skill_id)
	for value in [backstep_seconds,approach_seconds,prep_delay_seconds,reaction_out_seconds,reaction_return_seconds,recover_delay_seconds,recover_seconds]:
		if value < 0.0:
			errors.append("%s presentation durations must be >= 0" % skill_id)
	return errors
