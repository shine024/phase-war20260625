extends RefCounted
class_name LeaderboardPresenter
## 排行榜中间层 (Presenter)
##
## 协调 LeaderboardData 与 LeaderboardPanel 之间的通信。
## 负责敌对相位师排行榜数据的获取和详情弹窗的构建。
## UI 构建逻辑保留在 Presenter 中，Panel 仅负责挂载和容器管理。

const LeaderboardData = preload("res://scenes/ui/leaderboard/leaderboard_data.gd")
const EnemyPhaseLeaderboard = preload("res://data/enemy_phase_leaderboard.gd")
const LeaderboardEntry = preload("res://data/leaderboard_entry.gd")
const EnemyPhaseEquipment = preload("res://data/enemy_phase_equipment.gd")
const CompanyDefs = preload("res://data/company_definitions.gd")  # 统一阵营色来源

# 行模板场景
const FactionRowScene = preload("res://scenes/ui/leaderboard/faction_row.tscn")
const PlayerRowScene = preload("res://scenes/ui/leaderboard/player_row.tscn")
const EnemyRowScene = preload("res://scenes/ui/leaderboard/enemy_row.tscn")

## 共享样式资源（延迟加载，避免 preload 在 import 系统未就绪时失败）
static func _get_skill_panel_style() -> StyleBox:
	if not ResourceLoader.exists("res://scenes/ui/leaderboard/skill_panel_style.tres"):
		return StyleBoxFlat.new()
	return load("res://scenes/ui/leaderboard/skill_panel_style.tres") as StyleBox

# 势力色统一来源：CompanyDefinitions.get_faction_color()（Palette B 高饱和）
# 各 row 脚本（faction_row.gd/player_row.gd）直接调用该函数，不再经 Presenter 中转。

var _data: LeaderboardData
var _enemy_leaderboard: EnemyPhaseLeaderboard
var _panel: Node  # LeaderboardPanel 引用

func _init() -> void:
	_data = LeaderboardData.new()
	_enemy_leaderboard = EnemyPhaseLeaderboard.new()

## 设置面板引用（在面板 ready 后调用）
func setup(panel: Node) -> void:
	_panel = panel

## 获取数据层引用（供外部查询，如 GameManager 获取相位师配置）
func get_data() -> LeaderboardData:
	return _data

## 刷新所有排行榜数据
func refresh() -> void:
	_data.refresh()

## 获取公司势力排名
func get_faction_data() -> Array:
	return _data.get_faction_leaderboard()

## 获取NPC相位师排名
func get_npc_data() -> Array:
	return _data.get_npc_leaderboard()

## 获取敌方相位师排行榜前N名
func get_enemy_top_entries(count: int = 15) -> Array:
	return _enemy_leaderboard.get_top_entries(count)

## 获取敌方相位师详细信息
func get_enemy_master_details(master_id: String) -> Dictionary:
	return _enemy_leaderboard.get_master_details(master_id)

## 获取势力显示颜色（委托给统一数据源 CompanyDefinitions）
func get_faction_color(fid: String) -> Color:
	return CompanyDefs.get_faction_color(fid)

# ── 公司势力行构建 ──────────────────────────────────────────

## 构建公司势力表头行
func build_faction_header() -> Control:
	var container = HBoxContainer.new()
	container.add_theme_constant_override("separation", 8)

	container.add_child(_make_header_label("排名", 40, HORIZONTAL_ALIGNMENT_LEFT))

	var h_name = _make_header_label("公司名称", 0, HORIZONTAL_ALIGNMENT_LEFT)
	h_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.add_child(h_name)

	container.add_child(_make_header_label("已攻克/总关", 100, HORIZONTAL_ALIGNMENT_CENTER))
	container.add_child(_make_header_label("声望", 70, HORIZONTAL_ALIGNMENT_RIGHT))

	return container

## 构建单个公司势力行（使用 faction_row.tscn 模板）
func build_faction_row(rank: int, data: Dictionary) -> Control:
	var row = FactionRowScene.instantiate()
	row.setup(rank, data)
	return row

# ── NPC相位师行构建 ─────────────────────────────────────────

## 构建 NPC 相位师表头行
func build_player_header() -> Control:
	var container = HBoxContainer.new()
	container.add_theme_constant_override("separation", 8)

	container.add_child(_make_header_label("排名", 35, HORIZONTAL_ALIGNMENT_CENTER))

	var faction_label = _make_header_label("相位师", 0, HORIZONTAL_ALIGNMENT_LEFT)
	faction_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.add_child(faction_label)

	container.add_child(_make_header_label("当前关", 55, HORIZONTAL_ALIGNMENT_CENTER))
	container.add_child(_make_header_label("势力", 90, HORIZONTAL_ALIGNMENT_CENTER))
	container.add_child(_make_header_label("胜场", 50, HORIZONTAL_ALIGNMENT_RIGHT))

	return container

## 构建单个NPC相位师行（使用 player_row.tscn 模板）
func build_player_row(data: Dictionary) -> Control:
	var row = PlayerRowScene.instantiate()
	row.setup(data)
	return row

# ── 敌方相位师行构建 ────────────────────────────────────────

## 构建敌方相位师表头行
func build_enemy_header() -> Control:
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

## 构建单个敌方相位师行（使用 enemy_row.tscn 模板）
func build_enemy_row(entry: LeaderboardEntry, callback: Callable) -> Control:
	var row = EnemyRowScene.instantiate()
	row.setup(entry)
	row.row_pressed.connect(callback)
	return row

# ── 相位师详情弹窗构建 ──────────────────────────────────────

## 构建相位师详细信息弹窗（返回 PopupPanel，由调用者 add_child + popup）
func build_master_details_popup(master_id: String) -> PopupPanel:
	var details: Dictionary = get_enemy_master_details(master_id)
	if details.is_empty():
		return null

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

	return popup

# ── 内部辅助函数 ────────────────────────────────────────────

func _make_header_label(text: String, min_width: int, align: int) -> Label:
	var lbl = Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_color", Color(0.6, 0.85, 1, 1))
	if min_width > 0:
		lbl.custom_minimum_size = Vector2(min_width, 0)
	lbl.horizontal_alignment = align
	return lbl

static func _rank_text(rank: int) -> String:
	match rank:
		1: return "1"
		2: return "2"
		3: return "3"
		_: return str(rank)

static func _level_color(cur_lv: int) -> Color:
	if cur_lv >= 81:
		return Color(0.85, 0.5, 1.0, 1)
	elif cur_lv >= 61:
		return Color(0.0, 0.85, 0.95, 1)
	elif cur_lv >= 41:
		return Color(0.45, 0.7, 1.0, 1)
	elif cur_lv >= 21:
		return Color(0.4, 0.95, 0.35, 1)
	else:
		return Color(0.95, 0.78, 0.45, 1)

static func _enemy_level_color(level: int) -> Color:
	if level >= 25:
		return Color(0.85, 0.5, 1.0, 1)
	elif level >= 20:
		return Color(0.0, 0.85, 0.95, 1)
	elif level >= 15:
		return Color(0.45, 0.7, 1.0, 1)
	elif level >= 10:
		return Color(0.4, 0.95, 0.35, 1)
	else:
		return Color(0.95, 0.78, 0.45, 1)

## 创建单个小型 Label（用于详情弹窗内嵌数据）
static func _make_stat_label(text: String, font_size: int, color: Color) -> Label:
	var lbl = Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.add_theme_color_override("font_color", color)
	return lbl

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
		stars_text += "*"
	info_row.add_child(_make_stat_label(
		"%s %s" % [difficulty_info.name, stars_text], 12, difficulty_info.color))

	return container

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

func _create_equipment_section(equipment: Dictionary) -> Control:
	if equipment.is_empty():
		return null

	var container = VBoxContainer.new()
	container.add_theme_constant_override("separation", 8)
	container.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# 相位仪
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

	# 战斗载具
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
				if pstats.has("move_speed"):
					plat_stats_row.add_child(_make_stat_label("速度:%d" % int(pstats["move_speed"]), 10, Color(0.8, 0.6, 0.3, 0.9)))

			if not pspecial.is_empty():
				var tags_lbl = Label.new()
				# 翻译 raw 英文 effect tag 为中文（修复：原直接 join 显示英文）
				var translated: Array = []
				for tag in pspecial:
					translated.append(_translate_special_tag(String(tag)))
				tags_lbl.text = "  ".join(translated)
				tags_lbl.add_theme_font_size_override("font_size", 10)
				tags_lbl.add_theme_color_override("font_color", Color(0.5, 0.6, 0.7, 0.8))
				tags_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				tags_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				plat_inner.add_child(tags_lbl)

			container.add_child(plat_box)

	return container

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

## 翻译敌方相位师装备的 raw 英文 special tag 为中文（4 势力家族 + 梯度后缀）
static func _translate_special_tag(tag: String) -> String:
	# 已知完整翻译表（覆盖 enemy_equipment_specials.gd 全部 56 个 tag）
	const TAG_ZH: Dictionary = {
		# 钢铁（防御系）
		"steel_skin_basic": "钢肤·初", "steel_skin_advanced": "钢肤·进",
		"steel_skin_expert": "钢肤·精", "steel_skin_master": "钢肤·极",
		"fortress_aura": "堡垒光环", "fortress_mastery": "堡垒精通",
		"immortal_fortress": "不朽堡垒", "steel_mountain": "钢山之躯",
		"industrial_aura": "工业光环", "tempered_skin": "淬火之肤",
		"storm_forged": "风暴锻造", "divine_protection": "神圣庇护",
		# 火焰（燃烧系）
		"burning_aura_basic": "焚光·初", "burning_aura_advanced": "焚光·进",
		"burning_aura_expert": "焚光·精", "heat_wave": "热浪",
		"hellfire": "狱火", "immolation": "自焚",
		"eternal_flame": "永恒之焰", "world_burning": "焚世",
		"phoenix_aura": "凤凰光环", "immortal_flame": "不朽之焰",
		"molten_aura": "熔岩光环", "dimensional_burn": "维度灼烧",
		"entropy_flame_passive": "熵焰", "hell_on_earth": "人间炼狱",
		# 雷电（电流系）
		"static_field_basic": "静电场·初", "static_field_advanced": "静电场·进",
		"static_field_expert": "静电场·精", "chain_lightning_passive": "连锁闪电",
		"lightning_speed": "雷电之速", "overcharge": "过载",
		"omnipresent_lightning": "无处不在之雷", "conductive_world": "导通世界",
		"thunder_god_aura": "雷神光环", "conductive_armor": "导能装甲",
		"god_of_thunder": "雷霆之神", "thunder_dome_passive": "雷穹",
		"infinite_energy": "无尽能量",
		# 虚空（熵变系）
		"entropy_aura_basic": "熵光·初", "entropy_aura_advanced": "熵光·进",
		"entropy_aura_expert": "熵光·精", "phase_shift": "相位偏移",
		"reality_tear": "现实撕裂", "void_embrace": "虚空拥抱",
		"void_goddess": "虚空女神", "void_lord": "虚空领主",
		"void_mastery_ultimate": "虚空极意", "night_everlasting": "永夜",
		"reality_breakdown": "现实崩溃", "reality_erasure": "现实抹除",
		"chaos_aura": "混沌光环", "godly_aura": "神圣光环",
		"infinite_potential": "无尽潜能", "master_of_all": "万物之主",
		"perfect_harmony": "完美和谐", "energized_shield": "能量护盾",
	}
	return String(TAG_ZH.get(tag, tag))

func _create_skills_section(section_title: String, skills: Array) -> Control:
	var container = VBoxContainer.new()
	container.add_theme_constant_override("separation", 5)
	container.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	container.add_child(_make_stat_label(section_title, 14, Color(0.6, 0.85, 1, 1)))

	for skill in skills:
		container.add_child(_create_skill_box(skill))

	return container

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
