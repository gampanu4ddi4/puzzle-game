## 1장 주차장 (v2): 프롤로그 → B1 → 나선 경사로 → B2 → 기계식 주차 구역 v2_p01·v2_p02 (docs/levels/ch1_parking.md).
##
## 구성:
##   프롤로그 (prologue.gd): 지상 거리와 입구. 정산소 창문을 열고 개방 손잡이를 당기면 차단기가 올라간다.
##   B1      : 입구 경사로를 내려와 닿는 층. B2 북동쪽 위에 실제로 겹쳐 있다 (렌더 레이어 2).
##   동쪽 나선: B1 서쪽 끝에서 B2 동쪽 입구로 내려가는 270도 나선. 반복·순간이동 없는 정상 경사로다.
##   B2      : 나선을 내려오면 서쪽 끝(복도 정면)에 기계식 주차 구역 입구가 보인다.
##   P01·P02 : B2 서쪽 입구 밖의 기계식 주차 구역 (mech_parking.gd).
##
## 실행 인자 (테스트용):
##   --test=prologue|menu|tour|p01|p02    자동으로 걷거나 둘러보며 스크린샷을 찍고 종료
##   --start=prologue|b2|p01|p02          시작 위치 (기본: 프롤로그). b2 = 나선 출구, p01 = 기계식 구역 입구, p02 = P01을 푼 자리
##   --out=<폴더>                         테스트 스크린샷 저장 위치
##   --hint-scale=<배수>                  힌트 시간을 빠르게 (예: 100)
##   --rebake-gi                          간접광을 다시 굽는다
extends Node3D

const PLAYER_SCRIPT := preload("res://core/player/player.gd")
const GI_FLOOR_PATH := "res://levels/ch1_parking/p1_1_floor_voxelgi.res"
const GI_HELIX_PATH := "res://levels/ch1_parking/p1_1_helix_voxelgi.res"
const GI_MECH_PATH := "res://levels/ch1_parking/v2_mech_hall_voxelgi.res"

const W := ParkingFloor.W
const H := ParkingFloor.H
const EAST := HelixRamp.EAST_OFFSET               # 동쪽 나선 조각 원점
const SPAWN := Vector3(44.0, 0.05, 24.0)
const P01_SPAWN := Vector3(-0.8, 0.05, 24.0)

var player: CharacterBody3D
var b2: ParkingFloor
var b1: ParkingFloor            # 입구에서 내려와 닿는 위층
var prologue: Prologue
var prologue_done := false
var east_helix: HelixRamp
var mech: MechParking

var _sfx: AudioStreamPlayer3D
var _debug: Label
var _f2_was := false
var _rng := RandomNumberGenerator.new()
var _city: AudioStreamPlayer
var _far: AudioStreamPlayer3D
var _out_drip_next := 0.0
var traces: Array[String] = []
var menu: Menu

# 테스트용 길 안내
var _route: Array[Vector3] = []
var _route_backward := false
var _route_accept := 1.0         # 길 안내 점에 이만큼 가까워지면 다음 점으로 (좁은 곳에서는 줄인다)


func _ready() -> void:
	_rng.randomize()
	ProcAudio.ensure_reverb_bus("Parking", 0.85, 0.32)
	Settings.refresh_audio()
	var we := LevelEnv.create(self, LevelEnv.GI.BAKED)
	# 그래픽 품질과 밝기는 설정을 따른다
	Settings.apply_environment(we.environment)
	Settings.changed.connect(func() -> void: Settings.apply_environment(we.environment))

	b2 = _make_floor("B2", Vector3.ZERO, "B2", true, true, true, "출구  ↑ B1")
	b1 = _make_floor("B1", HelixRamp.upper_origin(), "B1", true, false, false, "출구  ↑ 1F", HelixRamp.UPPER_ROT_Y, true, 2209)
	b1.set_render_layer(2)
	prologue = Prologue.new()
	prologue.name = "Prologue"
	add_child(prologue)
	prologue.build(b1.to_global(Vector3(W + ParkingFloor.RAMP_LEN, ParkingFloor.RAMP_RISE, ParkingFloor.RAMP_Z)))
	prologue.ticket_taken.connect(_on_ticket)
	_build_half_shutter()
	east_helix = _make_helix("EastHelix", EAST, "east")
	mech = MechParking.new()
	mech.name = "MechParking"
	add_child(mech)
	mech.build_room()
	var hs := LevelEnv.arg_value("--hint-scale")
	if hs != "":
		mech.hint_scale = float(hs)

	_build_gi()
	_build_audio()
	LevelEnv.add_post_fx(self)
	_build_debug()

	var test := LevelEnv.arg_value("--test")
	var start := LevelEnv.arg_value("--start")
	if start == "":
		start = "prologue" if (test in ["", "prologue", "menu"]) else "b2"
	# 메뉴: 그냥 실행하면 메인 화면부터. 뒤로는 시작 지점의 실제 장면이 돌아간다.
	menu = Menu.new()
	add_child(menu)
	menu.start_requested.connect(_on_start)
	var show_menu := test in ["", "menu"] and start == "prologue"
	_spawn_player(test == "" and not show_menu, start)
	if show_menu:
		menu.show_main()
	elif test == "":
		menu.in_game = true
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


## 지상에서 B1로 내려가는 경사로 위쪽의 반쯤 내려온 셔터: 웅크려야 지나간다 (웅크리기를 배운다).
## 처음부터 이렇게 내려와 있는 정상 설비다 (나중에 닫히는 것이 아니다).
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


## 미리 구운 간접광 (VoxelGI). 층, 나선, 기계식 구역을 따로 굽는다.
## SDFGI는 카메라를 따라 계산이 쌓여서 밝기가 출렁이므로 쓰지 않는다.
func _build_gi() -> void:
	# 화면 없이(headless) 실행하면 제대로 구울 수 없으므로 아무것도 하지 않는다
	if DisplayServer.get_name() == "headless":
		return
	_gi_group([b2, b1], Vector3(24.0, 1.3, 16.0), Vector3(48.6, 3.2, 32.6), GI_FLOOR_PATH, 1.2)
	# 나선은 좁고 벽이 밝아서 간접광이 과하게 쌓인다. 층보다 약하게 한다
	_gi_group([east_helix], Vector3(13.0, 3.0, 9.0), Vector3(26.0, 7.0, 26.0), GI_HELIX_PATH, 0.55)
	_gi_group([mech], Vector3(-25.65, 0.05, 21.55), Vector3(51.8, 6.2, 15.8), GI_MECH_PATH, 0.9)


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


func _build_audio() -> void:
	var hum := AudioStreamPlayer.new()
	hum.stream = ProcAudio.hum()
	hum.volume_db = -26.0
	hum.autoplay = true
	add_child(hum)
	_sfx = AudioStreamPlayer3D.new()
	_sfx.bus = "Parking"
	_sfx.unit_size = 10.0
	add_child(_sfx)
	# 바깥 처마 물방울: 크게 울리고 멀리까지 들린다
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
	else:
		prologue_done = true
		prologue.raise_barrier()
		if start == "p01":
			player.position = P01_SPAWN
		elif start == "p02":
			mech.jump_to_p02()
			player.position = Vector3(-23.5, 0.05, 24.0)
		else:
			player.position = SPAWN
		player.rotation.y = PI / 2   # 서쪽(-X)을 본다: 방금 나선을 내려온 모습
	add_child(player)
	mech.player = player


# ================================================================ 진행

## 메인 화면에서 "새로 시작": 메뉴가 걷히고 그 자리에서 바로 움직일 수 있다
func _on_start() -> void:
	player.set("input_enabled", true)
	player.rotation.y = PI
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _on_ticket() -> void:
	traces.append("주차권 (1999.07.14)")
	_sfx.global_position = prologue.ticket.global_position
	_sfx.stream = ProcAudio.paper()
	_sfx.play()
	print("TRACE 1: 주차권")


## 프롤로그: 바깥 소리와 걸음, B2에 들어서면 끝.
func _update_prologue() -> void:
	if player == null:
		return
	var p := player.global_position
	if not prologue_done and _in_floor(b2, p):
		prologue_done = true
		print("prologue: reached B2")
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


func _process(_delta: float) -> void:
	# 메인 화면 뒤 장면: 시선이 아주 천천히 흔들린다
	if menu and menu.is_open() and not menu.in_game and player:
		player.rotation.y = PI + sin(Time.get_ticks_msec() / 1000.0 * 0.12) * 0.06
	_update_prologue()
	_update_floor_lights()
	if Input.is_physical_key_pressed(KEY_F2) and not _f2_was:
		_debug.visible = not _debug.visible
	_f2_was = Input.is_physical_key_pressed(KEY_F2)
	if _debug.visible and player:
		var p := player.global_position
		_debug.text = "barrier:%s  prologue:%s\nP0%d  lift:%d  deck:%d  hint:%d  stall:%.0fs\npos: %.1f, %.1f, %.1f   fps:%d" % [
			prologue.barrier_up, prologue_done, mech.stage, mech.lift.value, mech.deck.value, mech.hint_stage, mech.stall,
			p.x, p.y, p.z, Engine.get_frames_per_second()]


func _physics_process(_delta: float) -> void:
	_follow_route()


## 겹쳐 놓은 두 층 중 플레이어가 없는 층의 조명을 끈다.
## 레이어를 나눠도 볼류메트릭 안개는 그림자가 꺼지는 먼 거리에서 바닥 판을 넘어 빛을 받기 때문이다. 성능에도 이롭다.
var _b1_lights_on := true
var _b2_lights_on := true


func _update_floor_lights() -> void:
	if player == null:
		return
	var p := player.global_position
	var b1_on := p.y > 1.2
	var b2_on := b1.to_local(p).x < 10.0 or p.y < 1.2
	if b1_on != _b1_lights_on:
		_b1_lights_on = b1_on
		for l in b1.lights():
			(l as Light3D).visible = b1_on
	if b2_on != _b2_lights_on:
		_b2_lights_on = b2_on
		for l in b2.lights():
			(l as Light3D).visible = b2_on


# ================================================================ 자동 테스트

## 테스트용: 길 안내 점을 따라 걷게 한다. backward면 길을 등지고 뒷걸음질한다.
func _follow_route() -> void:
	if _route.is_empty() or player == null:
		return
	var to := _route[0] - player.global_position
	to.y = 0.0
	if to.length() < _route_accept:
		_route.remove_at(0)
		if _route.is_empty():
			player.set("auto_move", Vector3.ZERO)
		return
	var yaw := atan2(-to.x, -to.z)
	player.rotation.y = yaw + (PI if _route_backward else 0.0)
	player.set("auto_move", Vector3(0, 0, 1) if _route_backward else Vector3(0, 0, -1))


func _run_test(kind: String) -> void:
	var out := LevelEnv.arg_value("--out")
	if out == "":
		out = ProjectSettings.globalize_path("user://test_p1_1")
	DirAccess.make_dir_recursive_absolute(out)
	await get_tree().create_timer(3.0).timeout
	match kind:
		"tour":
			await _test_tour(out)
		"prologue":
			await _test_prologue(out)
		"menu":
			await _test_menu(out)
		"p01":
			await _test_p01(out)
		"p02":
			await _test_p02(out)
	get_tree().quit()


func _save(path: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)


func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _tour_list() -> Array:
	return [
		["t1_helix_exit_view", Vector3(44.0, 1.6, 24.0), Vector3(-12.0, 0.6, 24.0)],
		["t2_entrance", Vector3(-1.0, 1.6, 26.0), Vector3(-9.0, -0.5, 24.0)],
		["t3_m0_to_hall", Vector3(-22.0, 1.6, 24.6), Vector3(-34.0, 0.0, 24.0)],
		["t4_r_north_to_k", Vector3(-32.5, 1.6, 25.0), Vector3(-32.5, 0.0, 15.0)],
		["t5_k_to_m", Vector3(-31.6, 1.6, 15.4), Vector3(-41.0, 0.3, 15.6)],
		["t6_m_column", Vector3(-40.9, 1.6, 15.0), Vector3(-40.9, 0.3, 25.0)],
		["t7_m_to_exit", Vector3(-40.2, 1.6, 24.6), Vector3(-50.0, 0.8, 24.0)],
		["t8_r_from_m", Vector3(-41.5, 1.6, 24.0), Vector3(-30.0, 0.0, 24.0)],
	]


func _test_tour(out: String) -> void:
	player.set_physics_process(false)
	for s in _tour_list():
		player.global_position = s[1] - Vector3(0, 1.6, 0)
		player.camera.global_position = s[1]
		player.camera.look_at(s[2], Vector3.UP)
		await _wait(1.5)
		await _save(out.path_join(s[0] + ".png"))
		await _wait(2.0)   # 셰이더 준비가 끝난 뒤의 fps
		print("tour ", s[0], "  fps=", Engine.get_frames_per_second())


## 메뉴 화면들을 찍는다: 메인, 설정, 크레딧, 일시정지
func _test_menu(out: String) -> void:
	await _wait(1.5)
	await _save(out.path_join("m1_main.png"))
	menu.call("_open", "settings")
	await _wait(0.6)
	await _save(out.path_join("m2_settings.png"))
	menu.call("_open", "credits")
	await _wait(0.6)
	await _save(out.path_join("m3_credits.png"))
	# 설정이 실제로 적용되는지: 시야각과 감도
	var before: float = player.get("camera").fov
	Settings.set_value("fov", 90.0)
	print("fov setting applied: %.0f -> %.0f" % [before, player.get("camera").fov])
	Settings.set_value("fov", 75.0)
	menu.close()
	menu.in_game = true
	player.set("input_enabled", true)
	await _wait(0.3)
	menu.show_pause()
	await _wait(0.6)
	print("paused while pause menu open: ", get_tree().paused)
	await _save(out.path_join("m4_pause.png"))
	menu.close()
	print("unpaused after close: ", not get_tree().paused)


## 테스트용: 카메라가 이 점을 정확히 보게 한다
func _aim_at(target: Vector3) -> void:
	var cam: Camera3D = player.get("camera")
	var d := target - cam.global_position
	player.rotation.y = atan2(-d.x, -d.z)
	player.call("set_look", atan2(d.y, Vector2(d.x, d.z).length()))


func _walk_to(points: Array[Vector3], timeout_s := 60.0) -> bool:
	_route = points
	var deadline := Time.get_ticks_msec() + int(timeout_s * 1000.0)
	while not _route.is_empty() and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	if not _route.is_empty():
		print("  (route timed out at %s)" % player.global_position)
		_route.clear()
		player.set("auto_move", Vector3.ZERO)
		return false
	return true


func _set_shift(down: bool) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_SHIFT
	ev.keycode = KEY_SHIFT
	ev.pressed = down
	Input.parse_input_event(ev)


## 프롤로그를 처음부터 끝까지 걷는다: 길 건너기 → 인도 턱 → 차단기에 막힘 → 정산소 창문 → 개방 손잡이
## → 높이제한 바 → 셔터 밑 웅크리기 → B1 → 나선 → B2.
func _test_prologue(out: String) -> void:
	var m := prologue.mouth
	var gy := prologue.ground_y
	await _save(out.path_join("p0_start.png"))
	player.rotation.y = 0.0   # 뒤(건너편 아파트)를 본다
	await _wait(1.0)
	await _save(out.path_join("p0_behind.png"))
	player.rotation.y = PI
	# 길을 건너 이쪽 인도로 올라선다 (턱 0.15 m: 저절로 올라가야 한다)
	var pts: Array[Vector3] = [Vector3(m.x - 5.0, gy, m.z - 12.0), Vector3(m.x - 5.0, gy, m.z - 4.6)]
	await _walk_to(pts)
	print("step up onto sidewalk: y=%.2f (인도 높이 %.2f 근처여야 함)" % [player.global_position.y, gy + Prologue.WALK])
	await _save(out.path_join("p0_sidewalk.png"))
	# 차단기가 내려와 있다: 가운데, 오른쪽(정산소 쪽), 왼쪽으로 돌아 들어가 보기 — 모두 막혀야 한다
	var tries := [
		["middle", [Vector3(m.x, gy, m.z - 5.0), Vector3(m.x, gy, m.z - 1.0)]],
		["right", [Vector3(m.x + 4.3, gy, m.z - 5.0), Vector3(m.x + 4.3, gy, m.z - 1.2), Vector3(m.x + 2.0, gy, m.z - 1.0)]],
		["left", [Vector3(m.x - 4.0, gy, m.z - 5.0), Vector3(m.x - 4.0, gy, m.z - 1.2), Vector3(m.x - 2.0, gy, m.z - 1.0)]],
	]
	for t in tries:
		var route: Array[Vector3] = []
		for q in t[1]:
			route.append(q)
		await _walk_to(route, 6.0)
		var z := player.global_position.z - m.z
		print("barrier down, try %s: reached z=%.2f (차단기 선 -3.4보다 바깥이어야 함) %s" % [t[0], z, "OK" if z < -3.3 else "PASSED THROUGH"])
		player.global_position = Vector3(m.x, gy + 0.05, m.z - 5.0)
		await _wait(0.3)
	await _save(out.path_join("p1_barrier_down.png"))
	# 정산소 창문 앞 (차단기 바깥에서)
	player.global_position = Vector3(m.x + 3.1, gy + 0.05, m.z - 3.95)
	await _wait(0.4)
	_aim_at(prologue.booth_window.global_position)
	await _wait(0.4)
	await _save(out.path_join("p1_booth_closed.png"))
	print("open window: ", player.call("try_interact"))
	await _wait(1.0)
	_aim_at(prologue.barrier_lever.global_position)
	await _wait(0.3)
	await _save(out.path_join("p1_booth_open.png"))
	print("pull barrier lever: ", player.call("try_interact"))
	await _wait(2.2)
	print("barrier up: ", prologue.barrier_up)
	_aim_at(prologue.mouth + Vector3(0, 1.5, -3.4))
	await _wait(0.2)
	await _save(out.path_join("p1_barrier_up.png"))
	_aim_at(prologue.ticket.global_position)
	await _wait(0.3)
	print("take ticket (선택): ", player.call("try_interact"), "  traces=", traces)
	player.call("set_look", 0.0)
	# 높이제한 바 밑에서 점프: 머리가 닿으면 바가 흔들린다
	player.global_position = Vector3(m.x, gy + 0.05, m.z - 1.3)
	player.rotation.y = PI
	await _wait(0.3)
	player.set("auto_move", Vector3(0, 0, -1))
	player.call("request_jump")
	await _wait(0.6)
	player.set("auto_move", Vector3.ZERO)
	print("height bar swinging after jump: %s" % prologue.get("_bar_swinging"))
	# 입구로, 셔터 밑은 웅크려서
	pts = [Vector3(m.x, gy, m.z - 0.5)]
	await _walk_to(pts)
	await _save(out.path_join("p2_entrance.png"))
	var shutter_z := b1.to_global(ParkingFloor.tunnel_point(20.5)).z
	_route = [b1.to_global(ParkingFloor.tunnel_point(14.0))]
	await _wait(4.0)
	_route.clear()
	player.set("auto_move", Vector3.ZERO)
	print("standing at shutter: z=%.2f, shutter z=%.2f (서서는 셔터 앞에서 멈춰야 함)" % [player.global_position.z, shutter_z])
	player.set("auto_crouch", true)
	pts = [b1.to_global(ParkingFloor.tunnel_point(14.0))]
	await _walk_to(pts)
	player.set("auto_crouch", false)
	await _wait(0.5)
	# B1을 가로질러 나선으로
	pts = [b1.to_global(Vector3(W - 2.0, 0.0, 24.0)), b1.to_global(Vector3(24.0, 0.0, 24.0))]
	await _walk_to(pts)
	await _save(out.path_join("p3_b1.png"))
	pts = [b1.to_global(Vector3(1.0, 0.0, 24.0))]
	await _walk_to(pts)
	var down: Array[Vector3] = []
	for q in HelixRamp.route_down("east"):
		down.append(EAST + q)
	await _walk_to(down)
	await _wait(0.6)
	player.rotation.y = PI / 2
	player.call("set_look", -0.02)
	await _wait(0.5)
	await _save(out.path_join("p4_b2_first_view.png"))
	print("prologue test end: done=%s barrier_up=%s pos=%s" % [prologue_done, prologue.barrier_up, player.global_position])


## P01: 입구에서 첫 시야 → B를 건너 2호기 조작반 → ▼ 한 번(B·A 모두 반쯤) → ▼ → A를 건너 M0.
## 그 전에: 달려서 피트를 뛰어넘을 수 없는지, 떨어지면 마지막 발판으로 돌아오는지.
func _test_p01(out: String) -> void:
	_route_accept = 0.4
	player.call("set_look", -0.02)
	await _wait(1.0)
	await _save(out.path_join("01_first_view.png"))
	player.global_position = P01_SPAWN
	await _wait(0.5)
	_aim_at(Vector3(-9.0, -0.5, 24.0))
	await _wait(0.4)
	await _save(out.path_join("02_entrance.png"))
	# 피트 A를 R0에서 달려 뛰어넘기 (2호기 = 2라 A는 바닥)
	await _run_jump(MechParking.PIT_A.end.x + 0.2, Vector3(-12.2, 0.05, 24.0))
	var jx := player.global_position.x
	print("run+jump over pit A: x=%.2f -> %s" % [jx, "BLOCKED" if jx > MechParking.PIT_A.position.x else "CROSSED (실패)"])
	player.global_position = Vector3(-3.0, 0.05, 24.0)
	var pts: Array[Vector3] = [Vector3(-13.9, 0.0, 23.4)]
	await _walk_to(pts, 15.0)
	var down := mech.panel_button("2", -1)
	_aim_at(down.global_position)
	await _wait(0.3)
	await _save(out.path_join("03_panel.png"))
	await _press(down)
	print("2호기=%d  B y=%.2f A y=%.2f (둘 다 -1.30)" % [mech.lift_value("2"), mech.pallet_y("B"), mech.pallet_y("A")])
	_aim_at(Vector3(-18.7, -1.3, 24.0))
	await _wait(0.3)
	await _save(out.path_join("04_half_ahead.png"))
	await _press(down)
	print("2호기=%d  B y=%.2f A y=%.2f (B -2.6, A 0)" % [mech.lift_value("2"), mech.pallet_y("B"), mech.pallet_y("A")])
	pts = [Vector3(-23.5, 0.0, 24.0)]
	await _walk_to(pts, 15.0)
	print("P01: stage=%d (2여야 함)" % mech.stage)
	player.rotation.y = PI / 2
	player.call("set_look", -0.1)
	await _wait(0.4)
	await _save(out.path_join("05_m0_hall_view.png"))


## P02: M0에서 시작. 뛰어넘기 시도 → 해법(최소 8번 조작)을 따라가며 상태를 확인 → 출구.
func _test_p02(out: String) -> void:
	_route_accept = 0.35
	mech.jump_to_p02()
	player.global_position = Vector3(-23.5, 0.05, 24.0)
	player.rotation.y = PI / 2
	await _wait(1.0)
	await _save(out.path_join("11_m0_start.png"))
	await _run_jump(MechParking.PIT_SR.end.x - 0.2, Vector3(-22.0, 0.05, 24.0))
	var jx := player.global_position.x
	print("run+jump over pit SR: x=%.2f -> %s" % [jx, "BLOCKED" if jx > MechParking.PIT_SR.position.x else "CROSSED (실패)"])
	var at_m0 := Vector3(-22.9, 0.05, 23.3)
	var at_r := Vector3(-32.5, 0.0, 24.6)
	var at_k := Vector3(-32.5, 0.0, 15.0)
	# 1. M0: 4호기 ▼ (SR 메워짐)
	player.global_position = at_m0
	await _press(mech.panel_button("4", -1))
	_report("1 M0 4호기▼")
	# 2. R: 덮개 닫기 (통로판 내려옴)
	await _go([at_r])
	await _press(mech.handle_interactable(), MechParking.DECK_TIME + 0.3)
	_report("2 R 덮개")
	await _save(out.path_join("12_deck_closed.png"))
	# 3. 덮개 위로 M0: 4호기 ▲
	await _go([Vector3(-23.0, 0.0, 23.3)])
	await _press(mech.panel_button("4", 1))
	_report("3 M0 4호기▲")
	# 4. 덮개 위로 R: 덮개 열기 (통로판 올라감, SR 다시 열림)
	await _go([at_r])
	await _press(mech.handle_interactable(), MechParking.DECK_TIME + 0.3)
	_report("4 R 덮개")
	# 5. RK를 건너 K: 3호기 ▲ (RM 메워짐, RK 내려감)
	await _go([Vector3(-32.5, 0.0, 22.0), at_k])
	player.rotation.y = 0.0
	await _press(mech.panel_button("3", 1))
	_report("5 K 3호기▲")
	await _save(out.path_join("13_k_after.png"))
	# 6. KM을 건너 M, RM을 건너 R: 덮개 닫기
	await _go([Vector3(-40.9, 0.0, 15.6), Vector3(-40.9, 0.0, 24.0), at_r])
	await _press(mech.handle_interactable(), MechParking.DECK_TIME + 0.3)
	_report("6 R 덮개")
	# 7. 덮개 위로 M0: 4호기 ▼ (ME 메워짐)
	await _go([Vector3(-23.0, 0.0, 23.3)])
	await _press(mech.panel_button("4", -1))
	_report("7 M0 4호기▼")
	# 점유 보류: 덮개 위에 서서 손잡이
	player.global_position = Vector3(-31.0, 0.1, 24.6)
	await _wait(0.3)
	mech.call("_pull_handle")
	await _wait(0.3)
	print("hold while on deck: deck=%d (1 그대로)" % mech.deck.value)
	# 8. R: 덮개 열기 → RM, ME를 건너 E
	await _go([at_r])
	await _press(mech.handle_interactable(), MechParking.DECK_TIME + 0.3)
	_report("8 R 덮개")
	player.rotation.y = PI / 2
	player.call("set_look", -0.05)
	await _wait(0.3)
	await _save(out.path_join("14_r_to_exit.png"))
	await _go([Vector3(-36.7, 0.0, 24.0), Vector3(-45.1, 0.0, 24.0), Vector3(-49.5, 0.0, 24.0)])
	await _wait(0.5)
	print("P02: stage=%d (3이어야 함) pos=%s" % [mech.stage, player.global_position])
	await _wait(2.5)
	await _save(out.path_join("15_end.png"))
	print("fps=%d" % Engine.get_frames_per_second())


func _report(tag: String) -> void:
	print("%s: 3호기=%d 4호기=%d 덮개=%d  pos=(%.1f, %.1f)" % [tag, mech.lift_value("3"), mech.lift_value("4"), mech.deck.value, player.global_position.x, player.global_position.z])


func _go(points: Array) -> void:
	var pts: Array[Vector3] = []
	for q in points:
		pts.append(q)
	var ok := await _walk_to(pts, 25.0)
	if not ok:
		print("  !! 길이 막힘")


func _press(it: Interactable, wait_s := MechParking.LIFT_TIME + 0.3) -> void:
	_aim_at(it.global_position)
	await _wait(0.2)
	var ok: bool = player.call("try_interact")
	if not ok:
		print("  (press failed at %s)" % player.global_position)
	await _wait(wait_s)


## 서쪽(-X)으로 달려가 edge_x에서 뛴다. 떨어지면 복구까지 기다린다.
func _run_jump(edge_x: float, from: Vector3) -> void:
	player.global_position = from
	player.rotation.y = PI / 2
	player.call("set_look", 0.0)
	await _wait(0.4)
	player.set("input_enabled", true)   # 달리기는 Shift 입력이 있어야 한다
	_set_shift(true)
	player.set("auto_move", Vector3(0, 0, -1))
	var deadline := Time.get_ticks_msec() + 5000
	while player.global_position.x > edge_x and Time.get_ticks_msec() < deadline:
		await get_tree().physics_frame
	player.call("request_jump")
	await _wait(1.2)
	player.set("auto_move", Vector3.ZERO)
	_set_shift(false)
	player.set("input_enabled", false)
	await _wait(2.0)
