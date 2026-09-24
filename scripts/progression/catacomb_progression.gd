class_name CatacombProgression
extends Node

signal room_changed(room:int)
signal solo_limit_triggered
signal story_summon_unlocked
signal act0_completed
signal return_to_temple_requested

var room:=0
var room5_solo_limit_seen:=false
var summon_unlocked:=false
var rematch_ready:=false
var complete:=false

func restore(state:Dictionary)->void:
	room=clampi(int(state.get("catacomb_room",0)),0,5)
	room5_solo_limit_seen=bool(state.get("room5_solo_limit_seen",false))
	summon_unlocked=bool(state.get("story_summon_unlocked",false))
	rematch_ready=bool(state.get("room5_rematch_ready",false))
	complete=bool(state.get("act0_complete",false))

func snapshot()->Dictionary:
	return {"catacomb_room":room,"room5_solo_limit_seen":room5_solo_limit_seen,"story_summon_unlocked":summon_unlocked,"room5_rematch_ready":rematch_ready,"act0_complete":complete}

func start()->bool:
	if complete:
		return false
	if room==0:
		room=1
		room_changed.emit(room)
	return true

func clear_room(index:int)->bool:
	if complete or index<1 or index>5 or index!=room:
		return false
	if index<5:
		room=index+1
		room_changed.emit(room)
		return true
	if not summon_unlocked or not rematch_ready:
		return false
	complete=true
	act0_completed.emit()
	return true

func trigger_room5_solo_limit()->bool:
	if room!=5 or summon_unlocked or room5_solo_limit_seen or complete:
		return false
	room5_solo_limit_seen=true
	solo_limit_triggered.emit()
	return_to_temple_requested.emit()
	return true

func unlock_story_summon()->bool:
	if not room5_solo_limit_seen or summon_unlocked or complete:
		return false
	summon_unlocked=true
	rematch_ready=true
	story_summon_unlocked.emit()
	return true
