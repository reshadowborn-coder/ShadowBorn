class_name CombatAiInstruction
extends Resource

enum Priority {
	DEFAULT,
	DONT_USE,
	FIRST,
	SECOND,
	THIRD
}

@export var skill_id:StringName=&""
@export var priority:Priority=Priority.DEFAULT
@export var opener:bool=false
@export var conditions:Array[Dictionary]=[]
@export var target_selector:String=""

func validate()->Array[String]:
	var errors:Array[String]=[]
	if skill_id==&"":
		errors.append("AI instruction skill_id is empty")
	if not target_selector.is_empty() and target_selector not in CombatAbilityOps.TARGETS:
		errors.append("AI instruction target selector is invalid")
	errors.append_array(CombatAiCondition.validate_all(conditions))
	return errors
