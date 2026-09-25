class_name CombatSkillSpec
extends RefCounted

const BASIS_POINTS:=10000

var definition:CombatSkillDefinition
var rank:int=0
var cooldown_remaining:int=0
var runtime_values:Dictionary={}
var dynamic_tags:Array[StringName]=[]

func _init(in_definition:CombatSkillDefinition,in_rank:int=0)->void:
	assert(in_definition!=null,"CombatSkillSpec requires a definition")
	definition=in_definition
	runtime_values=definition.base_values.duplicate(true)
	for tag in definition.action_tags:
		dynamic_tags.append(tag)
	set_rank(in_rank)

func set_rank(value:int)->void:
	rank=maxi(0,value)
	runtime_values=definition.base_values.duplicate(true)
	dynamic_tags.clear()
	for tag in definition.action_tags:
		dynamic_tags.append(tag)
	for patch_value in definition.rank_patches:
		if typeof(patch_value)!=TYPE_DICTIONARY:
			continue
		var patch:Dictionary=patch_value
		if int(patch.get("rank",0))>rank:
			continue
		_apply_patch(patch)
	cooldown_remaining=clampi(cooldown_remaining,0,cooldown_max())

func cooldown_max()->int:
	var delta:=int(runtime_values.get("_cooldown_delta",0))
	return maxi(0,definition.base_cooldown+delta)

func is_ready()->bool:
	return cooldown_remaining<=0

func commit_use()->bool:
	if definition.kind==CombatSkillDefinition.SkillKind.AURA or not is_ready():
		return false
	if definition.kind==CombatSkillDefinition.SkillKind.ACTIVE:
		cooldown_remaining=cooldown_max()
	return true

func advance_actionable_owner_turn()->void:
	if cooldown_remaining>0:
		cooldown_remaining-=1

func has_tag(tag:StringName)->bool:
	return tag in dynamic_tags

func apply_external_patch(patch:Dictionary)->bool:
	var op:=str(patch.get("op",""))
	if op not in ["add","multiply_bp","set","cooldown_delta","add_tag"]:
		return false
	var key:=str(patch.get("key",""))
	if op in ["add","multiply_bp","set"] and (key.is_empty() or not runtime_values.has(key)):
		return false
	if op=="add_tag" and str(patch.get("value","")).is_empty():
		return false
	_apply_patch(patch)
	cooldown_remaining=clampi(cooldown_remaining,0,cooldown_max())
	return true

func snapshot()->Dictionary:
	var tags:Array[String]=[]
	for tag in dynamic_tags:
		tags.append(str(tag))
	return {
		"definition_id":str(definition.id),
		"rank":rank,
		"cooldown_remaining":cooldown_remaining,
		"cooldown_max":cooldown_max(),
		"runtime_values":runtime_values.duplicate(true),
		"tags":tags
	}

func _apply_patch(patch:Dictionary)->void:
	var op:=str(patch.get("op",""))
	var key:=str(patch.get("key",""))
	var value=patch.get("value")
	match op:
		"add":
			var current:=_number(runtime_values.get(key,0.0))
			runtime_values[key]=current+_number(value)
		"multiply_bp":
			var current:=_number(runtime_values.get(key,0.0))
			runtime_values[key]=current*float(int(value))/float(BASIS_POINTS)
		"set":
			runtime_values[key]=value
		"cooldown_delta":
			runtime_values["_cooldown_delta"]=int(runtime_values.get("_cooldown_delta",0))+int(value)
		"add_tag":
			var tag:=StringName(str(value))
			if tag!=&"" and tag not in dynamic_tags:
				dynamic_tags.append(tag)

static func _number(value)->float:
	if typeof(value) not in [TYPE_INT,TYPE_FLOAT]:
		return 0.0
	var number:=float(value)
	return number if number==number and not is_inf(number) else 0.0
