## 퍼즐 1-1 "끝없는 경사로" (docs/levels/ch1_parking.md).
##
## 규칙 R1: 화살표(아래)를 따라 내려가면 같은 B2가 반복되고, 거슬러 올라가면 B3에 도착한다.
##
## 구성 (모두 같은 모양의 층을 여러 벌 놓는다):
##   F_up   : B2 위층 자리. 동쪽 경사로 위쪽 끝에서만 보인다. 들어갈 수 없다.
##   F0     : 진짜 B2. 플레이어가 돌아다니는 곳.
##   F_down : B2 아래층 자리. 서쪽 경사로 아래쪽 끝에서만 보인다. 들어갈 수 없다.
##   B3     : 정답 경로의 도착지. 멀리 떨어진 곳에 따로 놓는다.
##
## 관문:
##   gate_down (서쪽 경사로 가운데) --정방향(내려감)--> gate_up 자리로: F0 동쪽 경사로로 다시 내려온다 (반복)
##   gate_up   (동쪽 경사로 가운데) --역방향(올라감)--> gate_b3 자리로: B3로 올라간다 (정답)
##
## 실행 인자 (테스트용):
##   --test=down|up|tour|hints   자동으로 걷거나 둘러보며 스크린샷을 찍고 종료
##   --out=<폴더>                테스트 스크린샷 저장 위치
##   --hint-scale=<배수>         힌트 시간을 빠르게 (예: 100)
##   --rebake-gi                 간접광을 다시 굽는다
extends Node3D

const PLAYER_SCRIPT := preload("res://core/player/player.gd")
const GI_PATH := "res://levels/ch1_parking/p1_1_voxelgi.res"

const W := ParkingFloor.W
const H := ParkingFloor.H
const STEP := ParkingFloor.STEP_DOWN
const B3_ORIGIN := Vector3(0.0, 0.0, 60.0)
const GATE_AT := 12.0                         # 관문: 경사로 시작에서 12 m (가운데)
const HINT_TIMES := [420.0, 720.0, 1080.0]    # 7분, 12분, 18분 (GDD 8장)
const SPAWN := Vector3(44.0, 0.05, 24.0)

var player: CharacterBody3D
var f0: ParkingFloor
var b3: ParkingFloor
var gate_down: LoopGate
var gate_up: LoopGate
var gate_b3: LoopGate

var loops := 0
var solved := false
var elapsed := 0.0
var hint_stage := 0
var hint_scale := 1.0

var _stain: Decal
var _b3_shutter: Node3D
var _b3_shutter_body: StaticBody3D
var _b3_shutter_closed := false
var _arrived_b3 := false
var _sign_pending := false
var _drip: AudioStreamPlayer3D
var _drip_next := 0.0
var _sfx: AudioStreamPlayer3D
var _debug: Label
var _hold: FrameHold
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	var hs := LevelEnv.arg_value("--hint-scale")
	if hs != "":
		hint_scale = float(hs)
	ProcAudio.ensure_reverb_bus("Parking", 0.85, 0.32)
	LevelEnv.create(self, LevelEnv.GI.BAKED)

	_make_floor("F_up", -STEP, "B2")
	f0 = _make_floor("F0", Vector3.ZERO, "B2")
	_make_floor("F_down", STEP, "B2", false)
	b3 = _make_floor("B3", B3_ORIGIN, "B3", true, false, "출구  ↑ B2")
	var b3_low := ParkingFloor.new()
	b3_low.name = "B3_LowerTunnel"
	b3_low.position = B3_ORIGIN + STEP
	add_child(b3_low)
	b3_low.build_tunnel_only(b3_low.position)

	_build_caps(b3_low)
	_build_shutters(b3_low)
	_build_gates(b3_low)
	_build_gi([get_node("F_up"), f0, get_node("F_down"), b3, b3_low])
	_build_stain()
	_build_audio()
	LevelEnv.add_post_fx(self)
	_build_debug()

	_hold = FrameHold.new()
	add_child(_hold)
	for g: LoopGate in [gate_down, gate_up]:
		g.crossed.connect(func(_f: bool, tp: bool) -> void:
			if tp:
				_hold.hold(1))
	var test := LevelEnv.arg_value("--test")
	_spawn_player(test == "")
	if test != "":
		_run_test(test)


# ================================================================ 만들기

func _make_floor(node_name: String, origin: Vector3, label: String, west := true, cup := true, sign := "출구  ↑ B1") -> ParkingFloor:
	var f := ParkingFloor.new()
	f.name = node_name
	f.floor_name = label
	f.sign_text = sign
	f.west_opening = west
	f.with_cup = cup
	f.position = origin
	add_child(f)
	f.build(origin)
	return f


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


func _build_caps(b3_low: ParkingFloor) -> void:
	# 위층 자리의 경사로 위쪽 끝: 아무 데도 이어지지 않으니 막는다 (보이지 않는 곳)
	var up_origin := -STEP
	_cap(up_origin, ParkingFloor.tunnel_point(ParkingFloor.RAMP_LEN) + Vector3(0.15, 1.35, 0), Vector3(0.3, 2.7, 6.6))
	# B3 아래 터널의 아래쪽 끝
	_cap(b3_low.position, ParkingFloor.tunnel_point(0.0) + Vector3(-0.15, 1.35, 0), Vector3(0.3, 2.7, 6.6))


func _shutter(at: Vector3) -> Array:
	var s: Node3D = (load(ParkingFloor.KIT + "fire_shutter.glb") as PackedScene).instantiate()
	s.position = at
	add_child(s)
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.2, 2.7, 6.0)
	cs.shape = shape
	cs.position = Vector3(0, 1.35, 0)
	body.position = at
	body.add_child(cs)
	add_child(body)
	return [s, body]


func _build_shutters(b3_low: ParkingFloor) -> void:
	# B3의 위로 가는 경사로는 처음부터 닫혀 있다
	_shutter(B3_ORIGIN + ParkingFloor.tunnel_point(1.0))
	# B3로 올라온 경사로: 플레이어가 지나가고 등을 돌린 사이 내려온다 (1-2 도입)
	var pair := _shutter(b3_low.position + ParkingFloor.tunnel_point(5.0))
	_b3_shutter = pair[0]
	_b3_shutter_body = pair[1]
	_b3_shutter.visible = false
	_b3_shutter_body.process_mode = Node.PROCESS_MODE_DISABLED


func _gate(node_name: String, floor_origin: Vector3) -> LoopGate:
	var g := LoopGate.new()
	g.name = node_name
	g.position = floor_origin + ParkingFloor.tunnel_point(GATE_AT) + Vector3(0, 1.0, 0)
	g.rotation.y = PI / 2   # 관문의 -Z(정방향) = 월드 -X = 경사로를 내려가는 쪽
	add_child(g)
	return g


func _build_gates(b3_low: ParkingFloor) -> void:
	gate_down = _gate("GateDown", STEP)          # F0 서쪽 경사로 = F_down의 동쪽 터널
	gate_up = _gate("GateUp", Vector3.ZERO)       # F0 동쪽 경사로
	gate_b3 = _gate("GateB3", b3_low.position)    # B3로 올라가는 경사로
	gate_down.forward_target = gate_up
	gate_up.reverse_target = gate_b3
	gate_down.crossed.connect(_on_gate_down)
	gate_up.crossed.connect(_on_gate_up)


## 미리 구운 간접광 (VoxelGI). 모든 층이 같은 모양이므로 한 번 구운 결과를 나눠 쓴다.
## SDFGI는 카메라를 따라 계산이 쌓여서, 순간이동 직후 밝기가 출렁이므로 여기서는 쓰지 않는다.
func _build_gi(floors: Array) -> void:
	var data: VoxelGIData = null
	if FileAccess.file_exists(GI_PATH) and LevelEnv.arg_value("--rebake-gi") == "":
		data = load(GI_PATH)
	var first: VoxelGI = null
	for f: Node3D in floors:
		var v := VoxelGI.new()
		v.name = "GI"
		v.subdiv = VoxelGI.SUBDIV_256
		v.size = Vector3(72.0, 6.4, 33.0)
		v.position = Vector3(36.0, 2.7, 16.0)
		f.add_child(v)
		if first == null:
			first = v
	if data == null:
		var t := Time.get_ticks_msec()
		var f0_gi: VoxelGI = f0.get_node("GI")
		f0_gi.bake(self, false)
		data = f0_gi.data
		data.interior = true
		data.energy = 1.2
		data.propagation = 0.65
		data.use_two_bounces = true
		ResourceSaver.save(data, GI_PATH)
		print("baked VoxelGI in %d ms" % (Time.get_ticks_msec() - t))
	for f: Node3D in floors:
		(f.get_node("GI") as VoxelGI).data = data


func _build_stain() -> void:
	_stain = Decal.new()
	_stain.texture_albedo = ParkingMats.tex("oil_stain_b")
	_stain.modulate = Color(0.75, 0.55, 0.35, 0.9)
	_stain.size = Vector3(0.3, 0.3, 0.3)
	_stain.position = Vector3(2.45, 0.0, 22.05)
	_stain.visible = false
	f0.add_child(_stain)


func _build_audio() -> void:
	var hum := AudioStreamPlayer.new()
	hum.stream = ProcAudio.hum()
	hum.volume_db = -26.0
	hum.autoplay = true
	add_child(hum)
	_drip = AudioStreamPlayer3D.new()
	_drip.bus = "Parking"
	_drip.unit_size = 6.0
	_drip.position = ParkingFloor.tunnel_point(17.0) + Vector3(0, 2.3, 1.5)
	f0.add_child(_drip)
	_sfx = AudioStreamPlayer3D.new()
	_sfx.bus = "Parking"
	_sfx.unit_size = 10.0
	add_child(_sfx)


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


func _spawn_player(interactive: bool) -> void:
	player = CharacterBody3D.new()
	player.set_script(PLAYER_SCRIPT)
	player.name = "Player"
	player.set("sfx_bus", "Parking")
	player.set("input_enabled", interactive)
	player.position = SPAWN
	player.rotation.y = PI / 2   # 서쪽(-X)을 본다: 방금 동쪽 경사로로 내려온 모습
	add_child(player)
	for g in [gate_down, gate_up, gate_b3]:
		g.player = player


# ================================================================ 진행

func _on_gate_down(forward: bool, teleported: bool) -> void:
	if forward and teleported:
		loops += 1
		if loops >= 3:
			# 반복할 때마다 커피컵에서 흘러나온 얼룩이 넓어진다 (반복 횟수의 표시)
			var s := minf(0.35 + 0.22 * (loops - 2), 1.5)
			_stain.size = Vector3(s, 0.3, s)
			_stain.visible = true
		print("loop ", loops)


func _on_gate_up(forward: bool, teleported: bool) -> void:
	if not forward and teleported:
		_arrived_b3 = true
		print("went up -> B3 ramp")


func _process(delta: float) -> void:
	if not solved:
		elapsed += delta * hint_scale
		while hint_stage < HINT_TIMES.size() and elapsed >= HINT_TIMES[hint_stage]:
			hint_stage += 1
			_apply_hint(hint_stage)
	_update_sign_hint()
	_update_drip()
	_update_b3_shutter()
	_check_solved()
	if Input.is_physical_key_pressed(KEY_F2) and not _f2_was:
		_debug.visible = not _debug.visible
	_f2_was = Input.is_physical_key_pressed(KEY_F2)
	if _debug.visible and player:
		var p := player.global_position
		_debug.text = "1-1  loops:%d  hint:%d  t:%.0fs  solved:%s\npos: %.1f, %.1f, %.1f   fps:%d" % [loops, hint_stage, elapsed, solved, p.x, p.y, p.z, Engine.get_frames_per_second()]

var _f2_was := false


func _apply_hint(stage: int) -> void:
	print("hint stage ", stage)
	match stage:
		1:
			# ① 위로 가는 경사로 입구의 형광등이 깜빡이기 시작한다
			for x in [46.0, 42.0, 38.0]:
				f0.make_fixture_flicker(Vector3(x, H, 24.0))
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
	var label := f0.hanging_sign_label
	var cam: Camera3D = player.get("camera")
	if cam and not cam.is_position_in_frustum(label.global_position):
		label.text = "↑  B3"
		label.modulate = Color(1.0, 1.0, 0.92)
		_sign_pending = false
		_sfx.global_position = label.global_position
		_sfx.stream = ProcAudio.click()
		_sfx.play()


func _update_b3_shutter() -> void:
	if _b3_shutter_closed or not _arrived_b3 or player == null:
		return
	var cam: Camera3D = player.get("camera")
	if cam == null:
		return
	# 플레이어가 셔터 위치를 지나 올라갔고, 셔터 자리가 화면에 없을 때 내려온다
	var base := _b3_shutter.global_position
	if player.global_position.x < base.x + 2.0:
		return
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


func _check_solved() -> void:
	if solved or player == null:
		return
	var p := player.global_position - B3_ORIGIN
	if p.y > -0.3 and p.x > 0.0 and p.x < W and p.z > 0.0 and p.z < ParkingFloor.D:
		solved = true
		print("PUZZLE 1-1 SOLVED  loops=%d  time=%.0fs  hint=%d" % [loops, elapsed / hint_scale, hint_stage])


# ================================================================ 자동 테스트

func _run_test(kind: String) -> void:
	var out := LevelEnv.arg_value("--out")
	if out == "":
		out = ProjectSettings.globalize_path("user://test_p1_1")
	DirAccess.make_dir_recursive_absolute(out)
	await get_tree().create_timer(3.0).timeout
	match kind:
		"down":
			await _test_walk(out, "down", Vector3(8.0, 0.05, 24.0), PI / 2, gate_down, 26.0)
		"up":
			await _test_walk(out, "up", ParkingFloor.tunnel_point(8.0) + Vector3(0, 0.05, 0), -PI / 2, gate_up, 14.0)
			# 도착 후 뒤를 돌아본다: 셔터가 내려와 있어야 한다
			player.rotation.y += PI
			await get_tree().create_timer(1.0).timeout
			await _save(out.path_join("up_look_back.png"))
			print("shutter closed: ", _b3_shutter_closed, "  solved: ", solved)
		"tour":
			await _test_tour(out)
		"hints":
			await _test_hints(out)
	get_tree().quit()


## 플레이어를 자동으로 걷게 해서 관문을 지나게 하고, 순간이동 전후 화면을 비교한다.
func _test_walk(out: String, tag: String, start: Vector3, yaw: float, gate: LoopGate, walk_after: float) -> void:
	player.global_position = start
	player.rotation.y = yaw
	player.call("set_look", -0.05)
	await get_tree().create_timer(1.5).timeout
	var state := {"hit": false}
	var on_cross := func(_f: bool, tp: bool) -> void:
		if tp:
			state["hit"] = true
	gate.crossed.connect(on_cross)
	player.set("auto_move", Vector3(0, 0, -1))
	# 순간이동이 일어난 프레임을 찾아, 직전 화면(before)과 직후 화면(after_N)을 저장한다.
	# 비교 기준: 순간이동 없이 한 프레임 걸었을 때의 차이(baseline)와 비슷하면 이음새가 안 보이는 것.
	var prev: Image = null
	var prev2: Image = null
	var frames_after := -1
	var deadline := Time.get_ticks_msec() + 15000
	while Time.get_ticks_msec() < deadline:
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		if frames_after < 0 and state["hit"] and prev != null:
			frames_after = 1
			prev.save_png(out.path_join("%s_before.png" % tag))
			img.save_png(out.path_join("%s_after_01.png" % tag))
			print("%s: baseline=%.4f  teleport=%.4f" % [tag, _diff(prev2, prev), _diff(prev, img)])
		elif frames_after >= 1:
			frames_after += 1
			if frames_after in [2, 10, 30]:
				img.save_png(out.path_join("%s_after_%02d.png" % [tag, frames_after]))
			if frames_after == 2:
				print("%s: before vs after_02 (첫 실제 화면) = %.4f" % [tag, _diff(prev, img)])
			if frames_after == 10:
				print("%s: before vs after_10 = %.4f" % [tag, _diff(prev, img)])
			if frames_after >= 30:
				break
		prev2 = prev
		prev = img
	await get_tree().create_timer(walk_after / 3.2).timeout
	player.set("auto_move", Vector3.ZERO)
	await _save(out.path_join("%s_end.png" % tag))
	var p := player.global_position
	print("%s end pos: %.1f, %.1f, %.1f  loops=%d solved=%s" % [tag, p.x, p.y, p.z, loops, solved])


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


const TOUR := [
	["t1_cup", Vector3(5.5, 1.6, 20.0), Vector3(1.0, 0.3, 23.0)],
	["t2_down_ramp", Vector3(4.0, 1.6, 24.0), Vector3(-20.0, -2.0, 24.0)],
	["t3_in_down_ramp", Vector3(-6.0, 0.95, 24.0), Vector3(-30.0, -2.4, 24.0)],
	["t4_look_up_east", Vector3(52.0, 2.1, 24.0), Vector3(75.0, 4.2, 24.0)],
	["t5_b3_floor", B3_ORIGIN + Vector3(4.0, 1.6, 24.0), B3_ORIGIN + Vector3(40.0, 1.2, 20.0)],
]


func _test_tour(out: String) -> void:
	player.set_physics_process(false)
	for s in TOUR:
		player.global_position = s[1] - Vector3(0, 1.6, 0)
		player.camera.global_position = s[1]
		player.camera.look_at(s[2], Vector3.UP)
		await get_tree().create_timer(1.5).timeout
		await _save(out.path_join(s[0] + ".png"))
		print("tour ", s[0], "  fps=", Engine.get_frames_per_second())


func _test_hints(out: String) -> void:
	hint_scale = 300.0
	player.global_position = Vector3(40.0, 0.05, 23.0)
	player.rotation.y = PI / 2
	await get_tree().create_timer(5.0).timeout
	player.rotation.y = -PI / 2 - 0.15   # 경사로 쪽을 본다
	await get_tree().create_timer(1.0).timeout
	await _save(out.path_join("hints_sign.png"))
	print("hint stage: ", hint_stage, "  sign: ", f0.hanging_sign_label.text)
