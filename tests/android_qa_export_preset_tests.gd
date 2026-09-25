extends SceneTree

var failures:=0

func _init()->void:
	call_deferred("_run")

func _check(condition:bool,message:String)->void:
	if not condition:
		failures+=1
		push_error("FAIL: "+message)

func _run()->void:
	var cfg:=ConfigFile.new()
	var err:=cfg.load("res://export_presets.cfg")
	_check(err==OK,"Android QA export preset file loads")
	if err==OK:
		_check(str(cfg.get_value("preset.0","name",""))=="Android QA","QA preset name is stable")
		_check(str(cfg.get_value("preset.0","platform",""))=="Android","QA preset targets Android")
		_check(bool(cfg.get_value("preset.0","runnable",false)),"Android QA preset is runnable for one-click deploy")
		_check(str(cfg.get_value("preset.0","export_filter",""))=="all_resources","QA export includes project resources")
		_check(bool(cfg.get_value("preset.0.options","architectures/arm64-v8a",false)),"Android QA includes arm64-v8a")
		_check(not bool(cfg.get_value("preset.0.options","architectures/armeabi-v7a",true)),"Android QA excludes legacy ARMv7")
		_check(not bool(cfg.get_value("preset.0.options","architectures/x86",true)),"Android QA excludes x86")
		_check(not bool(cfg.get_value("preset.0.options","architectures/x86_64",true)),"Android QA excludes x86_64")
		_check(str(cfg.get_value("preset.0.options","package/unique_name",""))=="org.shadowborn.chapter0.qa","QA package ID is isolated from any future production ID")
		_check(bool(cfg.get_value("preset.0.options","package/signed",false)),"debug QA APK is configured for signing")
		_check(bool(cfg.get_value("preset.0.options","screen/immersive_mode",false)),"QA build uses immersive mobile presentation")
		_check(str(cfg.get_value("preset.0.options","custom_template/release","")).is_empty(),"QA preset does not pin a release signing/template path")
		_check(bool(ProjectSettings.get_setting("rendering/textures/vram_compression/import_etc2_astc",false)),"Android QA keeps ETC2/ASTC texture import enabled")
	print("Android QA export preset tests complete. failures=%d"%failures)
	quit(1 if failures>0 else 0)
