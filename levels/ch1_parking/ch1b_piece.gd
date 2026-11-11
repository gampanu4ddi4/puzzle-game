## 1-2, 1-3에 쓰는 공간 조각들: 관리실, 비상계단, 일방통행 통로, 꺾인 연결 통로.
## ParkingFloor의 도우미(_box, _place, _fixture, _label …)를 그대로 쓰려고 상속한다.
## 조각마다 자기 좌표계가 있고, 텍스처는 mat_origin 기준으로 입힌다 (같은 모양의 조각끼리 무늬가 같도록).
class_name Ch1bPiece
extends ParkingFloor

const STREET := "res://assets/models/street/"

# 관리실에서 바깥이 쓰는 것
var drawer: Interactable
var ledger: Interactable
var door_lamp: OmniLight3D
var door_lamp_mat: StandardMaterial3D


func _init_piece(mat_origin: Vector3, seed: int) -> void:
	_rng.seed = seed
	_mats = ParkingMats.for_floor(mat_origin)
	_font = SystemFont.new()
	_font.font_names = PackedStringArray(["Malgun Gothic", "Noto Sans CJK KR", "Noto Sans KR", "NanumGothic", "UnDotum", "Noto Sans", "DejaVu Sans", "Arial"])
	_font.allow_system_fallback = true
	_font.font_weight = 700


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


func _street(name: String, pos: Vector3, yaw: float, parent: Node) -> Node3D:
	var n: Node3D = (load(STREET + name + ".glb") as PackedScene).instantiate()
	n.position = pos
	n.rotation.y = yaw
	parent.add_child(n)
	return n


func _tinted(key: String, tint: Color) -> ShaderMaterial:
	var m := (_mats[key] as ShaderMaterial).duplicate() as ShaderMaterial
	m.set_shader_parameter("tint", tint)
	return m


func _interactable(parent: Node, size: Vector3, center: Vector3) -> Interactable:
	var it := Interactable.new()
	it.position = center
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	it.add_child(cs)
	parent.add_child(it)
	return it


# ================================================================ 관리실 (1-2)
# 좌표: 원점 = 문 안쪽 바닥 가운데, +Z가 방 안쪽. 방은 x -2..2, z 0..5, 높이 2.6.

func build_room(mat_origin: Vector3) -> void:
	_init_piece(mat_origin, 1201)
	var g := _group("Room")
	var rh := 2.6
	var wall := _tinted("helix_wall", Color(0.93, 0.92, 0.86))
	var floor_m := _tinted("ramp_floor", Color(0.5, 0.58, 0.54))
	var ceil := _tinted("concrete_ceiling", Color(1.1, 1.1, 1.08))
	var steel := _std(Color("9aa0a2"), 0.35, 0.8)
	# 보이는 바닥 윗면만 3 cm 올린다: 아래층(B2) 천장 슬래브 윗면과 1 cm 차이라 멀리서 깜박였다.
	# 충돌은 원래 높이(0)에 둔다 (문턱에 3 cm 턱이 생기면 발이 걸린다).
	_box(g, Vector3(4.2, 0.13, 5.1), Vector3(0, -0.035, 2.5), floor_m, false)
	_collider(g, Vector3(4.2, 0.1, 5.1), Vector3(0, -0.05, 2.5))
	_box(g, Vector3(4.2, 0.1, 5.1), Vector3(0, rh + 0.05, 2.5), ceil)
	_box(g, Vector3(0.1, rh, 5.0), Vector3(-2.05, rh / 2, 2.5), wall)
	_box(g, Vector3(0.1, rh, 5.0), Vector3(2.05, rh / 2, 2.5), wall)
	_box(g, Vector3(4.2, rh, 0.1), Vector3(0, rh / 2, 5.05), wall)
	# 문 쪽 벽 (문 구멍 폭 1.0, 높이 2.1)
	_box(g, Vector3(1.5, rh, 0.05), Vector3(-1.25, rh / 2, 0.025), wall)
	_box(g, Vector3(1.5, rh, 0.05), Vector3(1.25, rh / 2, 0.025), wall)
	_box(g, Vector3(1.0, rh - 2.1, 0.05), Vector3(0, (rh + 2.1) / 2, 0.025), wall)
	# 문턱 (바깥 벽 두께만큼)
	_box(g, Vector3(1.1, 0.13, 0.4), Vector3(0, -0.035, -0.15), steel, false)
	_collider(g, Vector3(1.1, 0.1, 0.4), Vector3(0, -0.05, -0.15))
	# 걸레받이
	var base := _std(Color("3a3e3c"), 0.6)
	_box(g, Vector3(4.0, 0.1, 0.02), Vector3(0, 0.05, 4.99), base, false)
	_box(g, Vector3(0.02, 0.1, 5.0), Vector3(-1.99, 0.05, 2.5), base, false)
	_box(g, Vector3(0.02, 0.1, 5.0), Vector3(1.99, 0.05, 2.5), base, false)

	# 천장 형광등
	_place("fixture", Vector3(0, rh, 2.5), PI / 2, g, {"tube": _mats["tube_on"]})
	var light := OmniLight3D.new()
	light.position = Vector3(0, rh - 0.2, 2.5)
	light.light_color = Color("eef0e2")
	light.light_energy = 1.0
	light.omni_range = 6.0
	light.shadow_enabled = true
	light.shadow_bias = 0.05
	g.add_child(light)

	# 책상 (오른쪽 벽에 붙여서), 서랍장은 문 쪽 끝
	var wood := _std(Color("9c8a6c"), 0.6)
	var metal := _std(Color("8c8c84"), 0.5, 0.3)
	_box(g, Vector3(0.7, 0.04, 1.6), Vector3(1.6, 0.74, 3.3), wood)
	_box(g, Vector3(0.04, 0.72, 0.04), Vector3(1.3, 0.36, 4.06), metal, false)
	_box(g, Vector3(0.04, 0.72, 0.04), Vector3(1.92, 0.36, 4.06), metal, false)
	_box(g, Vector3(0.6, 0.7, 0.45), Vector3(1.63, 0.36, 2.76), metal, false)   # 서랍장 몸통 (충돌은 책상 상판이 맡는다)
	_box(g, Vector3(0.012, 0.2, 0.4), Vector3(1.326, 0.2, 2.76), _std(Color("7a7a72"), 0.5, 0.3), false)   # 아래 서랍 (장식)
	# 위 서랍: E로 연다. 안에 분실물 대장 (흔적 2)
	drawer = _interactable(g, Vector3(0.5, 0.2, 0.4), Vector3(1.56, 0.52, 2.76))
	var dm := MeshInstance3D.new()
	var dbox := BoxMesh.new()
	dbox.size = Vector3(0.5, 0.03, 0.4)
	dm.mesh = dbox
	dm.material_override = metal
	dm.position = Vector3(0, -0.085, 0)
	drawer.add_child(dm)
	var front := MeshInstance3D.new()
	var fbox := BoxMesh.new()
	fbox.size = Vector3(0.016, 0.2, 0.42)
	front.mesh = fbox
	front.material_override = _std(Color("7a7a72"), 0.5, 0.3)
	front.position = Vector3(-0.255, 0, 0)
	drawer.add_child(front)
	var pull := MeshInstance3D.new()
	var pbox := BoxMesh.new()
	pbox.size = Vector3(0.02, 0.02, 0.14)
	pull.mesh = pbox
	pull.material_override = _std(Color("c8c8c8"), 0.25, 1.0)
	pull.position = Vector3(-0.27, 0.03, 0)
	drawer.add_child(pull)
	ledger = _interactable(drawer, Vector3(0.24, 0.05, 0.3), Vector3(-0.05, -0.05, 0))
	var book := MeshInstance3D.new()
	var bbox := BoxMesh.new()
	bbox.size = Vector3(0.2, 0.025, 0.28)
	book.mesh = bbox
	book.material_override = _std(Color("2f4a3a"), 0.8)
	book.position = Vector3(0, -0.008, 0)
	ledger.add_child(book)
	var title := _label(ledger, "분실물 대장\n1999", Vector3(0, 0.008, 0), 0.0, 0.0005, Color(0.85, 0.8, 0.6), 64)
	title.rotation = Vector3(-PI / 2, PI / 2, 0)
	ledger.enabled = false

	# 책상 위: 모니터, 전화기, 서류
	_street("crt_monitor", Vector3(1.68, 0.76, 3.55), -PI / 2, g)
	_street("desk_phone", Vector3(1.55, 0.76, 2.95), -PI / 2 + 0.2, g)
	_box(g, Vector3(0.21, 0.012, 0.3), Vector3(1.45, 0.766, 3.9), _std(Color("efe9d8"), 0.8), false)
	_street("office_chair", Vector3(0.75, 0.0, 3.35), PI / 2 + 0.4, g)
	# 뒷벽: CCTV 모니터 선반 (꺼져 있다), 달력
	_box(g, Vector3(1.5, 0.04, 0.45), Vector3(-0.9, 1.25, 4.77), metal)
	_box(g, Vector3(0.04, 0.3, 0.4), Vector3(-1.6, 1.08, 4.78), metal, false)
	_box(g, Vector3(0.04, 0.3, 0.4), Vector3(-0.2, 1.08, 4.78), metal, false)
	_street("crt_monitor", Vector3(-1.3, 1.27, 4.78), PI, g)
	_street("crt_monitor", Vector3(-0.8, 1.27, 4.78), PI, g)
	_street("crt_monitor", Vector3(-0.3, 1.27, 4.78), PI, g)
	_box(g, Vector3(0.3, 0.42, 0.01), Vector3(1.0, 1.6, 4.99), _std(Color("f2f0e8"), 0.8), false)
	var cal := _label(g, "1999\n7\n\n일 월 화 수 목 금 토\n             1  2  3\n 4  5  6  7  8  9 10\n11 12 13 14 15 16 17\n18 19 20 21 22 23 24\n25 26 27 28 29 30 31",
		Vector3(1.0, 1.61, 4.98), PI, 0.00042, Color(0.15, 0.15, 0.15), 48)
	cal.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# 왼쪽 벽: 열쇠함, 서류 캐비닛
	_box(g, Vector3(0.08, 0.6, 0.5), Vector3(-1.96, 1.5, 1.6), _std(Color("6e7270"), 0.5, 0.4), false)
	for i in 8:
		_box(g, Vector3(0.012, 0.06, 0.03), Vector3(-1.915, 1.62 - 0.14 * (i / 4), 1.42 + 0.12 * (i % 4)), _std(Color("e3c23b"), 0.5), false)
	_box(g, Vector3(0.5, 1.3, 0.6), Vector3(-1.7, 0.65, 4.4), metal)
	for i in 4:
		_box(g, Vector3(0.012, 0.28, 0.54), Vector3(-1.446, 0.2 + 0.31 * i, 4.4), _std(Color("7a7a72"), 0.5, 0.3), false)
	# 바닥의 화살표 스티커: 방 안쪽을 가리킨다 (들어온 방향 = 화살표 방향. 1-2의 단서)
	var sticker := _place("arrow", Vector3(0, 0.003, 0.8), -PI / 2, g, {"paint_white": _mats["paint_yellow"]})
	sticker.scale = Vector3(0.3, 1.0, 0.3)

	# 문 밖(B3 쪽): "관리실" 명판과 작은 등
	_box(g, Vector3(0.5, 0.16, 0.012), Vector3(0, 2.34, -0.312), _std(Color("e8e8e2"), 0.5), false)
	_label(g, "관리실", Vector3(0, 2.34, -0.32), PI, 0.0011, Color(0.1, 0.12, 0.1), 112)
	door_lamp_mat = _std(Color("f2f7f0"), 0.3, 0.0, Color("dcebd8"), 3.0)
	_box(g, Vector3(0.3, 0.07, 0.07), Vector3(0, 2.56, -0.35), door_lamp_mat, false)
	door_lamp = OmniLight3D.new()
	door_lamp.position = Vector3(0, 2.5, -0.5)
	door_lamp.light_color = Color("dcebd8")
	door_lamp.light_energy = 0.5
	door_lamp.omni_range = 3.5
	g.add_child(door_lamp)


# ================================================================ 일방통행 통로 (1-3)
# 좌표 Q: 통로는 +X 방향(화살표 방향)으로 x 0..40, 폭 z -3..3, 높이 2.7.
# 같은 함수로 일부 구간(x0..x1)만 만들 수 있다: 연결 통로 너머로 보이는 "복제 구간"에 쓴다.

func build_aisle(mat_origin: Vector3, x0: float, x1: float, cap0: bool, cap1: bool, door_hole: bool) -> void:
	_init_piece(mat_origin, 1301)
	var g := _group("Aisle")
	var wall: Material = _mats["concrete_paint"]
	var length := x1 - x0
	var cx := (x0 + x1) / 2.0
	_box(g, Vector3(length, 0.3, 6.6), Vector3(cx, -0.15, 0), _mats["floor"])
	_box(g, Vector3(length, 0.3, 6.6), Vector3(cx, H + 0.15, 0), _mats["concrete_ceiling"])
	_box(g, Vector3(length, H, 0.3), Vector3(cx, H / 2, 3.15), wall)
	if door_hole:
		# 북쪽 벽 x = 5에 계단실 문 구멍 (폭 1.1, 높이 2.15)
		_box(g, Vector3(4.45 - x0, H, 0.3), Vector3((x0 + 4.45) / 2, H / 2, -3.15), wall)
		_box(g, Vector3(x1 - 5.55, H, 0.3), Vector3((5.55 + x1) / 2, H / 2, -3.15), wall)
		_box(g, Vector3(1.1, H - 2.15, 0.3), Vector3(5.0, (H + 2.15) / 2, -3.15), wall)
		_place("exit_sign", Vector3(5.0, 2.4, -3.0), 0.0, g)
		var green := OmniLight3D.new()
		green.position = Vector3(5.0, 2.3, -2.7)
		green.light_color = Color("3BD07A")
		green.light_energy = 0.5
		green.omni_range = 3.0
		g.add_child(green)
	else:
		_box(g, Vector3(length, H, 0.3), Vector3(cx, H / 2, -3.15), wall)
	if cap0:
		_box(g, Vector3(0.3, H, 6.6), Vector3(x0 - 0.15, H / 2, 0), wall)
	if cap1:
		_box(g, Vector3(0.3, H, 6.6), Vector3(x1 + 0.15, H / 2, 0), wall)
	_flat(g, Vector2(length, 0.12), Vector3(cx, 0.004, -2.55), _mats["paint_yellow"])
	_flat(g, Vector2(length, 0.12), Vector3(cx, 0.004, 2.55), _mats["paint_yellow"])

	var black := Color(0.08, 0.08, 0.07)
	var x := 2.0
	while x < 40.0:
		if x >= x0 and x <= x1:
			var state := "off" if is_equal_approx(x, 14.0) else ("flicker" if is_equal_approx(x, 22.0) else "on")
			_fixture(g, Vector3(x, H, 0.0), 0.0, state)
		x += 4.0
	x = 3.0
	while x < 40.0:
		if x >= x0 and x <= x1:
			_place_arrow(g, Vector3(x, 0.005, 0.0), 0.0)
		x += 6.0
	# 벽기둥과 구역 표지
	var n := 1
	x = 4.0
	while x < 40.0:
		if x >= x0 + 1.0 and x <= x1 - 1.0:     # 끝벽에 묻히는 자리는 뺀다
			for side: float in [-1.0, 1.0]:
				_box(g, Vector3(0.6, H, 0.3), Vector3(x, H / 2, side * 2.85), wall, false)
				_box(g, Vector3(0.46, 0.62, 0.02), Vector3(x, 1.72, side * 2.69), _mats["plate_yellow"], false)
				var yaw := 0.0 if side < 0 else PI
				_label(g, "B4", Vector3(x, 1.82, side * 2.678), yaw, 0.0016, black, 160)
				_label(g, "D%d" % n, Vector3(x, 1.56, side * 2.678), yaw, 0.0011, black, 128)
		n += 1
		x += 8.0
	# 천장 배관
	x = 4.0
	while x < 40.0:
		if x >= x0 and x <= x1:
			_place("pipe_gray", Vector3(x, 2.12, 2.2), 0.0, g)
		x += 8.0
	# 반복을 알아볼 수 있는 물건들 (앵커): 쓰러진 라바콘, 소화전함, 기름 자국
	if 19.2 >= x0 and 19.2 <= x1:
		var cone := _place("traffic_cone", Vector3(19.2, 0.14, 1.7), 0.0, g)
		cone.rotation = Vector3(PI / 2, 0.9, 0)
		_place("traffic_cone", Vector3(20.3, 0, 2.2), 0.4, g)
	if 28.0 >= x0 + 1.0 and 28.0 <= x1 - 1.0:
		_place("fire_cabinet", Vector3(28.0, 0.45, 3.0), PI, g)
	for spec in [[10.5, -0.8, 1.5], [31.0, 0.9, 1.2], [24.0, -1.2, 0.9]]:
		if spec[0] >= x0 + 1.0 and spec[0] <= x1 - 1.0:
			var d := Decal.new()
			d.texture_albedo = ParkingMats.tex("oil_stain_a" if spec[2] > 1.0 else "oil_stain_b")
			d.size = Vector3(spec[2], 0.4, spec[2])
			d.position = Vector3(spec[0], 0.0, spec[1])
			d.rotation.y = spec[0]
			g.add_child(d)


# ================================================================ 꺾인 연결 통로 (1-3)
# 좌표 C: 통로는 +Z 방향(화살표 방향)으로 z 0..12, 폭 x -2..2. 양 끝에 모퉁이 칸이 붙는다.
#   북쪽 모퉁이 z -6..0: 서쪽(x = -2)이 열려 있다.  남쪽 모퉁이 z 12..18: 동쪽(x = 2)이 열려 있다.
# 가운데(z = 6)에서는 양쪽 입구 너머가 3.7 m까지만 보인다. 반복 관문을 여기에 둔다.

func build_connector(mat_origin: Vector3) -> void:
	_init_piece(mat_origin, 1302)
	var g := _group("Connector")
	var wall: Material = _mats["concrete_paint"]
	_box(g, Vector3(4.0, 0.3, 24.0), Vector3(0, -0.15, 6.0), _mats["floor"])
	_box(g, Vector3(4.0, 0.3, 24.0), Vector3(0, H + 0.15, 6.0), _mats["concrete_ceiling"])
	_box(g, Vector3(0.3, H, 17.7), Vector3(-2.15, H / 2, 9.15), wall)     # 서쪽 벽 z 0.3..18
	_box(g, Vector3(0.3, H, 17.7), Vector3(2.15, H / 2, 2.85), wall)      # 동쪽 벽 z -6..11.7
	_box(g, Vector3(4.3, H, 0.3), Vector3(0.15, H / 2, -6.15), wall)      # 북쪽 끝
	_box(g, Vector3(4.3, H, 0.3), Vector3(-0.15, H / 2, 18.15), wall)     # 남쪽 끝
	_flat(g, Vector2(0.12, 12.0), Vector3(-1.6, 0.004, 6.0), _mats["paint_yellow"])
	_flat(g, Vector2(0.12, 12.0), Vector3(1.6, 0.004, 6.0), _mats["paint_yellow"])
	for z in [2.0, 10.0]:
		_place_arrow(g, Vector3(0, 0.005, z), -PI / 2)
	for z in [-3.0, 3.0, 9.0, 15.0]:
		_fixture(g, Vector3(0, H, z), PI / 2, "on")


# ================================================================ 비상계단 (1-2 → 1-3)
# 좌표 S: 원점 = 위층 문 바깥 바닥 가운데, +Z가 문에서 멀어지는 쪽. 폭 x -1.3..1.3, 깊이 z 0..5.4.
# 위층 참(y 0) → 왼쪽 계단 → 중간 참(y -1.5) → 오른쪽 계단 → 아래층 참(y -3). 아래층 문은 위층 문 바로 아래(z = 0 쪽).

const STEP_RISE := 1.5 / 9.0
const STEP_RUN := 0.28

func build_stairs(mat_origin: Vector3) -> void:
	_init_piece(mat_origin, 1203)
	var g := _group("Stairs")
	var wall: Material = _tinted("helix_wall", Color(0.9, 0.9, 0.86))
	var conc: Material = _mats["ramp_floor"]
	var hw := 1.3
	# 벽: 양옆, 뒤, 위층 문 쪽(문 구멍 폭 1.1, 높이 2.15)
	# 양옆 벽은 z 0부터: 문 쪽 벽 두께(z -0.3..0)까지 내밀면 아래층 통로 벽과 겹쳐 깜박인다
	_box(g, Vector3(0.3, 5.7, 5.7), Vector3(-hw - 0.15, -0.15, 2.85), wall)
	_box(g, Vector3(0.3, 5.7, 5.7), Vector3(hw + 0.15, -0.15, 2.85), wall)
	_box(g, Vector3(2.6, 5.7, 0.3), Vector3(0, -0.15, 5.55), wall)
	_box(g, Vector3(0.75, H, 0.3), Vector3(-0.925, H / 2, -0.15), wall)
	_box(g, Vector3(0.75, H, 0.3), Vector3(0.925, H / 2, -0.15), wall)
	_box(g, Vector3(1.1, H - 2.15, 0.3), Vector3(0, (H + 2.15) / 2, -0.15), wall)
	# 바닥, 천장, 참
	_box(g, Vector3(2.6, 0.3, 5.4), Vector3(0, -3.15, 2.7), conc)
	_box(g, Vector3(3.2, 0.3, 6.0), Vector3(0, H + 0.15, 2.7), _mats["concrete_ceiling"])
	_box(g, Vector3(2.6, 0.15, 1.5), Vector3(0, -0.075, 0.75), conc)
	_box(g, Vector3(2.6, 0.15, 1.38), Vector3(0, -1.575, 4.71), conc)
	# 가운데 벽, 위층 참 오른쪽의 벽(아래 계단 위), 왼쪽 계단 밑을 막는 벽
	_box(g, Vector3(0.1, 5.7, 2.52), Vector3(0, -0.15, 2.76), wall)
	_box(g, Vector3(1.25, H + 0.15, 0.1), Vector3(0.675, (H - 0.15) / 2, 1.55), wall)
	_box(g, Vector3(1.25, 2.85, 0.1), Vector3(-0.675, -1.575, 1.55), wall)
	# 계단: 디딤판마다 상자 (오르내릴 때 한 단씩 밟는다)
	var nosing := _std(Color("e3c23b"), 0.6)
	for i in 9:
		var top := -(i + 1) * STEP_RISE
		var z0 := 1.5 + i * STEP_RUN
		_box(g, Vector3(1.25, 0.4, STEP_RUN), Vector3(-0.675, top - 0.2, z0 + STEP_RUN / 2), conc)
		_box(g, Vector3(1.25, 0.012, 0.04), Vector3(-0.675, top + 0.004, z0 + 0.03), nosing, false)
	for j in 9:
		var top := -1.5 - (j + 1) * STEP_RISE
		var z1 := 4.02 - j * STEP_RUN
		var h := top + 3.0
		if h > 0.02:
			_box(g, Vector3(1.25, h, STEP_RUN), Vector3(0.675, top - h / 2, z1 - STEP_RUN / 2), conc)
			_box(g, Vector3(1.25, 0.012, 0.04), Vector3(0.675, top + 0.004, z1 - 0.03), nosing, false)
	# 난간 (벽에 붙은 손잡이)
	var rail := _std(Color("3a3e3c"), 0.4, 0.7)
	_rail(g, Vector3(-hw + 0.06, 0.9, 1.5), Vector3(-hw + 0.06, -0.6, 4.02), rail)
	_rail(g, Vector3(hw - 0.06, -0.6, 4.02), Vector3(hw - 0.06, -2.1, 1.5), rail)
	# 조명: 위층 참, 중간 참 위, 아래층 참
	_fixture(g, Vector3(0, H, 0.75), 0.0, "on")
	_fixture(g, Vector3(0, H, 4.7), 0.0, "flicker")
	_fixture(g, Vector3(0, -0.15, 0.75), 0.0, "on")
	# 층 표시
	var paint := Color("2E5A40")
	_label(g, "B3", Vector3(0.93, 1.6, 0.012), 0.0, 0.003, paint, 200)
	_label(g, "B4", Vector3(0.93, -1.5, 0.012), 0.0, 0.003, paint, 200)
	_box(g, Vector3(0.4, 0.16, 0.012), Vector3(0, -0.65, 0.008), _std(Color("16402c"), 0.5, 0.0, Color("3BD07A"), 1.5), false)
	_label(g, "주차장", Vector3(0, -0.65, 0.016), 0.0, 0.001, Color(0.95, 1.0, 0.95), 100)


func _rail(parent: Node, a: Vector3, b: Vector3, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.04, 0.04, a.distance_to(b))
	mi.mesh = bm
	mi.material_override = mat
	parent.add_child(mi)
	mi.transform = Transform3D(Basis.looking_at((b - a).normalized(), Vector3.UP), (a + b) / 2.0)
