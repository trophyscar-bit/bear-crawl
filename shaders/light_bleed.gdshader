shader_type canvas_item;
render_mode blend_add;

// Screen-space light "bleed" GI — gathers nearby BRIGHT (lit) pixels and ADDS
// their colour as a soft glow, faking indirect light bounce off the lit stone.
// Additive blend means it can only ADD light — it can never black out or break
// the base image even if the screen texture isn't ready.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float bleed : hint_range(0.0, 2.0) = 0.6;
uniform float radius : hint_range(0.0, 0.08) = 0.03;
uniform float threshold : hint_range(0.0, 1.0) = 0.3;

void fragment() {
	vec3 acc = vec3(0.0);
	float wsum = 0.0001;
	for (int i = 0; i < 20; i++) {
		float a = (float(i) + 0.5) / 20.0 * 6.28318530718;
		float ring = 0.45 + mod(float(i), 4.0) * 0.35;
		vec2 off = vec2(cos(a), sin(a)) * radius * ring;
		vec3 s = texture(screen_tex, SCREEN_UV + off).rgb;
		float b = max(s.r, max(s.g, s.b));
		float w = smoothstep(threshold, 1.0, b) / (1.0 + ring * 1.6);
		acc += s * w;
		wsum += w;
	}
	COLOR = vec4((acc / wsum) * bleed, 1.0);
}
