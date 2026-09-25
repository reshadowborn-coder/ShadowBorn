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
	var f:=FileAccess.open(path,FileAccess.READ)
	if f==null:
		return ""
	var text:=f.get_as_text()
	f.close()
	return text

func _run()->void:
	var project:=_read("res://project.godot")
	var presets:=_read("res://export_presets.cfg")

	_check(project.contains("window/handheld/orientation=4"),"project is locked to sensor-landscape orientation")
	_check(project.contains("window/ios/allow_high_refresh_rate=false"),"iPhone runtime is capped to the authored 60 FPS modes")
	_check(project.contains("window/ios/hide_home_indicator=true"),"iPhone home indicator is hidden during gameplay")
	_check(project.contains("window/ios/hide_status_bar=true"),"iPhone status bar is hidden during gameplay")
	_check(project.contains("window/ios/suppress_ui_gesture=true"),"iPhone system-edge gesture suppression is enabled")
	_check(project.contains("renderer/rendering_device/driver.ios=\"metal\""),"iPhone renderer uses native Metal")

	_check(presets.contains("name=\"iPhone QA\""),"iPhone QA export preset exists")
	_check(presets.contains("platform=\"iOS\""),"iPhone QA preset targets iOS")
	_check(presets.contains("architectures/arm64=true"),"iPhone QA preset exports arm64")
	_check(presets.contains("application/targeted_device_family=0"),"iPhone QA preset targets iPhone only")
	_check(presets.contains("application/min_ios_version=\"16.0\""),"iPhone QA preset requires iOS 16+ for Metal mobile rendering")
	_check(presets.contains("application/bundle_identifier=\"org.shadowborn.chapter0.qa\""),"iPhone QA bundle identifier is stable")
	_check(presets.contains("application/export_project_only=true"),"iPhone QA preset produces an Xcode project before signing")
	_check(presets.contains("application/app_store_team_id=\"\""),"Apple Team ID is intentionally not committed to source control")

	var margins:=MobileSafeArea.logical_margins(
		Vector2(1920,1080),
		Vector2(2796,1290),
		Rect2(132,0,2532,1251)
	)
	_check(margins.x>80.0 and margins.z>80.0,"safe-area conversion protects both landscape cutout edges")
	_check(margins.w>24.0,"safe-area conversion protects the home-indicator edge")
	var fallback:=MobileSafeArea.logical_margins(Vector2.ZERO,Vector2.ZERO,Rect2())
	_check(fallback==Vector4(24,24,24,24),"safe-area conversion has deterministic fallback padding")

	print("iPhone policy tests complete. failures=%d"%failures)
	quit(1 if failures>0 else 0)
