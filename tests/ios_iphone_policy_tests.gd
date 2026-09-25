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
	var game:=_read("res://scripts/world/chapter00_game.gd")
	var controls:=_read("res://scripts/ui/mobile_controls.gd")
	var hud_layout:=_read("res://scripts/ui/iphone_ui_layout.gd")

	_check(project.contains("window/handheld/orientation=4"),"project is locked to sensor-landscape orientation")
	_check(project.contains("window/ios/allow_high_refresh_rate=false"),"iPhone runtime is capped to the authored 60 FPS modes")
	_check(project.contains("window/ios/hide_home_indicator=true"),"iPhone home indicator is hidden during gameplay")
	_check(project.contains("window/ios/hide_status_bar=true"),"iPhone status bar is hidden during gameplay")
	_check(project.contains("window/ios/suppress_ui_gesture=true"),"iPhone system-edge gesture suppression is enabled")
	_check(project.contains("renderer/rendering_device/driver.ios=\"metal\""),"iPhone renderer uses native Metal")
	_check(project.contains("config/icon=\"res://assets/branding/shadowborn_ios_icon.svg\""),"iPhone export has a single opaque Shadowborn icon source")
	_check(FileAccess.file_exists("res://assets/branding/shadowborn_ios_icon.svg"),"Shadowborn iPhone icon source exists")
	_check(project.contains("boot_splash/show_image=false"),"engine boot uses the clean Shadowborn background without default Godot branding")
	_check(project.contains("boot_splash/bg_color=Color(0.035294, 0.043137, 0.062745, 1)"),"engine boot background matches Shadowborn launch color")

	_check(presets.contains("name=\"iPhone QA\""),"iPhone QA export preset exists")
	_check(presets.contains("platform=\"iOS\""),"iPhone QA preset targets iOS")
	_check(presets.contains("architectures/arm64=true"),"iPhone QA preset exports arm64")
	_check(presets.contains("application/targeted_device_family=0"),"iPhone QA preset targets iPhone only")
	_check(presets.contains("application/min_ios_version=\"16.0\""),"iPhone QA preset requires iOS 16+ for Metal mobile rendering")
	_check(presets.contains("application/bundle_identifier=\"org.shadowborn.chapter0.qa\""),"iPhone QA bundle identifier is stable")
	_check(presets.contains("application/export_project_only=true"),"iPhone QA preset produces an Xcode project before signing")
	_check(presets.contains("application/app_store_team_id=\"\""),"Apple Team ID is intentionally not committed to source control")
	_check(presets.contains("storyboard/custom_image@2x=\"res://assets/branding/shadowborn_ios_launch_pixel.png\""),"iPhone native launch storyboard uses Shadowborn launch asset")
	_check(presets.contains("storyboard/custom_image@3x=\"res://assets/branding/shadowborn_ios_launch_pixel.png\""),"iPhone native launch asset covers @3x devices")
	_check(presets.contains("storyboard/use_custom_bg_color=true"),"iPhone native launch storyboard uses custom background color")
	_check(FileAccess.file_exists("res://assets/branding/shadowborn_ios_launch_pixel.png"),"Shadowborn iPhone launch asset exists")

	_check(game.contains("NOTIFICATION_APPLICATION_PAUSED"),"iPhone suspend notification is handled")
	_check(game.contains("last_committed_state"),"iPhone suspend path keeps a last committed snapshot")
	_check(game.contains("SaveManager.save_state(last_committed_state.duplicate(true))"),"iPhone suspend writes only the committed snapshot")
	_check(game.contains("NOTIFICATION_APPLICATION_RESUMED"),"iPhone resume notification reapplies runtime policy")
	_check(game.contains("NOTIFICATION_OS_MEMORY_WARNING"),"iPhone memory warning is handled without mutating progression")
	_check(controls.contains("MobileSafeArea.current"),"touch controls are positioned from iPhone Safe Area")
	_check(controls.contains("reset_input()"),"touch input can be cleared before iOS suspension")
	_check(hud_layout.contains("MobileSafeArea.current"),"combat HUD is positioned from iPhone Safe Area")

	var margins:=MobileSafeArea.logical_margins(
		Vector2(1920,1080),
		Vector2(2796,1290),
		Rect2(132,0,2532,1251)
	)
	_check(margins.x>80.0 and margins.z>80.0,"safe-area conversion protects both landscape cutout edges")
	_check(margins.w>24.0,"safe-area conversion protects the home-indicator edge")
	var fallback:=MobileSafeArea.logical_margins(Vector2.ZERO,Vector2.ZERO,Rect2())
	_check(fallback==Vector4(24,24,24,24),"safe-area conversion has deterministic fallback padding")

	var target_3x:=MobileSafeArea.logical_points_to_viewport(44.0,Vector2(2341,1080),Vector2(2796,1290),3.0,80.0)
	var target_2x:=MobileSafeArea.logical_points_to_viewport(44.0,Vector2(1921,1080),Vector2(1334,750),2.0,80.0)
	_check(target_3x>=110.0,"44pt hit target expands correctly for a representative @3x landscape iPhone")
	_check(target_2x>=126.0,"44pt hit target expands correctly for a representative @2x landscape iPhone")
	_check(MobileSafeArea.logical_points_to_viewport(44.0,Vector2.ZERO,Vector2.ZERO,0.0,80.0)==80.0,"hit-target conversion has a deterministic fallback")

	print("iPhone policy tests complete. failures=%d"%failures)
	quit(1 if failures>0 else 0)
