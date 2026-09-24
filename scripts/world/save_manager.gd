class_name SaveManager
extends Node

const SAVE_PATH := "user://chapter00_save.json"
const TMP_PATH := SAVE_PATH + ".tmp"
const BAK_PATH := SAVE_PATH + ".bak"
const SAVE_VERSION := 2

static func default_state() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"checkpoint": "awakening",
		"route_index": 0,
		"checkpoint_position": [0.0, 0.9, 8.0],
		"cleared_encounters": [],
		"performance_mode": "smooth60",
		"act0_stage": "exterior",
		"covenant_joined": false,
		"weapon_family": "",
		"silver": 0,
		"forged_item": {},
		"first_forge_done": false,
		"story_summon_unlocked": false,
		"catacomb_room": 0,
		"room5_solo_limit_seen": false,
		"room5_rematch_ready": false,
		"act0_complete": false
	}

static func load_state() -> Dictionary:
	var parsed = _read_dictionary(SAVE_PATH)
	if parsed == null:
		parsed = _read_dictionary(BAK_PATH)
	if parsed == null:
		return default_state()
	return _migrate(parsed)

static func _read_dictionary(path:String):
	if not FileAccess.file_exists(path):
		return null
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return null
	return parsed

static func save_state(state: Dictionary) -> bool:
	var normalized := _migrate(state.duplicate(true))
	var file := FileAccess.open(TMP_PATH, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(normalized))
	file.flush()
	file.close()

	var save_abs := ProjectSettings.globalize_path(SAVE_PATH)
	var tmp_abs := ProjectSettings.globalize_path(TMP_PATH)
	var bak_abs := ProjectSettings.globalize_path(BAK_PATH)

	if FileAccess.file_exists(BAK_PATH):
		DirAccess.remove_absolute(bak_abs)

	if FileAccess.file_exists(SAVE_PATH):
		var backup_err := DirAccess.rename_absolute(save_abs, bak_abs)
		if backup_err != OK:
			DirAccess.remove_absolute(tmp_abs)
			return false

	var promote_err := DirAccess.rename_absolute(tmp_abs, save_abs)
	if promote_err != OK:
		if FileAccess.file_exists(BAK_PATH) and not FileAccess.file_exists(SAVE_PATH):
			DirAccess.rename_absolute(bak_abs, save_abs)
		return false

	if FileAccess.file_exists(BAK_PATH):
		DirAccess.remove_absolute(bak_abs)
	return true

static func _migrate(raw: Dictionary) -> Dictionary:
	var state := default_state()
	for key in raw.keys():
		state[key] = raw[key]
	state.version = SAVE_VERSION

	if typeof(state.get("cleared_encounters")) != TYPE_ARRAY:
		state.cleared_encounters = []
	if typeof(state.get("checkpoint_position")) != TYPE_ARRAY or state.checkpoint_position.size() != 3:
		state.checkpoint_position = [0.0,0.9,8.0]

	state.route_index = clampi(int(state.get("route_index",0)),0,Chapter00Director.ROUTE.size()-1)
	state.silver = maxi(0,int(state.get("silver",0)))
	state.catacomb_room = clampi(int(state.get("catacomb_room",0)),0,5)

	var mode:=str(state.get("performance_mode","smooth60"))
	state.performance_mode = mode if mode in ["smooth60","battery30"] else "smooth60"

	var valid_stages:=["exterior","temple_entry","weapon_choice","first_forge","catacombs","room5_return","room5_rematch","act0_complete"]
	if str(state.get("act0_stage","exterior")) not in valid_stages:
		state.act0_stage="exterior"

	var family:=str(state.get("weapon_family",""))
	if not family.is_empty() and not Act0Progression.WEAPONS.has(family):
		state.weapon_family=""
		state.forged_item={}
		state.first_forge_done=false

	if bool(state.get("first_forge_done",false)):
		var item=state.get("forged_item",{})
		if typeof(item)!=TYPE_DICTIONARY or str(item.get("family",""))!=str(state.weapon_family):
			state.first_forge_done=false
			state.forged_item={}
			if bool(state.get("covenant_joined",false)) and not str(state.weapon_family).is_empty():
				state.act0_stage="first_forge"

	# Repair progression dependencies instead of allowing impossible states.
	if not bool(state.get("covenant_joined",false)):
		state.weapon_family=""
		state.forged_item={}
		state.first_forge_done=false
		if str(state.act0_stage) not in ["exterior","temple_entry"]:
			state.act0_stage="temple_entry"

	if bool(state.get("first_forge_done",false)):
		state.covenant_joined=true
		if state.catacomb_room==0:
			state.catacomb_room=1
		if str(state.act0_stage) in ["weapon_choice","first_forge","temple_entry"]:
			state.act0_stage="catacombs"

	if bool(state.get("story_summon_unlocked",false)) or bool(state.get("room5_rematch_ready",false)):
		state.room5_solo_limit_seen=true
		state.story_summon_unlocked=true
		state.room5_rematch_ready=true
		state.catacomb_room=5
		if not bool(state.get("act0_complete",false)):
			state.act0_stage="room5_rematch"
	elif bool(state.get("room5_solo_limit_seen",false)):
		state.catacomb_room=5
		if not bool(state.get("act0_complete",false)):
			state.act0_stage="room5_return"

	if bool(state.get("act0_complete",false)):
		state.room5_solo_limit_seen=true
		state.story_summon_unlocked=true
		state.room5_rematch_ready=true
		state.catacomb_room=5
		state.act0_stage="act0_complete"

	return state

func patch_and_save(patch:Dictionary)->bool:
	var state:=load_state()
	for key in patch:
		state[key]=patch[key]
	return save_state(state)
