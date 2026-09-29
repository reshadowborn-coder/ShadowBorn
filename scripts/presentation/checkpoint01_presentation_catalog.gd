class_name Checkpoint01PresentationCatalog
extends RefCounted

const BASIC_SLASH: CombatPresentationProfile = preload("res://assets/presentation/checkpoint01/basic_slash.tres")
const SHADOW_LUNGE: CombatPresentationProfile = preload("res://assets/presentation/checkpoint01/shadow_lunge.tres")
const HOUND_BITE: CombatPresentationProfile = preload("res://assets/presentation/checkpoint01/hound_bite.tres")
const HOUND_REND: CombatPresentationProfile = preload("res://assets/presentation/checkpoint01/hound_rend.tres")

static func profile_for(skill_id: StringName) -> CombatPresentationProfile:
	match skill_id:
		&"basic_slash":
			return BASIC_SLASH
		&"shadow_lunge":
			return SHADOW_LUNGE
		&"hound_bite":
			return HOUND_BITE
		&"hound_rend":
			return HOUND_REND
		_:
			return null

static func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	for profile in [BASIC_SLASH,SHADOW_LUNGE,HOUND_BITE,HOUND_REND]:
		errors.append_array(profile.validate())
	return errors
