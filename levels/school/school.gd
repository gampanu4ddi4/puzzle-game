## 학교 전체 (5층). 받은 평면도를 바탕으로 school_layout.gd의 데이터로 짓는다 (school_builder.gd).
## 지금은 공간만: 재질·가구는 단순하고, CCTV·괴물은 아직 없다.
##
## 실행 인자 (테스트용):
##   --test=tour|climb      tour = 층마다 정해 둔 자리에서 스크린샷, climb = 정문에서 걸어 들어가 계단으로 5층까지
##   --out=<폴더>           스크린샷 저장 위치
## 조작: WASD, 마우스, Shift 달리기, Ctrl 웅크리기, Space 점프, Esc 일시정지, F2 위치 표시
extends Node3D

const PLAYER_SCRIPT := preload("res://core/player/player.gd")
const SPAWN := Vector3(29.0, 0.05, 66.0)

var builder: SchoolBuilder
var player: CharacterBody3D
var menu: Menu
var _debug: Label
var _f2_was := false
var _route: Array[Vector3] = []
var _route_accept := 0.35


func _ready() -> void:
	Settings.refresh_audio()
	var we := LevelEnv.create(self, LevelEnv.GI.SDFGI)
	var env := we.environment
	# 낮의 학교: 하늘과 해. 안개는 옅게
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color(0.45, 0.6, 0.78)
	sm.sky_horizon_color = Color(0.78, 0.82, 0.86)
	sm.ground_horizon_color = Color(0.7, 0.7, 0.68)
	sky.sky_material = sm
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.6
	env.fog_enabled = false
	env.volumetric_fog_enabled = false
	env.sdfgi_min_cell_size = 0.2
	env.sdfgi_energy = 1.3
	env.tonemap_exposure = 1.1
	Settings.apply_environment(env)
	Settings.changed.connect(func() -> void: Settings.apply_environment(env))
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-38.0, -35.0, 0.0)
	sun.light_energy = 1.4
	sun.light_color = Color(1.0, 0.97, 0.9)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 80.0
	add_child(sun)

	var t := Time.get_ticks_msec()
	builder = SchoolBuilder.new()
	builder.name = "School"
	add_child(builder)
	builder.build()
	print("build time %d ms" % (Time.get_ticks_msec() - t))
	LevelEnv.add_post_fx(self)
	_build_debug()

	var test := LevelEnv.arg_value("--test")
	player = CharacterBody3D.new()
	player.set_script(PLAYER_SCRIPT)
	player.name = "Player"
	player.set("input_enabled", test == "")
	player.position = SPAWN
	player.rotation.y = 0.0     # 북쪽(-Z), 정문을 본다
	add_child(player)
	menu = Menu.new()
	add_child(menu)
	menu.in_game = true
	if test == "":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	else:
		_run_test(test)


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


var _lit_floor := -1


## 지금 층과 위아래 한 층의 조명만 켠다 (보이는 조명 수 제한, 성능)
func _update_lights(p: Vector3) -> void:
	var f := clampi(int(floor((p.y + 0.5) / SchoolLayout.FLOOR_H)), 0, SchoolLayout.FLOORS - 1)
	if f == _lit_floor:
		return
	_lit_floor = f
	for k in SchoolLayout.FLOORS:
		var n := builder.get_node_or_null("Floor%d/Lights" % (k + 1))
		if n:
			(n as Node3D).visible = absi(k - f) <= 1


func _process(_delta: float) -> void:
	if player:
		var cam: Camera3D = player.get("camera")
		_update_lights(cam.global_position if cam else player.global_position)
	if Input.is_physical_key_pressed(KEY_F2) and not _f2_was:
		_debug.visible = not _debug.visible
	_f2_was = Input.is_physical_key_pressed(KEY_F2)
	if _debug.visible and player:
		var p := player.global_position
		var info := builder.room_at(p + Vector3(0, 0.5, 0))
		_debug.text = "%d층  %s\npos: %.1f, %.1f, %.1f   fps:%d" % [info[0], info[1], p.x, p.y, p.z, Engine.get_frames_per_second()]


func _physics_process(_delta: float) -> void:
	if _route.is_empty() or player == null:
		return
	var to := _route[0] - player.global_position
	to.y = 0.0
	if to.length() < _route_accept:
		_route.remove_at(0)
		if _route.is_empty():
			player.set("auto_move", Vector3.ZERO)
		return
	player.rotation.y = atan2(-to.x, -to.z)
	player.set("auto_move", Vector3(0, 0, -1))


# ================================================================ 자동 테스트

func _run_test(kind: String) -> void:
	var out := LevelEnv.arg_value("--out")
	if out == "":
		out = ProjectSettings.globalize_path("user://test_school")
	DirAccess.make_dir_recursive_absolute(out)
	await _wait(4.0)
	match kind:
		"tour":
			await _test_tour(out)
		"climb":
			await _test_climb(out)
		"perf":
			await _test_perf()
	get_tree().quit()


func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _save(path: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)


func _walk(points: Array, timeout_s := 30.0) -> bool:
	_route.clear()
	for q in points:
		_route.append(q)
	var deadline := Time.get_ticks_msec() + int(timeout_s * 1000.0)
	while not _route.is_empty() and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	if not _route.is_empty():
		print("  !! 막힘: %s (다음 점 %s)" % [player.global_position, _route[0]])
		_route.clear()
		player.set("auto_move", Vector3.ZERO)
		return false
	return true


## 층마다 같은 자리 몇 군데 + 바깥
func _tour_list() -> Array:
	var wc := (SchoolLayout.X_WC.x + SchoolLayout.X_WC.y) / 2.0
	var ec := (SchoolLayout.X_EC.x + SchoolLayout.X_EC.y) / 2.0
	var nc := (SchoolLayout.Z_NC.x + SchoolLayout.Z_NC.y) / 2.0
	var out: Array = [
		["00_front", Vector3(20.0, 1.7, 85.0), Vector3(25.0, 6.0, 30.0)],
		["00_aerial", Vector3(-70.0, 55.0, 95.0), Vector3(0.0, 5.0, 25.0)],
		["01_lobby", Vector3(19.0, 1.6, 56.5), Vector3(8.0, 1.2, 56.5)],
		["01_court", Vector3(29.5, 1.6, 56.0), Vector3(29.5, 6.0, 14.0)],
		["01_parking", Vector3(-36.0, 1.6, 12.2), Vector3(-55.0, 1.0, 22.0)],
		["01_north_gap", Vector3(29.0, 1.6, 20.0), Vector3(29.0, 1.6, 0.0)],
	]
	for f in range(1, 6):
		var y := (f - 1) * SchoolLayout.FLOOR_H + 1.6
		out.append(["%d_west_corridor" % f, Vector3(wc, y, 13.0), Vector3(wc, y - 0.2, 58.0)])
		out.append(["%d_north_corridor" % f, Vector3(1.5, y, nc), Vector3(58.0, y - 0.2, nc)])
		out.append(["%d_east_corridor" % f, Vector3(ec, y, 58.0), Vector3(ec, y - 0.2, 13.0)])
	var c27 := builder.room_rect(4, "2-7")
	var y4 := 3 * SchoolLayout.FLOOR_H
	out.append(["4_class_2-7_back", Vector3(c27.end.x - 1.0, y4 + 1.6, c27.end.y - 0.6), Vector3(c27.position.x + 2.0, y4 + 0.6, c27.position.y)])
	out.append(["4_class_2-7_front", Vector3(c27.position.x + 0.8, y4 + 1.6, c27.position.y + 0.6), Vector3(c27.end.x - 2.0, y4 + 0.6, c27.end.y)])
	var md := builder.room_rect(4, "Media Space")
	out.append(["4_media", Vector3(wc - 1.0, y4 + 1.6, md.position.y + 1.0), Vector3(md.end.x, y4 + 0.6, md.end.y - 4.0)])
	out.append(["3_court_view", Vector3(wc, 2 * SchoolLayout.FLOOR_H + 1.6, nc), Vector3(29.5, 3.0, 35.0)])
	out.append(["2_dining", Vector3(-27.0, SchoolLayout.FLOOR_H + 1.6, 10.5), Vector3(-50.0, SchoolLayout.FLOOR_H + 0.8, 20.0)])
	out.append(["3_gym", Vector3(-27.0, 2 * SchoolLayout.FLOOR_H + 1.6, 10.5), Vector3(-50.0, 2 * SchoolLayout.FLOOR_H + 0.8, 20.0)])
	out.append(["4_west_end", Vector3(2.0, 3 * SchoolLayout.FLOOR_H + 1.6, 12.2), Vector3(-30.0, 3 * SchoolLayout.FLOOR_H - 2.0, 12.0)])
	out.append(["1_parking_outside", Vector3(-41.0, 1.7, 34.0), Vector3(-41.0, 1.0, 10.0)])
	return out


func _test_tour(out: String) -> void:
	player.set_physics_process(false)
	for s in _tour_list():
		player.global_position = s[1] - Vector3(0, 1.6, 0)
		var cam: Camera3D = player.get("camera")
		cam.global_position = s[1]
		cam.look_at(s[2], Vector3.UP)
		_update_lights(s[1])
		await _wait(1.2)
		await _save(out.path_join(s[0] + ".png"))
		print("tour %s  fps=%d" % [s[0], Engine.get_frames_per_second()])


## 자리마다 4초 기다린 뒤 프레임 수 (간접광이 자리 잡은 뒤)
func _test_perf() -> void:
	player.set_physics_process(false)
	for s in _tour_list():
		player.global_position = s[1] - Vector3(0, 1.6, 0)
		var cam: Camera3D = player.get("camera")
		cam.global_position = s[1]
		cam.look_at(s[2], Vector3.UP)
		_update_lights(s[1])
		await _wait(4.0)
		print("perf %s  fps=%d  draw_calls=%d" % [s[0], Engine.get_frames_per_second(), RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)])


## 중정 남쪽 → 정문(A동 홀) → 서복도 → 계단 A남 → 5층까지 걸어 올라간다 (계단 이어짐 확인)
func _test_climb(out: String) -> void:
	var door: Vector3 = builder.door_points.get("1:계단 A남", Vector3.ZERO)
	print("stair door (1층 계단 A남): ", door)
	await _walk([Vector3(18.0, 0, 60.0), Vector3(18.0, 0, 56.5), Vector3(13.0, 0, 56.5), Vector3(9.0, 0, 56.5), Vector3(9.0, 0, door.z), Vector3(door.x - 0.6, 0, door.z)])
	await _save(out.path_join("c0_stair_door.png"))
	for f in range(1, 5):
		var ok := await _walk(builder.stair_route("계단 A남", f), 30.0)
		var info := builder.room_at(player.global_position + Vector3(0, 0.5, 0))
		print("climb: after flight pair %d -> %d층 %s  y=%.2f %s" % [f, info[0], info[1], player.global_position.y, "OK" if ok else "STUCK"])
	await _walk([Vector3(9.0, 0, door.z), Vector3(9.0, 0, 35.0)])
	var p := player.global_position
	print("climb end: %s  %s" % [p, builder.room_at(p + Vector3(0, 0.5, 0))])
	await _save(out.path_join("c1_5f_corridor.png"))
	# B동 북쪽 계단으로 내려가 본다 (옆벽 문 계단)
	var door_b: Vector3 = builder.door_points.get("5:계단 B북", Vector3.ZERO)
	print("stair door (5층 계단 B북): ", door_b)
	var sc := (SchoolLayout.Z_SC.x + SchoolLayout.Z_SC.y) / 2.0
	await _walk([Vector3(9.0, 0, sc), Vector3(door_b.x - 1.5, 0, sc), Vector3(door_b.x - 1.5, 0, door_b.z), Vector3(door_b.x + 0.6, 0, door_b.z)], 40.0)
	var down := builder.stair_route("계단 B북", 4)
	down.reverse()
	var ok := await _walk(down, 30.0)
	var info := builder.room_at(player.global_position + Vector3(0, 0.5, 0))
	print("down B북: %d층 %s  y=%.2f %s" % [info[0], info[1], player.global_position.y, "OK" if ok else "STUCK"])
	await _walk([Vector3(door_b.x - 1.5, 0, door_b.z)])
	info = builder.room_at(player.global_position + Vector3(0, 0.5, 0))
	print("out to: %d층 %s" % [info[0], info[1]])
	print("fps=%d" % Engine.get_frames_per_second())
