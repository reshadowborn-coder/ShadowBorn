class_name SaveManager
extends Node

const SAVE_PATH := "user://chapter00_save.json"
const SAVE_VERSION := 1

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
	if not FileAccess.file_exists(SAVE_PATH):
		return default_state()
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return default_state()
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return default_state()
	return _migrate(parsed)

static func save_state(state: Dictionary) -> bool:
	var normalized := _migrate(state.duplicate(true))
	var tmp_path := SAVE_PATH + ".tmp"
	var file := FileAccess.open(tmp_path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(normalized))
	file.flush()
	file.close()
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	var err := DirAccess.rename_absolute(ProjectSettings.globalize_path(tmp_path), ProjectSettings.globalize_path(SAVE_PATH))
	return err == OK

static func _migrate(raw: Dictionary) -> Dictionary:
	var state := default_state()
	for key in raw.keys(): state[key] = raw[key]
	state.version = SAVE_VERSION
	if typeof(state.get("cleared_encounters")) != TYPE_ARRAY: state.cleared_encounters = []
	if typeof(state.get("checkpoint_position")) != TYPE_ARRAY or state.checkpoint_position.size() != 3:
		state.checkpoint_position = [0.0,0.9,8.0]
	state.route_index = clampi(int(state.get("route_index",0)),0,Chapter00Director.ROUTE.size()-1)
	return state


func patch_and_save(patch:Dictionary)->bool:
	var state:=load_state()
	for key in patch:
		state[key]=patch[key]
	return save_state(state)
