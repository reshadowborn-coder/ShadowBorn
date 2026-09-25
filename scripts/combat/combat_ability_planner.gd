class_name CombatAbilityPlanner
extends RefCounted

static func build(steps:Array,context:Dictionary)->Dictionary:
	var errors:=CombatAbilityOps.validate_steps(steps)
	if not errors.is_empty():
		return {"ok":false,"errors":errors,"operations":[]}
	var operations:Array[Dictionary]=[]
	for step_index in range(steps.size()):
		var step:Dictionary=steps[step_index]
		var targets:=CombatTargetResolver.resolve(str(step.get("target","")),context)
		for target_id in targets:
			var scoped:=context.duplicate(true)
			scoped["primary_target_id"]=str(target_id)
			var conditions:Array=step.get("conditions",[])
			if not conditions.is_empty() and not CombatConditionEvaluator.evaluate_all(conditions,scoped):
				continue
			var operation:=step.duplicate(true)
			operation.erase("conditions")
			operation["step_index"]=step_index
			operation["source_actor_id"]=str(context.get("self_id",""))
			operation["target_actor_id"]=str(target_id)
			operations.append(operation)
	return {"ok":true,"errors":[],"operations":operations}

static func operation_count(plan:Dictionary,op:String="")->int:
	var count:=0
	for value in plan.get("operations",[]):
		var operation:Dictionary=value
		if op.is_empty() or str(operation.get("op",""))==op:
			count+=1
	return count
