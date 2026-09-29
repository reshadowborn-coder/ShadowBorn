extends SceneTree

const Driver = preload("res://scripts/presentation/combat_animation_driver.gd")
const Profiles = preload("res://scripts/presentation/checkpoint01_presentation_catalog.gd")

var failures := 0

func _init() -> void:
	var shadow_model := Node3D.new()
	var shadow = Driver.new(shadow_model,&"shadow")
	_check(not shadow.play_idle(),"driver tolerates missing preview AnimationPlayer")
	_check(shadow.logical_state == &"idle","Shadow driver owns idle logical state")
	shadow.play_action_start(Profiles.BASIC_SLASH)
	_check(shadow.logical_state == &"action_windup","Shadow A1 enters action_windup")
	_check(shadow.active_action_id == &"SHD_A1_SWORD_01","Shadow driver tracks semantic presentation action ID")
	shadow.play_hit()
	_check(shadow.logical_state == &"hit","Shadow driver owns hit state")
	shadow.play_death()
	_check(shadow.logical_state == &"death","Shadow driver owns death state")

	var hound_model := Node3D.new()
	var hound = Driver.new(hound_model,&"hound")
	hound.play_action_start(Profiles.HOUND_BITE)
	_check(hound.logical_state == &"action_windup","Hound Bite enters action_windup")
	_check(hound.active_action_id == &"HND_BITE_01","Hound driver tracks Bite action ID")
	hound.play_idle()
	_check(hound.logical_state == &"idle" and hound.active_action_id.is_empty(),"idle clears active action")

	shadow_model.free()
	hound_model.free()
	print("Combat animation driver tests complete. failures=%d" % failures)
	quit(1 if failures > 0 else 0)

func _check(condition: bool,message: String) -> void:
	if condition:
		print("PASS: "+message)
	else:
		failures += 1
		push_error("FAIL: "+message)
