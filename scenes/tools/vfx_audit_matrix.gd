extends Node2D
## v17 全矩阵 VFX 视觉审计机（tools 场景，非游戏内容）
##
## 用途：把"全面检查"从人眼抽查变成可重复的全矩阵视觉审计。
## 运行（需真实渲染，勿用 --headless——headless 是 dummy renderer 截不出内容）：
##   godot --path . res://scenes/tools/vfx_audit_matrix.tscn
## 产物：
##   docs/vfx_audit_shots/*.png        —— 12 武器族 × 敌我 × 开火/命中 = 48 格截图
##   tools/vfx_audit_review.html       —— 审查页（图片矩阵 + 档案规格 + 名字解析审计表）
## 浏览器打开 tools/vfx_audit_review.html 对照 PROFILES.spec 逐格打分（真实度验收标准）。
##
## 每格流程：清场 → 在标尺/参考单位旁生成真实特效（走正式入口 spawn_muzzle_flash /
## spawn_impact_with_kind，含签名武器分支与 power_tier 分级）→ 0.30s 峰值帧截图 →
## 0.85s 等特效自然消散归池 → 下一格。全程约 1 分钟。

const VfxFactory = preload("res://scripts/battle/vfx_impact_factory.gd")
const ProjVfx = preload("res://scripts/weapon_projectile_vfx.gd")
const WVP = preload("res://data/weapon_visual_profiles.gd")
const UCT = preload("res://data/unified_card_table.gd")

const SHOT_DIR := "res://docs/vfx_audit_shots/"
const HTML_PATH := "res://tools/vfx_audit_review.html"
# v17c 三帧择优捕获：0.05s（枪口火白热峰，寿命砍短后 0.12s 已是尾巴）/ 0.12s（光束/命中环峰）/
# 0.30s（火球帧/冲击波/爆炸贴图峰），取特效区最亮帧。单帧采样有时运成分（粒子帧间闪烁），
# 三帧覆盖快/中/慢峰值区，且改特效寿命后无需再逐次标定采样点。
# v20.20: 新增 0.02s 超早帧——磁轨/欧米茄等超高初速弹 0.15s 内飞完全程（2026-08-27 像素实测
# 弹道格 0 像素空场），旧三帧网格对快弹是采样盲区；早帧给"刚出膛"状态一次被拍到的机会。
const CAPTURE_FRAMES: Array = [0.02, 0.05, 0.12, 0.30]
const SETTLE_FOR: float = 0.85     # 截完后再等多少秒让特效消散归池

## 每族代表参数：命中演示用的武器名（3/7/9 走 impact_texture_by_name 专属贴图链）与 power_tier 档
const REP_NAME := {
	1: "81mm迫击炮", 2: "无人机导弹", 3: "122mm火箭炮", 5: "霰弹枪",
	7: "37mm高射炮", 9: "全装型导弹巢", 10: "重型等离子加农炮",
	11: "攻城电磁炮", 8: "激光步枪", 6: "粒子束步枪",
}
const REP_TIER := {0: 0, 4: 0, 5: 0, 6: 0, 8: 0, 1: 1, 2: 1, 3: 1, 7: 1, 9: 1, 10: 2, 11: 2}

var _fx_layer: Node2D
var _info_label: Label
var _cell_index: int = 0
var _total_cells: int = 0
var _html_rows: String = ""
var _audit_rows: String = ""
var _fallback_names: Array = []
var _name_total: int = 0
var _name_resolved: int = 0
var _manifest: Array = []  # v17b: 每格元数据（AI 评分脚本 review_vfx_audit_matrix.py 消费）

const MUZZLE_POS := Vector2(360, 430)
const IMPACT_POS := Vector2(900, 430)
const _TRAJ_CENTER := Vector2(630, 430)  # v17k: 弹道飞行中段（开火位与目标位之间）
var _capture_center: Vector2 = MUZZLE_POS

## v17k: 弹道飞行格——真实 batch 实例 fire 3 发，0.12s 飞行中段截图。
## 验证弹体可见性 + 曳光线（v17k 新增）+ 拖尾。这是 4.2 基线缺失的弹道维度审计。
func _spawn_trajectory_cell(f: int, side: bool) -> void:
	var batch_script: GDScript = load("res://managers/battle/simple_player_projectile_batch.gd" if side else "res://managers/battle/simple_enemy_projectile_batch.gd")
	var batch: Node2D = batch_script.new()
	_fx_layer.add_child(batch)
	# 假目标（弹道终点）
	var tgt := Node2D.new()
	tgt.position = IMPACT_POS
	_fx_layer.add_child(tgt)
	var shooter := Node2D.new()
	shooter.position = MUZZLE_POS
	_fx_layer.add_child(shooter)
	# v17l: 族分流——8/12 族不在 BATCH_FIRE_WEAPON_TYPES，旧兜底 wt=0 全在拍通用直射小弹体，
	# 曲射抛物线/火箭尾焰/激光光束/磁轨弹道等签名弹道从未进审计（"三段断裂/辨识度不足"主因）。
	# v17l-R2: 按族定制拍法（AI 批评逐项对齐弹道特性）——曲射等弧线展开、高炮连发显速射、
	# 火箭/导弹中段拍弹体、光束类单发清晰线。
	# v18-R8: [0,4,1,2]→[0,4]——f=1/2(曲射/空射)误入直射 batch（直线 MultiMesh），
	# 抛物线弧线从未进审计（AI 批"弹道几乎呈直线"实为工具渲染错，游戏本体走 indirect batch 无此问题）。
	# 现路由到 bullet 场景（_process_indirect 抛物线）+ 下方 cfg 按族拍法。
	if not (f in [0, 4]):
		var bullet_scene: PackedScene = load("res://scenes/units/bullet.tscn")
		# v20.20: 每族参数重标定（n=连发数 / gap=连发间隔 / wait=截帧前等待）。
		# 病根（2026-08-27 像素实测）：旧表无 gap 轴——n≤3 的族 3 发同帧出生，单帧只拍到
		# 1 个孤立点（AI 批"弹道完全缺失"）；wait 过大又让首发弹在采样窗内落地爆炸污染
		# 弹道格（AI 批 f02"拍到的是命中爆炸"）。新表保证：截帧窗口内所有弹都在飞、
		# 且沿弧线散开（gap 拉开 0.08-0.12s ≈ 弧线上 80-150px 间距）。
		var cfg: Dictionary = {
			1: {"n": 2, "gap": 0.12, "wait": 0.30},  # 曲射：2 发沿抛物线拉开（0.82s 飞行全程内）
			2: {"n": 3, "gap": 0.10, "wait": 0.25},  # 空射：3 发俯冲弧上分布
			3: {"n": 2, "gap": 0.08, "wait": 0.20},  # 火箭：2 发低平弧（0.59s 飞行，防落地穿窗）
			5: {"n": 6, "wait": 0.20},               # 霰弹：6 发散射扇面（v17m 散点目标不变）；
			                                         # v20.20 wait 0.12→0.20——0.12s 时弹丸只飞出
			                                         # 65-145px，±9° 扇面未张开读成"光条束"（AI 主诉）
			6: {"n": 1, "wait": 0.15},               # 狙击/光束：单发光束线清晰
			7: {"n": 6, "wait": 0.12},               # 高炮：速射连发
			8: {"n": 1, "wait": 0.15},               # 激光：v20.24 改单发（对齐狙击 6 拍法）。
			                                         # v18-R8 4 发连拍的初衷是保捕获，但 4 个
			                                         # 弹头亮斑沿路径每 14px 重复（gap0.01×
			                                         # 1400px/s），ADD 叠出周期性亮带 = AI 读
			                                         # "分段矩形块/断裂"的几何真身。单发飞行
			                                         # 光弹 + 160px 定长尾段正是 v19-R35 用户
			                                         # 定调的语义；4 采样帧覆盖 320px 飞行窗
			9: {"n": 2, "gap": 0.12, "wait": 0.30},  # 导弹：2 发中弧分布（0.72s 飞行）
			10: {"n": 1, "wait": 0.15},              # 欧米茄：单发快弹（0.02s 早帧捕获）
			11: {"n": 1, "wait": 0.15},              # 磁轨：单发快弹（0.02s 早帧捕获）
		}
		var c: Dictionary = cfg.get(f, {"n": 3, "wait": 0.14})
		var _gap: float = float(c.get("gap", 0.05))
		for i in range(int(c["n"])):
			var bl: Node2D = bullet_scene.instantiate()
			_fx_layer.add_child(bl)
			bl.global_position = MUZZLE_POS + Vector2(0, (i % 3 - 1) * 22.0)			# v17m-R4: 霰弹散布——6 发各自散点目标（18° 扇面，AI 批"弹道未体现散布特征"）
			var stgt: Node2D = tgt
			if f == 5:
				stgt = Node2D.new()
				stgt.position = IMPACT_POS + Vector2(-20 + (i % 3) * 20.0, -40 + (i / 3) * 80.0)
				_fx_layer.add_child(stgt)
			# v20.9-R1: 弹道格补代表武器名——空名走域感知兜底时，敌方域把裸 1/2 按
			# legacy 步枪/机枪解释归一为 0，f01 敌格会拍成轻动能小弹体而非族形态。
			# f01 用"榴弹炮"关键词命中族 1（双侧行为与游戏内命名曲射武器一致）；
			# f02（空射）无任何关键词/精确表可达（只能我方域 fallback 透传），敌格
			# 工具侧强制族号拍族形态（游戏内敌空射单位都带名走导弹/火箭族，无此形态）。
			var rep_name := "105mm 榴弹炮" if f == 1 else ""
			bl.setup(stgt, 10.0, side, f, shooter, null, false, rep_name, true, "")  # v18-R8: side 透传（敌光束暖色/敌曳光分色）
			if f == 2 and not side:
				bl.set("_visual_wt", 2)
			if i < int(c["n"]) - 1:
				await get_tree().create_timer(_gap).timeout
		await get_tree().create_timer(float(c["wait"]))
		return
	# v17k-R2: 6 发间隔连射（弹幕感——3 发瞬时在截图里是孤立点，连射才有"弹道线"）
	for i in range(6):
		var from: Vector2 = MUZZLE_POS + Vector2(0, (i % 3 - 1) * 26.0)
		batch.fire(from, tgt, 10.0, f if f in [0, 4, 1, 2] else 0, shooter, null, false, "", "")
		await get_tree().create_timer(0.045).timeout
	# 等 0.10s 让末批弹道飞到中段（不同批次分布在全程=弹道轨迹带）
	await get_tree().create_timer(0.10).timeout

func _ready() -> void:
	# v20.20: 强制 1280×720 无边框——桌面工作区装不下窗口时 OS 会压缩窗口尺寸，
	# 截图整视口被等比缩水（2026-08-27 实测 1028×720 = 0.8025×），AI 看到的特效比
	# 游戏内小 20% 且坐标映射漂移。无边框绕开"客户区+标题栏>工作区"的钳制。
	var _audit_win: Window = get_window()
	_audit_win.borderless = true
	_audit_win.size = Vector2i(1280, 720)
	_audit_win.position = Vector2i(0, 0)
	_build_stage()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SHOT_DIR))
	# v17c 预热：矩阵第一个格子的枪口火两轮实测确定性缺失（发光像素=3）——首个全新
	# one_shot 粒子节点的发射时序赶不上 0.05s 首帧。屏外先打一发暖池，代价半秒。
	VfxFactory.spawn_muzzle_flash(_fx_layer, Vector2(-500, -500), true, 0)
	await get_tree().create_timer(0.5).timeout
	await _run_matrix()
	await _build_resolution_audit()
	_write_html()
	print("[vfx_audit] 完成：%d 格截图 + 审查页 → %s" % [_total_cells, ProjectSettings.globalize_path(HTML_PATH)])
	await get_tree().process_frame
	get_tree().quit(0)

## ── 舞台：背景 + 地面线 + 参考单位框 + 标尺 + 信息标签 ──
func _build_stage() -> void:
	# v17m: 战场语境（AI 对暗背景空台上的特效系统性压批"无力/不可读"——同样特效
	# 在战场画面里辨识度完全不同。天空渐变+地面带+单位剪影给特效一个"宿主"）
	var sky := ColorRect.new()
	sky.color = Color(0.10, 0.12, 0.17, 1.0)
	sky.size = Vector2(1280, 480)
	sky.position = Vector2.ZERO
	add_child(sky)
	var sky_hi := ColorRect.new()  # 天际线亮带
	sky_hi.color = Color(0.16, 0.19, 0.26, 1.0)
	sky_hi.size = Vector2(1280, 60)
	sky_hi.position = Vector2(0, 420)
	add_child(sky_hi)
	var ground_band := ColorRect.new()
	ground_band.color = Color(0.13, 0.12, 0.10, 1.0)
	ground_band.size = Vector2(1280, 240)
	ground_band.position = Vector2(0, 480)
	add_child(ground_band)
	var ground_hi := ColorRect.new()  # 地平线光
	ground_hi.color = Color(0.20, 0.18, 0.14, 1.0)
	ground_hi.size = Vector2(1280, 8)
	ground_hi.position = Vector2(0, 480)
	add_child(ground_hi)
	# 单位剪影（简坦克形：车体+炮塔+炮管）——特效的宿主
	_make_tank_silhouette(MUZZLE_POS, Color(0.30, 0.55, 0.75, 0.9))
	_make_tank_silhouette(IMPACT_POS, Color(0.75, 0.40, 0.25, 0.9))
	var ground := ColorRect.new()
	ground.color = Color(0.16, 0.18, 0.22, 1.0)
	ground.size = Vector2(1280, 4)
	ground.position = Vector2(0, 500)
	add_child(ground)
	# 参考单位框（64px 高，特效尺度的锚）：开火位=我方朝右，受击位=敌方朝左
	_make_ref_box(MUZZLE_POS + Vector2(-24, -64), Color(0.35, 0.85, 1.0, 0.85), "我方单位(64px)")
	_make_ref_box(IMPACT_POS + Vector2(-24, -64), Color(1.0, 0.45, 0.25, 0.85), "目标单位(64px)")
	# 100px 标尺
	var ruler := ColorRect.new()
	ruler.color = Color(0.9, 0.9, 0.9, 0.7)
	ruler.size = Vector2(100, 2)
	ruler.position = Vector2(40, 680)
	add_child(ruler)
	_make_caption("100px", Vector2(40, 684), 14)
	_info_label = Label.new()
	_info_label.position = Vector2(24, 16)
	_info_label.add_theme_font_size_override("font_size", 26)
	_info_label.add_theme_color_override("font_color", Color(0.92, 0.95, 1.0))
	add_child(_info_label)
	_fx_layer = Node2D.new()
	add_child(_fx_layer)

## v17m: 简坦克剪影（车体矩形+炮塔梯形+炮管线）——给特效一个视觉宿主
func _make_tank_silhouette(base_pos: Vector2, col: Color) -> void:
	var hull := Polygon2D.new()
	hull.polygon = PackedVector2Array([
		Vector2(-34, -22), Vector2(34, -22), Vector2(40, -6), Vector2(-40, -6)])
	hull.color = Color(col.r * 0.5, col.g * 0.5, col.b * 0.5, 0.85)
	hull.position = base_pos + Vector2(0, -16)
	add_child(hull)
	var turret := Polygon2D.new()
	turret.polygon = PackedVector2Array([
		Vector2(-16, -38), Vector2(16, -38), Vector2(22, -22), Vector2(-22, -22)])
	turret.color = col
	turret.position = base_pos + Vector2(0, -16)
	add_child(turret)
	var barrel := ColorRect.new()
	barrel.color = Color(col.r * 0.7, col.g * 0.7, col.b * 0.7, 0.9)
	barrel.size = Vector2(38, 4)
	barrel.position = base_pos + Vector2(14, -38)
	add_child(barrel)

func _make_ref_box(top_left: Vector2, col: Color, caption: String) -> void:
	var box := ColorRect.new()
	box.color = Color(col.r, col.g, col.b, 0.18)
	box.size = Vector2(48, 64)
	box.position = top_left
	# 边框用九宫格麻烦，直接叠一个 Line2D 矩形
	var frame := Line2D.new()
	frame.width = 2.0
	frame.default_color = col
	frame.add_point(top_left)
	frame.add_point(top_left + Vector2(48, 0))
	frame.add_point(top_left + Vector2(48, 64))
	frame.add_point(top_left + Vector2(0, 64))
	frame.add_point(top_left)
	add_child(box)
	add_child(frame)
	_make_caption(caption, top_left + Vector2(-8, -24), 14)

func _make_caption(text: String, pos: Vector2, size: int) -> void:
	var l := Label.new()
	l.text = text
	l.position = pos
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", Color(0.75, 0.78, 0.85))
	add_child(l)

## ── 矩阵主循环：12 族 × 敌我 × 开火/命中 ──
func _run_matrix() -> void:
	var families: Array = WVP.all_families()
	# v20.20-fix: 每族实拍 6 格（muzzle/trajectory/impact × 敌我），旧值 ×4 是三段计数
	# 之前的遗留，日志一直显示"72/48"。
	_total_cells = families.size() * 6
	for f in families:
		var profile: Dictionary = WVP.profile_of(f)
		var row_shots: Dictionary = {}
		for side in [true, false]:
			var side_name: String = "player" if side else "enemy"
			# v17k: 加弹道飞行格（开火→飞行→命中三段叙事）——旧矩阵只拍开火/命中，
			# 弹道维度（弹体/曳光/拖尾）从未被审计（4.2 基线不含弹道分）
			for kind in ["muzzle", "trajectory", "impact"]:
				_cell_index += 1
				var cell: String = "f%02d_%s_%s" % [int(f), side_name, kind]
				_info_label.text = "[%d/%d] %s · %s · %s" % [
					_cell_index, _total_cells, WVP.family_label(int(f)),
					"我方" if side else "敌方", "开火" if kind == "muzzle" else "命中"]
				_clear_fx()
				if kind == "muzzle":
					await _spawn_muzzle_cell_burst(int(f), side)
				elif kind == "trajectory":
					await _spawn_trajectory_cell(int(f), side)
					_capture_center = _TRAJ_CENTER
				else:
					_spawn_impact_cell(int(f), side)
					_capture_center = IMPACT_POS
				if kind != "trajectory":
					_capture_center = MUZZLE_POS if kind == "muzzle" else IMPACT_POS
				await _capture(cell + ".png", _capture_center)
				row_shots["%s_%s" % [side_name, kind]] = cell + ".png"
				# v17b: manifest 行——AI 评分的单一元数据源（与截图同批生成，永不脱节）
				_manifest.append({
					"file": cell + ".png",
					"family": int(f),
					"family_label": WVP.family_label(int(f)),
					# v18: 弹道格 kind 标真值——旧版把 trajectory 也标成 "impact"，
				# AI 评分拿命中规格判飞行截图（判决高频"呈现为弹道拖尾而非命中"即此故），
				# 弹道维度分数全部失真。
				"kind": kind,
					"is_player": side,
					"power_tier": int(REP_TIER.get(int(f), 0)),
					"muzzle_class": String(profile.get("muzzle", "")),
					"impact_class": String(profile.get("impact", "")),
					"spec": String(profile.get("spec", "")),
				})
				await _settle()
		_html_rows += _html_family_row(int(f), profile, row_shots)
		print("[vfx_audit] %d/%d 族完成: %s" % [_cell_index, _total_cells, WVP.family_label(int(f))])

## v17l: muzzle 格连拍 3 次（AI 批"开火反馈弱"——单帧只有一颗星；
## 实战连发是密集弹幕但静态单发不可见，连拍让弹幕密度可测）
func _spawn_muzzle_cell_burst(f: int, side: bool) -> void:
	# v17l-fix: 最后一发不等（总 0.12s）——capture 首帧 0.05s 恰拍到第 3 发峰值 + 第 2 发余焰。
	# 旧版 3 次全等（0.18s）+ capture 再等 → 截图时枪口火（寿命 0.14s）全灭拍空场。
	for i in range(3):
		_spawn_muzzle_cell(f, side)
		if i < 2:
			await get_tree().create_timer(0.06).timeout

func _spawn_muzzle_cell(f: int, side: bool) -> void:
	# 开火格 = 单位级枪口火（construct_unit_ai._play_muzzle_feedback 的真身入口）
	# + bullet 路径的炮口贴图层——v17c 与 bullet._spawn_muzzle_effect 同步：
	# 轻武器无贴图层（粒子火星足够）；能量喷流 0.11（实测 974px 内容 → ~107px）；
	# 重炮爆闪 0.35（125px 内容 → ~44px）；wt6 代表名"粒子束步枪"是光束类 → 0.09。
	VfxFactory.spawn_muzzle_flash(_fx_layer, MUZZLE_POS, side, f)
	# v17d: 重炮枪口贴图换火焰舌（替代圆形爆球）；其他族保持 v17c 配置
	if f in [8, 10, 11]:
		VfxFactory.spawn_impact_sprite(_fx_layer, MUZZLE_POS, VfxFactory.PARTICLE_TEX_MUZZLE_ENERGY, 0.14, 0.14)
	elif f == 6:
		# v20.20: 与 bullet.gd wt6 同步（0.10/0.12 → 0.14/0.14，见 bullet._spawn_muzzle_effect）
		VfxFactory.spawn_impact_sprite(_fx_layer, MUZZLE_POS, VfxFactory.PARTICLE_TEX_MUZZLE_ENERGY, 0.14, 0.14)
	elif f in VfxFactory.HEAVY_MUZZLE_WT:
		VfxFactory.spawn_impact_sprite(_fx_layer, MUZZLE_POS, VfxFactory.PARTICLE_TEX_MUZZLE_JET, 0.42, 0.16)  # v18-R10d: 枪口贴图层回退旧图（v2 摄影版暗色读为空）

func _spawn_impact_cell(f: int, side: bool) -> void:
	# 命中格 = 正式命中入口（含 8/10/11 签名特效分支、power_tier 分级、专属贴图链）
	var opts: Dictionary = {"power_tier": int(REP_TIER.get(f, 0)), "direction": Vector2.RIGHT}
	ProjVfx.spawn_impact_with_kind(_fx_layer, IMPACT_POS, f, side, -1, opts, String(REP_NAME.get(f, "")))

func _clear_fx() -> void:
	# v19-R25: queue_free() 延迟释放导致上一格节点仍残留在树中，污染当前格截图。
	# 改用立即 remove_child + free，确保清理完成后再 spawn 新节点。
	for child in _fx_layer.get_children():
		_fx_layer.remove_child(child)
		child.free()

func _capture(file_name: String, center: Vector2) -> void:
	# v17c 三帧择优：见 CAPTURE_FRAMES 注释。逐帧截取特效区亮度最高的一张落盘。
	var best_img: Image = null
	var best_bright: float = -1.0
	var last_t: float = 0.0
	for t in CAPTURE_FRAMES:
		await get_tree().create_timer(t - last_t).timeout
		last_t = t
		await RenderingServer.frame_post_draw
		var img: Image = get_viewport().get_texture().get_image()
		var b: float = _region_brightness(img, center)
		if b > best_bright:
			best_bright = b
			best_img = img
	if best_img != null:
		best_img.save_png(SHOT_DIR + file_name)

## 特效区（center±130px）核心亮度合计——三帧择优选帧用。
## v17c: 阈值 45→140——总亮度指标偏向大面积弥散光（ADD 烟团），选出的都是烟帧导致
## AI 复测全格读成"烟雾云"。改按核心亮像素（>140，白热闪光级）计数，火帧必胜烟帧。
func _region_brightness(img: Image, center: Vector2) -> float:
	var total: float = 0.0
	var r := 130
	var x0: int = maxi(int(center.x) - r, 0)
	var x1: int = mini(int(center.x) + r, img.get_width())
	var y0: int = maxi(int(center.y) - r, 0)
	var y1: int = mini(int(center.y) + r, img.get_height())
	for y in range(y0, y1):
		for x in range(x0, x1):
			var c: Color = img.get_pixel(x, y)
			var v: float = (c.r8 + c.g8 + c.b8) / 3.0
			if v > 140.0:
				total += v
	return total

func _settle() -> void:
	await get_tree().create_timer(SETTLE_FOR).timeout

## ── 名字解析审计（HTML 附表：全部 UCT 武器名 → 族/溯源）──
func _build_resolution_audit() -> void:
	var names: Dictionary = {}
	for e in UCT.get_all_entries():
		for key in ["w_light", "w_armor", "w_air"]:
			var raw: String = String(e.get(key, ""))
			if not raw.is_empty():
				names[raw] = true
	_name_total = names.size()
	var by_family: Dictionary = {}
	for n in names.keys():
		var traced: Dictionary = WVP.resolve_traced(String(n), 0, true)
		var fam: int = int(traced["visual_wt"])
		if String(traced["via"]) != "wt_fallback":
			_name_resolved += 1
		else:
			_fallback_names.append(String(n))
		by_family[fam] = int(by_family.get(fam, 0)) + 1
		_audit_rows += "<tr><td>%s</td><td>%s</td><td>%s</td></tr>\n" % [
			String(n), _via_badge(String(traced["via"])), WVP.family_label(fam)]
	var fam_summary: String = ""
	for f in WVP.all_families():
		fam_summary += "%s×%d　" % [WVP.family_label(int(f)), int(by_family.get(int(f), 0))]
	print("[vfx_audit] 名字解析: %d/%d 有明确信号 | %s" % [_name_resolved, _name_total, fam_summary])

func _via_badge(via: String) -> String:
	if via == "exact":
		return "<span style=\"color:#4cc2ff\">exact</span>"
	if via == "keyword":
		return "<span style=\"color:#7ee787\">keyword</span>"
	return "<span style=\"color:#f0883e\">wt_fallback</span>"

## ── 审查页（浏览器打开，逐格对照 spec 打分）──
func _html_family_row(f: int, profile: Dictionary, shots: Dictionary) -> String:
	var row: String = ""
	row += "<div class=\"fam\">\n"
	row += "<h2>%s <small>visual_wt=%d</small></h2>\n" % [String(profile.get("label", "")), f]
	row += "<div class=\"meta\">枪口火：%s ｜ 命中：%s ｜ 弹体：%s ｜ 震屏：%s</div>\n" % [
		profile.get("muzzle", ""), profile.get("impact", ""), profile.get("projectile", ""), profile.get("shake", "")]
	row += "<div class=\"spec\"><b>验收规格：</b>%s</div>\n" % String(profile.get("spec", ""))
	row += "<div class=\"grid\">\n"
	for key in ["player_muzzle", "enemy_muzzle", "player_impact", "enemy_impact"]:
		var cap: String = {
			"player_muzzle": "我方·开火", "enemy_muzzle": "敌方·开火",
			"player_impact": "我方·命中", "enemy_impact": "敌方·命中"}[key]
		row += "<figure><img src=\"../docs/vfx_audit_shots/%s\" loading=\"lazy\"><figcaption>%s</figcaption></figure>\n" % [shots.get(key, ""), cap]
	row += "</div></div>\n"
	return row

func _write_html() -> void:
	var fb_list: String = "无"
	if not _fallback_names.is_empty():
		fb_list = "、".join(PackedStringArray(_fallback_names))
	var cov: float = 100.0 * float(_name_resolved) / float(maxi(_name_total, 1))
	var html: String = """<!DOCTYPE html>
<html lang="zh"><head><meta charset="utf-8">
<title>VFX 全矩阵视觉审计</title>
<style>
body{background:#101216;color:#cdd3dd;font-family:"Microsoft YaHei",sans-serif;margin:24px;max-width:1400px}
h1{color:#e8ecf3}h2{color:#9fd0ff;margin-bottom:4px}h2 small{color:#5a6472;font-weight:normal}
.meta{color:#8b95a5;font-size:14px}.spec{background:#171b22;border-left:3px solid #4cc2ff;padding:8px 12px;margin:8px 0;font-size:14px}
.grid{display:grid;grid-template-columns:repeat(4,1fr);gap:10px}
figure{margin:0;background:#0b0d10;border:1px solid #232a35;border-radius:6px;overflow:hidden}
figure img{width:100%%;display:block}figcaption{padding:6px 8px;font-size:12px;color:#8b95a5;text-align:center}
table{border-collapse:collapse;font-size:13px}td,th{border:1px solid #232a35;padding:3px 10px}
th{color:#9fd0ff;background:#171b22}.warn{color:#f0883e}
details{margin-top:16px}
</style></head><body>
<h1>VFX 全矩阵视觉审计</h1>
<p>生成时间：%s ｜ %d 格截图（12 武器族 × 敌我 × 开火/命中）｜ 枪口火在参考单位旁、命中在目标单位旁，对照 100px 标尺与验收规格逐格检查。</p>
<p>武器名解析覆盖：%d/%d（%.0f%%）有明确视觉信号；<span class="warn">wt_fallback %d 个</span>：%s</p>
%s
<details><summary>全部武器名解析表（%d 行）</summary><table>
<tr><th>武器名</th><th>解析途径</th><th>视觉族</th></tr>
%s</table></details>
</body></html>""" % [
		Time.get_datetime_string_from_system(), _total_cells,
		_name_resolved, _name_total, cov, _fallback_names.size(), fb_list,
		_html_rows, _name_total, _audit_rows]
	var f := FileAccess.open(HTML_PATH, FileAccess.WRITE)
	if f == null:
		push_error("[vfx_audit] 无法写审查页: " + HTML_PATH)
		return
	f.store_string(html)
	f.close()
	# v17b: manifest 落盘（AI 评分脚本消费）
	var mf := FileAccess.open(SHOT_DIR + "manifest.json", FileAccess.WRITE)
	if mf != null:
		mf.store_string(JSON.stringify({"cells": _manifest, "generated": Time.get_datetime_string_from_system()}, "\t"))
		mf.close()
