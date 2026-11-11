## 퍼즐 1-1 "끝없는 경사로" (docs/levels/ch1_parking.md).
##
## 규칙 R1: 화살표(아래)를 따라 내려가면 같은 B2가 반복되고, 거슬러 올라가면 B3에 도착한다.
##
## 구성 (층 두 개, 나선 두 개):
##   B2      : 플레이어가 돌아다니는 층. 동쪽에 위로 가는 나선, 서쪽에 아래로 가는 나선 입구가 있다.
##   동쪽 나선: 실제로 B3로 이어진다. 올라가는 쪽에는 순간이동이 없다.
##   서쪽 나선: B2 서쪽 입구에서 아래로 내려가는 나선. 아래층은 만들지 않는다 (보이지 않는다).
##   B3      : 동쪽 나선 출구(13 m 통로)에 닿는 진짜 위층. B2 북동쪽 바로 위에 겹쳐 놓았다 (B2 천장 = B3 바닥).
##             겹친 층끼리 조명이 새지 않도록 B3는 렌더 레이어 2를 쓰고, 플레이어가 없는 층의 조명은 끈다.
##
## 관문 하나:
##   서쪽 나선 가운데(135도)를 내려가며 지나면 → 동쪽 나선 가운데로 옮겨진다 → 계속 내려가면 다시 B2.
##   나선 가운데에서는 휘어진 벽 때문에 양 끝이 보이지 않으므로, 두 나선의 나선 부분만 같으면 이음새가 없다.
##   (자세한 모양은 helix_ramp.gd)
##
## B3 바닥에 들어선 뒤, 플레이어가 보지 않는 사이 B3 입구에 방화셔터가 내려온다 (1-2 도입).
##
## 프롤로그 (prologue.gd): 지상 입구 → 정산소 → 경사로 → B1 → 동쪽 나선을 내려가 B2.
##   B1과 B3는 같은 자리(B2 위층)에 겹쳐 만든 두 벌이다. 프롤로그 동안에는 B1이 보이고,
##   플레이어가 B2에 들어서면 (위층은 보이지 않으므로) 그 자리를 B3로 바꾼다. 그래서 "내려온 길로
##   되돌아 올라가면 B3"라는 1-1의 정답이 실제 공간으로 성립한다.
##
## 실행 인자 (테스트용):
##   --test=down|downback|up|tour|hints|prologue   자동으로 걷거나 둘러보며 스크린샷을 찍고 종료
##   --start=prologue|b2                  시작 위치 (기본: 프롤로그. 테스트는 prologue 외에는 b2)
##   --out=<폴더>                         테스트 스크린샷 저장 위치
##   --hint-scale=<배수>                  힌트 시간을 빠르게 (예: 100)
##   --hold=<프레임>                      순간이동 직후 직전 화면을 덮을 프레임 수 (기본 0)
##   --rebake-gi                          간접광을 다시 굽는다
extends Node3D

const PLAYER_SCRIPT := preload("res://core/player/player.gd")
const GI_FLOOR_PATH := "res://levels/ch1_parking/p1_1_floor_voxelgi.res"
const GI_HELIX_PATH := "res://levels/ch1_parking/p1_1_helix_voxelgi.res"

const W := ParkingFloor.W
const H := ParkingFloor.H
const EAST := HelixRamp.EAST_OFFSET               # 동쪽 나선 조각 원점
const WEST := HelixRamp.WEST_OFFSET               # 서쪽 나선 조각 원점
const JUMP := HelixRamp.EAST_OFFSET - HelixRamp.WEST_OFFSET   # 관문을 지날 때의 이동량
const HINT_TIMES := [420.0, 720.0, 1080.0]        # 7분, 12분, 18분 (GDD 8장)
const SPAWN := Vector3(44.0, 0.05, 24.0)

var player: CharacterBody3D
var b2: ParkingFloor
var b1: ParkingFloor            # 프롤로그 동안의 위층
var b3: ParkingFloor            # 프롤로그가 끝난 뒤의 위층 (같은 자리)
var prologue: Prologue
var prologue_done := false
var east_helix: HelixRamp
var west_helix: HelixRamp
var gate_down: LoopGate          # 서쪽 나선 가운데
var gate_landing: LoopGate       # 동쪽 나선 가운데 (도착 자리 표시용. 스스로는 아무것도 하지 않는다)

var loops := 0
var solved := false
var elapsed := 0.0
var hint_stage := 0
var hint_scale := 1.0

var _stain: Decal
var _b3_shutter: Node3D
var _b3_shutter_body: StaticBody3D
var _b3_shutter_closed := false
var _sign_pending := false
var _drip: AudioStreamPlayer3D
var _drip_next := 0.0
var _sfx: AudioStreamPlayer3D
var _debug: Label
var _hold: FrameHold
var _hold_frames := 0
var _f2_was := false
var _rng := RandomNumberGenerator.new()
var _barrier_lowered := false
var _city: AudioStreamPlayer
var _far: AudioStreamPlayer3D
var _out_drip_next := 0.0
var traces: Array[String] = []

# 테스트용 길 안내
var _route: Array[Vector3] = []
var _route_backward := false


func _ready() -> void:
	_rng.randomize()
	var hs := LevelEnv.arg_value("--hint-scale")
	if hs != "":
		hint_scale = float(hs)
	var hold := LevelEnv.arg_value("--hold")
	if hold != "":
		_hold_frames = int(hold)
	ProcAudio.ensure_reverb_bus("Parking", 0.85, 0.32)
	LevelEnv.create(self, LevelEnv.GI.BAKED)

	b2 = _make_floor("B2", Vector3.ZERO, "B2", true, true, true, "출구  ↑ B1")
	var upper := HelixRamp.upper_origin()
	b1 = _make_floor("B1", upper, "B1", true, false, false, "출구  ↑ 1F", HelixRamp.UPPER_ROT_Y, true, 2209)
	b3 = _make_floor("B3", upper, "B3", true, false, false, "출구  ↑ B2", HelixRamp.UPPER_ROT_Y, true, 3301)
	# B3의 위로 가는 경사로는 닫혀 있다
	var closed := (load(ParkingFloor.KIT + "fire_shutter.glb") as PackedScene).instantiate() as Node3D
	closed.position = ParkingFloor.tunnel_point(1.0)
	b3.add_child(closed)
	var closed_body := StaticBody3D.new()
	var ccs := CollisionShape3D.new()
	var cshape := BoxShape3D.new()
	cshape.size = Vector3(0.2, 2.7, 6.0)
	ccs.shape = cshape
	ccs.position = ParkingFloor.tunnel_point(1.0) + Vector3(0, 1.35, 0)
	closed_body.add_child(ccs)
	b3.add_child(closed_body)
	b1.set_render_layer(2)
	b3.set_render_layer(2)
	prologue = Prologue.new()
	prologue.name = "Prologue"
	add_child(prologue)
	prologue.build(b1.to_global(Vector3(W + ParkingFloor.RAMP_LEN, ParkingFloor.RAMP_RISE, ParkingFloor.RAMP_Z)))
	prologue.ticket_taken.connect(_on_ticket)
	_build_half_shutter()
	east_helix = _make_helix("EastHelix", EAST, "east")
	west_helix = _make_helix("WestHelix", WEST, "west")
	# 서쪽 나선의 아래쪽 끝은 아무 데도 이어지지 않으니 막는다 (가운데에서는 보이지 않는다)
	_cap(WEST, Vector3(-0.15, 1.35, 0.0), Vector3(0.3, 2.7, 6.6))

	_build_shutter()
	_build_gates()
	_build_gi()
	_build_stain()
	_build_audio()
	LevelEnv.add_post_fx(self)
	_build_debug()
	_hold = FrameHold.new()
	add_child(_hold)

	var test := LevelEnv.arg_value("--test")
	var start := LevelEnv.arg_value("--start")
	if start == "":
		start = "prologue" if (test == "" or test == "prologue") else "b2"
	_spawn_player(test == "", start)
	if test != "":
		_run_test(test)


# ================================================================ 만들기

func _make_floor(node_name: String, origin: Vector3, label: String, west: bool, helix: bool, cup: bool, sign: String, yaw := 0.0, tunnel := false, seed := 2209) -> ParkingFloor:
	var f := ParkingFloor.new()
	f.name = node_name
	f.floor_name = label
	f.sign_text = sign
	f.light_seed = seed
	f.west_opening = west
	f.east_tunnel = tunnel
	f.east_helix = helix
	f.with_cup = cup
	f.position = origin
	f.rotation.y = yaw
	add_child(f)
	f.build(origin)
	return f


func _make_helix(node_name: String, origin: Vector3, v: String) -> HelixRamp:
	var h := HelixRamp.new()
	h.name = node_name
	h.position = origin
	add_child(h)
	h.build_ramp(origin, v)
	return h


func _cap(origin: Vector3, center: Vector3, size: Vector3) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = ParkingMats.for_floor(origin)["concrete_paint"]
	mi.position = origin + center
	add_child(mi)
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	body.position = origin + center
	body.add_child(cs)
	add_child(body)


## 지상에서 B1로 내려가는 경사로 위쪽의 반쯤 내려온 셔터: 웅크려야 지나간다 (웅크리기를 배운다).
func _build_half_shutter() -> void:
	var gap := 1.15
	var at := ParkingFloor.tunnel_point(20.5)
	var s := (load(ParkingFloor.KIT + "fire_shutter.glb") as PackedScene).instantiate() as Node3D
	s.position = at + Vector3(0, gap, 0)
	b1.add_child(s)
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.25, 2.7 - gap + 0.3, 6.0)
	cs.shape = shape
	cs.position = at + Vector3(0, gap + shape.size.y / 2.0, 0)
	body.add_child(cs)
	b1.add_child(body)
	b1.set_render_layer(2)   # 새로 붙인 셔터도 B1 조명을 받게


## B3 입구(동쪽 나선 출구 끝)의 방화셔터. 처음에는 숨겨 둔다.
func _build_shutter() -> void:
	var at := EAST + Vector3(4.0, HelixRamp.RISE, HelixRamp.EAST_EXIT_Z + 1.5)
	_b3_shutter = (load(ParkingFloor.KIT + "fire_shutter.glb") as PackedScene).instantiate()
	_b3_shutter.position = at
	_b3_shutter.rotation.y = PI / 2
	_b3_shutter.visible = false
	add_child(_b3_shutter)
	_b3_shutter_body = StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.2, 2.7, 6.0)
	cs.shape = shape
	cs.position = Vector3(0, 1.35, 0)
	_b3_shutter_body.position = at
	_b3_shutter_body.rotation.y = PI / 2
	_b3_shutter_body.add_child(cs)
	_b3_shutter_body.process_mode = Node.PROCESS_MODE_DISABLED
	add_child(_b3_shutter_body)


func _gate(node_name: String, piece_origin: Vector3) -> LoopGate:
	var g := LoopGate.new()
	g.name = node_name
	g.position = piece_origin + HelixRamp.point(HelixRamp.GATE_PHI) + Vector3(0, 1.0, 0)
	# 관문의 -Z(정방향)를 나선을 내려가는 방향으로 돌린다
	var d := HelixRamp.downhill(HelixRamp.GATE_PHI)
	g.rotation.y = atan2(-d.x, -d.z)
	add_child(g)
	return g


func _build_gates() -> void:
	gate_down = _gate("GateDown", WEST)
	gate_landing = _gate("GateLanding", EAST)
	gate_down.forward_target = gate_landing
	gate_down.crossed.connect(_on_gate_down)


## 미리 구운 간접광 (VoxelGI). 층용 하나, 나선용 하나를 따로 굽고 같은 모양끼리 나눠 쓴다.
## 하나로 묶으면 조명이 많은 쪽(B2 층)의 나선이 서쪽 나선보다 어둡게 나와 관문에서 밝기 차이가 났다.
## SDFGI는 카메라를 따라 계산이 쌓여서, 순간이동 직후 밝기가 출렁이므로 쓰지 않는다.
func _build_gi() -> void:
	# 화면 없이(headless) 실행하면 제대로 구울 수 없으므로 아무것도 하지 않는다
	if DisplayServer.get_name() == "headless":
		return
	_gi_group([b2, b1, b3], Vector3(24.0, 1.3, 16.0), Vector3(48.6, 3.2, 32.6), GI_FLOOR_PATH, 1.2)
	# 나선은 좁고 벽이 밝아서 간접광이 과하게 쌓인다. 층보다 약하게 한다
	_gi_group([east_helix, west_helix], Vector3(13.0, 3.0, 9.0), Vector3(26.0, 7.0, 26.0), GI_HELIX_PATH, 0.55)


func _gi_group(nodes: Array, center: Vector3, size: Vector3, path: String, energy: float) -> void:
	var data: VoxelGIData = null
	if FileAccess.file_exists(path) and LevelEnv.arg_value("--rebake-gi") == "":
		data = load(path) as VoxelGIData
		if data != null and data.get_bounds().size == Vector3.ZERO:
			data = null   # 망가진 파일: 다시 굽는다
	for n: Node3D in nodes:
		var v := VoxelGI.new()
		v.name = "GI"
		v.subdiv = VoxelGI.SUBDIV_128
		v.size = size
		v.position = center
		v.layers = 1 | 2
		n.add_child(v)
	if data == null:
		var t := Time.get_ticks_msec()
		var first: VoxelGI = (nodes[0] as Node3D).get_node("GI")
		first.bake(self, false)
		data = first.data
		if data == null or data.get_bounds().size == Vector3.ZERO:
			push_warning("VoxelGI bake failed: " + path)
			return
		data.interior = true
		data.propagation = 0.65
		data.use_two_bounces = true
		ResourceSaver.save(data, path)
		print("baked %s in %d ms" % [path.get_file(), Time.get_ticks_msec() - t])
	data.energy = energy
	for n: Node3D in nodes:
		(n.get_node("GI") as VoxelGI).data = data


func _build_stain() -> void:
	_stain = Decal.new()
	_stain.texture_albedo = ParkingMats.tex("oil_stain_b")
	_stain.modulate = Color(0.75, 0.55, 0.35, 0.9)
	_stain.size = Vector3(0.3, 0.3, 0.3)
	_stain.position = Vector3(2.45, 0.0, 22.05)
	_stain.visible = false
	b2.add_child(_stain)


func _build_audio() -> void:
	var hum := AudioStreamPlayer.new()
	hum.stream = ProcAudio.hum()
	hum.volume_db = -26.0
	hum.autoplay = true
	add_child(hum)
	_drip = AudioStreamPlayer3D.new()
	_drip.bus = "Parking"
	_drip.unit_size = 6.0
	_drip.position = HelixRamp.point(HelixRamp.TURN * 0.6) + Vector3(0, 2.4, 0)
	east_helix.add_child(_drip)
	_sfx = AudioStreamPlayer3D.new()
	_sfx.bus = "Parking"
	_sfx.unit_size = 10.0
	add_child(_sfx)
	# 멀리서 나는 소리 (차단기): 크게 울리고 멀리까지 들린다
	_far = AudioStreamPlayer3D.new()
	_far.bus = "Parking"
	_far.unit_size = 30.0
	_far.max_distance = 120.0
	add_child(_far)
	# 바깥 밤거리 소리
	_city = AudioStreamPlayer.new()
	_city.stream = ProcAudio.city()
	_city.volume_db = -60.0
	_city.autoplay = true
	add_child(_city)


func _build_debug() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 20
	_debug = Label.new()
	_debug.position = Vector2(16, 12)
	_debug.add_theme_color_override("font_color", Color(0.7, 1.0, 0.75))
	_debug.add_theme_color_override("font_outline_color", Color.BLACK)
	_debug.add_theme_constant_override("outline_size", 4)
	_debug.visible = false
	layer.add_child(_debug)
	add_child(layer)


func _spawn_player(interactive: bool, start: String) -> void:
	player = CharacterBody3D.new()
	player.set_script(PLAYER_SCRIPT)
	player.name = "Player"
	player.set("sfx_bus", "Parking")
	player.set("input_enabled", interactive)
	if start == "prologue":
		player.position = prologue.start_point
		player.rotation.y = PI   # 건물 입구(+Z)를 본다
		_set_upper(false)
	else:
		player.position = SPAWN
		player.rotation.y = PI / 2   # 서쪽(-X)을 본다: 방금 동쪽 경사로로 내려온 모습
		prologue_done = true
		_barrier_lowered = true
		_set_upper(true)
	add_child(player)
	gate_down.player = player
	gate_landing.player = player


# ================================================================ 진행

## 위층을 B1(프롤로그) 또는 B3(그 뒤)로 정한다. 숨긴 쪽은 충돌과 처리도 끈다.
func _set_upper(is_b3: bool) -> void:
	b1.visible = not is_b3
	b1.process_mode = Node.PROCESS_MODE_DISABLED if is_b3 else Node.PROCESS_MODE_INHERIT
	b3.visible = is_b3
	b3.process_mode = Node.PROCESS_MODE_INHERIT if is_b3 else Node.PROCESS_MODE_DISABLED


func _upper() -> ParkingFloor:
	return b3 if prologue_done else b1


func _on_ticket() -> void:
	traces.append("주차권 (1999.07.14)")
	_sfx.global_position = prologue.ticket.global_position
	_sfx.stream = ProcAudio.paper()
	_sfx.play()
	print("TRACE 1: 주차권")


## 프롤로그 진행: B1에 들어서면 멀리서 차단기가 내려오고, B2에 들어서면 위층이 B3로 바뀐다.
func _update_prologue() -> void:
	if prologue_done or player == null:
		return
	var p := player.global_position
	var in_b1 := _in_floor(b1, p)
	if in_b1 and not _barrier_lowered:
		_barrier_lowered = true
		prologue.lower_barrier()
		_far.global_position = prologue.mouth + Vector3(4.0, 1.3, -3.4)
		_far.stream = ProcAudio.barrier()
		_far.play()
		print("prologue: entered B1, barrier lowered")
	if _in_floor(b2, p):
		prologue_done = true
		_set_upper(true)
		print("prologue: reached B2 -> upper floor is now B3")
	# 바깥: 도시 소리, 처마에서 떨어지는 물방울, 먼 쪽으로 갈수록 느려지는 걸음
	var outside := prologue.is_outside(p)
	_city.volume_db = lerpf(_city.volume_db, -22.0 if outside else -60.0, 0.05)
	var far := (prologue.mouth.z - 20.0) - p.z
	player.set("speed_scale", clampf(1.0 - far / 22.0, 0.12, 1.0) if outside else 1.0)
	var t := Time.get_ticks_msec() / 1000.0
	if outside and t >= _out_drip_next:
		_out_drip_next = t + _rng.randf_range(0.8, 2.2)
		_far.global_position = prologue.mouth + Vector3(_rng.randf_range(-6, 6), 3.3, -1.0)
		_far.stream = ProcAudio.drip(_rng.randi_range(1, 50))
		_far.play()


func _in_floor(f: ParkingFloor, world: Vector3) -> bool:
	var l := f.to_local(world)
	return l.x > 0.3 and l.x < W - 0.3 and l.z > 0.3 and l.z < ParkingFloor.D - 0.3 and l.y > -0.5 and l.y < 2.0


func _on_gate_down(forward: bool, teleported: bool) -> void:
	if not (forward and teleported):
		return
	if _hold_frames > 0:
		_hold.hold(_hold_frames)
	for i in _route.size():
		_route[i] += JUMP   # 테스트 길 안내도 같이 옮긴다
	loops += 1
	if loops >= 3:
		# 반복할 때마다 커피컵에서 흘러나온 얼룩이 넓어진다 (반복 횟수의 표시)
		var s := minf(0.35 + 0.22 * (loops - 2), 1.5)
		_stain.size = Vector3(s, 0.3, s)
		_stain.visible = true
	print("loop ", loops)


func _process(delta: float) -> void:
	_update_prologue()
	if not solved and prologue_done:
		elapsed += delta * hint_scale
		while hint_stage < HINT_TIMES.size() and elapsed >= HINT_TIMES[hint_stage]:
			hint_stage += 1
			_apply_hint(hint_stage)
	_update_sign_hint()
	_update_drip()
	_update_b3_shutter()
	_update_floor_lights()
	_check_solved()
	if Input.is_physical_key_pressed(KEY_F2) and not _f2_was:
		_debug.visible = not _debug.visible
	_f2_was = Input.is_physical_key_pressed(KEY_F2)
	if _debug.visible and player:
		var p := player.global_position
		_debug.text = "1-1  loops:%d  hint:%d  t:%.0fs  solved:%s\npos: %.1f, %.1f, %.1f   fps:%d" % [loops, hint_stage, elapsed, solved, p.x, p.y, p.z, Engine.get_frames_per_second()]


func _physics_process(_delta: float) -> void:
	_follow_route()


func _apply_hint(stage: int) -> void:
	print("hint stage ", stage)
	match stage:
		1:
			# ① 위로 가는 경사로 입구의 형광등이 깜빡이기 시작한다
			for x in [46.0, 42.0, 38.0]:
				b2.make_fixture_flicker(Vector3(x, H, 24.0))
		2:
			# ② 위쪽 경사로에서 물방울 소리
			_drip_next = 0.0
		3:
			# ③ 경사로 위 안내판이 "B3"를 가리킨다 (안 보는 사이에 바뀐다)
			_sign_pending = true


func _update_drip() -> void:
	if hint_stage < 2 or solved:
		return
	var t := Time.get_ticks_msec() / 1000.0
	if t >= _drip_next:
		_drip.stream = ProcAudio.drip(_rng.randi_range(1, 50))
		_drip.play()
		_drip_next = t + _rng.randf_range(1.6, 3.4)


func _update_sign_hint() -> void:
	if not _sign_pending or player == null:
		return
	var label := b2.hanging_sign_label
	var cam: Camera3D = player.get("camera")
	if cam and not cam.is_position_in_frustum(label.global_position):
		label.text = "↑  B3"
		label.modulate = Color(1.0, 1.0, 0.92)
		_sign_pending = false
		_sfx.global_position = label.global_position
		_sfx.stream = ProcAudio.click()
		_sfx.play()


func _update_b3_shutter() -> void:
	if _b3_shutter_closed or not solved or not prologue_done or player == null:
		return
	var cam: Camera3D = player.get("camera")
	if cam == null:
		return
	# 플레이어가 B3 바닥에 들어섰고, 셔터 자리가 화면에 없을 때 내려온다
	if b3.to_local(player.global_position).x < 1.5:
		return
	var base := _b3_shutter.global_position
	for off in [Vector3(0, 0.2, -2.8), Vector3(0, 0.2, 2.8), Vector3(0, 2.5, -2.8), Vector3(0, 2.5, 2.8), Vector3(0, 1.3, 0)]:
		if cam.is_position_in_frustum(base + off):
			return
	_b3_shutter.visible = true
	_b3_shutter_body.process_mode = Node.PROCESS_MODE_INHERIT
	_b3_shutter_closed = true
	_sfx.global_position = base + Vector3(0, 1.5, 0)
	_sfx.stream = ProcAudio.shutter()
	_sfx.play()
	print("B3 shutter closed")


## 겹쳐 놓은 두 층 중 플레이어가 없는 층의 조명을 끈다.
## 레이어를 나눠도 볼류메트릭 안개는 그림자가 꺼지는 먼 거리에서 바닥 판을 넘어 빛을 받기 때문이다. 성능에도 이롭다.
## B3는 동쪽 나선 위쪽(높이 1.2 m 이상)이나 B3에 있을 때만 켜고, B2는 B3 안쪽 깊이 들어가면 끈다.
var _b3_lights_on := true
var _b2_lights_on := true


func _update_floor_lights() -> void:
	if player == null:
		return
	var p := player.global_position
	var up := _upper()
	var b3_on := p.y > 1.2
	var b2_on := up.to_local(p).x < 10.0 or p.y < 1.2
	if b3_on != _b3_lights_on:
		_b3_lights_on = b3_on
		for f in [b1, b3]:
			for l in (f as ParkingFloor).lights():
				(l as Light3D).visible = b3_on
	if b2_on != _b2_lights_on:
		_b2_lights_on = b2_on
		for l in b2.lights():
			(l as Light3D).visible = b2_on


func _check_solved() -> void:
	if solved or not prologue_done or player == null:
		return
	var p := b3.to_local(player.global_position)
	if p.y > -0.3 and p.x > 0.0 and p.x < W and p.z > 0.0 and p.z < ParkingFloor.D:
		solved = true
		print("PUZZLE 1-1 SOLVED  loops=%d  time=%.0fs  hint=%d" % [loops, elapsed / hint_scale, hint_stage])


# ================================================================ 자동 테스트

## 테스트용: 길 안내 점을 따라 걷게 한다. backward면 길을 등지고 뒷걸음질한다.
func _follow_route() -> void:
	if _route.is_empty() or player == null:
		return
	var to := _route[0] - player.global_position
	to.y = 0.0
	if to.length() < 1.0:
		_route.remove_at(0)
		if _route.is_empty():
			player.set("auto_move", Vector3.ZERO)
		return
	var yaw := atan2(-to.x, -to.z)
	player.rotation.y = yaw + (PI if _route_backward else 0.0)
	player.set("auto_move", Vector3(0, 0, 1) if _route_backward else Vector3(0, 0, -1))


## 서쪽 나선을 내려가는 길. 관문을 지나면 길 전체가 JUMP만큼 옮겨져, 마지막 점은 B2 동쪽 안쪽이 된다.
func _route_through_west_helix() -> Array[Vector3]:
	var pts: Array[Vector3] = [Vector3(1.0, 0.0, 24.0)]
	for p in HelixRamp.route_down("west"):
		pts.append(WEST + p)
	return pts


func _route_up_to_b3() -> Array[Vector3]:
	var down := HelixRamp.route_down("east")
	down.reverse()
	var pts: Array[Vector3] = [Vector3(W - 0.5, 0.0, 24.0)]
	for p in down:
		pts.append(EAST + p)
	pts.append(b3.to_global(Vector3(6.0, 0.0, 24.0)))
	return pts


func _run_test(kind: String) -> void:
	var out := LevelEnv.arg_value("--out")
	if out == "":
		out = ProjectSettings.globalize_path("user://test_p1_1")
	DirAccess.make_dir_recursive_absolute(out)
	await get_tree().create_timer(3.0).timeout
	match kind:
		"down", "downback":
			player.global_position = Vector3(8.0, 0.05, 24.0)
			_route_backward = kind == "downback"
			await _test_seam(out, kind, _route_through_west_helix())
		"up":
			player.global_position = Vector3(40.0, 0.05, 24.0)
			_route = _route_up_to_b3()
			var deadline := Time.get_ticks_msec() + 40000
			while not _route.is_empty() and Time.get_ticks_msec() < deadline:
				await get_tree().process_frame
			await _save(out.path_join("up_arrive.png"))
			print("up: solved=%s shutter=%s pos=%s" % [solved, _b3_shutter_closed, player.global_position])
			player.rotation.y += PI
			await get_tree().create_timer(1.0).timeout
			await _save(out.path_join("up_look_back.png"))
		"tour":
			await _test_tour(out)
		"prologue":
			await _test_prologue(out)
		"hints":
			await _test_hints(out)
	get_tree().quit()


## 길을 따라 걷다가 관문을 지나는 순간의 직전·직후 화면을 비교한다.
## 기준: 순간이동 없이 한 프레임 걸었을 때의 차이(baseline)와 비슷하면 이음새가 안 보이는 것.
func _test_seam(out: String, tag: String, route: Array[Vector3]) -> void:
	var state := {"hit": false}
	gate_down.crossed.connect(func(_f: bool, tp: bool) -> void:
		if tp:
			state["hit"] = true)
	_route = route
	var prev: Image = null
	var prev2: Image = null
	var frames_after := -1
	var deadline := Time.get_ticks_msec() + 40000
	while Time.get_ticks_msec() < deadline:
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		if frames_after < 0 and state["hit"] and prev != null:
			frames_after = 1
			prev.save_png(out.path_join("%s_before.png" % tag))
			img.save_png(out.path_join("%s_after_01.png" % tag))
			print("%s: baseline=%.4f  after_01=%.4f" % [tag, _diff(prev2, prev), _diff(prev, img)])
		elif frames_after >= 1:
			frames_after += 1
			if frames_after <= 4:
				print("%s: after_%02d (직전 프레임 대비) = %.4f" % [tag, frames_after, _diff(prev, img)])
			if frames_after == 2:
				img.save_png(out.path_join("%s_after_02.png" % tag))
			if frames_after >= 10:
				break
		prev2 = prev
		prev = img
	while not _route.is_empty() and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	await _save(out.path_join("%s_end.png" % tag))
	var p := player.global_position
	print("%s end pos: %.1f, %.1f, %.1f  loops=%d  fps=%d" % [tag, p.x, p.y, p.z, loops, Engine.get_frames_per_second()])


func _diff(a: Image, b: Image) -> float:
	if a == null or b == null:
		return -1.0
	var x := a.duplicate() as Image
	var y := b.duplicate() as Image
	x.resize(160, 90, Image.INTERPOLATE_BILINEAR)
	y.resize(160, 90, Image.INTERPOLATE_BILINEAR)
	var sum := 0.0
	for j in 90:
		for i in 160:
			var ca := x.get_pixel(i, j)
			var cb := y.get_pixel(i, j)
			sum += absf(ca.r - cb.r) + absf(ca.g - cb.g) + absf(ca.b - cb.b)
	return sum / (160.0 * 90.0 * 3.0)


func _save(path: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)


func _tour_list() -> Array:
	var gp := HelixRamp.GATE_PHI
	var gate := EAST + HelixRamp.point(gp) + Vector3(0, 1.6, 0)
	var down := HelixRamp.downhill(gp) * 5.0
	return [
		["t1_west_entrance", Vector3(5.5, 1.6, 20.0), Vector3(0.0, 0.8, 24.0)],
		["t2_east_entrance", Vector3(40.0, 1.6, 23.0), Vector3(W + 6.0, 1.5, 24.0)],
		["t3_helix_gate_down", gate, gate + down + Vector3(0, -0.4, 0)],
		["t4_helix_gate_up", gate, gate - down + Vector3(0, 0.4, 0)],
		["t5_east_exit", EAST + Vector3(4.0, 4.6, 8.0), EAST + Vector3(4.0, 4.4, -6.0)],
		["t8_b3_from_entrance", b3.to_global(Vector3(2.0, 1.6, 24.0)), b3.to_global(Vector3(20.0, 1.2, 10.0))],
		["t9_b2_ceiling_under_b3", Vector3(36.0, 1.6, 12.0), Vector3(30.0, 2.6, 4.0)],
		["t6_b3_floor", b3.to_global(Vector3(4.0, 1.6, 24.0)), b3.to_global(Vector3(40.0, 1.2, 20.0))],
		["t7_west_exit_from_b2", Vector3(3.0, 1.6, 24.0), Vector3(-6.0, 1.2, 30.0)],
	]


func _test_tour(out: String) -> void:
	player.set_physics_process(false)
	for s in _tour_list():
		player.global_position = s[1] - Vector3(0, 1.6, 0)
		player.camera.global_position = s[1]
		player.camera.look_at(s[2], Vector3.UP)
		await get_tree().create_timer(1.5).timeout
		await _save(out.path_join(s[0] + ".png"))
		await get_tree().create_timer(2.0).timeout   # 셰이더 준비가 끝난 뒤의 fps
		print("tour ", s[0], "  fps=", Engine.get_frames_per_second())


## 테스트용: 카메라가 이 점을 정확히 보게 한다
func _aim_at(target: Vector3) -> void:
	var cam: Camera3D = player.get("camera")
	var d := target - cam.global_position
	player.rotation.y = atan2(-d.x, -d.z)
	player.call("set_look", atan2(d.y, Vector2(d.x, d.z).length()))


func _walk_to(points: Array[Vector3], timeout_s := 60.0) -> void:
	_route = points
	var deadline := Time.get_ticks_msec() + int(timeout_s * 1000.0)
	while not _route.is_empty() and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	if not _route.is_empty():
		print("prologue test: route timed out at ", player.global_position)
		_route.clear()
		player.set("auto_move", Vector3.ZERO)


## 프롤로그를 처음부터 끝까지 걷는다: 길 건너기 → 인도 턱 오르기 → 정산소 창문 열기 → 주차권
## → 높이제한 바에 머리 부딪히기 → 셔터 밑 웅크리기 → B1 → B2.
func _test_prologue(out: String) -> void:
	var m := prologue.mouth
	var gy := prologue.ground_y
	await _save(out.path_join("p0_start.png"))
	player.rotation.y = 0.0   # 뒤(건너편 아파트)를 본다
	await get_tree().create_timer(1.0).timeout
	await _save(out.path_join("p0_behind.png"))
	player.rotation.y = PI
	# 길을 건너 이쪽 인도로 올라선다 (턱 0.15 m: 저절로 올라가야 한다)
	await _walk_to([Vector3(m.x - 5.0, gy, m.z - 12.0), Vector3(m.x - 5.0, gy, m.z - 4.0)])
	print("step up onto sidewalk: y=%.2f (인도 높이 %.2f 근처여야 함)" % [player.global_position.y, gy + Prologue.WALK])
	await _save(out.path_join("p0_sidewalk.png"))
	# 정산소 창문 앞 (진입로에서 창문을 본다)
	await _walk_to([Vector3(m.x + 2.0, gy, m.z - 3.5)])
	player.global_position = Vector3(m.x + 3.05, gy + 0.05, m.z - 2.95)
	player.rotation.y = -PI / 2   # +X(정산소)를 본다
	player.call("set_look", 0.0)
	await get_tree().create_timer(0.5).timeout
	await _save(out.path_join("p1_booth_closed.png"))
	print("open window: ", player.call("try_interact"))
	await get_tree().create_timer(1.0).timeout
	_aim_at(prologue.ticket.global_position)
	await get_tree().create_timer(0.3).timeout
	await _save(out.path_join("p1_booth_open.png"))
	print("take ticket: ", player.call("try_interact"), "  traces=", traces)
	player.call("set_look", 0.0)
	# 높이제한 바 밑에서 점프: 머리가 닿으면 바가 흔들린다
	await _walk_to([Vector3(m.x, gy, m.z - 2.0)])
	player.global_position = Vector3(m.x, gy + 0.05, m.z - 0.75)
	player.rotation.y = PI
	await get_tree().create_timer(0.3).timeout
	player.call("request_jump")
	await get_tree().create_timer(0.35).timeout
	print("height bar swinging after jump: ", prologue.get("_bar_swinging"), "  max head y ~ ", player.global_position.y + 1.75)
	player.global_position = Vector3(m.x, gy + 0.05, m.z - 3.0)
	await get_tree().create_timer(0.8).timeout
	player.call("set_look", 0.15)
	await _save(out.path_join("p2_bar.png"))
	player.call("set_look", 0.0)
	# 입구로, 셔터 밑은 웅크려서
	await _walk_to([Vector3(m.x, gy, m.z - 4.0), Vector3(m.x, gy, m.z - 0.5)])
	await _save(out.path_join("p2_entrance.png"))
	# 서서는 셔터 밑을 못 지나가야 한다
	var shutter_z := b1.to_global(ParkingFloor.tunnel_point(20.5)).z
	_route = [b1.to_global(ParkingFloor.tunnel_point(14.0))]
	await get_tree().create_timer(4.0).timeout
	_route.clear()
	player.set("auto_move", Vector3.ZERO)
	print("standing at shutter: z=%.2f, shutter z=%.2f (서서는 셔터 앞에서 멈춰야 함)" % [player.global_position.z, shutter_z])
	player.set("auto_crouch", true)
	var tunnel_mid := b1.to_global(ParkingFloor.tunnel_point(14.0))
	await _walk_to([tunnel_mid])
	player.set("auto_crouch", false)
	await get_tree().create_timer(0.5).timeout
	print("after half shutter: crouching=%s pos=%s" % [player.get("crouching"), player.global_position])
	# B1을 가로질러 서쪽 입구로
	await _walk_to([b1.to_global(Vector3(W - 2.0, 0.0, 24.0)), b1.to_global(Vector3(24.0, 0.0, 24.0))])
	await _save(out.path_join("p3_b1.png"))
	await _walk_to([b1.to_global(Vector3(1.0, 0.0, 24.0))])
	# 동쪽 나선을 내려가 B2로
	var down: Array[Vector3] = []
	for q in HelixRamp.route_down("east"):
		down.append(EAST + q)
	await _walk_to(down)
	await get_tree().create_timer(0.5).timeout
	await _save(out.path_join("p4_b2.png"))
	print("prologue test end: done=%s barrier=%s b3_visible=%s pos=%s" % [prologue_done, _barrier_lowered, b3.visible, player.global_position])


func _test_hints(out: String) -> void:
	hint_scale = 300.0
	player.global_position = Vector3(40.0, 0.05, 23.0)
	player.rotation.y = PI / 2
	await get_tree().create_timer(5.0).timeout
	player.rotation.y = -PI / 2 - 0.15   # 경사로 쪽을 본다
	await get_tree().create_timer(1.0).timeout
	await _save(out.path_join("hints_sign.png"))
	print("hint stage: ", hint_stage, "  sign: ", b2.hanging_sign_label.text)
