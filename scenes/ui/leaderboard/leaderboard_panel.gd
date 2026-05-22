extends PopupPanel
## 排行榜面板：显示公司势力排名和相位师排名
## 注意：本面板 extends PopupPanel，弹出使用 popup_centered()，关闭使用 hide()

signal closed
signal master_selected(master_id: String)  # 相位师选择信号
##
## 势力排行规则：
##   各公司固定控制若干关卡（由 LevelInformation.faction_id 决定）
##   排行依据 = 玩家已通过该公司领地内的关卡数（score）
##   次要指标 = 该公司总领地数（territories_total）
##   声望（reputation）是玩家对该公司的个人好感度，不参与排名

# 每个势力 ID 对应的显示颜色（按公司定义顺序）
const FACTION_COLORS: Dictionary = {
	"iron_wall_corp":    Color(0.7,  0.85, 1.0,  1),  # 钢壁防务 — 钢蓝
	"nova_arms":         Color(1.0,  0.4,  0.2,  1),  # 新星兵工 — 火焰橙
	"aether_dynamics":   Color(0.2,  0.8,  1.0,  1),  # 以太动力 — 青色
	"quantum_logistics": Color(1.0,  0.843, 0.0, 1),  # 量子后勤 — 金色
	"helix_recon":       Color(0.5,  1.0,  0.2,  1),  # 螺旋侦察 — 绿色
	"void_research":     Color(0.7,  0.3,  1.0,  1),  # 虚空相位 — 紫色
	"frontier_union":    Color(1.0,  0.2,  0.8,  1),  # 边境联合 — 品红
}

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
var _close_btn: Button
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

# 各势力当前的动态状态：fid -> {total: 总关卡, cleared: 被NPC攻占数, lost: 丢失给其他势力数}
var _faction_dynamic_state: Dictionary = {}

# 模拟战斗次数计数器（用于生成随机种子）
var _simulation_seed: int = 0

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
	# 获取各个节点
	_tab_bar = get_node_or_null("Margin/VBox/TabBar") as TabBar
	_list_container = get_node_or_null("Margin/VBox/ScrollContainer/LeaderboardList") as VBoxContainer
	_close_btn = get_node_or_null("Margin/VBox/CloseButton") as Button

	if _close_btn:
		_close_btn.pressed.connect(_on_close)

	if _tab_bar:
		_tab_bar.tab_changed.connect(_on_tab_changed)
		_tab_bar.add_tab("公司势力排名")
		_tab_bar.add_tab("相位师排名 (预热)")
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

## 初始化相位师排名数据
## 7个NPC相位师各自为一个公司势力征战，进度基于该公司领地设计
func _initialize_player_data() -> void:
	# 各公司领地数据：start=起始关, end=结束关, name=公司名
	var faction_ranges: Array = [
		{"fid": "iron_wall_corp",    "start": 1,  "end": 20,  "name": "钢壁防务"},
		{"fid": "nova_arms",         "start": 21, "end": 40,  "name": "新星兵工"},
		{"fid": "aether_dynamics",   "start": 41, "end": 60,  "name": "以太动力"},
		{"fid": "quantum_logistics", "start": 61, "end": 80,  "name": "量子后勤"},
		{"fid": "helix_recon",       "start": 81, "end": 90,  "name": "螺旋侦察"},
		{"fid": "void_research",     "start": 91, "end": 100, "name": "虚空相位"},
		{"fid": "frontier_union",    "start": 1,  "end": 10,  "name": "边境联合"},  # 边境联合无固定领地，给它少量虚拟关卡
	]
	
	# NPC相位师预设数据（按排名顺序）：名字、风格、对应公司
	var npc_presets: Array = [
		{"name": "终焉之镰",     "style": "暗影猎手",   "wins": 342, "win_rate": 0.82},
		{"name": "炽焰星痕",     "style": "闪电术师",   "wins": 298, "win_rate": 0.78},
		{"name": "雷霆判官",     "style": "风暴使者",   "wins": 265, "win_rate": 0.75},
		{"name": "寒霜壁垒",     "style": "寒冰指挥官", "wins": 232, "win_rate": 0.71},
		{"name": "量子幽灵",     "style": "间谍",       "wins": 198, "win_rate": 0.68},
		{"name": "虚空低语",     "style": "相位法师",   "wins": 156, "win_rate": 0.65},
		{"name": "边境开拓者",   "style": "先锋",       "wins": 98,  "win_rate": 0.60},
	]
	
	_player_data.clear()
	
	# 为每个NPC分配公司势力和进度
	for i in range(min(npc_presets.size(), faction_ranges.size())):
		var npc = npc_presets[i]
		var faction = faction_ranges[i]
		var f_start = faction["start"]
		var f_end = faction["end"]
		var total = max(0, f_end - f_start + 1)
		
		# NPC进度设计：前几名接近或超过该公司的总领地，后面的逐步减少
		var progress_ratio: float
		match i:
			0: progress_ratio = 1.0   # 第1名：已完全攻克本公司领地
			1: progress_ratio = 0.95  # 第2名：接近全通
			2: progress_ratio = 0.80  # 第3名：8成
			3: progress_ratio = 0.65  # 第4名：6.5成
			4: progress_ratio = 0.50  # 第5名：对半
			5: progress_ratio = 0.35  # 第6名：3.5成
			_: progress_ratio = 0.20  # 第7名：刚起步
		
		var cleared: int = max(1, int(total * progress_ratio))
		cleared = clampi(cleared, 1, total) if total > 0 else 0
		
		var current_level: int = (f_start + cleared - 1) if total > 0 else f_start
		
		_player_data.append({
			"rank": i + 1,
			"name": npc["name"],
			"current_level": current_level,
			"wins": npc["wins"],
			"win_rate": npc["win_rate"],
			"preferred_faction": faction["fid"],
			"faction_name": faction["name"],
		})
	
	# 按"当前关卡"降序排序
	_player_data.sort_custom(func(a, b) -> bool:
		return a.get("current_level", 0) > b.get("current_level", 0)
	)

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
	
	for entry in top_entries:
		var row = EnemyRowScene.instantiate()
		_list_container.add_child(row)
		row.setup(entry)
		row.row_pressed.connect(_on_master_selected)

## 相位师选择处理
func _on_master_selected(master_id: String) -> void:
	_selected_master_id = master_id
	master_selected.emit(master_id)
	# 显示详细信息面板
	_show_master_details_popup(master_id)

## 关闭弹窗
func _on_close() -> void:
	hide()
	closed.emit()

## 外部接口：显示排行榜（自动刷新最新声望）
func show_leaderboard() -> void:
	refresh()
	popup_centered()

## 刷新排行榜数据（可在面板可见时随时调用）
func refresh() -> void:
	simulate_faction_battles()
	_initialize_faction_data()
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
	container.add_child(_make_header_label("胜场", 50, HORIZONTAL_ALIGNMENT_RIGHT))
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
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_color", Color(0.6, 0.85, 1, 1))
	if min_width > 0:
		lbl.custom_minimum_size = Vector2(min_width, 0)
	lbl.horizontal_alignment = align
	return lbl

func _make_separator() -> HSeparator:
	var sep = HSeparator.new()
	sep.add_theme_color_override("color", Color(0.3, 0.4, 0.5, 0.3))
	return sep

## 创建单个小型 Label（用于详情弹窗内嵌数据）
static func _make_stat_label(text: String, font_size: int, color: Color) -> Label:
	var lbl = Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.add_theme_color_override("font_color", color)
	return lbl

# ══════════════════════════════════════════════════════════════
# 模拟战斗系统（纯逻辑，无 UI .new()）
# ══════════════════════════════════════════════════════════════

## 模拟各势力之间的动态战斗（每次战斗后调用）
func simulate_faction_battles() -> void:
	_simulation_seed += 1
	var rng = RandomNumberGenerator.new()
	rng.seed = _simulation_seed * Time.get_ticks_msec()
	
	if _faction_dynamic_state.is_empty():
		_init_faction_dynamic_state()
	
	var factions = _faction_dynamic_state.keys()
	for attacker_fid in factions:
		if rng.randf() > 0.4:
			continue
		
		var attacker_state = _faction_dynamic_state[attacker_fid]
		var total = attacker_state["total"]
		var cleared = attacker_state["cleared"]
		
		var success = rng.randf() < 0.5
		
		if success:
			var targets = []
			for fid in factions:
				if fid != attacker_fid and _faction_dynamic_state[fid]["total"] > 0:
					targets.append(fid)
			if targets.is_empty():
				continue
			
			var target_fid = targets[rng.randi() % targets.size()]
			var target_state = _faction_dynamic_state[target_fid]
			
			if target_state["cleared"] > 0:
				target_state["cleared"] -= 1
				attacker_state["cleared"] += 1
				print("[模拟] %s 攻占了 %s 的1关！（当前: %s=%d, %s=%d）" % [
					attacker_fid, target_fid,
					attacker_fid, attacker_state["cleared"],
					target_fid, target_state["cleared"]
				])
		else:
			if attacker_state["cleared"] > 0:
				attacker_state["cleared"] -= 1
				print("[模拟] %s 进攻失败，丢失1关！（当前: %s=%d）" % [
					attacker_fid, attacker_fid, attacker_state["cleared"]
				])
	
	_update_npc_progress_from_faction_state()

func _init_faction_dynamic_state() -> void:
	var static_data = [
		{"fid": "iron_wall_corp",    "start": 1,  "end": 20},
		{"fid": "nova_arms",         "start": 21, "end": 40},
		{"fid": "aether_dynamics",   "start": 41, "end": 60},
		{"fid": "quantum_logistics", "start": 61, "end": 80},
		{"fid": "helix_recon",       "start": 81, "end": 90},
		{"fid": "void_research",     "start": 91, "end": 100},
		{"fid": "frontier_union",    "start": 1,  "end": 10},
	]
	for sd in static_data:
		var total = max(0, sd["end"] - sd["start"] + 1)
		var rng = RandomNumberGenerator.new()
		rng.randomize()
		var initial_cleared = int(total * rng.randf_range(0.2, 0.5))
		_faction_dynamic_state[sd["fid"]] = {
			"total": total,
			"cleared": initial_cleared,
		}

func _update_npc_progress_from_faction_state() -> void:
	var npc_faction_map = [
		{"npc_idx": 0, "fid": "iron_wall_corp"},
		{"npc_idx": 1, "fid": "nova_arms"},
		{"npc_idx": 2, "fid": "aether_dynamics"},
		{"npc_idx": 3, "fid": "quantum_logistics"},
		{"npc_idx": 4, "fid": "helix_recon"},
		{"npc_idx": 5, "fid": "void_research"},
		{"npc_idx": 6, "fid": "frontier_union"},
	]
	
	for mapping in npc_faction_map:
		var npc_idx = mapping["npc_idx"]
		var fid = mapping["fid"]
		if npc_idx >= _player_data.size():
			continue
		
		var faction_state = _faction_dynamic_state.get(fid, {"total": 0, "cleared": 0})
		var total = faction_state["total"]
		var cleared = faction_state["cleared"]
		
		var start_lv = 0
		match fid:
			"iron_wall_corp": start_lv = 1
			"nova_arms": start_lv = 21
			"aether_dynamics": start_lv = 41
			"quantum_logistics": start_lv = 61
			"helix_recon": start_lv = 81
			"void_research": start_lv = 91
			"frontier_union": start_lv = 1
		
		var new_level = start_lv + cleared - 1
		if total > 0:
			new_level = clampi(new_level, start_lv, start_lv + total - 1)
		else:
			new_level = start_lv
		
		_player_data[npc_idx]["current_level"] = max(1, new_level)
	
	_player_data.sort_custom(func(a, b) -> bool:
		return a.get("current_level", 0) > b.get("current_level", 0)
	)
	for i in range(_player_data.size()):
		_player_data[i]["rank"] = i + 1

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

		# 相位仪属性摘要
		var inst_stats: Dictionary = inst_data.get("base_stats", {})
		if not inst_stats.is_empty():
			var inst_stats_row = HBoxContainer.new()
			inst_stats_row.add_theme_constant_override("separation", 12)
			inst_stats_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			inst_inner.add_child(inst_stats_row)
			if inst_stats.has("max_hp"):
				inst_stats_row.add_child(_make_stat_label("HP:%d" % int(inst_stats["max_hp"]), 10, Color(0.8, 0.4, 0.4, 0.9)))
			if inst_stats.has("energy_capacity"):
				inst_stats_row.add_child(_make_stat_label("能量:%d" % int(inst_stats["energy_capacity"]), 10, Color(0.4, 0.8, 0.8, 0.9)))
			if inst_stats.has("energy_regen"):
				inst_stats_row.add_child(_make_stat_label("回复:%.1f/s" % float(inst_stats["energy_regen"]), 10, Color(0.4, 0.8, 0.4, 0.9)))
			if inst_stats.has("defense"):
				inst_stats_row.add_child(_make_stat_label("防御:%d" % int(inst_stats["defense"]), 10, Color(0.4, 0.4, 0.8, 0.9)))

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
				tags_lbl.add_theme_font_size_override("font_size", 9)
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
