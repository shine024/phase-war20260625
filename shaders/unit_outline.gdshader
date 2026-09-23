shader_type canvas_item;

// 战场单位深色描边（v26.9）——alpha 膨胀（8 向 × 3 环取样），把卡图轮廓从背景里分离。
// 修复：沙漠亮底上我方灰褐卡图与背景同明度，无描边时轮廓融化（实测本体/背景亮度差仅 30-60）。
//
// 半透明像素保护：ca（中心 alpha）较高的像素（图内软阴影/烟雾/玻璃）保持原观感，
// 只在接近全透明的轮廓带外扩加暗边——避免把卡图自带的软性元素涂成实心深色。
//
// region_uv：当前纹理可用 UV 区。雪碧图帧动画（AtlasTexture 横条）= 当前帧区域，
// 越区取样一律视为透明——否则膨胀会采到相邻帧的轮廓，在透明区飘鬼影。
// 整图贴图保持默认 (0,0,1,1)。两项 uniform 由 UnitOutline.refresh 维护（换贴图/scale 后必须刷新）。

uniform vec4 outline_color : source_color = vec4(0.05, 0.07, 0.11, 0.85);
uniform float edge_texels = 10.0; // 描边半径（当前纹理纹素数）= 目标屏幕像素宽 / spr.scale.x
uniform vec4 region_uv = vec4(0.0, 0.0, 1.0, 1.0);
// v6.15 打击感：受击剪影推白（0=常态 1=全白）。驱动方=UnitOutline.set_flash（材质为每
// sprite 独立实例，写 uniform 不串单位）。旧 modulate 1.8 乘法增亮推不白深色卡图
// （军绿/沙褐像素 0.3×1.8 仍是暗色），此 uniform 直接把剪影全像素向白 mix。
uniform float flash_strength : hint_range(0.0, 1.0) = 0.0;

// ⚠️ Godot 4 canvas_item 语义：fragment() 入口的 COLOR 已 = 顶点色×纹理色
// （官方文档："COLOR from the vertex() function multiplied by the TEXTURE color"）。
// 要让 modulate（受击闪白/死亡淡出）同步作用于描边，必须在 vertex() 捕获纯顶点色——
// 在 fragment 里再乘 COLOR 会把纹理二次叠乘：外扩描边带 alpha 归零（描边画不出）、
// 不透明像素 rgb 被平方（整体变暗）。像素级回归锁：tests/_tmp_outline_pixel_check.gd。
varying vec4 v_modulate;

void vertex() {
	v_modulate = COLOR;
}

void fragment() {
	vec4 col = texture(TEXTURE, UV);
	float ca = col.a;
	vec2 step_px = TEXTURE_PIXEL_SIZE * edge_texels;
	float oa = 0.0; // 膨胀后的邻域 alpha
	for (int i = 0; i < 8; i++) {
		float ang = float(i) * 0.785398163; // PI/4，8 向
		vec2 dir = vec2(cos(ang), sin(ang));
		for (int r = 1; r <= 3; r++) {
			vec2 suv = UV + dir * step_px * (float(r) / 3.0);
			if (suv.x < region_uv.x || suv.x > region_uv.z || suv.y < region_uv.y || suv.y > region_uv.w) {
				continue; // 越出当前帧区域=透明（防雪碧图相邻帧串味）
			}
			oa = max(oa, texture(TEXTURE, suv).a);
		}
	}
	float keep = smoothstep(0.02, 0.38, ca); // 较实的像素不描边（保软阴影/半透明部件）
	float added = oa * outline_color.a * (1.0 - keep);
	float out_a = max(ca, added);
	vec3 rgb = mix(outline_color.rgb, col.rgb, smoothstep(0.0, 0.5, ca));
	// v6.15：按最终剪影 alpha（本体+描边带）向白 mix——整个剪影含描边一起推白，
	// 命中读"白剪影一闪"（DR/Metal Slug 同款打击语言）
	rgb = mix(rgb, vec3(1.0), flash_strength * smoothstep(0.01, 0.2, out_a));
	COLOR = vec4(rgb, out_a) * v_modulate; // v_modulate=vertex() 捕获的纯 modulate（受击闪白/死亡淡出同步作用于描边）
}
