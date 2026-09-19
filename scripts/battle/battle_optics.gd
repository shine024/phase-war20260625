extends RefCounted
class_name BattleOptics
## v6.17 命中光学层：战场泛光 + 动态光闪。
## 参照系《轮回保险公司 R.I.P.》表现力拆解（2026-09-18，13 张官方截图）：它的弹道/爆炸
## "高级感"来自 HDR 发光体 + 全屏泛光 + 动态光照三层光学外衣，命中词汇本身与我们同构。
## 本文件是统一光学放大器——只放大既有词汇（白闪/火花/爆炸/曳光）的亮度，不新增命中
## 词汇（docs/命中表现夸张规则.md 横切规则已补录）。
##
## 两层职责：
##   1. ensure_glow(battlefield)：幂等挂 WorldEnvironment（glow），配 project.godot 的
##      viewport/hdr_2d=true，让 modulate>1 的画布内容过 bloom 阈值发光。
##   2. flash(...)：PointLight2D 闪光滑池（枪口小闪/爆炸大闪/大招巨闪）——光不投影、
##      限世界画布层、并发上限，寿命 0.1-0.5s 由 tween 衰减后归还。
## 总开关 GameConfig.vfx_glow_enabled / vfx_dynamic_lights_enabled；
## A/B 环境变量 PW_GLOW_OFF=1 / PW_LIGHTS_OFF=1 整层旁路（ColorGrade 先例）。
## 极速推演（BattleTimeState.ff_active）下 flash 直接短路（与特效工厂同门）。
##
## 记账纪律：光挂调用方父层（跟随单位/特效层坐标系），父层随战斗清场被释放时
## 池内引用失效——active/pool 双数组每次 flash 先滤无效项自愈（v27.12 弹痕池
## 同款"池内可能残留已 free 实例"问题，不靠计数器防漂移）。

const GameConfigScript = preload("res://resources/game_config.gd")
const BattleTimeState = preload("res://scripts/battle/battle_time_state.gd")

# ── 泛光 ──────────────────────────────────────────────────────────────

## 战场节点跨场常驻，env 只建一次；开关关着就不建（后续打开开关要等下一场进战斗
## _ready 才补建——低成本，可接受）。阈值 1.05：HUD/UI 颜色恒 ≤1 不进 bloom，
## 只有 VFX 侧刻意 >1 的发光体发光。
static func ensure_glow(battlefield: Node) -> void:
	if battlefield == null or not is_instance_valid(battlefield):
		return
	if battlefield.get_node_or_null("BattleOpticsEnv") != null:
		return
	if not bool(GameConfigScript.get_default().vfx_glow_enabled):
		return
	if OS.get_environment("PW_GLOW_OFF") == "1":
		return
	var env := Environment.new()
	env.glow_enabled = true
	env.glow_hdr_threshold = 1.05
	env.glow_intensity = 0.9
	env.glow_bloom = 0.15
	# v6.17 实测勘误（本机 GL 管线）：glow 后处理在 720p 下 ~4x 帧率损失
	# （280 帧战斗时钟 00:27 → 关 00:07）。极限收窄：只留 1 级模糊（第 3 级，
	# Godot 默认开 3/5 两级）。仍超预算则整层回退（开关已在）。
	for lvl in 7:
		env.set_glow_level(lvl, 1.0 if lvl == 2 else 0.0)
	var we := WorldEnvironment.new()
	we.name = "BattleOpticsEnv"
	we.environment = env
	battlefield.add_child(we)


# ── 动态光闪池 ────────────────────────────────────────────────────────

const MAX_LIGHTS: int = 10
const LIGHT_TEX_R_PX: float = 64.0  # 程序化光晕贴图半径（128 画布，无外置贴图免 import）

static var _light_pool: Array = []    # 空闲 PointLight2D（挂 holder 常驻树内）
static var _light_active: Array = []  # 在场光闪（挂各战场父层）
static var _light_tex: GradientTexture2D = null
static var _holder: Node = null       # 空闲池常驻根（v26.11(D1) VfxPoolRoot 同范式）

static func _get_light_tex() -> GradientTexture2D:
	if _light_tex != null:
		return _light_tex
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.45), Color(1, 1, 1, 0)])
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(0.5, 0.0)  # 半径=0.5 画布 → 边缘 alpha 0
	t.width = 128
	t.height = 128
	_light_tex = t
	return t


static func _get_holder() -> Node:
	if _holder != null and is_instance_valid(_holder) and _holder.is_inside_tree():
		return _holder
	var loop := Engine.get_main_loop()
	if loop == null or not (loop is SceneTree):
		return null
	var tree := loop as SceneTree
	if tree.root == null:
		return null
	_holder = Node.new()
	_holder.name = "BattleOpticsLightPool"
	_holder.process_mode = Node.PROCESS_MODE_DISABLED
	tree.root.add_child(_holder)
	return _holder


## 双数组自愈：清掉随战场父层一起被 free 的失效引用（节点被释放=tween 同死=
## 无回调归还，只能靠下次 flash 进场时过滤）
static func _heal_arrays() -> void:
	_light_pool = _light_pool.filter(func(n): return is_instance_valid(n))
	_light_active = _light_active.filter(func(n): return is_instance_valid(n))


## 一次光闪：parent 取战场内层（与调用方特效同父，local 坐标系一致）；
## radius_px 为目标可视半径；energy 峰值亮度；dur 衰减总时长。
## 典型档：枪口轻 64px/0.8/0.10s · 枪口重 92px/1.1/0.16s · 爆炸 130px/1.3/0.30s ·
## 大招 210px/1.6/0.50s。
static func flash(parent: Node, pos: Vector2, color: Color, radius_px: float, energy: float, dur: float) -> void:
	if BattleTimeState.ff_active:
		return
	if not bool(GameConfigScript.get_default().vfx_dynamic_lights_enabled):
		return
	if OS.get_environment("PW_LIGHTS_OFF") == "1":
		return
	if parent == null or not is_instance_valid(parent) or not (parent is Node2D):
		return
	_heal_arrays()
	var light: PointLight2D = null
	while not _light_pool.is_empty():
		var cand = _light_pool.pop_back()
		if is_instance_valid(cand):
			light = cand
			break
	if light == null and _light_active.size() + _light_pool.size() >= MAX_LIGHTS:
		return  # 并发上限：丢新请求（光闪寿命短，静默节流）
	if light == null:
		light = PointLight2D.new()
		light.shadow_enabled = false  # 2D 光影开销大，光闪语义不需要
	_light_active.append(light)
	light.texture = _get_light_tex()
	light.color = color
	light.texture_scale = radius_px / LIGHT_TEX_R_PX
	# 只影响世界画布层（layer 0）——HUD/弹窗等高层 CanvasLayer 不被战场光闪脉冲
	light.range_layer_min = 0
	light.range_layer_max = 0
	light.enabled = true
	light.visible = true
	var old_parent: Node = light.get_parent()
	if old_parent != parent:
		if old_parent != null:
			old_parent.remove_child(light)
		parent.add_child(light)
	light.position = pos
	light.energy = energy
	var tw := light.create_tween()
	tw.tween_property(light, "energy", 0.0, dur)
	tw.tween_callback(_release_light.bind(light))


static func _release_light(light: PointLight2D) -> void:
	_light_active.erase(light)
	if light == null or not is_instance_valid(light):
		return
	var holder := _get_holder()
	light.enabled = false
	light.visible = false
	if holder != null:
		if light.get_parent() != null:
			light.get_parent().remove_child(light)
		holder.add_child(light)
		if _light_pool.size() < MAX_LIGHTS:
			_light_pool.append(light)
		else:
			light.queue_free()
	else:
		# 树正在拆（退场）——直接释放
		light.queue_free()
