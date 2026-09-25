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
	if file==null:
		return ""
	var result:=file.get_as_text()
	file.close()
	return result

func _run()->void:
	var header:=_read("res://native/ios/ShadowbornIOS/shadowborn_ios.h")
	var implementation:=_read("res://native/ios/ShadowbornIOS/shadowborn_ios.mm")
	var module:=_read("res://native/ios/ShadowbornIOS/shadowborn_ios_module.cpp")
	var gdip:=_read("res://native/ios/ShadowbornIOS/ShadowbornIOS.gdip.in")
	var build_script:=_read("res://native/ios/ShadowbornIOS/build_xcframework.sh")

	for method in ["get_thermal_state","is_low_power_mode_enabled","supports_haptics","play_haptic","get_native_diagnostics"]:
		_check(header.contains(method),"native bridge declares "+method)
		_check(implementation.contains(method),"native bridge implements "+method)

	_check(implementation.contains("CHHapticEngine capabilitiesForHardware"),"haptic support uses public Core Haptics capability detection")
	_check(implementation.contains("UIImpactFeedbackGenerator"),"native bridge keeps UIKit impact generators behind the platform boundary")
	_check(implementation.contains("prepare]"),"impact generators are explicitly prepared for low-latency reuse")
	_check(not implementation.contains("_feedbackSupportLevel"),"native bridge does not use private haptic capability APIs")
	_check(module.contains("Engine::get_singleton()->add_singleton"),"native bridge registers one Godot engine singleton")
	_check(module.contains("\"ShadowbornIOS\""),"native singleton name matches PlatformRuntime contract")
	_check(gdip.contains("CoreHaptics.framework"),"plugin contract links CoreHaptics explicitly")
	_check(not FileAccess.file_exists("res://ios/plugins/shadowborn_ios/ShadowbornIOS.gdip"),"unverified native plugin is not auto-detected by Godot")
	_check(build_script.contains("godot_version=4.4.1-stable"),"native build artifact records the exact Godot header version")
	_check(build_script.contains("-create-xcframework"),"native build produces XCFramework artifacts")
	_check(not implementation.contains("Chapter00"),"native bridge has no Chapter 0 dependency")
	_check(not implementation.contains("SaveManager"),"native bridge has no save-system dependency")
	_check(not implementation.contains("Encounter"),"native bridge has no combat-controller dependency")

	print("iOS native bridge contract tests complete. failures=%d"%failures)
	quit(1 if failures>0 else 0)
