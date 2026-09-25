class_name CombatAuraRuntime
extends RefCounted

var _teams:Dictionary={}
var _alive:Dictionary={}
var _team_auras:Dictionary={}

func register_actor(actor_id:StringName,team:StringName,alive:bool=true)->bool:
	if actor_id==&"" or team==&"":
		return false
	_teams[actor_id]=team
	_alive[actor_id]=alive
	return true

func set_alive(actor_id:StringName,value:bool)->bool:
	if not _teams.has(actor_id):
		return false
	_alive[actor_id]=value
	return true

func activate_team_aura(
	team:StringName,
	owner_id:StringName,
	aura:CombatSkillDefinition
)->bool:
	if team==&"" or owner_id==&"" or aura==null:
		return false
	if StringName(_teams.get(owner_id,&""))!=team:
		return false
	if aura.kind!=CombatSkillDefinition.SkillKind.AURA:
		return false
	if not aura.validate().is_empty():
		return false
	_team_auras[team]={
		"owner_id":owner_id,
		"aura":aura
	}
	return true

func clear_team_aura(team:StringName)->void:
	_team_auras.erase(team)

func modifiers_for(actor_id:StringName,battle_tags:Array[StringName]=[])->Dictionary:
	var team:=StringName(_teams.get(actor_id,&""))
	if team==&"" or not _team_auras.has(team):
		return {}
	var record:Dictionary=_team_auras[team]
	var owner_id:=StringName(record.get("owner_id",&""))
	var aura_value=record.get("aura")
	if not (aura_value is CombatSkillDefinition):
		return {}
	var aura:CombatSkillDefinition=aura_value
	if not aura.aura_persists_after_owner_death and not bool(_alive.get(owner_id,false)):
		return {}
	for tag in aura.aura_required_battle_tags:
		if tag not in battle_tags:
			return {}
	for tag in aura.aura_blocked_battle_tags:
		if tag in battle_tags:
			return {}
	return aura.aura_stat_modifiers.duplicate(true)

func snapshot()->Dictionary:
	var out:Dictionary={}
	for raw_team in _team_auras:
		var team:=StringName(raw_team)
		var record:Dictionary=_team_auras[team]
		var aura_value=record.get("aura")
		if aura_value is CombatSkillDefinition:
			var aura:CombatSkillDefinition=aura_value
			out[str(team)]={
				"owner_id":str(record.get("owner_id","")),
				"aura_id":str(aura.id),
				"persists_after_owner_death":aura.aura_persists_after_owner_death
			}
	return out
