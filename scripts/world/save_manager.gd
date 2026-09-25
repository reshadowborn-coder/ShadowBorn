class_name SaveManager
extends Node

const SAVE_PATH := "user://chapter00_save.json"
const TMP_PATH := SAVE_PATH + ".tmp"
const BAK_PATH := SAVE_PATH + ".bak"
const SAVE_VERSION := 5

static func default_state() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"checkpoint": "awakening",
		"route_index": 0,
		"checkpoint_position": [0.0, 0.9, 8.0],
		"cleared_encounters": [],
		"performance_mode": "smooth60",
		"reduced_motion": false,
		"shadow_identity": "",
		"act0_stage": Act0Contract.STAGE_EXTERIOR,
		"hound_residual_absorbed": false,
		"temple_reveal_seen": false,
		"faded_sigil_activated": false,
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

static func _vector3_array(v:Vector3)->Array:
	return [v.x,v.y,v.z]

static func _strict_bool(value,default_value:bool=false)->bool:
	return bool(value) if typeof(value)==TYPE_BOOL else default_value

static func _checkpoint_values(value)->Variant:
	if typeof(value)!=TYPE_ARRAY or value.size()!=3:
		return null
	for component in value:
		if typeof(component) not in [TYPE_INT,TYPE_FLOAT]:
			return null
	var x:=float(value[0])
	var y:=float(value[1])
	var z:=float(value[2])
	if x!=x or y!=y or z!=z:
		return null
	if absf(x)>15.0 or y < -1.0 or y > 5.0 or z > 15.0 or z < -182.0:
		return null
	return Vector3(x,y,z)

static func _near_checkpoint(p:Vector3,target:Vector3,horizontal:float=1.75,vertical:float=1.5)->bool:
	return absf(p.x-target.x)<=horizontal and absf(p.z-target.z)<=horizontal and absf(p.y-target.y)<=vertical

static func _expected_checkpoint_id(state:Dictionary)->String:
	var stage:=str(state.get("act0_stage",Act0Contract.STAGE_EXTERIOR))
	match stage:
		Act0Contract.STAGE_EXTERIOR:
			if bool(state.get("temple_reveal_seen",false)):
				return "temple_reveal_seen"
			var cleared:Array=state.get("cleared_encounters",[])
			if "armless" in cleared:
				return "armless_cleared"
			if "hound" in cleared:
				return "hound_cleared"
			return "awakening"
		Act0Contract.STAGE_TEMPLE_ENTRY:
			return "temple_entry" if bool(state.get("faded_sigil_activated",false)) and str(state.get("checkpoint",""))=="temple_entry" else "faded_sigil"
		Act0Contract.STAGE_WEAPON_CHOICE,Act0Contract.STAGE_FIRST_FORGE:
			return "temple_entry"
		Act0Contract.STAGE_CATACOMBS:
			var room:=clampi(int(state.get("catacomb_room",0)),0,5)
			if room==0:
				return "temple_entry"
			match room:
				1: return "catacombs_entry"
				2: return "cat_r1_skeleton_cleared"
				3: return "cat_r2_hound_cleared"
				4: return "cat_r3_guard_cleared"
				5: return "cat_r4_revenant_cleared"
		Act0Contract.STAGE_ROOM5_RETURN:
			return "room5_return"
		Act0Contract.STAGE_ROOM5_REMATCH:
			return "room5_rematch"
		Act0Contract.STAGE_COMPLETE:
			return "act0_complete"
	return ""

static func _checkpoint_id_matches_stage(state:Dictionary)->bool:
	var expected:=_expected_checkpoint_id(state)
	if expected.is_empty():
		return false
	return str(state.get("checkpoint",""))==expected

static func _checkpoint_matches_stage(state:Dictionary,p:Vector3)->bool:
	var stage:=str(state.get("act0_stage",Act0Contract.STAGE_EXTERIOR))
	var checkpoint:=str(state.get("checkpoint",""))
	if p.y<0.35 or p.y>2.2:
		return false
	match stage:
		Act0Contract.STAGE_EXTERIOR:
			match checkpoint:
				"awakening":
					return _near_checkpoint(p,Vector3(0,0.9,8),3.0)
				"hound_cleared":
					return _near_checkpoint(p,Vector3(Act0Layout.HOUND_TRIGGER.x,0.9,Act0Layout.HOUND_TRIGGER.z),5.0)
				"armless_cleared":
					return _near_checkpoint(p,Vector3(Act0Layout.ARMLESS_TRIGGER.x,0.9,Act0Layout.ARMLESS_TRIGGER.z),5.0)
				"temple_reveal_seen":
					return _near_checkpoint(p,Vector3(Act0Layout.TEMPLE_REVEAL_TRIGGER.x,0.9,Act0Layout.TEMPLE_REVEAL_TRIGGER.z),5.0)
			return false
		Act0Contract.STAGE_TEMPLE_ENTRY:
			if checkpoint=="temple_entry":
				return _near_checkpoint(p,Act0Layout.TEMPLE_ENTRY_CHECKPOINT,2.0)
			if checkpoint=="faded_sigil":
				return _near_checkpoint(p,Vector3(Act0Layout.FADED_SIGIL_TRIGGER.x,0.9,Act0Layout.FADED_SIGIL_TRIGGER.z),2.0)
			return false
		Act0Contract.STAGE_WEAPON_CHOICE,Act0Contract.STAGE_FIRST_FORGE:
			return checkpoint=="temple_entry" and _near_checkpoint(p,Act0Layout.TEMPLE_ENTRY_CHECKPOINT,2.0)
		Act0Contract.STAGE_CATACOMBS:
			var room:=clampi(int(state.get("catacomb_room",0)),0,5)
			if room==0:
				return checkpoint=="temple_entry" and _near_checkpoint(p,Act0Layout.TEMPLE_ENTRY_CHECKPOINT,2.0)
			var room_z:=Act0Layout.catacomb_room_z(room)
			# A legitimate checkpoint for the current room can originate from
			# the previous room clear or from the approach to this room, but
			# never from a later room.
			return absf(p.x)<=5.15 and p.z<=room_z+13.5 and p.z>=room_z-3.5
		Act0Contract.STAGE_ROOM5_RETURN,Act0Contract.STAGE_ROOM5_REMATCH:
			return _near_checkpoint(p,Act0Layout.ROOM5_RETURN_CHECKPOINT,2.0)
		Act0Contract.STAGE_COMPLETE:
			return _near_checkpoint(p,Act0Layout.ROOM5_SHADOW_POSITION,5.0)
	return false

static func _repair_checkpoint(state:Dictionary)->Dictionary:
	var parsed=_checkpoint_values(state.get("checkpoint_position"))
	if parsed!=null and _checkpoint_matches_stage(state,parsed) and _checkpoint_id_matches_stage(state):
		return state

	var stage:=str(state.get("act0_stage",Act0Contract.STAGE_EXTERIOR))
	var recovery:=Vector3(0,0.9,8)
	var checkpoint:="awakening"
	match stage:
		Act0Contract.STAGE_TEMPLE_ENTRY:
			if bool(state.get("faded_sigil_activated",false)):
				recovery=Act0Layout.TEMPLE_ENTRY_CHECKPOINT
				checkpoint="temple_entry"
			else:
				recovery=Vector3(Act0Layout.FADED_SIGIL_TRIGGER.x,0.9,Act0Layout.FADED_SIGIL_TRIGGER.z)
				checkpoint="faded_sigil"
		Act0Contract.STAGE_WEAPON_CHOICE,Act0Contract.STAGE_FIRST_FORGE:
			recovery=Act0Layout.TEMPLE_ENTRY_CHECKPOINT
			checkpoint="temple_entry"
		Act0Contract.STAGE_CATACOMBS:
			var room:=clampi(int(state.get("catacomb_room",0)),0,5)
			if room==0:
				recovery=Act0Layout.TEMPLE_ENTRY_CHECKPOINT
				checkpoint="temple_entry"
			else:
				recovery=Act0Layout.catacomb_room_resume_position(room)
				checkpoint=_expected_checkpoint_id(state)
		Act0Contract.STAGE_ROOM5_RETURN:
			recovery=Act0Layout.ROOM5_RETURN_CHECKPOINT
			checkpoint="room5_return"
		Act0Contract.STAGE_ROOM5_REMATCH:
			recovery=Act0Layout.ROOM5_RETURN_CHECKPOINT
			checkpoint="room5_rematch"
		Act0Contract.STAGE_COMPLETE:
			recovery=Act0Layout.ROOM5_SHADOW_POSITION
			checkpoint="act0_complete"
	state.checkpoint_position=_vector3_array(recovery)
	state.checkpoint=checkpoint
	return state

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

	# Keep the previous valid generation. load_state() can then recover even
	# if the newly promoted primary file is later truncated or corrupted.
	return true

static func _migrate(raw: Dictionary) -> Dictionary:
	var source_version:=int(raw.get("version",0))
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
	state.reduced_motion=_strict_bool(state.get("reduced_motion",false))
	var identity:=str(state.get("shadow_identity",""))
	state.shadow_identity = identity if identity in ["","male","female"] else ""

	state.act0_stage=Act0Contract.normalize_stage(str(state.get("act0_stage",Act0Contract.STAGE_EXTERIOR)))

	var family:=str(state.get("weapon_family",""))
	if not family.is_empty() and (family not in Act0Contract.WEAPON_FAMILIES or not Act0Progression.WEAPONS.has(family)):
		family=""
	state.weapon_family=family

	var covenant:=_strict_bool(state.get("covenant_joined",false))
	var forged:=_strict_bool(state.get("first_forge_done",false))
	var solo_seen:=_strict_bool(state.get("room5_solo_limit_seen",false))
	var summon:=_strict_bool(state.get("story_summon_unlocked",false))
	var rematch:=_strict_bool(state.get("room5_rematch_ready",false))
	var complete:=_strict_bool(state.get("act0_complete",false))

	# Any downstream state proves the exterior route had already completed.
	# Recover forward rather than replaying irreversible rewards.
	var later_progress: bool = (
		covenant
		or not family.is_empty()
		or forged
		or int(state.catacomb_room)>0
		or solo_seen
		or summon
		or rematch
		or complete
		or str(state.act0_stage) not in [Act0Contract.STAGE_EXTERIOR,Act0Contract.STAGE_TEMPLE_ENTRY]
	)
	if later_progress and "shield_boss" not in state.cleared_encounters:
		state.cleared_encounters.append("shield_boss")

	# Exterior fights are a fixed chain. Repair old/corrupt ledgers so a later
	# encounter can never exist without all mandatory prerequisites.
	if "shield_boss" in state.cleared_encounters:
		for id in ["hound","armless"]:
			if id not in state.cleared_encounters:
				state.cleared_encounters.append(id)
	elif "armless" in state.cleared_encounters and "hound" not in state.cleared_encounters:
		state.cleared_encounters.append("hound")

	var hound_cleared:bool="hound" in state.cleared_encounters
	var armless_cleared:bool="armless" in state.cleared_encounters
	var shield_cleared:bool="shield_boss" in state.cleared_encounters

	# Hound clear and residual absorption are persisted by the same runtime
	# transition. A save containing the clear but not the one-shot flag is
	# incomplete/corrupt and must converge forward rather than replay it.
	state.hound_residual_absorbed=hound_cleared

	# Shield is unreachable in the canonical flow until the reveal has played.
	# If a later state proves Shield was reached, converge the one-shot forward.
	state.temple_reveal_seen=_strict_bool(state.get("temple_reveal_seen",false)) and armless_cleared
	if shield_cleared:
		state.temple_reveal_seen=true

	var downstream_after_sigil:bool=(
		covenant
		or not family.is_empty()
		or forged
		or int(state.catacomb_room)>0
		or solo_seen
		or summon
		or rematch
		or complete
		or str(state.act0_stage) not in [Act0Contract.STAGE_EXTERIOR,Act0Contract.STAGE_TEMPLE_ENTRY]
	)
	state.faded_sigil_activated=_strict_bool(state.get("faded_sigil_activated",false)) and shield_cleared
	if shield_cleared and (source_version<SAVE_VERSION or downstream_after_sigil):
		# Preserve access for v4 and older saves that already passed the old
		# ungated threshold.
		state.faded_sigil_activated=true

	# Route position is derived from irreversible gameplay evidence instead of
	# trusting a stale/corrupt index from an older Director implementation.
	if shield_cleared:
		state.route_index=Chapter00Director.ROUTE.find("temple_gate")
	elif bool(state.temple_reveal_seen):
		state.route_index=Chapter00Director.ROUTE.find("shield_boss")
	elif armless_cleared:
		state.route_index=Chapter00Director.ROUTE.find("temple_reveal")
	elif hound_cleared:
		state.route_index=Chapter00Director.ROUTE.find("ruins")
	else:
		state.route_index=Chapter00Director.ROUTE.find("awakening")

	# Validate a committed forge before trusting downstream Catacomb state.
	if forged:
		var item=state.get("forged_item",{})
		if (
			family.is_empty()
			or typeof(item)!=TYPE_DICTIONARY
			or not Act0Progression.is_valid_first_forge_item(item,family)
		):
			forged=false
			state.first_forge_done=false
			state.forged_item={}
			state.silver=maxi(1,state.silver)

	# Act 0 has exactly one Silver source (Shield) and the scripted first forge
	# consumes it. Treat currency as derived progression evidence, not arbitrary
	# JSON input.
	if not shield_cleared:
		state.silver=0
	elif forged:
		state.silver=0
	else:
		state.silver=1

	if not covenant:
		state.weapon_family=""
		state.forged_item={}
		state.first_forge_done=false
		state.catacomb_room=0
		state.room5_solo_limit_seen=false
		state.story_summon_unlocked=false
		state.room5_rematch_ready=false
		state.act0_complete=false
		state.act0_stage=Act0Contract.STAGE_TEMPLE_ENTRY if shield_cleared else Act0Contract.STAGE_EXTERIOR
		if shield_cleared:
			state.silver=maxi(1,state.silver)
		return _repair_checkpoint(state)

	state.covenant_joined=true
	state.faded_sigil_activated=true

	if family.is_empty():
		state.forged_item={}
		state.first_forge_done=false
		state.catacomb_room=0
		state.room5_solo_limit_seen=false
		state.story_summon_unlocked=false
		state.room5_rematch_ready=false
		state.act0_complete=false
		state.act0_stage=Act0Contract.STAGE_WEAPON_CHOICE
		if shield_cleared:
			state.silver=maxi(1,state.silver)
		return _repair_checkpoint(state)

	if not forged:
		state.first_forge_done=false
		state.forged_item={}
		state.catacomb_room=0
		state.room5_solo_limit_seen=false
		state.story_summon_unlocked=false
		state.room5_rematch_ready=false
		state.act0_complete=false
		state.act0_stage=Act0Contract.STAGE_FIRST_FORGE
		state.silver=maxi(1,state.silver)
		return _repair_checkpoint(state)

	# From this point on, Covenant + weapon + committed forge are valid.
	# Room 0 is meaningful: the forge is complete and the Catacomb passage is
	# unlocked, but the player has not physically entered Room 1 yet.
	state.first_forge_done=true
	state.catacomb_room=clampi(int(state.catacomb_room),0,5)

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
		state.act0_stage=Act0Contract.STAGE_COMPLETE
	elif summon or rematch:
		state.room5_solo_limit_seen=true
		state.story_summon_unlocked=true
		state.room5_rematch_ready=true
		state.catacomb_room=5
		state.act0_stage=Act0Contract.STAGE_ROOM5_REMATCH
	elif solo_seen:
		state.room5_solo_limit_seen=true
		state.story_summon_unlocked=false
		state.room5_rematch_ready=false
		state.catacomb_room=5
		state.act0_stage=Act0Contract.STAGE_ROOM5_RETURN
	else:
		state.room5_solo_limit_seen=false
		state.story_summon_unlocked=false
		state.room5_rematch_ready=false
		state.act0_complete=false
		state.act0_stage=Act0Contract.STAGE_CATACOMBS

	return _repair_checkpoint(state)

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
	# First promotion replaces the old game. The second identical promotion
	# seeds the retained backup with the new game too, so corruption cannot
	# resurrect progress the player explicitly replaced.
	if not save_state(state):
		return false
	return save_state(state)

static func set_identity_on_existing_save(identity:String)->bool:
	if identity not in ["male","female"] or not has_save():
		return false
	var state:=load_state()
	state.shadow_identity=identity
	return save_state(state)
