## 프롤로그: 지상 주차장 입구 (docs/levels/ch1_parking.md "프롤로그").
## 밤, 비가 그친 직후. 건물 외벽에 주차장 입구가 있고, 입구 옆에 정산소, 앞에 차단기가 있다.
## 플레이어는 도로 쪽에서 시작해 연석을 넘고(점프), 정산소 창문을 열고(상호작용), 경사로를 내려간다.
##
## 바깥 물체는 모두 렌더 레이어 4에 두고, 바깥 조명은 레이어 4만 비춘다 (지하 층과 섞이지 않게).
## 입구 = B1 동쪽 경사로의 위쪽 끝. 바깥은 입구에서 -Z 방향으로 펼쳐진다.
class_name Prologue
extends Node3D

signal ticket_taken

const LAYER := 4
const SODIUM := Color("ffb05a")

var mouth: Vector3            # 경사로 위쪽 끝 바닥 가운데 (월드)
var ground_y := 0.0
var start_point: Vector3      # 플레이어 시작 위치
var booth_window: Interactable
var ticket: Interactable

var _arm_pivot: Node3D
var _mats := {}
var _font: SystemFont


func build(at_mouth: Vector3) -> void:
	mouth = at_mouth
	ground_y = at_mouth.y
	start_point = Vector3(mouth.x, ground_y + 0.05, mouth.z - 26.0)
	_mats = ParkingMats.outdoor().duplicate()
	var facade := (_mats["facade"] as ShaderMaterial).duplicate() as ShaderMaterial
	facade.set_shader_parameter("floor_level", ground_y)
	_mats["facade"] = facade
	_font = SystemFont.new()
	_font.font_names = PackedStringArray(["Malgun Gothic", "Noto Sans CJK KR", "Noto Sans KR", "NanumGothic", "Noto Sans", "DejaVu Sans", "Arial"])
	_font.font_weight = 700

	_build_ground()
	_build_facade()
	_build_booth()
	_build_barrier()
	_build_lights()
	_build_bounds()


## 차단기를 내린다 (플레이어가 B1에 들어섰을 때. 소리는 레벨에서 낸다).
func lower_barrier() -> void:
	var tw := create_tween()
	tw.tween_property(_arm_pivot, "rotation:z", 0.0, 1.4).set_trans(Tween.TRANS_SINE)


## 바깥(도로 쪽)에 있는지
func is_outside(p: Vector3) -> bool:
	return p.y > ground_y - 0.5 and p.z < mouth.z - 0.6


# ================================================================ 도우미

func _std(color: Color, rough := 0.6, metal := 0.0, emit := Color.BLACK, emit_energy := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	m.metallic = metal
	if emit_energy > 0.0:
		m.emission_enabled = true
		m.emission = emit
		m.emission_energy_multiplier = emit_energy
	return m


func _box(parent: Node, size: Vector3, center: Vector3, mat: Material, collide := true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = center
	mi.layers = LAYER
	parent.add_child(mi)
	if collide:
		var body := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		cs.shape = shape
		body.position = center
		body.add_child(cs)
		parent.add_child(body)
	return mi


func _wall(parent: Node, size: Vector3, center: Vector3) -> void:
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	body.position = center
	body.add_child(cs)
	parent.add_child(body)


func _label(parent: Node, text: String, pos: Vector3, px: float, color: Color, size := 128, yaw := PI) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font = _font
	l.font_size = size
	l.pixel_size = px
	l.modulate = color
	l.outline_size = 0
	l.shaded = true
	l.alpha_cut = Label3D.ALPHA_CUT_OPAQUE_PREPASS
	l.position = pos
	l.rotation.y = yaw
	l.layers = LAYER
	parent.add_child(l)
	return l


func _omni(parent: Node, pos: Vector3, color: Color, energy: float, rng: float, shadows := true) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.position = pos
	l.light_color = color
	l.light_energy = energy
	l.omni_range = rng
	l.shadow_enabled = shadows
	l.light_cull_mask = LAYER
	l.light_volumetric_fog_energy = 1.2
	parent.add_child(l)
	return l


# ================================================================ 만들기

func _build_ground() -> void:
	var mx := mouth.x
	var gy := ground_y
	var mz := mouth.z
	# 도로 (비에 젖은 아스팔트)
	# (입구까지 이어서 외벽 두께만큼의 틈이 생기지 않게 한다)
	_box(self, Vector3(80.0, 0.3, 60.0), Vector3(mx, gy - 0.15, mz - 30.0), _mats["asphalt"])
	# 도로와 건물 앞마당 사이의 연석: 이어진 틈이 없어 넘어가야 한다 (점프를 배운다)
	_box(self, Vector3(70.0, 0.5, 0.5), Vector3(mx, gy + 0.25, mz - 10.0), _mats["curb"])
	# 앞마당 바닥 띠 (건물 쪽은 콘크리트)
	_box(self, Vector3(70.0, 0.02, 9.4), Vector3(mx, gy + 0.01, mz - 5.3), _mats["curb"], false)
	# 길 건너편 건물 실루엣 (안개 속)
	var dark := _std(Color(0.06, 0.065, 0.07), 0.9)
	for spec in [[-22.0, 26.0, 14.0], [4.0, 18.0, 22.0], [26.0, 30.0, 12.0]]:
		_box(self, Vector3(spec[2], spec[1], 8.0), Vector3(mx + spec[0], gy + spec[1] / 2.0, mz - 58.0), dark, false)


func _build_facade() -> void:
	var mx := mouth.x
	var gy := ground_y
	var fz := mouth.z - 0.3
	var mat: Material = _mats["facade"]
	var h := 12.0
	# 입구(폭 6.6, 높이 2.9)를 뚫은 외벽
	_box(self, Vector3(31.7, h, 0.6), Vector3(mx - 3.3 - 15.85, gy + h / 2.0, fz), mat)
	_box(self, Vector3(31.7, h, 0.6), Vector3(mx + 3.3 + 15.85, gy + h / 2.0, fz), mat)
	_box(self, Vector3(6.6, h - 2.9, 0.6), Vector3(mx, gy + 2.9 + (h - 2.9) / 2.0, fz), mat)
	# 처마 띠
	_box(self, Vector3(70.0, 0.4, 1.0), Vector3(mx, gy + 3.4, fz - 0.5), mat, false)
	# 위층 창문들 (불 꺼진 사무실)
	var glass := _std(Color(0.05, 0.06, 0.07), 0.15, 0.3)
	for i in 9:
		var wx := mx - 30.0 + 7.5 * i
		if absf(wx - mx) < 4.0:
			continue
		for row in [6.0, 9.0]:
			_box(self, Vector3(4.2, 1.6, 0.05), Vector3(wx, gy + row, fz - 0.31), glass, false)

	# 높이 제한 막대: 노랑·검정 줄무늬
	var yellow := _std(Color("e3c23b"), 0.6)
	var black := _std(Color("1a1a1a"), 0.6)
	for i in 8:
		_box(self, Vector3(0.85, 0.16, 0.16), Vector3(mx - 3.4 + 0.85 * i + 0.425, gy + 2.42, fz - 0.6), yellow if i % 2 == 0 else black, false)
	_label(self, "높이제한 2.3m", Vector3(mx, gy + 2.62, fz - 0.62), 0.0016, Color(0.9, 0.9, 0.85), 96)

	# 입구 간판 (희미하게 빛나는 판)
	_box(self, Vector3(7.0, 1.1, 0.15), Vector3(mx, gy + 4.3, fz - 0.4), _std(Color("16402c"), 0.5, 0.0, Color("1f6b47"), 0.8), false)
	_label(self, "새솔복합센터  주차장", Vector3(mx + 0.4, gy + 4.3, fz - 0.49), 0.0034, Color(0.95, 0.97, 0.95), 128)
	_box(self, Vector3(0.8, 0.8, 0.05), Vector3(mx - 2.9, gy + 4.3, fz - 0.5), _std(Color("2b5fb0"), 0.5, 0.0, Color("2b5fb0"), 0.6), false)
	_label(self, "P", Vector3(mx - 2.9, gy + 4.3, fz - 0.53), 0.005, Color.WHITE, 128)
	# 간판 불빛
	_omni(self, Vector3(mx, gy + 3.8, fz - 1.2), Color("9fe0bd"), 0.6, 5.0, false)


func _build_booth() -> void:
	var c := Vector3(mouth.x - 6.5, ground_y, mouth.z - 3.5)
	var body := _std(Color("d9d9d2"), 0.5, 0.1)
	var trim := _std(Color("4a4f4c"), 0.5, 0.4)
	var t := 0.08
	var sx := 1.8
	var sz := 2.2
	var sy := 2.4
	# 벽: 뒤(-x), 옆(±z), 앞(+x)은 창문 자리를 뚫는다
	_box(self, Vector3(t, sy, sz), c + Vector3(-sx / 2.0, sy / 2.0, 0), body)
	_box(self, Vector3(sx, sy, t), c + Vector3(0, sy / 2.0, -sz / 2.0), body)
	_box(self, Vector3(sx, sy, t), c + Vector3(0, sy / 2.0, sz / 2.0), body)
	_box(self, Vector3(t, 1.0, sz), c + Vector3(sx / 2.0, 0.5, 0), body)
	_box(self, Vector3(t, 0.4, sz), c + Vector3(sx / 2.0, 2.2, 0), body)
	_box(self, Vector3(t, 1.0, 0.3), c + Vector3(sx / 2.0, 1.5, -sz / 2.0 + 0.15), body)
	_box(self, Vector3(t, 1.0, 0.3), c + Vector3(sx / 2.0, 1.5, sz / 2.0 - 0.15), body)
	_box(self, Vector3(sx + 0.3, 0.12, sz + 0.3), c + Vector3(0, sy + 0.06, 0), trim)
	_box(self, Vector3(0.45, 0.05, 1.6), c + Vector3(sx / 2.0 - 0.27, 0.95, 0), trim, false)
	_label(self, "정산소", c + Vector3(sx / 2.0 + 0.05, 2.2, 0), 0.0022, Color(0.15, 0.15, 0.15), 120, PI / 2)
	# 안쪽 형광등 (희미하게 켜져 있어 창문 안 주차권에 눈이 간다)
	_omni(self, c + Vector3(0, 2.2, 0), Color("dcebd8"), 0.5, 3.0, false)

	# 미닫이 창문: E로 연다
	booth_window = Interactable.new()
	booth_window.position = c + Vector3(sx / 2.0 + 0.03, 1.5, 0)
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.04, 1.0, 1.6)
	cs.shape = shape
	booth_window.add_child(cs)
	var gm := MeshInstance3D.new()
	var gb := BoxMesh.new()
	gb.size = shape.size
	gm.mesh = gb
	var gmat := _std(Color(0.55, 0.62, 0.6, 0.45), 0.1)
	gmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	gm.material_override = gmat
	gm.layers = LAYER
	booth_window.add_child(gm)
	add_child(booth_window)
	booth_window.interacted.connect(_open_window)

	# 1999년 주차권 (흔적 1)
	ticket = Interactable.new()
	ticket.position = c + Vector3(sx / 2.0 - 0.3, 0.985, 0.1)
	ticket.rotation.y = 0.2
	var tcs := CollisionShape3D.new()
	var tshape := BoxShape3D.new()
	tshape.size = Vector3(0.12, 0.04, 0.2)
	tcs.shape = tshape
	ticket.add_child(tcs)
	var paper := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(0.08, 0.16)
	paper.mesh = pm
	paper.material_override = _std(Color("efe9d8"), 0.8)
	paper.layers = LAYER
	ticket.add_child(paper)
	var txt := _label(ticket, "새솔센터 주차권\n1999.07.14\n입차 21:40", Vector3(0, 0.003, 0), 0.00028, Color(0.12, 0.12, 0.14), 64, 0.0)
	txt.rotation = Vector3(-PI / 2, PI / 2, 0)
	ticket.enabled = false   # 창문을 연 뒤에 집을 수 있다
	add_child(ticket)
	ticket.interacted.connect(_take_ticket)


func _open_window() -> void:
	booth_window.enabled = false
	(booth_window.get_child(0) as CollisionShape3D).disabled = true
	var tw := create_tween()
	tw.tween_property(booth_window, "position:z", booth_window.position.z + 0.8, 0.6).set_trans(Tween.TRANS_SINE)
	ticket.enabled = true


func _take_ticket() -> void:
	ticket.enabled = false
	ticket.visible = false
	(ticket.get_child(0) as CollisionShape3D).disabled = true
	ticket_taken.emit()


func _build_barrier() -> void:
	var base := Vector3(mouth.x + 3.9, ground_y, mouth.z - 1.4)
	var post := _std(Color("e3c23b"), 0.6)
	_box(self, Vector3(0.3, 1.05, 0.3), base + Vector3(0, 0.525, 0), post)
	_box(self, Vector3(0.36, 0.25, 0.36), base + Vector3(0, 1.1, 0), _std(Color("2a2a2a"), 0.5, 0.3), false)
	_arm_pivot = Node3D.new()
	_arm_pivot.position = base + Vector3(0, 1.05, 0)
	add_child(_arm_pivot)
	var red := _std(Color("c8473f"), 0.5)
	var white := _std(Color("ededed"), 0.5)
	for i in 6:
		_box(_arm_pivot, Vector3(1.1, 0.09, 0.06), Vector3(-0.55 - 1.1 * i, 0, 0), red if i % 2 == 0 else white, false)
	_arm_pivot.rotation.z = deg_to_rad(-84.0)   # 올라가 있다


func _build_lights() -> void:
	var mx := mouth.x
	var gy := ground_y
	var mz := mouth.z
	var pole := _std(Color("3a3e3c"), 0.5, 0.6)
	for p in [Vector3(mx - 12.0, gy, mz - 18.0), Vector3(mx + 12.0, gy, mz - 18.0), Vector3(mx - 4.0, gy, mz - 36.0)]:
		_box(self, Vector3(0.16, 6.0, 0.16), p + Vector3(0, 3.0, 0), pole)
		_box(self, Vector3(0.5, 0.18, 0.9), p + Vector3(0, 6.0, 0.35), pole, false)
		_box(self, Vector3(0.4, 0.04, 0.6), p + Vector3(0, 5.9, 0.35), _std(SODIUM, 0.4, 0.0, SODIUM, 4.0), false)
		_omni(self, p + Vector3(0, 5.7, 0.35), SODIUM, 3.6, 21.0)
	# 경사로 입구 안쪽의 형광등: 어두운 입구에 눈이 가고, 반쯤 내려온 셔터가 보이게 한다.
	# 입구는 B1(레이어 2) 경사로의 일부이므로 레이어 2와 4를 함께 비춘다.
	var inner := _omni(self, mouth + Vector3(0, 2.5, 2.0), Color("dcebd8"), 1.3, 9.0)
	inner.light_cull_mask = LAYER | 2
	# 아주 희미한 달빛 (바깥 레이어만)
	var moon := DirectionalLight3D.new()
	moon.rotation = Vector3(deg_to_rad(-38.0), deg_to_rad(25.0), 0)
	moon.light_color = Color("8fa2c8")
	moon.light_energy = 0.2
	moon.light_cull_mask = LAYER
	moon.shadow_enabled = false
	add_child(moon)


## 보이지 않는 벽: 옆과 먼 쪽 (먼 쪽으로 갈수록 느려지는 것은 레벨이 처리한다)
func _build_bounds() -> void:
	var mx := mouth.x
	var gy := ground_y
	var mz := mouth.z
	_wall(self, Vector3(1.0, 6.0, 60.0), Vector3(mx - 34.0, gy + 3.0, mz - 30.0))
	_wall(self, Vector3(1.0, 6.0, 60.0), Vector3(mx + 34.0, gy + 3.0, mz - 30.0))
	_wall(self, Vector3(70.0, 6.0, 1.0), Vector3(mx, gy + 3.0, mz - 50.0))
