class_name CombatTriggerEvent
extends RefCounted

var event_type:StringName=&""
var source_actor_id:StringName=&""
var source_team:StringName=&""
var target_actor_id:StringName=&""
var target_team:StringName=&""
var source_skill_id:StringName=&""
var turn_serial:int=0
var transaction_id:int=0
var chain_depth:int=0
var tags:Array[StringName]=[]
var payload:Dictionary={}

func _init(
	in_event_type:StringName=&"",
	in_source_actor_id:StringName=&"",
	in_target_actor_id:StringName=&"",
	in_turn_serial:int=0
)->void:
	event_type=in_event_type
	source_actor_id=in_source_actor_id
	target_actor_id=in_target_actor_id
	turn_serial=maxi(0,in_turn_serial)

func has_tag(tag:StringName)->bool:
	return tag in tags

func add_tag(tag:StringName)->void:
	if tag!=&"" and tag not in tags:
		tags.append(tag)

func snapshot()->Dictionary:
	var out_tags:Array[String]=[]
	for tag in tags:
		out_tags.append(str(tag))
	return {
		"event_type":str(event_type),
		"source_actor_id":str(source_actor_id),
		"source_team":str(source_team),
		"target_actor_id":str(target_actor_id),
		"target_team":str(target_team),
		"source_skill_id":str(source_skill_id),
		"turn_serial":turn_serial,
		"transaction_id":transaction_id,
		"chain_depth":chain_depth,
		"tags":out_tags,
		"payload":payload.duplicate(true)
	}
