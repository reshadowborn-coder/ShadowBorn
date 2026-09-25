class_name Act1Layout
extends RefCounted

const SEWER_ENTRY:=Vector3(30.0,0.9,-76.0)
const ROOM1_TRIGGER:=Vector3(30.0,1.0,-86.0)
const ROOM2_TRIGGER:=Vector3(30.0,1.0,-101.0)
const ROOM3_TRIGGER:=Vector3(30.0,1.0,-117.0)
const ROOM3_SHADOW_POSITION:=Vector3(30.0,0.9,-114.0)
const ROOM3_FOCUS:=Vector3(30.0,1.0,-119.0)

const TEMPLE_RETURN:=Vector3(0.0,0.9,-97.0)
const KEEPER_HANDOFF:=Act0Layout.KEEPER_TRIGGER
const SMITH_HANDOFF:=Act0Layout.SMITH_TRIGGER
const GUARD_POSITION:=Vector3(4.7,0.0,-98.2)
const GUARD_TRIGGER:=Vector3(4.7,1.0,-98.2)

const ROOM_TRIGGER_SIZE:=Vector3(9.0,2.5,3.0)
const TEMPLE_HANDOFF_SIZE:=Vector3(6.0,2.5,4.0)

static func room_trigger(room:int)->Vector3:
	match room:
		1: return ROOM1_TRIGGER
		2: return ROOM2_TRIGGER
		3: return ROOM3_TRIGGER
	return SEWER_ENTRY

static func room_checkpoint(room:int)->Vector3:
	var trigger:=room_trigger(room)
	return Vector3(trigger.x,0.9,trigger.z+4.0)