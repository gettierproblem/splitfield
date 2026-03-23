shader_type canvas_item;

uniform float time_scale : hint_range(0.1, 5.0) = 0.5;
uniform float color_intensity : hint_range(0.1, 2.0) = 0.8;
uniform float plasma_scale : hint_range(1.0, 20.0) = 8.0;
uniform vec4 color_a : source_color = vec4(0.25, 0.04, 0.02, 1.0);
uniform vec4 color_b : source_color = vec4(0.08, 0.02, 0.02, 1.0);

void fragment() {
    float t = TIME * time_scale;
    vec2 uv = UV * plasma_scale;

    // Layered plasma for smooth organic feel
    float v1 = sin(uv.x * 1.2 + t * 0.9);
    float v2 = sin(uv.y * 1.1 + t * 0.7);
    float v3 = sin((uv.x + uv.y) * 0.7 + t * 0.5);
    float v4 = sin(length(uv - plasma_scale * 0.5) * 1.5 - t * 0.8);
    float v5 = sin(uv.x * 0.5 + uv.y * 1.3 + t * 0.6);

    float v = (v1 + v2 + v3 + v4 + v5) * 0.2;

    // Blend between the two level colors instead of full rainbow
    float blend = v * 0.5 + 0.5;
    vec3 base = mix(color_a.rgb, color_b.rgb, blend);

    // Add subtle color variation for visual interest
    float accent = sin(v * 3.14159 + t * 0.3) * 0.15;
    base += vec3(accent * 0.5, accent * 0.3, accent * 0.8);

    // Smooth blend with slight darkening for depth
    float brightness = 0.7 + 0.3 * sin(v * 2.0 + t * 0.3);

    COLOR = vec4(base * color_intensity * brightness, 1.0);
}
