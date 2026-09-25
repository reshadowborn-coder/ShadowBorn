class_name CombatSkillDefinition
extends Resource

enum SkillKind {
	DEFAULT,
	ACTIVE,
	AURA
}

enum TargetRule {
	SELF,
	SINGLE_ENEMY,
	ALL_ENEMIES,
	SINGLE_ALLY,
	ALL_ALLIES
}

@export var id:StringName=&""
@export var display_name:String=""
@export var kind:SkillKind=SkillKind.DEFAULT
@export var target_rule:TargetRule=TargetRule.SINGLE_ENEMY
@export_range(1,999,1) var unlock_level:int=1
@export_range(0,99,1) var base_cooldown:int=0
@export var action_tags:Array[StringName]=[]
@export var base_values:Dictionary={}
@export var effect_steps:Array[Dictionary]=[]
@export var rank_patches:Array[Dictionary]=[]
@export var presentation_id:StringName=&""

# Auto-battle defaults. Player AI presets can override these priorities without
# mutating the skill definition.
@export_range(-999,999,1) var ai_base_priority:int=0
@export var ai_conditions:Array[Dictionary]=[]
@export var ai_target_selector:String="primary_target"

@export var aura_stat_modifiers:Dictionary={}
@export var aura_required_battle_tags:Array[StringName]=[]
@export var aura_blocked_battle_tags:Array[StringName]=[]
@export var aura_persists_after_owner_death:bool=true

func validate()->Array[String]:
	var errors:Array[String]=[]
	if id==&"":
		errors.append("skill id is empty")
	if display_name.strip_edges().is_empty():
		errors.append("skill display name is empty")
	if unlock_level<1:
		errors.append("unlock level must be positive")
	if kind==SkillKind.DEFAULT and base_cooldown!=0:
		errors.append("default skill cannot have a cooldown")
	if kind==SkillKind.AURA and base_cooldown!=0:
		errors.append("aura cannot have a cooldown")
	if kind==SkillKind.AURA and target_rule!=TargetRule.ALL_ALLIES:
		errors.append("team aura must target all allies")
	if ai_target_selector not in CombatAbilityOps.TARGETS:
		errors.append("skill AI target selector is invalid")
	errors.append_array(CombatAiCondition.validate_all(ai_conditions))
	errors.append_array(CombatAbilityOps.validate_steps(effect_steps))
	for patch_value in rank_patches:
		if typeof(patch_value)!=TYPE_DICTIONARY:
			errors.append("rank patch must be a dictionary")
			continue
		var patch:Dictionary=patch_value
		var rank:=int(patch.get("rank",0))
		var key:=str(patch.get("key",""))
		var op:=str(patch.get("op",""))
		var value=patch.get("value")
		if rank<1:
			errors.append("rank patch rank must be >= 1")
		if key.is_empty():
			errors.append("rank patch key is empty")
		if op not in ["add","multiply_bp","set","cooldown_delta","add_tag"]:
			errors.append("unsupported rank patch op: "+op)
		if op!="add_tag" and typeof(value) not in [TYPE_INT,TYPE_FLOAT,TYPE_BOOL,TYPE_STRING,TYPE_STRING_NAME]:
			errors.append("rank patch value has unsupported type")
	return errors

func create_spec(rank:int=0)->CombatSkillSpec:
	return CombatSkillSpec.new(self,rank)
