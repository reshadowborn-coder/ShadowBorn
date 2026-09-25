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

func _run()->void:
	var service:=PlatformRuntimeService.new()
	root.add_child(service)
	await process_frame

	_check(PlatformRuntimeService.compute_effective_fps("smooth60",PlatformRuntimeService.PressureState.NOMINAL,false)==60,"smooth60 stays at 60 under nominal conditions")
	_check(PlatformRuntimeService.compute_effective_fps("battery30",PlatformRuntimeService.PressureState.NOMINAL,false)==30,"battery30 stays at 30")
	_check(PlatformRuntimeService.compute_effective_fps("smooth60",PlatformRuntimeService.PressureState.SERIOUS,false)==30,"serious thermal pressure forces 30")
	_check(PlatformRuntimeService.compute_effective_fps("smooth60",PlatformRuntimeService.PressureState.NOMINAL,true)==30,"Low Power Mode forces resilient 30 profile")
	_check(PlatformRuntimeService.compute_pressure(PlatformRuntimeService.PressureState.FAIR,false,PlatformRuntimeService.PressureState.NOMINAL)==PlatformRuntimeService.PressureState.FAIR,"thermal pressure maps directly")
	_check(PlatformRuntimeService.compute_pressure(PlatformRuntimeService.PressureState.NOMINAL,true,PlatformRuntimeService.PressureState.NOMINAL)==PlatformRuntimeService.PressureState.FAIR,"Low Power Mode raises at least fair pressure")
	_check(PlatformRuntimeService.compute_pressure(PlatformRuntimeService.PressureState.NOMINAL,false,PlatformRuntimeService.PressureState.SERIOUS)==PlatformRuntimeService.PressureState.SERIOUS,"memory warning establishes serious pressure floor")

	service.set_user_performance_mode("smooth60")
	service._debug_set_environment(PlatformRuntimeService.PressureState.NOMINAL,false)
	_check(service.effective_fps==60 and Engine.max_fps==60,"service owns the 60 FPS request")

	service._debug_set_environment(PlatformRuntimeService.PressureState.SERIOUS,false)
	_check(service.effective_fps==30 and Engine.max_fps==30,"serious pressure downgrades the engine cap")
	_check(service.get_quality_pressure()==PlatformRuntimeService.PressureState.SERIOUS,"serious pressure is exposed to presentation systems")

	service._debug_set_environment(PlatformRuntimeService.PressureState.NOMINAL,false,true)
	_check(service.get_quality_pressure()==PlatformRuntimeService.PressureState.SERIOUS,"memory pressure creates a serious quality floor")
	_check(float(service.get_native_diagnostics().memory_pressure_hold_seconds)>0.0,"diagnostics expose active memory-pressure hold")

	service.set_user_performance_mode("battery30")
	service._debug_set_environment(PlatformRuntimeService.PressureState.NOMINAL,false)
	_check(service.effective_fps==30,"user battery mode remains 30 after pressure clears")

	service.set_user_performance_mode("not_a_real_mode")
	_check(service.user_performance_mode=="smooth60","unknown mode normalizes safely to smooth60")

	service.set_haptics_enabled(false)
	_check(not service.request_haptic("heavy_impact"),"disabled haptics never dispatch")
	_check(not service.request_haptic("unknown_event"),"unknown semantic haptic ids are rejected")

	service.queue_free()
	await process_frame
	Engine.max_fps=0
	print("Platform runtime policy tests complete. failures=%d"%failures)
	quit(1 if failures>0 else 0)
