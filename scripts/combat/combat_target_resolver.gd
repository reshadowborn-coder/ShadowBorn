class_name CombatTargetResolver
extends RefCounted

static func resolve(selector:String,context:Dictionary)->Array[StringName]:
	var actors:Dictionary=context.get("actors",{})
	var self_id:=StringName(str(context.get("self_id","")))
	var self_actor:Dictionary=actors.get(str(self_id),actors.get(self_id,{}))
	var self_team:=str(self_actor.get("team",context.get("self_team","")))
	match selector:
		"self":
			return _one_if_alive(self_id,actors)
		"primary_target":
			return _one_if_alive(StringName(str(context.get("primary_target_id",""))),actors)
		"event_source":
			return _one_if_alive(StringName(str(context.get("event_source_id",""))),actors)
		"event_target":
			return _one_if_alive(StringName(str(context.get("event_target_id",""))),actors)
		"all_allies":
			return _team_ids(actors,self_team,true)
		"all_enemies":
			return _team_ids(actors,self_team,false)
		"lowest_hp_ally":
			return _lowest_hp(_team_ids(actors,self_team,true),actors)
		"highest_turn_meter_enemy":
			return _highest_turn_meter(_team_ids(actors,self_team,false),actors)
	return []

static func _one_if_alive(actor_id:StringName,actors:Dictionary)->Array[StringName]:
	if actor_id==&"":
		return []
	var actor:Dictionary=actors.get(str(actor_id),actors.get(actor_id,{}))
	if actor.is_empty() or not bool(actor.get("alive",true)):
		return []
	return [actor_id]

static func _team_ids(actors:Dictionary,self_team:String,want_same:bool)->Array[StringName]:
	var out:Array[StringName]=[]
	for raw_id in actors:
		var actor:Dictionary=actors[raw_id]
		if not bool(actor.get("alive",true)):
			continue
		var same:=str(actor.get("team",""))==self_team
		if same==want_same:
			out.append(StringName(str(raw_id)))
	out.sort_custom(func(a:StringName,b:StringName)->bool:return str(a)<str(b))
	return out

static func _lowest_hp(ids:Array[StringName],actors:Dictionary)->Array[StringName]:
	var best:=&""
	var best_ratio:=INF
	for id in ids:
		var actor:Dictionary=actors.get(str(id),actors.get(id,{}))
		var max_hp:=maxf(0.0,float(actor.get("max_hp",0.0)))
		if max_hp<=0.0:
			continue
		var ratio:=float(actor.get("hp",0.0))/max_hp
		if ratio<best_ratio or (is_equal_approx(ratio,best_ratio) and (best==&"" or str(id)<str(best))):
			best=id
			best_ratio=ratio
	return [] if best==&"" else [best]

static func _highest_turn_meter(ids:Array[StringName],actors:Dictionary)->Array[StringName]:
	var best:=&""
	var best_meter:=-1
	for id in ids:
		var actor:Dictionary=actors.get(str(id),actors.get(id,{}))
		var meter:=int(actor.get("turn_meter_bp",0))
		if meter>best_meter or (meter==best_meter and (best==&"" or str(id)<str(best))):
			best=id
			best_meter=meter
	return [] if best==&"" else [best]
