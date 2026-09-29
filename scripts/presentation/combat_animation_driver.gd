class_name CombatAnimationDriver
extends RefCounted

const Factory = preload("res://scripts/presentation/character_factory.gd")

var model: Node3D
var actor_kind: StringName
var logical_state: StringName = &"uninitialized"
var active_action_id: StringName = &""

func _init(p_model: Node3D,p_actor_kind: StringName) -> void:
	model = p_model
	actor_kind = p_actor_kind

func play_idle(speed: float = 1.0) -> bool:
	logical_state = &"idle"
	active_action_id = &""
	if actor_kind == &"shadow":
		return Factory.play_shadow_idle(model,speed)
	if actor_kind == &"hound":
		return Factory.play_hound_idle(model,speed)
	return false

func play_action_start(profile: CombatPresentationProfile,speed: float = 1.0) -> bool:
	active_action_id = profile.presentation_action_id
	logical_state = &"action_windup"
	match profile.choreography_id:
		&"shadow_basic":
			return Factory.play_shadow_basic(model,speed)
		&"shadow_heavy":
			return Factory.play_shadow_heavy_prep(model,speed)
		&"hound_bite":
			return Factory.play_hound_attack(model,speed)
		_:
			return false

func play_action_commit(profile: CombatPresentationProfile,speed: float = 1.0) -> bool:
	active_action_id = profile.presentation_action_id
	logical_state = &"action_commit"
	if profile.choreography_id == &"shadow_heavy":
		return Factory.play_shadow_heavy_strike(model,speed)
	return false

func play_hit(speed: float = 1.0) -> bool:
	logical_state = &"hit"
	if actor_kind == &"shadow":
		return Factory.play_shadow_hit(model,speed)
	if actor_kind == &"hound":
		return Factory.play_hound_hit(model,speed)
	return false

func play_death(speed: float = 1.0) -> bool:
	logical_state = &"death"
	active_action_id = &""
	return Factory.play_death(model,speed)
