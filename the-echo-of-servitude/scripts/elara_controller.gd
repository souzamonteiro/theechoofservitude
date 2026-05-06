extends CharacterBody3D
## ElaraController – third-person character controller.
##
## Vertical position is handled ENTIRELY by Godot physics (gravity + CharacterBody3D).
## No manual Y-axis manipulation exists anywhere in this script.
##
## Controls:
##   WASD / Arrow keys  – walk     Shift – run    Space – jump    C – crouch
##   Mouse left-click   – capture mouse for camera    Esc – release

const WALK_SPEED      := 3.5
const RUN_SPEED       := 7.0
const JUMP_VELOCITY   := 6.0
const GRAVITY         := -20.0
const CAM_SENSITIVITY := 0.003
const TURN_SPEED      := 12.0
const DECELERATION    := 18.0
@export_range(0.0, 0.30, 0.01) var idle_height_percent := 0.10
@export var elara_visual_height_m := 1.7

const ANIM_IDLE   := "Elara-Standing"
const ANIM_WALK   := "Elara-Walking"
const ANIM_RUN    := "Elara-Ranning"
const ANIM_JUMP   := "Elara-Jumping"
const ANIM_CROUCH := "Elara-Squat"

@onready var model      : Node3D      = $ElaraModel
@onready var camera_arm : SpringArm3D = $CameraArm
@onready var camera     : Camera3D    = $CameraArm/Camera3D

var _anim             : AnimationPlayer = null
var _mouse_captured   : bool = false
var _current_anim     : String = ""
# Locked local transform of the visual mesh — set once in _ready and restored
# every physics frame so animation clips cannot move the mesh node itself.
var _model_local_pos  : Vector3 = Vector3.ZERO
var _model_local_scale: Vector3 = Vector3.ONE


func _ready() -> void:
	# Capture the artist-positioned local transform before any animation plays.
	_model_local_pos   = model.position
	_model_local_scale = model.scale

	_anim = _find_anim_player(model)
	if _anim == null:
		push_warning("ElaraController: AnimationPlayer not found inside model.")
	else:
		_strip_scale_tracks()
		_force_loop(ANIM_IDLE)
		_force_loop(ANIM_WALK)
		_force_loop(ANIM_RUN)
		_play_anim(ANIM_IDLE)

	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

# ── Input ─────────────────────────────────────────────────────────────────────
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
			_mouse_captured = true
	if event is InputEventKey:
		if event.keycode == KEY_ESCAPE:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
			_mouse_captured = false
	if _mouse_captured and event is InputEventMouseMotion:
		camera_arm.rotation.y -= event.relative.x * CAM_SENSITIVITY
		camera_arm.rotation.x = clampf(
			camera_arm.rotation.x - event.relative.y * CAM_SENSITIVITY,
			-PI / 3.0, -0.05
		)


# ── Physics loop ──────────────────────────────────────────────────────────────
func _physics_process(delta: float) -> void:
	# Lock the visual mesh local transform so animation clips cannot shift
	# the node — only bones should move.
	model.position = _model_local_pos + Vector3(0.0, _get_idle_visual_offset(), 0.0)
	model.scale    = _model_local_scale

	# Gravity — CharacterBody3D floor detection keeps Elara grounded.
	if not is_on_floor():
		velocity.y += GRAVITY * delta

	# Horizontal input
	var move := Vector2.ZERO
	if _key(&"move_forward", KEY_W, KEY_UP):    move.y -= 1.0
	if _key(&"move_back",    KEY_S, KEY_DOWN):  move.y += 1.0
	if _key(&"move_left",    KEY_A, KEY_LEFT):  move.x -= 1.0
	if _key(&"move_right",   KEY_D, KEY_RIGHT): move.x += 1.0

	var running := Input.is_key_pressed(KEY_SHIFT)
	var speed   := RUN_SPEED if running else WALK_SPEED

	if move != Vector2.ZERO:
		move = move.normalized()
		var yaw   := camera_arm.rotation.y
		var fwd   := Vector3(-sin(yaw), 0.0, -cos(yaw))
		var right := Vector3( cos(yaw), 0.0, -sin(yaw))
		var dir   := (fwd * (-move.y) + right * move.x).normalized()

		velocity.x = dir.x * speed
		velocity.z = dir.z * speed
		model.rotation.y = lerp_angle(
			model.rotation.y, atan2(dir.x, dir.z), TURN_SPEED * delta
		)

		_play_anim(
			ANIM_JUMP if not is_on_floor() else (ANIM_RUN if running else ANIM_WALK)
		)
	else:
		velocity.x = move_toward(velocity.x, 0.0, DECELERATION * delta)
		velocity.z = move_toward(velocity.z, 0.0, DECELERATION * delta)
		if is_on_floor():
			_play_anim(ANIM_CROUCH if Input.is_key_pressed(KEY_C) else ANIM_IDLE)

	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY
		_play_anim(ANIM_JUMP)

	move_and_slide()

	# Restart clips that finished (safety for non-looped imports).
	if _anim != null and not _anim.is_playing():
		if move != Vector2.ZERO:
			_play_anim(ANIM_RUN if running else ANIM_WALK)
		else:
			_play_anim(ANIM_IDLE)


# ── Animation helpers ─────────────────────────────────────────────────────────
func _play_anim(anim_name: String) -> void:
	if _anim == null or _current_anim == anim_name:
		return
	if _anim.has_animation(anim_name):
		_anim.play(anim_name)
		_current_anim = anim_name
	else:
		push_warning("ElaraController: animation '%s' not found." % anim_name)


func _force_loop(anim_name: String) -> void:
	if _anim == null or not _anim.has_animation(anim_name):
		return
	var clip := _anim.get_animation(anim_name)
	if clip:
		clip.loop_mode = Animation.LOOP_LINEAR


func _strip_scale_tracks() -> void:
	## Removes only TYPE_SCALE_3D and legacy ":scale" property tracks.
	## Position/rotation bone tracks are preserved so animations play correctly.
	## The mesh node's own transform is locked each frame via _model_local_pos.
	if _anim == null:
		return
	for anim_name in _anim.get_animation_list():
		var clip := _anim.get_animation(anim_name)
		if clip == null:
			continue
		for i in range(clip.get_track_count() - 1, -1, -1):
			if clip.track_get_type(i) == Animation.TYPE_SCALE_3D:
				clip.remove_track(i)
				continue
			if str(clip.track_get_path(i)).ends_with(":scale"):
				clip.remove_track(i)


# ── Input helper ──────────────────────────────────────────────────────────────
func _key(action: StringName, k1: Key, k2: Key = KEY_NONE) -> bool:
	if InputMap.has_action(action) and Input.is_action_pressed(action):
		return true
	if Input.is_key_pressed(k1):
		return true
	return k2 != KEY_NONE and Input.is_key_pressed(k2)


func _find_anim_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer
	for child in node.get_children():
		var r := _find_anim_player(child)
		if r:
			return r
	return null


func _get_idle_visual_offset() -> float:
	# Visual-only adjustment for idle pose mismatch.
	# Physics body/collider are untouched, so grounding remains controlled by Godot physics.
	if _current_anim != ANIM_IDLE:
		return 0.0
	if not is_on_floor():
		return 0.0
	return -(elara_visual_height_m * idle_height_percent)
