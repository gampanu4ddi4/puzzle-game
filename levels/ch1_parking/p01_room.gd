## v2_p01 "겹친 빈자리" (docs/levels/ch1_parking.md).
##
## B2 서쪽 입구 밖에 붙는 공간. 좌표는 B2와 같다 (이 노드는 원점에 둔다, x < 0 쪽).
##
##   입구 홀 V (x -6..0)  ─ 서비스 통로 S (z 23..25, 천장 2.0) ─ 틈 (x -13..-11) ─ 통로 끝 문 (x -24)
##     │  └ 정비대 C (입구 바로 옆, 북쪽 벽 안. 손잡이 작동, A·B와 무관한 미끼)
##     └ 측면길 P (z 28.4..30.4) ─ 관찰창(A 칸 뒤 유리) ─ 정비 칸 (B, x -27..-21)
##
## 정비대 A(통로 틈 옆 칸, 손잡이 부러짐)와 B(정비 칸, 손잡이 작동)는 상태 하나(cart_stop)를 나눠 쓴다.
## 칸마다 같은 모양: 트렌치(깊이 1.2) + 벽 속 칸. 정지점 0 = 칸 깊숙이, 1 = 칸 입구, 2 = 트렌치를 메움.
## 정비대 윗면은 바닥 높이와 같아서 2에서는 걸어서 건넌다.
##
## 명세와 다른 수치: 틈 1.2 m → 2.0 m, 통로 천장 2.0 m. 플레이어는 약 0.9 m 점프하고 달리면 1.2 m 틈은 뛰어넘는다.
## 천장이 낮으면 점프가 0.25 m에서 막혀 달려서 뛰어도 약 1.6 m밖에 못 간다.
## 정지점 1은 통로 쪽으로 나오지 않는다 (조금이라도 나오면 모서리를 밟고 건널 수 있다).
class_name P01Room
extends ParkingFloor

signal solved_signal
signal finished_signal

const STOP_Z := [4.0, 3.3, 1.0]        # 정지점별 정비대 중심 (칸 좌표 z)
const MOVE_TIME := 1.2
const HINT_TIMES := [180.0, 360.0, 540.0]   # 새 증거·상태 변화 없이 3/6/9분 (GDD 7장)
const CEIL_S := 2.0                    # 서비스 통로 천장
const CEIL_P := 2.4                    # 측면길, 정비 칸 천장
const HOOD := 1.6                      # 칸 입구 높이
const GAP_X0 := -13.0
const GAP_X1 := -11.0

var player: CharacterBody3D
var cart_state: SharedStateOwner       # cart_stop (A·B가 나눠 씀)
var decoy_state: SharedStateOwner      # decoy_stop (C만)
var bays := {}                         # "A" / "B" / "C" → Dictionary
var is_solved := false
var is_finished := false
var hint_stage := 0
var stall := 0.0
var hint_scale := 1.0
var active := false                    # 플레이어가 P01에 들어온 뒤부터 힌트 시간을 센다
var shared_moves := 0
var decoy_moves := 0

var _moving := {}                      # state id → bool
var _echo_done := false
var _window_light: SpotLight3D
var _window_lamp_mat: StandardMaterial3D
var _hint_ui: CanvasLayer
var _hint_label: Label
var _hint_hide_at := 0.0
var _hint_next_repeat := 0.0
var _fade: ColorRect
var _recovering := false
var _end_layer: CanvasLayer
var _seen_window := false
var _seen_bay := false
var _steel: StandardMaterial3D
var _dark_steel: StandardMaterial3D
var _yellow: StandardMaterial3D
var _rail_mat: StandardMaterial3D


func build_room() -> void:
	_rng.seed = 2301
	_mats = ParkingMats.for_floor(Vector3.ZERO)
	_font = SystemFont.new()
	_font.font_names = PackedStringArray(["Malgun Gothic", "Noto Sans CJK KR", "Noto Sans KR", "NanumGothic", "UnDotum", "Noto Sans", "DejaVu Sans", "Arial"])
	_font.allow_system_fallback = true
	_font.font_weight = 700
	_steel = _std(Color("8d9396"), 0.45, 0.7)
	_dark_steel = _std(Color("3c4143"), 0.6, 0.6)
	_yellow = _std(Color("e3c23b"), 0.55)
	_rail_mat = _std(Color("6d6a64"), 0.35, 0.85)
	ProcAudio.ensure_reverb_bus("P01Echo", 0.97, 0.75)
	cart_state = SharedStateOwner.new("cart_stop", 0, 0, 2)
	decoy_state = SharedStateOwner.new("decoy_stop", 0, 0, 2)
	cart_state.changed.connect(func(_o: int, n: int) -> void: _on_state(cart_state, n))
	decoy_state.changed.connect(func(_o: int, n: int) -> void: _on_state(decoy_state, n))
	_moving[cart_state.id] = false
	_moving[decoy_state.id] = false

	var g := _group("Space")
	_build_vestibule(g)
	_build_corridor(g)
	_build_side_path(g)
	_build_bay_room(g)
	# 칸 셋: 같은 모양, 같은 크기
	bays["A"] = _make_bay("A", Vector3(-12.0, 0.0, 23.0), 0.0, cart_state, true, true, Vector3(-9.6, 0.05, 24.0), PI / 2)
	bays["B"] = _make_bay("B", Vector3(-24.0, 0.0, 31.4), 0.0, cart_state, true, false, Vector3(-22.0, 0.05, 30.9), PI / 2)
	bays["C"] = _make_bay("C", Vector3(-2.0, 0.0, 22.7), PI, decoy_state, false, false, Vector3(-3.0, 0.05, 24.5), PI / 2)
	_build_posts()
	_build_lights()
	_build_signs()
	_build_ui()


# ================================================================ 도우미

func _std(color: Color, rough := 0.6, metal := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	m.metallic = metal
	return m


## 두 모서리로 상자를 만든다 (월드 좌표 = 이 노드 좌표)
func _bb(parent: Node, a: Vector3, b: Vector3, mat: Material, collide := true) -> void:
	var lo := Vector3(minf(a.x, b.x), minf(a.y, b.y), minf(a.z, b.z))
	var hi := Vector3(maxf(a.x, b.x), maxf(a.y, b.y), maxf(a.z, b.z))
	_box(parent, hi - lo, (lo + hi) / 2.0, mat, collide)


## 칸 좌표 → 월드
func _lw(bay: Dictionary, l: Vector3) -> Vector3:
	return (bay["origin"] as Vector3) + Basis(Vector3.UP, bay["yaw"]) * l


## 칸 좌표의 두 모서리로 상자 (칸은 0 또는 180도만 돌리므로 상자는 그대로 상자다)
func _bbl(bay: Dictionary, parent: Node, a: Vector3, b: Vector3, mat: Material, collide := true) -> void:
	_bb(parent, _lw(bay, a), _lw(bay, b), mat, collide)


## 바닥판 (윗면 y 0, 두께 0.3). hole 사각형(x0, z0, x1, z1)은 비운다.
func _floor(parent: Node, x0: float, z0: float, x1: float, z1: float, hole := Rect2()) -> void:
	var m: Material = _mats["floor"]
	if hole.size == Vector2.ZERO:
		_bb(parent, Vector3(x0, -0.3, z0), Vector3(x1, 0, z1), m)
		return
	var hx0 := hole.position.x
	var hz0 := hole.position.y
	var hx1 := hole.end.x
	var hz1 := hole.end.y
	if hz0 > z0:
		_bb(parent, Vector3(x0, -0.3, z0), Vector3(x1, 0, hz0), m)
	if hz1 < z1:
		_bb(parent, Vector3(x0, -0.3, hz1), Vector3(x1, 0, z1), m)
	if hx0 > x0:
		_bb(parent, Vector3(x0, -0.3, hz0), Vector3(hx0, 0, hz1), m)
	if hx1 < x1:
		_bb(parent, Vector3(hx1, -0.3, hz0), Vector3(x1, 0, hz1), m)


# ================================================================ 공간

## 입구 홀 V: B2 서쪽 입구(z 20.7..27.3)에서 이어진다. 안쪽 x -6..-0.3, z 20.7..30.4, 천장 2.7.
func _build_vestibule(g: Node3D) -> void:
	var wall: Material = _mats["concrete_paint"]
	_floor(g, -6.3, 20.4, 0.0, 30.7, Rect2(-3.0, 20.4, 2.0, 2.3))      # C 트렌치 자리
	_bb(g, Vector3(-6.3, H, 20.4), Vector3(-0.3, H + 0.3, 30.7), _mats["concrete_ceiling"])
	# 북쪽 벽 (C 칸 입구 x -3..-1)
	_bb(g, Vector3(-6.3, 0, 20.4), Vector3(-3.0, H, 20.7), wall)
	_bb(g, Vector3(-1.0, 0, 20.4), Vector3(-0.3, H, 20.7), wall)
	_bb(g, Vector3(-3.0, HOOD + 0.2, 20.4), Vector3(-1.0, H, 20.7), wall)
	# 남쪽 벽
	_bb(g, Vector3(-6.3, 0, 30.4), Vector3(-0.3, H, 30.7), wall)
	# 서쪽 벽: 서비스 통로 입구(z 23..25, 높이 2.0), 측면길 입구(z 28.4..30.4, 높이 2.4)
	_bb(g, Vector3(-6.3, 0, 20.7), Vector3(-6.0, H, 23.0), wall)
	_bb(g, Vector3(-6.3, 0, 25.0), Vector3(-6.0, H, 28.4), wall)
	_bb(g, Vector3(-6.3, CEIL_S, 23.0), Vector3(-6.0, H, 25.0), wall)
	_bb(g, Vector3(-6.3, CEIL_P, 28.4), Vector3(-6.0, H, 30.4), wall)
	# C 트렌치 둘레 난간 (입구 홀에서는 떨어지지 않는다)
	_railing(g, Vector3(-3.25, 0, 20.75), Vector3(-3.25, 0, 22.95))
	_railing(g, Vector3(-3.25, 0, 22.95), Vector3(-0.75, 0, 22.95))
	_railing(g, Vector3(-0.75, 0, 22.95), Vector3(-0.75, 0, 20.75))
	# B2 주차장에서 이어지는 노면 표시: 안쪽으로 들어갈수록 끊긴다
	_flat(g, Vector2(5.2, 0.12), Vector3(-3.15, 0.004, 23.3), _mats["paint_yellow"])


## 서비스 통로 S: x -24..-6, 안쪽 z 23..25, 천장 2.0. 가운데 틈(트렌치) x -13..-11.
func _build_corridor(g: Node3D) -> void:
	var wall: Material = _mats["helix_wall"]
	_floor(g, -24.0, 22.7, -6.3, 25.3, Rect2(GAP_X0, 23.0, GAP_X1 - GAP_X0, 2.3))
	_bb(g, Vector3(-24.3, CEIL_S, 22.7), Vector3(-6.3, CEIL_S + 0.3, 25.3), _mats["concrete_ceiling"])
	_bb(g, Vector3(-24.3, 0, 22.7), Vector3(-6.3, CEIL_S, 23.0), wall)                  # 북
	_bb(g, Vector3(-24.3, 0, 25.0), Vector3(GAP_X0, CEIL_S, 25.3), wall)                # 남 (A 칸 서쪽)
	_bb(g, Vector3(GAP_X1, 0, 25.0), Vector3(-6.3, CEIL_S, 25.3), wall)                 # 남 (A 칸 동쪽)
	_bb(g, Vector3(GAP_X0, HOOD + 0.2, 25.0), Vector3(GAP_X1, CEIL_S, 25.3), wall)      # A 칸 입구 위
	# 통로 끝 벽과 문 (P02로 가는 문. 아직 잠겨 있다)
	_bb(g, Vector3(-24.3, 0, 23.0), Vector3(-24.0, CEIL_S, 23.55), wall)
	_bb(g, Vector3(-24.3, 0, 24.45), Vector3(-24.0, CEIL_S, 25.0), wall)
	_bb(g, Vector3(-24.3, 1.9, 23.55), Vector3(-24.0, CEIL_S, 24.45), wall)
	var door := SpringDoor.new()
	door.width = 0.9
	door.height = 1.9
	door.sfx_bus = "Parking"
	door.position = Vector3(-24.15, 0, 24.0)
	door.rotation.y = -PI / 2
	add_child(door)
	door.build(Color("7f8784"), Color("4f5552"), 0.3)
	door.lock()
	set_meta("end_door", door)
	# 통로 바닥 노란 안전선 (틈 앞에서 끊긴다)
	_flat(g, Vector2(4.4, 0.1), Vector3(-8.65, 0.004, 23.15), _mats["paint_yellow"])
	_flat(g, Vector2(4.4, 0.1), Vector3(-8.65, 0.004, 24.85), _mats["paint_yellow"])
	_flat(g, Vector2(10.6, 0.1), Vector3(-18.6, 0.004, 23.15), _mats["paint_yellow"])
	_flat(g, Vector2(10.6, 0.1), Vector3(-18.6, 0.004, 24.85), _mats["paint_yellow"])
	# 틈 가장자리 경고 줄무늬
	for x in [GAP_X1 + 0.2, GAP_X0 - 0.2]:
		_flat(g, Vector2(0.3, 1.9), Vector3(x, 0.005, 24.0), _hazard_mat())


## 측면길 P: x -27..-6, 안쪽 z 28.4..30.4, 천장 2.4. 북쪽 벽에 A 칸을 들여다보는 관찰창.
func _build_side_path(g: Node3D) -> void:
	var wall: Material = _mats["helix_wall"]
	_floor(g, -27.0, 28.4, -6.3, 30.4)
	_bb(g, Vector3(-27.3, CEIL_P, 28.1), Vector3(-6.3, CEIL_P + 0.3, 30.7), _mats["concrete_ceiling"])
	# 북쪽 벽 (A 칸 뒤가 창)
	_bb(g, Vector3(-27.3, 0, 28.1), Vector3(GAP_X0 - 0.3, CEIL_P, 28.4), wall)
	_bb(g, Vector3(GAP_X1 + 0.3, 0, 28.1), Vector3(-6.3, CEIL_P, 28.4), wall)
	_bb(g, Vector3(GAP_X0 - 0.3, HOOD + 0.2, 28.1), Vector3(GAP_X1 + 0.3, CEIL_P, 28.4), wall)
	# 남쪽 벽 (정비 칸 입구 x -27..-21)
	_bb(g, Vector3(-20.7, 0, 30.4), Vector3(-6.3, CEIL_P, 30.7), wall)
	# 서쪽 끝 벽 (정비 칸까지 이어진다)
	_bb(g, Vector3(-27.3, 0, 28.4), Vector3(-27.0, CEIL_P, 33.7), wall)
	# 관찰창 앞 안전 난간
	_railing(g, Vector3(GAP_X0 - 0.4, 0, 28.75), Vector3(GAP_X1 + 0.4, 0, 28.75))


## 정비 칸: x -27..-21, z 30.4..33.4. 남쪽 벽에 B 칸.
func _build_bay_room(g: Node3D) -> void:
	var wall: Material = _mats["helix_wall"]
	_floor(g, -27.0, 30.4, -21.0, 33.7, Rect2(-25.0, 31.4, 2.0, 2.3))
	_bb(g, Vector3(-27.3, CEIL_P, 30.7), Vector3(-20.7, CEIL_P + 0.3, 33.7), _mats["concrete_ceiling"])
	_bb(g, Vector3(-21.0, 0, 30.4), Vector3(-20.7, CEIL_P, 33.7), wall)                  # 동
	_bb(g, Vector3(-27.0, 0, 33.4), Vector3(-25.0, CEIL_P, 33.7), wall)                  # 남 (B 칸 서쪽)
	_bb(g, Vector3(-23.0, 0, 33.4), Vector3(-21.0, CEIL_P, 33.7), wall)                  # 남 (B 칸 동쪽)
	_bb(g, Vector3(-25.0, HOOD + 0.2, 33.4), Vector3(-23.0, CEIL_P, 33.7), wall)         # B 칸 입구 위
	# B 트렌치 둘레 난간 (정비 칸에서는 떨어지지 않는다)
	_railing(g, Vector3(-25.25, 0, 33.35), Vector3(-25.25, 0, 31.15))
	_railing(g, Vector3(-25.25, 0, 31.15), Vector3(-22.75, 0, 31.15))
	_railing(g, Vector3(-22.75, 0, 31.15), Vector3(-22.75, 0, 33.35))


## 안전 난간: 높이 1.05 (점프로 못 넘는다). 기둥 + 위·가운데 가로대.
func _railing(g: Node3D, a: Vector3, b: Vector3) -> void:
	var d := b - a
	var length := d.length()
	var yaw := atan2(d.x, d.z)
	var n := int(ceil(length / 1.2))
	for i in n + 1:
		var p := a + d * (float(i) / n)
		_box(g, Vector3(0.05, 1.05, 0.05), p + Vector3(0, 0.525, 0), _yellow, false)
	for y in [1.02, 0.55]:
		var bar := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.045, 0.045, length)
		bar.mesh = bm
		bar.material_override = _yellow
		bar.position = (a + b) / 2.0 + Vector3(0, y, 0)
		bar.rotation.y = yaw
		g.add_child(bar)
	# 충돌: 난간 전체를 얇은 판으로 (보이는 난간과 같은 높이)
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.08, 1.05, length)
	cs.shape = shape
	body.position = (a + b) / 2.0 + Vector3(0, 0.525, 0)
	body.rotation.y = yaw
	body.add_child(cs)
	g.add_child(body)


func _hazard_mat() -> StandardMaterial3D:
	var img := Image.create(64, 64, false, Image.FORMAT_RGB8)
	for y in 64:
		for x in 64:
			var stripe := int(floor((x + y) / 16.0)) % 2 == 0
			img.set_pixel(x, y, Color("d9b632") if stripe else Color("2a2a28"))
	var m := StandardMaterial3D.new()
	m.albedo_texture = ImageTexture.create_from_image(img)
	m.uv1_scale = Vector3(0.6, 4.0, 1.0)
	m.roughness = 0.7
	return m


# ================================================================ 칸과 정비대

## 칸 하나: 트렌치(칸 좌표 z 0..2) + 벽 속 칸(z 2..5.1). 벽선은 z 2..2.3.
## glass_back: 칸 뒤가 관찰창 (A). marked: 정비대에 꺾인 노랑 선과 용접 흠집 (A·B. C는 곧은 선, 흠집 없음).
func _make_bay(name: String, origin: Vector3, yaw: float, state: SharedStateOwner, marked: bool, glass_back: bool, safe: Vector3, safe_yaw: float) -> Dictionary:
	var bay := {"name": name, "origin": origin, "yaw": yaw, "state": state, "safe": safe, "safe_yaw": safe_yaw}
	var g := _group("Bay" + name)
	var wall: Material = _mats["helix_wall"]
	var conc: Material = _mats["ramp_floor"]
	# 트렌치 바닥, 끝벽, 옆벽 (바닥판 아래)
	_bbl(bay, g, Vector3(-1.3, -1.5, -0.3), Vector3(1.3, -1.2, 5.4), conc)
	_bbl(bay, g, Vector3(-1.3, -1.2, -0.3), Vector3(1.3, -0.3, 0.0), wall)
	_bbl(bay, g, Vector3(-1.3, -1.2, 0.0), Vector3(-1.0, -0.3, 2.3), wall)
	_bbl(bay, g, Vector3(1.0, -1.2, 0.0), Vector3(1.3, -0.3, 2.3), wall)
	# 벽 속 칸: 옆벽, 지붕, 뒷벽
	_bbl(bay, g, Vector3(-1.3, -1.2, 2.3), Vector3(-1.0, HOOD + 0.2, 5.4), wall)
	_bbl(bay, g, Vector3(1.0, -1.2, 2.3), Vector3(1.3, HOOD + 0.2, 5.4), wall)
	_bbl(bay, g, Vector3(-1.0, HOOD, 2.0), Vector3(1.0, HOOD + 0.2, 5.1), _mats["concrete_ceiling"])
	if glass_back:
		_bbl(bay, g, Vector3(-1.0, -1.2, 5.1), Vector3(1.0, 0.0, 5.4), wall)
		var glass := StandardMaterial3D.new()
		glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		glass.albedo_color = Color(0.62, 0.74, 0.76, 0.16)
		glass.roughness = 0.05
		glass.metallic_specular = 0.8
		_bbl(bay, g, Vector3(-1.0, 0.0, 5.18), Vector3(1.0, HOOD, 5.32), glass)
		# 창틀
		_bbl(bay, g, Vector3(-1.0, HOOD - 0.05, 5.1), Vector3(1.0, HOOD, 5.4), _dark_steel, false)
		_bbl(bay, g, Vector3(-1.0, 0.0, 5.1), Vector3(1.0, 0.05, 5.4), _dark_steel, false)
		_bbl(bay, g, Vector3(-1.0, HOOD, 5.1), Vector3(1.0, HOOD + 0.2, 5.4), wall)
	else:
		_bbl(bay, g, Vector3(-1.0, -1.2, 5.1), Vector3(1.0, HOOD + 0.2, 5.4), wall)
	# 레일 두 줄
	for x in [-0.6, 0.6]:
		_bbl(bay, g, Vector3(x - 0.04, -1.2, 0.0), Vector3(x + 0.04, -1.12, 5.1), _rail_mat, false)
	# 레일 눈금: 칸 왼쪽 벽 안쪽 면, 정비대 뒤 끝이 닿는 자리마다 숫자
	var marks := [[5.0, "0"], [4.3, "1"], [2.35, "2"]]
	var face_x := -1.0 if yaw == 0.0 else 1.0
	for mk in marks:
		var z: float = mk[0]
		_bbl(bay, g, Vector3(-0.99, 0.08, z - 0.015), Vector3(-1.0, 0.38, z + 0.015), _yellow, false)
		var lb := _label(g, str(mk[1]), _lw(bay, Vector3(-0.985, 0.5, z)), yaw + PI / 2, 0.0022, Color(0.95, 0.85, 0.3), 96)
		lb.double_sided = false
	_bbl(bay, g, Vector3(-0.99, 0.22, 2.3), Vector3(-1.0, 0.24, 5.1), _yellow, false)
	bay["face_x"] = face_x
	# 레일 강조 띠 (힌트 ②: A 정비대가 움직일 때 빛난다)
	var glow := StandardMaterial3D.new()
	glow.albedo_color = Color("e3c23b")
	glow.emission_enabled = true
	glow.emission = Color("ffd84a")
	glow.emission_energy_multiplier = 0.0
	for x in [-0.6, 0.6]:
		_bbl(bay, g, Vector3(x - 0.05, -1.12, 0.05), Vector3(x + 0.05, -1.105, 5.05), glow, false)
	bay["glow"] = glow
	# 정비대
	var body := AnimatableBody3D.new()
	body.name = "Cart" + name
	body.sync_to_physics = false
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(2.0, 1.2, 2.0)
	cs.shape = shape
	body.add_child(cs)
	body.rotation.y = yaw
	body.position = _lw(bay, Vector3(0, -0.6, STOP_Z[state.value]))
	add_child(body)
	_cart_visual(body, marked)
	bay["body"] = body
	var sfx := AudioStreamPlayer3D.new()
	sfx.bus = "Parking"
	sfx.unit_size = 7.0
	sfx.max_distance = 60.0
	sfx.position = Vector3(0, 0.6, 0)
	body.add_child(sfx)
	bay["sfx"] = sfx
	return bay


## 정비대 모양: 철제 몸통, 발판 무늬 윗면, 옆면의 노랑 선. marked면 선이 한 자리에서 꺾이고 용접 흠집이 있다.
func _cart_visual(body: Node3D, marked: bool) -> void:
	_box(body, Vector3(1.96, 1.14, 1.96), Vector3(0, -0.03, 0), _dark_steel, false)
	_box(body, Vector3(1.98, 0.04, 1.98), Vector3(0, 0.58, 0), _steel, false)
	# 발판 무늬 (윗면 위 아주 얇은 줄)
	for i in 9:
		var z := -0.8 + 0.2 * i
		_box(body, Vector3(1.8, 0.006, 0.05), Vector3(0, 0.603, z), _dark_steel, false)
	# 바퀴
	for x in [-0.6, 0.6]:
		for z in [-0.7, 0.7]:
			_box(body, Vector3(0.1, 0.16, 0.22), Vector3(x, -0.52, z), _rail_mat, false)
	# 앞뒤 옆면(±z)과 윗면 가장자리의 노랑 선
	for side in [-1.0, 1.0]:
		var zf: float = side * 0.985
		if marked:
			# 왼쪽 0.9 m는 수평, 이어서 14도 꺾여 올라간다
			_box(body, Vector3(1.0, 0.07, 0.012), Vector3(-0.48, 0.25, zf), _yellow, false)
			var seg := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(0.96, 0.07, 0.012)
			seg.mesh = bm
			seg.material_override = _yellow
			seg.position = Vector3(0.47, 0.25 + 0.47 * tan(deg_to_rad(14.0)), zf)
			seg.rotation.z = deg_to_rad(14.0)
			body.add_child(seg)
			# 꺾인 자리의 용접 흠집: 굵은 비드 + 긁힌 자국
			_box(body, Vector3(0.06, 0.34, 0.02), Vector3(0.0, 0.2, zf), _std(Color("2b2622"), 0.9, 0.4), false)
			for k in 3:
				_box(body, Vector3(0.22, 0.012, 0.014), Vector3(0.18 + 0.05 * k, 0.05 - 0.05 * k, zf), _std(Color("b9b5ad"), 0.3, 0.9), false)
		else:
			_box(body, Vector3(1.94, 0.07, 0.012), Vector3(0, 0.25, zf), _yellow, false)
	# 윗면 앞쪽 가장자리 선 (같은 꺾임)
	if marked:
		_box(body, Vector3(1.0, 0.008, 0.06), Vector3(-0.48, 0.604, -0.9), _yellow, false)
		var top := MeshInstance3D.new()
		var tb := BoxMesh.new()
		tb.size = Vector3(0.96, 0.008, 0.06)
		top.mesh = tb
		top.material_override = _yellow
		top.position = Vector3(0.47, 0.604, -0.9 + 0.47 * tan(deg_to_rad(14.0)))
		top.rotation.y = -deg_to_rad(14.0)
		body.add_child(top)
	else:
		_box(body, Vector3(1.94, 0.008, 0.06), Vector3(0, 0.604, -0.9), _yellow, false)
	var stencil := _label(body, "정비대", Vector3(0, -0.15, -0.995), PI, 0.0025, Color(0.85, 0.85, 0.8), 96)
	stencil.double_sided = false


# ================================================================ 손잡이

## 조작대: 기둥 + 손잡이 둘(전진/후진). A는 손잡이가 부러져 있다.
func _build_posts() -> void:
	_post(bays["B"], Vector3(-22.3, 0, 30.85), 0.0, false)
	_post(bays["C"], Vector3(-3.75, 0, 22.95), PI, false)
	_post(bays["A"], Vector3(-10.4, 0, 24.75), 0.0, true)


func _post(bay: Dictionary, pos: Vector3, yaw: float, broken: bool) -> void:
	var p := Node3D.new()
	p.name = "Post" + String(bay["name"])
	p.position = pos
	p.rotation.y = yaw
	add_child(p)
	_box(p, Vector3(0.22, 1.1, 0.18), Vector3(0, 0.55, 0), _std(Color("2f4a3a"), 0.6, 0.3))
	_box(p, Vector3(0.3, 0.3, 0.2), Vector3(0, 1.1, 0), _std(Color("33383a"), 0.5, 0.5), false)
	var lamp := _std(Color("5a1010"), 0.4)
	lamp.emission_enabled = true
	lamp.emission = Color("ff3020")
	lamp.emission_energy_multiplier = 0.0
	_box(p, Vector3(0.05, 0.05, 0.03), Vector3(0, 1.31, -0.08), lamp, false)
	bay["lamp"] = lamp
	var sfx := AudioStreamPlayer3D.new()
	sfx.bus = "Parking"
	sfx.unit_size = 5.0
	sfx.position = Vector3(0, 1.1, 0)
	p.add_child(sfx)
	bay["post_sfx"] = sfx
	bay["post"] = p
	if broken:
		# 부러진 손잡이: 짧은 그루터기와 바닥에 떨어진 조각
		_box(p, Vector3(0.05, 0.08, 0.05), Vector3(0, 1.29, -0.12), _steel, false)
		var piece := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.04, 0.32, 0.04)
		piece.mesh = bm
		piece.material_override = _steel
		piece.position = Vector3(0.25, 0.02, -0.3)
		piece.rotation = Vector3(PI / 2, 0.6, 0)
		p.add_child(piece)
		var it := Interactable.new()
		it.position = Vector3(0, 1.15, -0.1)
		var cs := CollisionShape3D.new()
		var sh := BoxShape3D.new()
		sh.size = Vector3(0.3, 0.35, 0.2)
		cs.shape = sh
		it.add_child(cs)
		p.add_child(it)
		it.interacted.connect(func() -> void:
			_play(sfx, ProcAudio.latch())
			_blink(bay))
		_label(p, "고장", Vector3(0, 0.85, -0.095), PI, 0.0018, Color(0.9, 0.3, 0.25), 80)
		return
	# 손잡이 두 개: 왼쪽 = 후진(칸 안으로), 오른쪽 = 전진(트렌치로)
	for d in [-1, 1]:
		var x: float = -0.075 * d   # 앞에서 보면 오른쪽이 전진
		var pivot := Node3D.new()
		pivot.position = Vector3(x, 1.2, -0.06)
		p.add_child(pivot)
		_box(pivot, Vector3(0.03, 0.26, 0.03), Vector3(0, 0.13, 0), _steel, false)
		_box(pivot, Vector3(0.05, 0.07, 0.05), Vector3(0, 0.27, 0), _std(Color("c23a2e") if d > 0 else Color("2e5fc2"), 0.5), false)
		var it := Interactable.new()
		it.position = Vector3(x, 1.33, -0.06)
		var cs := CollisionShape3D.new()
		var sh := BoxShape3D.new()
		sh.size = Vector3(0.11, 0.3, 0.14)
		cs.shape = sh
		it.add_child(cs)
		p.add_child(it)
		var dir: int = d
		it.interacted.connect(func() -> void: _on_lever(bay, dir, pivot))
		_label(p, "전진 ▶" if d > 0 else "◀ 후진", Vector3(x * 1.05, 1.06, -0.105), PI, 0.0007, Color(0.92, 0.92, 0.88), 64)
	bay["levers"] = true


func _on_lever(bay: Dictionary, dir: int, pivot: Node3D) -> void:
	var state: SharedStateOwner = bay["state"]
	var sfx: AudioStreamPlayer3D = bay["post_sfx"]
	if _moving[state.id]:
		_play(sfx, ProcAudio.latch())
		return
	var target := state.value + dir
	if target < state.min_value or target > state.max_value:
		_play(sfx, ProcAudio.latch())
		_blink(bay)
		return
	var who := _occupant(state)
	if who != "":
		# 정비대 위나 트렌치 안에 사람이 있다: 걸쇠가 걸려 움직이지 않는다
		print("P01 hold: occupied (%s)" % who)
		_play(sfx, ProcAudio.latch())
		_blink(bay)
		return
	var tw := create_tween()
	tw.tween_property(pivot, "rotation:x", -0.5 * dir, 0.12)
	tw.tween_property(pivot, "rotation:x", 0.0, 0.3).set_delay(0.25)
	_play(sfx, ProcAudio.lever())
	state.request(target)


## 이 상태를 쓰는 정비대 위, 또는 그 트렌치 안에 플레이어가 있으면 칸 이름을 돌려준다.
func _occupant(state: SharedStateOwner) -> String:
	if player == null:
		return ""
	for k: String in bays:
		var bay: Dictionary = bays[k]
		if bay["state"] != state:
			continue
		var l := (bay["body"] as Node3D).to_local(player.global_position)
		if absf(l.x) < 1.15 and absf(l.z) < 1.15 and l.y > 0.4 and l.y < 1.2:
			return k + ":top"
		var t := Basis(Vector3.UP, bay["yaw"]).inverse() * (player.global_position - (bay["origin"] as Vector3))
		if absf(t.x) < 1.0 and t.z > -0.3 and t.z < 5.1 and t.y < -0.2:
			return k + ":trench"
	return ""


func _blink(bay: Dictionary) -> void:
	var lamp: StandardMaterial3D = bay["lamp"]
	var tw := create_tween()
	for i in 3:
		tw.tween_property(lamp, "emission_energy_multiplier", 4.0, 0.06)
		tw.tween_property(lamp, "emission_energy_multiplier", 0.0, 0.14)


func _play(p: AudioStreamPlayer3D, s: AudioStream) -> void:
	p.stream = s
	p.play()


## 상태가 바뀌었다: 이 상태를 쓰는 모든 정비대가 같이 움직이고 같은 소리를 낸다.
func _on_state(state: SharedStateOwner, value: int) -> void:
	_moving[state.id] = true
	stall = 0.0
	if state == cart_state:
		shared_moves += 1
	else:
		decoy_moves += 1
	print("P01 %s -> %d" % [state.id, value])
	var roll := ProcAudio.cart_roll(MOVE_TIME)
	var first_shared := state == cart_state and not _echo_done
	for k: String in bays:
		var bay: Dictionary = bays[k]
		if bay["state"] != state:
			continue
		var body: AnimatableBody3D = bay["body"]
		var to := _lw(bay, Vector3(0, -0.6, STOP_Z[value]))
		var tw := create_tween()
		tw.tween_property(body, "position", to, MOVE_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		var sfx: AudioStreamPlayer3D = bay["sfx"]
		sfx.stream = roll
		# 처음 한 번: A 쪽 소리에 긴 울림 (같은 마찰음이 먼 곳에서 겹친다)
		sfx.bus = "P01Echo" if (first_shared and k == "A") else "Parking"
		sfx.volume_db = 2.0 if (state == cart_state and k == "A" and hint_stage >= 2) else 0.0
		sfx.play()
		if state == cart_state and k == "A" and hint_stage >= 2:
			var glow: StandardMaterial3D = bay["glow"]
			var gt := create_tween()
			gt.tween_property(glow, "emission_energy_multiplier", 3.0, 0.2)
			gt.tween_property(glow, "emission_energy_multiplier", 0.0, MOVE_TIME + 0.6)
	if first_shared:
		_echo_done = true
	get_tree().create_timer(MOVE_TIME + 0.05).timeout.connect(func() -> void: _moving[state.id] = false)


# ================================================================ 조명, 표지

func _build_lights() -> void:
	var g := _group("Lights")
	_fixture(g, Vector3(-3.2, H, 25.6), PI / 2, "on")
	_fixture(g, Vector3(-8.2, CEIL_S, 24.0), 0.0, "on")
	_fixture(g, Vector3(-12.0, CEIL_S, 24.0), 0.0, "on")
	_fixture(g, Vector3(-18.5, CEIL_S, 24.0), 0.0, "off")
	_fixture(g, Vector3(-22.6, CEIL_S, 24.0), 0.0, "on")
	_fixture(g, Vector3(-9.0, CEIL_P, 29.4), 0.0, "on")
	_fixture(g, Vector3(-17.5, CEIL_P, 29.4), 0.0, "off")
	_fixture(g, Vector3(-24.0, CEIL_P, 32.0), PI / 2, "on")
	# 틈 위 작업등: 나선을 내려와 B2 복도 끝을 보면 가장 먼저 눈에 띄는 밝은 자리 (목표와 장애물이 먼저 보인다)
	var work := OmniLight3D.new()
	work.position = Vector3(-12.0, CEIL_S - 0.25, 24.0)
	work.light_color = Color("ffe2a8")
	work.light_energy = 2.4
	work.omni_range = 7.0
	work.shadow_enabled = true
	g.add_child(work)
	var lamp_m := _std(Color("3a3a36"), 0.4)
	lamp_m.emission_enabled = true
	lamp_m.emission = Color("ffe2a8")
	lamp_m.emission_energy_multiplier = 4.0
	_box(g, Vector3(0.4, 0.1, 0.25), Vector3(-12.0, CEIL_S - 0.05, 24.0), lamp_m, false)
	# 칸 안 작은 등 (A·B·C 같은 자리)
	for k: String in bays:
		var bay: Dictionary = bays[k]
		var l := OmniLight3D.new()
		l.position = _lw(bay, Vector3(0, HOOD - 0.15, 4.2))
		l.light_color = Color("e8e4d0")
		l.light_energy = 0.35
		l.omni_range = 3.2
		g.add_child(l)
	# 힌트 ① 관찰창 위 작업등 (처음에는 꺼져 있다)
	var a: Dictionary = bays["A"]
	_window_lamp_mat = _std(Color("3a3a36"), 0.4)
	_window_lamp_mat.emission_enabled = true
	_window_lamp_mat.emission = Color("fff2c0")
	_window_lamp_mat.emission_energy_multiplier = 0.0
	_box(g, Vector3(0.5, 0.12, 0.22), _lw(a, Vector3(0, CEIL_P - 0.12, 5.75)), _window_lamp_mat, false)
	_window_light = SpotLight3D.new()
	_window_light.position = _lw(a, Vector3(0, CEIL_P - 0.2, 5.75))
	_window_light.light_color = Color("fff2c0")
	_window_light.light_energy = 0.0
	_window_light.spot_range = 6.0
	_window_light.spot_angle = 38.0
	_window_light.shadow_enabled = true
	add_child(_window_light)
	_window_light.look_at(_lw(a, Vector3(0, -0.6, 4.0)), Vector3.UP)


func _build_signs() -> void:
	var g := _group("Signs")
	# 서비스 통로 입구 위 표지
	_box(g, Vector3(0.04, 0.32, 1.7), Vector3(-5.97, 2.25, 24.0), _std(Color("f1f0ea"), 0.6), false)
	_label(g, "서비스 통로", Vector3(-5.945, 2.25, 24.0), PI / 2, 0.0021, Color(0.12, 0.22, 0.16), 112)
	# 측면길 입구 위 표지
	_box(g, Vector3(0.04, 0.24, 1.5), Vector3(-5.97, 2.55, 29.4), _std(Color("f1f0ea"), 0.6), false)
	_label(g, "정비실  →", Vector3(-5.945, 2.55, 29.4), PI / 2, 0.0018, Color(0.12, 0.22, 0.16), 112)
	# 통로 끝 문 위
	_label(g, "점검실 · 관계자 외 출입금지", Vector3(-23.98, 1.96, 24.0), PI / 2, 0.0011, Color(0.85, 0.25, 0.2), 96)


# ================================================================ 화면 (힌트 문장, 페이드, 끝)

func _build_ui() -> void:
	_hint_ui = CanvasLayer.new()
	_hint_ui.layer = 15
	add_child(_hint_ui)
	_hint_label = Label.new()
	_hint_label.anchor_left = 0.0
	_hint_label.anchor_right = 1.0
	_hint_label.anchor_top = 1.0
	_hint_label.anchor_bottom = 1.0
	_hint_label.offset_top = -110.0
	_hint_label.offset_bottom = -70.0
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_label.add_theme_font_override("font", _font)
	_hint_label.add_theme_font_size_override("font_size", 22)
	_hint_label.add_theme_color_override("font_color", Color(0.92, 0.92, 0.86))
	_hint_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_hint_label.add_theme_constant_override("outline_size", 6)
	_hint_label.modulate.a = 0.0
	_hint_ui.add_child(_hint_label)
	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 0)
	_fade.anchor_right = 1.0
	_fade.anchor_bottom = 1.0
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint_ui.add_child(_fade)


func show_hint_text(text: String, seconds := 10.0) -> void:
	_hint_label.text = text
	var tw := create_tween()
	tw.tween_property(_hint_label, "modulate:a", 1.0, 0.6)
	_hint_hide_at = Time.get_ticks_msec() / 1000.0 + seconds


func _show_end_card() -> void:
	_end_layer = CanvasLayer.new()
	_end_layer.layer = 18
	add_child(_end_layer)
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0)
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_end_layer.add_child(bg)
	var lb := Label.new()
	lb.text = "P01 · 겹친 빈자리\n\n여기까지 만들었습니다.\n점검실 너머(P02)는 아직 없습니다."
	lb.anchor_right = 1.0
	lb.anchor_bottom = 1.0
	lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lb.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lb.add_theme_font_override("font", _font)
	lb.add_theme_font_size_override("font_size", 28)
	lb.add_theme_color_override("font_color", Color(0.86, 0.88, 0.84))
	lb.modulate.a = 0.0
	_end_layer.add_child(lb)
	var tw := create_tween()
	tw.tween_property(bg, "color:a", 0.92, 2.0)
	tw.parallel().tween_property(lb, "modulate:a", 1.0, 2.5)


# ================================================================ 진행

func _process(delta: float) -> void:
	super._process(delta)
	if player == null:
		return
	var p := player.global_position
	if not active and p.x < -0.2:
		active = true
	if active and not is_solved:
		stall += delta * hint_scale * Settings.hint_scale()
		while hint_stage < HINT_TIMES.size() and stall >= HINT_TIMES[hint_stage]:
			hint_stage += 1
			_apply_hint(hint_stage)
		if hint_stage >= 3 and Time.get_ticks_msec() / 1000.0 >= _hint_next_repeat:
			_hint_next_repeat = Time.get_ticks_msec() / 1000.0 + 120.0
			show_hint_text("흠집이 같은 정비대를 한 칸만 움직이고 창 너머를 확인해 보세요.")
	# 새로 본 것 (증거): 정체 시간만 다시 센다
	if not _seen_window and p.z > 28.4 and p.z < 30.4 and absf(p.x - (GAP_X0 + GAP_X1) / 2.0) < 1.5:
		_seen_window = true
		stall = 0.0
	if not _seen_bay and p.z > 30.4 and p.x < -21.0:
		_seen_bay = true
		stall = 0.0
	if _hint_hide_at > 0.0 and Time.get_ticks_msec() / 1000.0 >= _hint_hide_at:
		_hint_hide_at = 0.0
		create_tween().tween_property(_hint_label, "modulate:a", 0.0, 0.8)
	_check_fall(p)
	if not is_solved and cart_state.value == 2 and p.x < GAP_X0 - 0.3 and p.z > 23.0 and p.z < 25.0 and p.y > -0.2:
		is_solved = true
		print("PUZZLE v2_p01 SOLVED  shared_moves=%d decoy_moves=%d hint=%d" % [shared_moves, decoy_moves, hint_stage])
		solved_signal.emit()
	if is_solved and not is_finished and p.x < -22.6 and p.z > 23.0 and p.z < 25.0:
		is_finished = true
		finished_signal.emit()
		_show_end_card()


func _apply_hint(stage: int) -> void:
	print("P01 hint stage ", stage)
	match stage:
		1:
			# ① 관찰창 위 작업등이 켜져 A 칸의 레일 눈금을 비춘다
			_window_light.light_energy = 2.2
			_window_lamp_mat.emission_energy_multiplier = 3.0
		2:
			# ② 이제부터 B를 움직이면 A 레일이 빛나고 A 쪽 소리가 조금 크다 (_on_state)
			pass
		3:
			_hint_next_repeat = 0.0


## 트렌치에 떨어지면 몸만 그 칸 앞 안전한 자리로 옮긴다 (장치 상태는 그대로).
func _check_fall(p: Vector3) -> void:
	if _recovering or p.y > -0.5:
		return
	for k: String in bays:
		var bay: Dictionary = bays[k]
		var t := Basis(Vector3.UP, bay["yaw"]).inverse() * (p - (bay["origin"] as Vector3))
		if absf(t.x) < 1.1 and t.z > -0.4 and t.z < 5.2:
			_recover(bay)
			return


func _recover(bay: Dictionary) -> void:
	_recovering = true
	print("P01 fell into trench ", bay["name"], " -> safe point")
	var tw := create_tween()
	tw.tween_interval(0.5)
	tw.tween_property(_fade, "color:a", 1.0, 0.35)
	tw.tween_callback(func() -> void:
		player.global_position = bay["safe"]
		player.rotation.y = bay["safe_yaw"]
		player.velocity = Vector3.ZERO)
	tw.tween_interval(0.3)
	tw.tween_property(_fade, "color:a", 0.0, 0.5)
	tw.tween_callback(func() -> void: _recovering = false)


## 처음 상태로 (현재 퍼즐만. 몸은 입구 안전 지점으로)
func reset_current() -> void:
	for st: SharedStateOwner in [cart_state, decoy_state]:
		st.restore(0)
	for k: String in bays:
		var bay: Dictionary = bays[k]
		(bay["body"] as Node3D).position = _lw(bay, Vector3(0, -0.6, STOP_Z[0]))
	if player:
		player.global_position = Vector3(-1.5, 0.05, 24.0)
		player.rotation.y = PI / 2


# ================================================================ 테스트용

func lever_of(bay_name: String, dir: int) -> Interactable:
	var p: Node3D = bays[bay_name]["post"]
	for c in p.get_children():
		if c is Interactable and absf((c as Node3D).position.x + 0.075 * dir) < 0.01:
			return c
	return null


func cart_local_z(bay_name: String) -> float:
	var bay: Dictionary = bays[bay_name]
	var t := Basis(Vector3.UP, bay["yaw"]).inverse() * ((bay["body"] as Node3D).global_position - (bay["origin"] as Vector3))
	return t.z
