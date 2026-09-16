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
## v24.3: 预加载 EnemyCardModMap（用于敌方 archetype_id → 玩家卡 ID 映射）
const EnemyCardModMap := preload("res://data/enemy_card_mod_map.gd")
## v27.2: 星冥占位/缴获镜像——archetype 的 visual_id（复用卡图 id）帧资产继承
const EnemyUnitManifest := preload("res://data/enemy_unit_manifest.gd")
## v26.9: 描边 uniform 刷新——换帧（AtlasTexture 区域）/尺寸补偿后必须同步，
## 否则描边取样越帧出鬼影、scale×2 后描边宽度翻倍（契约见 unit_outline.gd 头注）
const UnitOutline := preload("res://scripts/battle/unit_outline.gd")

## v27.12: anim.json 解析结果跨单位静态缓存——同 path 只读盘+解析一次（资产只读，会话内恒定）
static var _json_cache: Dictionary = {}
## v27.12: _resolve_key 探测结果缓存（含未命中空串）——同 id 多次出生不再重复磁盘探测
static var _key_cache: Dictionary = {}
## v27.12: 帧序列跨单位静态缓存（key/anim → AtlasTexture 数组）——同单位类型多次出生
## 不再每 attach 重建 N 个 AtlasTexture；数组只读共享（驱动器只按下标取，不改内容）
static var _seq_cache: Dictionary = {}


static func _resolve_key(anim_id: String) -> String:
	## v27.12: 先查缓存再走原探测链（语义不变，探测函数本身无副作用）
	if _key_cache.has(anim_id):
		return String(_key_cache[anim_id])
	var key := _resolve_key_impl(anim_id)
	_key_cache[anim_id] = key
	return key


static func _resolve_key_impl(anim_id: String) -> String:
	## id → 资产目录名（剥 foe_ 前缀）; 有 sheet_idle 且带 anim.json 才算命中
	for cand in [anim_id, anim_id.trim_prefix("foe_")]:
		var c := String(cand)
		if not c.is_empty() \
				and ResourceLoader.exists(ANIM_ROOT + c + "/sheet_idle.png") \
				and ResourceLoader.exists(ANIM_ROOT + c + "/anim.json"):
			return c
	## v24.3: 敌方 archetype_id 映射到玩家卡 ID（帧动画资源共用）
	## 通过 EnemyCardModMap 动态查找，覆盖所有敌方单位
	var player_card_id: String = EnemyCardModMap.get_player_card_id(anim_id)
	if not player_card_id.is_empty() \
			and ResourceLoader.exists(ANIM_ROOT + player_card_id + "/sheet_idle.png") \
			and ResourceLoader.exists(ANIM_ROOT + player_card_id + "/anim.json"):
		return player_card_id
	## v27.2: 占位图源回退——archetype（含 captured_ 缴获镜像剥前缀）的 visual_id
	## 本身是带雪碧条资产的卡图 id 时（星冥 20 单位复用现有卡图），继承该卡
	## idle/attack 动画。经典单位 visual_id 多为自身 → 无行为变化。
	var vis_fb: String = EnemyUnitManifest.visual_id_for_archetype(String(anim_id).trim_prefix("captured_"))
	if not vis_fb.is_empty() and vis_fb != String(anim_id) and vis_fb != player_card_id:
		if ResourceLoader.exists(ANIM_ROOT + vis_fb + "/sheet_idle.png") \
				and ResourceLoader.exists(ANIM_ROOT + vis_fb + "/anim.json"):
			return vis_fb
	return ""


static func _load_json(path: String) -> Dictionary:
	## v27.12: 路径级缓存（资产只读会话内恒定）——attach 原每单位出生读盘+解析一次，
	## 现全场同 key 只解析一次；负结果（空字典）同样缓存
	if _json_cache.has(path):
		return _json_cache[path]
	var txt := FileAccess.get_file_as_string(path)
	if txt.is_empty():
		_json_cache[path] = {}
		return {}
	var parsed = JSON.parse_string(txt)
	var d: Dictionary = parsed if parsed is Dictionary else {}
	_json_cache[path] = d
	return d


## v6.15: 该单位的动画雪碧图是否已预烘焙描边（deploy_unit_anims.py 写 anim.json 的
## outline.baked）——是则呈现层跳过 alpha 膨胀 shader（unit_outline.gd），否则烘焙描边
## 会被 shader 二次外扩。anim_id 口径与 attach 一致；非动画单位返回 false 继续走 shader。
## v6.15.1: boss/相位师逐帧资产目录（idle_f*.png，BossIdleAnim 消费，无雪碧图），
## _resolve_key 因缺 sheet_idle 不命中——兜底直读该目录 anim.json 的 outline 标记
##（deploy_unit_anims.py --bake-boss-frames 写入，纯标记文件）。
## ⚠️ 只按目录名直查（与 BossIdleAnim._load_frames 同口径），不做 captured_ 剥前缀——
## 缴获 boss 卡走 vis_player 卡图回退（无帧资产），静态卡图未烘焙，必须继续吃 shader。
static func is_outline_baked(anim_id: String) -> bool:
	if anim_id.is_empty():
		return false
	var key := _resolve_key(anim_id)
	if not key.is_empty():
		return bool(_load_json(ANIM_ROOT + key + "/anim.json").get("outline", {}).get("baked", false))
	for cand in [anim_id, anim_id.trim_prefix("foe_")]:
		var c := String(cand)
		if c.is_empty():
			continue
		var p := ANIM_ROOT + c + "/anim.json"
		if ResourceLoader.exists(p):
			return bool(_load_json(p).get("outline", {}).get("baked", false))
	return false


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
	## v27.12: 序列级缓存——AtlasTexture 只读资源共享给全部同型单位（含空结果负缓存）
	var ck := "%s/%s" % [key, anim]
	if _seq_cache.has(ck):
		return _seq_cache[ck]
	var out: Array = []
	if n <= 0:
		_seq_cache[ck] = out
		return out
	var sheet_path := ANIM_ROOT + key + "/sheet_%s.png" % anim
	if not ResourceLoader.exists(sheet_path):
		return out
	var sheet: Texture2D = load(sheet_path)
	if sheet == null:
		_seq_cache[ck] = out
		return out
	for i in range(n):
		var at := AtlasTexture.new()
		at.atlas = sheet
		at.region = Rect2(i * fs, 0.0, fs, fs)
		out.append(at)
	_seq_cache[ck] = out
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
		UnitOutline.refresh(_spr)  # v26.9: 首帧换 AtlasTexture + scale 补偿后刷描边 uniform

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
		UnitOutline.refresh(_spr)  # v26.9: 换帧同步描边区域（防雪碧图越帧取样）

	func play_attack() -> void:
		if attack_frames.is_empty():
			return
		_mode = "attack"
		_idx = 0
		_t = 0.0
		# v27.x: attack 播放时长对齐宿主攻击间隔——动态 fps = 帧数/间隔,播完正好回
		# idle（此前恒 anim.json 的 8fps=1.5s:快攻单位 0.55s 间隔被打断重播、慢攻
		# 单位 2.4s 间隔尾部空窗 ~0.9s）。宿主单位挂 unit_spr 的父节点,stats 缺失
		# 或 interval 异常时保持原 fps。clamp 6-24:低于 6 失去打击感,高于 24 帧闪。
		var host: Node = _spr.get_parent() if _spr != null and is_instance_valid(_spr) else null
		if host != null:
			var st: Variant = host.get("stats")
			if st != null and "attack_interval" in st:
				var itv: float = float(st.attack_interval)
				if itv > 0.05:
					fps = clampf(float(attack_frames.size()) / itv, 6.0, 24.0)
		if _spr == null or not is_instance_valid(_spr):
			_spr = get_parent() as Sprite2D
		if _spr != null:
			_spr.texture = attack_frames[0]
			UnitOutline.refresh(_spr)
