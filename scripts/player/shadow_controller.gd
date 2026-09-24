class_name ShadowController
extends CharacterBody3D

@export var move_speed := 3.6
@export var acceleration := 12.0
var input_enabled := true
var virtual_direction:=Vector2.ZERO

func set_virtual_direction(direction:Vector2)->void:
	virtual_direction=direction.limit_length(1.0)

func set_input_enabled(value:bool)->void:
	input_enabled=value
	if not value:
		virtual_direction=Vector2.ZERO

func _physics_process(delta: float) -> void:
	if not input_enabled:
		velocity.x = move_toward(velocity.x, 0.0, acceleration * delta)
		velocity.z = move_toward(velocity.z, 0.0, acceleration * delta)
		move_and_slide()
		return

	var keyboard:=Input.get_vector("ui_left","ui_right","ui_up","ui_down")
	var v:=virtual_direction if virtual_direction.length_squared()>0.001 else keyboard
	var target := Vector3(v.x, 0.0, v.y) * move_speed
	velocity.x = move_toward(velocity.x, target.x, acceleration * delta)
	velocity.z = move_toward(velocity.z, target.z, acceleration * delta)
	move_and_slide()
