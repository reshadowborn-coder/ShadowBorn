class_name CombatEffectDefinition
extends Resource

enum DurationPolicy {
	INSTANT,
	TURN_BASED
}

enum StackingPolicy {
	REFRESH,
	ADD_STACKS,
	INDEPENDENT
}

@export var id:StringName = &""
@export var semantic_tags:Array[StringName] = []
@export var duration_policy:DurationPolicy = DurationPolicy.INSTANT
@export_range(0,999,1) var base_duration_turns:int = 0
@export_range(1,999,1) var max_stacks:int = 1
@export var stacking_policy:StackingPolicy = StackingPolicy.REFRESH
@export var base_magnitudes:Dictionary = {}
@export var cue_ids:Array[StringName] = []

func create_spec(context:CombatEffectContext,level:float=1.0)->CombatEffectSpec:
	return CombatEffectSpec.new(self,context,level)
