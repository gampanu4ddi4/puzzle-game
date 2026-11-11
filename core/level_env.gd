## 장면 공통: 환경(조명, 안개, 색감)과 화면 효과.
class_name LevelEnv
extends RefCounted

const SHADER_POST := preload("res://assets/shaders/post_fx.gdshader")

enum GI { SDFGI, BAKED }


## gi = SDFGI: 실시간 간접광. 편하지만 카메라 위치를 따라 계산이 쌓이므로,
##   순간이동하는 반복 공간에서는 순간이동 직후 밝기가 출렁인다.
## gi = BAKED: VoxelGI 등 미리 구운 간접광을 쓴다 (반복 공간용). 여기서는 SDFGI만 끈다.
static func create(parent: Node, gi: GI = GI.SDFGI) -> WorldEnvironment:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color.BLACK
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("1d221f")
	env.ambient_light_energy = 0.35

	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = 1.05

	if gi == GI.SDFGI:
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
	# 시간 누적을 끈다: 순간이동 직후 안개가 번지는 것을 막는다
	env.volumetric_fog_temporal_reprojection_enabled = gi == GI.SDFGI

	env.adjustment_enabled = true
	env.adjustment_contrast = 1.04
	env.adjustment_saturation = 0.82

	var we := WorldEnvironment.new()
	we.name = "WorldEnvironment"
	we.environment = env
	parent.add_child(we)
	return we


static func add_post_fx(parent: Node) -> void:
	var layer := CanvasLayer.new()
	layer.name = "PostFX"
	layer.layer = 10
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m := ShaderMaterial.new()
	m.shader = SHADER_POST
	rect.material = m
	layer.add_child(rect)
	parent.add_child(layer)


static func arg_value(key: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with(key + "="):
			return a.substr(key.length() + 1)
		if a == key:
			return "1"
	return ""
