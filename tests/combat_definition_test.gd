extends SceneTree

const Catalog = preload("res://scripts/combat/checkpoint01_combat_catalog.gd")
const CombatCommandClass = preload("res://scripts/combat/combat_command.gd")

var failures := 0

func _init() -> void:
	var errors := Catalog.validate()
	_check(errors.is_empty(),"all Checkpoint 01 combat definitions validate: %s" % [errors])

	var slash = Catalog.skill_for(&"shadow",0)
	var lunge = Catalog.skill_for(&"shadow",1)
	var bite = Catalog.skill_for(&"grave_hound",0)
	var rend = Catalog.skill_for(&"grave_hound",1)

	_check(slash != null and slash.skill_id == &"basic_slash","Shadow A1 resolves from Resource catalog")
	_check(lunge != null and lunge.skill_id == &"shadow_lunge","Shadow A2 resolves from Resource catalog")
	_check(bite != null and bite.skill_id == &"hound_bite","Hound Bite resolves from Resource catalog")
	_check(rend != null and rend.skill_id == &"hound_rend","Hound Rend resolves from Resource catalog")
	_check(is_equal_approx(slash.multiplier,1.0) and is_equal_approx(slash.windup_seconds,0.38) and is_equal_approx(slash.recover_seconds,0.48),"A1 prototype balance preserved")
	_check(is_equal_approx(lunge.multiplier,1.72) and lunge.cooldown_opportunities == 3 and lunge.effect_id == &"turn_cut","A2 prototype semantics preserved")
	_check(is_equal_approx(bite.multiplier,1.0) and is_equal_approx(bite.windup_seconds,0.52),"Bite prototype timing preserved")
	_check(Catalog.skill_for(&"unknown",0) == null,"unknown actor has no implicit fallback action")

	var command = CombatCommandClass.new(&"shadow",0,&"manual")
	_check(command.actor_id == &"shadow" and command.skill_index == 0 and command.source == &"manual","CombatCommand preserves input intent without resolving gameplay")

	print("Combat definition tests complete. failures=%d" % failures)
	quit(1 if failures > 0 else 0)

func _check(condition: bool,message: String) -> void:
	if condition:
		print("PASS: "+message)
	else:
		failures += 1
		push_error("FAIL: "+message)
