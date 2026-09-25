class_name Act1Contract
extends RefCounted

const STAGE_LOCKED:="locked"
const STAGE_SEWER_ROOM1:="sewer_room1"
const STAGE_SEWER_ROOM2:="sewer_room2"
const STAGE_SEWER_ROOM3:="sewer_room3"
const STAGE_TEMPLE_RETURN:="temple_return"
const STAGE_KEEPER_BRIEFING:="keeper_briefing"
const STAGE_SMITH_HANDOFF:="smith_handoff"
const STAGE_GUARD_COVENANT:="guard_covenant"
const STAGE_ACT1_1_COMPLETE:="act1_1_complete"

const STAGES=[
	STAGE_LOCKED,
	STAGE_SEWER_ROOM1,
	STAGE_SEWER_ROOM2,
	STAGE_SEWER_ROOM3,
	STAGE_TEMPLE_RETURN,
	STAGE_KEEPER_BRIEFING,
	STAGE_SMITH_HANDOFF,
	STAGE_GUARD_COVENANT,
	STAGE_ACT1_1_COMPLETE
]

const SEWER_ENCOUNTER_IDS={
	1:["a1_r1_rat"],
	2:["a1_r2_poison_rat"],
	3:["a1_r3_rat_a","a1_r3_rat_b"]
}

const TRANSITIONS={
	STAGE_LOCKED:[STAGE_SEWER_ROOM1],
	STAGE_SEWER_ROOM1:[STAGE_SEWER_ROOM2],
	STAGE_SEWER_ROOM2:[STAGE_SEWER_ROOM3],
	STAGE_SEWER_ROOM3:[STAGE_TEMPLE_RETURN],
	STAGE_TEMPLE_RETURN:[STAGE_KEEPER_BRIEFING],
	STAGE_KEEPER_BRIEFING:[STAGE_SMITH_HANDOFF],
	STAGE_SMITH_HANDOFF:[STAGE_GUARD_COVENANT],
	STAGE_GUARD_COVENANT:[STAGE_ACT1_1_COMPLETE],
	STAGE_ACT1_1_COMPLETE:[]
}

static func normalize_stage(value:String,act0_complete:bool=false)->String:
	if value in STAGES:
		if value==STAGE_LOCKED and act0_complete:
			return STAGE_SEWER_ROOM1
		return value
	return STAGE_SEWER_ROOM1 if act0_complete else STAGE_LOCKED

static func can_transition(current:String,next:String)->bool:
	if current==next:
		return true
	return TRANSITIONS.has(current) and next in TRANSITIONS[current]

static func encounter_ids(room:int)->Array:
	return SEWER_ENCOUNTER_IDS.get(room,[]).duplicate()

static func all_encounter_ids()->Array:
	var out:Array=[]
	for room in range(1,4):
		out.append_array(encounter_ids(room))
	return out

static func room_for_stage(stage:String)->int:
	match stage:
		STAGE_SEWER_ROOM1: return 1
		STAGE_SEWER_ROOM2: return 2
		STAGE_SEWER_ROOM3: return 3
	return 0