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

const BOSS_POS := Vector2(1050, 430)
const PLAYER_POS := [Vector2(200, 330), Vector2(200, 430), Vector2(200, 530)]

func _ready() -> void:
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
	_total_frames = CASES.size() * 2
	for case in CASES:
		_run_case(case)
		await _settle()
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
	var prev_t: float = 0.0
	for m in marks:
		await _capture_at(m["t"] - prev_t, "%s_%s.png" % [case["id"], m["tag"]], case, m["tag"])
		prev_t = m["t"]

func _capture_at(delay: float, file_name: String, case: Dictionary, stage_name: String) -> void:
	await get_tree().create_timer(delay).timeout
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	img.save_png(SHOT_DIR + file_name)
	_frame_idx += 1
	_manifest.append({
		"file": file_name,
		"id": case["id"],
		"label": case["label"],
		"stage": stage_name,
		"spec": _spec_for(case["id"], stage_name),
	})

func _settle() -> void:
	# v20.30: 1.2→2.6s——spawn_smoke_column 发射 2.4s + 粒子寿命，旧 settle 让上一案
	# （如 inferno）的烟柱串进下一案截图（chain_after 2/10 的"红色烟雾团"即此）。
	await get_tree().create_timer(2.6).timeout

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
