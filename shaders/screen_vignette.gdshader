shader_type canvas_item;
// 全屏暗角：边缘压暗，把视线收进画面中心（移动基地氛围层）
uniform float strength : hint_range(0.0, 1.0) = 0.40;
uniform float softness : hint_range(0.1, 1.0) = 0.55;

void fragment() {
	vec2 uv = UV - vec2(0.5);
	uv.x *= 1.25; // 横向略宽，适配 16:9
	float d = length(uv);
	float a = smoothstep(1.0 - softness, 1.0, d) * strength;
	COLOR = vec4(0.0, 0.0, 0.02, a);
}
