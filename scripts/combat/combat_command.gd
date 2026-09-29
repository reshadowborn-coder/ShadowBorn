class_name CombatCommand
extends RefCounted

var actor_id: StringName
var skill_index: int
var source: StringName

func _init(p_actor_id: StringName, p_skill_index: int, p_source: StringName = &"runtime") -> void:
	actor_id = p_actor_id
	skill_index = p_skill_index
	source = p_source
