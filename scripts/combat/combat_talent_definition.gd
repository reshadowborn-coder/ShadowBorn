class_name CombatTalentDefinition
extends Resource

@export var id:StringName=&""
@export var display_name:String=""
@export var branch:StringName=&""
@export_range(1,99,1) var tier:int=1
@export_range(1,99,1) var min_level:int=1
@export_range(1,10,1) var max_rank:int=1
@export_range(0,99,1) var point_cost_per_rank:int=1
@export var prerequisite_ids:Array[StringName]=[]
@export var exclusive_group:StringName=&""
@export var stat_modifiers:Dictionary={}
@export var skill_patches:Array[Dictionary]=[]
@export var granted_passive_ids:Array[StringName]=[]

func validate()->Array[String]:
	var errors:Array[String]=[]
	if id==&"":
		errors.append("talent id is empty")
	if display_name.strip_edges().is_empty():
		errors.append("talent display name is empty")
	if branch==&"":
		errors.append("talent branch is empty")
	if tier<1 or min_level<1 or max_rank<1 or point_cost_per_rank<0:
		errors.append("talent progression values are invalid")
	if id in prerequisite_ids:
		errors.append("talent cannot require itself")
	return errors
