// RuneCraft screen post-process (GL Compatibility): soft vignette tinted towards a cool night
// colour, gentle warm/cool split toning and a little extra contrast. Put a full-rect ColorRect
// with this shader in a CanvasLayer above the 3D view.
shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float vignette_strength : hint_range(0.0, 1.0) = 0.32;
uniform float vignette_radius : hint_range(0.2, 1.2) = 0.78;
uniform float vignette_softness : hint_range(0.05, 1.0) = 0.55;
uniform vec3 vignette_tint : source_color = vec3(0.16, 0.18, 0.32);
uniform vec3 shadow_tone : source_color = vec3(0.92, 0.96, 1.06);
uniform vec3 highlight_tone : source_color = vec3(1.04, 1.01, 0.96);
uniform float contrast : hint_range(0.8, 1.3) = 1.06;

void fragment() {
	vec3 c = texture(screen_tex, SCREEN_UV).rgb;
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	c *= mix(shadow_tone, highlight_tone, smoothstep(0.2, 0.8, l));      // split toning
	c = (c - 0.5) * contrast + 0.5;                                        // contrast around mid grey
	vec2 d = (SCREEN_UV - 0.5) * vec2(1.0, 0.85);
	float v = smoothstep(vignette_radius, vignette_radius - vignette_softness, length(d) * 1.4142);
	c = mix(c * vignette_tint * 2.2, c, mix(1.0 - vignette_strength, 1.0, v));
	COLOR = vec4(clamp(c, 0.0, 1.0), 1.0);
}
