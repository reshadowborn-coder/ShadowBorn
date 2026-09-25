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
			var operation:=step.duplicate(true)
			operation["step_index"]=step_index
			operation["source_actor_id"]=str(context.get("self_id",""))
			operation["target_actor_id"]=str(target_id)
			operation["preview_condition_passed"]=operation_conditions_pass(operation,context)
			operations.append(operation)
	return {"ok":true,"errors":[],"operations":operations}

static func operation_count(plan:Dictionary,op:String="")->int:
	var count:=0
	for value in plan.get("operations",[]):
		var operation:Dictionary=value
		if op.is_empty() or str(operation.get("op",""))==op:
			count+=1
	return count


static func operation_conditions_pass(operation:Dictionary,context:Dictionary)->bool:
	var conditions:Array=operation.get("conditions",[])
	if conditions.is_empty():
		return true
	var scoped:=context.duplicate(true)
	scoped["primary_target_id"]=str(operation.get("target_actor_id",""))
	return CombatConditionEvaluator.evaluate_all(conditions,scoped)

static func preview_operation_count(plan:Dictionary,op:String="")->int:
	var count:=0
	for value in plan.get("operations",[]):
		var operation:Dictionary=value
		if not bool(operation.get("preview_condition_passed",true)):
			continue
		if op.is_empty() or str(operation.get("op",""))==op:
			count+=1
	return count
