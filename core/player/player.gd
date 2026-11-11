## 1인칭 플레이어 (룩 테스트용 최소 버전).
## WASD 걷기, Shift 천천히, Ctrl 웅크리기, 마우스 둘러보기, Esc 마우스 풀기, F12 스크린샷.
extends CharacterBody3D

@export var walk_speed := 3.2
@export var slow_speed := 1.6
@export var mouse_sensitivity := 0.0022
@export var eye_height := 1.6
@export var crouch_eye_height := 1.0

var _pitch := 0.0
var _bob := 0.0
var camera: Camera3D


func _ready() -> void:
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.3
	capsule.height = 1.75
	shape.shape = capsule
	shape.position.y = 0.875
	add_child(shape)

	camera = Camera3D.new()
	camera.fov = 75.0
	camera.near = 0.05
	camera.position.y = eye_height
	add_child(camera)
	camera.make_current()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * mouse_sensitivity)
		_pitch = clampf(_pitch - event.relative.y * mouse_sensitivity, -1.45, 1.45)
		camera.rotation.x = _pitch
	elif event is InputEventMouseButton and event.pressed:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_ESCAPE:
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			KEY_F12:
				_save_screenshot()


func _physics_process(delta: float) -> void:
	var input := Vector3.ZERO
	if Input.is_physical_key_pressed(KEY_W): input.z -= 1.0
	if Input.is_physical_key_pressed(KEY_S): input.z += 1.0
	if Input.is_physical_key_pressed(KEY_A): input.x -= 1.0
	if Input.is_physical_key_pressed(KEY_D): input.x += 1.0
	var dir := (transform.basis * input).normalized()
	var speed := slow_speed if Input.is_physical_key_pressed(KEY_SHIFT) else walk_speed
	velocity.x = dir.x * speed
	velocity.z = dir.z * speed
	if is_on_floor():
		velocity.y = -0.5
	else:
		velocity.y -= 9.8 * delta
	move_and_slide()

	var crouch := Input.is_physical_key_pressed(KEY_CTRL)
	var target := crouch_eye_height if crouch else eye_height
	if dir.length() > 0.1 and is_on_floor():
		_bob += delta * speed * 2.2
	camera.position.y = lerpf(camera.position.y, target + sin(_bob) * 0.018, 10.0 * delta)


func _save_screenshot() -> void:
	var img := get_viewport().get_texture().get_image()
	var path := "user://screenshot_%d.png" % Time.get_unix_time_from_system()
	img.save_png(path)
	print("saved ", ProjectSettings.globalize_path(path))
