extends Node2D
## v17f 敌方相位师大招演出真实性审计工具
##
## 现有 48 格武器族矩阵不覆盖 boss 大招（飞行弹体→落地爆炸的动态多阶段演出）。
## 本工具 mock 一个 boss driver + 3 个假玩家单位，直接调 EnemyMasterSkillEngine
## 的 6 类 _play_*_cinematic（演出与实战同一份代码），在关键帧截图：
##   飞行帧（弹体在空中）+ 落地帧（爆炸/命中瞬间）。
##
## 运行（勿用 --headless）：godot --path . res://scenes/tools/boss_spell_audit.tscn
## 产物：docs/boss_spell_shots/*.png + manifest.json（AI 评分管线消费）

const SkillEngine = preload("res://managers/battle/enemy_master_skill_engine.gd")
const VfxImpactFactory = preload("res://scripts/battle/vfx_impact_factory.gd")  # v27.19: 案间清场正门
const DT = preload("res://resources/design_tokens.gd")

const SHOT_DIR := "res://docs/boss_spell_shots/"

## 6 类演出 × 代表 effect 名 × 关键帧时刻（飞行中 / 落地爆炸）
## v17j: 每案可自定义 warn 时刻（默认 0.12）——chain 三环蓄力在 0/0.15/0.3s 依次激活，
## warn 0.12 只拍到第一环被 AI 批"蓄力未体现"；summon 能量柱 0.35s 触发需 flight≥0.45 才拍到。
const CASES: Array = [
	{"id": "apocalypse_meteor", "effect": "meteor_apocalypse", "label": "天降毁灭·陨石雨",
	 "warn": 0.12, "flight": 0.28, "land": 0.62},
	{"id": "apocalypse_void", "effect": "void_apocalypse", "label": "天降毁灭·虚空灾变",
	 "warn": 0.12, "flight": 0.28, "land": 0.62},
	{"id": "inferno", "effect": "hell_inferno", "label": "地狱烈焰·燃烧弹",
	 "warn": 0.12, "flight": 0.25, "land": 0.58},
	{"id": "chain", "effect": "tesla_chain", "label": "连锁闪电",
	 "warn": 0.32, "flight": 0.55, "land": 0.68},  # v17j: warn 拍三环蓄力齐；flight 拍预电弧。
	                                               # v20.30: land 0.85→0.68——环/预电弧/爆图在 ~0.85s
	                                               # 全部淡出，旧 land 帧只剩空场（AI 2/10 的主因）。
	{"id": "single", "effect": "god_weapon_single", "label": "精准打击·神罚光矛",
	 "warn": 0.12, "flight": 0.18, "land": 0.42},  # v17g: 0.48→0.42 激光峰值
	{"id": "summon", "effect": "forge_summon", "label": "召唤援军·传送门",
	 "warn": 0.15, "flight": 0.45, "land": 0.62},  # v17j: flight 0.30→0.45 拍能量柱（0.35s 触发）；land 0.70→0.62 拍警报帧
]

var _engine: RefCounted
var _boss_mock: Node2D
var _manifest: Array = []
var _frame_idx: int = 0
var _total_frames: int = 0
var _stage_nodes: Array = []   # v27.19: 案间清场豁免的舞台固定件

const BOSS_POS := Vector2(1050, 430)
const PLAYER_POS := [Vector2(200, 330), Vector2(200, 430), Vector2(200, 530)]

func _ready() -> void:
	# v26.12: 强制 1280×720 无边框（v20.20 同款补丁）——桌面工作区装不下窗口时 OS
	# 压缩窗口尺寸，截图被等比缩水且右缘构图（boss 位 x=1050）被裁。
	var _win: Window = get_window()
	_win.borderless = true
	_win.size = Vector2i(1280, 720)
	_win.position = Vector2i(0, 0)
	_build_stage()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SHOT_DIR))
	_engine = SkillEngine.new()
	# v20.29: mock boss 用独立 Node2D 摆到 BOSS_POS——原 driver=self 且根节点在原点，
	# _get_driver_pos() 恒回 (0,0)：主弹落点/传送门/闪电爆发等 boss 位效果全部炸在左上角，
	# 历史 boss 位截图与 AI 评分都是错位样本（目标侧效果不受影响，故此前未察觉）。
	# 不能直接挪根节点（会带着参考框/假目标一起移）。plain Node2D 无 _flash_body_on_buff，
	# 施法闪光经 has_method 守卫安全跳过。
	_boss_mock = Node2D.new()
	_boss_mock.position = BOSS_POS
	add_child(_boss_mock)
	_engine.setup(_boss_mock, self)  # driver=mock boss（BOSS_POS），battlefield=self
	# v27.19: 舞台固定件登记（此刻树上的都是布景；案间清场据此豁免）
	_stage_nodes = get_children().duplicate()
	_total_frames = CASES.size() * 4  # v17h 起 4 帧/案（warn/flight/land/after），旧 *2 是残留计数
	for case in CASES:
		_run_case(case)
		await _settle()
		_clear_case_fx()
	_write_manifest()
	print("[boss_spell_audit] 完成 %d 帧 → %s" % [_total_frames, ProjectSettings.globalize_path(SHOT_DIR)])
	await get_tree().process_frame
	get_tree().quit(0)

## mock driver：Node2D 位置即 boss 位置；player_units 组里的假目标供 AOE/锁定取用
func _build_stage() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.078, 0.086, 0.11, 1.0)
	bg.size = Vector2(1280, 720)
	add_child(bg)
	# boss 参考框（橙红 96px——相位师基地比普通单位大）
	_make_ref_box(BOSS_POS + Vector2(-48, -96), Color(1.0, 0.45, 0.25, 0.9), "敌方相位师基地(96px)")
	# 玩家目标参考框（青蓝 64px）×3
	for i in range(PLAYER_POS.size()):
		_make_ref_box(PLAYER_POS[i] + Vector2(-32, -64), Color(0.35, 0.85, 1.0, 0.9), "我方单位%d(64px)" % (i + 1))
		var dummy := Node2D.new()
		dummy.position = PLAYER_POS[i]
		dummy.add_to_group("player_units")
		dummy.set_meta("hp", 500.0)
		add_child(dummy)
	# 标尺
	var ruler := ColorRect.new()
	ruler.color = Color(0.9, 0.9, 0.9, 0.7)
	ruler.size = Vector2(100, 2)
	ruler.position = Vector2(40, 680)
	add_child(ruler)
	_make_caption("100px", Vector2(40, 684), 14)

func _make_ref_box(top_left: Vector2, col: Color, caption: String) -> void:
	var box := ColorRect.new()
	box.color = Color(col.r, col.g, col.b, 0.15)
	box.size = Vector2(96, 96) if caption.find("96px") >= 0 else Vector2(64, 64)
	box.position = top_left
	add_child(box)
	var frame := Line2D.new()
	frame.width = 2.0
	frame.default_color = col
	var sz: Vector2 = box.size
	frame.add_point(top_left)
	frame.add_point(top_left + Vector2(sz.x, 0))
	frame.add_point(top_left + sz)
	frame.add_point(top_left + Vector2(0, sz.y))
	frame.add_point(top_left)
	add_child(frame)
	_make_caption(caption, top_left + Vector2(-6, -22), 13)

func _make_caption(text: String, pos: Vector2, size_px: int) -> void:
	var l := Label.new()
	l.text = text
	l.position = pos
	l.add_theme_font_size_override("font_size", size_px)
	l.add_theme_color_override("font_color", Color(0.75, 0.78, 0.85))
	add_child(l)

## 逐案：触发演出 → 4 帧时间序列截图（预警/飞行/落地/余波）。
## v17h: 单帧审计原理上看不到动态过程（AI 批"缺碎屑/缺层次"但碎屑烟柱是动态层），
## 4 帧序列 + Python 拼 filmstrip 让 AI 看到"飞行→爆炸→余波"完整过程。
func _run_case(case: Dictionary) -> void:
	var label: String = case["label"]
	print("[boss_spell_audit] %s" % label)
	match case["id"]:
		"apocalypse_meteor":
			_engine._play_apocalypse_cinematic("meteor_apocalypse", "测试相位师")
		"apocalypse_void":
			_engine._play_apocalypse_cinematic("void_apocalypse", "测试相位师")
		"inferno":
			_engine._play_inferno_cinematic("hell_inferno", "测试相位师")
		"chain":
			_engine._play_chain_cinematic("tesla_chain", "测试相位师")
		"single":
			_engine._play_single_target_cinematic("god_weapon_single", "测试相位师")
		"summon":
			_engine._play_summon_cinematic("forge_summon", "测试相位师")
	# 4 帧时间序列（增量等待，v17f 教训：不能累计）
	var marks: Array = [
		{"t": float(case.get("warn", 0.12)), "tag": "warn"},  # v17j: 每案自定义预警时刻
		{"t": case["flight"], "tag": "flight"}, # 飞行中
		{"t": case["land"], "tag": "land"},     # 落地爆炸
		{"t": case["land"] + 0.35, "tag": "after"},  # 余波（烟柱/焦痕/残焰）
	]
	# v27.19: 绝对时钟锚定——旧版「增量等待」把 PNG 保存耗时（老 GPU 单张可达数百 ms）
	# 累计进后续帧，after 帧实拍于 ~1.5-1.9s：目标环(duration 0.9)已淡完、boss 环近尾、
	# 烟柱升顶 → "after 帧空场"假象（v20.30 把 land 0.85→0.68 提前实为同病补偿）。
	# 现以案起始 ticks 为锚，每帧按剩余时差等待，保存耗时只吃下一帧的等待量。
	var t0_ms := Time.get_ticks_msec()
	for m in marks:
		var target_ms := int(float(m["t"]) * 1000.0)
		var now_ms := Time.get_ticks_msec() - t0_ms
		if target_ms > now_ms:
			await get_tree().create_timer(float(target_ms - now_ms) / 1000.0).timeout
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		img.save_png(SHOT_DIR + String("%s_%s.png" % [case["id"], m["tag"]]))
		_manifest.append({
			"file": String("%s_%s.png" % [case["id"], m["tag"]]),
			"id": case["id"],
			"label": case["label"],
			"stage": String(m["tag"]),
			"spec": _spec_for(case["id"], String(m["tag"])),
		})
		_frame_idx += 1
		print("[dbg] shot=%s t=%.2fs children=%d" % [m["tag"],
			float(Time.get_ticks_msec() - t0_ms) / 1000.0, get_child_count()])  # v27.19 排障

func _capture_at(_delay: float, _file_name: String, _case: Dictionary, _stage_name: String) -> void:
	pass  # v27.19: 旧增量等待路径退役（PNG 保存耗时串进累计时钟的病根），保留签名防外部引用

func _settle() -> void:
	# v20.30: 1.2→2.6s——spawn_smoke_column 发射 2.4s + 粒子寿命，旧 settle 让上一案
	# （如 inferno）的烟柱串进下一案截图（chain_after 2/10 的"红色烟雾团"即此）。
	await get_tree().create_timer(2.6).timeout

## v27.19: 案间硬清场——settle 等「已发射粒子」自然消亡后，把残余 VFX 节点
## （烟柱尾段/池化环/贴图层）从战场树上摘除，下一案从零开始。
## v20.30 的纯时间兜底挡不住长寿命粒子串味（烟柱 2.5s 停止发射后粒子还能活 2.4s，
## 5_案序里 inferno→chain 的余波污染使 chain_after 连续两轮 2-3/10——测的是上一案）。
## 顺序：captures → settle（待延迟链自然发射完毕）→ clear → 下一案。
## 池化节点走 VfxImpactFactory.release_to_pool 正门（计数回落；直接 free 会让
## _active_* 只增不减，长跑后半场池上限假性拒发）；非池节点返回 false 自行 free。
func _clear_case_fx() -> void:
	for c in get_children():
		if c in _stage_nodes:
			continue
		if VfxImpactFactory.release_to_pool(c):
			continue
		remove_child(c)   # 立即出树（queue_free 要等帧末，下一案 warn 帧可能先拍）
		c.queue_free()

func _spec_for(case_id: String, stage: String) -> String:
	match case_id:
		"apocalypse_meteor":
			return "飞行帧=陨石弹体(64px宽,橙红,头朝下)从高空落下+拖尾;落地帧=360px火球爆炸+150px冲击波椭圆+9目标地毯轰炸小冲击波"
		"apocalypse_void":
			return "同陨石但紫色虚空球+紫色爆炸;配色区分橙红"
		"inferno":
			return "飞行帧=燃烧弹从侧方低空俯冲(红橙,头朝右下);落地帧=340px地狱火球+烟柱+120px冲击波"
		"chain":
			return "boss三层蓝白能量环爆发+连锁电弧跳向3目标+蓝白闪电贴图爆炸300px"
		"single":
			return "飞行帧=红色锁定双环+金白光矛(50px)从天而降;落地帧=红紫激光贯穿(boss→目标)+穿甲光线+80px冲击波"
		"summon":
			return "紫色传送门280px+螺旋能量,召唤感"
		_: return ""

func _write_manifest() -> void:
	var mf := FileAccess.open(SHOT_DIR + "manifest.json", FileAccess.WRITE)
	if mf != null:
		mf.store_string(JSON.stringify({"cells": _manifest, "generated": Time.get_datetime_string_from_system()}, "\t"))
		mf.close()
