extends SceneTree

const Save = preload("res://scripts/world/checkpoint01_save.gd")
const GameRootScript = preload("res://scripts/app/game_root.gd")

var failures := 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	_cleanup()
	_test_default_and_reject_invalid()
	_test_atomic_generations_and_backup_recovery()
	_test_tmp_crash_window_recovery()
	_test_invalid_tmp_falls_back_to_backup()
	_test_oversized_primary_falls_back_to_backup()
	_test_checksum_rejects_valid_json_tamper()
	_test_future_schema_rejected()
	await _test_game_root_resume_routes()
	_cleanup()
	print("Checkpoint 01 save tests complete. failures=%d" % failures)
	quit(1 if failures > 0 else 0)

func _test_default_and_reject_invalid() -> void:
	var state := Save.load_state()
	_check(str(state.checkpoint) == "title","no save defaults to title checkpoint")
	_check(int(state.generation) == 0,"default generation is zero")
	_check(not Save.save_checkpoint("mid_windup"),"arbitrary presentation checkpoint is rejected")
	_check(not Save.has_resume_checkpoint(),"title/default is not a resume checkpoint")

func _test_atomic_generations_and_backup_recovery() -> void:
	_cleanup()
	_check(Save.save_checkpoint("awakening"),"first checkpoint save succeeds")
	var a := Save.load_state()
	_check(str(a.checkpoint) == "awakening" and int(a.generation) == 1,"first saved generation loads")

	_check(Save.save_checkpoint("first_battle"),"second checkpoint save succeeds")
	var b := Save.load_state()
	_check(str(b.checkpoint) == "first_battle" and int(b.generation) == 2,"new primary generation loads")

	_write_text(Save.SAVE_PATH,"{truncated")
	var recovered := Save.load_state()
	_check(str(recovered.checkpoint) == "awakening","corrupt newest primary falls back to previous-good backup")
	_check(int(recovered.generation) == 1,"backup recovery preserves previous generation")

func _test_tmp_crash_window_recovery() -> void:
	_cleanup()
	_check(Save.save_checkpoint("awakening"),"tmp recovery fixture primary save succeeds")
	var copy_error := DirAccess.copy_absolute(
		ProjectSettings.globalize_path(Save.SAVE_PATH),
		ProjectSettings.globalize_path(Save.TMP_PATH)
	)
	_check(copy_error == OK,"valid primary can seed interrupted-promotion tmp fixture")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Save.SAVE_PATH))
	var recovered := Save.load_state()
	_check(str(recovered.checkpoint) == "awakening","valid tmp is recovered when primary is absent")
	_check(int(recovered.generation) == 1,"tmp recovery keeps newest committed candidate generation")

func _test_invalid_tmp_falls_back_to_backup() -> void:
	_cleanup()
	_check(Save.save_checkpoint("awakening"),"invalid-tmp fixture generation one succeeds")
	_check(Save.save_checkpoint("first_battle"),"invalid-tmp fixture generation two succeeds")
	# Remove/corrupt primary to enter recovery mode, but make tmp unusable.
	_write_text(Save.SAVE_PATH,"{broken-primary")
	_write_text(Save.TMP_PATH,"{broken-tmp")
	var recovered := Save.load_state()
	_check(str(recovered.checkpoint) == "awakening","invalid tmp never outranks previous-good backup")
	_check(int(recovered.generation) == 1,"invalid tmp fallback retains backup generation")

func _test_oversized_primary_falls_back_to_backup() -> void:
	_cleanup()
	_check(Save.save_checkpoint("awakening"),"oversize fixture generation one succeeds")
	_check(Save.save_checkpoint("first_battle"),"oversize fixture generation two succeeds")
	_write_text(Save.SAVE_PATH,"x".repeat(Save.MAX_SAVE_BYTES+64))
	var recovered := Save.load_state()
	_check(str(recovered.checkpoint) == "awakening","oversized newest primary is rejected before parsing")
	_check(int(recovered.generation) == 1,"oversized primary recovery keeps previous-good backup")

func _test_checksum_rejects_valid_json_tamper() -> void:
	_cleanup()
	_check(Save.save_checkpoint("awakening"),"checksum fixture generation one succeeds")
	_check(Save.save_checkpoint("first_battle"),"checksum fixture generation two succeeds")
	var text := _read_text(Save.SAVE_PATH)
	var envelope = JSON.parse_string(text)
	_check(typeof(envelope) == TYPE_DICTIONARY,"primary envelope parses before tamper")
	if typeof(envelope) != TYPE_DICTIONARY:
		return
	var payload = JSON.parse_string(str(envelope.payload))
	_check(typeof(payload) == TYPE_DICTIONARY,"inner payload parses before tamper")
	if typeof(payload) != TYPE_DICTIONARY:
		return
	payload["checkpoint"] = "awakening"
	# Deliberately keep old checksum so the outer JSON remains syntactically valid
	# but the generation is cryptographically inconsistent.
	envelope["payload"] = JSON.stringify(payload)
	_write_text(Save.SAVE_PATH,JSON.stringify(envelope))
	var recovered := Save.load_state()
	_check(str(recovered.checkpoint) == "awakening" and int(recovered.generation) == 1,"checksum mismatch rejects tampered primary and recovers backup")

func _test_future_schema_rejected() -> void:
	_cleanup()
	_check(Save.save_checkpoint("awakening"),"future-schema fixture generation one succeeds")
	_check(Save.save_checkpoint("first_battle"),"future-schema fixture generation two succeeds")
	var envelope = JSON.parse_string(_read_text(Save.SAVE_PATH))
	if typeof(envelope) != TYPE_DICTIONARY:
		_check(false,"future-schema fixture primary envelope parses")
		return
	var payload = JSON.parse_string(str(envelope.payload))
	if typeof(payload) != TYPE_DICTIONARY:
		_check(false,"future-schema fixture payload parses")
		return
	payload["version"] = Save.SAVE_VERSION+1
	var payload_json := JSON.stringify(payload)
	envelope["payload"] = payload_json
	envelope["sha256"] = payload_json.sha256_text()
	_write_text(Save.SAVE_PATH,JSON.stringify(envelope))
	var recovered := Save.load_state()
	_check(str(recovered.checkpoint) == "awakening","future schema version fails closed to previous-good backup")
	_check(int(recovered.generation) == 1,"future schema cannot silently migrate itself")

func _test_game_root_resume_routes() -> void:
	_cleanup()
	_check(Save.save_checkpoint("awakening"),"awakening route fixture saves")
	var app_awake := GameRootScript.new()
	root.add_child(app_awake)
	await process_frame
	await process_frame
	_check(app_awake.awakening != null,"saved awakening checkpoint resumes AwakeningStage instead of title")
	_check(app_awake.battle == null,"awakening resume does not create battle early")
	app_awake.queue_free()
	await process_frame

	_cleanup()
	_check(Save.save_checkpoint("first_battle"),"battle route fixture saves")
	var app_battle := GameRootScript.new()
	root.add_child(app_battle)
	await process_frame
	await process_frame
	_check(app_battle.battle != null,"saved first_battle checkpoint rebuilds battle from stable start")
	_check(app_battle.awakening == null,"battle resume does not replay awakening")
	if app_battle.battle != null:
		app_battle.battle.running = false
		app_battle.battle.turn_loop_generation += 1
	app_battle.queue_free()
	await process_frame

	_cleanup()
	var app_title := GameRootScript.new()
	root.add_child(app_title)
	await process_frame
	_check(app_title.screen_layer != null,"default title checkpoint still opens title screen")
	_check(app_title.battle == null and app_title.awakening == null,"default title has no hidden gameplay scene")
	app_title.queue_free()
	await process_frame

func _read_text(path: String) -> String:
	var f := FileAccess.open(path,FileAccess.READ)
	if f == null:
		return ""
	var text := f.get_as_text()
	f.close()
	return text

func _write_text(path: String,text: String) -> void:
	var f := FileAccess.open(path,FileAccess.WRITE)
	if f == null:
		failures += 1
		push_error("FAIL: could not write fixture "+path)
		return
	f.store_string(text)
	f.flush()
	f.close()

func _cleanup() -> void:
	for path in [Save.SAVE_PATH,Save.TMP_PATH,Save.BAK_PATH]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func _check(condition: bool,message: String) -> void:
	if condition:
		print("PASS: "+message)
	else:
		failures += 1
		push_error("FAIL: "+message)
