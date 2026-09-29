extends SceneTree

const Probe = preload("res://scripts/presentation/combat_contact_probe.gd")

var failures := 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var attacker := Node3D.new()
	attacker.name = "Attacker"
	root.add_child(attacker)
	attacker.position = Vector3(-1.0,0.0,0.0)

	var blade_tip := Node3D.new()
	blade_tip.name = "BladeTip"
	blade_tip.position = Vector3(0.8,1.0,0.0)
	attacker.add_child(blade_tip)

	var target := Node3D.new()
	target.name = "Target"
	root.add_child(target)
	target.position = Vector3(1.0,0.0,0.0)

	var impact := Node3D.new()
	impact.name = "CombatImpactTarget"
	impact.position = Vector3(-0.3,1.0,0.0)
	target.add_child(impact)

	await process_frame
	var sample := Probe.sample(attacker,target,&"basic_slash")
	_check(sample["phase"] == "contact","sample identifies contact phase")
	_check(sample["source_kind"] == "marker" and sample["source_name"] == "BladeTip","BladeTip marker is preferred")
	_check(sample["target_kind"] == "marker" and sample["target_name"] == "CombatImpactTarget","explicit target marker is preferred")
	_check(bool(sample["acceptance_markers_ready"]),"explicit source+target markers are acceptance-ready")
	_check(is_equal_approx(float(sample["contact_gap_3d"]),0.9),"contact gap is measured between semantic markers")
	_check(is_equal_approx(float(sample["root_gap_3d"]),2.0),"root gap remains separately observable")

	attacker.position = Vector3(0.17,0.0,0.0)
	var recovery := Probe.recovery_sample(attacker,Vector3.ZERO,"shadow")
	_check(is_equal_approx(float(recovery["recovery_root_error"]),0.17),"recovery error is measured independently from contact")

	attacker.queue_free()
	target.queue_free()
	await process_frame
	print("Combat contact probe tests complete. failures=%d" % failures)
	quit(1 if failures > 0 else 0)

func _check(condition: bool,message: String) -> void:
	if condition:
		print("PASS: "+message)
	else:
		failures += 1
		push_error("FAIL: "+message)
