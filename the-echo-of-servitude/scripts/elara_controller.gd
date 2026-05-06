extends Node3D

const WALK_SPEED := 2.2
const RUN_SPEED := 4.8
const TURN_SPEED := 10.0
const CAMERA_LERP_SPEED := 6.0
const CAMERA_OFFSET := Vector3(0.0, 1.6, 3.8)
const LOOK_AT_OFFSET := Vector3(0.0, 0.9, 0.0)
const TARGET_HEIGHT_METERS := 1.7

@onready var player: Node3D = $Player
@onready var elara: Node3D = $Player/Elara
@onready var animation_player: AnimationPlayer = $Player/Elara/AnimationPlayer
@onready var camera: Camera3D = $Camera3D

var _current_animation := ""

func _ready() -> void:
	_ensure_input_actions()
	_fit_elara_height(TARGET_HEIGHT_METERS)
	_play_animation("Elara-Standing")
	camera.current = true
	camera.global_position = player.global_position + CAMERA_OFFSET
	camera.look_at(player.global_position + LOOK_AT_OFFSET, Vector3.UP)


func _physics_process(delta: float) -> void:
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var is_moving := input_dir.length() > 0.01

	if is_moving:
		var move_dir := Vector3(input_dir.x, 0.0, input_dir.y).normalized()
		var speed := RUN_SPEED if Input.is_action_pressed("move_run") else WALK_SPEED
		player.global_position += move_dir * speed * delta

		var target_yaw := atan2(move_dir.x, move_dir.z)
		player.rotation.y = lerp_angle(player.rotation.y, target_yaw, TURN_SPEED * delta)

		if speed == RUN_SPEED:
			_play_animation("Elara-Ranning")
		else:
			_play_animation("Elara-Walking")
	else:
		_play_animation("Elara-Standing")

	_update_camera(delta)


func _update_camera(delta: float) -> void:
	var target_position := player.global_position + CAMERA_OFFSET
	camera.global_position = camera.global_position.lerp(target_position, min(1.0, CAMERA_LERP_SPEED * delta))
	camera.look_at(player.global_position + LOOK_AT_OFFSET, Vector3.UP)


func _fit_elara_height(target_height: float) -> void:
	var skeleton := elara.get_node_or_null("Node/Armature/Skeleton3D") as Skeleton3D
	if skeleton == null:
		return

	var min_y := INF
	var max_y := -INF
	for i in skeleton.get_bone_count():
		var pose: Transform3D = skeleton.get_bone_global_pose(i)
		var p: Vector3 = skeleton.global_transform * pose.origin
		min_y = min(min_y, p.y)
		max_y = max(max_y, p.y)

	var current_height := max_y - min_y
	if current_height <= 0.001:
		return

	var s := target_height / current_height
	elara.scale = Vector3.ONE * s


func _play_animation(animation_name: String) -> void:
	if _current_animation == animation_name:
		return
	if not animation_player.has_animation(animation_name):
		return
	_current_animation = animation_name
	animation_player.play(animation_name)


func _ensure_input_actions() -> void:
	_ensure_action("move_forward", [KEY_W, KEY_UP])
	_ensure_action("move_back", [KEY_S, KEY_DOWN])
	_ensure_action("move_left", [KEY_A, KEY_LEFT])
	_ensure_action("move_right", [KEY_D, KEY_RIGHT])
	_ensure_action("move_run", [KEY_SHIFT])


func _ensure_action(action: StringName, keycodes: Array[Key]) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)

	for keycode in keycodes:
		if _action_has_key(action, keycode):
			continue
		var event := InputEventKey.new()
		event.keycode = keycode
		InputMap.action_add_event(action, event)


func _action_has_key(action: StringName, keycode: Key) -> bool:
	for event in InputMap.action_get_events(action):
		if event is InputEventKey and event.keycode == keycode:
			return true
	return false
