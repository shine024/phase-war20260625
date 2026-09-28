shader_type canvas_item;
// v27 黑门无尽：彼岸空间微扭曲——"暗物质扭曲着空间"（docs/开场文本.md）。
// 仅由 battlefield.gd 在无尽模式挂到背景 Sprite（Level10Background）的 material 上，
// 普通关卡零影响；单位/弹道等节点不挂本材质（v26.9 可读性契约）。
// 振幅/流速由 endless_rift_ambience.gd 按渗度驱动；UV 末尾 clamp 防边缘越界采样。
uniform float warp_amplitude : hint_range(0.0, 0.02) = 0.0; // UV 振幅（0.003 ≈ 4px @1280 宽）
uniform float warp_speed : hint_range(0.0, 2.0) = 0.35;
uniform float time_acc = 0.0;
// v6.34: 每 run 随机色调滤镜(0=关;battlefield 按 EBM 裂隙环境/roll 注入,同场恒定)
uniform vec3 run_tint = vec3(1.0); // 乘法色调(每通道 0.75~1.15 微偏)
uniform float tint_enabled : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec2 uv = UV;
	float t = time_acc * warp_speed;
	uv.x += sin(uv.y * 9.0 + t * 2.1) * warp_amplitude;
	uv.y += sin(uv.x * 6.0 - t * 1.3) * warp_amplitude * 0.6;
	vec4 tex_color = texture(TEXTURE, clamp(uv, vec2(0.0), vec2(1.0)));
	COLOR = vec4(tex_color.rgb * mix(vec3(1.0), run_tint, tint_enabled), tex_color.a);
}
