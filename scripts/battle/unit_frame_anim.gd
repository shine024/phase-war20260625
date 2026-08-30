extends RefCounted
class_name UnitFrameAnim

## ============================================================
## v24.2: 敌我双方普通单位帧动画（idle ping-pong 往返 + attack 正向单次）——雪碧图版
##   敌方 sheet 原图朝左直接用; 我方 attach(face_right=true) → 驱动 flip_h 镜像成朝右。
##
## 资产约定（tools/deploy_unit_anims.py v2 部署）:
##   res://assets/effects/unit_anims/<unit_key>/sheet_idle.png   (N×256 横条)
##   res://assets/effects/unit_anims/<unit_key>/sheet_attack.png (M×256 横条)
##   res://assets/effects/unit_anims/<unit_key>/anim.json        {"fps":8,"frame_size":256,"counts":{...}}
##   源帧 512² 缩至 256² 拼条; 每单位 2 张 sheet（v1 逐帧 2200 PNG 已废弃）。
##
## 设计要点（沿用 BossIdleAnim v14 先例, 零断链）:
##   - 帧切换换 unit_spr.texture（AtlasTexture 指向 sheet 的区域切片）——
##     军衔条/枪口锚点/受击闪白/开火脉冲/空中悬空全挂 unit_spr, 不换节点。
##   - 尺寸补偿: 静态卡图 512², 帧 256² → attach 时 scale×2 / offset.y×0.5,
##     视觉大小与脚线锚定和静态图完全一致（无跳尺寸）。
##   - 运行时 id 兼容: archetype 带 foe_ 前缀 → 剥前缀查目录。
##   - motion_reduce 时不启用（帧动画属装饰性运动）。
##   - 回退: 删 assets/effects/unit_anims/<key>/ 即回静态卡图。
## ============================================================

const ANIM_ROOT := "res://assets/effects/unit_anims/"
const DRIVER_NAME := "UnitFrameAnimDriver"


static func _resolve_key(anim_id: String) -> String:
	## id → 资产目录名（剥 foe_ 前缀）; 有 sheet_idle 且带 anim.json 才算命中
	for cand in [anim_id, anim_id.trim_prefix("foe_")]:
		var c := String(cand)
		if not c.is_empty() \
				and ResourceLoader.exists(ANIM_ROOT + c + "/sheet_idle.png") \
				and ResourceLoader.exists(ANIM_ROOT + c + "/anim.json"):
			return c
	return ""


static func _load_json(path: String) -> Dictionary:
	var txt := FileAccess.get_file_as_string(path)
	if txt.is_empty():
		return {}
	var parsed = JSON.parse_string(txt)
	return parsed if parsed is Dictionary else {}


## 给单位挂 idle ping-pong + attack 单次驱动（敌我双方通用, v24.2）。
## 敌方(sheet 原图朝左) face_right=false; 我方传 true → 驱动给 unit_spr.flip_h=true 镜像成朝右。
## 成功返回 true（失败时不动 flip_h, 静态卡图朝向不受影响）。
static func attach(unit_spr: Sprite2D, anim_id: String, face_right: bool = false) -> bool:
	if unit_spr == null or anim_id.is_empty():
		return false
	var dt := preload("res://resources/design_tokens.gd")
	if dt.is_motion_reduce():
		return false
	if unit_spr.get_node_or_null(DRIVER_NAME) != null:
		return true  # 重挂表现直接复用
	var key := _resolve_key(anim_id)
	if key.is_empty():
		return false
	var meta_d := _load_json(ANIM_ROOT + key + "/anim.json")
	var fps: float = float(meta_d.get("fps", 8.0))
	var fs: int = int(meta_d.get("frame_size", 256))
	var counts: Dictionary = meta_d.get("counts", {})
	var idle := _load_seq(key, "idle", int(counts.get("idle", 0)), fs)
	if idle.size() < 2:
		return false
	var driver := FrameDriver.new()
	driver.name = DRIVER_NAME
	driver.idle_frames = idle
	driver.attack_frames = _load_seq(key, "attack", int(counts.get("attack", 0)), fs)
	driver.fps = fps
	# 我方镜像: sheet 全部朝左(敌方原图), flip_h 翻成朝右。
	# offset.x 恒为 0(apply_uniform_card_sprite), flip 无需补偿; 失败路径不会走到这里。
	unit_spr.flip_h = face_right
	unit_spr.add_child(driver)
	return true


static func _load_seq(key: String, anim: String, n: int, fs: int) -> Array:
	var out: Array = []
	if n <= 0:
		return out
	var sheet_path := ANIM_ROOT + key + "/sheet_%s.png" % anim
	if not ResourceLoader.exists(sheet_path):
		return out
	var sheet: Texture2D = load(sheet_path)
	if sheet == null:
		return out
	for i in range(n):
		var at := AtlasTexture.new()
		at.atlas = sheet
		at.region = Rect2(i * fs, 0.0, fs, fs)
		out.append(at)
	return out


## 开火通知：与 fire_lunge_sprite 同调用点；有驱动则播 attack 一遍后回 idle。
static func notify_fire(unit_spr: Sprite2D) -> void:
	if unit_spr == null:
		return
	var d := unit_spr.get_node_or_null(DRIVER_NAME)
	if d != null and d.has_method("play_attack"):
		d.call("play_attack")


## 帧驱动器：轻量 _process 计时换 texture（挂在 unit_spr 下, 随单位销毁）。
## idle=ping-pong 往返（消除高接缝 idle 的循环跳变, 2026-08-30）;
## attack=正向播一遍回 idle（attack 期间再次开火则重头播）。
## _ready 先做尺寸补偿（静态 512² → 帧 fs²）, 再切首帧。
class FrameDriver extends Node:
	var idle_frames: Array = []
	var attack_frames: Array = []
	var fps: float = 8.0
	var _t: float = 0.0
	var _idx: int = 0
	var _dir: int = 1  ## idle ping-pong 方向(1=正放,-1=倒放); attack 恒正向
	var _mode: String = "idle"
	var _spr: Sprite2D = null
	var _compensated: bool = false

	func _ready() -> void:
		_spr = get_parent() as Sprite2D
		if _spr == null or idle_frames.is_empty():
			return
		_compensate_size()
		_spr.texture = idle_frames[0]

	## 静态卡图(512²)与帧(fs²)分辨率不同时, 补偿 scale/offset 保持视觉一致:
	## scale ×(base_w/frame_w); offset.y ×(frame_h/base_h)（offset 在纹理空间随 scale 缩放）
	func _compensate_size() -> void:
		if _compensated or _spr == null or _spr.texture == null:
			return
		var base_w: float = float(_spr.texture.get_width())
		var base_h: float = float(_spr.texture.get_height())
		var frame_w: float = float(idle_frames[0].get_width())
		var frame_h: float = float(idle_frames[0].get_height())
		if base_w <= 0.0 or base_h <= 0.0 or frame_w <= 0.0 or frame_h <= 0.0:
			return
		_spr.scale = _spr.scale * (base_w / frame_w)
		_spr.offset = Vector2(_spr.offset.x, _spr.offset.y * (frame_h / base_h))
		_compensated = true

	func _process(delta: float) -> void:
		if _spr == null or not is_instance_valid(_spr):
			_spr = get_parent() as Sprite2D
			if _spr == null:
				return
		_t += delta
		if _t < 1.0 / maxf(fps, 0.1):
			return
		_t = 0.0
		var seq: Array = attack_frames if _mode == "attack" else idle_frames
		if seq.is_empty():
			seq = idle_frames
		if seq.is_empty():
			return
		if _mode == "attack":
			_idx += 1
			if _idx >= seq.size():
				_idx = 0
				_dir = 1
				_mode = "idle"
				seq = idle_frames
				if seq.is_empty():
					return
		else:
			# idle ping-pong: 0..N-1..0 往返, 首尾帧不重复播（0→1→…→N-1→N-2→…→1→0）
			_idx += _dir
			if _idx >= seq.size() - 1:
				_idx = seq.size() - 1
				_dir = -1
			elif _idx <= 0:
				_idx = 0
				_dir = 1
		_spr.texture = seq[_idx]

	func play_attack() -> void:
		if attack_frames.is_empty():
			return
		_mode = "attack"
		_idx = 0
		_t = 0.0
		if _spr == null or not is_instance_valid(_spr):
			_spr = get_parent() as Sprite2D
		if _spr != null:
			_spr.texture = attack_frames[0]
