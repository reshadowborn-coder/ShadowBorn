class_name Act0Contract
extends RefCounted

# Immutable gameplay contract for Act 0. Presentation/layout tuning must not
# redefine these states or bypass their order.
const STAGE_EXTERIOR := "exterior"
const STAGE_TEMPLE_ENTRY := "temple_entry"
const STAGE_WEAPON_CHOICE := "weapon_choice"
const STAGE_FIRST_FORGE := "first_forge"
const STAGE_CATACOMBS := "catacombs"
const STAGE_ROOM5_RETURN := "room5_return"
const STAGE_ROOM5_REMATCH := "room5_rematch"
const STAGE_COMPLETE := "act0_complete"

const STAGES := [
	STAGE_EXTERIOR,
	STAGE_TEMPLE_ENTRY,
	STAGE_WEAPON_CHOICE,
	STAGE_FIRST_FORGE,
	STAGE_CATACOMBS,
	STAGE_ROOM5_RETURN,
	STAGE_ROOM5_REMATCH,
	STAGE_COMPLETE
]

const WEAPON_FAMILIES := [
	"sword_shield",
	"bow",
	"two_hand_axe",
	"dual_daggers",
	"mage_staff"
]

const EXTERIOR_ENCOUNTERS := ["hound","armless","shield_boss"]

const CATACOMB_ENCOUNTER_IDS := {
	1:["cat_r1_skeleton"],
	2:["cat_r2_hound"],
	3:["cat_r3_guard"],
	4:["cat_r4_revenant"],
	5:["cat_r5_skeleton_a","cat_r5_skeleton_b"]
}

const CATACOMB_CHECKPOINT_IDS := {
	0:"temple_entry",
	1:"catacombs_entry",
	2:"cat_r1_skeleton_cleared",
	3:"cat_r2_hound_cleared",
	4:"cat_r3_guard_cleared",
	5:"cat_r4_revenant_cleared"
}

const TRANSITIONS := {
	STAGE_EXTERIOR:[STAGE_TEMPLE_ENTRY],
	STAGE_TEMPLE_ENTRY:[STAGE_WEAPON_CHOICE],
	STAGE_WEAPON_CHOICE:[STAGE_FIRST_FORGE],
	STAGE_FIRST_FORGE:[STAGE_CATACOMBS],
	STAGE_CATACOMBS:[STAGE_ROOM5_RETURN],
	STAGE_ROOM5_RETURN:[STAGE_ROOM5_REMATCH],
	STAGE_ROOM5_REMATCH:[STAGE_COMPLETE],
	STAGE_COMPLETE:[]
}

static func normalize_stage(value:String)->String:
	return value if value in STAGES else STAGE_EXTERIOR

static func can_transition(current:String,next:String)->bool:
	if current==next:
		return true
	if not TRANSITIONS.has(current):
		return false
	return next in TRANSITIONS[current]

static func is_exterior_encounter(id:String)->bool:
	return id in EXTERIOR_ENCOUNTERS

static func can_start_exterior_encounter(id:String,cleared:Array,temple_reveal_seen:bool=false)->bool:
	match id:
		"hound":
			return true
		"armless":
			return "hound" in cleared
		"shield_boss":
			return "hound" in cleared and "armless" in cleared and temple_reveal_seen
	return false

static func catacomb_encounter_ids(room:int)->Array:
	return CATACOMB_ENCOUNTER_IDS.get(room,[]).duplicate()

static func catacomb_checkpoint_id(room:int)->String:
	return str(CATACOMB_CHECKPOINT_IDS.get(clampi(room,0,5),""))

static func all_catacomb_encounter_ids()->Array:
	var out:Array=[]
	for room in range(1,6):
		out.append_array(catacomb_encounter_ids(room))
	return out

static func all_encounter_ids()->Array:
	var out:Array=EXTERIOR_ENCOUNTERS.duplicate()
	out.append_array(all_catacomb_encounter_ids())
	return out
