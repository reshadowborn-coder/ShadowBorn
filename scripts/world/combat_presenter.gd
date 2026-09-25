class_name CombatPresenter
extends Node

signal impact_presented(target_side: String, guarded: bool)

var shadow_visual: Node3D
var enemy_visual: Node3D
var shadow_origin := Vector3.ZERO
var enemy_origin := Vector3.ZERO
var reduced_motion:=false
var _impact_mesh_normal:SphereMesh
var _impact_mesh_guarded:SphereMesh

func bind_combatants(shadow: Node3D, enemy: Node3D) -> void:
	shadow_visual = shadow
	enemy_visual = enemy
	shadow_origin = shadow.position
	enemy_origin = enemy.position

func clear() -> void:
	shadow_visual = null
	enemy_visual = null

func play_shadow_attack(skill: String, _damage: float, target_guarded: bool) -> void:
	if not is_instance_valid(shadow_visual) or not is_instance_valid(enemy_visual):
		return
	if reduced_motion:
		_impact_flash(enemy_visual,target_guarded)
		return
	var timing: Dictionary = CombatPresentationContract.shadow_timing(skill,false)
	var origin := shadow_visual.position
	var dir := (enemy_visual.global_position - shadow_visual.global_position).normalized()
	var anticipation := origin - dir * (0.20 if skill == "A1" else 0.34)
	var contact := origin + dir * (0.58 if skill == "A1" else 1.05)
	var t := create_tween()
	t.tween_property(shadow_visual,"position",anticipation,float(timing["anticipation"])).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(shadow_visual,"position",contact,float(timing["active"])).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	t.tween_callback(func(): _impact_flash(enemy_visual,target_guarded))
	t.tween_property(shadow_visual,"position",origin,CombatPresentationContract.remainder_after_contact(timing)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func play_enemy_attack(_damage: float) -> void:
	if not is_instance_valid(shadow_visual) or not is_instance_valid(enemy_visual):
		return
	if reduced_motion:
		_impact_flash(shadow_visual,false)
		return
	var timing: Dictionary = CombatPresentationContract.enemy_timing("ATTACK",false)
	var origin := enemy_visual.position
	var dir := (shadow_visual.global_position - enemy_visual.global_position).normalized()
	var t := create_tween()
	t.tween_property(enemy_visual,"position",origin-dir*0.18,float(timing["anticipation"]))
	t.tween_property(enemy_visual,"position",origin+dir*0.48,float(timing["active"])).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	t.tween_callback(func(): _impact_flash(shadow_visual,false))
	t.tween_property(enemy_visual,"position",origin,CombatPresentationContract.remainder_after_contact(timing))

func play_enemy_death() -> void:
	if not is_instance_valid(enemy_visual): return
	if reduced_motion:
		enemy_visual.scale=Vector3(0.92,0.92,0.92)
		return
	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(enemy_visual, "rotation_degrees:z", 78.0, 0.28).set_trans(Tween.TRANS_QUAD)
	t.tween_property(enemy_visual, "position:y", enemy_visual.position.y - 0.55, 0.28)
	t.tween_property(enemy_visual, "scale", Vector3(0.86,0.55,0.86), 0.28)

func _impact_mesh(guarded:bool)->SphereMesh:
	var cached:=_impact_mesh_guarded if guarded else _impact_mesh_normal
	if cached!=null:
		return cached
	var sphere:=SphereMesh.new()
	sphere.radius=0.12 if guarded else 0.09
	sphere.height=sphere.radius*2.0
	var mat:=StandardMaterial3D.new()
	mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color=Color(0.75,0.68,0.46,0.95) if guarded else Color(0.72,0.78,0.88,0.92)
	sphere.material=mat
	if guarded:
		_impact_mesh_guarded=sphere
	else:
		_impact_mesh_normal=sphere
	return sphere

func _impact_flash(target: Node3D, guarded: bool) -> void:
	if not is_instance_valid(target): return
	var flash := MeshInstance3D.new()
	flash.name = "ImpactFlash"
	flash.mesh=_impact_mesh(guarded)
	target.add_child(flash); flash.position = Vector3(0,1.1,-0.45)
	var target_side := "shadow" if target == shadow_visual else "enemy"
	emit_signal("impact_presented",target_side,guarded)
	var t := create_tween(); t.set_parallel(true)
	var flash_scale:=Vector3(2.0,2.0,2.0) if reduced_motion else Vector3(4.0,4.0,4.0)
	var flash_time:=0.08 if reduced_motion else 0.14
	t.tween_property(flash,"scale",flash_scale,flash_time)
	t.tween_property(flash,"transparency",1.0,flash_time)
	t.chain().tween_callback(flash.queue_free)


func set_reduced_motion(value:bool)->void:
	reduced_motion=value


func play_enemy_beat(action:String, damage:float)->void:
	if action in ["RUSH_PREP","BRACE_EXIT","NONE"]:
		if not is_instance_valid(enemy_visual):
			return
		if reduced_motion:
			_impact_flash(enemy_visual,true)
			return
		var timing: Dictionary = CombatPresentationContract.enemy_timing(action,false)
		var origin_scale:=enemy_visual.scale
		var pulse_scale:=origin_scale*1.08
		var t:=create_tween()
		t.tween_property(enemy_visual,"scale",pulse_scale,float(timing["anticipation"])).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		t.tween_property(enemy_visual,"scale",origin_scale,maxf(0.0,float(timing["recovery_end"])-float(timing["anticipation"]))).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		return
	play_enemy_attack(damage)
