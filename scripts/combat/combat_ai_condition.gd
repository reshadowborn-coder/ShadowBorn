class_name CombatAiCondition
extends RefCounted

const OPS=[
	"always",
	"self_hp_lte_bp",
	"ally_hp_lte_bp",
	"enemy_hp_lte_bp",
	"primary_target_hp_lte_bp",
	"enemy_count_gte",
	"ally_count_gte",
	"self_has_tag",
	"self_missing_tag",
	"ally_missing_tag",
	"enemy_has_tag",
	"enemy_missing_tag",
	"primary_target_has_tag",
	"primary_target_missing_tag",
	"enemy_turn_meter_gte_bp",
	"ally_debuff_count_gte",
	"enemy_buff_count_gte",
	"boss_only",
	"not_boss",
	"turn_gte"
]

static func validate_all(conditions:Array)->Array[String]:
	var errors:Array[String]=[]
	for i in range(conditions.size()):
		var raw=conditions[i]
		if typeof(raw)!=TYPE_DICTIONARY:
			errors.append("AI condition %d is not a dictionary"%i)
			continue
		for error in validate(raw as Dictionary):
			errors.append("AI condition %d: %s"%[i,error])
	return errors

static func validate(condition:Dictionary)->Array[String]:
	var errors:Array[String]=[]
	var op:=str(condition.get("op",""))
	if op not in OPS:
		errors.append("unsupported condition: "+op)
		return errors
	if op in ["self_hp_lte_bp","ally_hp_lte_bp","enemy_hp_lte_bp","primary_target_hp_lte_bp","enemy_turn_meter_gte_bp"]:
		var value:=int(condition.get("value_bp",-1))
		if value<0 or value>10000:
			errors.append(op+" value_bp must be 0..10000")
	elif op in ["enemy_count_gte","ally_count_gte","ally_debuff_count_gte","enemy_buff_count_gte","turn_gte"]:
		if int(condition.get("value",-1))<0:
			errors.append(op+" value must be non-negative")
	elif op in ["self_has_tag","self_missing_tag","ally_missing_tag","enemy_has_tag","enemy_missing_tag","primary_target_has_tag","primary_target_missing_tag"]:
		if str(condition.get("tag","")).is_empty():
			errors.append(op+" requires tag")
	return errors

static func evaluate_all(conditions:Array,state:Dictionary)->bool:
	for raw in conditions:
		if typeof(raw)!=TYPE_DICTIONARY or not evaluate(raw as Dictionary,state):
			return false
	return true

static func evaluate(condition:Dictionary,state:Dictionary)->bool:
	var op:=str(condition.get("op",""))
	match op:
		"always":
			return true
		"self_hp_lte_bp":
			return _hp_bp(state.get("self",{}))<=int(condition.get("value_bp",0))
		"ally_hp_lte_bp":
			return _any_hp_lte(_living(state.get("allies",[])),int(condition.get("value_bp",0)))
		"enemy_hp_lte_bp":
			return _any_hp_lte(_living(state.get("enemies",[])),int(condition.get("value_bp",0)))
		"primary_target_hp_lte_bp":
			return _hp_bp(_primary_target(state))<=int(condition.get("value_bp",0))
		"enemy_count_gte":
			return _living(state.get("enemies",[])).size()>=int(condition.get("value",0))
		"ally_count_gte":
			return _living(state.get("allies",[])).size()>=int(condition.get("value",0))
		"self_has_tag":
			return _has_tag(state.get("self",{}),StringName(str(condition.get("tag",""))))
		"self_missing_tag":
			return not _has_tag(state.get("self",{}),StringName(str(condition.get("tag",""))))
		"ally_missing_tag":
			return _any_missing_tag(_living(state.get("allies",[])),StringName(str(condition.get("tag",""))))
		"enemy_has_tag":
			return _any_has_tag(_living(state.get("enemies",[])),StringName(str(condition.get("tag",""))))
		"enemy_missing_tag":
			return _any_missing_tag(_living(state.get("enemies",[])),StringName(str(condition.get("tag",""))))
		"primary_target_has_tag":
			return _has_tag(_primary_target(state),StringName(str(condition.get("tag",""))))
		"primary_target_missing_tag":
			return not _has_tag(_primary_target(state),StringName(str(condition.get("tag",""))))
		"enemy_turn_meter_gte_bp":
			var threshold:=int(condition.get("value_bp",0))
			for actor in _living(state.get("enemies",[])):
				if int((actor as Dictionary).get("turn_meter_bp",0))>=threshold:
					return true
			return false
		"ally_debuff_count_gte":
			var minimum:=int(condition.get("value",0))
			for actor in _living(state.get("allies",[])):
				if int((actor as Dictionary).get("debuff_count",0))>=minimum:
					return true
			return false
		"enemy_buff_count_gte":
			var minimum:=int(condition.get("value",0))
			for actor in _living(state.get("enemies",[])):
				if int((actor as Dictionary).get("buff_count",0))>=minimum:
					return true
			return false
		"boss_only":
			return bool(state.get("is_boss",false))
		"not_boss":
			return not bool(state.get("is_boss",false))
		"turn_gte":
			return int(state.get("turn_index",0))>=int(condition.get("value",0))
	return false

static func _living(raw_actors)->Array:
	var out:Array=[]
	if typeof(raw_actors)!=TYPE_ARRAY:
		return out
	for raw in raw_actors:
		if typeof(raw)==TYPE_DICTIONARY and bool((raw as Dictionary).get("alive",true)):
			out.append(raw)
	return out

static func _hp_bp(raw_actor)->int:
	if typeof(raw_actor)!=TYPE_DICTIONARY:
		return 10000
	var actor:Dictionary=raw_actor
	var max_hp:=maxf(0.0001,float(actor.get("max_hp",1.0)))
	var hp:=clampf(float(actor.get("hp",max_hp)),0.0,max_hp)
	return clampi(int(round(hp/max_hp*10000.0)),0,10000)

static func _primary_target(state:Dictionary)->Dictionary:
	var id:=str(state.get("primary_target_id",""))
	for raw in _living(state.get("enemies",[])):
		var actor:Dictionary=raw
		if str(actor.get("id",""))==id:
			return actor
	return {}

static func _has_tag(raw_actor,tag:StringName)->bool:
	if typeof(raw_actor)!=TYPE_DICTIONARY or tag==&"":
		return false
	for raw_tag in (raw_actor as Dictionary).get("tags",[]):
		if StringName(str(raw_tag))==tag:
			return true
	return false

static func _any_hp_lte(actors:Array,threshold:int)->bool:
	for actor in actors:
		if _hp_bp(actor)<=threshold:
			return true
	return false

static func _any_has_tag(actors:Array,tag:StringName)->bool:
	for actor in actors:
		if _has_tag(actor,tag):
			return true
	return false

static func _any_missing_tag(actors:Array,tag:StringName)->bool:
	for actor in actors:
		if not _has_tag(actor,tag):
			return true
	return false
