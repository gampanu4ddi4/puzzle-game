## 스프링 문: E로 열면 잠시 뒤 저절로 닫힌다 (문간에 사람이 서 있으면 기다린다).
## 이 노드의 원점 = 문틀 아래 가운데. 문짝은 로컬 XY 평면에 서 있고, +Z 쪽으로 열린다 (swing = -1이면 -Z 쪽).
## 열려 있는 동안에는 문짝에 충돌이 없다. 닫히면 다시 막는다.
class_name SpringDoor
extends Node3D

signal opened
signal closed
signal rattled          # 잠긴 문을 열려고 했다

var width := 1.0
var height := 2.1
var swing := 1.0
var close_delay := 1.8
var auto_close := true
var locked := false
var render_layers := 1
var sfx_bus := "Master"

var is_open := false
var leaf: Interactable
var player: Node3D       # 문간이 비었는지 볼 대상

var _hinge: Node3D
var _shape: CollisionShape3D
var _open_time := 0.0
var _moving := false
var _sfx: AudioStreamPlayer3D
var _tween: Tween


func build(leaf_color := Color("8e938f"), frame_color := Color("5f6461"), frame_depth := 0.12) -> void:
	var frame_mat := _std(frame_color, 0.5, 0.5)
	var leaf_mat := _std(leaf_color, 0.55, 0.4)
	# 문틀
	_mesh(self, Vector3(0.06, height + 0.06, frame_depth), Vector3(-width / 2.0 - 0.03, (height + 0.06) / 2.0, 0), frame_mat)
	_mesh(self, Vector3(0.06, height + 0.06, frame_depth), Vector3(width / 2.0 + 0.03, (height + 0.06) / 2.0, 0), frame_mat)
	_mesh(self, Vector3(width + 0.12, 0.06, frame_depth), Vector3(0, height + 0.03, 0), frame_mat)
	# 경첩 (왼쪽), 문짝
	_hinge = Node3D.new()
	_hinge.position = Vector3(-width / 2.0, 0, 0)
	add_child(_hinge)
	leaf = Interactable.new()
	_hinge.add_child(leaf)
	_shape = CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(width, height, 0.06)
	_shape.shape = box
	_shape.position = Vector3(width / 2.0, height / 2.0, 0)
	leaf.add_child(_shape)
	_mesh(leaf, Vector3(width - 0.01, height - 0.01, 0.045), Vector3(width / 2.0, height / 2.0, 0), leaf_mat)
	# 작은 유리창 (불투명한 어두운 유리), 손잡이
	var glass := _std(Color("14181a"), 0.1, 0.2)
	_mesh(leaf, Vector3(0.2, 0.5, 0.05), Vector3(width / 2.0, 1.55, 0), glass)
	var steel := _std(Color("c8c8c8"), 0.25, 1.0)
	for sz in [-1.0, 1.0]:
		_mesh(leaf, Vector3(0.12, 0.03, 0.03), Vector3(width - 0.14, 1.0, sz * 0.05), steel)
		_mesh(leaf, Vector3(0.03, 0.03, 0.05), Vector3(width - 0.09, 1.0, sz * 0.035), steel)
	leaf.interacted.connect(_on_interact)
	_sfx = AudioStreamPlayer3D.new()
	_sfx.bus = sfx_bus
	_sfx.unit_size = 6.0
	_sfx.position = Vector3(0, 1.0, 0)
	add_child(_sfx)


func open(angle_deg := 96.0, duration := 0.55) -> void:
	if _moving and is_open:
		return
	is_open = true
	_shape.disabled = true
	_open_time = Time.get_ticks_msec() / 1000.0
	_swing_to(deg_to_rad(angle_deg) * -swing, duration)
	_play(ProcAudio.door_open())
	opened.emit()


func close(duration := 0.7) -> void:
	if not is_open:
		return
	_swing_to(0.0, duration)
	await _tween.finished
	if absf(_hinge.rotation.y) > 0.01:
		return   # 닫히는 중에 다시 열렸다
	is_open = false
	_shape.disabled = false
	_play(ProcAudio.door_close())
	closed.emit()


func lock() -> void:
	locked = true


func _on_interact() -> void:
	if is_open:
		return
	if locked:
		_play(ProcAudio.door_rattle())
		var tw := create_tween()
		tw.tween_property(_hinge, "rotation:y", -0.02 * swing, 0.05)
		tw.tween_property(_hinge, "rotation:y", 0.0, 0.08)
		rattled.emit()
		return
	open()


func _process(_delta: float) -> void:
	if not is_open or not auto_close or _moving:
		return
	var t := Time.get_ticks_msec() / 1000.0
	if t - _open_time < close_delay:
		return
	# 문간(문짝이 지나가는 자리)에 사람이 있으면 기다린다
	if player != null:
		var l := to_local(player.global_position)
		if absf(l.x) < width / 2.0 + 0.45 and l.z * swing > -0.5 and l.z * swing < width + 0.45:
			return
	close()


func _swing_to(angle: float, duration: float) -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	_moving = true
	_tween = create_tween()
	_tween.tween_property(_hinge, "rotation:y", angle, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween.finished.connect(func() -> void: _moving = false)


func _play(stream: AudioStream) -> void:
	_sfx.stream = stream
	_sfx.play()


func _std(color: Color, rough: float, metal: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	m.metallic = metal
	return m


func _mesh(parent: Node, size: Vector3, center: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = center
	mi.layers = render_layers
	parent.add_child(mi)
	return mi
