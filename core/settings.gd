## 설정 (자동 로드 "Settings"). user://settings.cfg에 저장하고, 바뀌면 바로 적용한다.
## 화면·소리처럼 전역인 것은 여기서 적용하고, 플레이어·환경처럼 장면에 있는 것은 changed 신호를 받아 각자 적용한다.
extends Node

signal changed

const PATH := "user://settings.cfg"

const WINDOW_SIZES := [Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1920, 1080), Vector2i(2560, 1440)]
const QUALITY_NAMES := ["낮음", "보통", "높음"]
const HINT_NAMES := ["끄기", "기본", "빠르게"]

## 기본값. 키 이름이 곧 저장 이름이다.
const DEFAULTS := {
	"mouse_sensitivity": 1.0,   # 배수
	"invert_y": false,
	"fov": 75.0,
	"fullscreen": false,
	"window_size": 1,           # WINDOW_SIZES 번호
	"vsync": true,
	"quality": 2,               # 0 낮음, 1 보통, 2 높음
	"brightness": 1.0,
	"volume_master": 0.8,
	"volume_sfx": 1.0,
	"hints": 1,                 # 0 끄기, 1 기본, 2 빠르게
	"head_bob": true,
	"film_grain": true,
	"crosshair": false,
}

var values := {}


func _ready() -> void:
	values = DEFAULTS.duplicate()
	var cfg := ConfigFile.new()
	if cfg.load(PATH) == OK:
		for k in DEFAULTS:
			values[k] = cfg.get_value("settings", k, DEFAULTS[k])
	# 테스트나 스크린샷 촬영이 창 크기를 정했으면 그대로 둔다
	_apply_global(not _window_given_on_command_line())


func get_value(key: String) -> Variant:
	return values.get(key, DEFAULTS.get(key))


func set_value(key: String, v: Variant) -> void:
	if values.get(key) == v:
		return
	values[key] = v
	_apply_global(key in ["fullscreen", "window_size"])
	_save()
	changed.emit()


func reset() -> void:
	values = DEFAULTS.duplicate()
	_apply_global(true)
	_save()
	changed.emit()


## 힌트 시간 배수 (0이면 힌트가 나오지 않는다)
func hint_scale() -> float:
	return [0.0, 1.0, 2.0][int(get_value("hints"))]


## 그래픽 품질을 환경에 적용한다 (레벨이 자기 Environment를 넘겨 준다).
func apply_environment(env: Environment) -> void:
	var q := int(get_value("quality"))
	env.ssr_enabled = q >= 2
	env.ssil_enabled = q >= 2
	env.ssao_enabled = q >= 1
	env.volumetric_fog_enabled = q >= 1
	env.glow_enabled = true
	env.adjustment_brightness = float(get_value("brightness"))
	var vp := get_viewport()
	vp.scaling_3d_scale = [0.67, 0.85, 1.0][q]
	vp.use_taa = q >= 1
	vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA if q == 0 else Viewport.SCREEN_SPACE_AA_DISABLED
	RenderingServer.directional_soft_shadow_filter_set_quality([RenderingServer.SHADOW_QUALITY_SOFT_VERY_LOW, RenderingServer.SHADOW_QUALITY_SOFT_LOW, RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM][q])
	RenderingServer.positional_soft_shadow_filter_set_quality([RenderingServer.SHADOW_QUALITY_SOFT_VERY_LOW, RenderingServer.SHADOW_QUALITY_SOFT_LOW, RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM][q])


func _apply_global(window_too: bool) -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if get_value("vsync") else DisplayServer.VSYNC_DISABLED)
	_set_bus_volume("Master", float(get_value("volume_master")))
	_set_bus_volume("Parking", float(get_value("volume_sfx")))
	if not window_too or DisplayServer.get_name() == "headless":
		return
	if get_value("fullscreen"):
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		var size: Vector2i = WINDOW_SIZES[clampi(int(get_value("window_size")), 0, WINDOW_SIZES.size() - 1)]
		DisplayServer.window_set_size(size)
		var screen := DisplayServer.screen_get_size()
		DisplayServer.window_set_position((screen - size) / 2)


func _set_bus_volume(bus: String, linear: float) -> void:
	var idx := AudioServer.get_bus_index(bus)
	if idx == -1:
		return
	AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(linear, 0.0001)))
	AudioServer.set_bus_mute(idx, linear <= 0.001)


## 효과음 버스는 레벨이 나중에 만든다. 만든 뒤에 불러서 음량을 다시 맞춘다.
func refresh_audio() -> void:
	_set_bus_volume("Parking", float(get_value("volume_sfx")))


func _save() -> void:
	var cfg := ConfigFile.new()
	for k in values:
		cfg.set_value("settings", k, values[k])
	cfg.save(PATH)


func _window_given_on_command_line() -> bool:
	for a in OS.get_cmdline_args():
		if a in ["--resolution", "--windowed", "--fullscreen", "--headless"] or a.begins_with("--resolution"):
			return true
	return false
