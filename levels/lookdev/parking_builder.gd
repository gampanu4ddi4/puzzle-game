## 룩 테스트: 지하 주차장 B2 한 층.
## Blender에서 만든 모듈 부품(assets/models/parking)을 격자에 맞춰 조립한다.
## 편집기에서도 보이도록 @tool로 실행된다 (편집기에서는 플레이어와 화면 효과를 빼고 만든다).
##
## 실행 인자:
##   -- --shots=<폴더>   정해진 시점에서 스크린샷을 찍고 종료한다.
@tool
extends Node3D

const KIT := "res://assets/models/parking/"
const TEX := "res://assets/textures/parking/"
const SHADER_CONCRETE := preload("res://assets/shaders/concrete_triplanar.gdshader")
const SHADER_PAINT := preload("res://assets/shaders/floor_paint.gdshader")
const SHADER_POST := preload("res://assets/shaders/post_fx.gdshader")
const PLAYER_SCRIPT := preload("res://core/player/player.gd")

# 층 규격 (docs/levels/ch1_parking.md 공통 규격)
const W := 48.0                 # X 방향 길이
const D := 32.0                 # Z 방향 길이
const H := 2.7                  # 천장 높이 (보 아래는 2.25 m)
const PILLAR_X := [8.0, 16.0, 24.0, 32.0, 40.0]
const PILLAR_Z := [5.0, 16.0, 27.0]
const BAY_X := [8.0, 16.0, 24.0, 32.0]           # 주차 칸이 있는 구간의 시작 X (각 8 m)
const STALL_ROWS := [[0.0, 5.0], [11.0, 16.0], [16.0, 21.0], [27.0, 32.0]]
const RAMP_Z := 24.0            # 동쪽 벽의 경사로 입구 중심 (폭 6 m)
const DOOR_Z := 13.0            # 서쪽 벽의 비상계단 문 (z=16 보 아래는 피한다)
const LIGHT_COLOR := Color("dcebd8")
const FLOOR_NAME := "B2"

var _rng := RandomNumberGenerator.new()
var _mats := {}
var _kit_cache := {}
var _flicker: Array[Dictionary] = []
var _font: SystemFont


func _ready() -> void:
	for c in get_children():
		c.free()
	_rng.seed = 2209
	_font = SystemFont.new()
	_font.font_names = PackedStringArray(["Malgun Gothic", "Noto Sans KR", "Arial"])
	_font.font_weight = 700

	_make_materials()
	_build_environment()
	_build_shell()
	_build_structure()
	_build_ramp()
	_build_markings()
	_build_lights()
	_build_props()
	_build_signs()
	_build_decals()

	if Engine.is_editor_hint():
		return
	_build_post_fx()
	var shots := _arg_value("--shots")
	if shots != "":
		_run_shots(shots)
	else:
		_spawn_player()


# ================================================================ 재질

func _tex(name: String) -> Texture2D:
	return load(TEX + name + ".png")


func _concrete(prefix: String, tile: float) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = SHADER_CONCRETE
	m.set_shader_parameter("albedo_tex", _tex(prefix + "_albedo"))
	m.set_shader_parameter("normal_tex", _tex(prefix + "_normal"))
	m.set_shader_parameter("rough_tex", _tex(prefix + "_rough"))
	m.set_shader_parameter("noise_tex", _tex("noise_pack"))
	m.set_shader_parameter("tile_meters", tile)
	return m


func _paint(color: Color, wear: float) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = SHADER_PAINT
	m.set_shader_parameter("paint_color", color)
	m.set_shader_parameter("noise_tex", _tex("noise_pack"))
	m.set_shader_parameter("wear", wear)
	return m


func _make_materials() -> void:
	var floor_m := _concrete("floor", 4.0)
	floor_m.set_shader_parameter("puddle_amount", 0.2)
	floor_m.set_shader_parameter("macro_variation", 0.09)
	floor_m.set_shader_parameter("joint_spacing", 4.0)
	_mats["floor"] = floor_m

	var ramp_m := _concrete("floor", 4.0)
	ramp_m.set_shader_parameter("macro_variation", 0.1)
	ramp_m.set_shader_parameter("tint", Color(0.92, 0.92, 0.92))
	_mats["ramp_floor"] = ramp_m

	var wall_m := _concrete("wall", 2.0)
	wall_m.set_shader_parameter("band_height", 1.0)
	wall_m.set_shader_parameter("band_color", Color("4E7A5B"))
	wall_m.set_shader_parameter("band_line_color", Color("E3C23B"))
	wall_m.set_shader_parameter("grime_strength", 0.45)
	wall_m.set_shader_parameter("streak_strength", 0.22)
	_mats["concrete_paint"] = wall_m

	var ramp_wall := wall_m.duplicate() as ShaderMaterial
	ramp_wall.set_shader_parameter("floor_slope", 3.0 / 24.0)
	ramp_wall.set_shader_parameter("slope_start_x", W)
	_mats["ramp_wall"] = ramp_wall

	var ceil_m := _concrete("ceiling", 2.4)
	ceil_m.set_shader_parameter("macro_variation", 0.18)
	ceil_m.set_shader_parameter("tint", Color(0.82, 0.83, 0.82))
	_mats["concrete_ceiling"] = ceil_m

	_mats["paint_white"] = _paint(Color("E8E8E2"), 0.32)
	_mats["paint_yellow"] = _paint(Color("E3C23B"), 0.28)

	var tube_on := StandardMaterial3D.new()
	tube_on.albedo_color = Color("F2F7F0")
	tube_on.emission_enabled = true
	tube_on.emission = LIGHT_COLOR
	tube_on.emission_energy_multiplier = 6.0
	_mats["tube_on"] = tube_on

	var tube_off := StandardMaterial3D.new()
	tube_off.albedo_color = Color("B9BDB8")
	tube_off.roughness = 0.35
	_mats["tube_off"] = tube_off

	var plate := StandardMaterial3D.new()
	plate.albedo_color = Color("E3C23B")
	plate.roughness = 0.6
	_mats["plate_yellow"] = plate


## glb에서 들어온 재질 중 이름이 일치하는 것을 셰이더 재질로 바꿔 끼운다.
func _apply_mats(node: Node, overrides: Dictionary = {}) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		for i in mi.mesh.get_surface_count():
			var src := mi.mesh.surface_get_material(i)
			if src == null:
				continue
			var key := src.resource_name
			if overrides.has(key):
				mi.set_surface_override_material(i, overrides[key])
			elif _mats.has(key):
				mi.set_surface_override_material(i, _mats[key])
	for c in node.get_children():
		_apply_mats(c, overrides)


# ================================================================ 배치 도우미

func _kit(name: String) -> Node3D:
	if not _kit_cache.has(name):
		_kit_cache[name] = load(KIT + name + ".glb")
	return (_kit_cache[name] as PackedScene).instantiate()


func _place(name: String, pos: Vector3, yaw := 0.0, parent: Node = self, overrides := {}) -> Node3D:
	var n := _kit(name)
	n.position = pos
	n.rotation.y = yaw
	parent.add_child(n)
	_apply_mats(n, overrides)
	return n


func _group(name: String) -> Node3D:
	var g := Node3D.new()
	g.name = name
	add_child(g)
	return g


func _box(parent: Node, size: Vector3, center: Vector3, mat: Material, collide := true) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = center
	parent.add_child(mi)
	if collide:
		_collider(parent, size, center)


func _collider(parent: Node, size: Vector3, center: Vector3) -> void:
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	body.position = center
	body.add_child(cs)
	parent.add_child(body)


func _flat(parent: Node, size: Vector2, center: Vector3, mat: Material, yaw := 0.0) -> void:
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = size
	mi.mesh = pm
	mi.material_override = mat
	mi.position = center
	mi.rotation.y = yaw
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)


func _label(parent: Node, text: String, pos: Vector3, yaw: float, px_size: float, color: Color, font_size := 128) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font = _font
	l.font_size = font_size
	l.pixel_size = px_size
	l.modulate = color
	l.outline_size = 0
	l.shaded = true
	l.double_sided = false
	l.alpha_cut = Label3D.ALPHA_CUT_OPAQUE_PREPASS
	l.position = pos
	l.rotation.y = yaw
	parent.add_child(l)
	return l


# ================================================================ 환경

func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color.BLACK
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("1d221f")
	env.ambient_light_energy = 0.35

	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = 1.05

	env.sdfgi_enabled = true
	env.sdfgi_use_occlusion = true
	env.sdfgi_min_cell_size = 0.12
	env.sdfgi_cascades = 4
	env.sdfgi_energy = 1.1
	env.sdfgi_bounce_feedback = 0.6

	env.ssao_enabled = true
	env.ssao_radius = 1.2
	env.ssao_intensity = 2.2
	env.ssil_enabled = true
	env.ssr_enabled = true
	env.ssr_max_steps = 96
	env.ssr_fade_in = 0.1
	env.ssr_fade_out = 1.5

	env.glow_enabled = true
	env.glow_intensity = 0.55
	env.glow_bloom = 0.04
	env.glow_hdr_threshold = 1.2

	env.fog_enabled = true
	env.fog_light_color = Color("252b27")
	env.fog_density = 0.012

	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.018
	env.volumetric_fog_albedo = Color("c9d4cb")
	env.volumetric_fog_length = 48.0
	env.volumetric_fog_gi_inject = 0.4

	env.adjustment_enabled = true
	env.adjustment_contrast = 1.04
	env.adjustment_saturation = 0.82

	var we := WorldEnvironment.new()
	we.name = "WorldEnvironment"
	we.environment = env
	add_child(we)


func _build_post_fx() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 10
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m := ShaderMaterial.new()
	m.shader = SHADER_POST
	rect.material = m
	layer.add_child(rect)
	add_child(layer)


# ================================================================ 바닥, 천장, 벽

func _build_shell() -> void:
	var g := _group("Shell")
	_box(g, Vector3(W, 0.3, D), Vector3(W / 2, -0.15, D / 2), _mats["floor"])
	_box(g, Vector3(W + 0.6, 0.3, D + 0.6), Vector3(W / 2, H + 0.15, D / 2), _mats["concrete_ceiling"])
	var wall: Material = _mats["concrete_paint"]
	_box(g, Vector3(W + 0.6, H, 0.3), Vector3(W / 2, H / 2, -0.15), wall)                  # 북
	_box(g, Vector3(W + 0.6, H, 0.3), Vector3(W / 2, H / 2, D + 0.15), wall)               # 남
	_box(g, Vector3(0.3, H, D), Vector3(-0.15, H / 2, D / 2), wall)                        # 서
	var r0 := RAMP_Z - 3.3
	var r1 := RAMP_Z + 3.3
	_box(g, Vector3(0.3, H, r0), Vector3(W + 0.15, H / 2, r0 / 2), wall)                   # 동 (경사로 북쪽)
	_box(g, Vector3(0.3, H, D - r1), Vector3(W + 0.15, H / 2, (r1 + D) / 2), wall)         # 동 (경사로 남쪽)


func _build_structure() -> void:
	var g := _group("Structure")
	for x in PILLAR_X:
		for z in PILLAR_Z:
			_place("pillar", Vector3(x, 0, z), 0.0, g)
			_collider(g, Vector3(0.6, H, 0.6), Vector3(x, H / 2, z))
	# 보: 기둥 줄을 따라 X 방향, 기둥 열을 따라 Z 방향
	for z in PILLAR_Z:
		for i in 6:
			_place("beam", Vector3(4.0 + 8.0 * i, H, z), 0.0, g)
	for x in PILLAR_X:
		for j in 4:
			_place("beam", Vector3(x, H, 4.0 + 8.0 * j), PI / 2, g)
	# 배관: 통로 위를 따라
	for i in 6:
		var x := 4.0 + 8.0 * i
		_place("pipe_gray", Vector3(x, 2.12, 6.0), 0.0, g)
		_place("pipe_gray", Vector3(x, 2.12, 26.0), 0.0, g)
		_place("pipe_sprinkler", Vector3(x, 2.58, 9.5), 0.0, g)
		_place("pipe_sprinkler", Vector3(x, 2.58, 22.5), 0.0, g)


func _build_ramp() -> void:
	var g := _group("Ramp")
	var ramp := _place("ramp_tunnel", Vector3(W, 0, RAMP_Z), 0.0, g, {"concrete_paint": _mats["ramp_wall"]})
	if not Engine.is_editor_hint():
		for mi in ramp.find_children("*", "MeshInstance3D", true, false):
			(mi as MeshInstance3D).create_trimesh_collision()


# ================================================================ 바닥 표시

func _build_markings() -> void:
	var g := _group("Markings")
	var white: Material = _mats["paint_white"]
	var yellow: Material = _mats["paint_yellow"]
	for row in STALL_ROWS:
		var z0: float = row[0]
		var z1: float = row[1]
		var zc := (z0 + z1) / 2.0
		for bx in BAY_X:
			for k in 4:
				_flat(g, Vector2(0.1, 5.0), Vector3(bx + 0.25 + 2.5 * k, 0.004, zc), white)
			for k in 3:
				var cx: float = bx + 1.5 + 2.5 * k
				# 주차 턱: 칸 안쪽 끝(벽이나 맞은편 칸 쪽)에서 0.7 m
				var back := z0 + 0.7 if (z0 == 0.0 or z0 == 16.0) else z1 - 0.7
				if _rng.randf() > 0.08:
					var ws := _place("wheel_stop", Vector3(cx, 0, back), 0.0, g)
					ws.rotation.y = _rng.randf_range(-0.04, 0.04)
	# 등을 맞댄 주차 칸 사이 경계선
	_flat(g, Vector2(32.0, 0.1), Vector3(24.0, 0.004, 16.0), white)
	# 통로 가장자리 노란 선
	for z in [5.15, 10.85, 21.15, 26.85]:
		_flat(g, Vector2(32.0, 0.12), Vector3(24.0, 0.004, z), yellow)

	# 일방통행 화살표 (시계 방향 순환: 북쪽 통로 -X, 서쪽 +Z, 남쪽 +X, 동쪽 -Z)
	var arrow_mats := {"paint_white": white}
	for x in [12.0, 20.0, 28.0, 36.0]:
		_place_arrow(g, Vector3(x, 0.005, 8.0), PI, arrow_mats)
		_place_arrow(g, Vector3(x, 0.005, 24.0), 0.0, arrow_mats)
	_place_arrow(g, Vector3(4.0, 0.005, 13.0), -PI / 2, arrow_mats)
	_place_arrow(g, Vector3(4.0, 0.005, 19.0), -PI / 2, arrow_mats)
	_place_arrow(g, Vector3(44.0, 0.005, 19.0), PI / 2, arrow_mats)
	_place_arrow(g, Vector3(44.0, 0.005, 13.0), PI / 2, arrow_mats)

	# 경사로 바닥 화살표: 아래(B2 쪽)를 가리킨다 (1-1의 단서)
	var slope := atan(3.0 / 24.0)
	for x in [6.0, 15.0]:
		var tilt := Node3D.new()
		tilt.position = Vector3(W + x, x * 3.0 / 24.0 + 0.006, RAMP_Z)
		tilt.rotation.z = slope
		g.add_child(tilt)
		_place_arrow(tilt, Vector3.ZERO, PI, arrow_mats)


func _place_arrow(parent: Node, pos: Vector3, yaw: float, overrides: Dictionary) -> void:
	var a := _place("arrow", pos, yaw, parent, overrides)
	a.scale = Vector3(1.1, 1.0, 1.1)
	for mi in a.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


# ================================================================ 조명

func _build_lights() -> void:
	var g := _group("Lights")
	# 통로 위: X 방향으로 4 m 간격 (보와 겹치지 않게 2 m 어긋나게)
	for i in 12:
		var x := 2.0 + 4.0 * i
		_fixture(g, Vector3(x, H, 8.0), 0.0)
		_fixture(g, Vector3(x, H, 24.0), 0.0)
	# 양 끝 회전 통로
	for z in [13.0, 19.0]:
		_fixture(g, Vector3(4.0, H, z), PI / 2)
		_fixture(g, Vector3(44.0, H, z), PI / 2)
	# 주차 칸 위: 구간마다 하나
	for row in STALL_ROWS:
		var zc: float = (row[0] + row[1]) / 2.0
		for bx in BAY_X:
			_fixture(g, Vector3(bx + 4.0, H, zc), 0.0)
	# 경사로 안: 하나는 꺼져 있고 하나는 깜빡인다
	var slope := 3.0 / 24.0
	_fixture(g, Vector3(W + 7.0, H + 7.0 * slope, RAMP_Z), 0.0, "on", slope)
	_fixture(g, Vector3(W + 17.0, H + 17.0 * slope, RAMP_Z), 0.0, "flicker", slope)
	# 경사로 꼭대기(B1 쪽)에서 새어 나오는 희미한 빛: 경사가 읽히게 한다
	var glow := OmniLight3D.new()
	glow.position = Vector3(W + 22.5, 3.0 + 2.2, RAMP_Z)
	glow.light_color = Color("cfdcca")
	glow.light_energy = 0.7
	glow.omni_range = 12.0
	glow.shadow_enabled = true
	g.add_child(glow)


func _fixture(parent: Node, pos: Vector3, yaw: float, state := "", tilt := 0.0) -> void:
	if state == "":
		var r := _rng.randf()
		state = "on" if r < 0.72 else ("off" if r < 0.95 else "flicker")
	var on := state != "off"
	var f := _place("fixture", pos, yaw, parent, {"tube": _mats["tube_on" if on else "tube_off"]})
	f.rotation.z = atan(tilt)
	if not on:
		return
	var light := OmniLight3D.new()
	light.position = pos + Vector3(0, -0.14, 0)
	light.light_color = LIGHT_COLOR
	light.light_energy = 1.35
	light.omni_range = 8.0
	light.omni_attenuation = 1.15
	light.light_size = 0.25
	light.light_specular = 0.6
	light.light_volumetric_fog_energy = 0.6
	light.shadow_enabled = true
	light.shadow_bias = 0.05
	light.shadow_normal_bias = 1.5
	parent.add_child(light)
	if state == "flicker":
		_flicker.append({"light": light, "fixture": f, "next": 0.0, "on": true})


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	var t := Time.get_ticks_msec() / 1000.0
	for fl in _flicker:
		if t < fl["next"]:
			continue
		var on: bool = not fl["on"]
		fl["on"] = on
		# 켜져 있는 시간은 길고, 꺼지는 순간은 짧고 불규칙하다
		fl["next"] = t + (_rng.randf_range(0.4, 3.5) if on else _rng.randf_range(0.03, 0.18))
		(fl["light"] as OmniLight3D).light_energy = 1.35 if on else 0.0
		_apply_mats(fl["fixture"], {"tube": _mats["tube_on" if on else "tube_off"]})


# ================================================================ 소품

func _build_props() -> void:
	var g := _group("Props")
	# 서쪽 벽 비상계단 문과 비상구 표시등
	_place("steel_door", Vector3(0.0, 0, DOOR_Z), PI / 2, g)
	_place("exit_sign", Vector3(0.0, 2.35, DOOR_Z), PI / 2, g)
	var green := OmniLight3D.new()
	green.position = Vector3(0.25, 2.3, DOOR_Z)
	green.light_color = Color("3BD07A")
	green.light_energy = 0.5
	green.omni_range = 3.0
	g.add_child(green)
	# 소화전함
	_place("fire_cabinet", Vector3(20.0, 0.45, 0.0), 0.0, g)
	_place("fire_cabinet", Vector3(28.0, 0.45, D), PI, g)
	_place("fire_cabinet", Vector3(0.0, 0.45, 6.5), PI / 2, g)
	# 경사로 입구의 라바콘
	_place("traffic_cone", Vector3(46.9, 0, 21.5), 0.3, g)
	_place("traffic_cone", Vector3(46.4, 0, 26.6), -0.5, g)
	# 앵커: 쓰러진 커피컵 (1-1의 단서)
	var cup := _place("coffee_cup", Vector3(46.0, 0.044, 22.6), 0.0, g)
	cup.rotation = Vector3(0.0, 0.8, PI / 2)


func _build_signs() -> void:
	var g := _group("Signs")
	var black := Color(0.08, 0.08, 0.07)
	var rows := ["A", "B", "C"]
	for zi in PILLAR_Z.size():
		for xi in PILLAR_X.size():
			var x: float = PILLAR_X[xi]
			var z: float = PILLAR_Z[zi]
			var code := "%s%d" % [rows[zi], xi + 1]
			for side: float in [-1.0, 1.0]:
				var face: float = z + side * 0.3
				_box(g, Vector3(0.46, 0.62, 0.02), Vector3(x, 1.72, face + side * 0.01), _mats["plate_yellow"], false)
				var yaw := 0.0 if side > 0 else PI
				_label(g, FLOOR_NAME, Vector3(x, 1.82, face + side * 0.022), yaw, 0.0016, black, 160)
				_label(g, code, Vector3(x, 1.56, face + side * 0.022), yaw, 0.0011, black, 128)
	# 벽에 크게 칠한 층 번호 (흰 벽 위쪽, 진한 초록 페인트, 보와 겹치지 않는 자리)
	var wall_paint := Color("2E5A40")
	_label(g, FLOOR_NAME, Vector3(W - 0.02, 1.68, 11.0), -PI / 2, 0.0042, wall_paint, 256)
	_label(g, FLOOR_NAME, Vector3(0.02, 1.68, 22.0), PI / 2, 0.0042, wall_paint, 256)
	_label(g, FLOOR_NAME, Vector3(36.0, 1.68, 0.02), 0.0, 0.0042, wall_paint, 256)
	# 경사로 입구 위 안내판
	var sign := _place("hanging_sign", Vector3(W - 1.2, H - 0.45, RAMP_Z), -PI / 2, g)
	sign.rotation.y = PI / 2
	_label(g, "출구  ↑ B1", Vector3(W - 1.2 - 0.03, H - 0.45 - 0.32, RAMP_Z), -PI / 2, 0.0022, Color(0.95, 0.97, 0.95), 120)


func _build_decals() -> void:
	var g := _group("Decals")
	var oils := [_tex("oil_stain_a"), _tex("oil_stain_b")]
	# 주차 칸 가운데 기름 자국
	for row in STALL_ROWS:
		var zc: float = (row[0] + row[1]) / 2.0
		for bx in BAY_X:
			for k in 3:
				if _rng.randf() < 0.55:
					var d := Decal.new()
					d.texture_albedo = oils[_rng.randi() % 2]
					var s := _rng.randf_range(0.8, 1.6)
					d.size = Vector3(s, 0.4, s)
					d.position = Vector3(bx + 1.5 + 2.5 * k + _rng.randf_range(-0.3, 0.3), 0.0, zc + _rng.randf_range(-0.8, 0.8))
					d.rotation.y = _rng.randf() * TAU
					d.modulate = Color(1, 1, 1, _rng.randf_range(0.5, 0.95))
					g.add_child(d)
	# 통로 타이어 자국 (회전 구간에 많다)
	for spec in [[Vector3(6.5, 0, 9.0), 0.6], [Vector3(41.5, 0, 22.5), -0.5], [Vector3(20.0, 0, 24.3), 0.05], [Vector3(30.0, 0, 7.6), 0.0], [Vector3(5.0, 0, 21.5), 2.2]]:
		var d := Decal.new()
		d.texture_albedo = _tex("tire_marks")
		d.size = Vector3(6.0, 0.4, 1.6)
		d.position = spec[0]
		d.rotation.y = spec[1]
		d.modulate = Color(1, 1, 1, 0.8)
		g.add_child(d)
	# 벽의 누수 자국 (천장에서 흘러내림)
	for spec in [[Vector3(13.0, 1.45, 0.0), 0.0], [Vector3(35.0, 1.45, 0.0), 0.0], [Vector3(22.0, 1.45, D), PI], [Vector3(0.0, 1.45, 21.0), PI / 2]]:
		var d := Decal.new()
		d.texture_albedo = _tex("leak_streak")
		d.size = Vector3(1.2, 0.6, 2.5)
		d.position = spec[0]
		d.rotation = Vector3(PI / 2, spec[1], 0)
		d.modulate = Color(1, 1, 1, 0.85)
		g.add_child(d)


# ================================================================ 플레이어와 스크린샷

func _spawn_player() -> void:
	var p := CharacterBody3D.new()
	p.set_script(PLAYER_SCRIPT)
	p.name = "Player"
	p.position = Vector3(3.0, 0.05, 24.0)
	p.rotation.y = -PI / 2
	add_child(p)


func _arg_value(key: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with(key + "="):
			return a.substr(key.length() + 1)
	return ""


## 정해진 시점에서 화면을 찍는다. 이름, 눈 위치, 바라보는 곳.
const SHOTS := [
	["01_aisle_south", Vector3(2.5, 1.6, 24.0), Vector3(46.0, 1.3, 24.0)],
	["02_diagonal", Vector3(6.0, 1.6, 8.5), Vector3(40.0, 1.0, 20.0)],
	["03_ramp", Vector3(38.5, 1.6, 23.2), Vector3(60.0, 2.2, 24.2)],
	["04_exit_door", Vector3(7.0, 1.6, 10.0), Vector3(0.0, 1.4, 13.0)],
	["05_stalls", Vector3(14.0, 1.6, 10.0), Vector3(22.0, 0.6, 2.0)],
	["06_aisle_north", Vector3(46.0, 1.6, 8.0), Vector3(0.0, 1.4, 8.0)],
	["07_wall_b2", Vector3(42.0, 1.6, 14.0), Vector3(48.0, 1.5, 11.0)],
	["08_ramp_inside", Vector3(49.0, 1.7, 23.0), Vector3(62.0, 2.6, 24.0)],
]


func _run_shots(dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	var cam := Camera3D.new()
	cam.fov = 75.0
	cam.near = 0.05
	add_child(cam)
	cam.make_current()
	await get_tree().create_timer(4.0).timeout
	for s in SHOTS:
		cam.position = s[1]
		cam.look_at(s[2], Vector3.UP)
		await get_tree().create_timer(2.5).timeout   # GI와 TAA가 자리 잡을 시간
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		img.save_png(dir.path_join(s[0] + ".png"))
		print("shot ", s[0], "  fps=", Engine.get_frames_per_second())
	get_tree().quit()
