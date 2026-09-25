extends SceneTree

const Rules = preload("res://scripts/combat/battle_rules.gd")

func _init() -> void:
	var failures := 0
	failures += _expect(Rules.compute_damage(30.0,1.0,10.0) == 27,"damage baseline")
	failures += _expect(Rules.compute_damage(1.0,0.1,999.0) == 1,"minimum damage")
	var unit := {"hp":100,"max_hp":100,"statuses":{"poison":2}}
	var poison := Rules.poison_tick(unit)
	failures += _expect(poison == 6,"poison is six percent max HP")
	failures += _expect(int(unit["hp"]) == 94,"poison applies damage")
	failures += _expect(int(unit["statuses"]["poison"]) == 1,"poison duration decreases")
	var statuses := {"stun":1,"freeze":0,"sleep":0}
	failures += _expect(not Rules.can_take_turn(statuses),"control status blocks turn")
	failures += _expect(Rules.consume_control(statuses) == "stun","control status is consumed")
	failures += _expect(Rules.can_take_turn(statuses),"actor can act after status expires")
	if failures == 0:
		print("Shadowborn combat rules: PASS")
		quit(0)
	else:
		push_error("Shadowborn combat rules: %d failure(s)" % failures)
		quit(1)

func _expect(condition: bool,label: String) -> int:
	if condition:
		print("PASS: "+label)
		return 0
	push_error("FAIL: "+label)
	return 1
