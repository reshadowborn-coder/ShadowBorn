class_name PlatformRuntimeService
extends Node

signal performance_policy_changed(effective_fps:int, pressure_state:int, reason:String)
signal quality_pressure_changed(pressure_state:int, reason:String)
signal lifecycle_changed(state:String)
signal memory_pressure_requested(level:int)
signal native_diagnostics_updated(data:Dictionary)
signal haptic_dispatched(event_id:String)

enum PressureState {
	NOMINAL,
	FAIR,
	SERIOUS,
	CRITICAL
}

const NATIVE_SINGLETON := "ShadowbornIOS"
const POLL_INTERVAL_SECONDS := 1.0
const RECOVERY_HOLD_SECONDS := 8.0
const MEMORY_PRESSURE_HOLD_SECONDS := 20.0

const MODE_SMOOTH60 := "smooth60"
const MODE_BATTERY30 := "battery30"

const HAPTIC_POLICIES := {
	"ui_confirm": {"interval_ms":80, "duration_ms":18, "amplitude":0.22},
	"ui_reject": {"interval_ms":140, "duration_ms":28, "amplitude":0.34},
	"light_contact": {"interval_ms":55, "duration_ms":14, "amplitude":0.20},
	"guarded_contact": {"interval_ms":75, "duration_ms":20, "amplitude":0.32},
	"guard_break": {"interval_ms":180, "duration_ms":42, "amplitude":0.72},
	"perfect_timing": {"interval_ms":140, "duration_ms":26, "amplitude":0.48},
	"heavy_impact": {"interval_ms":180, "duration_ms":48, "amplitude":0.82},
	"summon_commit": {"interval_ms":260, "duration_ms":58, "amplitude":0.64},
	"rune_complete": {"interval_ms":220, "duration_ms":44, "amplitude":0.52}
}

var user_performance_mode := MODE_SMOOTH60
var haptics_enabled := true
var haptics_intensity := 1.0

var thermal_state := PressureState.NOMINAL
var low_power_mode := false
var effective_pressure := PressureState.NOMINAL
var effective_fps := 60

var _native_bridge:Object
var _poll_accumulator := 0.0
var _recovery_elapsed := 0.0
var _memory_pressure_remaining := 0.0
var _last_haptic_ms:Dictionary = {}
var _last_diagnostics:Dictionary = {}

func _ready()->void:
	process_mode=Node.PROCESS_MODE_ALWAYS
	_bind_native_bridge()
	_apply_policy("startup")
	set_process(_native_bridge!=null or _memory_pressure_remaining>0.0)

func _bind_native_bridge()->void:
	if Engine.has_singleton(NATIVE_SINGLETON):
		_native_bridge=Engine.get_singleton(NATIVE_SINGLETON)
	else:
		_native_bridge=null

func set_user_performance_mode(mode:String)->void:
	var normalized:=MODE_BATTERY30 if mode==MODE_BATTERY30 else MODE_SMOOTH60
	if normalized==user_performance_mode:
		return
	user_performance_mode=normalized
	_apply_policy("user_mode")

func set_haptics_enabled(value:bool)->void:
	haptics_enabled=value

func set_haptics_intensity(value:float)->void:
	haptics_intensity=clampf(value,0.0,1.0)

static func compute_effective_fps(mode:String, pressure:int, low_power:bool)->int:
	if mode==MODE_BATTERY30:
		return 30
	if low_power or pressure>=PressureState.SERIOUS:
		return 30
	return 60

static func compute_pressure(thermal:int, low_power:bool, memory_floor:int)->int:
	var pressure:=clampi(thermal,PressureState.NOMINAL,PressureState.CRITICAL)
	if low_power:
		pressure=maxi(pressure,PressureState.FAIR)
	return maxi(pressure,clampi(memory_floor,PressureState.NOMINAL,PressureState.CRITICAL))

func get_quality_pressure()->int:
	return effective_pressure

func get_native_diagnostics()->Dictionary:
	var result:=_last_diagnostics.duplicate(true)
	result["native_bridge"]=(_native_bridge!=null)
	result["platform"]=OS.get_name()
	result["user_performance_mode"]=user_performance_mode
	result["effective_fps"]=effective_fps
	result["effective_pressure"]=effective_pressure
	result["thermal_state"]=thermal_state
	result["low_power_mode"]=low_power_mode
	result["memory_pressure_hold_seconds"]=_memory_pressure_remaining
	return result

func request_haptic(event_id:String, intensity:float=1.0)->bool:
	if not haptics_enabled or haptics_intensity<=0.0:
		return false
	var policy:Dictionary=HAPTIC_POLICIES.get(event_id,{})
	if policy.is_empty():
		return false

	var now:=Time.get_ticks_msec()
	var min_interval:=int(policy.get("interval_ms",100))
	var last:=int(_last_haptic_ms.get(event_id,-1000000))
	if now-last<min_interval:
		return false
	_last_haptic_ms[event_id]=now

	var scaled_intensity:=clampf(float(policy.get("amplitude",0.3))*clampf(intensity,0.0,1.0)*haptics_intensity,0.0,1.0)
	var dispatched:=false
	if _native_bridge!=null and _native_bridge.has_method("play_haptic"):
		var native_supported:=true
		if _native_bridge.has_method("supports_haptics"):
			native_supported=bool(_native_bridge.call("supports_haptics"))
		if native_supported:
			_native_bridge.call("play_haptic",event_id,scaled_intensity)
			dispatched=true
	elif OS.get_name() in ["iOS","Android"]:
		Input.vibrate_handheld(int(policy.get("duration_ms",20)),scaled_intensity)
		dispatched=true

	if dispatched:
		haptic_dispatched.emit(event_id)
	return dispatched

func _process(delta:float)->void:
	if _memory_pressure_remaining>0.0:
		_memory_pressure_remaining=maxf(0.0,_memory_pressure_remaining-delta)

	# Recovery hysteresis must continue even on desktop/headless builds where
	# no native iOS bridge exists. Otherwise a simulated/real memory warning
	# could leave the service permanently stuck in SERIOUS pressure.
	var desired_now:=compute_pressure(thermal_state,low_power_mode,_memory_floor())
	if desired_now<effective_pressure:
		_update_effective_pressure(delta,"pressure_recovery")
	elif desired_now>effective_pressure:
		_update_effective_pressure(delta,"runtime_pressure")

	if _native_bridge==null:
		if _memory_pressure_remaining<=0.0 and desired_now>=effective_pressure:
			set_process(false)
		return

	_poll_accumulator+=delta
	if _poll_accumulator<POLL_INTERVAL_SECONDS:
		return
	var elapsed:=_poll_accumulator
	_poll_accumulator=0.0
	_poll_native_environment(elapsed)

func _poll_native_environment(delta:float)->void:
	var observed_thermal:=thermal_state
	var observed_low_power:=low_power_mode
	if _native_bridge.has_method("get_thermal_state"):
		observed_thermal=clampi(int(_native_bridge.call("get_thermal_state")),PressureState.NOMINAL,PressureState.CRITICAL)
	if _native_bridge.has_method("is_low_power_mode_enabled"):
		observed_low_power=bool(_native_bridge.call("is_low_power_mode_enabled"))

	var changed:=observed_thermal!=thermal_state or observed_low_power!=low_power_mode
	thermal_state=observed_thermal
	low_power_mode=observed_low_power

	if _native_bridge.has_method("get_native_diagnostics"):
		var value=_native_bridge.call("get_native_diagnostics")
		if value is Dictionary:
			_last_diagnostics=(value as Dictionary).duplicate(true)
			native_diagnostics_updated.emit(_last_diagnostics.duplicate(true))

	_update_effective_pressure(delta,"native_environment" if changed else "native_poll")

func _memory_floor()->int:
	return PressureState.SERIOUS if _memory_pressure_remaining>0.0 else PressureState.NOMINAL

func _update_effective_pressure(delta:float, reason:String)->void:
	var desired:=compute_pressure(thermal_state,low_power_mode,_memory_floor())
	if desired>effective_pressure:
		_recovery_elapsed=0.0
		_set_effective_pressure(desired,reason)
		return
	if desired==effective_pressure:
		_recovery_elapsed=0.0
		_apply_policy(reason)
		return

	_recovery_elapsed+=delta
	if _recovery_elapsed>=RECOVERY_HOLD_SECONDS:
		_recovery_elapsed=0.0
		_set_effective_pressure(desired,"pressure_recovery")
	else:
		_apply_policy(reason)

func _set_effective_pressure(value:int, reason:String)->void:
	var normalized:=clampi(value,PressureState.NOMINAL,PressureState.CRITICAL)
	if normalized!=effective_pressure:
		effective_pressure=normalized
		quality_pressure_changed.emit(effective_pressure,reason)
	_apply_policy(reason)

func _apply_policy(reason:String)->void:
	var target_fps:=compute_effective_fps(user_performance_mode,effective_pressure,low_power_mode)
	var changed:=target_fps!=effective_fps
	effective_fps=target_fps
	if Engine.max_fps!=effective_fps:
		Engine.max_fps=effective_fps
	if changed or reason in ["startup","user_mode","memory_warning","pressure_recovery"]:
		performance_policy_changed.emit(effective_fps,effective_pressure,reason)

func _notification(what:int)->void:
	match what:
		NOTIFICATION_APPLICATION_FOCUS_OUT:
			lifecycle_changed.emit("focus_out")
		NOTIFICATION_APPLICATION_PAUSED:
			lifecycle_changed.emit("paused")
		NOTIFICATION_APPLICATION_FOCUS_IN:
			lifecycle_changed.emit("focus_in")
		NOTIFICATION_APPLICATION_RESUMED:
			lifecycle_changed.emit("resumed")
		NOTIFICATION_OS_MEMORY_WARNING:
			_memory_pressure_remaining=MEMORY_PRESSURE_HOLD_SECONDS
			memory_pressure_requested.emit(PressureState.SERIOUS)
			set_process(true)
			_update_effective_pressure(0.0,"memory_warning")

func _debug_set_environment(thermal:int, low_power:bool, memory_pressure:bool=false)->void:
	thermal_state=clampi(thermal,PressureState.NOMINAL,PressureState.CRITICAL)
	low_power_mode=low_power
	_memory_pressure_remaining=MEMORY_PRESSURE_HOLD_SECONDS if memory_pressure else 0.0
	_set_effective_pressure(compute_pressure(thermal_state,low_power_mode,_memory_floor()),"debug_environment")
