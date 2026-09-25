class_name CombatPassiveRuntime
extends RefCounted

const BLOCK_PASSIVES_TAG:=&"Status.BlockPassiveSkills"

var _teams:Dictionary={}
var _definitions:Dictionary={}
var _state:Dictionary={}
var _blocked_actors:Dictionary={}

func register_actor(actor_id:StringName,team:StringName)->bool:
	if actor_id==&"" or team==&"":
		return false
	_teams[actor_id]=team
	if not _definitions.has(actor_id):
		_definitions[actor_id]=[]
	return true

func register_passive(actor_id:StringName,definition:CombatPassiveDefinition)->bool:
	if definition==null or not _teams.has(actor_id) or not definition.validate().is_empty():
		return false
	var entries:Array=_definitions.get(actor_id,[])
	for existing_value in entries:
		var existing:CombatPassiveDefinition=existing_value
		if existing.id==definition.id:
			return false
	entries.append(definition)
	_definitions[actor_id]=entries
	_state[_key(actor_id,definition.id)]={
		"used_battle":false,
		"last_turn_serial":-1,
		"cooldown_owner_turns":0
	}
	return true

func set_passives_blocked(actor_id:StringName,value:bool)->void:
	if value:
		_blocked_actors[actor_id]=true
	else:
		_blocked_actors.erase(actor_id)

func advance_owner_turn(actor_id:StringName)->void:
	for definition_value in _definitions.get(actor_id,[]):
		var definition:CombatPassiveDefinition=definition_value
		var key:=_key(actor_id,definition.id)
		var state:Dictionary=_state.get(key,{})
		var cooldown:=maxi(0,int(state.get("cooldown_owner_turns",0))-1)
		state["cooldown_owner_turns"]=cooldown
		_state[key]=state

func collect_reactions(event:CombatTriggerEvent)->Array[Dictionary]:
	var out:Array[Dictionary]=[]
	if event==null or event.event_type==&"":
		return out
	for raw_actor_id in _definitions:
		var owner_id:=StringName(raw_actor_id)
		var owner_team:=StringName(_teams.get(owner_id,&""))
		for definition_value in _definitions[owner_id]:
			var definition:CombatPassiveDefinition=definition_value
			if not _eligible(owner_id,owner_team,definition,event):
				continue
			var key:=_key(owner_id,definition.id)
			var state:Dictionary=_state[key]
			state["used_battle"]=true
			state["last_turn_serial"]=event.turn_serial
			state["cooldown_owner_turns"]=definition.internal_cooldown_owner_turns
			_state[key]=state
			out.append({
				"actor_id":owner_id,
				"passive_id":definition.id,
				"reaction_kind":definition.reaction_kind,
				"priority":definition.priority,
				"proc_chance_bp":definition.proc_chance_bp,
				"source_turn_serial":event.turn_serial,
				"chain_depth":event.chain_depth+1,
				"effect_steps":definition.effect_steps.duplicate(true)
			})
	out.sort_custom(func(a:Dictionary,b:Dictionary)->bool:
		var pa:=int(a.get("priority",0))
		var pb:=int(b.get("priority",0))
		if pa!=pb:
			return pa>pb
		var aa:=str(a.get("actor_id",""))
		var ab:=str(b.get("actor_id",""))
		if aa!=ab:
			return aa<ab
		return str(a.get("passive_id",""))<str(b.get("passive_id",""))
	)
	return out

func state_snapshot()->Dictionary:
	return _state.duplicate(true)

func _eligible(
	owner_id:StringName,
	owner_team:StringName,
	definition:CombatPassiveDefinition,
	event:CombatTriggerEvent
)->bool:
	if definition.trigger_event!=event.event_type:
		return false
	if bool(_blocked_actors.get(owner_id,false)) and not definition.unblockable:
		return false
	var state:Dictionary=_state.get(_key(owner_id,definition.id),{})
	if definition.once_per_battle and bool(state.get("used_battle",false)):
		return false
	if definition.once_per_turn and event.turn_serial>0 and int(state.get("last_turn_serial",-1))==event.turn_serial:
		return false
	if int(state.get("cooldown_owner_turns",0))>0:
		return false
	for tag in definition.required_event_tags:
		if not event.has_tag(tag):
			return false
	for tag in definition.blocked_event_tags:
		if event.has_tag(tag):
			return false
	return _relation_matches(owner_id,owner_team,definition.owner_relation,event)

static func _relation_matches(
	owner_id:StringName,
	owner_team:StringName,
	relation:CombatPassiveDefinition.OwnerRelation,
	event:CombatTriggerEvent
)->bool:
	match relation:
		CombatPassiveDefinition.OwnerRelation.ANY:
			return true
		CombatPassiveDefinition.OwnerRelation.SELF_SOURCE:
			return event.source_actor_id==owner_id
		CombatPassiveDefinition.OwnerRelation.SELF_TARGET:
			return event.target_actor_id==owner_id
		CombatPassiveDefinition.OwnerRelation.ALLY_SOURCE:
			return event.source_actor_id!=owner_id and event.source_team==owner_team and owner_team!=&""
		CombatPassiveDefinition.OwnerRelation.ALLY_TARGET:
			return event.target_actor_id!=owner_id and event.target_team==owner_team and owner_team!=&""
		CombatPassiveDefinition.OwnerRelation.ENEMY_SOURCE:
			return event.source_team!=&"" and owner_team!=&"" and event.source_team!=owner_team
		CombatPassiveDefinition.OwnerRelation.ENEMY_TARGET:
			return event.target_team!=&"" and owner_team!=&"" and event.target_team!=owner_team
	return false

static func _key(actor_id:StringName,passive_id:StringName)->String:
	return str(actor_id)+"|"+str(passive_id)
