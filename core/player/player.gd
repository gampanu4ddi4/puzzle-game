## 1인칭 플레이어.
## WASD 걷기, Shift 천천히, Ctrl 웅크리기, 마우스 둘러보기, Esc 마우스 풀기, F12 스크린샷.
extends CharacterBody3D

@export var walk_speed := 3.2
@export var slow_speed := 1.6
@export var mouse_sensitivity := 0.0022
@export var eye_height := 1.6
@export var crouch_eye_height := 1.0
@export var step_length := 0.75
@export var sfx_bus := "Master"

## 테스트용: 0이 아니면 키 입력 대신 이 방향(로컬, -Z가 앞)으로 걷는다
var auto_move := Vector3.ZERO
var input_enabled := true

var camera: Camera3D

var _pitch := 0.0
var _bob := 0.0
var _step_dist := 0.0
var _steps: Array[AudioStreamWAV] = []
var _step_player: AudioStreamPlayer
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.3
	capsule.height = 1.75
	shape.shape = capsule
	shape.position.y = 0.875
	add_child(shape)
	floor_max_angle = deg_to_rad(20.0)
	floor_snap_length = 0.3

	camera = Camera3D.new()
	camera.fov = 75.0
	camera.near = 0.05
	camera.position.y = eye_height
	add_child(camera)
	camera.make_current()

	for i in 6:
		_steps.append(ProcAudio.footstep(100 + i))
	_step_player = AudioStreamPlayer.new()
	_step_player.bus = sfx_bus
	_step_player.volume_db = -14.0
	add_child(_step_player)

	if input_enabled:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func set_look(pitch: float) -> void:
	_pitch = pitch
	camera.rotation.x = pitch


func _unhandled_input(event: InputEvent) -> void:
	if not input_enabled:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * mouse_sensitivity)
		set_look(clampf(_pitch - event.relative.y * mouse_sensitivity, -1.45, 1.45))
	elif event is InputEventMouseButton and event.pressed:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_ESCAPE:
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			KEY_F12:
				_save_screenshot()


func _physics_process(delta: float) -> void:
	var input := auto_move
	if auto_move == Vector3.ZERO and input_enabled:
		if Input.is_physical_key_pressed(KEY_W): input.z -= 1.0
		if Input.is_physical_key_pressed(KEY_S): input.z += 1.0
		if Input.is_physical_key_pressed(KEY_A): input.x -= 1.0
		if Input.is_physical_key_pressed(KEY_D): input.x += 1.0
	var dir := (transform.basis * input).normalized()
	var slow := input_enabled and Input.is_physical_key_pressed(KEY_SHIFT)
	var speed := slow_speed if slow else walk_speed
	velocity.x = dir.x * speed
	velocity.z = dir.z * speed
	if is_on_floor():
		velocity.y = -0.5
	else:
		velocity.y -= 9.8 * delta
	var before := global_position
	move_and_slide()

	var moved := Vector2(global_position.x - before.x, global_position.z - before.z).length()
	if is_on_floor() and moved > 0.0:
		_bob += delta * speed * 2.2
		_step_dist += moved
		if _step_dist >= step_length:
			_step_dist = 0.0
			_play_step(slow)

	var crouch := input_enabled and Input.is_physical_key_pressed(KEY_CTRL)
	var target := crouch_eye_height if crouch else eye_height
	camera.position.y = lerpf(camera.position.y, target + sin(_bob) * 0.018, 10.0 * delta)


func _play_step(slow: bool) -> void:
	_step_player.stream = _steps[_rng.randi() % _steps.size()]
	_step_player.pitch_scale = _rng.randf_range(0.92, 1.08)
	_step_player.volume_db = -20.0 if slow else -14.0
	_step_player.play()


## 반복 관문이 옮겨 준 뒤 불린다.
func on_teleported(_xf: Transform3D) -> void:
	pass


func _save_screenshot() -> void:
	var img := get_viewport().get_texture().get_image()
	var path := "user://screenshot_%d.png" % Time.get_unix_time_from_system()
	img.save_png(path)
	print("saved ", ProjectSettings.globalize_path(path))
