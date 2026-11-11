## 지하 주차장 한 층 (48 x 32 m) + 위층으로 올라가는 동쪽 경사로 터널.
## 같은 설정(seed)으로 만든 층은 완전히 똑같이 생긴다. R1 반복 공간은 이 성질에 기댄다.
##
## 층 배치 약속 (docs/levels/ch1_parking.md, docs/TECH.md 3.1):
##   한 층 아래 = 원점에서 STEP_DOWN 만큼 옮긴 곳. 그 층의 동쪽 터널이 이 층의 서쪽 입구로 이어진다.
class_name ParkingFloor
extends Node3D

const KIT := "res://assets/models/parking/"

const W := 48.0
const D := 32.0
const H := 2.7
const PILLAR_X := [8.0, 16.0, 24.0, 32.0, 40.0]
const PILLAR_Z := [5.0, 16.0, 27.0]
const BAY_X := [8.0, 16.0, 24.0, 32.0]
const STALL_ROWS := [[0.0, 5.0], [11.0, 16.0], [16.0, 21.0], [27.0, 32.0]]
const RAMP_Z := 24.0
const RAMP_LEN := 24.0
const RAMP_RISE := 3.0
const RAMP_HALF := 3.3          # 터널 바깥 반폭
const DOOR_Z := 13.0
const LIGHT_COLOR := Color("dcebd8")
## 한 층 아래로 내려갈 때의 이동량
const STEP_DOWN := Vector3(-(W + RAMP_LEN), -RAMP_RISE, 0.0)

# ---- 설정 (build 전에 정한다)
var floor_name := "B2"
var sign_text := "출구  ↑ B1"
var light_seed := 2209
var west_opening := true        # 서쪽 벽에 아래층 경사로 입구를 뚫는다
var east_tunnel := true         # 위층으로 가는 경사로 터널을 만든다
var with_cup := true            # 앵커: 서쪽 경사로 입구의 쓰러진 커피컵
var collisions := true

# ---- 만든 뒤 바깥에서 쓰는 것
var hanging_sign_label: Label3D
var cup: Node3D

var _rng := RandomNumberGenerator.new()
var _mats := {}
var _kit_cache := {}
var _font: SystemFont
var _flicker: Array[Dictionary] = []
var _fixtures := {}             # 위치 문자열 → {"node", "light"}


func build(world_origin: Vector3) -> void:
	_rng.seed = light_seed
	_mats = ParkingMats.for_floor(world_origin)
	_font = SystemFont.new()
	_font.font_names = PackedStringArray(["Malgun Gothic", "Noto Sans KR", "Arial"])
	_font.font_weight = 700
	_build_shell()
	_build_structure()
	if east_tunnel:
		_build_tunnel()
	_build_markings()
	_build_lights()
	_build_props()
	_build_signs()
	_build_decals()


# ================================================================ 바깥에서 쓰는 기능

## 터널 하나만 따로 만들 때 (예: 다음 층이 없는데 아래로 가는 터널이 필요한 경우).
func build_tunnel_only(world_origin: Vector3) -> void:
	_rng.seed = light_seed
	_mats = ParkingMats.for_floor(world_origin)
	_build_tunnel()


## 터널 위의 점: 터널 시작에서 x만큼 올라간 바닥 위치 (층 기준 좌표).
static func tunnel_point(x: float) -> Vector3:
	return Vector3(W + x, x * RAMP_RISE / RAMP_LEN, RAMP_Z)


## 이 위치에 있는 형광등을 깜빡이게 만든다 (힌트 연출용).
func make_fixture_flicker(local_pos: Vector3) -> void:
	var key := _key(local_pos)
	if not _fixtures.has(key):
		return
	var f: Dictionary = _fixtures[key]
	if f["light"] == null:
		return
	for fl in _flicker:
		if fl["light"] == f["light"]:
			return
	_flicker.append({"light": f["light"], "fixture": f["node"], "next": 0.0, "on": true})


func _process(_delta: float) -> void:
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


# ================================================================ 도우미

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
	if not collisions:
		return
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	body.position = center
	body.add_child(cs)
	parent.add_child(body)


func _flat(parent: Node, size: Vector2, center: Vector3, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = size
	mi.mesh = pm
	mi.material_override = mat
	mi.position = center
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


func _key(p: Vector3) -> String:
	return "%.1f,%.1f,%.1f" % [p.x, p.y, p.z]


# ================================================================ 바닥, 천장, 벽

func _build_shell() -> void:
	var g := _group("Shell")
	_box(g, Vector3(W, 0.3, D), Vector3(W / 2, -0.15, D / 2), _mats["floor"])
	_box(g, Vector3(W + 0.6, 0.3, D + 0.6), Vector3(W / 2, H + 0.15, D / 2), _mats["concrete_ceiling"])
	var wall: Material = _mats["concrete_paint"]
	_box(g, Vector3(W + 0.6, H, 0.3), Vector3(W / 2, H / 2, -0.15), wall)                   # 북
	_box(g, Vector3(W + 0.6, H, 0.3), Vector3(W / 2, H / 2, D + 0.15), wall)                # 남
	var r0 := RAMP_Z - RAMP_HALF
	var r1 := RAMP_Z + RAMP_HALF
	if west_opening:
		_box(g, Vector3(0.3, H, r0), Vector3(-0.15, H / 2, r0 / 2), wall)                  # 서 (입구 북쪽)
		_box(g, Vector3(0.3, H, D - r1), Vector3(-0.15, H / 2, (r1 + D) / 2), wall)        # 서 (입구 남쪽)
	else:
		_box(g, Vector3(0.3, H, D), Vector3(-0.15, H / 2, D / 2), wall)
	if east_tunnel:
		_box(g, Vector3(0.3, H, r0), Vector3(W + 0.15, H / 2, r0 / 2), wall)               # 동 (경사로 북쪽)
		_box(g, Vector3(0.3, H, D - r1), Vector3(W + 0.15, H / 2, (r1 + D) / 2), wall)     # 동 (경사로 남쪽)
	else:
		_box(g, Vector3(0.3, H, D), Vector3(W + 0.15, H / 2, D / 2), wall)


func _build_structure() -> void:
	var g := _group("Structure")
	for x in PILLAR_X:
		for z in PILLAR_Z:
			_place("pillar", Vector3(x, 0, z), 0.0, g)
			_collider(g, Vector3(0.6, H, 0.6), Vector3(x, H / 2, z))
	for z in PILLAR_Z:
		for i in 6:
			_place("beam", Vector3(4.0 + 8.0 * i, H, z), 0.0, g)
	for x in PILLAR_X:
		for j in 4:
			_place("beam", Vector3(x, H, 4.0 + 8.0 * j), PI / 2, g)
	for i in 6:
		var x := 4.0 + 8.0 * i
		_place("pipe_gray", Vector3(x, 2.12, 6.0), 0.0, g)
		_place("pipe_gray", Vector3(x, 2.12, 26.0), 0.0, g)
		_place("pipe_sprinkler", Vector3(x, 2.58, 9.5), 0.0, g)
		_place("pipe_sprinkler", Vector3(x, 2.58, 22.5), 0.0, g)


func _build_tunnel() -> void:
	var g := _group("EastTunnel")
	var ramp := _place("ramp_tunnel", Vector3(W, 0, RAMP_Z), 0.0, g, {"concrete_paint": _mats["ramp_wall"]})
	if collisions and not Engine.is_editor_hint():
		for mi in ramp.find_children("*", "MeshInstance3D", true, false):
			(mi as MeshInstance3D).create_trimesh_collision()
	# 터널 바닥 화살표: 아래(이 층 쪽)를 가리킨다
	var slope := atan(RAMP_RISE / RAMP_LEN)
	for x in [6.0, 15.0]:
		var tilt := Node3D.new()
		tilt.position = tunnel_point(x) + Vector3(0, 0.006, 0)
		tilt.rotation.z = slope
		g.add_child(tilt)
		_place_arrow(tilt, Vector3.ZERO, PI)
	# 터널 조명: 아래쪽은 켜져 있고, 위쪽은 깜빡인다 (모든 층에서 같은 배치)
	var tan_slope := RAMP_RISE / RAMP_LEN
	_fixture(g, tunnel_point(7.0) + Vector3(0, H, 0), 0.0, "on", tan_slope)
	_fixture(g, tunnel_point(17.0) + Vector3(0, H, 0), 0.0, "flicker", tan_slope)


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
				var back := z0 + 0.7 if (z0 == 0.0 or z0 == 16.0) else z1 - 0.7
				if _rng.randf() > 0.08:
					var ws := _place("wheel_stop", Vector3(cx, 0, back), 0.0, g)
					ws.rotation.y = _rng.randf_range(-0.04, 0.04)
					_collider(g, Vector3(1.6, 0.11, 0.15), Vector3(cx, 0.055, back))
	_flat(g, Vector2(32.0, 0.1), Vector3(24.0, 0.004, 16.0), white)
	for z in [5.15, 10.85, 21.15, 26.85]:
		_flat(g, Vector2(32.0, 0.12), Vector3(24.0, 0.004, z), yellow)
	# 일방통행 화살표 (시계 방향 순환)
	for x in [12.0, 20.0, 28.0, 36.0]:
		_place_arrow(g, Vector3(x, 0.005, 8.0), PI)
		_place_arrow(g, Vector3(x, 0.005, 24.0), 0.0)
	_place_arrow(g, Vector3(4.0, 0.005, 13.0), -PI / 2)
	_place_arrow(g, Vector3(4.0, 0.005, 19.0), -PI / 2)
	_place_arrow(g, Vector3(44.0, 0.005, 19.0), PI / 2)
	_place_arrow(g, Vector3(44.0, 0.005, 13.0), PI / 2)


func _place_arrow(parent: Node, pos: Vector3, yaw: float) -> void:
	var a := _place("arrow", pos, yaw, parent)
	a.scale = Vector3(1.1, 1.0, 1.1)
	for mi in a.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


# ================================================================ 조명

func _build_lights() -> void:
	var g := _group("Lights")
	for i in 12:
		var x := 2.0 + 4.0 * i
		_fixture(g, Vector3(x, H, 8.0), 0.0)
		_fixture(g, Vector3(x, H, 24.0), 0.0)
	for z in [13.0, 19.0]:
		_fixture(g, Vector3(4.0, H, z), PI / 2)
		_fixture(g, Vector3(44.0, H, z), PI / 2)
	for row in STALL_ROWS:
		var zc: float = (row[0] + row[1]) / 2.0
		for bx in BAY_X:
			_fixture(g, Vector3(bx + 4.0, H, zc), 0.0)


func _fixture(parent: Node, pos: Vector3, yaw: float, state := "", tilt := 0.0) -> void:
	if state == "":
		var r := _rng.randf()
		state = "on" if r < 0.72 else ("off" if r < 0.95 else "flicker")
	var on := state != "off"
	var f := _place("fixture", pos, yaw, parent, {"tube": _mats["tube_on" if on else "tube_off"]})
	f.rotation.z = atan(tilt)
	var light: OmniLight3D = null
	if on:
		light = OmniLight3D.new()
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
		light.distance_fade_enabled = true
		light.distance_fade_begin = 36.0
		light.distance_fade_shadow = 22.0
		light.distance_fade_length = 8.0
		parent.add_child(light)
		if state == "flicker":
			_flicker.append({"light": light, "fixture": f, "next": 0.0, "on": true})
	_fixtures[_key(pos)] = {"node": f, "light": light}


# ================================================================ 소품, 표지, 데칼

func _build_props() -> void:
	var g := _group("Props")
	_place("steel_door", Vector3(0.0, 0, DOOR_Z), PI / 2, g)
	_place("exit_sign", Vector3(0.0, 2.35, DOOR_Z), PI / 2, g)
	var green := OmniLight3D.new()
	green.position = Vector3(0.25, 2.3, DOOR_Z)
	green.light_color = Color("3BD07A")
	green.light_energy = 0.5
	green.omni_range = 3.0
	g.add_child(green)
	_place("fire_cabinet", Vector3(20.0, 0.45, 0.0), 0.0, g)
	_place("fire_cabinet", Vector3(28.0, 0.45, D), PI, g)
	_place("fire_cabinet", Vector3(0.0, 0.45, 6.5), PI / 2, g)
	if east_tunnel:
		_place("traffic_cone", Vector3(46.9, 0, 21.5), 0.3, g)
		_place("traffic_cone", Vector3(46.4, 0, 26.6), -0.5, g)
	if with_cup and west_opening:
		# 앵커: 아래로 가는 경사로 입구 옆에 쓰러진 커피컵 (1-1의 단서)
		cup = _place("coffee_cup", Vector3(2.2, 0.044, 21.9), 0.0, g)
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
				_label(g, floor_name, Vector3(x, 1.82, face + side * 0.022), yaw, 0.0016, black, 160)
				_label(g, code, Vector3(x, 1.56, face + side * 0.022), yaw, 0.0011, black, 128)
	var wall_paint := Color("2E5A40")
	_label(g, floor_name, Vector3(W - 0.02, 1.68, 11.0), -PI / 2, 0.0042, wall_paint, 256)
	_label(g, floor_name, Vector3(0.02, 1.68, 17.6), PI / 2, 0.0042, wall_paint, 256)
	_label(g, floor_name, Vector3(36.0, 1.68, 0.02), 0.0, 0.0042, wall_paint, 256)
	if east_tunnel:
		var sign := _place("hanging_sign", Vector3(W - 1.2, H - 0.45, RAMP_Z), PI / 2, g)
		sign.name = "HangingSign"
		hanging_sign_label = _label(g, sign_text, Vector3(W - 1.2 - 0.03, H - 0.45 - 0.32, RAMP_Z), -PI / 2, 0.0022, Color(0.95, 0.97, 0.95), 120)


func _build_decals() -> void:
	var g := _group("Decals")
	var oils := [ParkingMats.tex("oil_stain_a"), ParkingMats.tex("oil_stain_b")]
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
	for spec in [[Vector3(6.5, 0, 9.0), 0.6], [Vector3(41.5, 0, 22.5), -0.5], [Vector3(20.0, 0, 24.3), 0.05], [Vector3(30.0, 0, 7.6), 0.0], [Vector3(5.0, 0, 21.5), 2.2]]:
		var d := Decal.new()
		d.texture_albedo = ParkingMats.tex("tire_marks")
		d.size = Vector3(6.0, 0.4, 1.6)
		d.position = spec[0]
		d.rotation.y = spec[1]
		d.modulate = Color(1, 1, 1, 0.8)
		g.add_child(d)
	for spec in [[Vector3(13.0, 1.45, 0.0), 0.0], [Vector3(35.0, 1.45, 0.0), 0.0], [Vector3(22.0, 1.45, D), PI], [Vector3(0.0, 1.45, 9.5), PI / 2]]:
		var d := Decal.new()
		d.texture_albedo = ParkingMats.tex("leak_streak")
		d.size = Vector3(1.2, 0.6, 2.5)
		d.position = spec[0]
		d.rotation = Vector3(PI / 2, spec[1], 0)
		d.modulate = Color(1, 1, 1, 0.85)
		g.add_child(d)
