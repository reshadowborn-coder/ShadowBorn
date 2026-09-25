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
	if spent_points_in_branch(ranks,definition.branch,definition.id)<definition.required_branch_points_before:
		return {"ok":false,"reason":"branch_points"}
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

func validate_ranks(
	ranks:Dictionary,
	actor_level:int=999,
	point_budget:int=-1,
	max_active_branches:int=DEFAULT_MAX_ACTIVE_BRANCHES
)->Array[String]:
	var errors:Array[String]=[]
	var selected_by_exclusive:Dictionary={}
	for raw_key in ranks:
		var id:=StringName(str(raw_key))
		var raw_rank=ranks[raw_key]
		if typeof(raw_rank) not in [TYPE_INT,TYPE_FLOAT]:
			errors.append("talent rank is not numeric: "+str(id))
			continue
		var rank_float:=float(raw_rank)
		if rank_float!=floor(rank_float):
			errors.append("talent rank is fractional: "+str(id))
			continue
		var rank:=int(rank_float)
		if rank==0:
			continue
		if not _definitions.has(id):
			errors.append("unknown selected talent: "+str(id))
			continue
		var definition:CombatTalentDefinition=_definitions[id]
		if rank<0 or rank>definition.max_rank:
			errors.append("talent rank outside authored bounds: "+str(id))
			continue
		if actor_level<definition.min_level:
			errors.append("talent selected below level gate: "+str(id))
		for prereq in definition.prerequisite_ids:
			if int(ranks.get(str(prereq),0))<=0:
				errors.append("%s missing prerequisite %s"%[str(id),str(prereq)])
		if spent_points_in_branch(ranks,definition.branch,definition.id)<definition.required_branch_points_before:
			errors.append("talent selected before branch point gate: "+str(id))
		if definition.exclusive_group!=&"":
			var chosen:Array=selected_by_exclusive.get(definition.exclusive_group,[])
			chosen.append(id)
			selected_by_exclusive[definition.exclusive_group]=chosen
	for raw_group in selected_by_exclusive:
		if (selected_by_exclusive[raw_group] as Array).size()>1:
			errors.append("mutually exclusive talents selected together: "+str(raw_group))
	if active_branches(ranks).size()>maxi(1,max_active_branches):
		errors.append("talent selection exceeds active branch cap")
	if point_budget>=0 and total_spent_points(ranks)>point_budget:
		errors.append("talent selection exceeds point budget")
	return errors

func spent_points_in_branch(ranks:Dictionary,branch:StringName,exclude_id:StringName=&"")->int:
	var total:=0
	for raw_id in _definitions:
		var definition:CombatTalentDefinition=_definitions[raw_id]
		if definition.branch!=branch or definition.id==exclude_id:
			continue
		var rank:=clampi(int(ranks.get(str(definition.id),0)),0,definition.max_rank)
		total+=rank*definition.point_cost_per_rank
	return total

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
