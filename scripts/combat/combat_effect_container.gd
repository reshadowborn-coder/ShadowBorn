class_name CombatEffectContainer
extends RefCounted

var _entries:Array[Dictionary]=[]
var _tags:=CombatTagLedger.new()
var _instance_counter:int=0

func clear()->void:
	_entries.clear()
	_tags.clear()
	_instance_counter=0

func apply(definition:CombatEffectDefinition,context:CombatEffectContext,level:float=1.0,runtime_overrides:Dictionary={})->Dictionary:
	if definition==null or context==null or definition.id==&"":
		return {"applied":false,"reason":"invalid","instance_id":0}
	var spec:=definition.create_spec(context,level)
	for raw_key in runtime_overrides:
		spec.set_runtime_magnitude(str(raw_key),runtime_overrides[raw_key],context)
	match definition.stacking_policy:
		CombatEffectDefinition.StackingPolicy.REFRESH:
			var index:=_first_index(definition.id)
			if index>=0:
				var entry:Dictionary=_entries[index]
				var existing:CombatEffectSpec=entry.spec
				existing.remaining_turns=maxi(existing.remaining_turns,spec.remaining_turns)
				_merge_spec_magnitudes(existing,spec,definition.magnitude_merge_policy)
				# Overall context records the latest application/refresher, while
				# retained magnitudes keep their own source attribution.
				existing.context=spec.context.duplicate_context()
				return {"applied":true,"reason":"refreshed","instance_id":int(entry.instance_id),"stack_count":existing.stack_count}
			return _append_spec(spec)
		CombatEffectDefinition.StackingPolicy.ADD_STACKS:
			var index:=_first_index(definition.id)
			if index>=0:
				var entry:Dictionary=_entries[index]
				var existing:CombatEffectSpec=entry.spec
				if existing.stack_count>=definition.max_stacks:
					existing.remaining_turns=maxi(existing.remaining_turns,spec.remaining_turns)
					_merge_spec_magnitudes(existing,spec,definition.magnitude_merge_policy)
					return {"applied":true,"reason":"stack_cap_refreshed","instance_id":int(entry.instance_id),"stack_count":existing.stack_count}
				existing.stack_count+=1
				existing.add_stack_source(spec.context)
				existing.remaining_turns=maxi(existing.remaining_turns,spec.remaining_turns)
				_merge_spec_magnitudes(existing,spec,definition.magnitude_merge_policy)
				return {"applied":true,"reason":"stack_added","instance_id":int(entry.instance_id),"stack_count":existing.stack_count}
			return _append_spec(spec)
		CombatEffectDefinition.StackingPolicy.INDEPENDENT:
			if count(definition.id)>=definition.max_stacks:
				return {"applied":false,"reason":"stack_cap","instance_id":0}
			return _append_spec(spec)
	return {"applied":false,"reason":"unsupported_policy","instance_id":0}

func advance_owner_turn()->Array[Dictionary]:
	var expired:Array[Dictionary]=[]
	for i in range(_entries.size()-1,-1,-1):
		var entry:Dictionary=_entries[i]
		var spec:CombatEffectSpec=entry.spec
		spec.advance_turn()
		if spec.is_expired():
			expired.append(_receipt(entry,"expired"))
			_remove_at(i)
	expired.reverse()
	return expired

func remove_by_id(effect_id:StringName,max_count:int=999)->Array[Dictionary]:
	var removed:Array[Dictionary]=[]
	var remaining:=maxi(0,max_count)
	for i in range(_entries.size()-1,-1,-1):
		if remaining<=0:
			break
		var entry:Dictionary=_entries[i]
		var spec:CombatEffectSpec=entry.spec
		if spec.definition.id!=effect_id:
			continue
		removed.append(_receipt(entry,"removed"))
		_remove_at(i)
		remaining-=1
	removed.reverse()
	return removed

func remove_by_tag(tag:StringName,max_count:int=999)->Array[Dictionary]:
	var removed:Array[Dictionary]=[]
	var remaining:=maxi(0,max_count)
	for i in range(_entries.size()-1,-1,-1):
		if remaining<=0:
			break
		var entry:Dictionary=_entries[i]
		var spec:CombatEffectSpec=entry.spec
		if not spec.has_tag(tag):
			continue
		removed.append(_receipt(entry,"removed"))
		_remove_at(i)
		remaining-=1
	removed.reverse()
	return removed

func count(effect_id:StringName)->int:
	var total:=0
	for entry_value in _entries:
		var entry:Dictionary=entry_value
		var spec:CombatEffectSpec=entry.spec
		if spec.definition.id==effect_id:
			total+=1
	return total

func stack_count(effect_id:StringName)->int:
	var total:=0
	for entry_value in _entries:
		var entry:Dictionary=entry_value
		var spec:CombatEffectSpec=entry.spec
		if spec.definition.id==effect_id:
			total+=spec.stack_count
	return total

func has_tag(tag:StringName)->bool:
	return _tags.has(tag)

func first_spec(effect_id:StringName)->CombatEffectSpec:
	var index:=_first_index(effect_id)
	if index<0:
		return null
	return (_entries[index] as Dictionary).spec as CombatEffectSpec

func snapshot()->Dictionary:
	var effects:Array[Dictionary]=[]
	for entry_value in _entries:
		var entry:Dictionary=entry_value
		var spec:CombatEffectSpec=entry.spec
		effects.append({"instance_id":int(entry.instance_id),"spec":spec.snapshot()})
	return {"effects":effects,"tags":_tags.snapshot(),"instance_counter":_instance_counter}

func _append_spec(spec:CombatEffectSpec)->Dictionary:
	_instance_counter+=1
	var instance_id:=_instance_counter
	var tag_source:=StringName("effect_instance_%d"%instance_id)
	for tag in spec.definition.semantic_tags:
		_tags.add(tag,tag_source)
	for tag in spec.dynamic_tags:
		_tags.add(tag,tag_source)
	_entries.append({"instance_id":instance_id,"tag_source":tag_source,"spec":spec})
	return {"applied":true,"reason":"created","instance_id":instance_id,"stack_count":spec.stack_count}

func _remove_at(index:int)->void:
	var entry:Dictionary=_entries[index]
	var spec:CombatEffectSpec=entry.spec
	var tag_source:=StringName(entry.tag_source)
	for tag in spec.definition.semantic_tags:
		_tags.remove(tag,tag_source)
	for tag in spec.dynamic_tags:
		_tags.remove(tag,tag_source)
	_entries.remove_at(index)

func _first_index(effect_id:StringName)->int:
	for i in range(_entries.size()):
		var entry:Dictionary=_entries[i]
		var spec:CombatEffectSpec=entry.spec
		if spec.definition.id==effect_id:
			return i
	return -1

static func _merge_spec_magnitudes(
	existing:CombatEffectSpec,
	incoming:CombatEffectSpec,
	policy:CombatEffectDefinition.MagnitudeMergePolicy
)->void:
	for raw_key in incoming.runtime_magnitudes:
		var key:=str(raw_key)
		var next_value=incoming.runtime_magnitudes[raw_key]
		if policy==CombatEffectDefinition.MagnitudeMergePolicy.REPLACE or not existing.runtime_magnitudes.has(raw_key):
			existing.set_runtime_magnitude(key,next_value,incoming.magnitude_source(key))
			continue
		var old_value=existing.runtime_magnitudes[raw_key]
		if typeof(next_value) in [TYPE_INT,TYPE_FLOAT] and typeof(old_value) in [TYPE_INT,TYPE_FLOAT]:
			var incoming_wins:=(
				float(next_value)>float(old_value)
				if policy==CombatEffectDefinition.MagnitudeMergePolicy.MAX_NUMERIC
				else float(next_value)<float(old_value)
			)
			if incoming_wins:
				existing.set_runtime_magnitude(key,next_value,incoming.magnitude_source(key))
		else:
			existing.set_runtime_magnitude(key,next_value,incoming.magnitude_source(key))

static func _receipt(entry:Dictionary,reason:String)->Dictionary:
	var spec:CombatEffectSpec=entry.spec
	return {
		"instance_id":int(entry.instance_id),
		"effect_id":spec.definition.id,
		"source_actor_id":spec.context.source_actor_id,
		"stack_count":spec.stack_count,
		"reason":reason
	}
