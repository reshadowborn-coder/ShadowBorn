extends SceneTree

var failures:=0

func _init()->void:
	call_deferred("_run")

func _check(condition:bool,message:String)->void:
	if not condition:
		failures+=1
		push_error("FAIL: "+message)

func _remove(path:String)->void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func _cleanup()->void:
	_remove(SaveManager.SAVE_PATH)
	_remove(SaveManager.TMP_PATH)
	_remove(SaveManager.BAK_PATH)

func _run()->void:
	_cleanup()

	var first:=SaveManager.default_state()
	first.shadow_identity="male"
	first.reduced_motion=false
	_check(SaveManager.save_state(first),"first save generation commits")

	var second:=first.duplicate(true)
	second.reduced_motion=true
	_check(SaveManager.save_state(second),"second save generation commits")
	_check(FileAccess.file_exists(SaveManager.SAVE_PATH),"primary save exists after promotion")
	_check(FileAccess.file_exists(SaveManager.BAK_PATH),"previous valid generation is retained as backup")

	var primary:=SaveManager.load_state()
	_check(bool(primary.reduced_motion),"primary save is preferred while valid")

	var corrupt:=FileAccess.open(SaveManager.SAVE_PATH,FileAccess.WRITE)
	_check(corrupt!=null,"test can open primary save for corruption fixture")
	if corrupt:
		corrupt.store_string("{corrupt-json")
		corrupt.close()

	var recovered:=SaveManager.load_state()
	_check(not bool(recovered.reduced_motion),"corrupt primary falls back to previous valid generation")
	_check(str(recovered.shadow_identity)=="male","backup recovery preserves gameplay identity")

	# A syntactically valid but unreasonably large primary must be rejected
	# before JSON parsing can allocate around attacker/corruption-controlled data.
	var oversized:=FileAccess.open(SaveManager.SAVE_PATH,FileAccess.WRITE)
	_check(oversized!=null,"test can open primary for oversized save fixture")
	if oversized:
		oversized.store_string("{\"junk\":\""+("x".repeat(SaveManager.MAX_SAVE_BYTES+64))+"\"}")
		oversized.close()
	var recovered_oversized:=SaveManager.load_state()
	_check(str(recovered_oversized.shadow_identity)=="male","oversized primary falls back to bounded valid backup")

	_cleanup()
	var replaced:=SaveManager.default_state()
	replaced.shadow_identity="male"
	replaced.reduced_motion=true
	_check(SaveManager.save_state(replaced),"replacement fixture creates an old game")
	_check(SaveManager.create_new_game("female"),"New Game replaces and reseeds both save generations")
	var corrupt_new:=FileAccess.open(SaveManager.SAVE_PATH,FileAccess.WRITE)
	if corrupt_new:
		corrupt_new.store_string("{broken-new-game")
		corrupt_new.close()
	var recovered_new:=SaveManager.load_state()
	_check(str(recovered_new.shadow_identity)=="female","New Game backup cannot resurrect the replaced identity")
	_check(not bool(recovered_new.reduced_motion) and str(recovered_new.act0_stage)==Act0Contract.STAGE_EXTERIOR,"New Game backup contains the fresh default progression")

	_cleanup()

	# Simulate iOS terminating the process in the only atomic rename window:
	# newest tmp is fully flushed, primary has moved to backup, promotion has
	# not happened yet. Continue must recover the newest tmp generation.
	var crash_base:=SaveManager.default_state()
	crash_base.shadow_identity="male"
	crash_base.reduced_motion=false
	_check(SaveManager.save_state(crash_base),"crash-window fixture creates primary")
	var crash_newer:=crash_base.duplicate(true)
	crash_newer.reduced_motion=true
	var crash_tmp:=FileAccess.open(SaveManager.TMP_PATH,FileAccess.WRITE)
	_check(crash_tmp!=null,"crash-window fixture can create flushed tmp")
	if crash_tmp:
		crash_tmp.store_string(JSON.stringify(SaveManager._migrate(crash_newer)))
		crash_tmp.flush()
		crash_tmp.close()
	var crash_rename:=DirAccess.rename_absolute(
		ProjectSettings.globalize_path(SaveManager.SAVE_PATH),
		ProjectSettings.globalize_path(SaveManager.BAK_PATH)
	)
	_check(crash_rename==OK,"crash-window fixture moves primary to backup")
	_check(not FileAccess.file_exists(SaveManager.SAVE_PATH) and FileAccess.file_exists(SaveManager.TMP_PATH),"crash-window fixture matches interrupted atomic promotion")
	_check(SaveManager.has_save(),"Continue remains available during interrupted promotion recovery")
	var crash_recovered:=SaveManager.load_state()
	_check(bool(crash_recovered.reduced_motion),"interrupted promotion recovers newest flushed tmp instead of older backup")

	# An invalid tmp must never outrank a valid backup.
	var broken_tmp:=FileAccess.open(SaveManager.TMP_PATH,FileAccess.WRITE)
	if broken_tmp:
		broken_tmp.store_string("{broken-tmp")
		broken_tmp.close()
	var crash_fallback:=SaveManager.load_state()
	_check(not bool(crash_fallback.reduced_motion),"invalid interrupted tmp falls back to previous valid backup")
	_cleanup()

	var canonical:=SaveManager.default_state()
	canonical.shadow_identity="male"
	canonical["unknown_future_blob"]="x".repeat(1024)
	_check(SaveManager.save_state(canonical),"canonical save strips unknown top-level fields before promotion")
	var canonical_loaded:=SaveManager.load_state()
	_check(not canonical_loaded.has("unknown_future_blob"),"unknown top-level save fields cannot accumulate across iPhone saves")
	_cleanup()

	print("Save manager IO recovery tests complete. failures=%d"%failures)
	quit(1 if failures>0 else 0)
