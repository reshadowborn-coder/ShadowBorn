class_name TeamState
extends Node

signal slot_unlocked(index:int)
var slots:Array=[{"id":"shadow","locked":false},{"id":"","locked":true}]

func restore(state:Dictionary)->void:
	slots=[{"id":"shadow","locked":false},{"id":"","locked":true}]
	if bool(state.get("story_summon_unlocked",false)):
		slots[1]={"id":StoryCompanion.ID,"locked":false}

func unlock_story_slot()->void:
	if not slots[1].locked:return
	slots[1]={"id":StoryCompanion.ID,"locked":false}
	slot_unlocked.emit(1)

func active_ids()->Array[String]:
	var out:Array[String]=[]
	for slot in slots:
		if not slot.locked and not str(slot.id).is_empty():out.append(str(slot.id))
	return out
