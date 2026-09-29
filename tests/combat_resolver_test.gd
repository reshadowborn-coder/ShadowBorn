extends SceneTree

const Catalog = preload("res://scripts/combat/checkpoint01_combat_catalog.gd")
const Resolver = preload("res://scripts/combat/combat_resolver.gd")

var failures := 0

func _init() -> void:
	_test_a1_without_mutation()
	_test_a2_turn_cut_and_cooldown()
	_test_lethal_hit_does_not_turn_cut()
	print("Combat resolver tests complete. failures=%d" % failures)
	quit(1 if failures > 0 else 0)

func _test_a1_without_mutation() -> void:
	var attacker := {"id":"shadow","power":31.0,"cooldowns":[0,0]}
	var target := {"id":"grave_hound","hp":118,"defense":8.0}
	var result = Resolver.resolve(attacker,target,0,Catalog.BASIC_SLASH)

	_check(result.damage_applied == 28,"A1 damage remains 28")
	_check(result.target_hp_after == 90,"A1 computes target HP after hit")
	_check(int(target["hp"]) == 118,"resolver does not mutate target")
	_check((attacker["cooldowns"] as Array) == [0,0],"resolver does not mutate attacker cooldowns")
	_check(result.target_gauge_delta_bp == 0,"A1 has no meter effect")

func _test_a2_turn_cut_and_cooldown() -> void:
	var attacker := {"id":"shadow","power":31.0,"cooldowns":[0,0]}
	var target := {"id":"grave_hound","hp":118,"defense":8.0}
	var result = Resolver.resolve(attacker,target,1,Catalog.SHADOW_LUNGE)

	_check(result.damage_applied == 51,"A2 damage remains 51")
	_check(result.target_hp_after == 67,"A2 computes target HP after hit")
	_check(result.attacker_cooldowns_after == [0,3],"A2 commits CD3 in result")
	_check(result.target_gauge_delta_bp == -3000,"A2 requests -30 turn meter")
	_check(result.effect_text == "TURN METER -30","A2 presentation text preserved")

func _test_lethal_hit_does_not_turn_cut() -> void:
	var attacker := {"id":"shadow","power":31.0,"cooldowns":[0,0]}
	var target := {"id":"grave_hound","hp":20,"defense":8.0}
	var result = Resolver.resolve(attacker,target,1,Catalog.SHADOW_LUNGE)

	_check(result.damage_applied == 20,"lethal damage clamps to remaining HP")
	_check(result.target_hp_after == 0 and result.target_died(),"lethal result marks death")
	_check(result.target_gauge_delta_bp == 0,"turn cut is not applied to dead target")
	_check(result.effect_text.is_empty(),"dead target has no turn-cut presentation text")

func _check(condition: bool,message: String) -> void:
	if condition:
		print("PASS: "+message)
	else:
		failures += 1
		push_error("FAIL: "+message)
