shader_type canvas_item;

// Soft drifting fog, anchored to the WORLD (not the screen) so it scrolls past
// as the camera moves instead of following the player. Samples a smooth tileable
// cloud-noise texture in world space at two scales, plus a very slow drift.

uniform sampler2D noise_tex : filter_linear, repeat_enable;
uniform float density : hint_range(0.0, 0.6) = 0.06;
uniform vec3 fog_color : source_color = vec3(0.55, 0.57, 0.66);
uniform vec2 cam_pos = vec2(0.0);      // camera world position (px)
uniform vec2 vp = vec2(1152.0, 648.0); // viewport size (px)

void fragment() {
	// World position of this screen pixel (camera is centred).
	vec2 world = cam_pos + (SCREEN_UV - vec2(0.5)) * vp;
	vec2 uv = world * 0.0011;   // world px -> noise uv
	float n1 = texture(noise_tex, uv * 1.0 + vec2(TIME * 0.004, TIME * 0.002)).r;
	float n2 = texture(noise_tex, uv * 2.0 - vec2(TIME * 0.003, TIME * 0.0015)).r;
	float n = n1 * 0.62 + n2 * 0.38;
	float a = density * smoothstep(0.2, 0.92, n);
	COLOR = vec4(fog_color, clamp(a, 0.0, 1.0));
}
