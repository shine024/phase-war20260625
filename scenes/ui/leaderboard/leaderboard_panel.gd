extends PanelContainer
## 排行榜面板：显示公司势力排名和相位师排名
## v7.x 面板统一：迁出 PopupPanel，改走常驻 Overlay（与其他 20+ 面板同构），
## 由 main.gd _toggle_overlay 统一开关；关闭统一 PanelChrome 右上 ✕。

const CompanyDefs = preload("res://data/company_definitions.gd")  # 统一阵营色来源
const DT = preload("res://resources/design_tokens.gd")
const PanelStyles = preload("res://scripts/ui/panel_styles.gd")
const PanelChrome = preload("res://scenes/ui/components/panel_chrome.gd")

signal closed
signal master_selected(master_id: String)  # 相位师选择信号
##
## 势力排行规则：
##   各公司固定控制若干关卡（由 LevelInformation.faction_id 决定）
##   排行依据 = 玩家已通过该公司领地内的关卡数（score）
##   次要指标 = 该公司总领地数（territories_total）
##   声望（reputation）是玩家对该公司的个人好感度，不参与排名

# 势力色统一来源：CompanyDefinitions.get_faction_color()（Palette B 高饱和）

# 行模板场景（场景化：替代 .new() 链）
const FactionRowScene = preload("res://scenes/ui/leaderboard/faction_row.tscn")
const PlayerRowScene = preload("res://scenes/ui/leaderboard/player_row.tscn")
const EnemyRowScene = preload("res://scenes/ui/leaderboard/enemy_row.tscn")

## 共享样式资源（延迟加载，避免 preload 在 import 系统未就绪时失败）
static func _get_skill_panel_style() -> StyleBox:
	if not ResourceLoader.exists("res://scenes/ui/leaderboard/skill_panel_style.tres"):
		return StyleBoxFlat.new()
	return load("res://scenes/ui/leaderboard/skill_panel_style.tres") as StyleBox

var _tab_bar: TabBar
var _list_container: VBoxContainer
var _current_tab: int = 0
var _faction_data: Array = []  # 公司势力数据（从 FactionSystemManager 读取）
var _player_data: Array = []   # 相位师排名数据

# 敌方相位师排行榜相关
const EnemyPhaseLeaderboard = preload("res://data/enemy_phase_leaderboard.gd")
const LeaderboardEntry = preload("res://data/leaderboard_entry.gd")
const EnemyPhaseEquipment = preload("res://data/enemy_phase_equipment.gd")
var _enemy_leaderboard: EnemyPhaseLeaderboard
var _current_enemy_tab: int = 0  # 敌方相位师当前子标签
var _selected_master_id: String = ""  # 当前选中的相位师ID

# NPC相位师战斗配置：根据关卡进度使用对应时代的卡牌
# 格式：{ name: 相位师名, faction: 势力ID, platform_id: 平台卡ID, weapon_ids: [武器卡ID列表], era: 时代 }
const NPC_PHASE_MASTERS: Array = [
	{"name": "终焉之镰",   "faction": "void_research",     "era": "future",   "platform": "platform_future_heavy", "weapons": ["weapon_future_plasma", "weapon_future_rail", "weapon_future_laser"]},
	{"name": "炽焰星痕",   "faction": "nova_arms",         "era": "future",   "platform": "platform_future_medium", "weapons": ["weapon_future_laser", "weapon_future_plasma"]},
	{"name": "雷霆判官",   "faction": "aether_dynamics",  "era": "cold",     "platform": "platform_cold_medium",   "weapons": ["weapon_cold_missile", "weapon_cold_sniper", "weapon_cold_lmg"]},
	{"name": "寒霜壁垒",   "faction": "iron_wall_corp",    "era": "ww2",      "platform": "platform_ww2_heavy",    "weapons": ["weapon_ww2_mg", "weapon_ww2_at", "weapon_ww2_rifle"]},
	{"name": "量子幽灵",   "faction": "quantum_logistics", "era": "modern",   "platform": "platform_modern_medium", "weapons": ["weapon_modern_missile", "weapon_modern_sniper"]},
	{"name": "虚空低语",   "faction": "helix_recon",       "era": "future",   "platform": "platform_future_light", "weapons": ["weapon_future_laser", "weapon_future_rail"]},
	{"name": "边境开拓者", "faction": "frontier_union",    "era": "ww2",      "platform": "platform_ww2_light",    "weapons": ["weapon_ww2_smg", "weapon_ww2_mg"]},
]

## 获取当前活跃的相位师配置（基于排行榜前几名的NPC）
func get_active_phase_masters() -> Array:
	return NPC_PHASE_MASTERS.duplicate()

## 根据相位师名字获取配置
func get_phase_master_config(name: String) -> Dictionary:
	for config in NPC_PHASE_MASTERS:
		if config.get("name") == name:
			return config
	return {}

func _ready() -> void:
	# v7.x 面板统一：MEDIUM 档 + 金色签名框架 + PanelChrome 标题栏（右上 ✕ 关闭）
	custom_minimum_size = DT.PANEL_SIZE_MEDIUM
	var accent := DT.get_panel_accent("leaderboard")
	add_theme_stylebox_override("panel", PanelStyles.make_panel_frame(accent))
	var chrome = PanelChrome.attach_to($Margin/VBox, "排行榜", accent, "LEADERBOARD")
	chrome.closed.connect(_on_close)
	# 获取各个节点
	_tab_bar = get_node_or_null("Margin/VBox/TabBar") as TabBar
	_list_container = get_node_or_null("Margin/VBox/ScrollContainer/LeaderboardList") as VBoxContainer

	if _tab_bar:
		_tab_bar.tab_changed.connect(_on_tab_changed)
		_tab_bar.add_tab("公司势力排名")
		_tab_bar.add_tab("相位师排名")
		_tab_bar.add_tab("敌方相位师")
		_tab_bar.current_tab = 0

	# 初始化敌方相位师排行榜
	_enemy_leaderboard = EnemyPhaseLeaderboard.new()

	# 初始化数据
	_initialize_faction_data()
	_initialize_player_data()

	# 显示第一个标签页
	_refresh_list()

## 初始化公司势力数据
## 排序依据：玩家已通关该公司领地内的关卡数（score = cleared_in_territory）
func _initialize_faction_data() -> void:
	_faction_data.clear()
	
	# 玩家当前关卡进度（current_level - 1 = 已通关数，关卡是顺序解锁的）
	var current_level: int = 1
	if GameManager and "current_level" in GameManager:
		current_level = int(GameManager.current_level)
	var cleared_max: int = max(0, current_level - 1)  # 已通关的最高关号
	
	var fsm: Node = get_node_or_null("/root/FactionSystemManager")
	if fsm and fsm.has_method("get_all_factions_info"):
		var all_factions: Array = fsm.get_all_factions_info()
		for fi in all_factions:
			var fid: String = fi.get("id", "")
			if fid.is_empty():
				continue
			var controlled: Array = fi.get("controlled_levels", [])
			var total: int = controlled.size()
			# 计算玩家已通过该公司领地内的关卡数
			var cleared: int = 0
			for lv in controlled:
				if int(lv) <= cleared_max:
					cleared += 1
			_faction_data.append({
				"name": fi.get("name", fid),
				"faction_id": fid,
				"score": cleared,               # 玩家已攻克的该公司领地数 → 排序依据
				"territories_total": total,     # 该公司总领地数
				"reputation": fi.get("reputation", 0),  # 玩家对该公司的声望（独立显示，不排序）
			})
	else:
		# Fallback：FactionSystemManager 不可用时用静态领地数据
		push_warning("LeaderboardPanel: FactionSystemManager 不可用，使用静态数据")
		var static_data: Array = [
			{"name": "钢壁防务公司",   "faction_id": "iron_wall_corp",    "start": 1,  "end": 20},
			{"name": "新星兵工制造",   "faction_id": "nova_arms",         "start": 21, "end": 40},
			{"name": "以太动力重工",   "faction_id": "aether_dynamics",   "start": 41, "end": 60},
			{"name": "量子后勤集团",   "faction_id": "quantum_logistics", "start": 61, "end": 80},
			{"name": "螺旋侦察系统",   "faction_id": "helix_recon",       "start": 81, "end": 90},
			{"name": "虚空相位研究所", "faction_id": "void_research",     "start": 91, "end": 100},
			{"name": "边境联合公司",   "faction_id": "frontier_union",    "start": 0,  "end": -1},
		]
		for sd in static_data:
			var s: int = sd["start"]; var e: int = sd["end"]
			var total: int = max(0, e - s + 1) if e >= s else 0
			var cleared: int = clampi(cleared_max - s + 1, 0, total) if s > 0 else 0
			_faction_data.append({
				"name": sd["name"],
				"faction_id": sd["faction_id"],
				"score": cleared,
				"territories_total": total,
				"reputation": 0,
			})
	
	# 主排序：已攻克领地数降序；同分则总领地多的排前（更强的公司）
	_faction_data.sort_custom(func(a, b) -> bool:
		if a["score"] != b["score"]:
			return a["score"] > b["score"]
		return a["territories_total"] > b["territories_total"]
	)

## 初始化相位师排名数据（基于真实玩家进度）
## 排名构成：玩家本人（真实进度）+ 各势力挑战者（基于真实占领数的基准进度）
## 不再使用硬编码的虚构NPC名字/胜场/胜率——所有进度数据来自真实游戏状态。
func _initialize_player_data() -> void:
	_player_data.clear()

	# === 读取玩家真实进度 ===
	var player_max_level: int = 1
	var player_stars: int = 0
	var lpm: Node = get_node_or_null("/root/LevelProgressManager")
	if lpm and lpm.has_method("get_max_unlocked_level"):
		player_max_level = int(lpm.get_max_unlocked_level())
	# 累计真实星数（每关 0-3 星）
	if lpm and "level_stars" in lpm:
		for lv in range(1, player_max_level + 1):
			player_stars += int(lpm.level_stars.get(lv, 0))

	# 玩家势力（激活势力，无激活则"自由相位师"）
	var player_faction_id: String = ""
	var player_faction_name: String = "自由相位师"
	var fsm: Node = get_node_or_null("/root/FactionSystemManager")
	if fsm and fsm.has_method("get_active_faction"):
		player_faction_id = String(fsm.get_active_faction())
	if player_faction_id != "" and fsm and fsm.has_method("get_faction_info"):
		var pfac: Dictionary = fsm.get_faction_info(player_faction_id)
		player_faction_name = String(pfac.get("name", player_faction_name))

	# 玩家行：真实进度
	_player_data.append({
		"rank": 0,  # 排序后回填
		"name": "我（玩家）",
		"current_level": player_max_level,
		"wins": player_stars,  # 复用 wins 列显示星数（更有意义的真实指标）
		"win_rate": 0.0,
		"preferred_faction": player_faction_id,
		"faction_name": player_faction_name,
		"is_player": true,
	})

	# === 各势力挑战者（基于真实占领数的基准进度，非硬编码） ===
	# 每个势力派出一名"挑战者"，其进度 = 该势力真实控制的关卡数（占领越多进度越高）
	if fsm and fsm.has_method("get_all_factions_info"):
		var all_factions: Array = fsm.get_all_factions_info()
		for fi in all_factions:
			var fid: String = fi.get("id", "")
			if fid.is_empty() or fid == player_faction_id:
				continue
			var controlled: Array = fi.get("controlled_levels", [])
			var territory: int = controlled.size()
			# 挑战者进度 = 占领的最高关卡（真实领地）
			var challenger_level: int = 1
			if not controlled.is_empty():
				challenger_level = int(controlled.max())
			# 星数估算：占领领地 × 2（基准星，非伪造——来源是真实占领数）
			var challenger_stars: int = territory * 2
			_player_data.append({
				"rank": 0,
				"name": "%s·挑战者" % String(fi.get("name", fid)),
				"current_level": challenger_level,
				"wins": challenger_stars,
				"win_rate": 0.0,
				"preferred_faction": fid,
				"faction_name": String(fi.get("name", fid)),
				"is_player": false,
			})

	# 按"当前关卡"降序排序，同分看星数
	_player_data.sort_custom(func(a, b) -> bool:
		if a.get("current_level", 0) != b.get("current_level", 0):
			return a.get("current_level", 0) > b.get("current_level", 0)
		return a.get("wins", 0) > b.get("wins", 0)
	)
	for i in range(_player_data.size()):
		_player_data[i]["rank"] = i + 1

## 标签页切换信号处理
func _on_tab_changed(tab: int) -> void:
	_current_tab = tab
	_refresh_list()

## 刷新列表显示
func _refresh_list() -> void:
	if _list_container == null:
		return
	
	# 清空列表
	for child in _list_container.get_children():
		child.queue_free()
	
	match _current_tab:
		0:
			_refresh_faction_list()
		1:
			_refresh_player_list()
		2:
			_refresh_enemy_master_list()
		_:
			_refresh_faction_list()

## 刷新公司势力榜单（场景化：使用 FactionRowScene 模板）
func _refresh_faction_list() -> void:
	if _list_container == null:
		return

	# 添加标题行
	_list_container.add_child(_build_faction_header())
	# 分割线
	_list_container.add_child(_make_separator())

	if _faction_data.is_empty():
		_list_container.add_child(_make_empty_hint("暂无势力数据"))
		return

	for i in range(_faction_data.size()):
		var row = FactionRowScene.instantiate()
		_list_container.add_child(row)
		row.setup(i + 1, _faction_data[i])

## 刷新相位师排名（场景化：使用 PlayerRowScene 模板）
func _refresh_player_list() -> void:
	if _list_container == null:
		return

	# 标题行
	_list_container.add_child(_build_player_header())
	# 分割线
	_list_container.add_child(_make_separator())

	if _player_data.is_empty():
		_list_container.add_child(_make_empty_hint("暂无排名数据"))
		return

	for player_info in _player_data:
		var row = PlayerRowScene.instantiate()
		_list_container.add_child(row)
		row.setup(player_info)

## 刷新敌方相位师排行榜（场景化：使用 EnemyRowScene 模板）
func _refresh_enemy_master_list() -> void:
	if _list_container == null:
		return

	# 添加标题行
	_list_container.add_child(_build_enemy_header())
	# 分割线
	_list_container.add_child(_make_separator())

	# 获取前15名敌方相位师
	var top_entries = _enemy_leaderboard.get_top_entries(15)

	if top_entries.is_empty():
		_list_container.add_child(_make_empty_hint("暂无敌方相位师数据"))
		return

	for entry in top_entries:
		var row = EnemyRowScene.instantiate()
		_list_container.add_child(row)
		row.setup(entry)
		row.row_pressed.connect(_on_master_selected)

## 构建空状态提示 Label（列表数据为空时显示）
func _make_empty_hint(text: String) -> Control:
	var lbl := Label.new()
	lbl.text = text
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_color_override("font_color", DT.COLOR_TEXT_DIM)
	lbl.add_theme_font_size_override("font_size", DT.FONT_SIZE_SMALL)
	lbl.custom_minimum_size = Vector2(0, 80)
	lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return lbl

## 相位师选择处理
func _on_master_selected(master_id: String) -> void:
	_selected_master_id = master_id
	master_selected.emit(master_id)
	# 显示详细信息面板
	_show_master_details_popup(master_id)

## 关闭弹窗（Overlay 由 main.gd 统一收起）
func _on_close() -> void:
	closed.emit()

## 外部接口：显示排行榜（可见性由 Overlay 管理，这里只负责刷新数据）
func show_leaderboard() -> void:
	refresh()

## 刷新排行榜数据（可在面板可见时随时调用）
func refresh() -> void:
	_initialize_faction_data()
	_initialize_player_data()
	_refresh_list()

# ══════════════════════════════════════════════════════════════
# 标题行构建（仅列标题，少量 .new()，每次 tab 切换仅 1 次）
# ══════════════════════════════════════════════════════════════

func _build_faction_header() -> Control:
	var container = HBoxContainer.new()
	container.add_theme_constant_override("separation", 8)
	container.add_child(_make_header_label("排名", 40, HORIZONTAL_ALIGNMENT_LEFT))
	var h_name = _make_header_label("公司名称", 0, HORIZONTAL_ALIGNMENT_LEFT)
	h_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.add_child(h_name)
	container.add_child(_make_header_label("已攻克/总关", 100, HORIZONTAL_ALIGNMENT_CENTER))
	container.add_child(_make_header_label("声望", 70, HORIZONTAL_ALIGNMENT_RIGHT))
	return container

func _build_player_header() -> Control:
	var container = HBoxContainer.new()
	container.add_theme_constant_override("separation", 8)
	container.add_child(_make_header_label("排名", 35, HORIZONTAL_ALIGNMENT_CENTER))
	var h_name = _make_header_label("相位师", 0, HORIZONTAL_ALIGNMENT_LEFT)
	h_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.add_child(h_name)
	container.add_child(_make_header_label("当前关", 55, HORIZONTAL_ALIGNMENT_CENTER))
	container.add_child(_make_header_label("势力", 90, HORIZONTAL_ALIGNMENT_CENTER))
	container.add_child(_make_header_label("星级", 50, HORIZONTAL_ALIGNMENT_RIGHT))
	return container

func _build_enemy_header() -> Control:
	var container = HBoxContainer.new()
	container.add_theme_constant_override("separation", 8)
	container.add_child(_make_header_label("排名", 35, HORIZONTAL_ALIGNMENT_CENTER))
	var h_name = _make_header_label("相位师", 0, HORIZONTAL_ALIGNMENT_LEFT)
	h_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.add_child(h_name)
	container.add_child(_make_header_label("等级", 50, HORIZONTAL_ALIGNMENT_CENTER))
	container.add_child(_make_header_label("势力", 70, HORIZONTAL_ALIGNMENT_CENTER))
	container.add_child(_make_header_label("难度", 60, HORIZONTAL_ALIGNMENT_CENTER))
	container.add_child(_make_header_label("胜率", 55, HORIZONTAL_ALIGNMENT_RIGHT))
	return container

# ══════════════════════════════════════════════════════════════
# 共享辅助函数
# ══════════════════════════════════════════════════════════════

func _make_header_label(text: String, min_width: int, align: int) -> Label:
	var lbl = Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", DT.FONT_SIZE_SMALL)
	lbl.add_theme_color_override("font_color", DT.COLOR_CYAN_TECH)
	if min_width > 0:
		lbl.custom_minimum_size = Vector2(min_width, 0)
	lbl.horizontal_alignment = align
	return lbl

func _make_separator() -> HSeparator:
	var sep = HSeparator.new()
	sep.add_theme_color_override("color", Color(DT.COLOR_BORDER.r, DT.COLOR_BORDER.g, DT.COLOR_BORDER.b, 0.3))
	return sep

## 创建单个小型 Label（用于详情弹窗内嵌数据）
static func _make_stat_label(text: String, font_size: int, color: Color) -> Label:
	var lbl = Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.add_theme_color_override("font_color", color)
	return lbl

# ══════════════════════════════════════════════════════════════
# 敌方相位师详情弹窗（低频创建，保留部分 .new() 但使用 _get_skill_panel_style()）
# ══════════════════════════════════════════════════════════════

## 显示相位师详细信息弹窗
func _show_master_details_popup(master_id: String) -> void:
	var details = _enemy_leaderboard.get_master_details(master_id)
	if details.is_empty():
		return

	var popup = PopupPanel.new()
	popup.title = "相位师详情"
	popup.min_size = Vector2i(420, 320)
	popup.exclusive = true

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 10)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	popup.add_child(margin)

	var scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_child(scroll)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(vbox)

	var basic_info = details.get("basic_info", {})
	vbox.add_child(_create_master_header(basic_info))
	vbox.add_child(HSeparator.new())

	vbox.add_child(_create_stats_display(details.get("stats", {})))
	vbox.add_child(HSeparator.new())

	var equipment_section = _create_equipment_section(details.get("equipment", {}))
	if equipment_section != null:
		vbox.add_child(equipment_section)
		vbox.add_child(HSeparator.new())

	var active_skills = details.get("active_spells", [])
	if not active_skills.is_empty():
		vbox.add_child(_create_skills_section("主动技能", active_skills))

	var passive_skills = details.get("passive_spells", [])
	if not passive_skills.is_empty():
		vbox.add_child(_create_skills_section("被动技能", passive_skills))

	var close_btn = Button.new()
	close_btn.text = "关闭"
	close_btn.custom_minimum_size = Vector2(0, 36)
	close_btn.pressed.connect(popup.hide)
	vbox.add_child(close_btn)

	add_child(popup)
	popup.popup_centered(Vector2i(560, 580))
	popup.visibility_changed.connect(func():
		if is_instance_valid(popup) and not popup.visible:
			popup.call_deferred("queue_free")
	)

## 创建相位师头部信息
func _create_master_header(basic_info: Dictionary) -> Control:
	var container = VBoxContainer.new()
	container.add_theme_constant_override("separation", 5)

	var name_row = HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 6)
	container.add_child(name_row)

	var name_label = Label.new()
	name_label.text = basic_info.get("name", "未知")
	name_label.add_theme_font_size_override("font_size", 18)
	name_label.add_theme_color_override("font_color", Color.WHITE)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_row.add_child(name_label)

	var title_label = Label.new()
	title_label.text = basic_info.get("title", "")
	title_label.add_theme_font_size_override("font_size", 14)
	title_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7, 1))
	title_label.size_flags_horizontal = Control.SIZE_SHRINK_END
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_row.add_child(title_label)

	var info_row = HBoxContainer.new()
	info_row.add_theme_constant_override("separation", 8)
	container.add_child(info_row)

	info_row.add_child(_make_stat_label(
		"Lv.%d  " % basic_info.get("level", 1), 12, Color.WHITE))

	var faction = basic_info.get("faction", "")
	var faction_info = EnemyPhaseLeaderboard.get_faction_display_info(faction)
	var faction_lbl = _make_stat_label(
		"%s%s  " % [faction_info.icon, faction_info.name], 12, faction_info.color)
	info_row.add_child(faction_lbl)

	var difficulty = basic_info.get("difficulty", "")
	var difficulty_info = EnemyPhaseLeaderboard.get_difficulty_display_info(difficulty)
	var stars_text = ""
	for i in range(difficulty_info.stars):
		stars_text += "★"
	info_row.add_child(_make_stat_label(
		"%s %s" % [difficulty_info.name, stars_text], 12, difficulty_info.color))

	return container

## 创建属性显示
func _create_stats_display(stats: Dictionary) -> Control:
	var container = VBoxContainer.new()
	container.add_theme_constant_override("separation", 3)
	container.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	container.add_child(_make_stat_label("战斗属性", 14, Color(0.6, 0.85, 1, 1)))

	var stats_row = HBoxContainer.new()
	stats_row.add_theme_constant_override("separation", 15)
	stats_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.add_child(stats_row)

	stats_row.add_child(_make_stat_label("HP: %d" % stats.get("max_hp", 0), 11, Color(0.8, 0.4, 0.4, 1)))
	stats_row.add_child(_make_stat_label("攻击: %d" % stats.get("attack_power", 0), 11, Color(0.4, 0.8, 0.4, 1)))
	stats_row.add_child(_make_stat_label("防御: %d" % stats.get("defense", 0), 11, Color(0.4, 0.4, 0.8, 1)))
	stats_row.add_child(_make_stat_label("能量: %.1f/s" % stats.get("energy_regen", 0), 11, Color(0.4, 0.8, 0.8, 1)))

	return container

## 创建装备情报区域（相位仪 + 战斗平台）
func _create_equipment_section(equipment: Dictionary) -> Control:
	if equipment.is_empty():
		return null

	var container = VBoxContainer.new()
	container.add_theme_constant_override("separation", 8)
	container.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# — 相位仪 —
	var instrument_id: String = equipment.get("phase_instrument", "")
	if not instrument_id.is_empty():
		var inst_data: Dictionary = EnemyPhaseEquipment.get_phase_instrument(instrument_id)
		var inst_name: String = inst_data.get("name", instrument_id)
		var inst_level: int = int(equipment.get("level", 1))
		var inst_faction: String = equipment.get("instrument_faction", inst_data.get("faction", ""))
		var faction_info = EnemyPhaseLeaderboard.get_faction_display_info(inst_faction) if not inst_faction.is_empty() else null
		var inst_color: Color = faction_info.color if faction_info else Color(0.6, 0.85, 1.0, 1)

		var inst_box = PanelContainer.new()
		inst_box.add_theme_stylebox_override("panel", _get_skill_panel_style())
		inst_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var inst_inner = VBoxContainer.new()
		inst_inner.add_theme_constant_override("separation", 3)
		inst_inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		inst_box.add_child(inst_inner)

		var inst_header = HBoxContainer.new()
		inst_header.add_theme_constant_override("separation", 8)
		inst_inner.add_child(inst_header)

		inst_header.add_child(_make_stat_label("相位仪", 13, Color(0.6, 0.85, 1.0, 1)))
		var inst_level_lbl = _make_stat_label("Lv.%d" % inst_level, 11, inst_color)
		inst_level_lbl.size_flags_horizontal = Control.SIZE_SHRINK_END
		inst_header.add_child(inst_level_lbl)

		var inst_name_lbl = Label.new()
		inst_name_lbl.text = inst_name
		inst_name_lbl.add_theme_font_size_override("font_size", 14)
		inst_name_lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.6, 1))
		inst_name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		inst_inner.add_child(inst_name_lbl)

		# 相位仪属性摘要（v7.x: 统一池用 star + level + properties，base_stats 已废）
		var inst_star: int = int(inst_data.get("star", 0))
		if inst_star > 0:
			var inst_stats_row = HBoxContainer.new()
			inst_stats_row.add_theme_constant_override("separation", 12)
			inst_stats_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			inst_inner.add_child(inst_stats_row)
			inst_stats_row.add_child(_make_stat_label("%d★" % inst_star, 10, Color(1.0, 0.9, 0.6, 0.9)))
			var inst_data_level: int = int(inst_data.get("level", 0))
			if inst_data_level > 0:
				inst_stats_row.add_child(_make_stat_label("Lv.%d" % inst_data_level, 10, Color(0.8, 0.8, 0.8, 0.9)))
			for p in inst_data.get("properties", []):
				var disp: String = String(p.get("display", ""))
				if not disp.is_empty():
					inst_stats_row.add_child(_make_stat_label(disp, 10, Color(0.6, 0.8, 0.6, 0.9)))

		container.add_child(inst_box)

	# — 战斗载具 —
	var platforms: Array = equipment.get("platforms", [])
	if not platforms.is_empty():
		var excluded_types: Array[String] = ["striker", "sniper", "stealth", "mage"]
		container.add_child(_make_stat_label("战斗载具", 13, Color(0.6, 0.85, 1.0, 1)))

		for pid in platforms:
			var pdata: Dictionary = EnemyPhaseEquipment.get_war_platform(pid)
			var pname: String = pdata.get("name", pid)
			var ptype: String = pdata.get("type", "")
			if excluded_types.has(ptype):
				continue
			var pstats: Dictionary = pdata.get("stats", {})
			var pspecial: Array = pdata.get("special", [])

			var plat_box = PanelContainer.new()
			plat_box.add_theme_stylebox_override("panel", _get_skill_panel_style())
			plat_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var plat_inner = VBoxContainer.new()
			plat_inner.add_theme_constant_override("separation", 2)
			plat_inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			plat_box.add_child(plat_inner)

			var plat_header = HBoxContainer.new()
			plat_header.add_theme_constant_override("separation", 8)
			plat_inner.add_child(plat_header)

			var plat_name_lbl = Label.new()
			plat_name_lbl.text = pname
			plat_name_lbl.add_theme_font_size_override("font_size", 12)
			plat_name_lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.6, 1))
			plat_name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			plat_header.add_child(plat_name_lbl)

			if not ptype.is_empty():
				var type_lbl = Label.new()
				type_lbl.text = _platform_type_display(ptype)
				type_lbl.add_theme_font_size_override("font_size", 10)
				type_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8, 1))
				type_lbl.size_flags_horizontal = Control.SIZE_SHRINK_END
				plat_header.add_child(type_lbl)

			if not pstats.is_empty():
				var plat_stats_row = HBoxContainer.new()
				plat_stats_row.add_theme_constant_override("separation", 12)
				plat_stats_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				plat_inner.add_child(plat_stats_row)
				if pstats.has("hp"):
					plat_stats_row.add_child(_make_stat_label("HP:%d" % int(pstats["hp"]), 10, Color(0.8, 0.4, 0.4, 0.9)))
				if pstats.has("attack"):
					plat_stats_row.add_child(_make_stat_label("攻击:%d" % int(pstats["attack"]), 10, Color(0.4, 0.8, 0.4, 0.9)))
				if pstats.has("defense"):
					plat_stats_row.add_child(_make_stat_label("防御:%d" % int(pstats["defense"]), 10, Color(0.4, 0.4, 0.8, 0.9)))
				if pstats.has("defense"):
					plat_stats_row.add_child(_make_stat_label("防御:%d" % int(pstats["defense"]), 10, Color(0.4, 0.4, 0.8, 0.9)))

			if not pspecial.is_empty():
				var tags_lbl = Label.new()
				tags_lbl.text = "  ".join(pspecial)
				tags_lbl.add_theme_font_size_override("font_size", 10)
				tags_lbl.add_theme_color_override("font_color", Color(0.5, 0.6, 0.7, 0.8))
				tags_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				tags_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				plat_inner.add_child(tags_lbl)

			container.add_child(plat_box)

	return container

## 平台类型中文显示
static func _platform_type_display(type_str: String) -> String:
	match type_str:
		"fortress": return "[堡垒]"
		"titan": return "[泰坦]"
		"raider": return "[突击]"
		"siege": return "[攻城]"
		"striker": return "[猎犬]"
		"sniper": return "[侦察]"
		"stealth": return "[隐匿]"
		"mage": return "[护卫]"
		_: return "[%s]" % type_str

## 创建技能区域
func _create_skills_section(section_title: String, skills: Array) -> Control:
	var container = VBoxContainer.new()
	container.add_theme_constant_override("separation", 5)
	container.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	container.add_child(_make_stat_label(section_title, 14, Color(0.6, 0.85, 1, 1)))

	for skill in skills:
		container.add_child(_create_skill_box(skill))

	return container

## 创建技能框
func _create_skill_box(skill: Dictionary) -> Control:
	var outer = VBoxContainer.new()
	outer.add_theme_constant_override("separation", 2)
	outer.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var panel = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _get_skill_panel_style())
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	outer.add_child(panel)

	var skill_container = VBoxContainer.new()
	skill_container.add_theme_constant_override("separation", 3)
	skill_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_child(skill_container)

	var header_row = HBoxContainer.new()
	header_row.add_theme_constant_override("separation", 8)
	skill_container.add_child(header_row)

	var name_label = Label.new()
	name_label.text = skill.get("name", "未知技能")
	name_label.add_theme_font_size_override("font_size", 12)
	name_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.6, 1))
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_row.add_child(name_label)

	var mana_cost = skill.get("mana_cost", 0)
	var cooldown = skill.get("cooldown", 0.0)
	header_row.add_child(_make_stat_label(
		"%dMP  %.1fs" % [mana_cost, cooldown], 10, Color(0.6, 0.7, 0.8, 1)))

	var desc_label = Label.new()
	desc_label.text = skill.get("description", "")
	desc_label.add_theme_font_size_override("font_size", 11)
	desc_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85, 1))
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	skill_container.add_child(desc_label)

	return outer
