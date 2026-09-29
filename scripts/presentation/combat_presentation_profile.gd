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
@export var adaptive_contact_staging: bool = false
@export var desired_contact_gap: float = 0.12
@export var max_approach_distance: float = 0.0
@export var prep_delay_seconds: float = 0.0

@export var reaction_distance: float = 0.0
@export var reaction_lift: float = 0.0
@export var reaction_out_seconds: float = 0.0
@export var reaction_return_seconds: float = 0.0

@export var recover_delay_seconds: float = 0.0
@export var recover_seconds: float = 0.0
@export var impact_vfx_family: StringName = &""
@export var camera_profile: StringName = &"none"
@export var camera_offset: Vector3 = Vector3.ZERO
@export var camera_fov: float = 0.0
@export var camera_in_seconds: float = 0.0
@export var camera_out_seconds: float = 0.0

func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if skill_id.is_empty():
		errors.append("skill_id is required")
	if presentation_action_id.is_empty():
		errors.append("%s presentation_action_id is required" % skill_id)
	if choreography_id.is_empty():
		errors.append("%s choreography_id is required" % skill_id)
	if desired_contact_gap < 0.0:
		errors.append("%s desired_contact_gap must be >= 0" % skill_id)
	if max_approach_distance < 0.0:
		errors.append("%s max_approach_distance must be >= 0" % skill_id)
	if adaptive_contact_staging and max_approach_distance < approach_distance:
		errors.append("%s adaptive staging max must be >= base approach" % skill_id)
	for value in [backstep_seconds,approach_seconds,prep_delay_seconds,reaction_out_seconds,reaction_return_seconds,recover_delay_seconds,recover_seconds,camera_in_seconds,camera_out_seconds]:
		if value < 0.0:
			errors.append("%s presentation durations must be >= 0" % skill_id)
	return errors
