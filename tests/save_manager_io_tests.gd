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
	print("Save manager IO recovery tests complete. failures=%d"%failures)
	quit(1 if failures>0 else 0)
