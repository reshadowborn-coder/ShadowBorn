extends SceneTree

const BattleStageScript = preload("res://scripts/presentation/battle_stage.gd")

var failures := 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1280,720)
	await _measure_exchange("shadow","grave_hound","basic_slash",0.40,0.36)
	await _measure_exchange("grave_hound","shadow","hound_bite",0.55,0.36)
	print("Live contact probe integration complete. failures=%d" % failures)
	quit(1 if failures > 0 else 0)

func _measure_exchange(attacker_id: String,target_id: String,skill_id: String,windup_wait: float,recovery_wait: float) -> void:
	var battle := BattleStageScript.new()
	root.add_child(battle)
	await process_frame
	battle.apply_state({
		"speed":1.0,
		"units":[
			{"id":"shadow","name":"Shadow","hp":100,"max_hp":100},
			{"id":"grave_hound","name":"Grave Hound","hp":80,"max_hp":80}
		]
	})
	await create_timer(0.20).timeout

	battle.play_windup(attacker_id,target_id,skill_id)
	await create_timer(windup_wait).timeout
	battle.play_impact(attacker_id,target_id,skill_id,1,"")
	await process_frame

	var sample: Dictionary = battle.get("last_contact_probe")
	_check(not sample.is_empty(),"%s emits semantic contact sample" % skill_id)
	_check(str(sample.get("phase","")) == "contact","%s sample phase is contact" % skill_id)
	_check(float(sample.get("root_gap_3d",0.0)) > 0.0,"%s reports nonzero root gap" % skill_id)
	_check(bool(sample.get("source_found",false)),"%s resolves a diagnostic source point" % skill_id)
	_check(bool(sample.get("target_found",false)),"%s resolves a diagnostic target region" % skill_id)
	_check(is_finite(float(sample.get("contact_gap_3d",INF))),"%s reports finite diagnostic contact gap" % skill_id)
	print("LIVE_CONTACT %s root_gap_3d=%.4f contact_gap_3d=%.4f screen_gap_px=%s source=%s/%s target=%s/%s acceptance_markers=%s" % [
		skill_id,
		float(sample.get("root_gap_3d",INF)),
		float(sample.get("contact_gap_3d",INF)),
		str(sample.get("screen_gap_px",INF)),
		str(sample.get("source_kind","missing")),
		str(sample.get("source_name","")),
		str(sample.get("target_kind","missing")),
		str(sample.get("target_name","")),
		str(sample.get("acceptance_markers_ready",false))
	])

	await create_timer(recovery_wait).timeout
	var recovery: Dictionary = battle.get("last_recovery_probe")
	_check(not recovery.is_empty(),"%s emits recovery sample" % skill_id)
	_check(float(recovery.get("recovery_root_error",INF)) < 0.002,"%s returns to home without accumulated root drift" % skill_id)
	print("LIVE_RECOVERY %s recovery_root_error=%.6f" % [skill_id,float(recovery.get("recovery_root_error",INF))])

	battle.queue_free()
	await process_frame

func _check(condition: bool,message: String) -> void:
	if condition:
		print("PASS: "+message)
	else:
		failures += 1
		push_error("FAIL: "+message)
