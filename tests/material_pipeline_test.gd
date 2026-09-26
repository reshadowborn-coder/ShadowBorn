extends SceneTree

const MaterialLibrary = preload("res://scripts/presentation/act0_material_library.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var has_maps := MaterialLibrary.has_cemetery_cobble()
	var material := MaterialLibrary.create_cemetery_cobble()
	if has_maps:
		if not (material is ORMMaterial3D):
			push_error("Production cobble maps exist but ORMMaterial3D was not created")
			quit(1)
		print("PASS: production cemetery cobble uses ORMMaterial3D")
	else:
		if material != null:
			push_error("Material library must return null when production maps are incomplete")
			quit(1)
		print("PASS: production cemetery cobble cleanly falls back while maps are absent")
	quit(0)
