class_name RoomEncounterFlow
extends RefCounted

enum State { IDLE, LOADING, READY, COMBAT, RESOLVED }

var state:=State.IDLE
var mission_id:=""
var room_id:=""
var transition_serial:=0

func request_room(next_mission_id:String,next_room_id:String)->bool:
	if state not in [State.IDLE,State.RESOLVED]:
		return false
	if next_mission_id.is_empty() or next_room_id.is_empty():
		return false
	mission_id=next_mission_id
	room_id=next_room_id
	transition_serial+=1
	state=State.LOADING
	return true

func mark_loaded(serial:int)->bool:
	if state!=State.LOADING or serial!=transition_serial: return false
	state=State.READY
	return true

func begin_combat(serial:int)->bool:
	if state!=State.READY or serial!=transition_serial: return false
	state=State.COMBAT
	return true

func resolve_room(serial:int)->bool:
	if state!=State.COMBAT or serial!=transition_serial: return false
	state=State.RESOLVED
	return true

func snapshot()->Dictionary:
	return {"state":state,"mission_id":mission_id,"room_id":room_id,"transition_serial":transition_serial}
