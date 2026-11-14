## v2_p01 "겹친 빈자리" + v2_p02 "덮개의 앞과 뒤" (docs/levels/ch1_parking.md).
##
## B2 서쪽 입구 밖의 기계식 주차 구역. 좌표는 B2와 같다 (이 노드는 원점, x < 0 쪽).
##
## P01 통로 (z 22.6..25.4):  입구 S0 ─ 피트 B ─ R0(2호기 조작반) ─ 피트 A ─ M0
##   2호기(lift_2, 0..2): B는 같은 방향, A는 거꾸로. 처음 2 (B 메워짐, A 바닥).
##
## P02 홀 (M0에서 서쪽):
##
##         z 14.2 ┌ M ─ 피트 KM(4호기) ─ K(3호기 조작반)
##                │ M       [기계실 벽]        │ 피트 RK(3호기, 거꾸로)
##   z 22.6..25.4 │ M ─ 피트 RM(3호기)│통로판 ─ R(덮개 손잡이) ─ 피트 SR(4호기, 거꾸로, 덮개) ─ M0(4호기 조작반)
##                └ 피트 ME(4호기, 거꾸로) ─ 출구 E
##
##   3호기(lift_3, 0/1)·4호기(lift_4, 0/1)는 위/아래 두 칸. 처음 3호기 아래, 4호기 위, 덮개 열림(0).
##   덮개판 D-7: 1이면 피트 SR 위로 덮개가 밀려 나오고, 같은 판인 통로판이 내려와 R─RM 사이를 막는다.
##   출구로 가는 조합은 3호기 위·4호기 아래·덮개 0 하나. 조작반이 흩어져 있어 순서를 계획해야 한다 (최소 8번 조작).
##   상태 탐색: 덮개·3호기·4호기 중 하나라도 빼면 풀리지 않고, 되돌릴 수 없는 상태는 없다 (문서 참고).
##
## 피트 길이 5.6 m: 천장 2.7 m에서 달려 뛰어도 약 4.7 m라 못 넘는다.
class_name MechParking
extends ParkingFloor

signal p01_solved
signal p02_solved

const LZ0 := 22.6
const LZ1 := 25.4
const LIFT_TIME := 2.2
const DECK_TIME := 1.6
const HINT_TIMES := [180.0, 360.0, 540.0]
# 발판 (x0, z0, x1, z1)
const S0 := Rect2(-6.3, 20.4, 6.3, 7.2)
const R0 := Rect2(-15.9, 22.6, 4.0, 2.8)
const M0 := Rect2(-25.5, 22.6, 4.0, 2.8)
const R := Rect2(-33.9, 22.6, 2.8, 2.8)
const K := Rect2(-33.9, 14.2, 2.8, 2.8)
const M := Rect2(-42.3, 14.2, 2.8, 11.2)
const E := Rect2(-51.0, 22.6, 3.1, 2.8)
const CORE := Rect2(-39.5, 17.0, 5.6, 5.6)
# 피트 (x0, z0, 크기)
const PIT_B := Rect2(-11.9, 22.6, 5.6, 2.8)
const PIT_A := Rect2(-21.5, 22.6, 5.6, 2.8)
const PIT_SR := Rect2(-31.1, 22.6, 5.6, 2.8)
const PIT_RM := Rect2(-39.5, 22.6, 5.6, 2.8)
const PIT_ME := Rect2(-47.9, 22.6, 5.6, 2.8)
const PIT_RK := Rect2(-33.9, 17.0, 2.8, 5.6)
const PIT_KM := Rect2(-39.5, 14.2, 5.6, 2.8)
const DECK_IN_Z := 27.15                  # 덮개 중심 z (남쪽 벽 속)
const DECK_OUT_Z := 24.0                  # 덮개 중심 z (SR 위)
const GATE_X := -39.46                    # 통로판 (RM의 M쪽 끝)

var player: CharacterBody3D
var lifts := {}                          # "2"/"3"/"4" → SharedStateOwner
var deck: SharedStateOwner               # 덮개판 D-7
var pits := {}                           # 이름 → Dictionary
var stage := 1                           # 1 = P01, 2 = P02, 3 = 끝
var hint_stage := 0
var stall := 0.0
var hint_scale := 1.0
var active := false
var lift_moves := 0
var deck_moves := 0

var _moving := {}
var _echo_done := {}
var _deck_body: AnimatableBody3D
var _gate_body: AnimatableBody3D
var _deck_sfx: AudioStreamPlayer3D
var _gate_sfx: AudioStreamPlayer3D
var _panels := {}                        # 호기 → {"node", "lamp", "sfx"}
var _handle_sfx: AudioStreamPlayer3D
var _handle_lamp: StandardMaterial3D
var _handle_pivot: Node3D
var _hint_lights: Array[Light3D] = []
var _stripe_mats: Array[StandardMaterial3D] = []
var _hint_label: Label
var _hint_hide_at := 0.0
var _hint_next_repeat := 0.0
var _fade: ColorRect
var _recovering := false
var _last_safe := Vector3(-3.0, 0.05, 24.0)
var _seen := {}
var _steel: StandardMaterial3D
var _dark: StandardMaterial3D
var _yellow: StandardMaterial3D


func build_room() -> void:
	_rng.seed = 2301
	_mats = ParkingMats.for_floor(Vector3.ZERO)
	_font = SystemFont.new()
	_font.font_names = PackedStringArray(["Malgun Gothic", "Noto Sans CJK KR", "Noto Sans KR", "NanumGothic", "UnDotum", "Noto Sans", "DejaVu Sans", "Arial"])
	_font.allow_system_fallback = true
	_font.font_weight = 700
	_steel = _std(Color("8a9094"), 0.45, 0.75)
	_dark = _std(Color("33383a"), 0.6, 0.55)
	_yellow = _std(Color("e3c23b"), 0.55)
	ProcAudio.ensure_reverb_bus("MechEcho", 0.97, 0.75)
	lifts["2"] = SharedStateOwner.new("lift_2", 2, 0, 2)
	lifts["3"] = SharedStateOwner.new("lift_3", 0, 0, 1)
	lifts["4"] = SharedStateOwner.new("lift_4", 1, 0, 1)
	deck = SharedStateOwner.new("deck_d7", 0, 0, 1)
	for k: String in lifts:
		var st: SharedStateOwner = lifts[k]
		var key := k
		st.changed.connect(func(_o: int, n: int) -> void: _on_lift(key, n))
		_moving[st.id] = false
	deck.changed.connect(func(_o: int, n: int) -> void: _on_deck(n))
	_moving[deck.id] = false
	var g := _group("Space")
	_build_mech_shell(g)
	_make_pit("B", PIT_B, "x", "2", false)
	_make_pit("A", PIT_A, "x", "2", true)
	_make_pit("SR", PIT_SR, "x", "4", true)
	_make_pit("RM", PIT_RM, "x", "3", false)
	_make_pit("ME", PIT_ME, "x", "4", true)
	_make_pit("RK", PIT_RK, "z", "3", true)
	_make_pit("KM", PIT_KM, "x", "4", false)
	_build_deck_and_gate()
	_panel("2", Vector3(R0.get_center().x, 0.0, LZ0), 0.0)
	_panel("4", Vector3(M0.get_center().x + 0.6, 0.0, LZ0), 0.0)
	_panel("3", Vector3(K.get_center().x, 0.0, K.position.y), 0.0)
	_build_handle(Vector3(R.get_center().x, 0.0, LZ1), PI)
	_build_mech_lights()
	_build_mech_signs()
	_build_ui()


# ================================================================ 도우미

func _std(color: Color, rough := 0.6, metal := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	m.metallic = metal
	return m


func _bb(parent: Node, a: Vector3, b: Vector3, mat: Material, collide := true) -> void:
	var lo := Vector3(minf(a.x, b.x), minf(a.y, b.y), minf(a.z, b.z))
	var hi := Vector3(maxf(a.x, b.x), maxf(a.y, b.y), maxf(a.z, b.z))
	_box(parent, hi - lo, (lo + hi) / 2.0, mat, collide)


## 사각형(x0, z0, 크기) 위에 y0..y1 상자
func _br(parent: Node, r: Rect2, y0: float, y1: float, mat: Material, collide := true) -> void:
	_bb(parent, Vector3(r.position.x, y0, r.position.y), Vector3(r.end.x, y1, r.end.y), mat, collide)


func _hazard_mat(along_z: bool) -> StandardMaterial3D:
	var img := Image.create(64, 64, false, Image.FORMAT_RGB8)
	for y in 64:
		for x in 64:
			var stripe := int(floor((x + y) / 16.0)) % 2 == 0
			img.set_pixel(x, y, Color("d9b632") if stripe else Color("2a2a28"))
	var m := StandardMaterial3D.new()
	m.albedo_texture = ImageTexture.create_from_image(img)
	m.uv1_scale = Vector3(0.6, 4.0, 1.0) if along_z else Vector3(4.0, 0.6, 1.0)
	m.roughness = 0.7
	return m


func _interactable(parent: Node3D, pos: Vector3, size: Vector3) -> Interactable:
	var it := Interactable.new()
	it.position = pos
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	it.add_child(cs)
	parent.add_child(it)
	return it


func _sfx3d(parent: Node3D, pos: Vector3, unit := 7.0) -> AudioStreamPlayer3D:
	var s := AudioStreamPlayer3D.new()
	s.bus = "Parking"
	s.unit_size = unit
	s.max_distance = 70.0
	s.position = pos
	parent.add_child(s)
	return s


func _play(p: AudioStreamPlayer3D, s: AudioStream, bus := "Parking") -> void:
	p.bus = bus
	p.stream = s
	p.play()


func _lift_y(st: SharedStateOwner, inverse: bool) -> float:
	var v := st.max_value - st.value if inverse else st.value
	return lerpf(-2.6, 0.0, float(v) / st.max_value)


# ================================================================ 공간

func _build_mech_shell(g: Node3D) -> void:
	var wall: Material = _mats["concrete_paint"]
	var ceil: Material = _mats["concrete_ceiling"]
	var floor_m: Material = _mats["floor"]
	# 입구 홀 S0 (B2 서쪽 입구 z 20.7..27.3에서 이어진다)
	_br(g, S0, -0.3, 0.0, floor_m)
	_bb(g, Vector3(-6.6, H, 20.1), Vector3(-0.3, H + 0.3, 27.9), ceil)
	_bb(g, Vector3(-6.6, 0, 20.1), Vector3(-0.3, H, 20.4), wall)
	_bb(g, Vector3(-6.6, 0, 27.6), Vector3(-0.3, H, 27.9), wall)
	_bb(g, Vector3(-6.6, 0, 20.4), Vector3(-6.3, H, LZ0 - 0.3), wall)
	_bb(g, Vector3(-6.6, 0, LZ1 + 0.3), Vector3(-6.3, H, 27.6), wall)
	# 천장 하나 (통로와 홀 전체)
	_bb(g, Vector3(-51.3, H, 13.9), Vector3(-6.6, H + 0.3, 25.7), ceil)
	# 남쪽 벽 (SR 위에는 덮개가 드나드는 틈, 높이 0..0.2)
	_bb(g, Vector3(-51.3, -2.6, LZ1), Vector3(PIT_SR.position.x, H, LZ1 + 0.3), wall)
	_bb(g, Vector3(PIT_SR.end.x, -2.6, LZ1), Vector3(-6.3, H, LZ1 + 0.3), wall)
	_bb(g, Vector3(PIT_SR.position.x, -2.6, LZ1), Vector3(PIT_SR.end.x, 0.0, LZ1 + 0.3), wall)
	_bb(g, Vector3(PIT_SR.position.x, 0.2, LZ1), Vector3(PIT_SR.end.x, H, LZ1 + 0.3), wall)
	# 덮개가 들어가 있는 벽 속 칸
	var x0 := PIT_SR.position.x
	var x1 := PIT_SR.end.x
	_bb(g, Vector3(x0, -0.3, LZ1 + 0.3), Vector3(x1, 0.0, 28.9), _dark)
	_bb(g, Vector3(x0, 0.2, LZ1 + 0.3), Vector3(x1, 0.5, 28.9), _dark)
	_bb(g, Vector3(x0, -0.3, 28.9), Vector3(x1, 0.5, 29.2), _dark)
	_bb(g, Vector3(x0 - 0.3, -0.3, LZ1 + 0.3), Vector3(x0, 0.5, 29.2), _dark)
	_bb(g, Vector3(x1, -0.3, LZ1 + 0.3), Vector3(x1 + 0.3, 0.5, 29.2), _dark)
	# 남쪽 줄의 북쪽 벽: P01 통로, SR 위, ME·E 위 (R 북쪽은 피트 RK, RM 북쪽은 기계실 벽, M은 북쪽으로 이어진다)
	_bb(g, Vector3(M0.position.x - 5.6, -2.6, LZ0 - 0.3), Vector3(-6.3, H, LZ0), wall)
	_bb(g, Vector3(-51.3, -2.6, LZ0 - 0.3), Vector3(M.position.x, H, LZ0), wall)
	# 기계실 벽 (가운데 덩어리), 홀 북쪽 벽, K·RK 동쪽 벽, M 서쪽 벽
	_br(g, CORE, -2.6, H, _std(Color("7d7f78"), 0.85))
	_bb(g, Vector3(-42.6, -2.6, 13.9), Vector3(-30.8, H, 14.2), wall)
	_bb(g, Vector3(K.end.x, -2.6, 13.9), Vector3(K.end.x + 0.3, H, LZ0 - 0.3), wall)
	_bb(g, Vector3(-42.6, -2.6, 13.9), Vector3(M.position.x, H, LZ0 - 0.3), wall)
	# 발판 바닥
	for r: Rect2 in [R0, M0, R, K, M, E]:
		_br(g, r, -0.3, 0.0, floor_m)
	# 출구 E 끝: 잠긴 문 (P03 자리)
	var ex := E.position.x
	_bb(g, Vector3(ex - 0.3, 0, LZ0), Vector3(ex, H, 23.55), wall)
	_bb(g, Vector3(ex - 0.3, 0, 24.45), Vector3(ex, H, LZ1), wall)
	_bb(g, Vector3(ex - 0.3, 2.05, 23.55), Vector3(ex, H, 24.45), wall)
	var door := SpringDoor.new()
	door.width = 0.9
	door.height = 2.05
	door.sfx_bus = "Parking"
	door.position = Vector3(ex - 0.15, 0, 24.0)
	door.rotation.y = -PI / 2
	add_child(door)
	door.build(Color("7f8784"), Color("4f5552"), 0.3)
	door.lock()


## 피트: 바닥, 양 끝벽(발판 아래), 안내 기둥, 팔레트. 옆벽은 둘레 벽이 맡는다.
## inverse면 그 호기 상태와 거꾸로 움직인다.
func _make_pit(name: String, r: Rect2, axis: String, lift_key: String, inverse: bool) -> void:
	var g := _group("Pit" + name)
	var pit_wall := _std(Color("6f716c"), 0.85)
	var x0 := r.position.x
	var z0 := r.position.y
	var x1 := r.end.x
	var z1 := r.end.y
	_bb(g, Vector3(x0 - 0.3, -2.9, z0 - 0.3), Vector3(x1 + 0.3, -2.6, z1 + 0.3), _mats["ramp_floor"])
	if axis == "x":
		_bb(g, Vector3(x0 - 0.3, -2.6, z0), Vector3(x0, -0.3, z1), pit_wall)
		_bb(g, Vector3(x1, -2.6, z0), Vector3(x1 + 0.3, -0.3, z1), pit_wall)
	else:
		_bb(g, Vector3(x0, -2.6, z0 - 0.3), Vector3(x1, -0.3, z0), pit_wall)
		_bb(g, Vector3(x0, -2.6, z1), Vector3(x1, -0.3, z1 + 0.3), pit_wall)
	# 네 귀퉁이 노란 안내 기둥
	for cx in [x0 + 0.06, x1 - 0.06]:
		for cz in [z0 + 0.06, z1 - 0.06]:
			_bb(g, Vector3(cx - 0.04, -2.6, cz - 0.04), Vector3(cx + 0.04, -0.02, cz + 0.04), _yellow, false)
	# 가장자리 경고 줄무늬 (발판 쪽 두 끝)
	var hz := _hazard_mat(axis == "z")
	if axis == "x":
		for x in [x0 - 0.15, x1 + 0.15]:
			_flat(g, Vector2(0.3, z1 - z0), Vector3(x, 0.005, (z0 + z1) / 2.0), hz)
	else:
		for z in [z0 - 0.15, z1 + 0.15]:
			_flat(g, Vector2(x1 - x0, 0.3), Vector3((x0 + x1) / 2.0, 0.005, z), hz)
	var st: SharedStateOwner = lifts[lift_key]
	var length := (x1 - x0 if axis == "x" else z1 - z0) - 0.04
	var width := (z1 - z0 if axis == "x" else x1 - x0) - 0.04
	var body := AnimatableBody3D.new()
	body.name = "Pallet" + name
	body.sync_to_physics = false
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(length, 0.2, width)
	cs.shape = shape
	cs.position = Vector3(0, -0.1, 0)
	body.add_child(cs)
	body.rotation.y = 0.0 if axis == "x" else PI / 2
	body.position = Vector3((x0 + x1) / 2.0, _lift_y(st, inverse), (z0 + z1) / 2.0)
	add_child(body)
	_pallet_visual(body, length, width, lift_key)
	var sfx := _sfx3d(body, Vector3(0, 0.4, 0))
	var light := OmniLight3D.new()
	light.position = Vector3((x0 + x1) / 2.0, -0.6, (z0 + z1) / 2.0)
	light.light_color = Color("e8e2c8")
	light.light_energy = 0.0
	light.omni_range = 4.5
	g.add_child(light)
	pits[name] = {"name": name, "rect": r, "lift": lift_key, "inverse": inverse, "body": body, "sfx": sfx, "light": light}


## 팔레트: 줄무늬 철판, 노란 테두리, 양 끝 호기 번호, 아래 유압 기둥.
## 같은 호기의 팔레트는 같은 흠집을 가진다 (같은 것의 표시): 2호기 = 꺾인 테두리와 용접, 3호기 = 붉은 페인트 얼룩, 4호기 = 끊긴 테두리와 덧댄 판.
func _pallet_visual(body: Node3D, lx: float, lz: float, lift_key: String) -> void:
	_box(body, Vector3(lx, 0.1, lz), Vector3(0, -0.05, 0), _steel, false)
	_box(body, Vector3(lx - 0.2, 0.3, lz - 0.2), Vector3(0, -0.25, 0), _dark, false)
	_box(body, Vector3(0.36, 2.7, 0.36), Vector3(0, -1.75, 0), _std(Color("9a9f9c"), 0.3, 0.9), false)
	for i in int(lx / 0.3):
		_box(body, Vector3(0.05, 0.006, lz - 0.3), Vector3(-lx / 2.0 + 0.3 + 0.3 * i, 0.003, 0), _dark, false)
	for z in [-0.75, 0.75]:
		_box(body, Vector3(lx - 1.0, 0.007, 0.06), Vector3(0, 0.0035, z), _yellow, false)
	var zn := -lz / 2.0 - 0.005
	match lift_key:
		"2":
			_box(body, Vector3(lx * 0.55, 0.05, 0.012), Vector3(-lx * 0.225, -0.05, zn), _yellow, false)
			var seg := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(lx * 0.45, 0.05, 0.012)
			seg.mesh = bm
			seg.material_override = _yellow
			var ang := deg_to_rad(-6.0)
			seg.position = Vector3(lx * 0.05 + lx * 0.225 * cos(ang), -0.05 + lx * 0.225 * sin(ang), zn)
			seg.rotation.z = ang
			body.add_child(seg)
			_box(body, Vector3(0.06, 0.24, 0.02), Vector3(lx * 0.05, -0.1, zn), _std(Color("2b2622"), 0.9, 0.4), false)
		"3":
			_box(body, Vector3(lx, 0.05, 0.012), Vector3(0, -0.05, zn), _yellow, false)
			_box(body, Vector3(0.7, 0.008, 0.5), Vector3(lx * 0.3, 0.004, -lz * 0.25), _std(Color("9c2a22"), 0.7), false)
			_box(body, Vector3(0.25, 0.006, 0.9), Vector3(lx * 0.3 + 0.4, 0.004, -lz * 0.1), _std(Color("9c2a22"), 0.7), false)
		"4":
			_box(body, Vector3(lx * 0.4, 0.05, 0.012), Vector3(-lx * 0.3, -0.05, zn), _yellow, false)
			_box(body, Vector3(lx * 0.4, 0.05, 0.012), Vector3(lx * 0.3, -0.05, zn), _yellow, false)
			_box(body, Vector3(0.9, 0.012, 0.7), Vector3(-lx * 0.2, 0.006, lz * 0.2), _std(Color("6d7275"), 0.5, 0.8), false)
	_box(body, Vector3(lx, 0.05, 0.012), Vector3(0, -0.05, lz / 2.0 + 0.005), _yellow, false)
	for side in [-1.0, 1.0]:
		var lb := _label(body, lift_key, Vector3(side * (lx / 2.0 - 0.45), 0.008, 0), PI / 2 if side < 0 else -PI / 2, 0.006, Color(0.9, 0.82, 0.3), 128)
		lb.rotation.x = -PI / 2


## 덮개판 D-7: SR 위로 밀려 나오는 철판(수평)과 R─RM 사이를 막는 통로판(수직). 같은 사선 무늬, 같은 번호.
func _build_deck_and_gate() -> void:
	var lx := PIT_SR.size.x
	var lz := PIT_SR.size.y
	var stripe := _std(Color("d9b632"), 0.6)
	stripe.emission_enabled = true
	stripe.emission = Color("ffd84a")
	stripe.emission_energy_multiplier = 0.0
	_stripe_mats.append(stripe)
	_deck_body = AnimatableBody3D.new()
	_deck_body.name = "DeckSR"
	_deck_body.sync_to_physics = false
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(lx - 0.04, 0.06, lz - 0.02)
	cs.shape = sh
	cs.position = Vector3(0, 0.03, 0)
	_deck_body.add_child(cs)
	_deck_body.position = Vector3(PIT_SR.get_center().x, 0.0, DECK_IN_Z if deck.value == 0 else DECK_OUT_Z)
	add_child(_deck_body)
	_box(_deck_body, Vector3(lx - 0.04, 0.06, lz - 0.02), Vector3(0, 0.03, 0), _steel, false)
	for i in 6:
		var s := MeshInstance3D.new()
		var b := BoxMesh.new()
		b.size = Vector3(0.18, 0.004, lz * 0.9)
		s.mesh = b
		s.material_override = stripe
		s.position = Vector3(-lx / 2.0 + 0.7 + 0.85 * i, 0.062, 0)
		s.rotation.y = deg_to_rad(35.0)
		_deck_body.add_child(s)
	var dl := _label(_deck_body, "D-7", Vector3(0, 0.065, -lz / 2.0 + 0.45), PI, 0.004, Color(0.92, 0.92, 0.88), 128)
	dl.rotation.x = -PI / 2
	_deck_sfx = _sfx3d(_deck_body, Vector3(0, 0.2, 0))
	# 통로판: 닫히면 RM의 M쪽 끝을 바닥부터 천장까지 막는다. 열리면 천장 속으로
	var gz := LZ1 - LZ0 - 0.04
	_gate_body = AnimatableBody3D.new()
	_gate_body.name = "GatePanel"
	_gate_body.sync_to_physics = false
	var gcs := CollisionShape3D.new()
	var gsh := BoxShape3D.new()
	gsh.size = Vector3(0.08, H, gz)
	gcs.shape = gsh
	_gate_body.add_child(gcs)
	_gate_body.position = Vector3(GATE_X, H / 2.0 if deck.value == 1 else H * 1.5 + 0.05, 24.0)
	add_child(_gate_body)
	_box(_gate_body, Vector3(0.08, H, gz), Vector3.ZERO, _steel, false)
	for i in 4:
		var s := MeshInstance3D.new()
		var b := BoxMesh.new()
		b.size = Vector3(0.004, 0.18, gz * 0.9)
		s.mesh = b
		s.material_override = stripe
		s.position = Vector3(0.042, -0.9 + 0.6 * i, 0)
		s.rotation.x = deg_to_rad(35.0)
		_gate_body.add_child(s)
	_label(_gate_body, "D-7", Vector3(0.045, 0.5, 0), PI / 2, 0.004, Color(0.92, 0.92, 0.88), 128)
	_gate_sfx = _sfx3d(_gate_body, Vector3(0.2, 0, 0))


# ================================================================ 조작반, 손잡이

## 호기 조작반: 벽에 붙은 회색 상자. ▲ 상승 / ▼ 하강, 상태 등. pos는 벽면, yaw 0이면 앞이 +Z.
func _panel(lift_key: String, pos: Vector3, yaw: float) -> void:
	var p := Node3D.new()
	p.name = "Panel" + lift_key
	p.position = pos
	p.rotation.y = yaw
	add_child(p)
	_box(p, Vector3(0.62, 0.8, 0.18), Vector3(0, 1.3, 0.09), _std(Color("b8bbb4"), 0.55, 0.2))
	_box(p, Vector3(0.1, 0.9, 0.08), Vector3(0, 0.45, 0.04), _std(Color("8c8f8a"), 0.6, 0.3), false)
	_label(p, "기계식 주차 %s호기" % lift_key, Vector3(0, 1.62, 0.185), 0.0, 0.0011, Color(0.12, 0.14, 0.14), 64)
	_label(p, "▲ 상승", Vector3(-0.14, 1.12, 0.185), 0.0, 0.0012, Color(0.12, 0.14, 0.14), 64)
	_label(p, "▼ 하강", Vector3(0.14, 1.12, 0.185), 0.0, 0.0012, Color(0.12, 0.14, 0.14), 64)
	var lamp := _std(Color("1f4a22"), 0.4)
	lamp.emission_enabled = true
	lamp.emission = Color("4dff6a")
	lamp.emission_energy_multiplier = 1.5
	_box(p, Vector3(0.06, 0.06, 0.03), Vector3(0.22, 1.5, 0.19), lamp, false)
	_box(p, Vector3(0.09, 0.09, 0.05), Vector3(-0.22, 1.5, 0.2), _std(Color("c0281e"), 0.4), false)
	for d in [1, -1]:
		var x: float = -0.14 if d > 0 else 0.14
		_box(p, Vector3(0.1, 0.1, 0.04), Vector3(x, 1.28, 0.2), _std(Color("2e7d3a") if d > 0 else Color("2e4f9d"), 0.4), false)
		var it := _interactable(p, Vector3(x, 1.28, 0.2), Vector3(0.14, 0.14, 0.08))
		var dir: int = d
		it.interacted.connect(func() -> void: _press_lift(lift_key, dir))
	_panels[lift_key] = {"node": p, "lamp": lamp, "sfx": _sfx3d(p, Vector3(0, 1.3, 0.3), 5.0)}


## 덮개 손잡이: 당길 때마다 덮개가 나오거나 들어간다.
func _build_handle(pos: Vector3, yaw: float) -> void:
	var p := Node3D.new()
	p.name = "DeckHandle"
	p.position = pos
	p.rotation.y = yaw
	add_child(p)
	_box(p, Vector3(0.4, 0.55, 0.14), Vector3(0, 1.15, 0.07), _std(Color("2f4a3a"), 0.6, 0.3))
	_label(p, "피트 덮개 D-7
닫힘 ↔ 열림", Vector3(0, 0.97, 0.145), 0.0, 0.0009, Color(0.9, 0.9, 0.85), 64)
	_handle_pivot = Node3D.new()
	_handle_pivot.position = Vector3(0, 1.15, 0.16)
	p.add_child(_handle_pivot)
	_box(_handle_pivot, Vector3(0.035, 0.3, 0.035), Vector3(0, 0.15, 0), _steel, false)
	_box(_handle_pivot, Vector3(0.07, 0.07, 0.07), Vector3(0, 0.3, 0), _std(Color("c23a2e"), 0.45), false)
	_handle_pivot.rotation.z = 0.6 if deck.value == 1 else -0.6
	_handle_lamp = _std(Color("5a1010"), 0.4)
	_handle_lamp.emission_enabled = true
	_handle_lamp.emission = Color("ff3020")
	_handle_lamp.emission_energy_multiplier = 0.0
	_box(p, Vector3(0.05, 0.05, 0.03), Vector3(0.15, 1.36, 0.15), _handle_lamp, false)
	var it := _interactable(p, Vector3(0, 1.3, 0.18), Vector3(0.3, 0.35, 0.16))
	it.interacted.connect(_pull_handle)
	_handle_sfx = _sfx3d(p, Vector3(0, 1.2, 0.3), 5.0)


func _press_lift(key: String, dir: int) -> void:
	var st: SharedStateOwner = lifts[key]
	var pn: Dictionary = _panels[key]
	var target := st.value + dir
	if _moving[st.id] or target < st.min_value or target > st.max_value:
		_play(pn["sfx"], ProcAudio.latch())
		_blink(pn["lamp"], 1.5)
		return
	var who := _lift_occupant(key)
	if who != "":
		print("lift %s hold: occupied (%s)" % [key, who])
		_play(pn["sfx"], ProcAudio.latch())
		_blink(pn["lamp"], 1.5)
		return
	_play(pn["sfx"], ProcAudio.click())
	st.request(target)


func _pull_handle() -> void:
	if _moving[deck.id]:
		_play(_handle_sfx, ProcAudio.latch())
		return
	var who := _deck_occupant()
	if who != "":
		print("deck hold: occupied (%s)" % who)
		_play(_handle_sfx, ProcAudio.latch())
		_blink(_handle_lamp, 0.0)
		return
	var target := 1 - deck.value
	create_tween().tween_property(_handle_pivot, "rotation:z", 0.6 if target == 1 else -0.6, 0.25).set_trans(Tween.TRANS_SINE)
	_play(_handle_sfx, ProcAudio.lever())
	deck.request(target)


func _in_rect(r: Rect2, p: Vector3, margin := 0.0) -> bool:
	return p.x > r.position.x - margin and p.x < r.end.x + margin and p.z > r.position.y - margin and p.z < r.end.y + margin


## 이 호기의 팔레트 위나 그 피트 안에 사람이 있으면 피트 이름
func _lift_occupant(key: String) -> String:
	if player == null:
		return ""
	var p := player.global_position
	for k: String in pits:
		var pit: Dictionary = pits[k]
		if pit["lift"] != key or not _in_rect(pit["rect"], p, 0.25):
			continue
		var top: float = (pit["body"] as Node3D).position.y
		if p.y < -0.2 or absf(p.y - top) < 0.4:
			return k
	return ""


## 덮개 위나 통로판 자리에 사람이 있으면
func _deck_occupant() -> String:
	if player == null:
		return ""
	var p := player.global_position
	if deck.value == 1 and _in_rect(PIT_SR, p, 0.25) and p.y > -0.2:
		return "deck"
	if absf(p.x - GATE_X) < 0.45 and p.z > LZ0 and p.z < LZ1:
		return "gate"
	return ""


func _blink(lamp: StandardMaterial3D, rest: float) -> void:
	var tw := create_tween()
	for i in 3:
		tw.tween_property(lamp, "emission_energy_multiplier", 0.0 if rest > 0.0 else 4.0, 0.08)
		tw.tween_property(lamp, "emission_energy_multiplier", 4.0 if rest > 0.0 else 0.0, 0.12)
	tw.tween_property(lamp, "emission_energy_multiplier", rest, 0.1)


## 호기 상태가 바뀌었다: 그 호기의 팔레트가 모든 피트에서 같이 움직이고 같은 소리를 낸다.
func _on_lift(key: String, _value: int) -> void:
	var st: SharedStateOwner = lifts[key]
	_moving[st.id] = true
	stall = 0.0
	lift_moves += 1
	print("lift_%s -> %d" % [key, st.value])
	var first := not _echo_done.has(st.id)
	_echo_done[st.id] = true
	var snd := ProcAudio.cart_roll(LIFT_TIME)
	var near: String = ""
	var best := INF
	var pn: Node3D = _panels[key]["node"]
	for k: String in pits:
		if pits[k]["lift"] == key:
			var d := (pits[k]["body"] as Node3D).global_position.distance_to(pn.global_position)
			if d < best:
				best = d
				near = k
	for k: String in pits:
		var pit: Dictionary = pits[k]
		if pit["lift"] != key:
			continue
		var body: AnimatableBody3D = pit["body"]
		create_tween().tween_property(body, "position:y", _lift_y(st, pit["inverse"]), LIFT_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		# 처음 한 번: 조작반에서 먼 피트의 소리에 긴 울림
		_play(pit["sfx"], snd, "MechEcho" if (first and k != near) else "Parking")
		if hint_stage >= 2:
			_flash(pit["light"] as OmniLight3D)
	get_tree().create_timer(LIFT_TIME + 0.05).timeout.connect(func() -> void: _moving[st.id] = false)


func _on_deck(value: int) -> void:
	_moving[deck.id] = true
	stall = 0.0
	deck_moves += 1
	print("deck_d7 -> %d" % value)
	var first := not _echo_done.has(deck.id)
	_echo_done[deck.id] = true
	var snd := ProcAudio.cart_roll(DECK_TIME)
	create_tween().tween_property(_deck_body, "position:z", DECK_OUT_Z if value == 1 else DECK_IN_Z, DECK_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	create_tween().tween_property(_gate_body, "position:y", H / 2.0 if value == 1 else H * 1.5 + 0.05, DECK_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_play(_deck_sfx, snd, "MechEcho" if first else "Parking")
	_play(_gate_sfx, snd, "MechEcho" if first else "Parking")
	if hint_stage >= 2:
		for m in _stripe_mats:
			var tw := create_tween()
			tw.tween_property(m, "emission_energy_multiplier", 2.5, 0.2)
			tw.tween_property(m, "emission_energy_multiplier", 0.0, DECK_TIME + 0.8)
	get_tree().create_timer(DECK_TIME + 0.05).timeout.connect(func() -> void: _moving[deck.id] = false)


func _flash(l: OmniLight3D) -> void:
	var tw := create_tween()
	tw.tween_property(l, "light_energy", 1.6, 0.25)
	tw.tween_property(l, "light_energy", 0.25, LIFT_TIME + 0.8)


# ================================================================ 조명, 표지

func _build_mech_lights() -> void:
	var g := _group("Lights")
	_fixture(g, Vector3(-3.2, H, 24.0), PI / 2, "on")
	for r: Rect2 in [PIT_B, R0, PIT_A, M0, PIT_SR, R, PIT_RM, PIT_ME, E]:
		_fixture(g, Vector3(r.get_center().x, H, 24.0), 0.0, "on")
	for r: Rect2 in [K, PIT_KM]:
		_fixture(g, Vector3(r.get_center().x, H, 15.6), 0.0, "on")
	_fixture(g, Vector3(PIT_RK.get_center().x, H, PIT_RK.get_center().y), PI / 2, "on")
	_fixture(g, Vector3(M.get_center().x, H, 18.5), PI / 2, "flicker")
	# 힌트용 작업등 (처음에는 꺼짐): P01은 2호기 조작반, P02는 덮개가 드나드는 남쪽 벽 틈
	for at in [Vector3(R0.get_center().x, 2.2, 23.2), Vector3(PIT_SR.get_center().x, 1.2, 25.0)]:
		var l := SpotLight3D.new()
		l.position = at
		l.light_color = Color("fff2c0")
		l.light_energy = 0.0
		l.spot_range = 4.0
		l.spot_angle = 40.0
		g.add_child(l)
		l.look_at(at + Vector3(0, -1.0, 0.8 if at.z > 24.5 else -0.8), Vector3.UP)
		_hint_lights.append(l)


func _build_mech_signs() -> void:
	var g := _group("Signs")
	var white := _std(Color("f1f0ea"), 0.6)
	_box(g, Vector3(0.04, 0.42, 2.6), Vector3(-6.4, 2.4, 24.0), white, false)
	_label(g, "기계식 주차장  승용차 전용 · 2.2t", Vector3(-6.375, 2.47, 24.0), PI / 2, 0.0016, Color(0.12, 0.2, 0.16), 96)
	_label(g, "보행 주의 · 팔레트 승강 중 진입 금지", Vector3(-6.375, 2.29, 24.0), PI / 2, 0.0011, Color(0.75, 0.2, 0.15), 96)
	# 기계실 벽의 안내판: 호기 번호와 위치 (그림 대신 글)
	_box(g, Vector3(0.04, 0.5, 1.6), Vector3(CORE.end.x + 0.02, 1.6, 19.8), white, false)
	_label(g, "기계실\n2 · 3 · 4호기 승강 설비", Vector3(CORE.end.x + 0.045, 1.6, 19.8), PI / 2, 0.0012, Color(0.15, 0.17, 0.17), 80)
	# 출구 비상구 등
	var green := _std(Color("1d8f4e"), 0.4)
	green.emission_enabled = true
	green.emission = Color("3BD07A")
	green.emission_energy_multiplier = 2.0
	_box(g, Vector3(0.05, 0.16, 0.45), Vector3(E.position.x + 0.03, 2.35, 24.0), green, false)
	_label(g, "출구", Vector3(E.position.x + 0.06, 2.35, 24.0), PI / 2, 0.0013, Color(0.95, 1.0, 0.95), 80)


# ================================================================ 화면 (힌트 문장, 페이드, 끝)

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 15
	add_child(layer)
	_hint_label = Label.new()
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
	layer.add_child(_hint_label)
	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 0)
	_fade.anchor_right = 1.0
	_fade.anchor_bottom = 1.0
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_fade)


func show_hint_text(text: String, seconds := 10.0) -> void:
	_hint_label.text = text
	create_tween().tween_property(_hint_label, "modulate:a", 1.0, 0.6)
	_hint_hide_at = Time.get_ticks_msec() / 1000.0 + seconds


func _show_end_card() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 18
	add_child(layer)
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0)
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(bg)
	var lb := Label.new()
	lb.text = "P01 · 겹친 빈자리\nP02 · 덮개의 앞과 뒤\n\n여기까지 만들었습니다.\n문 너머(P03)는 아직 없습니다."
	lb.anchor_right = 1.0
	lb.anchor_bottom = 1.0
	lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lb.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lb.add_theme_font_override("font", _font)
	lb.add_theme_font_size_override("font_size", 28)
	lb.add_theme_color_override("font_color", Color(0.86, 0.88, 0.84))
	lb.modulate.a = 0.0
	layer.add_child(lb)
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
	# 발판 위에 서 있으면 그 자리를 안전 지점으로 기억한다
	if p.y > -0.15:
		for r: Rect2 in [S0, R0, M0, R, K, M, E]:
			if _in_rect(r, p, -0.3):
				_last_safe = Vector3(clampf(p.x, r.position.x + 0.6, r.end.x - 0.6), 0.05, clampf(p.z, r.position.y + 0.6, r.end.y - 0.6))
				if not _seen.has(r):
					_seen[r] = true
					stall = 0.0   # 새 발판에 처음 섰다 = 새 증거
	if active and stage < 3:
		stall += delta * hint_scale * Settings.hint_scale()
		while hint_stage < HINT_TIMES.size() and stall >= HINT_TIMES[hint_stage]:
			hint_stage += 1
			_apply_hint(hint_stage)
		var now := Time.get_ticks_msec() / 1000.0
		if hint_stage >= 3 and now >= _hint_next_repeat:
			_hint_next_repeat = now + 120.0
			show_hint_text(_hint_line())
	if _hint_hide_at > 0.0 and Time.get_ticks_msec() / 1000.0 >= _hint_hide_at:
		_hint_hide_at = 0.0
		create_tween().tween_property(_hint_label, "modulate:a", 0.0, 0.8)
	_check_fall(p)
	if stage == 1 and _in_rect(M0, p, -0.3) and p.y > -0.2:
		stage = 2
		_reset_hints()
		print("PUZZLE v2_p01 SOLVED  lift_moves=%d" % lift_moves)
		p01_solved.emit()
	if stage == 2 and _in_rect(E, p, -0.2) and p.y > -0.2:
		stage = 3
		print("PUZZLE v2_p02 SOLVED  lift_moves=%d deck_moves=%d" % [lift_moves, deck_moves])
		p02_solved.emit()
		_show_end_card()


func _reset_hints() -> void:
	hint_stage = 0
	stall = 0.0
	_hint_next_repeat = 0.0
	for l in _hint_lights:
		l.light_energy = 0.0
	for k: String in pits:
		(pits[k]["light"] as OmniLight3D).light_energy = 0.0


func _hint_line() -> String:
	if stage == 1:
		return "조작반을 한 번 누르고, 지나온 구덩이와 앞의 구덩이를 함께 보세요."
	return "출구로 가는 길은 3호기 위 · 4호기 아래 · 덮개 열림입니다. 덮개로 지나온 길을 붙잡아 두세요."


func _apply_hint(n: int) -> void:
	print("hint stage %d (P0%d)" % [n, stage])
	match n:
		1:
			# ① 볼 곳: P01은 2호기 조작반 위, P02는 덮개가 드나드는 벽 틈
			_hint_lights[0 if stage == 1 else 1].light_energy = 2.0
		2:
			# ② 관계: 이제부터 호기가 움직일 때 그 호기의 피트 등이 모두 밝아지고, 덮개·통로판 무늬가 함께 빛난다
			pass
		3:
			_hint_next_repeat = 0.0


## 피트에 떨어지면 몸만 마지막으로 서 있던 발판으로 옮긴다 (장치 상태는 그대로).
func _check_fall(p: Vector3) -> void:
	if _recovering or p.y > -0.6:
		return
	_recovering = true
	print("fell into a pit -> back to ", _last_safe)
	var tw := create_tween()
	tw.tween_interval(0.5)
	tw.tween_property(_fade, "color:a", 1.0, 0.35)
	tw.tween_callback(func() -> void:
		player.global_position = _last_safe
		player.velocity = Vector3.ZERO)
	tw.tween_interval(0.3)
	tw.tween_property(_fade, "color:a", 0.0, 0.5)
	tw.tween_callback(func() -> void: _recovering = false)


# ================================================================ 테스트용

func pallet_y(name: String) -> float:
	return (pits[name]["body"] as Node3D).position.y


func lift_value(key: String) -> int:
	return (lifts[key] as SharedStateOwner).value


func panel_button(key: String, dir: int) -> Interactable:
	var p: Node3D = _panels[key]["node"]
	for c in p.get_children():
		if c is Interactable and absf((c as Node3D).position.x - (-0.14 if dir > 0 else 0.14)) < 0.01:
			return c
	return null


func handle_interactable() -> Interactable:
	for c in get_node("DeckHandle").get_children():
		if c is Interactable:
			return c
	return null


## 테스트용: P02 시작 상태로 (P01을 푼 직후)
func jump_to_p02() -> void:
	var st: SharedStateOwner = lifts["2"]
	st.restore(0)
	for k: String in pits:
		var pit: Dictionary = pits[k]
		if pit["lift"] == "2":
			(pit["body"] as Node3D).position.y = _lift_y(st, pit["inverse"])
	stage = 2
	active = true
