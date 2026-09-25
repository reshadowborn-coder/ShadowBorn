class_name CombatPresenter
extends Node

signal impact_presented(target_side: String, guarded: bool)

const IMPACT_POOL_SIZE := 4
const IMPACT_LOCAL_POSITION := Vector3(0, 1.1, -0.45)

var shadow_visual: Node3D
var enemy_visual: Node3D
var shadow_origin := Vector3.ZERO
var enemy_origin := Vector3.ZERO
var reduced_motion := false

var _impact_mesh_normal: SphereMesh
var _impact_mesh_guarded: SphereMesh
var _impact_pool: Array[MeshInstance3D] = []
var _impact_tweens: Dictionary = {}
var _impact_cursor := 0

func _ready() -> void:
	_ensure_impact_pool()

func bind_combatants(shadow: Node3D, enemy: Node3D) -> void:
	shadow_visual = shadow
	enemy_visual = enemy
	shadow_origin = shadow.position
	enemy_origin = enemy.position

func clear() -> void:
	shadow_visual = null
	enemy_visual = null
	_reset_impact_pool()

func play_shadow_attack(skill: String, _damage: float, target_guarded: bool) -> void:
	if not is_instance_valid(shadow_visual) or not is_instance_valid(enemy_visual):
		return
	if reduced_motion:
		_impact_flash(enemy_visual, target_guarded)
		return
	var timing: Dictionary = CombatPresentationContract.shadow_timing(skill, false)
	var origin := shadow_visual.position
	var dir := (enemy_visual.global_position - shadow_visual.global_position).normalized()
	var anticipation := origin - dir * (0.20 if skill == "A1" else 0.34)
	var contact := origin + dir * (0.58 if skill == "A1" else 1.05)
	var tween := create_tween()
	tween.tween_property(shadow_visual, "position", anticipation, float(timing["anticipation"])).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(shadow_visual, "position", contact, float(timing["active"])).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	tween.tween_callback(func(): _impact_flash(enemy_visual, target_guarded))
	tween.tween_property(shadow_visual, "position", origin, CombatPresentationContract.remainder_after_contact(timing)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func play_enemy_attack(_damage: float) -> void:
	if not is_instance_valid(shadow_visual) or not is_instance_valid(enemy_visual):
		return
	if reduced_motion:
		_impact_flash(shadow_visual, false)
		return
	var timing: Dictionary = CombatPresentationContract.enemy_timing("ATTACK", false)
	var origin := enemy_visual.position
	var dir := (shadow_visual.global_position - enemy_visual.global_position).normalized()
	var tween := create_tween()
	tween.tween_property(enemy_visual, "position", origin - dir * 0.18, float(timing["anticipation"]))
	tween.tween_property(enemy_visual, "position", origin + dir * 0.48, float(timing["active"])).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	tween.tween_callback(func(): _impact_flash(shadow_visual, false))
	tween.tween_property(enemy_visual, "position", origin, CombatPresentationContract.remainder_after_contact(timing))

func play_enemy_death() -> void:
	if not is_instance_valid(enemy_visual):
		return
	if reduced_motion:
		enemy_visual.scale = Vector3(0.92, 0.92, 0.92)
		return
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(enemy_visual, "rotation_degrees:z", 78.0, 0.28).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(enemy_visual, "position:y", enemy_visual.position.y - 0.55, 0.28)
	tween.tween_property(enemy_visual, "scale", Vector3(0.86, 0.55, 0.86), 0.28)

func _impact_mesh(guarded: bool) -> SphereMesh:
	var cached := _impact_mesh_guarded if guarded else _impact_mesh_normal
	if cached != null:
		return cached

	var sphere := SphereMesh.new()
	sphere.radius = 0.12 if guarded else 0.09
	sphere.height = sphere.radius * 2.0
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(0.75, 0.68, 0.46, 0.95) if guarded else Color(0.72, 0.78, 0.88, 0.92)
	sphere.material = material

	if guarded:
		_impact_mesh_guarded = sphere
	else:
		_impact_mesh_normal = sphere
	return sphere

func _ensure_impact_pool() -> void:
	while _impact_pool.size() < IMPACT_POOL_SIZE:
		var flash := MeshInstance3D.new()
		flash.name = "ImpactFlash_%d" % _impact_pool.size()
		flash.visible = false
		flash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(flash)
		_impact_pool.append(flash)

func _acquire_impact_flash() -> MeshInstance3D:
	_ensure_impact_pool()
	var flash := _impact_pool[_impact_cursor]
	_impact_cursor = (_impact_cursor + 1) % IMPACT_POOL_SIZE

	var key := flash.get_instance_id()
	if _impact_tweens.has(key):
		var previous: Tween = _impact_tweens[key]
		if previous != null:
			previous.kill()
		_impact_tweens.erase(key)

	flash.visible = false
	flash.scale = Vector3.ONE
	flash.transparency = 0.0
	return flash

func _impact_flash(target: Node3D, guarded: bool) -> void:
	if not is_instance_valid(target):
		return

	var flash := _acquire_impact_flash()
	flash.mesh = _impact_mesh(guarded)
	flash.global_position = target.to_global(IMPACT_LOCAL_POSITION)
	flash.visible = true

	var target_side := "shadow" if target == shadow_visual else "enemy"
	emit_signal("impact_presented", target_side, guarded)

	var flash_scale := Vector3(2.0, 2.0, 2.0) if reduced_motion else Vector3(4.0, 4.0, 4.0)
	var flash_time := 0.08 if reduced_motion else 0.14
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(flash, "scale", flash_scale, flash_time)
	tween.tween_property(flash, "transparency", 1.0, flash_time)
	tween.chain().tween_callback(func(): _release_impact_flash(flash))
	_impact_tweens[flash.get_instance_id()] = tween

func _release_impact_flash(flash: MeshInstance3D) -> void:
	if not is_instance_valid(flash):
		return
	_impact_tweens.erase(flash.get_instance_id())
	flash.visible = false
	flash.scale = Vector3.ONE
	flash.transparency = 0.0

func _reset_impact_pool() -> void:
	for tween_value in _impact_tweens.values():
		var tween := tween_value as Tween
		if tween != null:
			tween.kill()
	_impact_tweens.clear()
	for flash in _impact_pool:
		if is_instance_valid(flash):
			flash.visible = false
			flash.scale = Vector3.ONE
			flash.transparency = 0.0

func set_reduced_motion(value: bool) -> void:
	reduced_motion = value

func play_enemy_beat(action: String, damage: float) -> void:
	if action in ["RUSH_PREP", "BRACE_EXIT", "NONE"]:
		if not is_instance_valid(enemy_visual):
			return
		if reduced_motion:
			_impact_flash(enemy_visual, true)
			return
		var timing: Dictionary = CombatPresentationContract.enemy_timing(action, false)
		var origin_scale := enemy_visual.scale
		var pulse_scale := origin_scale * 1.08
		var tween := create_tween()
		tween.tween_property(enemy_visual, "scale", pulse_scale, float(timing["anticipation"])).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(enemy_visual, "scale", origin_scale, maxf(0.0, float(timing["recovery_end"]) - float(timing["anticipation"]))).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		return
	play_enemy_attack(damage)
