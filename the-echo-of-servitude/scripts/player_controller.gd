extends CharacterBody3D

@export var walk_speed: float = 3.0
@export var run_speed: float = 6.0
@export var acceleration: float = 10.0
@export var deceleration: float = 12.0
@export var gravity_scale: float = 1.0
@export var deadzone: float = 0.15

@onready var elara_idle: Node3D = $Visuals/ElaraIdle
@onready var elara_walk: Node3D = $Visuals/ElaraWalk
@onready var elara_run: Node3D = $Visuals/ElaraRun

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

func _ready() -> void:
	_play_embedded_animations(elara_idle)
	_play_embedded_animations(elara_walk)
	_play_embedded_animations(elara_run)

func _physics_process(delta: float) -> void:
	var input_vector := _get_movement_input()
	var has_input := input_vector.length() > deadzone
	var running := has_input and _is_run_pressed()
	var target_speed := run_speed if running else walk_speed

	if has_input:
		var direction := Vector3(input_vector.x, 0.0, input_vector.y).normalized()
		velocity.x = move_toward(velocity.x, direction.x * target_speed, acceleration * delta)
		velocity.z = move_toward(velocity.z, direction.z * target_speed, acceleration * delta)
		look_at(global_position + Vector3(velocity.x, 0.0, velocity.z), Vector3.UP)
	else:
		velocity.x = move_toward(velocity.x, 0.0, deceleration * delta)
		velocity.z = move_toward(velocity.z, 0.0, deceleration * delta)

	if not is_on_floor():
		velocity.y -= _gravity * gravity_scale * delta
	else:
		velocity.y = 0.0

	move_and_slide()
	_update_visual_state(has_input, running)

func _get_movement_input() -> Vector2:
	var keyboard := _get_keyboard_input()
	var stick := _get_left_stick_input()
	var combined := keyboard

	if stick.length() > deadzone:
		combined = stick

	if combined.length() > 1.0:
		combined = combined.normalized()

	return combined

func _get_keyboard_input() -> Vector2:
	var left := Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT)
	var right := Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT)
	var forward := Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP)
	var backward := Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN)

	var x := float(int(right) - int(left))
	var y := float(int(backward) - int(forward))
	var keyboard := Vector2(x, y)

	if keyboard.length() > 1.0:
		keyboard = keyboard.normalized()

	return keyboard

func _get_left_stick_input() -> Vector2:
	var joypads := Input.get_connected_joypads()
	if joypads.is_empty():
		return Vector2.ZERO

	var joy_id: int = joypads[0]
	var x := Input.get_joy_axis(joy_id, JOY_AXIS_LEFT_X)
	var y := Input.get_joy_axis(joy_id, JOY_AXIS_LEFT_Y)
	var stick := Vector2(x, y)

	if stick.length() <= deadzone:
		return Vector2.ZERO

	return stick

func _is_run_pressed() -> bool:
	if Input.is_key_pressed(KEY_SHIFT):
		return true

	for joy_id in Input.get_connected_joypads():
		if Input.is_joy_button_pressed(joy_id, JOY_BUTTON_B):
			return true
		if Input.get_joy_axis(joy_id, JOY_AXIS_TRIGGER_RIGHT) > 0.5:
			return true

	return false

func _update_visual_state(has_input: bool, running: bool) -> void:
	elara_idle.visible = not has_input
	elara_walk.visible = has_input and not running
	elara_run.visible = has_input and running

func _play_embedded_animations(root: Node) -> void:
	for child in root.get_children():
		if child is AnimationPlayer:
			var animation_player := child as AnimationPlayer
			var names := animation_player.get_animation_list()
			if not names.is_empty():
				animation_player.play(names[0])
		_play_embedded_animations(child)
