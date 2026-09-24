class_name Act0Orchestrator
extends Node

signal temple_return(reason:String)
signal companion_ready(profile:Dictionary)
signal act0_finished

var temple:Act0Progression
var catacombs:CatacombProgression

func setup(t:Act0Progression,c:CatacombProgression,_save_manager:Node=null)->void:
	temple=t
	catacombs=c
	catacombs.return_to_temple_requested.connect(_on_solo_limit)
	catacombs.story_summon_unlocked.connect(_on_companion_unlock)
	catacombs.act0_completed.connect(_on_act0_complete)

func restore(state:Dictionary)->void:
	temple.restore(state)
	catacombs.restore(state)

func enter_catacombs()->bool:
	if not temple.first_forge_done:
		return false
	if temple.stage not in ["catacombs","room5_rematch"]:
		return false
	return catacombs.start()

func room_cleared(room:int)->bool:
	return catacombs.clear_room(room)

func room5_first_contact()->bool:
	return catacombs.trigger_room5_solo_limit()

func temple_story_handoff()->bool:
	if temple.stage!="room5_return":
		return false
	return catacombs.unlock_story_summon()

func _on_solo_limit()->void:
	temple.stage="room5_return"
	temple_return.emit("solo_limit")

func _on_companion_unlock()->void:
	temple.stage="room5_rematch"
	companion_ready.emit(StoryCompanion.profile())

func _on_act0_complete()->void:
	temple.stage="act0_complete"
	act0_finished.emit()
