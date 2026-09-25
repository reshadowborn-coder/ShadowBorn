class_name CombatTalentGraph
extends RefCounted

const DEFAULT_MAX_ACTIVE_BRANCHES:=2

var _definitions:Dictionary={}

func add_definition(definition:CombatTalentDefinition)->bool:
	if definition==null or not definition.validate().is_empty() or _definitions.has(definition.id):
		return false
	_definitions[definition.id]=definition
	return true

func definition(id:StringName)->CombatTalentDefinition:
	return _definitions.get(id) as CombatTalentDefinition

func validate_graph()->Array[String]:
	var errors:Array[String]=[]
	for raw_id in _definitions:
		var id:=StringName(raw_id)
		var definition_value=_definitions[id]
		if not (definition_value is CombatTalentDefinition):
			errors.append("invalid talent definition object: "+str(id))
			continue
		var definition:CombatTalentDefinition=definition_value
		for prereq in definition.prerequisite_ids:
			if not _definitions.has(prereq):
				errors.append("%s requires missing talent %s"%[str(id),str(prereq)])
		if _has_cycle_from(id,{},{}):
			errors.append("talent prerequisite cycle includes "+str(id))
	return errors

func can_purchase(
	ranks:Dictionary,
	talent_id:StringName,
	actor_level:int,
	available_points:int,
	max_active_branches:int=DEFAULT_MAX_ACTIVE_BRANCHES
)->Dictionary:
	if not _definitions.has(talent_id):
		return {"ok":false,"reason":"missing"}
	var definition:CombatTalentDefinition=_definitions[talent_id]
	var current_rank:=int(ranks.get(str(talent_id),0))
	if current_rank>=definition.max_rank:
		return {"ok":false,"reason":"max_rank"}
	if actor_level<definition.min_level:
		return {"ok":false,"reason":"level"}
	if available_points<definition.point_cost_per_rank:
		return {"ok":false,"reason":"points"}
	for prereq in definition.prerequisite_ids:
		if int(ranks.get(str(prereq),0))<=0:
			return {"ok":false,"reason":"prerequisite"}
	if definition.exclusive_group!=&"":
		for raw_id in _definitions:
			var other:CombatTalentDefinition=_definitions[raw_id]
			if other.id==definition.id or other.exclusive_group!=definition.exclusive_group:
				continue
			if int(ranks.get(str(other.id),0))>0:
				return {"ok":false,"reason":"exclusive"}
	var branches:=active_branches(ranks)
	if definition.branch not in branches and branches.size()>=maxi(1,max_active_branches):
		return {"ok":false,"reason":"branch_limit"}
	return {"ok":true,"reason":""}

func active_branches(ranks:Dictionary)->Array[StringName]:
	var branches:Array[StringName]=[]
	for raw_id in _definitions:
		var definition:CombatTalentDefinition=_definitions[raw_id]
		if int(ranks.get(str(definition.id),0))>0 and definition.branch not in branches:
			branches.append(definition.branch)
	branches.sort_custom(func(a:StringName,b:StringName)->bool:return str(a)<str(b))
	return branches

func selected_definitions(ranks:Dictionary)->Array[CombatTalentDefinition]:
	var out:Array[CombatTalentDefinition]=[]
	for raw_id in _definitions:
		var definition:CombatTalentDefinition=_definitions[raw_id]
		if int(ranks.get(str(definition.id),0))>0:
			out.append(definition)
	out.sort_custom(func(a:CombatTalentDefinition,b:CombatTalentDefinition)->bool:
		if a.tier!=b.tier:
			return a.tier<b.tier
		return str(a.id)<str(b.id)
	)
	return out

func total_spent_points(ranks:Dictionary)->int:
	var total:=0
	for raw_id in _definitions:
		var definition:CombatTalentDefinition=_definitions[raw_id]
		total+=clampi(int(ranks.get(str(definition.id),0)),0,definition.max_rank)*definition.point_cost_per_rank
	return total

func _has_cycle_from(id:StringName,visiting:Dictionary,visited:Dictionary)->bool:
	if bool(visiting.get(id,false)):
		return true
	if bool(visited.get(id,false)):
		return false
	visiting[id]=true
	var definition_value=_definitions.get(id)
	if definition_value is CombatTalentDefinition:
		var definition:CombatTalentDefinition=definition_value
		for prereq in definition.prerequisite_ids:
			if _definitions.has(prereq) and _has_cycle_from(prereq,visiting,visited):
				return true
	visiting.erase(id)
	visited[id]=true
	return false
