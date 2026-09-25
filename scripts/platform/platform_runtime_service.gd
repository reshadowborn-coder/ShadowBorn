class_name PlatformRuntimeService
extends Node

signal effective_profile_changed(requested_mode:String,effective_mode:String,target_fps:int,quality_pressure:int)
signal memory_pressure(level:int)
signal thermal_state_changed(state:String)
signal low_power_mode_changed(enabled:bool)
signal reportable_state_changed(domain:String,label:String,metadata:Dictionary)

const MODE_SMOOTH_60 := "smooth60"
const MODE_BATTERY_30 := "battery30"
const THERMAL_NOMINAL := "nominal"
const THERMAL_FAIR := "fair"
const THERMAL_SERIOUS := "serious"
const THERMAL_CRITICAL := "critical"
const BRIDGE_NAME := "ShadowbornIOS"

var requested_mode := MODE_SMOOTH_60
var effective_mode := MODE_SMOOTH_60
var target_fps := 60
var quality_pressure := 0
var thermal_state := THERMAL_NOMINAL
var low_power_mode := false
var memory_pressure_count := 0

var _bridge:Object
var _reported_states:Dictionary={}

func _ready()->void:
	_bind_native_bridge()
	_refresh_native_snapshot()
	_recompute_policy()

func _notification(what:int)->void:
	if what==NOTIFICATION_OS_MEMORY_WARNING:
		memory_pressure_count+=1
		memory_pressure.emit(memory_pressure_count)
	elif what in [NOTIFICATION_APPLICATION_FOCUS_IN,NOTIFICATION_APPLICATION_RESUMED]:
		_refresh_native_snapshot()

func set_requested_mode(mode:String)->void:
	if mode not in [MODE_SMOOTH_60,MODE_BATTERY_30]:
		push_warning("Unknown performance mode: %s"%mode)
		return
	if requested_mode==mode:
		_recompute_policy()
		return
	requested_mode=mode
	_recompute_policy()

func apply_system_snapshot(next_thermal:String,next_low_power:bool)->void:
	# Public on purpose: native adapters and deterministic tests use one
	# normalized entry point instead of mutating policy fields independently.
	if next_thermal not in [THERMAL_NOMINAL,THERMAL_FAIR,THERMAL_SERIOUS,THERMAL_CRITICAL]:
		next_thermal=THERMAL_NOMINAL
	if thermal_state!=next_thermal:
		thermal_state=next_thermal
		thermal_state_changed.emit(thermal_state)
	if low_power_mode!=next_low_power:
		low_power_mode=next_low_power
		low_power_mode_changed.emit(low_power_mode)
	_recompute_policy()

func report_state(domain:String,label:String,metadata:Dictionary={})->void:
	if domain.is_empty() or label.is_empty():
		return
	var previous:Dictionary=_reported_states.get(domain,{})
	if str(previous.get("label",""))==label and previous.get("metadata",{})==metadata:
		return
	var snapshot:={"label":label,"metadata":metadata.duplicate(true)}
	_reported_states[domain]=snapshot
	reportable_state_changed.emit(domain,label,snapshot.metadata)
	if _bridge and _bridge.has_method("report_state"):
		_bridge.call("report_state",domain,label,snapshot.metadata)

func current_reported_state(domain:String)->Dictionary:
	return (_reported_states.get(domain,{}) as Dictionary).duplicate(true)

func play_haptic(event_id:String,intensity:float=1.0)->void:
	if event_id.is_empty():
		return
	if _bridge and _bridge.has_method("play_haptic"):
		_bridge.call("play_haptic",event_id,clampf(intensity,0.0,1.0))

func native_available()->bool:
	return _bridge!=null

func _bind_native_bridge()->void:
	_bridge=null
	if OS.get_name()=="iOS" and Engine.has_singleton(BRIDGE_NAME):
		_bridge=Engine.get_singleton(BRIDGE_NAME)
		if _bridge.has_signal("thermal_state_changed"):
			_bridge.connect("thermal_state_changed",Callable(self,"_on_native_thermal"))
		if _bridge.has_signal("low_power_mode_changed"):
			_bridge.connect("low_power_mode_changed",Callable(self,"_on_native_low_power"))
		if _bridge.has_signal("memory_warning"):
			_bridge.connect("memory_warning",Callable(self,"_on_native_memory_warning"))

func _refresh_native_snapshot()->void:
	if not _bridge:
		return
	var next_thermal:=thermal_state
	var next_low_power:=low_power_mode
	if _bridge.has_method("get_thermal_state"):
		next_thermal=_normalize_thermal(_bridge.call("get_thermal_state"))
	if _bridge.has_method("is_low_power_mode_enabled"):
		next_low_power=bool(_bridge.call("is_low_power_mode_enabled"))
	apply_system_snapshot(next_thermal,next_low_power)

func _normalize_thermal(value)->String:
	if typeof(value)==TYPE_STRING:
		var text:=str(value).to_lower()
		if text in [THERMAL_NOMINAL,THERMAL_FAIR,THERMAL_SERIOUS,THERMAL_CRITICAL]:
			return text
	var numeric:=int(value)
	match numeric:
		1: return THERMAL_FAIR
		2: return THERMAL_SERIOUS
		3: return THERMAL_CRITICAL
		_: return THERMAL_NOMINAL

func _on_native_thermal(value)->void:
	apply_system_snapshot(_normalize_thermal(value),low_power_mode)

func _on_native_low_power(enabled:bool)->void:
	apply_system_snapshot(thermal_state,enabled)

func _on_native_memory_warning()->void:
	memory_pressure_count+=1
	memory_pressure.emit(memory_pressure_count)

func _recompute_policy()->void:
	var next_pressure:=0
	match thermal_state:
		THERMAL_FAIR:
			next_pressure=1
		THERMAL_SERIOUS:
			next_pressure=2
		THERMAL_CRITICAL:
			next_pressure=3
	if low_power_mode:
		next_pressure=maxi(next_pressure,1)

	var force_30:=requested_mode==MODE_BATTERY_30 or low_power_mode or thermal_state in [THERMAL_SERIOUS,THERMAL_CRITICAL]
	var next_mode:=MODE_BATTERY_30 if force_30 else MODE_SMOOTH_60
	var next_fps:=30 if force_30 else 60
	var changed:=effective_mode!=next_mode or target_fps!=next_fps or quality_pressure!=next_pressure

	effective_mode=next_mode
	target_fps=next_fps
	quality_pressure=next_pressure
	Engine.max_fps=target_fps

	if changed:
		effective_profile_changed.emit(requested_mode,effective_mode,target_fps,quality_pressure)
