shader_type canvas_item;
// 全局调色后期层（ColorGrade autoload 专用，全屏 ColorRect 载体）。
// 统一"摄影层"：饱和度 / S 曲线对比 / 阴影-高光分离色调（时代色温）/ 暗角 / 细颗粒抑带。
// 参数全部由 managers/color_grade.gd 的预设表驱动，shader 不含任何业务常量。
// A/B 对比：设环境变量 PW_GRADE_OFF=1 可整体旁路（截图对比用）。

uniform sampler2D screen_tex : hint_screen_texture, filter_linear, repeat_disable;
uniform float enabled : hint_range(0.0, 1.0) = 1.0;
uniform float saturation : hint_range(0.0, 2.0) = 1.06;
uniform float contrast : hint_range(0.5, 1.6) = 1.05;
uniform float brightness : hint_range(0.5, 1.5) = 1.0;
// 阴影/高光分离乘色：暗部染 shadow_tint、亮部染 highlight_tint，tint_balance 控制掺量
uniform vec3 shadow_tint = vec3(1.0, 0.99, 0.97);
uniform vec3 highlight_tint = vec3(1.0, 1.0, 1.0);
uniform float tint_balance : hint_range(0.0, 1.0) = 0.25;
uniform float vignette_strength : hint_range(0.0, 1.0) = 0.10;
uniform float grain_amount : hint_range(0.0, 0.1) = 0.010;

void fragment() {
	vec3 col = texture(screen_tex, SCREEN_UV).rgb;
	if (enabled > 0.5) {
		float lum = dot(col, vec3(0.299, 0.587, 0.114));
		// 饱和度（围绕亮度重投影）
		col = mix(vec3(lum), col, saturation);
		// 分离色调：暗部/亮部各自乘色温（乘法保持亮度结构，不会发灰）
		float shadow_w = 1.0 - smoothstep(0.0, 0.62, lum);
		float high_w = smoothstep(0.42, 1.0, lum);
		col *= mix(vec3(1.0), shadow_tint, shadow_w * tint_balance);
		col *= mix(vec3(1.0), highlight_tint, high_w * tint_balance);
		// 对比：向 smoothstep S 曲线收敛（contrast>1 才掺入，1.0 时零操作）
		col = clamp(col, vec3(0.0), vec3(1.0));
		vec3 s_curve = col * col * (3.0 - 2.0 * col);
		col = mix(col, s_curve, clamp((contrast - 1.0) * 2.2, 0.0, 1.0));
		col *= brightness;
		// 暗角（角部渐入，不动中心 60% 画面）
		vec2 d = SCREEN_UV - vec2(0.5);
		float vig = 1.0 - vignette_strength * smoothstep(0.34, 0.98, length(d) * 1.414);
		col *= vig;
		// 细颗粒（微幅抖动，压暗部色带 + 胶片感；随 TIME 缓动）
		float n = fract(sin(dot(SCREEN_UV * vec2(1234.5, 6789.1) + fract(TIME) * 7.13, vec2(12.9898, 78.233))) * 43758.5453);
		col += (n - 0.5) * grain_amount;
	}
	COLOR = vec4(clamp(col, vec3(0.0), vec3(1.0)), 1.0);
}
