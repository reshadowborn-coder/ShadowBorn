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
	var launch_shell:=_read("res://scripts/ui/launch_shell.gd")
	var platform_runtime:=_read("res://scripts/platform/platform_runtime.gd")

	_check(project.contains("window/handheld/orientation=4"),"project is locked to sensor-landscape orientation")
	_check(project.contains("window/ios/allow_high_refresh_rate=false"),"iPhone runtime is capped to the authored 60 FPS modes")
	_check(project.contains("window/ios/hide_home_indicator=true"),"iPhone home indicator is hidden during gameplay")
	_check(project.contains("window/ios/hide_status_bar=true"),"iPhone status bar is hidden during gameplay")
	_check(project.contains("window/ios/suppress_ui_gesture=true"),"iPhone system-edge gesture suppression is enabled")
	_check(project.contains("PlatformRuntime=\"*res://scripts/platform/platform_runtime.gd\""),"platform runtime control plane is mounted as an autoload")
	_check(project.contains("renderer/rendering_device/driver.ios=\"metal\""),"iPhone renderer uses native Metal")
	_check(project.contains("config/icon=\"res://assets/branding/shadowborn_ios_icon.svg\""),"iPhone export has a single opaque Shadowborn icon source")
	_check(FileAccess.file_exists("res://assets/branding/shadowborn_ios_icon.svg"),"Shadowborn iPhone icon source exists")
	_check(project.contains("boot_splash/show_image=false"),"engine boot uses the clean Shadowborn background without default Godot branding")
	_check(project.contains("boot_splash/bg_color=Color(0.035294, 0.043137, 0.062745, 1)"),"engine boot background matches Shadowborn launch color")
	_check(launch_shell.contains("LAUNCH_BACKGROUND := Color(0.035294, 0.043137, 0.062745, 1.0)"),"LaunchShell background matches the iPhone boot color exactly")

	_check(presets.contains("name=\"iPhone QA\""),"iPhone QA export preset exists")
	_check(presets.contains("platform=\"iOS\""),"iPhone QA preset targets iOS")
	_check(presets.contains("architectures/arm64=true"),"iPhone QA preset exports arm64")
	_check(presets.contains("application/targeted_device_family=0"),"iPhone QA preset targets iPhone only")
	_check(presets.contains("application/min_ios_version=\"16.0\""),"iPhone QA preset requires iOS 16+ for Metal mobile rendering")
	_check(presets.contains("LSSupportsGameMode"),"iPhone export declares Apple Game Mode support")
	_check(presets.contains("capabilities/performance_a12=true"),"iPhone QA requires A12-class graphics or newer")
	_check(presets.contains("capabilities/performance_gaming_tier=false"),"iPhone QA does not require A17 Gaming Tier, preserving iPhone 13 Pro support")
	_check(presets.contains("application/bundle_identifier=\"org.shadowborn.chapter0.qa\""),"iPhone QA bundle identifier is stable")
	_check(presets.contains("application/export_project_only=true"),"iPhone QA preset produces an Xcode project before signing")
	_check(presets.contains("application/app_store_team_id=\"\""),"Apple Team ID is intentionally not committed to source control")
	var iphone_preset_pos:=presets.find("[preset.1]")
	var iphone_preset:=presets.substr(iphone_preset_pos) if iphone_preset_pos>=0 else ""
	_check(iphone_preset.contains("exclude_filter=\"tests/*\""),"iPhone export excludes headless tests and fixtures from the shipped PCK")
	_check(presets.contains("storyboard/custom_image@2x=\"res://assets/branding/shadowborn_ios_launch_pixel.png\""),"iPhone native launch storyboard uses Shadowborn launch asset")
	_check(presets.contains("storyboard/custom_image@3x=\"res://assets/branding/shadowborn_ios_launch_pixel.png\""),"iPhone native launch asset covers @3x devices")
	_check(presets.contains("storyboard/use_custom_bg_color=true"),"iPhone native launch storyboard uses custom background color")
	_check(FileAccess.file_exists("res://assets/branding/shadowborn_ios_launch_pixel.png"),"Shadowborn iPhone launch asset exists")

	_check(game.contains("NOTIFICATION_APPLICATION_PAUSED"),"iPhone suspend notification is handled")
	_check(game.contains("last_committed_state"),"iPhone suspend path keeps a last committed snapshot")
	_check(game.contains("SaveManager.save_state(last_committed_state.duplicate(true))"),"iPhone suspend writes only the committed snapshot")
	_check(game.contains("NOTIFICATION_APPLICATION_RESUMED"),"iPhone resume notification reapplies runtime policy")
	_check(game.contains("NOTIFICATION_OS_MEMORY_WARNING"),"iPhone memory warning is handled without mutating progression")
	_check(game.contains("/root/PlatformRuntime"),"Chapter 0 routes performance intent through the platform runtime service")
	_check(not game.contains("func _apply_performance_mode() -> void:\n\tEngine.max_fps ="),"Chapter 0 no longer directly owns the production frame cap")
	_check(platform_runtime.contains("PressureState"),"platform runtime exposes explicit pressure states")
	_check(platform_runtime.contains("RECOVERY_HOLD_SECONDS"),"platform runtime has recovery hysteresis instead of immediate quality oscillation")
	_check(platform_runtime.contains("request_haptic"),"platform runtime exposes semantic haptic routing")
	_check(controls.contains("MobileSafeArea.current"),"touch controls are positioned from iPhone Safe Area")
	_check(controls.contains("reset_input()"),"touch input can be cleared before iOS suspension")
	_check(hud_layout.contains("MobileSafeArea.current"),"combat HUD is positioned from iPhone Safe Area")

	# iPhone 13 Pro target fixture: 2532x1170 physical landscape pixels.
	# Runtime DisplayServer safe-area data remains authoritative on device.
	var margins:=MobileSafeArea.logical_margins(
		Vector2(1920,1080),
		Vector2(2532,1170),
		Rect2(141,0,2250,1107)
	)
	_check(margins.x>100.0 and margins.z>100.0,"iPhone 13 Pro safe-area conversion protects both landscape cutout edges")
	_check(margins.w>50.0,"iPhone 13 Pro safe-area conversion protects the home-indicator edge")
	var fallback:=MobileSafeArea.logical_margins(Vector2.ZERO,Vector2.ZERO,Rect2())
	_check(fallback==Vector4(24,24,24,24),"safe-area conversion has deterministic fallback padding")

	var target_13pro:=MobileSafeArea.logical_points_to_viewport(44.0,Vector2(1920,1080),Vector2(2532,1170),3.0,80.0)
	var target_2x:=MobileSafeArea.logical_points_to_viewport(44.0,Vector2(1921,1080),Vector2(1334,750),2.0,80.0)
	_check(target_13pro>=120.0,"44pt hit target expands correctly for the iPhone 13 Pro target fixture")
	_check(target_2x>=126.0,"44pt hit target expands correctly for a representative @2x landscape iPhone")
	_check(MobileSafeArea.logical_points_to_viewport(44.0,Vector2.ZERO,Vector2.ZERO,0.0,80.0)==80.0,"hit-target conversion has a deterministic fallback")

	print("iPhone policy tests complete. failures=%d"%failures)
	quit(1 if failures>0 else 0)
