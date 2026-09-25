class_name PerfTrace
extends Node

const SCHEMA_VERSION := 1
const DEFAULT_CAPACITY := 2048
const DEFAULT_SAMPLE_HZ := 5.0
const FRAME_BUDGET_60_MS := 1000.0 / 60.0
const FRAME_BUDGET_30_MS := 1000.0 / 30.0

var _capacity: int = DEFAULT_CAPACITY
var _buffer: Array = []
var _write_index := 0
var _count := 0
var _capture_enabled := false
var _sample_interval_sec := 1.0 / DEFAULT_SAMPLE_HZ
var _sample_accumulator_sec := 0.0
var _frame_index := 0
var _beat_id: StringName = &"UNSPECIFIED"
var _lifecycle_epoch := 0
var _cold_run := true
var _frame_mode := 60
var _quality_preset: StringName = &"target"
var _viewport_rid := RID()
var _render_measurement_enabled := false

func _init(capacity: int = DEFAULT_CAPACITY) -> void:
	_capacity = maxi(32, capacity)
	_buffer.resize(_capacity)

func start_capture(viewport: Viewport = null, sample_hz: float = DEFAULT_SAMPLE_HZ) -> void:
	_sample_interval_sec = 1.0 / clampf(sample_hz, 1.0, 20.0)
	_sample_accumulator_sec = 0.0
	_frame_index = 0
	_capture_enabled = true
	if viewport != null:
		_viewport_rid = viewport.get_viewport_rid()
		if _viewport_rid.is_valid():
			RenderingServer.viewport_set_measure_render_time(_viewport_rid, true)
			_render_measurement_enabled = true
	set_process(true)
	mark_event(&"capture_start")

func stop_capture() -> void:
	if not _capture_enabled:
		return
	mark_event(&"capture_stop")
	_capture_enabled = false
	if _render_measurement_enabled and _viewport_rid.is_valid():
		RenderingServer.viewport_set_measure_render_time(_viewport_rid, false)
	_render_measurement_enabled = false
	set_process(false)

func configure_context(frame_mode: int, quality_preset: StringName, cold_run: bool) -> void:
	_frame_mode = 30 if frame_mode == 30 else 60
	_quality_preset = quality_preset
	_cold_run = cold_run

func set_beat(beat_id: StringName) -> void:
	if beat_id == _beat_id:
		return
	_beat_id = beat_id
	mark_event(&"beat")

func mark_lifecycle(event_name: StringName) -> void:
	_lifecycle_epoch += 1
	_push(_base_record(&"lifecycle", event_name))

func mark_event(event_name: StringName, fields: Dictionary = {}) -> void:
	var record := _base_record(&"event", event_name)
	for key in fields:
		record[key] = fields[key]
	_push(record)

func _process(delta: float) -> void:
	if not _capture_enabled:
		return
	_frame_index += 1
	var frame_ms := delta * 1000.0
	var budget_ms := FRAME_BUDGET_30_MS if _frame_mode == 30 else FRAME_BUDGET_60_MS
	if frame_ms > budget_ms:
		var hitch := _base_record(&"hitch", &"frame_budget_miss")
		hitch["frame_ms"] = frame_ms
		hitch["budget_ms"] = budget_ms
		_push(hitch)
	_sample_accumulator_sec += delta
	if _sample_accumulator_sec < _sample_interval_sec:
		return
	_sample_accumulator_sec = fmod(_sample_accumulator_sec, _sample_interval_sec)
	_push(_trend_record(frame_ms))

func _trend_record(frame_ms: float) -> Dictionary:
	var record := _base_record(&"trend", &"periodic")
	record["frame_ms"] = frame_ms
	record["fps"] = Engine.get_frames_per_second()
	var render_known := _render_measurement_enabled and _frame_index >= 2
	record["render_time_known"] = render_known
	if render_known:
		record["render_cpu_ms"] = RenderingServer.viewport_get_measured_render_time_cpu(_viewport_rid)
		record["render_gpu_ms"] = RenderingServer.viewport_get_measured_render_time_gpu(_viewport_rid)
	var render_info_known := _frame_index >= 2
	record["render_info_known"] = render_info_known
	if render_info_known:
		record["draw_calls"] = Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		record["objects_in_frame"] = Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)
		record["primitives_in_frame"] = Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
	record["memory_static_known"] = OS.is_debug_build()
	if OS.is_debug_build():
		record["memory_static_bytes"] = Performance.get_monitor(Performance.MEMORY_STATIC)
	return record

func _base_record(kind: StringName, name: StringName) -> Dictionary:
	return {"schema": SCHEMA_VERSION, "timestamp_us": Time.get_ticks_usec(), "kind": String(kind), "name": String(name), "beat": String(_beat_id), "lifecycle_epoch": _lifecycle_epoch, "cold": _cold_run, "frame_mode": _frame_mode, "quality": String(_quality_preset)}

func _push(record: Dictionary) -> void:
	_buffer[_write_index] = record
	_write_index = (_write_index + 1) % _capacity
	_count = mini(_count + 1, _capacity)

func clear() -> void:
	_buffer.fill(null)
	_write_index = 0
	_count = 0

func size() -> int:
	return _count

func snapshot() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	out.resize(_count)
	var start := (_write_index - _count + _capacity) % _capacity
	for i in _count:
		out[i] = (_buffer[(start + i) % _capacity] as Dictionary).duplicate(true)
	return out

static func summarize_frame_times(frame_times_ms: Array[float], budget_ms: float) -> Dictionary:
	if frame_times_ms.is_empty():
		return {"count": 0, "median_ms": 0.0, "p90_ms": 0.0, "p95_ms": 0.0, "p99_ms": 0.0, "worst_ms": 0.0, "misses": 0, "longest_miss_streak": 0}
	var sorted := frame_times_ms.duplicate()
	sorted.sort()
	var misses := 0
	var streak := 0
	var longest := 0
	for value in frame_times_ms:
		if value > budget_ms:
			misses += 1
			streak += 1
			longest = maxi(longest, streak)
		else:
			streak = 0
	return {"count": frame_times_ms.size(), "median_ms": _nearest_rank(sorted, 0.50), "p90_ms": _nearest_rank(sorted, 0.90), "p95_ms": _nearest_rank(sorted, 0.95), "p99_ms": _nearest_rank(sorted, 0.99), "worst_ms": sorted[sorted.size() - 1], "misses": misses, "longest_miss_streak": longest}

static func _nearest_rank(sorted_values: Array[float], percentile: float) -> float:
	var rank := ceili(clampf(percentile, 0.0, 1.0) * sorted_values.size())
	var index := clampi(maxi(1, rank) - 1, 0, sorted_values.size() - 1)
	return sorted_values[index]
