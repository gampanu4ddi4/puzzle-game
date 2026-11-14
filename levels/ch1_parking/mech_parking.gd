## v2_p01 "겹친 빈자리" + v2_p02 "덮개의 앞과 뒤" (docs/levels/ch1_parking.md).
##
## B2 서쪽 입구 밖의 기계식 주차 구역. 좌표는 B2와 같다 (이 노드는 원점, x < 0 쪽). 일렬 배치:
##
##   입구 홀 S0 ─ 피트 B ─ 관제 발판 R(2호기 조작반) ─ 피트 A ─ 덮개 발판 M(덮개 손잡이) ─ 피트 G ─ 출구판 ─ 출구 E
##
## 2호기 팔레트(lift_2, 0..2)는 세 피트에 동시에 있다: B와 G는 s만큼 올라오고, A는 거꾸로(2 - s).
##   정지점 높이: 0 = 피트 바닥(-2.6), 1 = 중간(-1.3), 2 = 바닥면(0). 중간에서는 세 팔레트가 모두 반쯤 떠 있다.
## 덮개판 D-7(deck, 0/1)은 두 곳에 있다: 1이면 A 위로 덮개가 밀려 나와 건널 수 있고, 같은 판인 출구판은 내려와 닫힌다.
##   덮개는 수평으로, 출구판은 수직으로 움직인다 (90도 돌아간 같은 판).
##
## P01: 처음엔 s = 2 (B, G가 메워짐, A는 바닥). B를 건너 조작반으로 s = 0 → A가 올라오고 B가 내려간다 → A를 건넌다.
## P02: M에서 출구 앞 G는 비어 있다(s = 0). G를 메우려면 s = 2인데, 그러면 A가 비어 조작반에서 돌아올 수 없다.
##   덮개(1)로 A를 미리 덮고(출구판 닫힘) → 조작반에서 s = 2 → 덮개로 돌아와 → 덮개를 열면(0) 출구판이 열린다.
##   덮개를 쓰지 않고는 출구에 갈 수 없다 (상태 탐색으로 확인. 문서 참고).
##
## 피트 길이 5.6 m: 천장 2.7 m에서 달려 뛰어도 약 4.7 m라 못 넘는다. 중간 높이(-1.3)에서는 점프+턱 오르기(약 1.1 m)로도 못 나온다.
class_name MechParking
extends ParkingFloor

signal p01_solved
signal p02_solved

const LZ0 := 22.6                        # 통로 안쪽 z
const LZ1 := 25.4
const LIFT_Y := [-2.6, -1.3, 0.0]
const LIFT_TIME := 2.2
const DECK_TIME := 1.6
const HINT_TIMES := [180.0, 360.0, 540.0]
# 구간 (x0, x1)
const S0 := Vector2(-6.3, 0.0)
const PIT_B := Vector2(-11.9, -6.3)
const R := Vector2(-15.9, -11.9)
const PIT_A := Vector2(-21.5, -15.9)
const M := Vector2(-25.5, -21.5)
const PIT_G := Vector2(-31.1, -25.5)
const DOOR := Vector2(-31.4, -31.1)
const E := Vector2(-34.0, -31.4)
const DECK_IN_Z := 20.85                  # 덮개 중심 z (벽 속)
const DECK_OUT_Z := 24.0                  # 덮개 중심 z (A 위)

var player: CharacterBody3D
var lift: SharedStateOwner               # 2호기 팔레트
var deck: SharedStateOwner               # 덮개판 D-7
var pits := {}                           # "B"/"A"/"G" → Dictionary
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
var _door_body: AnimatableBody3D
var _deck_sfx: AudioStreamPlayer3D
var _door_sfx: AudioStreamPlayer3D
var _panel_sfx: AudioStreamPlayer3D
var _handle_sfx: AudioStreamPlayer3D
var _panel_lamp: StandardMaterial3D
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
var _seen_r := false
var _seen_m := false
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
	lift = SharedStateOwner.new("lift_2", 2, 0, 2)
	deck = SharedStateOwner.new("deck_d7", 0, 0, 1)
	lift.changed.connect(func(_o: int, n: int) -> void: _on_lift(n))
	deck.changed.connect(func(_o: int, n: int) -> void: _on_deck(n))
	_moving[lift.id] = false
	_moving[deck.id] = false
	var g := _group("Space")
	_build_mech_shell(g)
	pits["B"] = _make_pit("B", PIT_B, false, Vector3(-3.0, 0.05, 24.0))
	pits["A"] = _make_pit("A", PIT_A, true, Vector3(-13.9, 0.05, 24.0))
	pits["G"] = _make_pit("G", PIT_G, false, Vector3(-23.5, 0.05, 24.0))
	_build_deck_and_door(g)
	_build_panel()
	_build_handle()
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


func _hazard_mat() -> StandardMaterial3D:
	var img := Image.create(64, 64, false, Image.FORMAT_RGB8)
	for y in 64:
		for x in 64:
			var stripe := int(floor((x + y) / 16.0)) % 2 == 0
			img.set_pixel(x, y, Color("d9b632") if stripe else Color("2a2a28"))
	var m := StandardMaterial3D.new()
	m.albedo_texture = ImageTexture.create_from_image(img)
	m.uv1_scale = Vector3(4.0, 0.6, 1.0)
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


# ================================================================ 공간

func _build_mech_shell(g: Node3D) -> void:
	var wall: Material = _mats["concrete_paint"]
	var ceil: Material = _mats["concrete_ceiling"]
	# 입구 홀 S0 (B2 서쪽 입구 z 20.7..27.3에서 이어진다)
	_bb(g, Vector3(S0.x, -0.3, 20.4), Vector3(0.0, 0.0, 27.6), _mats["floor"])
	_bb(g, Vector3(S0.x - 0.3, H, 20.1), Vector3(-0.3, H + 0.3, 27.9), ceil)
	_bb(g, Vector3(S0.x - 0.3, 0, 20.1), Vector3(-0.3, H, 20.4), wall)
	_bb(g, Vector3(S0.x - 0.3, 0, 27.6), Vector3(-0.3, H, 27.9), wall)
	_bb(g, Vector3(S0.x - 0.3, 0, 20.4), Vector3(S0.x, H, LZ0 - 0.3), wall)
	_bb(g, Vector3(S0.x - 0.3, 0, LZ1 + 0.3), Vector3(S0.x, H, 27.6), wall)
	# 통로 (S0 서쪽 끝부터 출구 E까지): 양옆 벽은 피트 바닥까지 내려간다
	var x_end := E.x - 0.3
	_bb(g, Vector3(x_end, H, LZ0 - 0.3), Vector3(S0.x - 0.3, H + 0.3, LZ1 + 0.3), ceil)
	_bb(g, Vector3(x_end, -2.6, LZ1), Vector3(S0.x, H, LZ1 + 0.3), wall)                       # 남
	# 북쪽 벽: A 위에는 덮개가 드나드는 틈(높이 0..0.2)
	_bb(g, Vector3(x_end, -2.6, LZ0 - 0.3), Vector3(PIT_A.x, H, LZ0), wall)
	_bb(g, Vector3(PIT_A.y, -2.6, LZ0 - 0.3), Vector3(S0.x, H, LZ0), wall)
	_bb(g, Vector3(PIT_A.x, -2.6, LZ0 - 0.3), Vector3(PIT_A.y, 0.0, LZ0), wall)
	_bb(g, Vector3(PIT_A.x, 0.2, LZ0 - 0.3), Vector3(PIT_A.y, H, LZ0), wall)
	# 덮개가 들어가 있는 벽 속 칸
	_bb(g, Vector3(PIT_A.x, -0.3, 19.1), Vector3(PIT_A.y, 0.0, LZ0 - 0.3), _dark)
	_bb(g, Vector3(PIT_A.x, 0.2, 19.1), Vector3(PIT_A.y, 0.5, LZ0 - 0.3), _dark)
	_bb(g, Vector3(PIT_A.x, -0.3, 18.8), Vector3(PIT_A.y, 0.5, 19.1), _dark)
	_bb(g, Vector3(PIT_A.x - 0.3, -0.3, 18.8), Vector3(PIT_A.x, 0.5, LZ0 - 0.3), _dark)
	_bb(g, Vector3(PIT_A.y, -0.3, 18.8), Vector3(PIT_A.y + 0.3, 0.5, LZ0 - 0.3), _dark)
	# 발판 바닥: R, M, E (출구판 벽 아래까지)
	for seg in [R, M, Vector2(E.x, DOOR.y)]:
		_bb(g, Vector3(seg.x, -0.3, LZ0), Vector3(seg.y, 0.0, LZ1), _mats["floor"])
	# 출구 벽 (가운데 문 구멍 z 23.4..24.6, 높이 2.1)
	_bb(g, Vector3(DOOR.x, 0, LZ0), Vector3(DOOR.y, H, 23.4), wall)
	_bb(g, Vector3(DOOR.x, 0, 24.6), Vector3(DOOR.y, H, LZ1), wall)
	_bb(g, Vector3(DOOR.x, 2.1, 23.4), Vector3(DOOR.y, H, 24.6), wall)
	# 출구 E 끝: 잠긴 문 (P03 자리)
	_bb(g, Vector3(x_end, 0, LZ0), Vector3(E.x, H, 23.55), wall)
	_bb(g, Vector3(x_end, 0, 24.45), Vector3(E.x, H, LZ1), wall)
	_bb(g, Vector3(x_end, 2.05, 23.55), Vector3(E.x, H, 24.45), wall)
	var door := SpringDoor.new()
	door.width = 0.9
	door.height = 2.05
	door.sfx_bus = "Parking"
	door.position = Vector3(E.x - 0.15, 0, 24.0)
	door.rotation.y = -PI / 2
	add_child(door)
	door.build(Color("7f8784"), Color("4f5552"), 0.3)
	door.lock()
	# 피트 가장자리 경고 줄무늬 (발판 쪽)
	var hz := _hazard_mat()
	for x in [PIT_B.y + 0.15, PIT_B.x - 0.15, PIT_A.y + 0.15, PIT_A.x - 0.15, PIT_G.y + 0.15]:
		_flat(g, Vector2(0.3, LZ1 - LZ0), Vector3(x, 0.005, 24.0), hz)


## 피트 하나: 바닥, 양 끝벽, 팔레트. inverse면 2호기 상태와 거꾸로 움직인다 (A).
func _make_pit(name: String, span: Vector2, inverse: bool, safe: Vector3) -> Dictionary:
	var g := _group("Pit" + name)
	var pit_wall := _std(Color("6f716c"), 0.85)
	_bb(g, Vector3(span.x - 0.3, -2.9, LZ0 - 0.3), Vector3(span.y + 0.3, -2.6, LZ1 + 0.3), _mats["ramp_floor"])
	_bb(g, Vector3(span.x - 0.3, -2.6, LZ0), Vector3(span.x, -0.3, LZ1), pit_wall)
	_bb(g, Vector3(span.y, -2.6, LZ0), Vector3(span.y + 0.3, -0.3, LZ1), pit_wall)
	# 끝벽의 노란 안내 기둥 (승강 가이드), 바닥 기름 자국
	for x in [span.x + 0.03, span.y - 0.03]:
		for z in [LZ0 + 0.35, LZ1 - 0.35]:
			_bb(g, Vector3(x - 0.03, -2.6, z - 0.07), Vector3(x + 0.03, -0.02, z + 0.07), _yellow, false)
	var body := AnimatableBody3D.new()
	body.name = "Pallet" + name
	body.sync_to_physics = false
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(span.y - span.x - 0.04, 0.2, LZ1 - LZ0 - 0.04)
	cs.shape = shape
	cs.position = Vector3(0, -0.1, 0)
	body.add_child(cs)
	body.position = Vector3((span.x + span.y) / 2.0, LIFT_Y[_stop_of(inverse, lift.value)], 24.0)
	add_child(body)
	_pallet_visual(body, span.y - span.x - 0.04, LZ1 - LZ0 - 0.04)
	var sfx := _sfx3d(body, Vector3(0, 0.4, 0))
	var light := OmniLight3D.new()
	light.position = Vector3((span.x + span.y) / 2.0, -0.6, 24.0)
	light.light_color = Color("e8e2c8")
	light.light_energy = 0.0
	light.omni_range = 4.5
	g.add_child(light)
	return {"name": name, "span": span, "inverse": inverse, "body": body, "sfx": sfx, "safe": safe, "light": light}


func _stop_of(inverse: bool, s: int) -> int:
	return 2 - s if inverse else s


## 2호기 팔레트: 줄무늬 철판, 노란 테두리(한쪽 긴 변이 한 자리에서 꺾여 있고 용접 흠집), 양 끝 "2", 아래 유압 기둥.
## 세 피트의 팔레트는 같은 모양, 같은 흠집이다 (같은 것의 표시).
func _pallet_visual(body: Node3D, lx: float, lz: float) -> void:
	_box(body, Vector3(lx, 0.1, lz), Vector3(0, -0.05, 0), _steel, false)
	_box(body, Vector3(lx - 0.2, 0.3, lz - 0.2), Vector3(0, -0.25, 0), _dark, false)
	_box(body, Vector3(0.36, 2.7, 0.36), Vector3(0, -1.75, 0), _std(Color("9a9f9c"), 0.3, 0.9), false)
	for i in int(lx / 0.3):
		_box(body, Vector3(0.05, 0.006, lz - 0.3), Vector3(-lx / 2.0 + 0.3 + 0.3 * i, 0.003, 0), _dark, false)
	# 바퀴 자리 표시 (노란 사다리꼴 대신 두 줄)
	for z in [-0.75, 0.75]:
		_box(body, Vector3(lx - 1.0, 0.007, 0.06), Vector3(0, 0.0035, z), _yellow, false)
	# 긴 변 옆면의 노란 선: 남쪽은 곧고, 북쪽은 한 자리에서 꺾인다 + 용접 흠집
	var zn := -lz / 2.0 - 0.005
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
	for k in 3:
		_box(body, Vector3(0.3, 0.012, 0.014), Vector3(lx * 0.05 + 0.25 + 0.06 * k, -0.02 - 0.04 * k, zn), _std(Color("b9b5ad"), 0.3, 0.9), false)
	_box(body, Vector3(lx, 0.05, 0.012), Vector3(0, -0.05, lz / 2.0 + 0.005), _yellow, false)
	# 양 끝 번호 "2"
	for side in [-1.0, 1.0]:
		var lb := _label(body, "2", Vector3(side * (lx / 2.0 - 0.45), 0.008, 0), PI / 2 if side < 0 else -PI / 2, 0.006, Color(0.9, 0.82, 0.3), 128)
		lb.rotation.x = -PI / 2


## 덮개판 D-7: A 위로 밀려 나오는 철판(수평)과 출구를 막는 판(수직). 같은 사선 무늬, 같은 번호.
func _build_deck_and_door(g: Node3D) -> void:
	var lx := PIT_A.y - PIT_A.x
	var lz := LZ1 - LZ0
	var stripe := _std(Color("d9b632"), 0.6)
	stripe.emission_enabled = true
	stripe.emission = Color("ffd84a")
	stripe.emission_energy_multiplier = 0.0
	_stripe_mats.append(stripe)
	# 덮개 (윗면 높이 0.06)
	_deck_body = AnimatableBody3D.new()
	_deck_body.name = "DeckA"
	_deck_body.sync_to_physics = false
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(lx - 0.04, 0.06, lz - 0.02)
	cs.shape = sh
	cs.position = Vector3(0, 0.03, 0)
	_deck_body.add_child(cs)
	_deck_body.position = Vector3((PIT_A.x + PIT_A.y) / 2.0, 0.0, DECK_IN_Z if deck.value == 0 else DECK_OUT_Z)
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
	var dl := _label(_deck_body, "D-7", Vector3(0, 0.065, lz / 2.0 - 0.45), 0.0, 0.004, Color(0.92, 0.92, 0.88), 128)
	dl.rotation.x = -PI / 2
	_deck_sfx = _sfx3d(_deck_body, Vector3(0, 0.2, 0))
	# 출구판 (닫히면 문 구멍을 막는다. 열리면 위로 올라가 천장 속으로)
	_door_body = AnimatableBody3D.new()
	_door_body.name = "DoorPanel"
	_door_body.sync_to_physics = false
	var dcs := CollisionShape3D.new()
	var dsh := BoxShape3D.new()
	dsh.size = Vector3(0.08, 2.1, 1.3)
	dcs.shape = dsh
	_door_body.add_child(dcs)
	_door_body.position = Vector3(DOOR.y + 0.04, 1.05 if deck.value == 1 else 3.2, 24.0)
	add_child(_door_body)
	_box(_door_body, Vector3(0.08, 2.1, 1.3), Vector3.ZERO, _steel, false)
	for i in 3:
		var s := MeshInstance3D.new()
		var b := BoxMesh.new()
		b.size = Vector3(0.004, 0.18, 1.2)
		s.mesh = b
		s.material_override = stripe
		s.position = Vector3(0.042, -0.6 + 0.6 * i, 0)
		s.rotation.x = deg_to_rad(35.0)
		_door_body.add_child(s)
	_label(_door_body, "D-7", Vector3(0.045, 0.75, 0), PI / 2, 0.004, Color(0.92, 0.92, 0.88), 128)
	_door_sfx = _sfx3d(_door_body, Vector3(0.2, 0, 0))


# ================================================================ 조작반, 손잡이

## R의 2호기 조작반: 북쪽 벽에 붙은 회색 상자. ▲ 상승 / ▼ 하강, 상태 등.
func _build_panel() -> void:
	var p := Node3D.new()
	p.name = "Panel2"
	p.position = Vector3((R.x + R.y) / 2.0, 0.0, LZ0)
	add_child(p)
	_box(p, Vector3(0.62, 0.8, 0.18), Vector3(0, 1.3, 0.09), _std(Color("b8bbb4"), 0.55, 0.2))
	_box(p, Vector3(0.1, 0.9, 0.08), Vector3(0, 0.45, 0.04), _std(Color("8c8f8a"), 0.6, 0.3), false)
	_label(p, "기계식 주차 2호기", Vector3(0, 1.62, 0.185), 0.0, 0.0011, Color(0.12, 0.14, 0.14), 64)
	_label(p, "▲ 상승", Vector3(-0.14, 1.12, 0.185), 0.0, 0.0012, Color(0.12, 0.14, 0.14), 64)
	_label(p, "▼ 하강", Vector3(0.14, 1.12, 0.185), 0.0, 0.0012, Color(0.12, 0.14, 0.14), 64)
	_panel_lamp = _std(Color("1f4a22"), 0.4)
	_panel_lamp.emission_enabled = true
	_panel_lamp.emission = Color("4dff6a")
	_panel_lamp.emission_energy_multiplier = 1.5
	_box(p, Vector3(0.06, 0.06, 0.03), Vector3(0.22, 1.5, 0.19), _panel_lamp, false)
	_box(p, Vector3(0.09, 0.09, 0.05), Vector3(-0.22, 1.5, 0.2), _std(Color("c0281e"), 0.4), false)   # 비상정지 (장식)
	for d in [1, -1]:
		var x: float = -0.14 if d > 0 else 0.14
		_box(p, Vector3(0.1, 0.1, 0.04), Vector3(x, 1.28, 0.2), _std(Color("2e7d3a") if d > 0 else Color("2e4f9d"), 0.4), false)
		var it := _interactable(p, Vector3(x, 1.28, 0.2), Vector3(0.14, 0.14, 0.08))
		var dir: int = d
		it.interacted.connect(func() -> void: _press_lift(dir))
	_panel_sfx = _sfx3d(p, Vector3(0, 1.3, 0.3), 5.0)


## M의 덮개 손잡이: 북쪽 벽의 레버 (당길 때마다 덮개가 나오거나 들어간다).
func _build_handle() -> void:
	var p := Node3D.new()
	p.name = "DeckHandle"
	p.position = Vector3((M.x + M.y) / 2.0 + 0.6, 0.0, LZ0)
	add_child(p)
	_box(p, Vector3(0.4, 0.55, 0.14), Vector3(0, 1.15, 0.07), _std(Color("2f4a3a"), 0.6, 0.3))
	_label(p, "피트 덮개 D-7", Vector3(0, 1.48, 0.145), 0.0, 0.0011, Color(0.9, 0.9, 0.85), 64)
	_label(p, "닫힘 ↔ 열림", Vector3(0, 0.93, 0.145), 0.0, 0.0009, Color(0.9, 0.9, 0.85), 64)
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


func _press_lift(dir: int) -> void:
	var target := lift.value + dir
	if _moving[lift.id] or target < lift.min_value or target > lift.max_value:
		_play(_panel_sfx, ProcAudio.latch())
		_blink(_panel_lamp, 1.5)
		return
	var who := _lift_occupant()
	if who != "":
		print("lift hold: occupied (%s)" % who)
		_play(_panel_sfx, ProcAudio.latch())
		_blink(_panel_lamp, 1.5)
		return
	_play(_panel_sfx, ProcAudio.click())
	lift.request(target)


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


## 팔레트 위나 피트 안에 사람이 있으면 그 피트 이름
func _lift_occupant() -> String:
	if player == null:
		return ""
	var p := player.global_position
	if p.z < LZ0 or p.z > LZ1:
		return ""
	for k: String in pits:
		var span: Vector2 = pits[k]["span"]
		if p.x > span.x - 0.25 and p.x < span.y + 0.25:
			var top: float = (pits[k]["body"] as Node3D).position.y
			if p.y < -0.2 or absf(p.y - top) < 0.4:
				return k
	return ""


## 덮개 위나 출구판 문간에 사람이 있으면
func _deck_occupant() -> String:
	if player == null:
		return ""
	var p := player.global_position
	if p.z < LZ0 or p.z > LZ1:
		return ""
	if deck.value == 1 and p.x > PIT_A.x - 0.25 and p.x < PIT_A.y + 0.25 and p.y > -0.2:
		return "deck"
	if p.x > DOOR.x - 0.35 and p.x < DOOR.y + 0.35:
		return "doorway"
	return ""


func _blink(lamp: StandardMaterial3D, rest: float) -> void:
	var tw := create_tween()
	for i in 3:
		tw.tween_property(lamp, "emission_energy_multiplier", 0.0 if rest > 0.0 else 4.0, 0.08)
		tw.tween_property(lamp, "emission_energy_multiplier", 4.0 if rest > 0.0 else 0.0, 0.12)
	tw.tween_property(lamp, "emission_energy_multiplier", rest, 0.1)


## 2호기 상태가 바뀌었다: 세 피트의 팔레트가 같이 움직이고 같은 소리를 낸다 (A는 반대로).
func _on_lift(value: int) -> void:
	_moving[lift.id] = true
	stall = 0.0
	lift_moves += 1
	print("lift_2 -> %d" % value)
	var first := not _echo_done.has(lift.id)
	_echo_done[lift.id] = true
	var snd := ProcAudio.cart_roll(LIFT_TIME)
	for k: String in pits:
		var pit: Dictionary = pits[k]
		var body: AnimatableBody3D = pit["body"]
		var y: float = LIFT_Y[_stop_of(pit["inverse"], value)]
		create_tween().tween_property(body, "position:y", y, LIFT_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		# 처음 한 번: 조작반에서 먼 피트(A, G)의 소리에 긴 울림
		_play(pit["sfx"], snd, "MechEcho" if (first and k != "B") else "Parking")
		if stage == 1 and hint_stage >= 2 and k == "A":
			_flash(pit["light"] as OmniLight3D)
	get_tree().create_timer(LIFT_TIME + 0.05).timeout.connect(func() -> void: _moving[lift.id] = false)


func _on_deck(value: int) -> void:
	_moving[deck.id] = true
	stall = 0.0
	deck_moves += 1
	print("deck_d7 -> %d" % value)
	var first := not _echo_done.has(deck.id)
	_echo_done[deck.id] = true
	var snd := ProcAudio.cart_roll(DECK_TIME)
	create_tween().tween_property(_deck_body, "position:z", DECK_OUT_Z if value == 1 else DECK_IN_Z, DECK_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	create_tween().tween_property(_door_body, "position:y", 1.05 if value == 1 else 3.2, DECK_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_play(_deck_sfx, snd, "MechEcho" if first else "Parking")
	_play(_door_sfx, snd, "MechEcho" if first else "Parking")
	if stage == 2 and hint_stage >= 2:
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
	for x in [(PIT_B.x + PIT_B.y) / 2.0, (R.x + R.y) / 2.0, (PIT_A.x + PIT_A.y) / 2.0, (M.x + M.y) / 2.0, (PIT_G.x + PIT_G.y) / 2.0, (E.x + E.y) / 2.0]:
		_fixture(g, Vector3(x, H, 24.0), 0.0, "on")
	# 힌트용 작업등 (처음에는 꺼짐): P01은 조작반, P02는 덮개 틈
	for at in [Vector3((R.x + R.y) / 2.0, 2.2, 23.2), Vector3((PIT_A.x + PIT_A.y) / 2.0, 1.2, 23.0)]:
		var l := SpotLight3D.new()
		l.position = at
		l.light_color = Color("fff2c0")
		l.light_energy = 0.0
		l.spot_range = 4.0
		l.spot_angle = 40.0
		g.add_child(l)
		l.look_at(at + Vector3(0, -1.0, -0.8), Vector3.UP)
		_hint_lights.append(l)


func _build_mech_signs() -> void:
	var g := _group("Signs")
	var white := _std(Color("f1f0ea"), 0.6)
	_box(g, Vector3(0.04, 0.42, 2.6), Vector3(S0.x - 0.1, 2.4, 24.0), white, false)
	_label(g, "기계식 주차장  승용차 전용 · 2.2t", Vector3(S0.x - 0.075, 2.47, 24.0), PI / 2, 0.0016, Color(0.12, 0.2, 0.16), 96)
	_label(g, "보행 주의 · 팔레트 승강 중 진입 금지", Vector3(S0.x - 0.075, 2.29, 24.0), PI / 2, 0.0011, Color(0.75, 0.2, 0.15), 96)
	# 출구 비상구 등
	var green := _std(Color("1d8f4e"), 0.4)
	green.emission_enabled = true
	green.emission = Color("3BD07A")
	green.emission_energy_multiplier = 2.0
	_box(g, Vector3(0.05, 0.16, 0.45), Vector3(DOOR.y + 0.14, 2.45, 24.0), green, false)
	_label(g, "출구", Vector3(DOOR.y + 0.17, 2.45, 24.0), PI / 2, 0.0013, Color(0.95, 1.0, 0.95), 80)


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
	if p.y > -0.15 and p.z > LZ0 and p.z < LZ1:
		for seg: Vector2 in [S0, R, M, E]:
			if p.x > seg.x + 0.4 and p.x < seg.y - 0.4:
				_last_safe = Vector3(clampf(p.x, seg.x + 0.8, seg.y - 0.8), 0.05, 24.0)
	if not _seen_r and p.x < R.y and p.x > R.x and p.y > -0.2:
		_seen_r = true
		stall = 0.0
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
	if stage == 1 and p.x < M.y - 0.3 and p.y > -0.2 and p.z > LZ0 and p.z < LZ1:
		stage = 2
		_reset_hints()
		print("PUZZLE v2_p01 SOLVED  lift_moves=%d" % lift_moves)
		p01_solved.emit()
	if stage == 2 and p.x < E.y - 0.2 and p.y > -0.2:
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
	return "덮개로 앞 구덩이를 건널 수 있다면, 팔레트는 다른 곳에 써도 됩니다."


func _apply_hint(n: int) -> void:
	print("hint stage %d (P0%d)" % [n, stage])
	match n:
		1:
			# ① 볼 곳: P01은 조작반 위, P02는 덮개가 드나드는 벽 틈
			_hint_lights[0 if stage == 1 else 1].light_energy = 2.0
		2:
			# ② 관계: P01은 A 피트 등이 팔레트 움직임에 맞춰 밝아진다, P02는 덮개·출구판 사선 무늬가 함께 빛난다
			if stage == 1:
				(pits["A"]["light"] as OmniLight3D).light_energy = 0.25
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


func panel_button(dir: int) -> Interactable:
	var p := get_node("Panel2")
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
	lift.restore(0)
	for k: String in pits:
		var pit: Dictionary = pits[k]
		(pit["body"] as Node3D).position.y = LIFT_Y[_stop_of(pit["inverse"], 0)]
	stage = 2
	active = true
