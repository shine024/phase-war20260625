extends RefCounted
class_name AttackPoseAnim

## ============================================================
## v9.x 攻击姿态反馈——按武器类型分化攻击动作 + 可选攻击帧美术
##
## 程序姿态（永远生效，替代原 22px 单一前冲滑步——人形班组读作"整队滑步"而非射击）：
##   轻武器(0/4/5/6)    → 前冲 14px + 立绘前倾 4° 回弹（抵肩射击）
##   重型化学能(3/7/9)  → 后坐 10px + 立绘后仰 2.5° 回弹（炮身后坐）
##   能量重型(8/10/11)  → 前冲 8px + 立绘前倾 2°（能量武器后坐小）
##   曲射/空射(1/2)     → 前移 8px + 立绘上扬 6° 回弹（抛射/俯冲）
##
## 攻击帧美术（存在即自动启用，可选）：
##   res://assets/effects/unit_anims/<unit_id>/attack_f0.png（可选 f1，两帧交替）
##   由 tools/generate_attack_frames.py 生成（img2img 同角色攻击姿态，保角色一致性）
##   有帧时开火瞬间换贴图 ~0.16s；与 BossIdleFrameDriver 协调（暂停待机帧→攻击帧→恢复）。
##   帧贴图必须与卡图同分辨率 512（BossIdleAnim 同约束：归一化缩放按纹理宽度算）。
##
## 调用方：ConstructUnitAI.do_attack_with_damage / construct_unit / enemy_unit._do_attack。
## motion_reduce：保留位移（攻击 Telegraph 是 gameplay 信息），跳过立绘倾斜与帧动画。
## ============================================================

const FRAME_ROOT := "res://assets/effects/unit_anims/"
const FRAME_HOLD_SEC := 0.16

static var _frame_cache: Dictionary = {}
static var _frame_probe: Dictionary = {}  # unit_id → bool（已探测过路径，负结果也缓存）

## 攻击主入口：位移姿态 + 立绘倾斜 + 攻击帧（如有美术）。
static func play(u: Node2D, wt: int = -1) -> void:
	if u == null or not is_instance_valid(u):
		return
	var pose: Dictionary = _pose_params(wt)
	_play_lunge(u, pose)
	var dt := preload("res://resources/design_tokens.gd")
	if dt.is_motion_reduce():
		return
	var spr := _find_sprite(u)
	if spr == null:
		return
	_play_lean(spr, pose, bool(u.get("is_player")))
	_try_play_frames(u, spr)


## 姿态参数表：位移像素（正=朝面向前冲，负=后坐）+ 立绘倾角（度，正=朝面向前倾）。
static func _pose_params(wt: int) -> Dictionary:
	match wt:
		3, 7, 9:      # ROCKET / FLAK / MISSILE — 化学能重型：后坐
			return {"lunge": -10.0, "lean": -2.5}
		8, 10, 11:    # LASER / OMEGA / RAIL — 能量重型：前冲小、倾角小
			return {"lunge": 8.0, "lean": 2.0}
		1, 2:         # INDIRECT / AERIAL — 抛射/俯冲：上扬
			return {"lunge": 8.0, "lean_up": 6.0}
		0, 4, 5, 6, _:  # DIRECT/PISTOL/SHOTGUN/SNIPER/未知 — 轻武器：抵肩前倾
			return {"lunge": 14.0, "lean": 4.0}


## 位移姿态：驱动单位 _card_nudge_tween（敌我两单位类同名字段，duck-typing 存取）。
static func _play_lunge(u: Node2D, pose: Dictionary) -> void:
	if not bool(u.get("_presentation_card_grid")):
		return
	var rest_x: float = float(u.get("_card_grid_rest_x"))
	if is_nan(rest_x):
		rest_x = (u as Node2D).position.x
		u.set("_card_grid_rest_x", rest_x)
	var old_tw: Tween = u.get("_card_nudge_tween")
	if old_tw != null and old_tw is Tween and old_tw.is_valid():
		old_tw.kill()
		(u as Node2D).position.x = rest_x
	var tw: Tween = (u as Node2D).create_tween()
	u.set("_card_nudge_tween", tw)
	var dir: float = 1.0 if bool(u.get("is_player")) else -1.0
	var px: float = float(pose.get("lunge", 14.0)) * dir
	tw.tween_property(u, "position:x", rest_x + px, 0.07)
	tw.tween_property(u, "position:x", rest_x, 0.09)


## 立绘倾斜：轻武器前倾 / 重型后仰 / 曲射上扬，快速回弹。
## 只动 Sprite 子节点 rotation——不动根节点（根 scale.x 可能带翻转）。
static func _play_lean(spr: Sprite2D, pose: Dictionary, is_player: bool) -> void:
	var deg: float = 0.0
	if pose.has("lean_up"):
		deg = -float(pose["lean_up"])  # 上扬（负=逆时针抬头，与朝向无关）
	else:
		deg = float(pose.get("lean", 4.0)) * (1.0 if is_player else -1.0)
	if absf(deg) < 0.01:
		return
	# 已有倾斜 tween 在播则先复位（攻速快时避免角度累积）
	if spr.has_meta("_lean_tween") :
		var old: Tween = spr.get_meta("_lean_tween") as Tween
		if old != null and old.is_valid():
			old.kill()
		spr.rotation = 0.0
	var tw: Tween = spr.create_tween()
	spr.set_meta("_lean_tween", tw)
	var rad := deg_to_rad(deg)
	tw.tween_property(spr, "rotation", rad, 0.05)
	tw.tween_property(spr, "rotation", 0.0, 0.11)
	tw.tween_callback(func() -> void:
		if is_instance_valid(spr):
			spr.remove_meta("_lean_tween")
	)


## 攻击帧：unit_anims/<unit_id>/attack_f0(+f1)。有 BossIdleFrameDriver 时暂停待机循环，
## 攻击帧展示 FRAME_HOLD_SEC 后恢复（driver 下一 tick 自动切回待机帧；无 driver 恢复原贴图）。
static func _try_play_frames(u: Node2D, spr: Sprite2D) -> void:
	var uid := _resolve_unit_id(u)
	if uid.is_empty() or not has_attack_frames(uid):
		return
	var frames: Array = _load_frames(uid)
	if frames.is_empty():
		return
	var driver: Node = spr.get_node_or_null("BossIdleFrameDriver")
	if driver != null:
		driver.set_process(false)
	var orig: Texture2D = spr.texture
	spr.texture = frames[0]
	if frames.size() >= 2:
		var t1: SceneTreeTimer = u.get_tree().create_timer(FRAME_HOLD_SEC * 0.5)
		t1.timeout.connect(func() -> void:
			if is_instance_valid(spr):
				spr.texture = frames[1]
		)
	var t2: SceneTreeTimer = u.get_tree().create_timer(FRAME_HOLD_SEC)
	t2.timeout.connect(func() -> void:
		if not is_instance_valid(spr):
			return
		if driver != null and is_instance_valid(driver):
			driver.set_process(true)  # 下一 tick 恢复待机帧
		else:
			spr.texture = orig
	)


static func has_attack_frames(uid: String) -> bool:
	if uid.is_empty():
		return false
	if _frame_probe.has(uid):
		return bool(_frame_probe[uid])
	var ok: bool = FileAccess.file_exists(FRAME_ROOT + uid + "/attack_f0.png")
	_frame_probe[uid] = ok
	return ok


static func _load_frames(uid: String) -> Array:
	if _frame_cache.has(uid):
		return _frame_cache[uid]
	var out: Array = []
	for i in range(2):
		var p := FRAME_ROOT + uid + "/attack_f%d.png" % i
		if not ResourceLoader.exists(p):
			break
		var t: Texture2D = load(p)
		if t == null:
			break
		out.append(t)
	_frame_cache[uid] = out
	return out


## 单位视觉 id 解析（与 _play_muzzle_feedback 的锚点解析同链）：
## 敌方裸 archetype_id → 我方 _visual_archetype_id → stats.platform_card_id。
static func _resolve_unit_id(u: Node2D) -> String:
	var aid: String = String(u.get("archetype_id")) if "archetype_id" in u else ""
	if aid.is_empty():
		aid = String(u.get("_visual_archetype_id")) if "_visual_archetype_id" in u else ""
	if aid.is_empty() and u.get("stats") != null:
		var st = u.get("stats")
		if st != null and "platform_card_id" in st:
			aid = String(st.platform_card_id)
	return aid


static func _find_sprite(u: Node2D) -> Sprite2D:
	var spr: Sprite2D = null
	if bool(u.get("is_player")):
		spr = u.get_node_or_null("Sprite") as Sprite2D
	else:
		spr = u.get_node_or_null("Sprite2D") as Sprite2D
	if spr == null:
		spr = u.get_node_or_null("Sprite") as Sprite2D
		if spr == null:
			spr = u.get_node_or_null("Sprite2D") as Sprite2D
	return spr


## 测试用：清空帧缓存（热重载资产后）
static func clear_cache() -> void:
	_frame_cache.clear()
	_frame_probe.clear()
