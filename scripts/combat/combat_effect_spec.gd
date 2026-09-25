class_name CombatEffectSpec
extends RefCounted

var definition:CombatEffectDefinition
var context:CombatEffectContext
var level:float = 1.0
var remaining_turns:int = 0
var stack_count:int = 1
var runtime_magnitudes:Dictionary = {}
# Provenance is tracked per magnitude instead of assuming the latest refresher
# owns every retained value. This matters for DoT kill credit/passive triggers.
var magnitude_sources:Dictionary = {}
var stack_sources:Array[CombatEffectContext] = []
var dynamic_tags:Array[StringName] = []
var calculated_deltas:Dictionary = {}
var created_tags:Array[StringName] = []
var consumed_tags:Array[StringName] = []
var cue_ids:Array[StringName] = []

func _init(
	in_definition:CombatEffectDefinition,
	in_context:CombatEffectContext,
	in_level:float=1.0
)->void:
	assert(in_definition!=null,"CombatEffectSpec requires a definition")
	assert(in_context!=null,"CombatEffectSpec requires a context")
	definition=in_definition
	context=in_context.duplicate_context()
	level=maxf(0.0,in_level)
	remaining_turns=maxi(0,definition.base_duration_turns)
	runtime_magnitudes=definition.base_magnitudes.duplicate(true)
	for raw_key in runtime_magnitudes:
		magnitude_sources[str(raw_key)]=context.duplicate_context()
	stack_sources.append(context.duplicate_context())
	cue_ids.assign(definition.cue_ids)

func set_runtime_magnitude(key:String,value,source_context:CombatEffectContext=null)->void:
	runtime_magnitudes[key]=value
	var source:=source_context if source_context!=null else context
	magnitude_sources[key]=source.duplicate_context()

func magnitude_source(key:String)->CombatEffectContext:
	var value=magnitude_sources.get(key)
	if value is CombatEffectContext:
		return (value as CombatEffectContext).duplicate_context()
	return context.duplicate_context()

func add_stack_source(source_context:CombatEffectContext)->void:
	if source_context!=null:
		stack_sources.append(source_context.duplicate_context())

func stack_source_actor_ids()->Array[String]:
	var out:Array[String]=[]
	for source in stack_sources:
		out.append(str(source.source_actor_id))
	return out

func has_tag(tag:StringName)->bool:
	return tag in definition.semantic_tags or tag in dynamic_tags

func inject_tag(tag:StringName)->void:
	if tag!=&"" and tag not in dynamic_tags:
		dynamic_tags.append(tag)

func record_delta(key:StringName,value:float)->void:
	calculated_deltas[key]=value

func advance_turn()->void:
	if definition.duration_policy!=CombatEffectDefinition.DurationPolicy.TURN_BASED:
		return
	remaining_turns=maxi(0,remaining_turns-1)

func is_expired()->bool:
	if definition.duration_policy==CombatEffectDefinition.DurationPolicy.INSTANT:
		return true
	return remaining_turns<=0

func snapshot()->Dictionary:
	var tags:Array[String]=[]
	for tag in dynamic_tags:
		tags.append(str(tag))
	var made:Array[String]=[]
	for tag in created_tags:
		made.append(str(tag))
	var spent:Array[String]=[]
	for tag in consumed_tags:
		spent.append(str(tag))
	var cues:Array[String]=[]
	for cue in cue_ids:
		cues.append(str(cue))
	return {
		"definition_id":str(definition.id),
		"context":context.snapshot(),
		"level":level,
		"remaining_turns":remaining_turns,
		"stack_count":stack_count,
		"runtime_magnitudes":runtime_magnitudes.duplicate(true),
		"magnitude_sources":_magnitude_source_snapshot(),
		"stack_source_actor_ids":stack_source_actor_ids(),
		"dynamic_tags":tags,
		"calculated_deltas":calculated_deltas.duplicate(true),
		"created_tags":made,
		"consumed_tags":spent,
		"cue_ids":cues
	}


func _magnitude_source_snapshot()->Dictionary:
	var out:Dictionary={}
	for raw_key in magnitude_sources:
		var value=magnitude_sources[raw_key]
		if value is CombatEffectContext:
			out[str(raw_key)]=(value as CombatEffectContext).snapshot()
	return out
