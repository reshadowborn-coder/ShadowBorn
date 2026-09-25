class_name CombatEffectContext
extends RefCounted

var source_actor_id:StringName = &""
var source_skill_id:StringName = &""
var source_item_id:StringName = &""
var source_school_id:StringName = &""
var weapon_family:StringName = &""
var target_actor_id:StringName = &""
var turn_index:int = 0
var transaction_id:int = 0

func _init(
	in_source_actor_id:StringName=&"",
	in_target_actor_id:StringName=&"",
	in_turn_index:int=0,
	in_transaction_id:int=0
)->void:
	source_actor_id=in_source_actor_id
	target_actor_id=in_target_actor_id
	turn_index=maxi(0,in_turn_index)
	transaction_id=maxi(0,in_transaction_id)

func duplicate_context()->CombatEffectContext:
	var copy:=CombatEffectContext.new(source_actor_id,target_actor_id,turn_index,transaction_id)
	copy.source_skill_id=source_skill_id
	copy.source_item_id=source_item_id
	copy.source_school_id=source_school_id
	copy.weapon_family=weapon_family
	return copy

func snapshot()->Dictionary:
	return {
		"source_actor_id":str(source_actor_id),
		"source_skill_id":str(source_skill_id),
		"source_item_id":str(source_item_id),
		"source_school_id":str(source_school_id),
		"weapon_family":str(weapon_family),
		"target_actor_id":str(target_actor_id),
		"turn_index":turn_index,
		"transaction_id":transaction_id
	}
