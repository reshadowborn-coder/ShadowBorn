class_name Act0Orchestrator
extends Node

signal temple_return(reason:String)
signal companion_ready(profile:Dictionary)
signal act0_finished

var temple:Act0Progression
var catacombs:CatacombProgression
var save_manager:Node

func setup(t:Act0Progression,c:CatacombProgression,s:Node)->void:
	temple=t;catacombs=c;save_manager=s
	catacombs.return_to_temple_requested.connect(_on_solo_limit)
	catacombs.story_summon_unlocked.connect(_on_companion_unlock)
	catacombs.act0_completed.connect(_on_act0_complete)

func restore(state:Dictionary)->void:
	temple.restore(state);catacombs.restore(state)

func enter_catacombs()->bool:
	if not temple.first_forge_done:return false
	catacombs.start();_commit();return true

func room_cleared(room:int)->void:
	catacombs.clear_room(room);_commit()

func room5_first_contact()->bool:
	var triggered:=catacombs.trigger_room5_solo_limit()
	if triggered:_commit()
	return triggered

func temple_story_handoff()->bool:
	if not catacombs.room5_solo_limit_seen or catacombs.summon_unlocked:return false
	catacombs.unlock_story_summon();_commit();return true

func _on_solo_limit()->void:
	temple.stage="room5_return";temple_return.emit("solo_limit");_commit()

func _on_companion_unlock()->void:
	temple.stage="room5_rematch"
	companion_ready.emit(StoryCompanion.profile())

func _on_act0_complete()->void:
	temple.stage="act0_complete";act0_finished.emit();_commit()

func _commit()->void:
	if save_manager==null:return
	var merged:=temple.snapshot()
	for k in catacombs.snapshot():merged[k]=catacombs.snapshot()[k]
	if save_manager.has_method("patch_and_save"):save_manager.patch_and_save(merged)
