class_name ShadowController
extends CharacterBody3D

@export var move_speed := 3.6
@export var acceleration := 12.0
var input_enabled := true

func _physics_process(delta: float) -> void:
	if not input_enabled:
		velocity.x = move_toward(velocity.x, 0.0, acceleration * delta)
		velocity.z = move_toward(velocity.z, 0.0, acceleration * delta)
		move_and_slide(); return
	var v := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var target := Vector3(v.x, 0.0, v.y) * move_speed
	velocity.x = move_toward(velocity.x, target.x, acceleration * delta)
	velocity.z = move_toward(velocity.z, target.z, acceleration * delta)
	move_and_slide()
