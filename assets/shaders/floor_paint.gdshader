// 바닥에 칠한 선과 화살표. 오래돼서 군데군데 벗겨진 페인트.
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled;

uniform vec3 paint_color : source_color = vec3(0.9, 0.9, 0.87);
uniform sampler2D noise_tex : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform float wear = 0.35;      // 0이면 새 페인트, 1이면 거의 다 벗겨짐

varying vec3 w_pos;

void vertex() {
	w_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float big = texture(noise_tex, w_pos.xz * 0.11).g;
	float fine = texture(noise_tex, w_pos.xz * 1.7).b;
	float tire = texture(noise_tex, vec2(w_pos.x * 0.05, w_pos.z * 0.9)).a;  // 차가 지나다닌 방향으로 닳음
	float keep = big * 0.55 + fine * 0.3 + tire * 0.15;
	if (keep < wear * 0.85) {
		discard;
	}
	float dirt = texture(noise_tex, w_pos.xz * 0.5).g;
	ALBEDO = paint_color * (0.78 + 0.22 * dirt);
	ROUGHNESS = 0.55 + 0.25 * fine;
	SPECULAR = 0.5;
}
