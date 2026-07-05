shader_type canvas_item;
// 圆形头像遮罩（v7.x 剧情对话面板美化）
// 将方形纹理裁切成正圆，配合徽章的角色色描边与外发光使用。
// 无论源图是 200×200 还是 512×512，经 TextureRect cover 填充后都渲染为统一圆形。
// 边缘用 smoothstep 做 2px 抗锯齿过渡，避免硬边锯齿。
void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float d = distance(UV, vec2(0.5));
	float mask = 1.0 - smoothstep(0.48, 0.5, d); // 0.48~0.5 区间软过渡
	COLOR = vec4(c.rgb, c.a * mask);
}
