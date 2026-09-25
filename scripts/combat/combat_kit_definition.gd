class_name CombatKitDefinition
extends RefCounted

var actor_id:StringName=&""
var skills:Array[CombatSkillDefinition]=[]
var passives:Array[CombatPassiveDefinition]=[]
var aura:CombatSkillDefinition

func validate(max_active_skills:int=3)->Array[String]:
	var errors:Array[String]=[]
	var ids:Dictionary={}
	var default_count:=0
	var active_count:=0
	for skill in skills:
		if skill==null:
			errors.append("kit contains null skill")
			continue
		for error in skill.validate():
			errors.append("%s: %s"%[str(skill.id),error])
		if ids.has(skill.id):
			errors.append("duplicate ability id: "+str(skill.id))
		ids[skill.id]=true
		if skill.kind==CombatSkillDefinition.SkillKind.DEFAULT:
			default_count+=1
		elif skill.kind==CombatSkillDefinition.SkillKind.ACTIVE:
			active_count+=1
		elif skill.kind==CombatSkillDefinition.SkillKind.AURA:
			errors.append("aura must use dedicated aura slot")
	for passive in passives:
		if passive==null:
			errors.append("kit contains null passive")
			continue
		for error in passive.validate():
			errors.append("%s: %s"%[str(passive.id),error])
		if ids.has(passive.id):
			errors.append("duplicate ability id: "+str(passive.id))
		ids[passive.id]=true
	if aura!=null:
		for error in aura.validate():
			errors.append("%s: %s"%[str(aura.id),error])
		if aura.kind!=CombatSkillDefinition.SkillKind.AURA:
			errors.append("dedicated aura slot must contain an aura")
		if ids.has(aura.id):
			errors.append("duplicate ability id: "+str(aura.id))
	if default_count!=1:
		errors.append("kit requires exactly one default attack")
	if active_count<0 or active_count>maxi(0,max_active_skills):
		errors.append("kit active skill count exceeds cap")
	return errors
