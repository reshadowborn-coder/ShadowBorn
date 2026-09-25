class_name CombatPassiveDefinition
extends Resource

enum OwnerRelation {
	ANY,
	SELF_SOURCE,
	SELF_TARGET,
	ALLY_SOURCE,
	ALLY_TARGET,
	ENEMY_SOURCE,
	ENEMY_TARGET
}

@export var id:StringName=&""
@export var display_name:String=""
@export_range(1,999,1) var unlock_level:int=1
@export var trigger_event:StringName=&""
@export var owner_relation:OwnerRelation=OwnerRelation.ANY
@export_range(-999,999,1) var priority:int=0
@export var reaction_kind:StringName=CombatReactionQueue.KIND_FOLLOW_UP
@export var once_per_action:bool=false
@export var once_per_turn:bool=false
@export var once_per_battle:bool=false
@export var allow_reaction_trigger:bool=false
@export_range(0,99,1) var internal_cooldown_owner_turns:int=0
@export_range(0,10000,1) var proc_chance_bp:int=10000
@export var unblockable:bool=false
@export var required_event_tags:Array[StringName]=[]
@export var blocked_event_tags:Array[StringName]=[]
@export var effect_steps:Array[Dictionary]=[]

func validate()->Array[String]:
	var errors:Array[String]=[]
	if id==&"":
		errors.append("passive id is empty")
	if display_name.strip_edges().is_empty():
		errors.append("passive display name is empty")
	if trigger_event==&"" or trigger_event not in CombatEventTypes.all():
		errors.append("passive trigger event is invalid")
	if reaction_kind not in [
		CombatReactionQueue.KIND_COUNTER,
		CombatReactionQueue.KIND_ASSIST,
		CombatReactionQueue.KIND_FOLLOW_UP,
		CombatReactionQueue.KIND_INTERRUPT
	]:
		errors.append("passive reaction kind is invalid")
	if proc_chance_bp<0 or proc_chance_bp>10000:
		errors.append("passive proc chance is outside basis-point range")
	errors.append_array(CombatAbilityOps.validate_steps(effect_steps))
	return errors
