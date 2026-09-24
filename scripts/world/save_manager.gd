class_name SaveManager
extends Node

const SAVE_PATH := "user://chapter00_save.json"
const TMP_PATH := SAVE_PATH + ".tmp"
const BAK_PATH := SAVE_PATH + ".bak"
const SAVE_VERSION := 3

static func default_state() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"checkpoint": "awakening",
		"route_index": 0,
		"checkpoint_position": [0.0, 0.9, 8.0],
		"cleared_encounters": [],
		"performance_mode": "smooth60",
		"shadow_identity": "",
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
	else:
		var clean:Array=[]
		var seen:Dictionary={}
		for value in state.cleared_encounters:
			var id:=str(value)
			if id.is_empty() or seen.has(id):
				continue
			seen[id]=true
			clean.append(id)
		state.cleared_encounters=clean

	if typeof(state.get("checkpoint_position")) != TYPE_ARRAY or state.checkpoint_position.size() != 3:
		state.checkpoint_position = [0.0,0.9,8.0]

	state.route_index = clampi(int(state.get("route_index",0)),0,Chapter00Director.ROUTE.size()-1)
	state.silver = maxi(0,int(state.get("silver",0)))
	state.catacomb_room = clampi(int(state.get("catacomb_room",0)),0,5)

	var mode:=str(state.get("performance_mode","smooth60"))
	state.performance_mode = mode if mode in ["smooth60","battery30"] else "smooth60"
	var identity:=str(state.get("shadow_identity",""))
	state.shadow_identity = identity if identity in ["","male","female"] else ""

	var valid_stages:=["exterior","temple_entry","weapon_choice","first_forge","catacombs","room5_return","room5_rematch","act0_complete"]
	var stage:=str(state.get("act0_stage","exterior"))
	state.act0_stage = stage if stage in valid_stages else "exterior"

	var family:=str(state.get("weapon_family",""))
	if not family.is_empty() and not Act0Progression.WEAPONS.has(family):
		family=""
	state.weapon_family=family

	var covenant:=bool(state.get("covenant_joined",false))
	var forged:=bool(state.get("first_forge_done",false))
	var solo_seen:=bool(state.get("room5_solo_limit_seen",false))
	var summon:=bool(state.get("story_summon_unlocked",false))
	var rematch:=bool(state.get("room5_rematch_ready",false))
	var complete:=bool(state.get("act0_complete",false))

	# Later progress proves the Shield route was already cleared. Repair the
	# reward ledger instead of allowing the boss/Silver transition to replay.
	var later_progress:=covenant or not family.is_empty() or forged or state.catacomb_room>0 or solo_seen or summon or rematch or complete or str(state.act0_stage) not in ["exterior","temple_entry"]
	if later_progress and "shield_boss" not in state.cleared_encounters:
		state.cleared_encounters.append("shield_boss")
	var shield_cleared:="shield_boss" in state.cleared_encounters
	if shield_cleared:
		state.route_index=maxi(state.route_index,Chapter00Director.ROUTE.size()-1)

	# Validate a committed forge before trusting downstream Catacomb state.
	if forged:
		var item=state.get("forged_item",{})
		if family.is_empty() or typeof(item)!=TYPE_DICTIONARY or str(item.get("family",""))!=family or not bool(item.get("equipped",false)):
			forged=false
			state.first_forge_done=false
			state.forged_item={}
			state.silver=maxi(1,state.silver)

	if not covenant:
		state.weapon_family=""
		state.forged_item={}
		state.first_forge_done=false
		state.catacomb_room=0
		state.room5_solo_limit_seen=false
		state.story_summon_unlocked=false
		state.room5_rematch_ready=false
		state.act0_complete=false
		state.act0_stage="temple_entry" if shield_cleared else "exterior"
		if shield_cleared:
			state.silver=maxi(1,state.silver)
		return state

	state.covenant_joined=true

	if family.is_empty():
		state.forged_item={}
		state.first_forge_done=false
		state.catacomb_room=0
		state.room5_solo_limit_seen=false
		state.story_summon_unlocked=false
		state.room5_rematch_ready=false
		state.act0_complete=false
		state.act0_stage="weapon_choice"
		if shield_cleared:
			state.silver=maxi(1,state.silver)
		return state

	if not forged:
		state.first_forge_done=false
		state.forged_item={}
		state.catacomb_room=0
		state.room5_solo_limit_seen=false
		state.story_summon_unlocked=false
		state.room5_rematch_ready=false
		state.act0_complete=false
		state.act0_stage="first_forge"
		state.silver=maxi(1,state.silver)
		return state

	# From this point on, Covenant + weapon + committed forge are valid.
	state.first_forge_done=true
	state.catacomb_room=clampi(maxi(1,state.catacomb_room),1,5)

	# Rebuild the visual/encounter ledger from authoritative room progress.
	var cleared_by_room:={
		2:"cat_r1_skeleton",
		3:"cat_r2_hound",
		4:"cat_r3_guard",
		5:"cat_r4_revenant"
	}
	for threshold in cleared_by_room:
		var cleared_id:String=cleared_by_room[threshold]
		if state.catacomb_room>=int(threshold) and cleared_id not in state.cleared_encounters:
			state.cleared_encounters.append(cleared_id)

	if complete:
		for id in ["cat_r5_skeleton_a","cat_r5_skeleton_b"]:
			if id not in state.cleared_encounters:
				state.cleared_encounters.append(id)
		state.room5_solo_limit_seen=true
		state.story_summon_unlocked=true
		state.room5_rematch_ready=true
		state.catacomb_room=5
		state.act0_stage="act0_complete"
	elif summon or rematch:
		state.room5_solo_limit_seen=true
		state.story_summon_unlocked=true
		state.room5_rematch_ready=true
		state.catacomb_room=5
		state.act0_stage="room5_rematch"
	elif solo_seen:
		state.room5_solo_limit_seen=true
		state.story_summon_unlocked=false
		state.room5_rematch_ready=false
		state.catacomb_room=5
		state.act0_stage="room5_return"
	else:
		state.room5_solo_limit_seen=false
		state.story_summon_unlocked=false
		state.room5_rematch_ready=false
		state.act0_complete=false
		state.act0_stage="catacombs"

	return state

func patch_and_save(patch:Dictionary)->bool:
	var state:=load_state()
	for key in patch:
		state[key]=patch[key]
	return save_state(state)


static func has_save()->bool:
	return _read_dictionary(SAVE_PATH)!=null or _read_dictionary(BAK_PATH)!=null

static func create_new_game(identity:String)->bool:
	if identity not in ["male","female"]:
		return false
	var state:=default_state()
	state.shadow_identity=identity
	return save_state(state)

static func set_identity_on_existing_save(identity:String)->bool:
	if identity not in ["male","female"] or not has_save():
		return false
	var state:=load_state()
	state.shadow_identity=identity
	return save_state(state)
