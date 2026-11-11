// 콘크리트 삼면 투영 셰이더.
// UV 없이 월드 좌표로 텍스처를 입혀서, 모듈 부품끼리 이음매 없이 이어진다.
// 칠한 띠(벽 아래 초록), 바닥 근처 때, 흘러내린 자국, 바닥 물웅덩이를 한 셰이더에서 처리한다.
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rough_tex : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D noise_tex : hint_default_white, filter_linear_mipmap, repeat_enable;

uniform float tile_meters = 4.0;            // 텍스처 한 장이 덮는 길이(m)
uniform vec3 tint : source_color = vec3(1.0);
uniform float normal_strength = 1.0;
uniform float macro_variation = 0.12;        // 넓은 범위의 밝기 얼룩

uniform float band_height = -1.0;            // 이 높이 아래를 칠한다. 음수면 띠 없음
uniform vec3 band_color : source_color = vec3(0.30, 0.48, 0.36);
uniform float band_line = 0.05;              // 띠 위 경계선 두께(m)
uniform vec3 band_line_color : source_color = vec3(0.85, 0.72, 0.2);

uniform float grime_height = 0.35;           // 바닥에서 이 높이까지 때가 탄다
uniform float grime_strength = 0.0;
uniform float streak_strength = 0.0;         // 위에서 흘러내린 자국

uniform float puddle_amount = 0.0;           // 0~1, 바닥 물웅덩이 양
uniform float floor_level = 0.0;
uniform float floor_slope = 0.0;             // 경사로: X가 slope_start_x를 넘으면 바닥 높이가 이만큼씩 오른다
uniform float slope_start_x = 0.0;
uniform vec3 slope_dir = vec3(1.0, 0.0, 0.0);    // 경사로가 올라가는 방향 (돌려 놓은 층이면 함께 돈다)

uniform float joint_spacing = 0.0;           // 바닥 줄눈 간격(m). 0이면 없음
uniform float joint_width = 0.012;

// 층 원점. 같은 층을 여러 벌 놓아도 무늬가 똑같이 나오도록 이 점을 기준으로 텍스처를 입힌다.
uniform vec3 world_offset = vec3(0.0);

varying vec3 w_pos;
varying vec3 w_nrm;

void vertex() {
	w_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz - world_offset;
	w_nrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

vec3 unpack_n(vec4 t) {
	vec3 n = t.xyz * 2.0 - 1.0;
	n.xy *= normal_strength;
	return n;
}

void fragment() {
	vec3 n = normalize(w_nrm);
	vec3 blend = pow(abs(n), vec3(4.0));
	blend /= (blend.x + blend.y + blend.z);
	vec3 s = sign(n);
	vec3 p = w_pos / tile_meters;

	// 면마다 UV (뒤집힌 면의 좌우를 맞춘다)
	vec2 uv_x = vec2(p.z * s.x, p.y);
	vec2 uv_y = vec2(p.x * s.y, p.z);
	vec2 uv_z = vec2(-p.x * s.z, p.y);

	vec3 alb = texture(albedo_tex, uv_x).rgb * blend.x
		+ texture(albedo_tex, uv_y).rgb * blend.y
		+ texture(albedo_tex, uv_z).rgb * blend.z;
	float rough = texture(rough_tex, uv_x).r * blend.x
		+ texture(rough_tex, uv_y).r * blend.y
		+ texture(rough_tex, uv_z).r * blend.z;

	// 화이트아웃 방식의 삼면 노멀 합성 (월드 공간)
	vec3 tnx = unpack_n(texture(normal_tex, uv_x));
	vec3 tny = unpack_n(texture(normal_tex, uv_y));
	vec3 tnz = unpack_n(texture(normal_tex, uv_z));
	tnx.x *= s.x;
	tny.x *= s.y;
	tnz.x *= -s.z;
	tnx = vec3(tnx.xy + n.zy, abs(tnx.z) * n.x);
	tny = vec3(tny.xy + n.xz, abs(tny.z) * n.y);
	tnz = vec3(tnz.xy + n.xy, abs(tnz.z) * n.z);
	vec3 wn = normalize(tnx.zyx * blend.x + tny.xzy * blend.y + tnz.xyz * blend.z);

	// 넓은 범위 얼룩
	vec4 macro = texture(noise_tex, (w_pos.xz + w_pos.y * 0.37) * 0.035);
	alb *= tint * (1.0 + (macro.r - 0.5) * 2.0 * macro_variation);

	// 칠한 띠
	float h = w_pos.y - floor_level - max(dot(w_pos, slope_dir) - slope_start_x, 0.0) * floor_slope;
	if (band_height > 0.0) {
		float lum = dot(alb, vec3(0.333));
		float in_band = 1.0 - step(band_height, h);
		float on_line = step(band_height, h) * (1.0 - step(band_height + band_line, h));
		vec3 paint = band_color * (0.75 + 0.35 * lum);
		alb = mix(alb, paint, in_band);
		alb = mix(alb, band_line_color * (0.8 + 0.3 * lum), on_line);
		rough = mix(rough, rough * 0.8, in_band + on_line);
	}

	// 바닥 근처 때 (벽, 기둥)
	float vert = 1.0 - blend.y;
	if (grime_strength > 0.0) {
		float g = 1.0 - smoothstep(0.0, grime_height, h);
		float gn = texture(noise_tex, vec2(w_pos.x + w_pos.z, h * 3.0) * 0.4).g;
		alb *= 1.0 - grime_strength * g * (0.5 + gn) * vert;
	}

	// 흘러내린 자국 (세로로 늘어난 노이즈)
	if (streak_strength > 0.0) {
		float st = texture(noise_tex, vec2((w_pos.x + w_pos.z) * 0.35, w_pos.y * 0.06)).a;
		float top = smoothstep(0.6, 2.6, h);
		alb *= 1.0 - streak_strength * smoothstep(0.55, 0.85, st) * top * vert;
	}

	// 바닥 줄눈 (콘크리트를 잘라 놓은 선, 때가 끼어 어둡다)
	if (joint_spacing > 0.0) {
		float up_j = smoothstep(0.85, 0.95, n.y);
		vec2 g = abs(fract(w_pos.xz / joint_spacing + 0.5) - 0.5) * joint_spacing;
		float dist = min(g.x, g.y);
		float line = 1.0 - smoothstep(joint_width * 0.5, joint_width, dist);
		float halo = 1.0 - smoothstep(joint_width, joint_width * 6.0, dist);
		alb *= 1.0 - up_j * (0.55 * line + 0.08 * halo);
		rough = mix(rough, 1.0, line * up_j);
	}

	// 바닥 물웅덩이: 어둡고 매끈하고 평평하다
	if (puddle_amount > 0.0) {
		float up = smoothstep(0.85, 0.95, n.y);
		float pn = texture(noise_tex, w_pos.xz * 0.045).r * 0.75 + texture(noise_tex, w_pos.xz * 0.21).g * 0.25;
		float wet = smoothstep(1.0 - puddle_amount, 1.0 - puddle_amount + 0.06, pn) * up;
		float damp = smoothstep(1.0 - puddle_amount - 0.12, 1.0 - puddle_amount, pn) * up;
		alb *= mix(1.0, 0.72, damp);
		alb *= mix(1.0, 0.85, wet);
		rough = mix(rough, rough * 0.6, damp);
		rough = mix(rough, 0.04, wet);
		wn = normalize(mix(wn, n, wet));
	}

	ALBEDO = alb;
	ROUGHNESS = clamp(rough, 0.02, 1.0);
	METALLIC = 0.0;
	SPECULAR = 0.45;
	NORMAL = normalize((VIEW_MATRIX * vec4(wn, 0.0)).xyz);
}
