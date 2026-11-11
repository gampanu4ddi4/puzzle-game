// 화면 효과: 옛 디지털카메라 느낌 (필름 그레인, 비네팅, 약한 색 번짐).
shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float grain = 0.035;
uniform float vignette = 0.45;
uniform float aberration = 0.0025;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 d = uv - 0.5;
	float r = texture(screen_tex, uv + d * aberration).r;
	float g = texture(screen_tex, uv).g;
	float b = texture(screen_tex, uv - d * aberration).b;
	vec3 c = vec3(r, g, b);
	c *= 1.0 - vignette * dot(d, d) * 1.6;
	float n = hash(floor(uv / SCREEN_PIXEL_SIZE) + fract(TIME * 7.0) * vec2(113.0, 71.0)) - 0.5;
	float lum = dot(c, vec3(0.299, 0.587, 0.114));
	c += n * grain * (0.4 + 0.6 * (1.0 - lum));   // 어두운 곳에 더 강하게
	COLOR = vec4(c, 1.0);
}
