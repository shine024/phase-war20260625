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
// R6-1 色盲辅助滤镜（F-18）：0=关 1=红色弱(protan) 2=绿色弱(deutan) 3=蓝黄(tritan)。
// 独立于 enabled 开关——可及性滤镜不受调色总开关/PW_GRADE_OFF 影响。
// 算法 = 经典 Daltonize：Machado(2009) 模拟矩阵求视觉误差 → err2mod 重分布补偿回原图。
uniform float color_blind_mode : hint_range(0.0, 3.0) = 0.0;

vec3 cvd_simulate(vec3 c, float mode) {
	// Machado et al. 2009 线性 RGB 模拟矩阵（severity 1.0）
	if (mode < 1.5) { // protanopia
		return clamp(vec3(
			0.152286 * c.r + 1.052583 * c.g - 0.204868 * c.b,
			0.114503 * c.r + 0.786281 * c.g + 0.099216 * c.b,
			-0.003882 * c.r - 0.048116 * c.g + 1.051998 * c.b), vec3(0.0), vec3(1.0));
	} else if (mode < 2.5) { // deuteranopia
		return clamp(vec3(
			0.367322 * c.r + 0.860646 * c.g - 0.227968 * c.b,
			0.280085 * c.r + 0.672501 * c.g + 0.047413 * c.b,
			-0.011820 * c.r + 0.042940 * c.g + 0.968881 * c.b), vec3(0.0), vec3(1.0));
	}
	return clamp(vec3( // tritanopia
		1.255528 * c.r - 0.076749 * c.g - 0.178779 * c.b,
		-0.078411 * c.r + 0.930809 * c.g + 0.147602 * c.b,
		0.004733 * c.r + 0.691367 * c.g + 0.303900 * c.b), vec3(0.0), vec3(1.0));
}

vec3 daltonize(vec3 c, float mode) {
	vec3 err = c - cvd_simulate(c, mode);
	vec3 corrected;
	if (mode < 1.5) { // protan：红轴误差重分布进 G/B
		corrected = c + vec3(0.0, 0.7 * err.r + err.g, 0.7 * err.r + err.b);
	} else if (mode < 2.5) { // deutan：绿轴误差压进 B
		corrected = c + vec3(0.0, err.g, 0.75 * err.g + err.b);
	} else { // tritan：蓝轴误差压进 R/G
		corrected = c + vec3(err.r + 0.7 * err.b, err.g + 0.7 * err.b, err.b);
	}
	return clamp(corrected, vec3(0.0), vec3(1.0));
}

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
	// 色盲辅助：独立于调色 enabled（可及性开关不受 PW_GRADE_OFF/调色总开关影响）
	if (color_blind_mode > 0.5) {
		col = daltonize(clamp(col, vec3(0.0), vec3(1.0)), color_blind_mode);
	}
	COLOR = vec4(clamp(col, vec3(0.0), vec3(1.0)), 1.0);
}
