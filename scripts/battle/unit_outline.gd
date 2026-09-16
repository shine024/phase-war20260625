extends RefCounted
class_name UnitOutline

## v26.9 战场单位深色描边——alpha 膨胀 shader，卡图轮廓从背景分离。
## 修复：沙漠亮底上我方灰褐卡图与背景同明度融合（本体/背景亮度差仅 30-60）。
##
## ⚠️ 契约：两项 uniform 依赖"当前贴图 × 当前 scale"，凡运行期改动二者必须调 refresh()：
##   - edge_texels = OUTLINE_PX / spr.scale.x——帧动画 attach 有 scale×2 尺寸补偿，不刷新则描边翻倍
##   - region_uv——雪碧图帧动画换 AtlasTexture 后收敛到当前帧区域，不刷新则取样越帧出鬼影
## 已接入 refresh 的换贴图点：UnitFrameAnim.FrameDriver（idle/attack 换帧+尺寸补偿）、
## BossIdleAnim.FrameDriver（boss 换帧）。AttackPoseAnim 攻击帧=同分辨率整图，无需刷新。
## 新增任何 unit_spr.texture / scale 直写点，同步接 refresh，否则描边宽度/区域失真。

const SHADER := preload("res://shaders/unit_outline.gdshader")
const OUTLINE_PX := 1.6  # 目标描边宽（屏幕像素），全单位一致

## 单位呈现时挂材质（幂等：重复呈现复用已有材质，只刷 uniform）
## v6.15: skip_pre_baked=true 时直接跳过——该单位雪碧图已在发布管线预烘焙描边
##（deploy_unit_anims.py → anim.json outline.baked），再挂 shader 会二次外扩（描边翻倍）。
static func apply(spr: Sprite2D, skip_pre_baked := false) -> void:
	if spr == null or skip_pre_baked:
		return
	var mat := spr.material as ShaderMaterial
	if mat == null or mat.shader != SHADER:
		mat = ShaderMaterial.new()
		mat.shader = SHADER
		spr.material = mat
	refresh(spr)


## 换贴图 / scale 变化后重算 uniform（见类头契约）
## v27.12 perf: uniform 值缓存于材质 meta——换帧 tick（8-24Hz/单位全场）时 scale/region
## 未变则跳过 uniform 写（同分辨率帧序列两项恒定，boss 帧动画原每帧白写 2 次 uniform）。
## 缓存挂 ShaderMaterial（随材质生死），材质换挡自动失效，无泄漏。
static func refresh(spr: Sprite2D) -> void:
	if spr == null or spr.texture == null:
		return
	var mat := spr.material as ShaderMaterial
	if mat == null or mat.shader != SHADER:
		return
	var edge: float = OUTLINE_PX / maxf(absf(spr.scale.x), 0.0001)
	var tex := spr.texture
	var uv: Vector4 = Vector4(0.0, 0.0, 1.0, 1.0)
	var uv_valid := true
	if tex is AtlasTexture:
		var at := tex as AtlasTexture
		var sheet: Texture2D = at.atlas
		if sheet != null:
			var sw: float = maxf(float(sheet.get_width()), 1.0)
			var sh: float = maxf(float(sheet.get_height()), 1.0)
			var r := at.region
			uv = Vector4(
				r.position.x / sw, r.position.y / sh,
				(r.position.x + r.size.x) / sw, (r.position.y + r.size.y) / sh)
		else:
			uv_valid = false  # 原行为：atlas 缺失时不写 region_uv
	if uv_valid and bool(mat.get_meta("_outline_clean", false)) \
			and is_equal_approx(float(mat.get_meta("_outline_edge", -1.0)), edge) \
			and (mat.get_meta("_outline_uv", Vector4(-1.0, -1.0, -1.0, -1.0)) as Vector4) == uv:
		return
	mat.set_shader_parameter("edge_texels", edge)
	if uv_valid:
		mat.set_shader_parameter("region_uv", uv)
		mat.set_meta("_outline_edge", edge)
		mat.set_meta("_outline_uv", uv)
		mat.set_meta("_outline_clean", true)
