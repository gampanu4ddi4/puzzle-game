## 1인칭 플레이어.
## WASD 걷기, Shift 달리기, Ctrl 웅크리기, Space 점프, E 상호작용, 마우스 둘러보기, F12 스크린샷.
## (Esc는 메뉴가 맡는다.) 감도, 상하 반전, 시야각, 화면 흔들림, 가운데 점은 설정(Settings)을 따른다.
extends CharacterBody3D

@export var walk_speed := 3.2
@export var run_speed := 5.5
@export var crouch_speed := 1.6
@export var jump_velocity := 4.2       # 약 0.9 m 높이까지
const BASE_SENSITIVITY := 0.0022
@export var mouse_sensitivity := BASE_SENSITIVITY
@export var eye_height := 1.6
@export var crouch_eye_height := 1.0
@export var reach := 2.3               # 상호작용 거리
@export var step_length := 1.7         # 발소리 간격(m). 실제 보폭보다 길게 잡아 덜 거슬리게 한다
@export var sfx_bus := "Master"

const STAND_HEIGHT := 1.75
const CROUCH_HEIGHT := 1.0

## 테스트용: 0이 아니면 키 입력 대신 이 방향(로컬, -Z가 앞)으로 걷는다
var auto_move := Vector3.ZERO
var auto_crouch := false
var input_enabled := true
## 바깥(레벨)에서 걷는 속도에 곱한다 (예: 경계 근처에서 느려지기)
var speed_scale := 1.0

var camera: Camera3D
var crouching := false
var hovered: Interactable = null

var _pitch := 0.0
var _bob := 0.0
var _step_dist := 0.0
var _steps: Array[AudioStreamWAV] = []
var _step_player: AudioStreamPlayer
var _rng := RandomNumberGenerator.new()
var _shape: CollisionShape3D
var _capsule: CapsuleShape3D
var _jump_requested := false
var _dot: ColorRect
var _invert_y := false
var _head_bob := true
var _always_dot := false


func _ready() -> void:
	_shape = CollisionShape3D.new()
	_capsule = CapsuleShape3D.new()
	_capsule.radius = 0.3
	_capsule.height = STAND_HEIGHT
	_shape.shape = _capsule
	_shape.position.y = STAND_HEIGHT / 2.0
	add_child(_shape)
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

	# 상호작용할 수 있는 것을 가리키면 화면 가운데에 작은 점이 나온다 (GDD 10장)
	var layer := CanvasLayer.new()
	layer.layer = 15
	_dot = ColorRect.new()
	_dot.color = Color(1, 1, 1, 0.75)
	_dot.size = Vector2(6, 6)
	_dot.set_anchors_preset(Control.PRESET_CENTER)
	_dot.position -= Vector2(3, 3)
	_dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dot.visible = false
	layer.add_child(_dot)
	add_child(layer)

	if input_enabled:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_apply_settings()
	Settings.changed.connect(_apply_settings)


func _apply_settings() -> void:
	mouse_sensitivity = BASE_SENSITIVITY * float(Settings.get_value("mouse_sensitivity"))
	_invert_y = bool(Settings.get_value("invert_y"))
	_head_bob = bool(Settings.get_value("head_bob"))
	_always_dot = bool(Settings.get_value("crosshair"))
	if camera:
		camera.fov = float(Settings.get_value("fov"))


func set_look(pitch: float) -> void:
	_pitch = pitch
	camera.rotation.x = pitch


## 테스트용: 다음 물리 프레임에 점프
func request_jump() -> void:
	_jump_requested = true


## 지금 가리키는 것과 상호작용한다. 성공하면 true.
func try_interact() -> bool:
	_update_hover()
	if hovered != null:
		hovered.interact()
		return true
	return false


func _unhandled_input(event: InputEvent) -> void:
	if not input_enabled:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * mouse_sensitivity)
		var dy: float = event.relative.y * (-1.0 if _invert_y else 1.0)
		set_look(clampf(_pitch - dy * mouse_sensitivity, -1.45, 1.45))
	elif event is InputEventMouseButton and event.pressed:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_F12:
				_save_screenshot()
			KEY_E:
				try_interact()
			KEY_SPACE:
				_jump_requested = true


func _physics_process(delta: float) -> void:
	var input := auto_move
	if auto_move == Vector3.ZERO and input_enabled:
		if Input.is_physical_key_pressed(KEY_W): input.z -= 1.0
		if Input.is_physical_key_pressed(KEY_S): input.z += 1.0
		if Input.is_physical_key_pressed(KEY_A): input.x -= 1.0
		if Input.is_physical_key_pressed(KEY_D): input.x += 1.0

	_update_crouch(auto_crouch or (input_enabled and Input.is_physical_key_pressed(KEY_CTRL)))

	var dir := (transform.basis * input).normalized()
	var running := input_enabled and Input.is_physical_key_pressed(KEY_SHIFT) and not crouching and input.z < 0.0
	var speed := crouch_speed if crouching else (run_speed if running else walk_speed)
	speed *= speed_scale
	velocity.x = dir.x * speed
	velocity.z = dir.z * speed
	if is_on_floor():
		if _jump_requested and not crouching:
			velocity.y = jump_velocity
		elif velocity.y <= 0.0:
			velocity.y = -0.5
	else:
		velocity.y -= 9.8 * delta
	_jump_requested = false
	_try_step_up(delta)
	var before := global_position
	move_and_slide()

	var moved := Vector2(global_position.x - before.x, global_position.z - before.z).length()
	if is_on_floor() and moved > 0.0:
		_bob += delta * speed * 2.2
		_step_dist += moved
		# 달릴 때는 발소리 간격을 조금 늘린다 (속도만큼 늘리면 너무 띄엄띄엄하다)
		if _step_dist >= step_length * (1.3 if running else 1.0):
			_step_dist = 0.0
			_play_step(crouching, running)

	var target := crouch_eye_height if crouching else eye_height
	var bob := sin(_bob) * (0.028 if running else 0.018) if _head_bob else 0.0
	camera.position.y = lerpf(camera.position.y, target + bob, 10.0 * delta)
	_update_hover()


## 낮은 턱(보도 연석, 주차 턱 등 STEP_HEIGHT 이하)은 걸어서 올라간다.
## 앞이 벽처럼 막혔는데, 그만큼 들어 올린 위치에서는 막히지 않으면 몸을 올려 준다 (바닥 붙이기가 다시 내려 준다).
const STEP_HEIGHT := 0.22

func _try_step_up(delta: float) -> void:
	if not is_on_floor():
		return
	var motion := Vector3(velocity.x, 0.0, velocity.z) * delta
	if motion.length() < 0.0005:
		return
	var hit := move_and_collide(motion, true, 0.001, false, 4)
	if hit == null:
		return
	# 둥근 발이 턱 모서리에 닿으면 충돌 방향이 비스듬하게(위쪽 성분 0.5 안팎) 나온다.
	# 경사로·비탈은 위쪽 성분이 0.94 이상(20도 이하)이므로 0.85를 기준으로 가른다.
	var blocked_by_step := false
	for i in hit.get_collision_count():
		if hit.get_normal(i).y < 0.85:
			blocked_by_step = true
	if not blocked_by_step:
		return   # 바닥이나 비탈(경사로)에 닿았을 뿐이다
	var up := Vector3(0, STEP_HEIGHT, 0)
	if test_move(global_transform, up):
		return
	var raised := global_transform.translated(up)
	if test_move(raised, motion * 2.0):
		return   # 올라가도 막힌다: 진짜 벽
	global_position += up


## 웅크리면 몸 높이도 줄어서 낮은 곳을 지나갈 수 있다. 머리 위가 막혀 있으면 일어서지 않는다.
func _update_crouch(want: bool) -> void:
	if want == crouching:
		return
	if not want:
		var stand_up := Vector3(0, STAND_HEIGHT - CROUCH_HEIGHT, 0)
		if test_move(global_transform, stand_up):
			return
	crouching = want
	_capsule.height = CROUCH_HEIGHT if crouching else STAND_HEIGHT
	_shape.position.y = _capsule.height / 2.0


func _update_hover() -> void:
	hovered = null
	if camera == null:
		return
	var from := camera.global_position
	var to := from - camera.global_transform.basis.z * reach
	var q := PhysicsRayQueryParameters3D.create(from, to)
	q.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if not hit.is_empty() and hit["collider"] is Interactable and (hit["collider"] as Interactable).can_interact():
		hovered = hit["collider"]
	_dot.visible = hovered != null or _always_dot
	_dot.color = Color(1, 1, 1, 0.75) if hovered != null else Color(1, 1, 1, 0.35)


func _play_step(quiet: bool, loud := false) -> void:
	_step_player.stream = _steps[_rng.randi() % _steps.size()]
	_step_player.pitch_scale = _rng.randf_range(0.92, 1.08)
	_step_player.volume_db = -20.0 if quiet else (-10.0 if loud else -14.0)
	_step_player.play()


## 반복 관문이 옮겨 준 뒤 불린다.
func on_teleported(_xf: Transform3D) -> void:
	pass


func _save_screenshot() -> void:
	var img := get_viewport().get_texture().get_image()
	var path := "user://screenshot_%d.png" % Time.get_unix_time_from_system()
	img.save_png(path)
	print("saved ", ProjectSettings.globalize_path(path))
