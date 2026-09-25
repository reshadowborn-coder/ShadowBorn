class_name CombatTurnTimeline
extends RefCounted

const GAUGE_MAX:=10000
const MAX_GAUGE:=30000
const BASIS_POINTS:=10000
const MIN_SPEED_MULT_BP:=4000
const MAX_SPEED_MULT_BP:=30000
const MAX_RESOLVE_STACKS:=3
const RESOLVE_GAUGE_PER_STACK:=1000
const MAX_EXTRA_TURNS_PER_ACTOR:=2

const TAG_SPEED:=&"Stat.Speed"
const TAG_HARD_CONTROL:=&"Control.Hard"
const TAG_STUN:=&"Control.Stun"
const TAG_SLEEP:=&"Control.Sleep"
const TAG_FREEZE:=&"Control.Freeze"
const TAG_PROVOKE:=&"Control.Provoke"
const TAG_SILENCE:=&"Control.Silence"
const TAG_BREAK_ON_ACTIVE_DAMAGE:=&"Break.OnActiveDamage"

var _actors:Dictionary={}
var _order_counter:=0
var _turn_serial:=0
var _extra_turn_queue:Array[StringName]=[]
var _active_ticket:Dictionary={}

func reset()->void:
	_actors.clear()
	_order_counter=0
	_turn_serial=0
	_extra_turn_queue.clear()
	_active_ticket.clear()

func add_actor(
	actor_id:StringName,
	team:StringName,
	base_speed:int,
	initial_gauge:int=0
)->bool:
	if actor_id==&"" or team==&"" or base_speed<=0 or _actors.has(actor_id):
		return false
	_actors[actor_id]={
		"id":actor_id,
		"team":team,
		"base_speed":base_speed,
		"gauge":clampi(initial_gauge,0,MAX_GAUGE),
		"alive":true,
		"effects":[],
		"resolve_stacks":0,
		"order":_order_counter
	}
	_order_counter+=1
	return true

func has_actor(actor_id:StringName)->bool:
	return _actors.has(actor_id)

func set_alive(actor_id:StringName,value:bool)->bool:
	if not _actors.has(actor_id):
		return false
	var actor:Dictionary=_actors[actor_id]
	actor["alive"]=value
	if not value:
		_extra_turn_queue=_extra_turn_queue.filter(func(id:StringName)->bool:return id!=actor_id)
		if str(_active_ticket.get("actor_id",""))==str(actor_id):
			_active_ticket.clear()
	return true

func actor_alive(actor_id:StringName)->bool:
	return _actors.has(actor_id) and bool((_actors[actor_id] as Dictionary).get("alive",false))

func gauge(actor_id:StringName)->int:
	if not _actors.has(actor_id):
		return 0
	return int((_actors[actor_id] as Dictionary).get("gauge",0))

func gauge_bp(actor_id:StringName)->int:
	return clampi(int(round(float(gauge(actor_id))*float(BASIS_POINTS)/float(GAUGE_MAX))),0,MAX_GAUGE)

func base_speed(actor_id:StringName)->int:
	if not _actors.has(actor_id):
		return 0
	return int((_actors[actor_id] as Dictionary).get("base_speed",0))

func effective_speed(actor_id:StringName)->int:
	if not _actors.has(actor_id):
		return 0
	var actor:Dictionary=_actors[actor_id]
	var speed_mod_bp:=0
	for effect_value in actor.get("effects",[]):
		var effect:Dictionary=effect_value
		if _effect_has_tag(effect,TAG_SPEED):
			speed_mod_bp+=int(effect.get("magnitude_bp",0))
	var multiplier:=clampi(BASIS_POINTS+speed_mod_bp,MIN_SPEED_MULT_BP,MAX_SPEED_MULT_BP)
	return maxi(1,int(round(float(actor.get("base_speed",1))*float(multiplier)/float(BASIS_POINTS))))

func apply_effect(
	actor_id:StringName,
	effect_id:StringName,
	tags:Array,
	turns:int,
	magnitude_bp:int=0,
	source_id:StringName=&"",
	metadata:Dictionary={}
)->bool:
	if not _actors.has(actor_id) or effect_id==&"" or turns<=0:
		return false
	var normalized_tags:Array[StringName]=[]
	for raw_tag in tags:
		var tag:=StringName(str(raw_tag))
		if tag!=&"" and tag not in normalized_tags:
			normalized_tags.append(tag)
	if normalized_tags.is_empty():
		return false

	var actor:Dictionary=_actors[actor_id]
	var effects:Array=actor.get("effects",[])
	for i in range(effects.size()):
		var existing:Dictionary=effects[i]
		if StringName(existing.get("id",&""))==effect_id and StringName(existing.get("source_id",&""))==source_id:
			existing["turns"]=maxi(int(existing.get("turns",0)),turns)
			if abs(magnitude_bp)>abs(int(existing.get("magnitude_bp",0))):
				existing["magnitude_bp"]=magnitude_bp
			existing["tags"]=normalized_tags.duplicate()
			existing["metadata"]=metadata.duplicate(true)
			effects[i]=existing
			actor["effects"]=effects
			return true

	effects.append({
		"id":effect_id,
		"source_id":source_id,
		"tags":normalized_tags,
		"turns":turns,
		"magnitude_bp":magnitude_bp,
		"metadata":metadata.duplicate(true)
	})
	actor["effects"]=effects
	return true

func apply_speed_modifier(
	actor_id:StringName,
	source_id:StringName,
	percent_bp:int,
	turns:int
)->bool:
	if percent_bp==0:
		return false
	var prefix:="Buff.Speed." if percent_bp>0 else "Debuff.Speed."
	var source_text:=str(source_id) if source_id!=&"" else "anonymous"
	return apply_effect(
		actor_id,
		StringName(prefix+source_text),
		[TAG_SPEED],
		turns,
		percent_bp,
		source_id
	)

func apply_control(
	actor_id:StringName,
	control_tag:StringName,
	turns:int,
	source_id:StringName=&""
)->bool:
	if control_tag not in [TAG_STUN,TAG_SLEEP,TAG_FREEZE]:
		return false
	var tags:Array=[TAG_HARD_CONTROL,control_tag]
	if control_tag==TAG_SLEEP:
		tags.append(TAG_BREAK_ON_ACTIVE_DAMAGE)
	var suffix:=str(source_id) if source_id!=&"" else "anonymous"
	return apply_effect(
		actor_id,
		StringName(str(control_tag)+"."+suffix),
		tags,
		turns,
		0,
		source_id
	)

func apply_provoke(
	actor_id:StringName,
	source_actor_id:StringName,
	turns:int
)->bool:
	if source_actor_id==&"":
		return false
	return apply_effect(
		actor_id,
		StringName("Control.Provoke."+str(source_actor_id)),
		[TAG_PROVOKE],
		turns,
		0,
		source_actor_id,
		{"forced_target_id":source_actor_id}
	)

func apply_silence(actor_id:StringName,source_id:StringName,turns:int)->bool:
	return apply_effect(
		actor_id,
		StringName("Control.Silence."+str(source_id)),
		[TAG_SILENCE],
		turns,
		0,
		source_id
	)

func remove_effect(actor_id:StringName,effect_id:StringName,source_id:StringName=&"")->int:
	if not _actors.has(actor_id):
		return 0
	var actor:Dictionary=_actors[actor_id]
	var effects:Array=actor.get("effects",[])
	var kept:Array=[]
	var removed:=0
	for effect_value in effects:
		var effect:Dictionary=effect_value
		var same_id:=StringName(effect.get("id",&""))==effect_id
		var same_source:=source_id==&"" or StringName(effect.get("source_id",&""))==source_id
		if same_id and same_source:
			removed+=1
		else:
			kept.append(effect)
	actor["effects"]=kept
	return removed

func remove_effects_with_tag(actor_id:StringName,tag:StringName)->int:
	if not _actors.has(actor_id) or tag==&"":
		return 0
	var actor:Dictionary=_actors[actor_id]
	var kept:Array=[]
	var removed:=0
	for effect_value in actor.get("effects",[]):
		var effect:Dictionary=effect_value
		if _effect_has_tag(effect,tag):
			removed+=1
		else:
			kept.append(effect)
	actor["effects"]=kept
	return removed

func has_tag(actor_id:StringName,tag:StringName)->bool:
	if not _actors.has(actor_id):
		return false
	for effect_value in (_actors[actor_id] as Dictionary).get("effects",[]):
		if _effect_has_tag(effect_value as Dictionary,tag):
			return true
	return false

func forced_target_id(actor_id:StringName)->StringName:
	if not _actors.has(actor_id):
		return &""
	for effect_value in (_actors[actor_id] as Dictionary).get("effects",[]):
		var effect:Dictionary=effect_value
		if _effect_has_tag(effect,TAG_PROVOKE):
			var metadata:Dictionary=effect.get("metadata",{})
			return StringName(metadata.get("forced_target_id",&""))
	return &""

func active_skills_blocked(actor_id:StringName)->bool:
	return has_tag(actor_id,TAG_SILENCE)

func notify_active_damage(actor_id:StringName)->int:
	# Direct/active damage wakes Sleep. Periodic damage should not call this.
	return remove_effects_with_tag(actor_id,TAG_BREAK_ON_ACTIVE_DAMAGE)

func incoming_damage_multiplier(actor_id:StringName)->float:
	# RAID-style Freeze protection is deliberately explicit. Future skills can
	# add Shatter by consuming the Freeze tag before damage is resolved.
	return 0.75 if has_tag(actor_id,TAG_FREEZE) else 1.0

func adjust_turn_meter(actor_id:StringName,delta_bp:int)->bool:
	if not _actors.has(actor_id):
		return false
	var actor:Dictionary=_actors[actor_id]
	var delta:=int(round(float(GAUGE_MAX)*float(delta_bp)/float(BASIS_POINTS)))
	actor["gauge"]=clampi(int(actor.get("gauge",0))+delta,0,MAX_GAUGE)
	return true

func set_turn_meter(actor_id:StringName,value_bp:int)->bool:
	if not _actors.has(actor_id):
		return false
	var actor:Dictionary=_actors[actor_id]
	actor["gauge"]=clampi(int(round(float(GAUGE_MAX)*float(value_bp)/float(BASIS_POINTS))),0,MAX_GAUGE)
	return true

func grant_extra_turn(actor_id:StringName,count:int=1)->bool:
	if not actor_alive(actor_id) or count<=0:
		return false
	var already:=0
	for queued_id in _extra_turn_queue:
		if queued_id==actor_id:
			already+=1
	var to_add:=mini(count,MAX_EXTRA_TURNS_PER_ACTOR-already)
	for _i in range(maxi(0,to_add)):
		_extra_turn_queue.append(actor_id)
	return to_add>0

func next_turn()->Dictionary:
	if not _active_ticket.is_empty():
		return {}

	while not _extra_turn_queue.is_empty():
		var extra_id:StringName=_extra_turn_queue.pop_front()
		if actor_alive(extra_id):
			return _open_ticket(extra_id,true)

	var living:=_living_actor_ids()
	if living.is_empty():
		return {}

	if not _any_ready(living):
		var ticks:=_ticks_until_next_ready(living)
		for actor_id in living:
			var actor:Dictionary=_actors[actor_id]
			var next_gauge:=int(actor.get("gauge",0))+effective_speed(actor_id)*ticks
			actor["gauge"]=mini(MAX_GAUGE,next_gauge)

	var actor_id:=_best_ready_actor(living)
	if actor_id==&"":
		return {}
	return _open_ticket(actor_id,false)

func end_turn(actor_id:StringName)->bool:
	if _active_ticket.is_empty() or StringName(_active_ticket.get("actor_id",&""))!=actor_id:
		return false
	if not _actors.has(actor_id):
		_active_ticket.clear()
		return false

	var actor:Dictionary=_actors[actor_id]
	var skipped:=bool(_active_ticket.get("skipped",false))
	_tick_owner_turn_effects(actor)
	if skipped:
		var resolve:=mini(MAX_RESOLVE_STACKS,int(actor.get("resolve_stacks",0))+1)
		actor["resolve_stacks"]=resolve
		actor["gauge"]=clampi(
			int(actor.get("gauge",0))+resolve*RESOLVE_GAUGE_PER_STACK,
			0,
			MAX_GAUGE
		)
	else:
		actor["resolve_stacks"]=0
	_active_ticket.clear()
	return true

func active_ticket()->Dictionary:
	return _active_ticket.duplicate(true)

func actor_snapshot(actor_id:StringName)->Dictionary:
	if not _actors.has(actor_id):
		return {}
	var actor:Dictionary=(_actors[actor_id] as Dictionary).duplicate(true)
	actor["effective_speed"]=effective_speed(actor_id)
	actor["gauge_bp"]=gauge_bp(actor_id)
	return actor

func snapshot()->Dictionary:
	var actors_out:Dictionary={}
	for raw_id in _actors:
		actors_out[str(raw_id)]=actor_snapshot(StringName(raw_id))
	var queue:Array[String]=[]
	for actor_id in _extra_turn_queue:
		queue.append(str(actor_id))
	return {
		"gauge_max":GAUGE_MAX,
		"actors":actors_out,
		"extra_turn_queue":queue,
		"active_ticket":_active_ticket.duplicate(true),
		"turn_serial":_turn_serial
	}

func _open_ticket(actor_id:StringName,extra_turn:bool)->Dictionary:
	var actor:Dictionary=_actors[actor_id]
	if not extra_turn:
		actor["gauge"]=maxi(0,int(actor.get("gauge",0))-GAUGE_MAX)
	var control_reason:=_hard_control_reason(actor_id)
	_turn_serial+=1
	_active_ticket={
		"serial":_turn_serial,
		"actor_id":actor_id,
		"team":StringName(actor.get("team",&"")),
		"extra_turn":extra_turn,
		"skipped":control_reason!=&"",
		"control_reason":control_reason,
		"cooldowns_advance":control_reason==&"",
		"effective_speed":effective_speed(actor_id),
		"gauge_after_consume":int(actor.get("gauge",0)),
		"resolve_stacks":int(actor.get("resolve_stacks",0))
	}
	return _active_ticket.duplicate(true)

func _hard_control_reason(actor_id:StringName)->StringName:
	for tag in [TAG_STUN,TAG_FREEZE,TAG_SLEEP]:
		if has_tag(actor_id,tag):
			return tag
	return &""

func _tick_owner_turn_effects(actor:Dictionary)->void:
	var kept:Array=[]
	for effect_value in actor.get("effects",[]):
		var effect:Dictionary=effect_value
		var remaining:=maxi(0,int(effect.get("turns",0))-1)
		if remaining>0:
			effect["turns"]=remaining
			kept.append(effect)
	actor["effects"]=kept

func _living_actor_ids()->Array[StringName]:
	var out:Array[StringName]=[]
	for raw_id in _actors:
		var actor_id:=StringName(raw_id)
		if actor_alive(actor_id):
			out.append(actor_id)
	return out

func _any_ready(ids:Array[StringName])->bool:
	for actor_id in ids:
		if gauge(actor_id)>=GAUGE_MAX:
			return true
	return false

func _ticks_until_next_ready(ids:Array[StringName])->int:
	var best:=1<<30
	for actor_id in ids:
		var remaining:=maxi(0,GAUGE_MAX-gauge(actor_id))
		var speed:=maxi(1,effective_speed(actor_id))
		var ticks:=0 if remaining<=0 else int((remaining+speed-1)/speed)
		best=mini(best,ticks)
	return maxi(0,best)

func _best_ready_actor(ids:Array[StringName])->StringName:
	var best_id:=&""
	var best_gauge:=-1
	var best_speed:=-1
	var best_order:=1<<30
	for actor_id in ids:
		var current_gauge:=gauge(actor_id)
		if current_gauge<GAUGE_MAX:
			continue
		var actor:Dictionary=_actors[actor_id]
		var speed:=effective_speed(actor_id)
		var order:=int(actor.get("order",0))
		if (
			current_gauge>best_gauge
			or (current_gauge==best_gauge and speed>best_speed)
			or (current_gauge==best_gauge and speed==best_speed and order<best_order)
		):
			best_id=actor_id
			best_gauge=current_gauge
			best_speed=speed
			best_order=order
	return best_id

static func _effect_has_tag(effect:Dictionary,tag:StringName)->bool:
	for raw_tag in effect.get("tags",[]):
		if StringName(str(raw_tag))==tag:
			return true
	return false
