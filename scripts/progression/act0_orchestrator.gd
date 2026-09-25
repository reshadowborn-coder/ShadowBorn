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
	if not catacombs.return_to_temple_requested.is_connected(_on_solo_limit):
		catacombs.return_to_temple_requested.connect(_on_solo_limit)
	if not catacombs.story_summon_unlocked.is_connected(_on_companion_unlock):
		catacombs.story_summon_unlocked.connect(_on_companion_unlock)
	if not catacombs.act0_completed.is_connected(_on_act0_complete):
		catacombs.act0_completed.connect(_on_act0_complete)

func restore(state:Dictionary)->void:
	temple.restore(state)
	catacombs.restore(state)

func enter_catacombs()->bool:
	if not temple.first_forge_done:
		return false
	if temple.stage not in [Act0Contract.STAGE_CATACOMBS,Act0Contract.STAGE_ROOM5_REMATCH]:
		return false
	return catacombs.start()

func room_cleared(room:int)->bool:
	return catacombs.clear_room(room)

func room5_first_contact()->bool:
	return catacombs.trigger_room5_solo_limit()

func temple_story_handoff()->bool:
	if temple.stage!=Act0Contract.STAGE_ROOM5_RETURN:
		return false
	return catacombs.unlock_story_summon()

func _on_solo_limit()->void:
	if not temple.transition_to(Act0Contract.STAGE_ROOM5_RETURN):
		push_error("Act 0 contract rejected Catacombs -> Room 5 return transition")

func _on_companion_unlock()->void:
	if not temple.transition_to(Act0Contract.STAGE_ROOM5_REMATCH):
		push_error("Act 0 contract rejected Room 5 return -> rematch transition")

func _on_act0_complete()->void:
	if not temple.transition_to(Act0Contract.STAGE_COMPLETE):
		push_error("Act 0 contract rejected Room 5 rematch -> completion transition")

# External irreversible signals must describe committed state, not tentative
# in-memory transitions. Chapter00Game calls these only after save succeeds.
func commit_solo_limit_presentation()->bool:
	if temple.stage!=Act0Contract.STAGE_ROOM5_RETURN or not catacombs.room5_solo_limit_seen:
		return false
	temple_return.emit("solo_limit")
	return true

func commit_story_handoff_presentation()->bool:
	if temple.stage!=Act0Contract.STAGE_ROOM5_REMATCH or not catacombs.summon_unlocked or not catacombs.rematch_ready:
		return false
	companion_ready.emit(StoryCompanion.profile())
	return true

func commit_act0_completion_presentation()->bool:
	if temple.stage!=Act0Contract.STAGE_COMPLETE or not catacombs.complete:
		return false
	act0_finished.emit()
	return true
