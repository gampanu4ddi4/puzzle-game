## 프롤로그: 지상 주차장 입구 (docs/levels/ch1_parking.md "프롤로그").
## 밤, 비가 그친 직후의 한국 도심 거리. 4차선 도로 건너편 인도에서 시작한다.
##
## 배치 (입구에서 바깥 = -Z 방향):
##   건물 외벽(1층 상가 + 위층 사무실) | 인도 6 m | 차도 18 m | 건너편 인도 6 m | 건너편 상가와 아파트
##   주차장 입구: 외벽에 뚫린 입구, 매달린 높이제한 바, 간판, 진입로, 과속방지턱, 발권기, 차단기, 정산소
##
## 바깥 물체는 모두 렌더 레이어 4, 바깥 조명은 레이어 4만 비춘다 (지하 층과 섞이지 않게).
class_name Prologue
extends Node3D

signal ticket_taken
signal barrier_raised

const LAYER := 4
const SODIUM := Color("ffb05a")
const STREET := "res://assets/models/street/"
const TEX := "res://assets/textures/street/"

var mouth: Vector3            # 경사로 위쪽 끝 바닥 가운데 (월드)
var ground_y := 0.0
var start_point: Vector3      # 플레이어 시작 위치
var booth: Node3D
var booth_window: Interactable
var ticket: Interactable
var barrier_lever: Interactable     # 정산소 안 차단기 개방 손잡이 (창문을 연 뒤 손이 닿는다)
var barrier_up := false

# 거리 치수 (입구 기준 z 오프셋, 바깥쪽이 음수)
const WALK := 0.15            # 인도 높이
const NEAR_CURB := -6.6
const FAR_CURB := -24.6
const FAR_EDGE := -30.6

var _arm_pivot: Node3D
var _arm_shape: CollisionShape3D
var _lever_pivot: Node3D
var _bar_pivot: Node3D
var _bar_swinging := false
var _amber: Array[StandardMaterial3D] = []
var _amber_lights: Array[OmniLight3D] = []
var _flicker_signs: Array[Dictionary] = []
var _mats := {}
var _font: SystemFont
var _cache := {}
var _sfx: AudioStreamPlayer3D
var _rng := RandomNumberGenerator.new()


func build(at_mouth: Vector3) -> void:
	mouth = at_mouth
	ground_y = at_mouth.y
	_rng.seed = 77
	start_point = _w(0.0, WALK + 0.05, FAR_CURB - 3.0)
	_mats = ParkingMats.outdoor().duplicate()
	var facade := (_mats["facade"] as ShaderMaterial).duplicate() as ShaderMaterial
	facade.set_shader_parameter("floor_level", ground_y)
	_mats["facade"] = facade
	_mats["pavers"] = _pavers()
	_font = SystemFont.new()
	_font.font_names = PackedStringArray(["Malgun Gothic", "Noto Sans CJK KR", "Noto Sans KR", "NanumGothic", "Noto Sans", "DejaVu Sans", "Arial"])
	_font.font_weight = 700
	_sfx = AudioStreamPlayer3D.new()
	_sfx.unit_size = 8.0
	add_child(_sfx)

	_build_ground()
	_build_markings()
	_build_facade()
	_build_shops()
	_build_entrance()
	_build_booth()
	_build_street_furniture()
	_build_poles_and_wires()
	_build_far_side()
	_build_bounds()


## 차단기를 올린다 (정산소 개방 손잡이). 올라가는 동안 소리가 나고, 다 올라가면 지나갈 수 있다.
## 한 번 올린 차단기는 다시 내려오지 않는다 (확보한 길을 몰래 닫지 않는다).
func raise_barrier() -> void:
	if barrier_up:
		return
	barrier_up = true
	_arm_shape.disabled = true
	var tw := create_tween()
	tw.tween_property(_arm_pivot, "rotation:z", deg_to_rad(-84.0), 1.4).set_trans(Tween.TRANS_SINE)
	_sfx.global_position = _arm_pivot.global_position
	_sfx.stream = ProcAudio.barrier()
	_sfx.play()
	barrier_raised.emit()


## 바깥(도로 쪽)에 있는지
func is_outside(p: Vector3) -> bool:
	return p.y > ground_y - 0.5 and p.z < mouth.z - 0.6


func _process(_delta: float) -> void:
	var t := Time.get_ticks_msec() / 1000.0
	# 황색 점멸 신호
	var on := fmod(t, 1.2) < 0.6
	for m in _amber:
		m.emission_energy_multiplier = 5.0 if on else 0.0
	for l in _amber_lights:
		l.light_energy = 0.8 if on else 0.0
	# 오래된 간판 형광등이 가끔 꺼졌다 켜진다
	for s in _flicker_signs:
		if t >= s["next"]:
			s["on"] = not s["on"]
			s["next"] = t + (_rng.randf_range(0.6, 5.0) if s["on"] else _rng.randf_range(0.04, 0.25))
			(s["mat"] as StandardMaterial3D).emission_energy_multiplier = s["energy"] if s["on"] else 0.05
			(s["light"] as OmniLight3D).light_energy = s["light_energy"] if s["on"] else 0.0


# ================================================================ 도우미

## 입구 기준 좌표 → 월드 (x: 입구 가운데에서 오른쪽(+X), y: 땅 위 높이, z: 입구에서 바깥쪽은 음수)
func _w(x: float, y: float, z: float) -> Vector3:
	return Vector3(mouth.x + x, ground_y + y, mouth.z + z)


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


func _pavers() -> ShaderMaterial:
	var s := ShaderMaterial.new()
	s.shader = preload("res://assets/shaders/concrete_triplanar.gdshader")
	s.set_shader_parameter("albedo_tex", load(TEX + "pavers_albedo.png"))
	s.set_shader_parameter("normal_tex", load(TEX + "pavers_normal.png"))
	s.set_shader_parameter("rough_tex", load(TEX + "pavers_rough.png"))
	s.set_shader_parameter("noise_tex", ParkingMats.tex("noise_pack"))
	s.set_shader_parameter("tile_meters", 2.0)
	s.set_shader_parameter("tint", Color(0.62, 0.62, 0.62))
	s.set_shader_parameter("puddle_amount", 0.22)
	s.set_shader_parameter("macro_variation", 0.15)
	return s


func _set_layer(n: Node) -> void:
	if n is Light3D:
		(n as Light3D).light_cull_mask = LAYER
	elif n is Decal:
		(n as Decal).cull_mask = LAYER
		(n as Decal).layers = LAYER
	elif n is VisualInstance3D:
		(n as VisualInstance3D).layers = LAYER
	for c in n.get_children():
		_set_layer(c)


func _box(parent: Node, size: Vector3, center: Vector3, mat: Material, collide := true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = center
	mi.layers = LAYER
	parent.add_child(mi)
	if collide:
		_solid(parent, size, center)
	return mi


func _solid(parent: Node, size: Vector3, center: Vector3) -> void:
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	body.position = center
	body.add_child(cs)
	parent.add_child(body)


## 소품 놓기. collide: "none" | "box"(크기 지정) | "mesh"(모양 그대로)
func _prop(name: String, pos: Vector3, yaw := 0.0, collide := "none", box := Vector3.ZERO, parent: Node = self) -> Node3D:
	if not _cache.has(name):
		_cache[name] = load(STREET + name + ".glb")
	var n: Node3D = (_cache[name] as PackedScene).instantiate()
	n.position = pos
	n.rotation.y = yaw
	parent.add_child(n)
	_set_layer(n)
	if collide == "mesh":
		for mi in n.find_children("*", "MeshInstance3D", true, false):
			(mi as MeshInstance3D).create_trimesh_collision()
	elif collide == "box":
		var body := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = box
		cs.shape = shape
		cs.position = Vector3(0, box.y / 2.0, 0)
		body.add_child(cs)
		n.add_child(body)
	return n


## 가게 셔터: 방화셔터 모델에서 노란 경고 띠만 셔터 색으로 바꾼다
var _shop_shutter_mat: StandardMaterial3D

func _plain_shutter(n: Node) -> void:
	if _shop_shutter_mat == null:
		_shop_shutter_mat = _std(Color("8c908d"), 0.45, 0.55)
	_override(n, "hazard_yellow", _shop_shutter_mat)


## 소품 안의 특정 재질을 바꿔 끼운다 (예: 간판 앞판을 켜기)
func _override(n: Node, mat_name: String, mat: Material) -> void:
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		for i in m.mesh.get_surface_count():
			var src := m.mesh.surface_get_material(i)
			if src and src.resource_name == mat_name:
				m.set_surface_override_material(i, mat)


func _label(parent: Node, text: String, pos: Vector3, px: float, color: Color, size := 128, yaw := PI) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font = _font
	l.font_size = size
	l.pixel_size = px
	l.modulate = color
	l.outline_size = 0
	l.shaded = true
	l.alpha_cut = Label3D.ALPHA_CUT_OPAQUE_PREPASS
	l.position = pos
	l.rotation.y = yaw
	l.layers = LAYER
	parent.add_child(l)
	return l


func _omni(parent: Node, pos: Vector3, color: Color, energy: float, rng: float, shadows := false) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.position = pos
	l.light_color = color
	l.light_energy = energy
	l.omni_range = rng
	l.shadow_enabled = shadows
	l.light_cull_mask = LAYER
	l.light_volumetric_fog_energy = 1.0
	parent.add_child(l)
	return l


func _paint_quad(size: Vector2, center: Vector3, color: Color, wear := 0.3) -> void:
	var m := ShaderMaterial.new()
	m.shader = preload("res://assets/shaders/floor_paint.gdshader")
	m.set_shader_parameter("paint_color", color)
	m.set_shader_parameter("noise_tex", ParkingMats.tex("noise_pack"))
	m.set_shader_parameter("wear", wear)
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = size
	mi.mesh = pm
	mi.material_override = m
	mi.position = center
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.layers = LAYER
	add_child(mi)


func _decal(tex: Texture2D, pos: Vector3, size: Vector3, yaw := 0.0, alpha := 1.0) -> void:
	var d := Decal.new()
	d.texture_albedo = tex
	d.size = size
	d.position = pos
	d.rotation.y = yaw
	d.modulate = Color(1, 1, 1, alpha)
	d.cull_mask = LAYER
	d.layers = LAYER
	add_child(d)


## 늘어진 선 (전선, 체인): 두 점 사이를 아래로 처지게 잇는다
func _sag_line(a: Vector3, b: Vector3, sag: float, thick: float, mat: Material, segments := 12) -> void:
	var prev := a
	for i in range(1, segments + 1):
		var t := float(i) / segments
		var p := a.lerp(b, t) - Vector3(0, sag * 4.0 * t * (1.0 - t), 0)
		var mid := (prev + p) / 2.0
		var d := p - prev
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(thick, thick, d.length() + thick)
		mi.mesh = bm
		mi.material_override = mat
		mi.position = mid
		mi.layers = LAYER
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
		mi.look_at_from_position(mid, p, Vector3.UP if absf(d.normalized().y) < 0.99 else Vector3.RIGHT)
		prev = p


# ================================================================ 땅

func _build_ground() -> void:
	var asphalt: Material = _mats["asphalt"]
	var pav: Material = _mats["pavers"]
	var curb: Material = _mats["curb"]
	var span := 90.0
	# 차도 (건물 앞 진입로까지 이어진다. 외벽 두께만큼의 틈이 생기지 않게 입구 안쪽까지)
	_box(self, Vector3(span, 0.3, -FAR_CURB + 0.6), _w(0, -0.15, FAR_CURB / 2.0 + 0.3), asphalt)
	# 인도·연석은 서로 겹치지 않고 맞닿게만 놓는다.
	# (윗면 높이가 같은 상자가 겹치면 겹친 곳에서 두 면이 번갈아 그려져 깜빡인다)
	var cw := 0.2                         # 연석 폭
	var half := span / 2.0
	# 이쪽 인도: 진입로(폭 6.8 m)와 진입로 옆 연석을 비우고 양쪽에, 도로 쪽 연석 안쪽까지
	var walk_z0 := -0.6
	var walk_z1 := NEAR_CURB + cw
	var walk_d := walk_z0 - walk_z1
	var side_x := 3.4 + cw               # 진입로 옆 연석 바깥쪽
	var walk_w := half - side_x
	for sx in [-1.0, 1.0]:
		_box(self, Vector3(walk_w, WALK, walk_d), _w(sx * (side_x + walk_w / 2.0), WALK / 2.0, (walk_z0 + walk_z1) / 2.0), pav)
		# 진입로 옆 연석 (인도 깊이만큼)
		_box(self, Vector3(cw, WALK, walk_d), _w(sx * (3.4 + cw / 2.0), WALK / 2.0, (walk_z0 + walk_z1) / 2.0), curb)
		# 도로 쪽 연석 (진입로 옆 연석의 끝 모서리까지 덮는다)
		var curb_w := half - 3.4
		_box(self, Vector3(curb_w, WALK, cw), _w(sx * (3.4 + curb_w / 2.0), WALK / 2.0, NEAR_CURB + cw / 2.0), curb)
	# 건너편: 도로 쪽 연석, 그 뒤로 인도
	_box(self, Vector3(span, WALK, cw), _w(0, WALK / 2.0, FAR_CURB - cw / 2.0), curb)
	var far_d := (FAR_CURB - cw) - FAR_EDGE
	_box(self, Vector3(span, WALK, far_d), _w(0, WALK / 2.0, FAR_CURB - cw - far_d / 2.0), pav)
	# 맨홀과 빗물받이
	var manhole := load(TEX + "manhole.png") as Texture2D
	var drain := load(TEX + "drain.png") as Texture2D
	for spec in [[-12.0, -15.6], [9.0, -11.0], [24.0, -19.0], [-26.0, -10.5]]:
		_decal(manhole, _w(spec[0], 0.0, spec[1]), Vector3(0.75, 0.3, 0.75), _rng.randf() * TAU)
	for x in [-30.0, -18.0, -6.0, 8.0, 20.0, 32.0]:
		_decal(drain, _w(x, 0.0, NEAR_CURB - 0.35), Vector3(0.9, 0.3, 0.4))
		_decal(drain, _w(x + 4.0, 0.0, FAR_CURB + 0.35), Vector3(0.9, 0.3, 0.4))
	# 기름 자국 (차가 서던 자리)
	for i in 10:
		_decal(ParkingMats.tex("oil_stain_a" if i % 2 == 0 else "oil_stain_b"),
			_w(_rng.randf_range(-35, 35), 0.0, _rng.randf_range(FAR_CURB + 1.5, NEAR_CURB - 1.5)),
			Vector3(1.6, 0.4, 1.6), _rng.randf() * TAU, 0.6)


func _build_markings() -> void:
	var mid := (NEAR_CURB + FAR_CURB) / 2.0
	var yellow := Color("e3c23b")
	var white := Color("e8e8e2")
	var y := 0.005
	# 중앙선 (노란 겹선)
	for dz in [-0.12, 0.12]:
		_paint_quad(Vector2(90.0, 0.13), _w(0, y, mid + dz), yellow, 0.35)
	# 차선 (흰 점선 3 m, 간격 5 m)
	for lane_z in [mid + 4.5, mid - 4.5]:
		var x := -44.0
		while x < 44.0:
			if absf(x - 16.0) > 4.0:   # 횡단보도 안에서는 끊는다
				_paint_quad(Vector2(3.0, 0.13), _w(x + 1.5, y, lane_z), white, 0.4)
			x += 8.0
	# 횡단보도 (입구 오른쪽 16 m): 줄무늬가 차 진행 방향으로 길다
	var cz := FAR_CURB + 0.7
	while cz < NEAR_CURB - 0.5:
		_paint_quad(Vector2(4.0, 0.45), _w(16.0, y, cz), white, 0.45)
		cz += 0.9
	# 정지선
	_paint_quad(Vector2(0.35, 8.6), _w(12.8, y, mid + 4.5), white, 0.4)
	_paint_quad(Vector2(0.35, 8.6), _w(19.2, y, mid - 4.5), white, 0.4)


# ================================================================ 건물

func _build_facade() -> void:
	var gy := 0.0
	var fz := -0.3
	var mat: Material = _mats["facade"]
	var h := 13.0
	# 입구(폭 6.6, 높이 2.9)를 뚫은 외벽
	_box(self, Vector3(41.7, h, 0.6), _w(-3.3 - 20.85, h / 2.0, fz), mat)
	_box(self, Vector3(41.7, h, 0.6), _w(3.3 + 20.85, h / 2.0, fz), mat)
	_box(self, Vector3(6.6, h - 2.9, 0.6), _w(0, 2.9 + (h - 2.9) / 2.0, fz), mat)
	# 1층과 2층 사이 띠, 옥상 난간
	_box(self, Vector3(90.0, 0.35, 0.8), _w(0, 3.9, fz - 0.4), mat, false)
	_box(self, Vector3(90.0, 0.6, 0.7), _w(0, h + 0.3, fz - 0.05), mat, false)
	# 위층 사무실 창 (대부분 꺼져 있고, 하나는 형광등이 켜진 채)
	var glass := _std(Color(0.05, 0.06, 0.07), 0.12, 0.3)
	var lit := _std(Color(0.5, 0.55, 0.5), 0.3, 0.0, Color("cfe0d0"), 0.45)
	for i in 11:
		var wx := -37.5 + 7.5 * i
		if absf(wx) < 4.0:
			continue
		for row in [5.6, 8.4, 11.2]:
			var m: Material = lit if (i == 7 and row == 8.4) else glass
			_box(self, Vector3(5.6, 1.7, 0.05), _w(wx, row, fz - 0.31), m, false)
			_box(self, Vector3(0.06, 1.7, 0.06), _w(wx, row, fz - 0.34), _std(Color("5a5e60"), 0.4, 0.6), false)
	# 실외기 (벽에 매달린 것과 바닥에 놓인 것)
	for spec in [[-30.0, 6.6], [-16.5, 9.4], [-9.0, 6.6], [12.0, 9.4], [26.0, 6.6], [33.0, 12.2]]:
		_box(self, Vector3(0.9, 0.05, 0.45), _w(spec[0], spec[1] - 0.05, fz - 0.55), _std(Color("4a4f4c"), 0.5, 0.5), false)
		_prop("ac_unit", _w(spec[0], spec[1], fz - 0.48), PI)
	# "임대" 현수막
	var banner := _box(self, Vector3(1.2, 4.5, 0.02), _w(19.0, 8.2, fz - 0.33), _std(Color("c8302a"), 0.8), false)
	banner.rotation.x = 0.0
	_label(self, "임\n대\n문\n의", _w(19.0, 8.4, fz - 0.35), 0.006, Color(1, 1, 1), 128)


## 1층 상가: 셔터 내린 가게들과 간판. 하나는 형광등 간판이 가끔 깜빡인다.
func _build_shops() -> void:
	var fz := -0.6
	var shops := [
		[-28.0, "새솔부동산", Color("2f4f8a"), false],
		[-21.0, "24시 셀프빨래방", Color("2a8fb0"), true],
		[-14.0, "꽃집", Color("3a7a4a"), false],
		[14.0, "새솔약국", Color("2a8a4a"), true],
		[21.0, "점포 임대", Color("8c8c84"), false],
		[28.0, "새솔 PC", Color("6a3fa8"), false],
	]
	for s in shops:
		var x: float = s[0]
		var shutter: Node3D = (load(ParkingFloor.KIT + "fire_shutter.glb") as PackedScene).instantiate()
		shutter.position = _w(x, WALK, fz - 0.02)
		shutter.rotation.y = PI / 2
		add_child(shutter)
		_set_layer(shutter)
		_plain_shutter(shutter)
		var box := _prop("sign_box", _w(x, 2.95, fz - 0.1), PI)
		var on: bool = s[3]
		var face := _std(Color(0.9, 0.9, 0.88), 0.4, 0.0, Color(0.95, 0.97, 1.0), 1.4 if on else 0.0)
		if not on:
			face.albedo_color = Color(0.55, 0.56, 0.55)
		_override(box, "sign_face", face)
		_label(self, s[1], _w(x, 3.4, fz - 0.25), 0.0042, s[2], 128)
		if on:
			var l := _omni(self, _w(x, 3.3, fz - 1.4), Color(0.9, 0.95, 1.0), 0.9, 6.0)
			if s[1] == "24시 셀프빨래방":
				_flicker_signs.append({"mat": face, "light": l, "on": true, "next": 0.0, "energy": 1.4, "light_energy": 0.9})
	# 약국 초록 십자 (가게 옆 돌출 간판)
	var cross_mat := _std(Color("2a8a4a"), 0.4, 0.0, Color("3ad07a"), 2.5)
	_box(self, Vector3(0.12, 0.7, 0.22), _w(17.4, 3.6, fz - 0.55), cross_mat, false)
	_box(self, Vector3(0.12, 0.22, 0.7), _w(17.4, 3.6, fz - 0.55), cross_mat, false)
	_omni(self, _w(17.4, 3.6, fz - 1.2), Color("3ad07a"), 0.5, 4.0)


func _build_entrance() -> void:
	var fz := -0.6
	# 입구 간판 (희미하게 빛나는 판)
	_box(self, Vector3(7.0, 1.0, 0.15), _w(0, 4.6, fz - 0.1), _std(Color("16402c"), 0.5, 0.0, Color("1f6b47"), 0.8), false)
	_label(self, "새솔복합센터  주차장", _w(0.45, 4.6, fz - 0.19), 0.0034, Color(0.95, 0.97, 0.95), 128)
	_box(self, Vector3(0.75, 0.75, 0.05), _w(-2.9, 4.6, fz - 0.2), _std(Color("2b5fb0"), 0.5, 0.0, Color("2b5fb0"), 0.6), false)
	_label(self, "P", _w(-2.9, 4.6, fz - 0.23), 0.005, Color.WHITE, 128)
	_omni(self, _w(0, 4.0, fz - 1.0), Color("9fe0bd"), 0.5, 5.0)
	# 입구 위 경광등 (주황, 천천히 깜빡인다 → 황색 점멸과 함께 돈다)
	var beacon := _std(Color("e0561e"), 0.3, 0.0, Color("ff7a2a"), 4.0)
	_box(self, Vector3(0.18, 0.22, 0.18), _w(3.0, 3.25, fz - 0.15), beacon, false)
	_amber.append(beacon)
	# 입구 안쪽 형광등 (B1 경사로 레이어 2도 비춘다)
	var inner := _omni(self, _w(0, 2.5, 2.0), Color("dcebd8"), 1.3, 9.0)
	inner.light_cull_mask = LAYER | 2
	# 매달린 높이제한 바
	_build_height_bar()
	# 과속방지턱, 진입로 바닥 글씨
	_prop("speed_bump", _w(0, 0.0, -5.6))
	_paint_quad(Vector2(2.6, 0.9), _w(0, 0.006, -3.8), Color("e8e8e2"), 0.4)
	_label(self, "입구 IN", _w(0, 0.012, -3.8), 0.0045, Color(0.18, 0.18, 0.2), 128, PI).rotation.x = -PI / 2
	# 차단기 (올라가 있다)
	var base := _w(4.0, WALK, -3.4)
	_box(self, Vector3(0.32, 1.05, 0.32), base + Vector3(0, 0.525, 0), _std(Color("e3c23b"), 0.6))
	_box(self, Vector3(0.38, 0.3, 0.38), base + Vector3(0, 1.15, 0), _std(Color("2a2a2a"), 0.5, 0.3), false)
	_arm_pivot = Node3D.new()
	_arm_pivot.position = base + Vector3(0, 1.08, 0)
	add_child(_arm_pivot)
	var red := _std(Color("c8473f"), 0.5)
	var white := _std(Color("ededed"), 0.5)
	for i in 7:
		_box(_arm_pivot, Vector3(1.0, 0.09, 0.06), Vector3(-0.5 - 1.0 * i, 0, 0), red if i % 2 == 0 else white, false)
	# 내려와 있다. 팔 아래 늘어진 칸살(차단기 스커트)까지 막는다
	var skirt := _std(Color("d8d8d2"), 0.6)
	var arm_h := WALK + 1.08
	for i in 20:
		_box(_arm_pivot, Vector3(0.025, arm_h - 0.32, 0.025), Vector3(-0.3 - 0.35 * i, -(arm_h - 0.32) / 2.0 - 0.05, 0), skirt, false)
	_box(_arm_pivot, Vector3(6.95, 0.03, 0.03), Vector3(-3.5, -(arm_h - 0.27), 0), skirt, false)
	var arm_body := StaticBody3D.new()
	_arm_shape = CollisionShape3D.new()
	var arm_box := BoxShape3D.new()
	arm_box.size = Vector3(7.0, arm_h, 0.14)
	_arm_shape.shape = arm_box
	_arm_shape.position = Vector3(-3.5, -arm_h / 2.0 + 0.05, 0)
	arm_body.add_child(_arm_shape)
	_arm_pivot.add_child(arm_body)
	# 차단기 양옆 보행자 난간: 차로 밖으로 돌아 들어가지 못하게 (건물 외벽까지)
	_guard_rail(_w(3.6, 0.0, -3.4), _w(3.6, 0.0, -0.65))
	_guard_rail(_w(-3.45, 0.0, -3.4), _w(-3.45, 0.0, -0.65))
	# 발권기 (차로 쪽을 본다)
	_prop("ticket_machine", _w(4.2, WALK, -4.9), 0.0, "box", Vector3(0.5, 1.62, 0.5))
	# 도로반사경 (진입로 왼쪽 모서리, 나가는 차가 도로를 보게)
	_prop("convex_mirror", _w(-4.3, WALK, -6.0), PI * 0.85, "box", Vector3(0.1, 3.0, 0.1))


## 체인 두 줄에 매달린 노랑·검정 바. 가운데 판에 "높이제한 2.3m". 머리를 부딪히면 흔들리며 소리가 난다.
func _build_height_bar() -> void:
	_bar_pivot = Node3D.new()
	_bar_pivot.position = _w(0, 2.9, -0.75)
	add_child(_bar_pivot)
	var drop := 0.48
	var chain_mat := _std(Color("6e7270"), 0.4, 0.8)
	for sx in [-2.6, 2.6]:
		for k in 6:
			var link := MeshInstance3D.new()
			var tm := TorusMesh.new()
			tm.inner_radius = 0.015
			tm.outer_radius = 0.035
			link.mesh = tm
			link.material_override = chain_mat
			link.position = Vector3(sx, -0.04 - 0.075 * k, 0)
			link.rotation = Vector3(PI / 2 if k % 2 == 0 else 0.0, PI / 2, 0)
			link.layers = LAYER
			_bar_pivot.add_child(link)
		_box(self, Vector3(0.12, 0.06, 0.12), _w(sx, 2.93, -0.75), chain_mat, false)   # 천장 고리
	var yellow := _std(Color("e3c23b"), 0.55)
	var black := _std(Color("1a1a1a"), 0.55)
	for i in 8:
		_box(_bar_pivot, Vector3(0.85, 0.18, 0.18), Vector3(-3.4 + 0.85 * i + 0.425, -drop, 0), yellow if i % 2 == 0 else black, false)
	# 가운데 판과 글씨 (판 앞면에 붙어 있다)
	_box(_bar_pivot, Vector3(1.7, 0.34, 0.03), Vector3(0, -drop, -0.105), _std(Color("f0d64a"), 0.5), false)
	_box(_bar_pivot, Vector3(1.66, 0.3, 0.005), Vector3(0, -drop, -0.121), _std(Color("1a1a1a"), 0.5), false)
	_box(_bar_pivot, Vector3(1.6, 0.25, 0.005), Vector3(0, -drop, -0.124), _std(Color("f0d64a"), 0.5), false)
	_label(_bar_pivot, "높이제한  2.3m", Vector3(0, -drop, -0.128), 0.0015, Color(0.08, 0.08, 0.08), 112)
	# 충돌: 바 자체 + 머리가 닿는 것을 알아채는 영역
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(6.8, 0.2, 0.2)
	cs.shape = shape
	cs.position = Vector3(0, -drop, 0)
	body.add_child(cs)
	_bar_pivot.add_child(body)
	var area := Area3D.new()
	var acs := CollisionShape3D.new()
	var ashape := BoxShape3D.new()
	ashape.size = Vector3(6.9, 0.3, 0.6)
	acs.shape = ashape
	acs.position = Vector3(0, -drop, 0)
	area.add_child(acs)
	_bar_pivot.add_child(area)
	area.body_entered.connect(_on_bar_hit)


func _on_bar_hit(body: Node) -> void:
	if not body is CharacterBody3D or _bar_swinging:
		return
	_bar_swinging = true
	# 부딪힌 사람이 움직이던 쪽으로 밀려난다 (멈춰 있었다면 사람 반대쪽으로).
	# 바는 매단 점 아래에 있으므로 X축으로 +θ 돌면 바가 -Z로 움직인다 → 밀 방향과 부호가 반대다.
	var push := (body as CharacterBody3D).velocity.z
	if absf(push) < 0.1:
		push = _bar_pivot.global_position.z - body.global_position.z
	var dir := -signf(push) if push != 0.0 else 1.0
	var tw := create_tween()
	var amp := 0.28
	for i in 6:
		tw.tween_property(_bar_pivot, "rotation:x", amp * dir, 0.32).set_trans(Tween.TRANS_SINE)
		amp *= 0.55
		dir = -dir
	tw.tween_property(_bar_pivot, "rotation:x", 0.0, 0.3)
	tw.finished.connect(func() -> void: _bar_swinging = false)
	_sfx.global_position = _bar_pivot.global_position
	_sfx.stream = ProcAudio.clank()
	_sfx.play()


func _build_booth() -> void:
	var c := _w(5.6, WALK, -2.6)
	booth = _prop("booth", c, 0.0, "mesh")
	# 안쪽 소품 (부스 기준 좌표: 창문은 -X, 계산대는 x -0.6, 높이 1.0)
	_prop("crt_monitor", Vector3(-0.58, 1.0, -0.5), PI / 2, "none", Vector3.ZERO, booth)
	_prop("desk_phone", Vector3(-0.6, 1.0, 0.62), PI / 2 + 0.3, "none", Vector3.ZERO, booth)
	_prop("desk_fan", Vector3(-0.66, 1.0, 0.9), PI / 2 - 0.4, "none", Vector3.ZERO, booth)
	_prop("office_chair", Vector3(0.25, 0.0, 0.05), -PI / 2 + 0.35, "none", Vector3.ZERO, booth)
	# 영수증 뭉치와 머그컵
	_box(booth, Vector3(0.1, 0.03, 0.14), Vector3(-0.55, 1.015, 0.2), _std(Color("efe9d8"), 0.8), false)
	var mug := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.04
	cm.bottom_radius = 0.04
	cm.height = 0.1
	mug.mesh = cm
	mug.material_override = _std(Color("e8e8e2"), 0.3)
	mug.position = Vector3(-0.5, 1.05, -0.05)
	mug.layers = LAYER
	booth.add_child(mug)
	# 1999년 7월 달력 (게시판 위)
	_box(booth, Vector3(0.01, 0.42, 0.3), Vector3(0.815, 1.55, -0.45), _std(Color("f2f0e8"), 0.8), false)
	var cal := _label(booth, "1999\n7\n\n일 월 화 수 목 금 토\n             1  2  3\n 4  5  6  7  8  9 10\n11 12 13 14 15 16 17\n18 19 20 21 22 23 24\n25 26 27 28 29 30 31",
		Vector3(0.808, 1.56, -0.45), 0.00042, Color(0.15, 0.15, 0.15), 48, -PI / 2)
	cal.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# 지붕 띠 글씨, 창문 아래 요금표
	_label(booth, "정  산  소", Vector3(-1.17, 2.39, 0), 0.0013, Color(0.15, 0.2, 0.18), 112, -PI / 2)
	_box(booth, Vector3(0.01, 0.62, 0.52), Vector3(-0.905, 0.6, -0.55), _std(Color("f4f4ee"), 0.6), false)
	_label(booth, "주차요금 안내\n\n최초 30분   1,000원\n추가 10분     500원\n1일 최대  15,000원\n\n※ 1시간 무료 (센터 이용 시)",
		Vector3(-0.912, 0.62, -0.55), 0.00055, Color(0.12, 0.12, 0.14), 56, -PI / 2)
	# 안쪽 형광등
	_omni(booth, Vector3(0, 2.25, 0), Color("f0ead8"), 0.4, 3.0)

	# 미닫이 창문: E로 연다
	booth_window = Interactable.new()
	booth_window.position = Vector3(-0.93, 1.5, 0)
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.03, 0.98, 1.5)
	cs.shape = shape
	booth_window.add_child(cs)
	var gm := MeshInstance3D.new()
	var gb := BoxMesh.new()
	gb.size = shape.size
	gm.mesh = gb
	var gmat := _std(Color(0.6, 0.66, 0.66, 0.32), 0.05, 0.1)
	gmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	gm.material_override = gmat
	gm.layers = LAYER
	booth_window.add_child(gm)
	var handle := _box(booth_window, Vector3(0.03, 0.12, 0.02), Vector3(-0.025, 0, 0.6), _std(Color("c8c8c8"), 0.25, 1.0), false)
	handle.layers = LAYER
	booth.add_child(booth_window)
	booth_window.interacted.connect(_open_window)

	# 1999년 주차권 (흔적 1): 계산대 위, 창문 가까이
	ticket = Interactable.new()
	ticket.position = Vector3(-0.72, 1.004, -0.35)   # 창문을 열면 드러나는 쪽
	ticket.rotation.y = 0.25
	var tcs := CollisionShape3D.new()
	var tshape := BoxShape3D.new()
	tshape.size = Vector3(0.14, 0.04, 0.2)
	tcs.shape = tshape
	ticket.add_child(tcs)
	var paper := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(0.08, 0.16)
	paper.mesh = pm
	paper.material_override = _std(Color("efe9d8"), 0.8)
	paper.layers = LAYER
	ticket.add_child(paper)
	var txt := _label(ticket, "새솔센터 주차권\n1999.07.14\n입차 21:40", Vector3(0, 0.003, 0), 0.00028, Color(0.12, 0.12, 0.14), 64, 0.0)
	txt.rotation = Vector3(-PI / 2, PI / 2, 0)
	ticket.enabled = false   # 창문을 연 뒤에 집을 수 있다
	booth.add_child(ticket)
	ticket.interacted.connect(_take_ticket)

	# 차단기 개방 손잡이: 계산대 창가 쪽. 유리 너머로 처음부터 보이고, 창문을 열면 손이 닿는다
	_box(booth, Vector3(0.16, 0.06, 0.22), Vector3(-0.72, 1.03, -0.6), _std(Color("33383a"), 0.5, 0.5), false)
	_lever_pivot = Node3D.new()
	_lever_pivot.position = Vector3(-0.72, 1.06, -0.6)
	booth.add_child(_lever_pivot)
	_box(_lever_pivot, Vector3(0.025, 0.22, 0.025), Vector3(0, 0.11, 0), _std(Color("c8c8c8"), 0.25, 1.0), false)
	_box(_lever_pivot, Vector3(0.06, 0.06, 0.06), Vector3(0, 0.23, 0), _std(Color("c23a2e"), 0.45), false)
	_lever_pivot.rotation.x = 0.5
	var plate := _label(booth, "차단기 열림", Vector3(-0.72, 1.062, -0.82), 0.0009, Color(0.9, 0.9, 0.86), 64, -PI / 2)
	plate.rotation.x = -PI / 2
	barrier_lever = Interactable.new()
	barrier_lever.position = Vector3(-0.72, 1.18, -0.6)
	var lcs := CollisionShape3D.new()
	var lsh := BoxShape3D.new()
	lsh.size = Vector3(0.2, 0.3, 0.2)
	lcs.shape = lsh
	barrier_lever.add_child(lcs)
	barrier_lever.enabled = false
	booth.add_child(barrier_lever)
	barrier_lever.interacted.connect(_pull_lever)


## 노랑·검정 보행자 난간 (높이 1.05, 점프로 못 넘는다)
func _guard_rail(a: Vector3, b: Vector3) -> void:
	var d := b - a
	var length := d.length()
	var yaw := atan2(d.x, d.z)
	var yellow := _std(Color("e3c23b"), 0.55)
	var black := _std(Color("1e1e1e"), 0.6)
	var n := int(ceil(length / 1.0))
	for i in n + 1:
		var p := a + d * (float(i) / n)
		_box(self, Vector3(0.06, 1.05, 0.06), p + Vector3(0, 0.525, 0), yellow, false)
	for k in 2:
		var bar := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.05, 0.05, length)
		bar.mesh = bm
		bar.material_override = yellow if k == 0 else black
		bar.position = (a + b) / 2.0 + Vector3(0, 1.02 if k == 0 else 0.55, 0)
		bar.rotation.y = yaw
		bar.layers = LAYER
		add_child(bar)
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.1, 1.05, length)
	cs.shape = shape
	body.position = (a + b) / 2.0 + Vector3(0, 0.525, 0)
	body.rotation.y = yaw
	body.add_child(cs)
	add_child(body)


func _open_window() -> void:
	booth_window.enabled = false
	barrier_lever.enabled = true
	(booth_window.get_child(0) as CollisionShape3D).disabled = true
	var tw := create_tween()
	tw.tween_property(booth_window, "position:z", booth_window.position.z + 0.72, 0.6).set_trans(Tween.TRANS_SINE)
	ticket.enabled = true
	_sfx.global_position = booth_window.global_position
	_sfx.stream = ProcAudio.click()
	_sfx.play()


func _pull_lever() -> void:
	barrier_lever.enabled = false
	var tw := create_tween()
	tw.tween_property(_lever_pivot, "rotation:x", -0.5, 0.25).set_trans(Tween.TRANS_SINE)
	_sfx.global_position = _lever_pivot.global_position
	_sfx.stream = ProcAudio.lever()
	_sfx.play()
	get_tree().create_timer(0.35).timeout.connect(raise_barrier)


func _take_ticket() -> void:
	ticket.enabled = false
	ticket.visible = false
	(ticket.get_child(0) as CollisionShape3D).disabled = true
	ticket_taken.emit()


# ================================================================ 거리 시설물

func _build_street_furniture() -> void:
	var near := NEAR_CURB + 0.45
	# 가로등: 이쪽 인도 두 개(팔이 도로 쪽 = -Z), 건너편 두 개(팔이 도로 쪽 = +Z)
	for spec in [[-14.0, near, PI], [14.0, near, PI], [6.0, FAR_CURB - 0.45, 0.0], [30.0, FAR_CURB - 0.45, 0.0]]:
		var lamp := _prop("street_lamp", _w(spec[0], WALK, spec[1]), spec[2], "box", Vector3(0.2, 8.0, 0.2))
		_omni(self, lamp.to_global(Vector3(0, 8.35, 2.15)), SODIUM, 4.0, 22.0, true)
	# 신호등 (횡단보도 양쪽, 황색 점멸)
	for spec in [[19.6, near, PI], [12.4, FAR_CURB - 0.45, 0.0]]:
		var tl := _prop("traffic_light", _w(spec[0], WALK, spec[1]), spec[2], "box", Vector3(0.2, 6.0, 0.2))
		var amber := _std(Color("ffb020"), 0.2, 0.0, Color("ffb020"), 5.0)
		_override(tl, "lamp_amber", amber)
		_amber.append(amber)
		_amber_lights.append(_omni(self, tl.to_global(Vector3(-0.3, 5.55, 3.2)), Color("ffb020"), 0.8, 7.0))
	# 주정차금지 표지판
	var sign := _prop("no_parking_sign", _w(-7.5, WALK, near), PI, "box", Vector3(0.08, 2.7, 0.08))
	_label(sign, "주정차금지", Vector3(0, 2.02, 0.05), 0.0011, Color(0.8, 0.12, 0.1), 112, 0.0)
	# 자판기와 쓰레기통 (외벽 앞)
	var vend := _prop("vending_machine", _w(-8.5, WALK, -1.05), PI, "box", Vector3(1.0, 1.85, 0.8))
	var vmat := _std(Color.WHITE, 0.25, 0.0, Color.WHITE, 0.45)
	vmat.albedo_texture = load(TEX + "vending_front.png")
	vmat.emission_texture = vmat.albedo_texture
	# 앞판은 텍스처 좌표가 맞는 평면으로 따로 붙인다 (모델 안의 앞판은 가린다)
	_override(vend, "vend_front", _std(Color(0.05, 0.05, 0.05), 0.5))
	var front := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(0.86, 1.6)
	front.mesh = qm
	front.material_override = vmat
	front.position = Vector3(0, 0.93, 0.412)
	front.layers = LAYER
	vend.add_child(front)
	_omni(self, _w(-8.5, 1.3, -2.2), Color("e8f0ff"), 1.1, 4.5)
	_prop("trash_bins", _w(-10.2, WALK, -0.95), PI, "box", Vector3(1.0, 0.95, 0.5))
	# 볼라드와 체인: 인도 가장자리 (차가 인도로 올라오지 못하게). 넘어가려면 점프
	var chain_mat := _std(Color("6e7270"), 0.4, 0.8)
	var xs := [-11.0, -8.5, -6.0]
	for i in xs.size():
		_prop("bollard", _w(xs[i], WALK, near - 0.15), 0.0, "box", Vector3(0.16, 0.85, 0.16))
		if i > 0:
			_sag_line(_w(xs[i - 1], WALK + 0.6, near - 0.15), _w(xs[i], WALK + 0.6, near - 0.15), 0.14, 0.03, chain_mat)
			_solid(self, Vector3(2.5, 0.5, 0.1), _w((xs[i - 1] + xs[i]) / 2.0, WALK + 0.25, near - 0.15))
	# 버려진 라바콘 하나
	var cone := (load(ParkingFloor.KIT + "traffic_cone.glb") as PackedScene).instantiate() as Node3D
	cone.position = _w(-5.2, WALK + 0.12, -4.5)
	cone.rotation = Vector3(PI / 2, 0.6, 0)
	add_child(cone)
	_set_layer(cone)


## 전봇대와 전선: 건너편 인도를 따라 늘어서고, 전선 몇 가닥이 건물로 건너간다.
func _build_poles_and_wires() -> void:
	var z := FAR_CURB - 0.5
	var poles: Array[Node3D] = []
	for x in [-30.0, -6.0, 18.0, 42.0]:
		poles.append(_prop("utility_pole", _w(x, WALK, z), 0.0, "box", Vector3(0.4, 11.0, 0.4)))
	var wire := _std(Color("141414"), 0.6, 0.2)
	for i in range(1, poles.size()):
		for h in [[9.95, 1.0], [9.95, -1.0], [9.35, 0.85], [9.35, -0.85]]:
			var a := poles[i - 1].to_global(Vector3(0, h[0], h[1]))
			var b := poles[i].to_global(Vector3(0, h[0], h[1]))
			_sag_line(a, b, 0.55, 0.025, wire, 16)
	# 길을 건너 건물로 가는 인입선
	for spec in [[1, -1.0, -10.0, 7.4], [2, -0.85, 9.0, 7.2], [2, 1.0, 24.0, 7.6]]:
		var a := poles[spec[0]].to_global(Vector3(0, 9.35, spec[1]))
		_sag_line(a, _w(spec[2], spec[3], -0.62), 0.9, 0.02, wire, 18)
		_box(self, Vector3(0.15, 0.15, 0.1), _w(spec[2], spec[3], -0.65), _std(Color("3a3e3c"), 0.5, 0.5), false)


## 건너편: 1층 상가 줄과 그 뒤 아파트 (몇 집만 불이 켜져 있다)
func _build_far_side() -> void:
	var mat: Material = _mats["facade"]
	var z0 := FAR_EDGE
	# 상가 건물 (2층)
	_box(self, Vector3(90.0, 7.0, 8.0), _w(0, 3.5, z0 - 4.0), mat)
	for x in [-35.0, -28.0, -21.0, -14.0, -7.0, 0.0, 7.0, 14.0, 21.0, 28.0, 35.0]:
		var sh: Node3D = (load(ParkingFloor.KIT + "fire_shutter.glb") as PackedScene).instantiate()
		sh.position = _w(x, WALK, z0 + 0.02)
		sh.rotation.y = PI / 2
		add_child(sh)
		_set_layer(sh)
		_plain_shutter(sh)
		_box(self, Vector3(6.4, 0.8, 0.2), _w(x, 3.2, z0 + 0.1), _std(Color("2a2d30"), 0.5, 0.3), false)
	_label(self, "새솔 김밥", _w(-14.0, 3.2, z0 + 0.22), 0.004, Color(0.85, 0.85, 0.8), 128, 0.0)
	_label(self, "세탁", _w(7.0, 3.2, z0 + 0.22), 0.004, Color(0.85, 0.85, 0.8), 128, 0.0)
	var conv_mat := _std(Color(0.9, 0.95, 0.9), 0.4, 0.0, Color("dff0e6"), 1.2)
	_box(self, Vector3(6.0, 0.6, 0.05), _w(21.0, 3.2, z0 + 0.22), conv_mat, false)
	_label(self, "24  편의점", _w(21.0, 3.2, z0 + 0.26), 0.0038, Color("1f6b47"), 128, 0.0)
	_omni(self, _w(21.0, 3.0, z0 + 1.6), Color("dff0e6"), 0.9, 7.0)
	# 아파트 두 동 (창문 텍스처: 꺼진 창 + 켜진 몇 집)
	var apt := _std(Color.WHITE, 0.8, 0.0, Color.WHITE, 1.4)
	apt.albedo_texture = load(TEX + "apartment_albedo.png")
	apt.emission_texture = load(TEX + "apartment_emission.png")
	apt.uv1_scale = Vector3(1, 1, 1)
	for spec in [[-18.0, 36.0], [22.0, 30.0]]:
		var mi := _box(self, Vector3(30.0, 30.0, 12.0), _w(spec[0], 15.0, z0 - spec[1]), apt, false)
		mi.material_override = null
		var bm := mi.mesh as BoxMesh
		bm.material = apt
	# 길 양옆으로 이어지는 건물 (안개 속)
	var dark := _std(Color(0.08, 0.085, 0.09), 0.9)
	for spec in [[-58.0, -12.0, 26.0], [58.0, -12.0, 22.0]]:
		_box(self, Vector3(24.0, spec[2], 30.0), _w(spec[0], spec[2] / 2.0, spec[1]), dark, false)
	# 하늘빛 (도시 불빛에 물든 낮은 구름): 아주 넓고 어두운 판
	var sky := _std(Color(0.0, 0.0, 0.0), 1.0, 0.0, Color("2a1e14"), 0.25)
	sky.cull_mode = BaseMaterial3D.CULL_DISABLED
	_box(self, Vector3(400.0, 1.0, 400.0), _w(0, 60.0, -40.0), sky, false)


## 보이지 않는 벽: 길 양옆 (안개 속 먼 곳으로는 레벨이 걸음을 늦춘다)
func _build_bounds() -> void:
	_solid(self, Vector3(1.0, 8.0, 32.0), _w(-40.0, 4.0, -15.0))
	_solid(self, Vector3(1.0, 8.0, 32.0), _w(40.0, 4.0, -15.0))
