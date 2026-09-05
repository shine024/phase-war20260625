shader_type canvas_item;
// CRT 扫描线覆盖层：细横向暗线（统计终端磷光屏质感），只输出暗线 alpha
uniform float line_alpha : hint_range(0.0, 1.0) = 0.13;
uniform float line_count = 220.0;

void fragment() {
	float band = fract(UV.y * line_count);
	float a = line_alpha * (1.0 - smoothstep(0.0, 0.45, band));
	COLOR = vec4(0.0, 0.0, 0.0, a);
}
