class_name CombatSkillbookRuntime
extends RefCounted

var actor_id:StringName=&""
var actor_level:int=1
var _slots:Dictionary={}
var _specs:Dictionary={}
var _definitions:Dictionary={}

func configure(kit:CombatKitDefinition,level:int,skill_ranks:Dictionary={})->Array[String]:
	clear()
	var errors:Array[String]=[]
	if kit==null:
		errors.append("missing kit")
		return errors
	errors.append_array(kit.validate())
	if not errors.is_empty():
		return errors
	actor_id=kit.actor_id
	actor_level=maxi(1,level)

	var default_skill:CombatSkillDefinition=null
	var active_skills:Array[CombatSkillDefinition]=[]
	for skill in kit.skills:
		if skill.kind==CombatSkillDefinition.SkillKind.DEFAULT:
			default_skill=skill
		elif skill.kind==CombatSkillDefinition.SkillKind.ACTIVE:
			active_skills.append(skill)

	if default_skill==null:
		errors.append("skillbook requires a default skill")
		return errors

	_register_slot(&"A1",default_skill,skill_ranks,errors)
	for i in range(active_skills.size()):
		_register_slot(StringName("A%d"%(i+2)),active_skills[i],skill_ranks,errors)
	return errors

func clear()->void:
	actor_id=&""
	actor_level=1
	_slots.clear()
	_specs.clear()
	_definitions.clear()

func has_slot(slot_id:StringName)->bool:
	return _slots.has(slot_id)

func definition_for_slot(slot_id:StringName)->CombatSkillDefinition:
	var skill_id:=StringName(_slots.get(slot_id,&""))
	return _definitions.get(skill_id) as CombatSkillDefinition

func spec_for_slot(slot_id:StringName)->CombatSkillSpec:
	var skill_id:=StringName(_slots.get(slot_id,&""))
	return _specs.get(skill_id) as CombatSkillSpec

func activation_state(slot_id:StringName,active_skills_blocked:bool=false,default_only:bool=false)->Dictionary:
	var definition:=definition_for_slot(slot_id)
	var spec:=spec_for_slot(slot_id)
	if definition==null or spec==null:
		return {"ok":false,"reason":"missing"}
	if actor_level<definition.unlock_level:
		return {"ok":false,"reason":"locked"}
	if default_only and definition.kind!=CombatSkillDefinition.SkillKind.DEFAULT:
		return {"ok":false,"reason":"default_only"}
	if active_skills_blocked and definition.kind==CombatSkillDefinition.SkillKind.ACTIVE:
		return {"ok":false,"reason":"active_blocked"}
	if not spec.is_ready():
		return {"ok":false,"reason":"cooldown","cooldown":spec.cooldown_remaining}
	return {"ok":true,"reason":""}

func can_use(slot_id:StringName,active_skills_blocked:bool=false,default_only:bool=false)->bool:
	return bool(activation_state(slot_id,active_skills_blocked,default_only).get("ok",false))

func commit_use(slot_id:StringName,active_skills_blocked:bool=false,default_only:bool=false)->bool:
	if not can_use(slot_id,active_skills_blocked,default_only):
		return false
	var spec:=spec_for_slot(slot_id)
	return spec!=null and spec.commit_use()

func advance_actionable_owner_turn()->void:
	for raw_id in _specs:
		var spec:CombatSkillSpec=_specs[raw_id]
		spec.advance_actionable_owner_turn()

func cooldown_remaining(slot_id:StringName)->int:
	var spec:=spec_for_slot(slot_id)
	return 0 if spec==null else spec.cooldown_remaining

func runtime_value(slot_id:StringName,key:String,default_value=0.0):
	var spec:=spec_for_slot(slot_id)
	return default_value if spec==null else spec.runtime_values.get(key,default_value)

func snapshot()->Dictionary:
	var slots_out:Dictionary={}
	for raw_slot in _slots:
		var slot:=StringName(raw_slot)
		var spec:=spec_for_slot(slot)
		var definition:=definition_for_slot(slot)
		if spec!=null and definition!=null:
			slots_out[str(slot)]={"skill_id":str(definition.id),"unlocked":actor_level>=definition.unlock_level,"spec":spec.snapshot()}
	return {"actor_id":str(actor_id),"actor_level":actor_level,"slots":slots_out}

func _register_slot(slot_id:StringName,skill:CombatSkillDefinition,skill_ranks:Dictionary,errors:Array[String])->void:
	var raw_rank=skill_ranks.get(str(skill.id),0)
	if typeof(raw_rank) not in [TYPE_INT,TYPE_FLOAT]:
		errors.append("skill rank is not numeric: "+str(skill.id))
		return
	var rank_float:=float(raw_rank)
	if rank_float!=floor(rank_float) or rank_float<0.0:
		errors.append("skill rank is invalid: "+str(skill.id))
		return
	var max_rank:=_max_authored_rank(skill)
	var requested_rank:=int(rank_float)
	if requested_rank>max_rank:
		errors.append("skill rank exceeds authored maximum: "+str(skill.id))
		return
	var spec:=skill.create_spec(requested_rank)
	_slots[slot_id]=skill.id
	_specs[skill.id]=spec
	_definitions[skill.id]=skill

static func _max_authored_rank(skill:CombatSkillDefinition)->int:
	var highest:=0
	for patch_value in skill.rank_patches:
		if typeof(patch_value)==TYPE_DICTIONARY:
			highest=maxi(highest,int((patch_value as Dictionary).get("rank",0)))
	return highest
