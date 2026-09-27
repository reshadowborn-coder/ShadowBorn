class_name BattleTurnScheduler
extends RefCounted

# Deterministic Checkpoint 01 Turn Meter scheduler.
#
# This is intentionally narrower than the pre-reboot CombatTurnTimeline:
# it owns only Speed, Turn Meter, stable tie-breaking and direct meter changes.
# Status semantics, cooldowns and skill legality stay outside until they are
# explicitly migrated. The key guarantee is that render-frame delta partitioning
# cannot change which actor truly reaches READY first.

const GAUGE_MAX := 10000
const MAX_GAUGE := 30000
const TICKS_PER_SECOND := 110.0

var _actors: Dictionary = {}
var _order_counter := 0

func reset() -> void:
	_actors.clear()
	_order_counter = 0

func add_actor(actor_id: StringName, speed: int, initial_gauge_bp: int = 0) -> bool:
	if actor_id == &"" or speed <= 0 or _actors.has(actor_id):
		return false
	_actors[actor_id] = {
		"id": actor_id,
		"speed": speed,
		"gauge": clampi(initial_gauge_bp, 0, MAX_GAUGE),
		"alive": true,
		"order": _order_counter
	}
	_order_counter += 1
	return true

func has_actor(actor_id: StringName) -> bool:
	return _actors.has(actor_id)

func set_alive(actor_id: StringName, alive: bool) -> bool:
	if not _actors.has(actor_id):
		return false
	(_actors[actor_id] as Dictionary)["alive"] = alive
	return true

func set_gauge_bp(actor_id: StringName, gauge_bp: int) -> bool:
	if not _actors.has(actor_id):
		return false
	(_actors[actor_id] as Dictionary)["gauge"] = clampi(gauge_bp, 0, MAX_GAUGE)
	return true

func adjust_gauge_bp(actor_id: StringName, delta_bp: int) -> bool:
	if not _actors.has(actor_id):
		return false
	var actor: Dictionary = _actors[actor_id]
	actor["gauge"] = clampi(int(actor.get("gauge", 0)) + delta_bp, 0, MAX_GAUGE)
	return true

func gauge_bp(actor_id: StringName) -> int:
	if not _actors.has(actor_id):
		return 0
	return int((_actors[actor_id] as Dictionary).get("gauge", 0))

func speed(actor_id: StringName) -> int:
	if not _actors.has(actor_id):
		return 0
	return int((_actors[actor_id] as Dictionary).get("speed", 0))

func next_event() -> Dictionary:
	var living := _living_actor_ids()
	if living.is_empty():
		return {}

	var ticks_waited := 0
	if not _any_ready(living):
		ticks_waited = _ticks_until_next_ready(living)
		_advance_ticks(living, ticks_waited)

	var actor_id := _best_ready_actor(living)
	if actor_id == &"":
		return {}

	var actor: Dictionary = _actors[actor_id]
	actor["gauge"] = maxi(0, int(actor.get("gauge", 0)) - GAUGE_MAX)
	return {
		"actor_id": actor_id,
		"ticks_waited": ticks_waited,
		"wait_seconds_1x": ticks_to_seconds(ticks_waited, 1.0),
		"gauge_after_consume": int(actor.get("gauge", 0)),
		"snapshot": snapshot()
	}

func snapshot() -> Dictionary:
	var out: Dictionary = {}
	for raw_id in _actors:
		var actor_id := StringName(raw_id)
		var actor: Dictionary = (_actors[actor_id] as Dictionary).duplicate(true)
		out[str(actor_id)] = actor
	return out

static func ticks_to_seconds(ticks: int, battle_speed: float = 1.0) -> float:
	return float(maxi(0, ticks)) / TICKS_PER_SECOND / maxf(0.001, battle_speed)

func _advance_ticks(ids: Array[StringName], ticks: int) -> void:
	if ticks <= 0:
		return
	for actor_id in ids:
		var actor: Dictionary = _actors[actor_id]
		actor["gauge"] = mini(MAX_GAUGE, int(actor.get("gauge", 0)) + int(actor.get("speed", 0)) * ticks)

func _living_actor_ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for raw_id in _actors:
		var actor_id := StringName(raw_id)
		if bool((_actors[actor_id] as Dictionary).get("alive", false)):
			out.append(actor_id)
	return out

func _any_ready(ids: Array[StringName]) -> bool:
	for actor_id in ids:
		if gauge_bp(actor_id) >= GAUGE_MAX:
			return true
	return false

func _ticks_until_next_ready(ids: Array[StringName]) -> int:
	var best := 1 << 30
	for actor_id in ids:
		var remaining := maxi(0, GAUGE_MAX - gauge_bp(actor_id))
		var actor_speed := maxi(1, speed(actor_id))
		var ticks := 0 if remaining <= 0 else int((remaining + actor_speed - 1) / actor_speed)
		best = mini(best, ticks)
	return maxi(0, best)

func _best_ready_actor(ids: Array[StringName]) -> StringName:
	var best_id := &""
	var best_gauge := -1
	var best_speed := -1
	var best_order := 1 << 30
	for actor_id in ids:
		var current_gauge := gauge_bp(actor_id)
		if current_gauge < GAUGE_MAX:
			continue
		var actor: Dictionary = _actors[actor_id]
		var actor_speed := speed(actor_id)
		var order := int(actor.get("order", 0))
		if (
			current_gauge > best_gauge
			or (current_gauge == best_gauge and actor_speed > best_speed)
			or (current_gauge == best_gauge and actor_speed == best_speed and order < best_order)
		):
			best_id = actor_id
			best_gauge = current_gauge
			best_speed = actor_speed
			best_order = order
	return best_id
