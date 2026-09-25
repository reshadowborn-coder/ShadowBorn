class_name CombatEventRouter
extends RefCounted

const MAX_EVENTS_PER_WINDOW:=32

var passive_runtime:CombatPassiveRuntime
var reaction_queue:CombatReactionQueue
var rng:CombatDeterministicRng
var _window_serial:int=0
var _event_count:int=0

func _init(
	in_passive_runtime:CombatPassiveRuntime=null,
	in_reaction_queue:CombatReactionQueue=null,
	in_rng:CombatDeterministicRng=null
)->void:
	passive_runtime=in_passive_runtime if in_passive_runtime!=null else CombatPassiveRuntime.new()
	reaction_queue=in_reaction_queue if in_reaction_queue!=null else CombatReactionQueue.new()
	rng=in_rng if in_rng!=null else CombatDeterministicRng.new(1)

func begin_turn_window(turn_serial:int)->void:
	_window_serial=maxi(0,turn_serial)
	_event_count=0
	reaction_queue.begin_window(_window_serial)

func dispatch(event:CombatTriggerEvent)->Dictionary:
	if event==null or event.event_type==&"":
		return {"accepted":false,"reason":"invalid_event","receipts":[]}
	if event.turn_serial!=_window_serial:
		return {"accepted":false,"reason":"wrong_window","receipts":[]}
	if _event_count>=MAX_EVENTS_PER_WINDOW:
		return {"accepted":false,"reason":"event_budget","receipts":[]}
	_event_count+=1

	var receipts:Array[Dictionary]=[]
	var candidates:=passive_runtime.collect_reactions(event,false)
	for candidate in candidates:
		var actor_id:=StringName(candidate.get("actor_id",&""))
		var passive_id:=StringName(candidate.get("passive_id",&""))
		var kind:=StringName(candidate.get("reaction_kind",&""))
		var priority:=int(candidate.get("priority",0))
		var chance:=clampi(int(candidate.get("proc_chance_bp",10000)),0,10000)
		var chain_depth:=int(candidate.get("chain_depth",0))
		var roll:=rng.next_bp()

		if roll>=chance:
			receipts.append(_receipt(actor_id,passive_id,false,"proc_miss",roll,chance))
			continue
		if chain_depth>CombatReactionQueue.MAX_CHAIN_DEPTH:
			receipts.append(_receipt(actor_id,passive_id,false,"chain_guard",roll,chance))
			continue

		var payload:Dictionary={
			"passive_id":passive_id,
			"event":event.snapshot(),
			"effect_steps":candidate.get("effect_steps",[]),
			"proc_roll_bp":roll,
			"proc_chance_bp":chance
		}
		var queued:=reaction_queue.queue_reaction(
			actor_id,
			passive_id,
			kind,
			priority,
			chain_depth,
			payload
		)
		if not queued:
			receipts.append(_receipt(actor_id,passive_id,false,"queue_guard",roll,chance))
			continue

		passive_runtime.commit_trigger(actor_id,passive_id,event.turn_serial,event.transaction_id)
		receipts.append(_receipt(actor_id,passive_id,true,"queued",roll,chance))

	return {
		"accepted":true,
		"reason":"",
		"event_count":_event_count,
		"receipts":receipts,
		"pending_reactions":reaction_queue.size()
	}

func pop_reaction()->Dictionary:
	return reaction_queue.pop_next()

func event_count()->int:
	return _event_count

static func _receipt(
	actor_id:StringName,
	passive_id:StringName,
	queued:bool,
	reason:String,
	roll:int,
	chance:int
)->Dictionary:
	return {
		"actor_id":actor_id,
		"passive_id":passive_id,
		"queued":queued,
		"reason":reason,
		"proc_roll_bp":roll,
		"proc_chance_bp":chance
	}
