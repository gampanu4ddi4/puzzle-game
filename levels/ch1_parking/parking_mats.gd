## 주차장 재질 모음.
## 층마다 원점(world_offset)이 다른 재질 묶음을 만든다. 같은 층을 여러 벌 놓아도
## 바닥 무늬, 물웅덩이, 페인트 벗겨짐이 완전히 같게 나와서 반복 공간의 이음새가 보이지 않는다.
class_name ParkingMats
extends RefCounted

const TEX := "res://assets/textures/parking/"
const SHADER_CONCRETE := preload("res://assets/shaders/concrete_triplanar.gdshader")
const SHADER_PAINT := preload("res://assets/shaders/floor_paint.gdshader")
const LIGHT_COLOR := Color("dcebd8")
const RAMP_SLOPE := 3.0 / 24.0
const RAMP_START_X := 48.0   # 층 기준, 동쪽 경사로가 시작되는 X

static var _by_origin := {}
static var _shared := {}


static func tex(name: String) -> Texture2D:
	return load(TEX + name + ".png")


## 이 원점에 놓인 층이 쓸 재질 묶음.
static func for_floor(origin: Vector3) -> Dictionary:
	var key := "%.2f,%.2f,%.2f" % [origin.x, origin.y, origin.z]
	if _by_origin.has(key):
		return _by_origin[key]
	var m := {}

	var floor_m := _concrete("floor", 4.0, origin)
	floor_m.set_shader_parameter("puddle_amount", 0.2)
	floor_m.set_shader_parameter("macro_variation", 0.09)
	floor_m.set_shader_parameter("joint_spacing", 4.0)
	m["floor"] = floor_m

	var ramp_m := _concrete("floor", 4.0, origin)
	ramp_m.set_shader_parameter("macro_variation", 0.1)
	ramp_m.set_shader_parameter("tint", Color(0.92, 0.92, 0.92))
	m["ramp_floor"] = ramp_m

	var wall_m := _concrete("wall", 2.0, origin)
	wall_m.set_shader_parameter("band_height", 1.0)
	wall_m.set_shader_parameter("band_color", Color("4E7A5B"))
	wall_m.set_shader_parameter("band_line_color", Color("E3C23B"))
	wall_m.set_shader_parameter("grime_strength", 0.45)
	wall_m.set_shader_parameter("streak_strength", 0.22)
	m["concrete_paint"] = wall_m

	var ramp_wall := wall_m.duplicate() as ShaderMaterial
	ramp_wall.set_shader_parameter("floor_slope", RAMP_SLOPE)
	ramp_wall.set_shader_parameter("slope_start_x", RAMP_START_X)
	m["ramp_wall"] = ramp_wall

	# 나선 경사로 벽: 바닥 높이가 계속 변하므로 띠를 셰이더 높이로 정하지 않고,
	# Blender에서 띠(초록) / 선(노랑) / 위쪽 벽을 따로 나눠 재질로 칠한다.
	var helix_wall := wall_m.duplicate() as ShaderMaterial
	helix_wall.set_shader_parameter("band_height", -1.0)
	helix_wall.set_shader_parameter("grime_strength", 0.0)
	m["helix_wall"] = helix_wall
	var helix_band := wall_m.duplicate() as ShaderMaterial
	helix_band.set_shader_parameter("band_height", 1000.0)
	helix_band.set_shader_parameter("grime_strength", 0.0)
	helix_band.set_shader_parameter("streak_strength", 0.0)
	m["helix_band"] = helix_band
	var helix_line := helix_band.duplicate() as ShaderMaterial
	helix_line.set_shader_parameter("band_color", Color("E3C23B"))
	m["helix_line"] = helix_line

	var ceil_m := _concrete("ceiling", 2.4, origin)
	ceil_m.set_shader_parameter("macro_variation", 0.18)
	ceil_m.set_shader_parameter("tint", Color(0.82, 0.83, 0.82))
	m["concrete_ceiling"] = ceil_m

	m["paint_white"] = _paint(Color("E8E8E2"), 0.32, origin)
	m["paint_yellow"] = _paint(Color("E3C23B"), 0.28, origin)

	for k in shared():
		m[k] = shared()[k]
	_by_origin[key] = m
	return m


## 위치와 상관없는 재질 (형광관, 표지판 판).
static func shared() -> Dictionary:
	if not _shared.is_empty():
		return _shared
	var tube_on := StandardMaterial3D.new()
	tube_on.albedo_color = Color("F2F7F0")
	tube_on.emission_enabled = true
	tube_on.emission = LIGHT_COLOR
	tube_on.emission_energy_multiplier = 6.0
	_shared["tube_on"] = tube_on

	var tube_off := StandardMaterial3D.new()
	tube_off.albedo_color = Color("B9BDB8")
	tube_off.roughness = 0.35
	_shared["tube_off"] = tube_off

	var plate := StandardMaterial3D.new()
	plate.albedo_color = Color("E3C23B")
	plate.roughness = 0.6
	_shared["plate_yellow"] = plate
	return _shared


static func _concrete(prefix: String, tile: float, origin: Vector3) -> ShaderMaterial:
	var s := ShaderMaterial.new()
	s.shader = SHADER_CONCRETE
	s.set_shader_parameter("albedo_tex", tex(prefix + "_albedo"))
	s.set_shader_parameter("normal_tex", tex(prefix + "_normal"))
	s.set_shader_parameter("rough_tex", tex(prefix + "_rough"))
	s.set_shader_parameter("noise_tex", tex("noise_pack"))
	s.set_shader_parameter("tile_meters", tile)
	s.set_shader_parameter("world_offset", origin)
	return s


static func _paint(color: Color, wear: float, origin: Vector3) -> ShaderMaterial:
	var s := ShaderMaterial.new()
	s.shader = SHADER_PAINT
	s.set_shader_parameter("paint_color", color)
	s.set_shader_parameter("noise_tex", tex("noise_pack"))
	s.set_shader_parameter("wear", wear)
	s.set_shader_parameter("world_offset", origin)
	return s
