class_name Act0Layout
extends RefCounted

# Mutable spatial/presentation tuning. These values may move during graybox
# iteration without changing the Act 0 progression contract.
const TEMPLE_GATE_TRIGGER := Vector3(0,1,-73)
const FADED_SIGIL_TRIGGER := Vector3(0,1,-67)
const TEMPLE_ENTRY_CHECKPOINT := Vector3(0,0.9,-78)

const KEEPER_TRIGGER := Vector3(0,1,-101)
const COVENANT_TRIGGER := Vector3(0,1,-105)
const SMITH_TRIGGER := Vector3(-4.5,1,-82)
const MERCHANT_TRIGGER := Vector3(4.6,1,-82)
const ENGRAVER_TRIGGER := Vector3(-4.6,1,-91)
const CATACOMBS_TRIGGER := Vector3(0,1,-112)

const CATACOMB_ENTRY_CHECKPOINT := Vector3(0,0.9,-117)
const ROOM5_RETURN_CHECKPOINT := Vector3(0,0.9,-96)
const ROOM5_SHADOW_POSITION := Vector3(0,0.9,-171.5)
const ROOM5_FOCUS_ANCHOR := Vector3(0,1.0,-175.5)

const TEMPLE_INTERACTION_TRIGGER_SIZE := Vector3(5,2.5,3)
const TEMPLE_GATE_TRIGGER_SIZE := Vector3(16,3.0,4)
const TEMPLE_GATE_BLOCKER_SIZE := Vector3(28,4.0,0.8)
const CATACOMB_GATE_BLOCKER_SIZE := Vector3(7.2,4.0,0.8)
const CATACOMB_ROOM_TRIGGER_SIZE := Vector3(11.0,2.5,3)
const EXTERIOR_ENCOUNTER_TRIGGER_SIZE := Vector3(26,2.5,4)

static func catacomb_room_trigger_position(room:int)->Vector3:
	return Vector3(0,1,-122.0-float(room-1)*13.0)
