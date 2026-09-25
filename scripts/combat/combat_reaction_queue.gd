class_name CombatReactionQueue
extends RefCounted

const KIND_COUNTER:=&"counter"
const KIND_ASSIST:=&"assist"
const KIND_FOLLOW_UP:=&"follow_up"
const KIND_INTERRUPT:=&"interrupt"

const MAX_PENDING:=8
const MAX_CHAIN_DEPTH:=2

var _pending:Array[Dictionary]=[]
var _seen:Dictionary={}
var _insertion_counter:=0
var _window_serial:=0

func begin_window(source_turn_serial:int)->void:
	_window_serial=maxi(0,source_turn_serial)
	_pending.clear()
	_seen.clear()
	_insertion_counter=0

func queue_reaction(
	actor_id:StringName,
	reaction_id:StringName,
	kind:StringName,
	priority:int=0,
	chain_depth:int=0,
	payload:Dictionary={}
)->bool:
	if actor_id==&"" or reaction_id==&"":
		return false
	if kind not in [KIND_COUNTER,KIND_ASSIST,KIND_FOLLOW_UP,KIND_INTERRUPT]:
		return false
	if chain_depth<0 or chain_depth>MAX_CHAIN_DEPTH:
		return false
	if _pending.size()>=MAX_PENDING:
		return false

	var key:="%s|%s|%s|%d"%[str(actor_id),str(reaction_id),str(kind),_window_serial]
	if _seen.has(key):
		return false
	_seen[key]=true

	_pending.append({
		"actor_id":actor_id,
		"reaction_id":reaction_id,
		"kind":kind,
		"priority":priority,
		"chain_depth":chain_depth,
		"source_turn_serial":_window_serial,
		"payload":payload.duplicate(true),
		"order":_insertion_counter
	})
	_insertion_counter+=1
	return true

func has_pending()->bool:
	return not _pending.is_empty()

func size()->int:
	return _pending.size()

func pop_next()->Dictionary:
	if _pending.is_empty():
		return {}
	var best_index:=0
	for i in range(1,_pending.size()):
		var candidate:Dictionary=_pending[i]
		var best:Dictionary=_pending[best_index]
		var candidate_priority:=int(candidate.get("priority",0))
		var best_priority:=int(best.get("priority",0))
		if candidate_priority>best_priority:
			best_index=i
		elif candidate_priority==best_priority and int(candidate.get("order",0))<int(best.get("order",0)):
			best_index=i
	var result:Dictionary=_pending[best_index].duplicate(true)
	_pending.remove_at(best_index)
	return result

func clear_actor(actor_id:StringName)->void:
	if actor_id==&"":
		return
	var kept:Array[Dictionary]=[]
	for reaction in _pending:
		if StringName(reaction.get("actor_id",&""))!=actor_id:
			kept.append(reaction)
	_pending=kept

func snapshot()->Dictionary:
	return {
		"source_turn_serial":_window_serial,
		"pending":_pending.duplicate(true),
		"count":_pending.size()
	}
