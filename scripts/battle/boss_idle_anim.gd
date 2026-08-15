extends RefCounted
class_name BossIdleAnim

## ============================================================
## v14/P2: boss/相位师专属待机帧动画
##
## 帧资产约定(给 agnes-image 流水线,详见 docs/BOSS_IDLE_ANIM_SPEC.md):
##   res://assets/effects/unit_anims/<unit_id>/idle_f0.png ~ idle_f5.png
##   512×512 透明底,与对应卡图同构图,逐帧仅细微动作差(悬浮/炮管/披风)。
##
## 设计要点:
##   - 帧切换直接换 unit_spr.texture —— 不新建 AnimatedSprite2D。
##     原因:军衔条/稀有度角标/枪口锚点/受击闪白/开火脉冲/战场痕迹都挂在
##     unit_spr 这一个节点上,换节点会把这些系统全部断链;换贴图零侵入。
##   - 帧贴图必须与静态卡图同分辨率(归一化缩放按纹理宽度算,分辨率不同会跳尺寸)。
##   - <2 帧 → 返回 false,调用方走程序化待机 fallback,零依赖。
##   - motion_reduce 时不启用(帧动画属装饰性运动)。
## ============================================================

const ANIM_ROOT := "res://assets/effects/unit_anims/"
const MAX_FRAMES: int = 8
const DEFAULT_FPS := 6.0


## 尝试给单位挂待机帧动画。成功返回 true。
## [param unit_id] 卡图 id(enemy_master_XXX / boss_*)——同时是帧目录名。
static func attach(unit_spr: Sprite2D, unit_id: String, fps: float = DEFAULT_FPS) -> bool:
	if unit_spr == null or unit_id.is_empty():
		return false
	var dt := preload("res://resources/design_tokens.gd")
	if dt.is_motion_reduce():
		return false
	# 已挂过(重挂表现)则直接复用
	var existing: Node = unit_spr.get_node_or_null("BossIdleFrameDriver")
	if existing != null:
		return true
	var frames: Array = []
	for i in range(MAX_FRAMES):
		var p := ANIM_ROOT + unit_id + "/idle_f%d.png" % i
		if not ResourceLoader.exists(p):
			break
		var t: Texture2D = load(p)
		if t == null:
			break
		frames.append(t)
	if frames.size() < 2:
		return false
	var driver := FrameDriver.new()
	driver.name = "BossIdleFrameDriver"
	driver.frames = frames
	driver.fps = fps
	unit_spr.add_child(driver)
	return true


## 帧驱动器:轻量 _process 计时换 texture(挂在 unit_spr 下,随单位销毁)。
class FrameDriver extends Node:
	var frames: Array = []
	var fps: float = 6.0
	var _t: float = 0.0
	var _idx: int = 0
	var _spr: Sprite2D = null

	func _process(delta: float) -> void:
		if _spr == null:
			_spr = get_parent() as Sprite2D
			if _spr == null:
				return
		_t += delta
		if _t < 1.0 / maxf(fps, 0.1):
			return
		_t = 0.0
		_idx = (_idx + 1) % frames.size()
		_spr.texture = frames[_idx]
