class_name CombatAiPolicy
extends RefCounted

static func validate(kit:CombatKitDefinition,instructions:Array)->Array[String]:
	var errors:Array[String]=[]
	if kit==null:
		errors.append("AI policy requires a kit")
		return errors
	var skills:Dictionary={}
	for skill in kit.skills:
		if skill!=null:
			skills[str(skill.id)]=skill

	var seen_skills:Dictionary={}
	var priority_owner:Dictionary={}
	var opener_count:=0
	for raw_instruction in instructions:
		if not (raw_instruction is CombatAiInstruction):
			errors.append("AI policy contains an invalid instruction object")
			continue
		var instruction:CombatAiInstruction=raw_instruction
		errors.append_array(instruction.validate())
		var key:=str(instruction.skill_id)
		if seen_skills.has(key):
			errors.append("duplicate AI instruction for "+key)
		seen_skills[key]=true
		if not skills.has(key):
			errors.append("AI instruction references missing skill "+key)
			continue
		var skill:CombatSkillDefinition=skills[key]
		if skill.kind==CombatSkillDefinition.SkillKind.AURA:
			errors.append("AI instructions cannot target aura slot")
		if skill.kind==CombatSkillDefinition.SkillKind.DEFAULT and instruction.priority!=CombatAiInstruction.Priority.DEFAULT:
			errors.append("default attack priority is implicit; only Opener may override it")
		if instruction.opener:
			opener_count+=1
		if instruction.priority in [CombatAiInstruction.Priority.FIRST,CombatAiInstruction.Priority.SECOND,CombatAiInstruction.Priority.THIRD]:
			var pkey:=str(int(instruction.priority))
			if priority_owner.has(pkey):
				errors.append("AI priority slot is already assigned")
			priority_owner[pkey]=key
	if opener_count>1:
		errors.append("AI policy allows only one opener per actor")
	return errors

static func choose_action(
	skill_specs:Dictionary,
	instructions:Array,
	state:Dictionary,
	actor_turn_count:int,
	active_skills_blocked:bool=false
)->Dictionary:
	var instruction_map:=_instruction_map(instructions)

	if actor_turn_count<=0:
		for raw_instruction in instructions:
			if raw_instruction is CombatAiInstruction:
				var opener:CombatAiInstruction=raw_instruction
				if not opener.opener:
					continue
				var opener_spec_value=skill_specs.get(str(opener.skill_id))
				if opener_spec_value is CombatSkillSpec:
					var opener_spec:CombatSkillSpec=opener_spec_value
					if _usable(opener_spec,opener,state,active_skills_blocked,true):
						return _choice(opener_spec,opener,"opener")

	for priority in [CombatAiInstruction.Priority.FIRST,CombatAiInstruction.Priority.SECOND,CombatAiInstruction.Priority.THIRD]:
		for raw_instruction in instructions:
			if not (raw_instruction is CombatAiInstruction):
				continue
			var instruction:CombatAiInstruction=raw_instruction
			if instruction.priority!=priority:
				continue
			var spec_value=skill_specs.get(str(instruction.skill_id))
			if spec_value is CombatSkillSpec:
				var spec:CombatSkillSpec=spec_value
				if _usable(spec,instruction,state,active_skills_blocked,false):
					return _choice(spec,instruction,"priority_%d"%int(priority-CombatAiInstruction.Priority.FIRST+1))

	var candidates:Array[CombatSkillSpec]=[]
	var default_spec:CombatSkillSpec=null
	for raw_key in skill_specs:
		var spec_value=skill_specs[raw_key]
		if not (spec_value is CombatSkillSpec):
			continue
		var spec:CombatSkillSpec=spec_value
		if spec.definition.kind==CombatSkillDefinition.SkillKind.DEFAULT:
			default_spec=spec
			continue
		if spec.definition.kind!=CombatSkillDefinition.SkillKind.ACTIVE:
			continue
		var instruction:CombatAiInstruction=instruction_map.get(str(spec.definition.id)) as CombatAiInstruction
		if instruction!=null and instruction.priority==CombatAiInstruction.Priority.DONT_USE:
			continue
		if _usable(spec,instruction,state,active_skills_blocked,false):
			candidates.append(spec)

	candidates.sort_custom(func(a:CombatSkillSpec,b:CombatSkillSpec)->bool:
		if a.definition.ai_base_priority!=b.definition.ai_base_priority:
			return a.definition.ai_base_priority>b.definition.ai_base_priority
		return str(a.definition.id)<str(b.definition.id)
	)
	if not candidates.is_empty():
		var selected:CombatSkillSpec=candidates[0]
		var selected_instruction:CombatAiInstruction=instruction_map.get(str(selected.definition.id)) as CombatAiInstruction
		return _choice(selected,selected_instruction,"default_ai")

	if default_spec!=null:
		var default_instruction:CombatAiInstruction=instruction_map.get(str(default_spec.definition.id)) as CombatAiInstruction
		if _usable(default_spec,default_instruction,state,false,false):
			return _choice(default_spec,default_instruction,"default_fallback")
	return {"skill_id":"","target_selector":"","reason":"no_action"}

static func _usable(
	spec:CombatSkillSpec,
	instruction:CombatAiInstruction,
	state:Dictionary,
	active_skills_blocked:bool,
	opener_override:bool
)->bool:
	if spec==null or not spec.is_ready():
		return false
	var definition:=spec.definition
	if int(state.get("actor_level",999))<definition.unlock_level:
		return false
	if definition.kind==CombatSkillDefinition.SkillKind.AURA:
		return false
	if active_skills_blocked and definition.kind==CombatSkillDefinition.SkillKind.ACTIVE:
		return false
	if instruction!=null and instruction.priority==CombatAiInstruction.Priority.DONT_USE and not opener_override:
		return false
	if not CombatAiCondition.evaluate_all(definition.ai_conditions,state):
		return false
	if instruction!=null and not CombatAiCondition.evaluate_all(instruction.conditions,state):
		return false
	return true

static func _choice(spec:CombatSkillSpec,instruction:CombatAiInstruction,reason:String)->Dictionary:
	var selector:=spec.definition.ai_target_selector
	if instruction!=null and not instruction.target_selector.is_empty():
		selector=instruction.target_selector
	return {
		"skill_id":str(spec.definition.id),
		"target_selector":selector,
		"reason":reason
	}

static func _instruction_map(instructions:Array)->Dictionary:
	var out:Dictionary={}
	for raw_instruction in instructions:
		if raw_instruction is CombatAiInstruction:
			var instruction:CombatAiInstruction=raw_instruction
			out[str(instruction.skill_id)]=instruction
	return out
