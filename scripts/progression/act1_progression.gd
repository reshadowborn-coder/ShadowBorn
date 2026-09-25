class_name Act1Progression
extends Node

signal stage_changed(stage:String)
signal temple_watch_joined

var stage:=Act1Contract.STAGE_LOCKED
var sewer_room:=0
var sewer_defeat_seen:=false
var keeper_briefed:=false
var smith_handoff_done:=false
var temple_watch_covenant_joined:=false
var act1_1_complete:=false

func restore(state:Dictionary)->void:
	var act0_complete:=bool(state.get("act0_complete",false))
	stage=Act1Contract.normalize_stage(str(state.get("act1_stage",Act1Contract.STAGE_LOCKED)),act0_complete)
	sewer_room=clampi(int(state.get("act1_sewer_room",Act1Contract.room_for_stage(stage))),0,3)
	sewer_defeat_seen=bool(state.get("act1_sewer_defeat_seen",false))
	keeper_briefed=bool(state.get("act1_keeper_briefed",false))
	smith_handoff_done=bool(state.get("act1_smith_handoff_done",false))
	temple_watch_covenant_joined=bool(state.get("temple_watch_covenant_joined",false))
	act1_1_complete=bool(state.get("act1_1_complete",false))

func snapshot()->Dictionary:
	return {
		"act1_stage":stage,
		"act1_sewer_room":sewer_room,
		"act1_sewer_defeat_seen":sewer_defeat_seen,
		"act1_keeper_briefed":keeper_briefed,
		"act1_smith_handoff_done":smith_handoff_done,
		"temple_watch_covenant_joined":temple_watch_covenant_joined,
		"act1_1_complete":act1_1_complete
	}

func begin_from_completed_act0()->bool:
	if stage!=Act1Contract.STAGE_LOCKED:
		return stage==Act1Contract.STAGE_SEWER_ROOM1
	stage=Act1Contract.STAGE_SEWER_ROOM1
	sewer_room=1
	stage_changed.emit(stage)
	return true

func room_cleared(room:int)->bool:
	if room not in [1,2]:
		return false
	if room!=sewer_room or Act1Contract.room_for_stage(stage)!=room:
		return false
	var next_stage:=Act1Contract.STAGE_SEWER_ROOM2 if room==1 else Act1Contract.STAGE_SEWER_ROOM3
	if not Act1Contract.can_transition(stage,next_stage):
		return false
	stage=next_stage
	sewer_room=room+1
	stage_changed.emit(stage)
	return true

func commit_pack_defeat()->bool:
	if stage!=Act1Contract.STAGE_SEWER_ROOM3 or sewer_room!=3 or sewer_defeat_seen:
		return false
	if not Act1Contract.can_transition(stage,Act1Contract.STAGE_TEMPLE_RETURN):
		return false
	sewer_defeat_seen=true
	stage=Act1Contract.STAGE_TEMPLE_RETURN
	sewer_room=0
	stage_changed.emit(stage)
	return true

func keeper_briefing()->bool:
	if stage!=Act1Contract.STAGE_TEMPLE_RETURN or not sewer_defeat_seen:
		return false
	if not Act1Contract.can_transition(stage,Act1Contract.STAGE_KEEPER_BRIEFING):
		return false
	keeper_briefed=true
	stage=Act1Contract.STAGE_KEEPER_BRIEFING
	stage_changed.emit(stage)
	return true

func smith_handoff()->bool:
	if stage!=Act1Contract.STAGE_KEEPER_BRIEFING or not keeper_briefed:
		return false
	if not Act1Contract.can_transition(stage,Act1Contract.STAGE_SMITH_HANDOFF):
		return false
	smith_handoff_done=true
	stage=Act1Contract.STAGE_SMITH_HANDOFF
	stage_changed.emit(stage)
	return true

func guard_offer_ready()->bool:
	return stage==Act1Contract.STAGE_SMITH_HANDOFF and keeper_briefed and smith_handoff_done and not temple_watch_covenant_joined

func join_temple_watch()->bool:
	if not guard_offer_ready():
		return false
	if not Act1Contract.can_transition(stage,Act1Contract.STAGE_GUARD_COVENANT):
		return false
	temple_watch_covenant_joined=true
	stage=Act1Contract.STAGE_GUARD_COVENANT
	temple_watch_joined.emit()
	stage_changed.emit(stage)
	return true

func complete_act1_1()->bool:
	if stage!=Act1Contract.STAGE_GUARD_COVENANT or not temple_watch_covenant_joined:
		return false
	if not Act1Contract.can_transition(stage,Act1Contract.STAGE_ACT1_1_COMPLETE):
		return false
	act1_1_complete=true
	stage=Act1Contract.STAGE_ACT1_1_COMPLETE
	stage_changed.emit(stage)
	return true