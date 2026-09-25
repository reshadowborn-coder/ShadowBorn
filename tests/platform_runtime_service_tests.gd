extends SceneTree

var failures:=0

func _init()->void:
	call_deferred("_run")

func _check(condition:bool,message:String)->void:
	if condition:
		print("PASS: "+message)
	else:
		failures+=1
		push_error("FAIL: "+message)

func _read(path:String)->String:
	var file:=FileAccess.open(path,FileAccess.READ)
	return file.get_as_text() if file else ""

func _run()->void:
	var service:=root.get_node_or_null("PlatformRuntime") as PlatformRuntimeService
	_check(service!=null,"PlatformRuntime autoload exists")
	if service==null:
		quit(1)
		return

	service.apply_system_snapshot(PlatformRuntimeService.THERMAL_NOMINAL,false)
	service.set_requested_mode(PlatformRuntimeService.MODE_SMOOTH_60)
	_check(service.target_fps==60 and service.effective_mode=="smooth60","nominal smooth mode targets 60 FPS")
	_check(service.effective_reason=="nominal","nominal smooth mode records a nominal effective reason")
	_check(Engine.max_fps==60,"PlatformRuntime is the single effective FPS owner")

	service.apply_system_snapshot(PlatformRuntimeService.THERMAL_FAIR,false)
	_check(service.target_fps==60 and service.quality_pressure==1,"fair thermal state keeps 60 FPS but raises cosmetic pressure")
	_check(service.effective_reason=="thermal_fair","fair thermal state records the correct policy reason")

	service.apply_system_snapshot(PlatformRuntimeService.THERMAL_SERIOUS,false)
	_check(service.target_fps==30 and service.quality_pressure==2,"serious thermal state forces controlled 30 FPS fallback")
	_check(service.effective_reason=="thermal_serious","serious thermal state records the correct policy reason")

	service.apply_system_snapshot(PlatformRuntimeService.THERMAL_CRITICAL,false)
	_check(service.target_fps==30 and service.quality_pressure==3,"critical thermal state raises maximum quality pressure")
	_check(service.effective_reason=="thermal_critical","critical thermal state records the correct policy reason")

	service.apply_system_snapshot(PlatformRuntimeService.THERMAL_NOMINAL,true)
	_check(service.target_fps==30 and service.quality_pressure>=1,"Low Power Mode forces resilient 30 FPS without changing gameplay semantics")
	_check(service.effective_reason=="low_power","Low Power Mode records a low-power effective reason")

	service.apply_system_snapshot(PlatformRuntimeService.THERMAL_NOMINAL,false)
	service.set_requested_mode(PlatformRuntimeService.MODE_BATTERY_30)
	_check(service.target_fps==30 and service.effective_mode=="battery30","explicit battery mode stays 30 FPS under nominal conditions")
	_check(service.quality_pressure>=1,"explicit battery mode also reduces optional presentation cost")
	_check(service.effective_reason=="user_battery","explicit battery mode records a user-battery effective reason")

	service.set_requested_mode(PlatformRuntimeService.MODE_SMOOTH_60)
	var state_counter:={"count":0}
	var callback:=func(_domain:String,_label:String,_metadata:Dictionary): state_counter["count"]=int(state_counter["count"])+1
	service.reportable_state_changed.connect(callback)
	service.report_state("com.shadowborn.presentation","smooth60",{"reduced_motion":false})
	service.report_state("com.shadowborn.presentation","smooth60",{"reduced_motion":false})
	service.report_state("com.shadowborn.presentation","battery30",{"reduced_motion":false})
	_check(int(state_counter["count"])==2,"reportable state transitions deduplicate identical state/metadata pairs")
	_check(str(service.current_reported_state("com.shadowborn.presentation").get("label",""))=="battery30","latest reportable state is retained for diagnostics")
	service.report_state("com.shadowborn.presentation","privacy_probe",{"reduced_motion":true,"player_name":"must_not_escape","nested":{"unsafe":true}})
	var privacy_state:=service.current_reported_state("com.shadowborn.presentation")
	var privacy_metadata:Dictionary=privacy_state.get("metadata",{})
	_check(privacy_metadata.size()==1 and privacy_metadata.get("reduced_motion",false)==true,"reporting schema drops unregistered or structured metadata before native forwarding")
	service.reportable_state_changed.disconnect(callback)

	var memory_counter:={"count":0}
	var memory_callback:=func(_count:int): memory_counter["count"]=int(memory_counter["count"])+1
	service.memory_pressure.connect(memory_callback)
	service._notification(NOTIFICATION_OS_MEMORY_WARNING)
	_check(int(memory_counter["count"])==1,"OS memory warning is centralized through PlatformRuntime")
	service.memory_pressure.disconnect(memory_callback)

	var chapter0_source:=_read("res://scripts/world/chapter00_game.gd")
	var chapter1_source:=_read("res://scripts/world/chapter01_game.gd")
	_check(not chapter0_source.contains("Engine.max_fps"),"Chapter00Game no longer owns engine FPS directly")
	_check(not chapter0_source.contains("NOTIFICATION_OS_MEMORY_WARNING"),"Chapter00Game no longer owns OS memory-warning routing")
	_check(chapter0_source.contains("PlatformRuntime.report_state"),"Chapter00Game emits semantic performance context instead of native API calls")
	_check(not chapter1_source.contains("Engine.max_fps"),"Chapter01Game no longer owns engine FPS directly")
	_check(not chapter1_source.contains("NOTIFICATION_OS_MEMORY_WARNING"),"Chapter01Game no longer owns OS memory-warning routing")
	_check(chapter1_source.contains("PlatformRuntime.memory_pressure.connect(_on_platform_memory_pressure)"),"Chapter01Game consumes semantic memory pressure through PlatformRuntime")
	_check(chapter1_source.contains("PlatformRuntime.report_state"),"Chapter01Game emits semantic gameplay/encounter context instead of native API calls")

	service.apply_system_snapshot(PlatformRuntimeService.THERMAL_NOMINAL,false)
	service.set_requested_mode(PlatformRuntimeService.MODE_SMOOTH_60)
	print("Platform runtime architecture tests complete. failures=%d"%failures)
	quit(1 if failures>0 else 0)
