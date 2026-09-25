class_name CombatBuildCompiler
extends RefCounted

static func compile(
	kit:CombatKitDefinition,
	talent_graph:CombatTalentGraph,
	talent_ranks:Dictionary
)->Dictionary:
	if kit==null:
		return {"ok":false,"errors":["missing kit"]}
	var errors:=kit.validate()
	if talent_graph!=null:
		errors.append_array(talent_graph.validate_graph())
	if not errors.is_empty():
		return {"ok":false,"errors":errors}

	var specs:Dictionary={}
	for skill in kit.skills:
		specs[str(skill.id)]=skill.create_spec(0)

	var stat_modifiers:Dictionary={}
	var granted_passive_ids:Array[StringName]=[]
	if talent_graph!=null:
		for talent in talent_graph.selected_definitions(talent_ranks):
			var rank:=clampi(int(talent_ranks.get(str(talent.id),0)),0,talent.max_rank)
			if rank<=0:
				continue
			for raw_key in talent.stat_modifiers:
				var key:=str(raw_key)
				var value=talent.stat_modifiers[raw_key]
				if typeof(value) not in [TYPE_INT,TYPE_FLOAT]:
					continue
				stat_modifiers[key]=float(stat_modifiers.get(key,0.0))+float(value)*float(rank)
			for passive_id in talent.granted_passive_ids:
				if passive_id not in granted_passive_ids:
					granted_passive_ids.append(passive_id)
			for patch_value in talent.skill_patches:
				if typeof(patch_value)!=TYPE_DICTIONARY:
					continue
				var patch:Dictionary=patch_value
				var skill_id:=str(patch.get("skill_id",""))
				var spec_value=specs.get(skill_id)
				if spec_value is CombatSkillSpec:
					for _i in range(rank):
						(spec_value as CombatSkillSpec).apply_external_patch(patch)

	return {
		"ok":true,
		"errors":[],
		"skill_specs":specs,
		"stat_modifiers":stat_modifiers,
		"granted_passive_ids":granted_passive_ids
	}
