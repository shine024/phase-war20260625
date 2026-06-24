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
# 格式：{ name: 相位师名, faction: 势力ID, platform: 平台卡ID, era: 时代 }
const NPC_PHASE_MASTERS: Array = [
	{"name": "终焉之镰",   "faction": "void_research",     "era": "future",   "platform": "platform_future_heavy"},
	{"name": "炽焰星痕",   "faction": "nova_arms",         "era": "future",   "platform": "platform_future_medium"},
	{"name": "雷霆判官",   "faction": "aether_dynamics",  "era": "cold",     "platform": "platform_cold_medium"},
	{"name": "寒霜壁垒",   "faction": "iron_wall_corp",    "era": "ww2",      "platform": "platform_ww2_heavy"},
	{"name": "量子幽灵",   "faction": "quantum_logistics", "era": "modern",   "platform": "platform_modern_medium"},
	{"name": "虚空低语",   "faction": "helix_recon",       "era": "future",   "platform": "platform_future_light"},
	{"name": "边境开拓者", "faction": "frontier_union",    "era": "ww2",      "platform": "platform_ww2_light"},
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
		# 这样排名看起来像是在为公司"争夺"领地
		var progress_ratio: float
		match i:
			0: progress_ratio = 1.0   # 第1名：已完全攻克本公司领地
			1: progress_ratio = 0.95  # 第2名：接近全通
			2: progress_ratio = 0.80  # 第3名：8成
			3: progress_ratio = 0.65  # 第4名：6.5成
			4: progress_ratio = 0.50  # 第5名：对半
			5: progress_ratio = 0.35  # 第6名：3.5成
			_: progress_ratio = 0.20  # 第7名：刚起步
		
		# 转换为关卡数
		var cleared: int = max(1, int(total * progress_ratio))
		cleared = clampi(cleared, 1, total) if total > 0 else 0
		
		# 玩家是顺序推关的，NPC的"当前关卡" = 起始关 + 已攻克数 - 1
		var current_level: int = (f_start + cleared - 1) if total > 0 else f_start
		
		_player_data.append({
			"rank": i + 1,
			"name": npc["name"],
			"current_level": current_level,      # NPC当前关卡
			"wins": npc["wins"],
			"win_rate": npc["win_rate"],
			"preferred_faction": faction["fid"],  # 所效力的公司
			"faction_name": faction["name"],       # 公司名称（显示用）
		})
	
	# 按"当前关卡"降序排序（关卡数越高排名越前）
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

## 刷新公司势力榜单
func _refresh_faction_list() -> void:
	if _list_container == null:
		return
	
	# 添加标题行
	var title_container = HBoxContainer.new()
	title_container.add_theme_constant_override("separation", 8)
	_list_container.add_child(title_container)
	
	var _h_rank = _make_header_label("排名", 40, HORIZONTAL_ALIGNMENT_LEFT)
	title_container.add_child(_h_rank)
	
	var _h_name = _make_header_label("公司名称", 0, HORIZONTAL_ALIGNMENT_LEFT)
	_h_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_container.add_child(_h_name)
	
	var _h_ter = _make_header_label("已攻克/总关", 100, HORIZONTAL_ALIGNMENT_CENTER)
	title_container.add_child(_h_ter)
	
	var _h_rep = _make_header_label("声望", 70, HORIZONTAL_ALIGNMENT_RIGHT)
	title_container.add_child(_h_rep)
	
	# 分割线
	var separator = HSeparator.new()
	separator.add_theme_color_override("color", Color(0.3, 0.4, 0.5, 0.3))
	_list_container.add_child(separator)
	
	for i in range(_faction_data.size()):
		var row = _create_faction_row(i + 1, _faction_data[i])
		_list_container.add_child(row)

## 创建单个公司行
func _create_faction_row(rank: int, data: Dictionary) -> Control:
	var container = HBoxContainer.new()
	container.add_theme_constant_override("separation", 8)
	container.custom_minimum_size = Vector2(0, 40)
	
	# 排名（前3名高亮）
	var rank_label = Label.new()
	match rank:
		1: rank_label.text = "①"
		2: rank_label.text = "②"
		3: rank_label.text = "③"
		_: rank_label.text = str(rank)
	rank_label.add_theme_font_size_override("font_size", 13)
	rank_label.add_theme_color_override("font_color",
		Color(1.0, 0.843, 0.0, 1) if rank <= 3 else Color(0.65, 0.65, 0.65, 1))
	rank_label.custom_minimum_size = Vector2(40, 0)
	container.add_child(rank_label)
	
	# 公司名称（带势力颜色）
	var fid: String = data.get("faction_id", "")
	var name_label = Label.new()
	name_label.text = data.get("name", "未知")
	name_label.add_theme_font_size_override("font_size", 13)
	name_label.add_theme_color_override("font_color", FACTION_COLORS.get(fid, Color.WHITE))
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.add_child(name_label)
	
	# 已攻克/总关卡数
	var cleared: int = data.get("score", 0)
	var total: int = data.get("territories_total", 0)
	var ter_label = Label.new()
	if total > 0:
		ter_label.text = "%d / %d" % [cleared, total]
		# 全部攻克时用金色，否则按进度着色
		var ratio: float = float(cleared) / float(total)
		ter_label.add_theme_color_override("font_color",
			Color(1.0, 0.843, 0.0, 1) if cleared == total else
			Color(0.4 + ratio * 0.5, 0.7 + ratio * 0.25, 0.5, 1))
	else:
		ter_label.text = "— / —"
		ter_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5, 1))
	ter_label.add_theme_font_size_override("font_size", 13)
	ter_label.custom_minimum_size = Vector2(100, 0)
	ter_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	container.add_child(ter_label)
	
	# 玩家对该公司的声望（仅参考，不影响排名）
	var rep_label = Label.new()
	rep_label.text = str(data.get("reputation", 0))
	rep_label.add_theme_font_size_override("font_size", 12)
	rep_label.add_theme_color_override("font_color", Color(0.65, 0.75, 0.9, 0.85))
	rep_label.custom_minimum_size = Vector2(70, 0)
	rep_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	container.add_child(rep_label)
	
	return container

## 辅助：生成标题列 Label
func _make_header_label(text: String, min_width: int, align: int) -> Label:
	var lbl = Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_color", Color(0.6, 0.85, 1, 1))
	if min_width > 0:
		lbl.custom_minimum_size = Vector2(min_width, 0)
	lbl.horizontal_alignment = align
	return lbl

## 刷新相位师排名
func _refresh_player_list() -> void:
	if _list_container == null:
		return
	
	# 标题行
	var title_container = HBoxContainer.new()
	title_container.add_theme_constant_override("separation", 8)
	_list_container.add_child(title_container)
	
	title_container.add_child(_make_header_label("排名", 35, HORIZONTAL_ALIGNMENT_CENTER))
	var faction_label = _make_header_label("相位师", 0, HORIZONTAL_ALIGNMENT_LEFT)
	faction_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_container.add_child(faction_label)
	title_container.add_child(_make_header_label("当前关", 55, HORIZONTAL_ALIGNMENT_CENTER))
	title_container.add_child(_make_header_label("势力", 90, HORIZONTAL_ALIGNMENT_CENTER))
	title_container.add_child(_make_header_label("胜场", 50, HORIZONTAL_ALIGNMENT_RIGHT))
	
	# 分割线
	var separator = HSeparator.new()
	separator.add_theme_color_override("color", Color(0.3, 0.4, 0.5, 0.3))
	_list_container.add_child(separator)
	
	for player_info in _player_data:
		var row = _create_player_row(player_info)
		_list_container.add_child(row)

## 创建单个玩家行
func _create_player_row(data: Dictionary) -> Control:
	var container = HBoxContainer.new()
	container.add_theme_constant_override("separation", 8)
	container.custom_minimum_size = Vector2(0, 40)
	
	# 排名图标
	var rank = data.get("rank", 0)
	var rank_label = Label.new()
	match rank:
		1: rank_label.text = "①"
		2: rank_label.text = "②"
		3: rank_label.text = "③"
		_: rank_label.text = str(rank)
	rank_label.add_theme_font_size_override("font_size", 13)
	rank_label.add_theme_color_override("font_color",
		Color(1.0, 0.843, 0.0, 1) if rank <= 3 else Color(0.65, 0.65, 0.65, 1))
	rank_label.custom_minimum_size = Vector2(35, 0)
	rank_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	container.add_child(rank_label)
	
	# 相位师名称（用势力颜色着色）
	var fid: String = data.get("preferred_faction", "")
	var name_label = Label.new()
	name_label.text = data.get("name", "未知玩家")
	name_label.add_theme_font_size_override("font_size", 13)
	name_label.add_theme_color_override("font_color", FACTION_COLORS.get(fid, Color.WHITE))
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.add_child(name_label)
	
	# 当前关卡
	var cur_lv: int = data.get("current_level", 0)
	var lv_label = Label.new()
	lv_label.text = "Lv.%d" % cur_lv
	lv_label.add_theme_font_size_override("font_size", 12)
	# 按关卡区间着色
	var era_color: Color
	if cur_lv >= 81:
		era_color = Color(0.85, 0.5, 1.0, 1)    # 近未来 - 紫色
	elif cur_lv >= 61:
		era_color = Color(0.0, 0.85, 0.95, 1)    # 现代 - 青色
	elif cur_lv >= 41:
		era_color = Color(0.45, 0.7, 1.0, 1)     # 冷战 - 蓝色
	elif cur_lv >= 21:
		era_color = Color(0.4, 0.95, 0.35, 1)     # 二战 - 绿色
	else:
		era_color = Color(0.95, 0.78, 0.45, 1)    # 一战 - 金色
	lv_label.add_theme_color_override("font_color", era_color)
	lv_label.custom_minimum_size = Vector2(55, 0)
	lv_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	container.add_child(lv_label)
	
	# 所属势力
	var faction_name: String = data.get("faction_name", fid)
	var fac_label = Label.new()
	fac_label.text = faction_name
	fac_label.add_theme_font_size_override("font_size", 11)
	fac_label.add_theme_color_override("font_color", FACTION_COLORS.get(fid, Color.GRAY).lightened(0.3))
	fac_label.custom_minimum_size = Vector2(90, 0)
	fac_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	container.add_child(fac_label)
	
	# 胜场
	var wins = data.get("wins", 0)
	var wins_label = Label.new()
	wins_label.text = str(wins)
	wins_label.add_theme_font_size_override("font_size", 12)
	wins_label.add_theme_color_override("font_color", Color(0.5, 1.0, 0.4, 1))
	wins_label.custom_minimum_size = Vector2(50, 0)
	wins_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	container.add_child(wins_label)
	
	return container

## 关闭弹窗
func _on_close() -> void:
	hide()
	closed.emit()

## 外部接口：显示排行榜（自动刷新最新声望）
func show_leaderboard() -> void:
	refresh()
	popup_centered()

## 模拟各势力之间的动态战斗（每次战斗后调用）
## 规则：各势力的NPC相位师会相互进攻，有成功有失败
func simulate_faction_battles() -> void:
	_simulation_seed += 1
	var rng = RandomNumberGenerator.new()
	rng.seed = _simulation_seed * Time.get_ticks_msec()
	
	# 初始化各势力状态（如果还没有）
	if _faction_dynamic_state.is_empty():
		_init_faction_dynamic_state()
	
	# 每个势力都有概率发起进攻
	var factions = _faction_dynamic_state.keys()
	for attacker_fid in factions:
		# 40%概率发起进攻
		if rng.randf() > 0.4:
			continue
		
		var attacker_state = _faction_dynamic_state[attacker_fid]
		var total = attacker_state["total"]
		var cleared = attacker_state["cleared"]
		
		# 进攻成功概率：50%
		var success = rng.randf() < 0.5
		
		if success:
			# 进攻成功：随机选择一个其他势力，夺取1关
			var targets = []
			for fid in factions:
				if fid != attacker_fid and _faction_dynamic_state[fid]["total"] > 0:
					targets.append(fid)
			if targets.is_empty():
				continue
			
			var target_fid = targets[rng.randi() % targets.size()]
			var target_state = _faction_dynamic_state[target_fid]
			
			# 从目标势力夺取1关
			if target_state["cleared"] > 0:
				target_state["cleared"] -= 1
				attacker_state["cleared"] += 1
			else:
				# 目标已经被攻占完了，不再减少
				pass
		else:
			# 进攻失败：本方可能丢失1关（如果有被攻占的关卡）
			if attacker_state["cleared"] > 0:
				attacker_state["cleared"] -= 1
	
	# 根据动态状态更新NPC相位师的进度
	_update_npc_progress_from_faction_state()

func _init_faction_dynamic_state() -> void:
	"""初始化各势力的动态状态"""
	# 静态领地数据
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
		# 初始时各势力都有部分关卡被NPC攻占（模拟已有战斗发生）
		# 势力越强，初始被攻占越少
		var rng = RandomNumberGenerator.new()
		rng.randomize()
		var initial_cleared = int(total * rng.randf_range(0.2, 0.5))  # 20%-50%被攻占
		_faction_dynamic_state[sd["fid"]] = {
			"total": total,
			"cleared": initial_cleared,  # 被NPC攻占的关卡数
		}

func _update_npc_progress_from_faction_state() -> void:
	"""根据势力动态状态更新NPC相位师的进度"""
	# NPC相位师与势力的对应关系（排名顺序）
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
		
		# NPC的当前关卡 = 起始关 + 已攻占的关卡数
		var start关 = 0
		match fid:
			"iron_wall_corp": start关 = 1
			"nova_arms": start关 = 21
			"aether_dynamics": start关 = 41
			"quantum_logistics": start关 = 61
			"helix_recon": start关 = 81
			"void_research": start关 = 91
			"frontier_union": start关 = 1
		
		var new_level = start关 + cleared - 1
		if total > 0:
			new_level = clampi(new_level, start关, start关 + total - 1)
		else:
			new_level = start关
		
		_player_data[npc_idx]["current_level"] = max(1, new_level)
	
	# 重新按关卡数排序
	_player_data.sort_custom(func(a, b) -> bool:
		return a.get("current_level", 0) > b.get("current_level", 0)
	)
	# 更新排名
	for i in range(_player_data.size()):
		_player_data[i]["rank"] = i + 1

## 刷新排行榜数据（可在面板可见时随时调用）
func refresh() -> void:
	# 先模拟各势力的动态战斗（每次打开排行榜都有新变化）
	simulate_faction_battles()
	_initialize_faction_data()
	_refresh_list()

## ==================== 敌方相位师排行榜功能 ====================

## 刷新敌方相位师排行榜
func _refresh_enemy_master_list() -> void:
	if _list_container == null:
		return

	# 添加标题行和子标签
	var title_container = HBoxContainer.new()
	title_container.add_theme_constant_override("separation", 8)
	_list_container.add_child(title_container)

	var _h_rank = _make_header_label("排名", 35, HORIZONTAL_ALIGNMENT_CENTER)
	title_container.add_child(_h_rank)

	var _h_name = _make_header_label("相位师", 0, HORIZONTAL_ALIGNMENT_LEFT)
	_h_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_container.add_child(_h_name)

	var _h_level = _make_header_label("等级", 50, HORIZONTAL_ALIGNMENT_CENTER)
	title_container.add_child(_h_level)

	var _h_faction = _make_header_label("势力", 70, HORIZONTAL_ALIGNMENT_CENTER)
	title_container.add_child(_h_faction)

	var _h_difficulty = _make_header_label("难度", 60, HORIZONTAL_ALIGNMENT_CENTER)
	title_container.add_child(_h_difficulty)

	var _h_winrate = _make_header_label("胜率", 55, HORIZONTAL_ALIGNMENT_RIGHT)
	title_container.add_child(_h_winrate)

	# 分割线
	var separator = HSeparator.new()
	separator.add_theme_color_override("color", Color(0.3, 0.4, 0.5, 0.3))
	_list_container.add_child(separator)

	# 获取前15名敌方相位师
	var top_entries = _enemy_leaderboard.get_top_entries(15)

	for entry in top_entries:
		var row = _create_enemy_master_row(entry)
		_list_container.add_child(row)

## 创建敌方相位师行
func _create_enemy_master_row(entry: LeaderboardEntry) -> Control:
	var container = HBoxContainer.new()
	container.add_theme_constant_override("separation", 8)
	container.custom_minimum_size = Vector2(0, 40)

	# 添加点击事件（子 Label 必须放在内部 HBox 里：Button 不会横向排列多个子控件，会全部叠在左上角）
	var gui_button = Button.new()
	gui_button.custom_minimum_size = Vector2(0, 40)
	gui_button.flat = true
	gui_button.mouse_filter = Control.MOUSE_FILTER_STOP
	gui_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gui_button.pressed.connect(_on_master_selected.bind(entry.master_id))
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	gui_button.add_child(row)

	# 排名图标
	var rank_label = Label.new()
	match entry.rank:
		1: rank_label.text = "①"
		2: rank_label.text = "②"
		3: rank_label.text = "③"
		_: rank_label.text = str(entry.rank)
	rank_label.add_theme_font_size_override("font_size", 13)
	rank_label.add_theme_color_override("font_color",
		Color(1.0, 0.843, 0.0, 1) if entry.rank <= 3 else Color(0.65, 0.65, 0.65, 1))
	rank_label.custom_minimum_size = Vector2(35, 0)
	rank_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(rank_label)

	# 相位师名称（带势力颜色）
	var faction_info = EnemyPhaseLeaderboard.get_faction_display_info(entry.faction)
	var name_label = Label.new()
	name_label.text = entry.name
	name_label.add_theme_font_size_override("font_size", 13)
	name_label.add_theme_color_override("font_color", faction_info.color)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	name_label.clip_text = true
	row.add_child(name_label)

	# 等级
	var level_label = Label.new()
	level_label.text = "Lv.%d" % entry.level
	level_label.add_theme_font_size_override("font_size", 12)
	# 按等级区间着色
	var era_color: Color
	if entry.level >= 25:
		era_color = Color(0.85, 0.5, 1.0, 1)    # 大师级 - 紫色
	elif entry.level >= 20:
		era_color = Color(0.0, 0.85, 0.95, 1)    # 高级 - 青色
	elif entry.level >= 15:
		era_color = Color(0.45, 0.7, 1.0, 1)     # 中高级 - 蓝色
	elif entry.level >= 10:
		era_color = Color(0.4, 0.95, 0.35, 1)     # 中级 - 绿色
	else:
		era_color = Color(0.95, 0.78, 0.45, 1)    # 初级 - 金色
	level_label.add_theme_color_override("font_color", era_color)
	level_label.custom_minimum_size = Vector2(50, 0)
	level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(level_label)

	# 势力
	var faction_label = Label.new()
	faction_label.text = faction_info.name
	faction_label.add_theme_font_size_override("font_size", 11)
	faction_label.add_theme_color_override("font_color", faction_info.color.lightened(0.3))
	faction_label.custom_minimum_size = Vector2(70, 0)
	faction_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	faction_label.clip_text = true
	row.add_child(faction_label)

	# 难度星级
	var difficulty_info = EnemyPhaseLeaderboard.get_difficulty_display_info(entry.difficulty)
	var diff_label = Label.new()
	var stars_text = ""
	for i in range(difficulty_info.stars):
		stars_text += "★"
	diff_label.text = stars_text
	diff_label.add_theme_font_size_override("font_size", 10)
	diff_label.add_theme_color_override("font_color", difficulty_info.color)
	diff_label.custom_minimum_size = Vector2(60, 0)
	diff_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(diff_label)

	# 胜率
	var winrate_label = Label.new()
	winrate_label.text = EnemyPhaseLeaderboard.format_win_rate(entry.win_rate)
	winrate_label.add_theme_font_size_override("font_size", 12)
	winrate_label.add_theme_color_override("font_color", Color(0.5, 1.0, 0.4, 1))
	winrate_label.custom_minimum_size = Vector2(55, 0)
	winrate_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(winrate_label)

	container.add_child(gui_button)
	return container

## 相位师选择处理
func _on_master_selected(master_id: String) -> void:
	_selected_master_id = master_id
	master_selected.emit(master_id)

	# 显示详细信息面板
	_show_master_details_popup(master_id)

## 显示相位师详细信息弹窗
func _show_master_details_popup(master_id: String) -> void:
	var details = _enemy_leaderboard.get_master_details(master_id)
	if details.is_empty():
		return

	var popup = PopupPanel.new()
	popup.title = "相位师详情"
	popup.min_size = Vector2i(420, 320)
	popup.exclusive = true

	# PopupPanel 的第一个子节点需铺满内容区；用边距 + 滚动避免长情报被裁切或叠在一起
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
	var header = _create_master_header(basic_info)
	vbox.add_child(header)

	var sep1 = HSeparator.new()
	vbox.add_child(sep1)

	var stats_container = _create_stats_display(details.get("stats", {}))
	vbox.add_child(stats_container)

	var sep2 = HSeparator.new()
	vbox.add_child(sep2)

	## 装备情报：相位仪 + 战斗载具
	var equipment_section = _create_equipment_section(details.get("equipment", {}))
	if equipment_section != null:
		vbox.add_child(equipment_section)
		var sep_equip = HSeparator.new()
		vbox.add_child(sep_equip)

	var active_skills = details.get("active_spells", [])
	if not active_skills.is_empty():
		var active_section = _create_skills_section("主动技能", active_skills)
		vbox.add_child(active_section)

	var passive_skills = details.get("passive_spells", [])
	if not passive_skills.is_empty():
		var passive_section = _create_skills_section("被动技能", passive_skills)
		vbox.add_child(passive_section)

	var close_btn = Button.new()
	close_btn.text = "关闭"
	close_btn.custom_minimum_size = Vector2(0, 36)
	close_btn.pressed.connect(popup.hide)
	vbox.add_child(close_btn)

	add_child(popup)
	popup.popup_centered(Vector2i(560, 580))
	# 必须在显示之后再连，否则初始 visible=false 时会误删弹窗
	popup.visibility_changed.connect(func():
		if is_instance_valid(popup) and not popup.visible:
			popup.call_deferred("queue_free")
	)

## 创建相位师头部信息
func _create_master_header(basic_info: Dictionary) -> Control:
	var container = VBoxContainer.new()
	container.add_theme_constant_override("separation", 5)

	# 名称和称号
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

	# 详细信息行
	var info_row = HBoxContainer.new()
	info_row.add_theme_constant_override("separation", 8)
	container.add_child(info_row)

	# 等级
	var level_label = Label.new()
	level_label.text = "Lv.%d  " % basic_info.get("level", 1)
	level_label.add_theme_font_size_override("font_size", 12)
	info_row.add_child(level_label)

	# 势力
	var faction = basic_info.get("faction", "")
	var faction_info = EnemyPhaseLeaderboard.get_faction_display_info(faction)
	var faction_label = Label.new()
	faction_label.text = "%s%s  " % [faction_info.icon, faction_info.name]
	faction_label.add_theme_font_size_override("font_size", 12)
	faction_label.add_theme_color_override("font_color", faction_info.color)
	info_row.add_child(faction_label)

	# 难度
	var difficulty = basic_info.get("difficulty", "")
	var difficulty_info = EnemyPhaseLeaderboard.get_difficulty_display_info(difficulty)
	var diff_label = Label.new()
	var stars_text = ""
	for i in range(difficulty_info.stars):
		stars_text += "★"
	diff_label.text = "%s %s" % [difficulty_info.name, stars_text]
	diff_label.add_theme_font_size_override("font_size", 12)
	diff_label.add_theme_color_override("font_color", difficulty_info.color)
	info_row.add_child(diff_label)

	return container

## 创建属性显示
func _create_stats_display(stats: Dictionary) -> Control:
	var container = VBoxContainer.new()
	container.add_theme_constant_override("separation", 3)
	container.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var title = Label.new()
	title.text = "战斗属性"
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", Color(0.6, 0.85, 1, 1))
	container.add_child(title)

	var stats_row = HBoxContainer.new()
	stats_row.add_theme_constant_override("separation", 15)
	stats_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.add_child(stats_row)

	# HP
	var hp_label = Label.new()
	hp_label.text = "HP: %d" % stats.get("max_hp", 0)
	hp_label.add_theme_font_size_override("font_size", 11)
	hp_label.add_theme_color_override("font_color", Color(0.8, 0.4, 0.4, 1))
	stats_row.add_child(hp_label)

	# 攻击力
	var atk_label = Label.new()
	atk_label.text = "攻击: %d" % stats.get("attack_power", 0)
	atk_label.add_theme_font_size_override("font_size", 11)
	atk_label.add_theme_color_override("font_color", Color(0.4, 0.8, 0.4, 1))
	stats_row.add_child(atk_label)

	# 防御
	var def_label = Label.new()
	def_label.text = "防御: %d" % stats.get("defense", 0)
	def_label.add_theme_font_size_override("font_size", 11)
	def_label.add_theme_color_override("font_color", Color(0.4, 0.4, 0.8, 1))
	stats_row.add_child(def_label)

	# 能量回复
	var energy_label = Label.new()
	energy_label.text = "能量: %.1f/s" % stats.get("energy_regen", 0)
	energy_label.add_theme_font_size_override("font_size", 11)
	energy_label.add_theme_color_override("font_color", Color(0.4, 0.8, 0.8, 1))
	stats_row.add_child(energy_label)

	return container

## 创建装备情报区域（相位仪 + 战斗平台）
func _create_equipment_section(equipment: Dictionary) -> Control:
	if equipment.is_empty():
		return null

	var container = VBoxContainer.new()
	container.add_theme_constant_override("separation", 8)
	container.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	## — 相位仪 —
	var instrument_id: String = equipment.get("phase_instrument", "")
	if not instrument_id.is_empty():
		var inst_data: Dictionary = EnemyPhaseEquipment.get_phase_instrument(instrument_id)
		var inst_name: String = inst_data.get("name", instrument_id)
		var inst_level: int = int(equipment.get("level", 1))
		var inst_faction: String = equipment.get("instrument_faction", inst_data.get("faction", ""))
		var faction_info = EnemyPhaseLeaderboard.get_faction_display_info(inst_faction) if not inst_faction.is_empty() else null
		var inst_color: Color = faction_info.color if faction_info else Color(0.6, 0.85, 1.0, 1)

		var inst_box = PanelContainer.new()
		inst_box.add_theme_stylebox_override("panel", _create_skill_panel_style())
		inst_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var inst_inner = VBoxContainer.new()
		inst_inner.add_theme_constant_override("separation", 3)
		inst_inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		inst_box.add_child(inst_inner)

		var inst_header = HBoxContainer.new()
		inst_header.add_theme_constant_override("separation", 8)
		inst_inner.add_child(inst_header)

		var inst_title = Label.new()
		inst_title.text = "相位仪"
		inst_title.add_theme_font_size_override("font_size", 13)
		inst_title.add_theme_color_override("font_color", Color(0.6, 0.85, 1.0, 1))
		inst_header.add_child(inst_title)

		var inst_level_lbl = Label.new()
		inst_level_lbl.text = "Lv.%d" % inst_level
		inst_level_lbl.add_theme_font_size_override("font_size", 11)
		inst_level_lbl.add_theme_color_override("font_color", inst_color)
		inst_level_lbl.size_flags_horizontal = Control.SIZE_SHRINK_END
		inst_header.add_child(inst_level_lbl)

		var inst_name_lbl = Label.new()
		inst_name_lbl.text = inst_name
		inst_name_lbl.add_theme_font_size_override("font_size", 14)
		inst_name_lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.6, 1))
		inst_name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		inst_inner.add_child(inst_name_lbl)

		## 相位仪属性摘要
		var inst_stats: Dictionary = inst_data.get("base_stats", {})
		if not inst_stats.is_empty():
			var inst_stats_row = HBoxContainer.new()
			inst_stats_row.add_theme_constant_override("separation", 12)
			inst_stats_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			inst_inner.add_child(inst_stats_row)
			if inst_stats.has("max_hp"):
				var hp_lbl = Label.new()
				hp_lbl.text = "HP:%d" % int(inst_stats["max_hp"])
				hp_lbl.add_theme_font_size_override("font_size", 10)
				hp_lbl.add_theme_color_override("font_color", Color(0.8, 0.4, 0.4, 0.9))
				inst_stats_row.add_child(hp_lbl)
			if inst_stats.has("energy_capacity"):
				var ec_lbl = Label.new()
				ec_lbl.text = "能量:%d" % int(inst_stats["energy_capacity"])
				ec_lbl.add_theme_font_size_override("font_size", 10)
				ec_lbl.add_theme_color_override("font_color", Color(0.4, 0.8, 0.8, 0.9))
				inst_stats_row.add_child(ec_lbl)
			if inst_stats.has("energy_regen"):
				var er_lbl = Label.new()
				er_lbl.text = "回复:%.1f/s" % float(inst_stats["energy_regen"])
				er_lbl.add_theme_font_size_override("font_size", 10)
				er_lbl.add_theme_color_override("font_color", Color(0.4, 0.8, 0.4, 0.9))
				inst_stats_row.add_child(er_lbl)
			if inst_stats.has("defense"):
				var def_lbl = Label.new()
				def_lbl.text = "防御:%d" % int(inst_stats["defense"])
				def_lbl.add_theme_font_size_override("font_size", 10)
				def_lbl.add_theme_color_override("font_color", Color(0.4, 0.4, 0.8, 0.9))
				inst_stats_row.add_child(def_lbl)

		container.add_child(inst_box)

	## — 战斗载具 —
	var platforms: Array = equipment.get("platforms", [])
	if not platforms.is_empty():
		var excluded_types: Array[String] = ["striker", "sniper", "stealth", "mage"]
		var plat_title = Label.new()
		plat_title.text = "战斗载具"
		plat_title.add_theme_font_size_override("font_size", 13)
		plat_title.add_theme_color_override("font_color", Color(0.6, 0.85, 1.0, 1))
		container.add_child(plat_title)

		for pid in platforms:
			var pdata: Dictionary = EnemyPhaseEquipment.get_war_platform(pid)
			var pname: String = pdata.get("name", pid)
			var ptype: String = pdata.get("type", "")
			# 与相位场/奖励口径一致：剔除纯步兵相关平台
			if excluded_types.has(ptype):
				continue
			var pstats: Dictionary = pdata.get("stats", {})
			var pspecial: Array = pdata.get("special", [])

			var plat_box = PanelContainer.new()
			plat_box.add_theme_stylebox_override("panel", _create_skill_panel_style())
			plat_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var plat_inner = VBoxContainer.new()
			plat_inner.add_theme_constant_override("separation", 2)
			plat_inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			plat_box.add_child(plat_inner)

			## 平台名 + 类型
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

			## 平台属性
			if not pstats.is_empty():
				var plat_stats_row = HBoxContainer.new()
				plat_stats_row.add_theme_constant_override("separation", 12)
				plat_stats_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				plat_inner.add_child(plat_stats_row)
				if pstats.has("hp"):
					var hp_lbl = Label.new()
					hp_lbl.text = "HP:%d" % int(pstats["hp"])
					hp_lbl.add_theme_font_size_override("font_size", 10)
					hp_lbl.add_theme_color_override("font_color", Color(0.8, 0.4, 0.4, 0.9))
					plat_stats_row.add_child(hp_lbl)
				if pstats.has("attack"):
					var atk_lbl = Label.new()
					atk_lbl.text = "攻击:%d" % int(pstats["attack"])
					atk_lbl.add_theme_font_size_override("font_size", 10)
					atk_lbl.add_theme_color_override("font_color", Color(0.4, 0.8, 0.4, 0.9))
					plat_stats_row.add_child(atk_lbl)
				if pstats.has("defense"):
					var def_lbl = Label.new()
					def_lbl.text = "防御:%d" % int(pstats["defense"])
					def_lbl.add_theme_font_size_override("font_size", 10)
					def_lbl.add_theme_color_override("font_color", Color(0.4, 0.4, 0.8, 0.9))
					plat_stats_row.add_child(def_lbl)
				if pstats.has("move_speed"):
					var spd_lbl = Label.new()
					spd_lbl.text = "速度:%d" % int(pstats["move_speed"])
					spd_lbl.add_theme_font_size_override("font_size", 10)
					spd_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.4, 0.9))
					plat_stats_row.add_child(spd_lbl)

			## 特殊标签
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

	var title = Label.new()
	title.text = section_title
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", Color(0.6, 0.85, 1, 1))
	container.add_child(title)

	for skill in skills:
		var skill_box = _create_skill_box(skill)
		container.add_child(skill_box)

	return container

## 创建技能框
func _create_skill_box(skill: Dictionary) -> Control:
	var outer = VBoxContainer.new()
	outer.add_theme_constant_override("separation", 2)
	outer.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# Panel 不会排列子控件；用 PanelContainer 才能把标题/描述正确铺在背景内
	var panel = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _create_skill_panel_style())
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

	var cost_label = Label.new()
	var mana_cost = skill.get("mana_cost", 0)
	var cooldown = skill.get("cooldown", 0.0)
	cost_label.text = "%dMP  %.1fs" % [mana_cost, cooldown]
	cost_label.add_theme_font_size_override("font_size", 10)
	cost_label.add_theme_color_override("font_color", Color(0.6, 0.7, 0.8, 1))
	header_row.add_child(cost_label)

	var desc_label = Label.new()
	desc_label.text = skill.get("description", "")
	desc_label.add_theme_font_size_override("font_size", 11)
	desc_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85, 1))
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	skill_container.add_child(desc_label)

	return outer

## 创建技能面板样式
func _create_skill_panel_style() -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.15, 0.8)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.3, 0.3, 0.4, 1)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	return style
