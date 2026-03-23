shader_type canvas_item;

uniform float time_scale : hint_range(0.1, 5.0) = 0.5;
uniform float color_intensity : hint_range(0.1, 2.0) = 0.8;
uniform float plasma_scale : hint_range(1.0, 20.0) = 8.0;

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

    // Smooth color cycling — no quantization
    float r = sin(v * 3.14159 + t * 0.2) * 0.5 + 0.5;
    float g = sin(v * 3.14159 + t * 0.35 + 2.094) * 0.5 + 0.5;
    float b = sin(v * 3.14159 + t * 0.5 + 4.188) * 0.5 + 0.5;

    // Smooth blend with slight darkening for depth
    float brightness = 0.7 + 0.3 * sin(v * 2.0 + t * 0.3);

    COLOR = vec4(r * color_intensity * brightness, g * color_intensity * brightness, b * color_intensity * brightness, 1.0);
}
