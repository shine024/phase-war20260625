extends PanelContainer
## v9.1 组合技状态条：底部 HUD，显示 6 套套路激活状态
## 颜色三态：灰(未激活) / 橙(单卡激活，装≥2配套改造) / 绿(全队激活，兵种组合满足)
## 每秒轮询 combo_engine + 场上单位 mods（节流，非每帧）
## v21 P2: 追加"搭档协同"指示区——单按钮 🤝n/5，tooltip 列出 5 对搭档激活态
## （宽度敏感：本面板顶部预算 472px，6 套路图标已占 348px，搭档区只加 56px 保持 404px 内）

const DT = preload("res://resources/design_tokens.gd")
# 批次三 B10：字号 token 引入（10px 白名单/中文升 12）
const ComboTactics = preload("res://data/combo_tactics.gd")
const ComboEngine = preload("res://scripts/battle/combo_engine.gd")

const _COMBO_ORDER: Array[String] = [
	ComboTactics.COMBO_INCENDIARY,
	ComboTactics.COMBO_EMP,
	ComboTactics.COMBO_NANO,
	ComboTactics.COMBO_LASER,
	ComboTactics.COMBO_RECON,
	ComboTactics.COMBO_CHEM,
]

## v21 P2: 搭档协同显示顺序
const _PAIR_ORDER: Array[String] = [
	"pair_recon_artillery", "pair_engineer_infantry", "pair_aa_air",
	"pair_armor_infantry", "pair_fort_support",
]

var _icon_buttons: Array = []  # [{btn:Button, combo_id:String}]
var _pair_btn: Button = null   # v21 P2: 搭档协同指示按钮
var _refresh_acc: float = 0.0
const REFRESH_SEC: float = 0.6
var _dt_accum: float = 0.0  # 用于 tooltip 更新
var _cache_team_combos: Array = []
var _cache_card_combos: Array = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# v9.1 修复重叠：内容仅 348px（标题60 + 6×42按钮 + 间隔），原 520 会强制撑宽顶到 TopHudBar 居中区。
	# 收到 360 让 PanelContainer 贴合实际内容，main.tscn 定位 (8,8,480,48) 给足 472px 余量。
	custom_minimum_size = Vector2(360, 40)
	# 半透明深色背景
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.04, 0.06, 0.10, 0.72)
	bg.set_content_margin_all(4)
	bg.set_corner_radius_all(6)
	bg.border_width_left = 1
	bg.border_width_top = 1
	bg.border_width_right = 1
	bg.border_width_bottom = 1
	bg.border_color = Color(0.3, 0.4, 0.5, 0.4)
	add_theme_stylebox_override("panel", bg)
	# 内边距
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 6)
	margin.add_theme_constant_override("margin_right", 6)
	margin.add_theme_constant_override("margin_top", 2)
	margin.add_theme_constant_override("margin_bottom", 2)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(margin)
	# HBox：标题 + 6 图标
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 4)
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(hbox)
	# 标题
	var title := Label.new()
	title.text = "⚔组合技"
	title.add_theme_font_size_override("font_size", DT.FONT_SIZE_SMALL)
	title.add_theme_color_override("font_color", Color(0.75, 0.8, 0.88, 0.85))
	title.add_theme_color_override("font_outline_color", DT.COLOR_BACKDROP_DEEP)
	title.add_theme_constant_override("outline_size", 1)
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(title)
	# 6 个套路图标
	for combo_id in _COMBO_ORDER:
		var def := ComboTactics.get_combo_def(combo_id)
		if def.is_empty():
			continue
		var btn := _make_combo_icon_button(def, combo_id)
		hbox.add_child(btn)
		_icon_buttons.append({"btn": btn, "combo_id": combo_id})
	# v21 P2: 搭档协同指示按钮（🤝 n/5，tooltip 列出全部搭档）
	_pair_btn = _make_pair_button()
	hbox.add_child(_pair_btn)
	# 宽度预算：原 348 + 8(分隔) + 52(搭档钮) = 408 ≤ 472 顶部预算
	custom_minimum_size = Vector2(408, 40)


## v21 P2: 创建搭档协同指示按钮
func _make_pair_button() -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(52, 30)
	btn.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.text = "🤝0/5"
	btn.add_theme_font_size_override("font_size", DT.FONT_SIZE_SMALL)
	btn.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6, 1))
	btn.add_theme_color_override("font_outline_color", DT.COLOR_BACKDROP_DEEP)
	btn.add_theme_constant_override("outline_size", 1)
	_set_combo_style(btn, 0)
	btn.tooltip_text = _build_pair_tooltip(0)
	return btn


## v21 P2: 搭档协同 tooltip（列出 5 对搭档与激活态）
func _build_pair_tooltip(active_count: int) -> String:
	var lines: Array[String] = ["🤝搭档协同（%d/5 激活）" % active_count]
	var eng: RefCounted = _get_combo_engine()
	for pid in _PAIR_ORDER:
		var def: Dictionary = ComboTactics.PAIR_SYNERGIES.get(pid, {})
		if def.is_empty():
			continue
		var active: bool = eng != null and eng.has_method("is_pair_active") and bool(eng.is_pair_active(pid))
		lines.append("%s %s — %s" % ["✓" if active else "○", String(def.get("name", pid)), String(def.get("desc", ""))])
	return "\n".join(lines)


func _make_combo_icon_button(def: Dictionary, combo_id: String) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(42, 30)
	btn.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.text = String(def.get("icon", "?"))
	btn.add_theme_font_size_override("font_size", DT.FONT_SIZE_BODY)
	btn.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6, 1))
	btn.add_theme_color_override("font_outline_color", DT.COLOR_BACKDROP_DEEP)
	btn.add_theme_constant_override("outline_size", 1)
	_set_combo_style(btn, 0)
	# tooltip 动态生成（每秒刷新）
	btn.tooltip_text = _build_tooltip(combo_id, 0)
	return btn


func _build_tooltip(combo_id: String, level: int) -> String:
	var def := ComboTactics.get_combo_def(combo_id)
	var name := String(def.get("name", combo_id))
	var desc := String(def.get("desc", ""))
	var state_text := "未激活"
	match level:
		1: state_text = "单卡激活（装了≥2配套改造）"
		2: state_text = "✦全队激活✦（兵种组合满足）"
	return "%s\n%s\n状态：%s" % [name, desc, state_text]


## level: 0=未激活 1=单卡 2=全队
func _set_combo_style(btn: Button, level: int) -> void:
	var normal := StyleBoxFlat.new()
	var hover := StyleBoxFlat.new()
	var focused := StyleBoxFlat.new()
	normal.set_corner_radius_all(4)
	hover.set_corner_radius_all(4)
	focused.set_corner_radius_all(4)
	normal.set_content_margin_all(2)
	hover.set_content_margin_all(2)
	focused.set_content_margin_all(2)
	match level:
		0:  # 未激活：深灰
			normal.bg_color = Color(0.12, 0.13, 0.16, 0.85)
			hover.bg_color = Color(0.18, 0.19, 0.22, 0.9)
			focused.bg_color = normal.bg_color
			btn.add_theme_color_override("font_color", Color(0.55, 0.55, 0.58, 1))
		1:  # 单卡：橙
			normal.bg_color = Color(0.75, 0.45, 0.10, 0.85)
			hover.bg_color = Color(0.85, 0.55, 0.15, 0.9)
			focused.bg_color = hover.bg_color
			btn.add_theme_color_override("font_color", Color(1.0, 0.95, 0.85, 1))
		2:  # 全队：绿 + 发光边框
			normal.bg_color = Color(0.18, 0.72, 0.32, 0.92)
			hover.bg_color = Color(0.25, 0.85, 0.40, 0.96)
			focused.bg_color = hover.bg_color
			normal.border_width_left = 1
			normal.border_width_top = 1
			normal.border_width_right = 1
			normal.border_width_bottom = 1
			normal.border_color = Color(0.6, 1.0, 0.5, 0.95)
			btn.add_theme_color_override("font_color", Color(0.98, 1.0, 0.95, 1))
	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("focus", focused)
	btn.add_theme_stylebox_override("pressed", normal)


func _process(delta: float) -> void:
	_refresh_acc += delta
	if _refresh_acc >= REFRESH_SEC:
		_refresh_acc = 0.0
		_refresh()


func _refresh() -> void:
	var eng: RefCounted = _get_combo_engine()
	if eng == null:
		# 战斗未开始：全部置灰
		for entry in _icon_buttons:
			var btn: Button = entry["btn"]
			_set_combo_style(btn, 0)
			btn.tooltip_text = _build_tooltip(entry["combo_id"], 0)
		if _pair_btn != null:
			_set_combo_style(_pair_btn, 0)
			_pair_btn.text = "🤝0/5"
			_pair_btn.tooltip_text = _build_pair_tooltip(0)
		return
	# 全队激活 combo_id（通过 mechanisms 反推）
	var team_mechs: Array = eng.get_active_mechanisms()
	var team_combos: Array = _mechs_to_combo_ids(team_mechs)
	# 单卡激活 combo_id（扫描场上单位 mods）
	var card_combos: Array = _detect_card_combos_on_field(eng)
	_cache_team_combos = team_combos
	_cache_card_combos = card_combos
	# 更新 6 个按钮
	for entry in _icon_buttons:
		var combo_id: String = entry["combo_id"]
		var btn: Button = entry["btn"]
		var level: int = 0
		if team_combos.has(combo_id):
			level = 2
		elif card_combos.has(combo_id):
			level = 1
		_set_combo_style(btn, level)
		btn.tooltip_text = _build_tooltip(combo_id, level)
	# v21 P2: 搭档协同指示刷新
	if _pair_btn != null:
		var pair_active: int = 0
		if eng.has_method("is_pair_active"):
			for pid in _PAIR_ORDER:
				if bool(eng.is_pair_active(pid)):
					pair_active += 1
		_set_combo_style(_pair_btn, 2 if pair_active > 0 else 0)
		_pair_btn.text = "🤝%d/5" % pair_active
		_pair_btn.tooltip_text = _build_pair_tooltip(pair_active)


## 从 active mechanisms 反推 combo_id（机制名→套路映射）
func _mechs_to_combo_ids(mechs: Array) -> Array:
	var result: Array = []
	for combo_id in _COMBO_ORDER:
		var def := ComboTactics.get_combo_def(combo_id)
		var combo_mechs: Array = def.get("mechanisms", [])
		var hit: bool = false
		for m in combo_mechs:
			if mechs.has(String(m)):
				hit = true
				break
		if hit:
			result.append(combo_id)
	return result


## 扫描场上玩家单位的 mods，检测单卡激活的 combo_id
func _detect_card_combos_on_field(eng: RefCounted) -> Array:
	var allies: Array = []
	var tree := get_tree()
	if tree != null:
		allies = tree.get_nodes_in_group("player_units")
	var result: Array = []
	for u in allies:
		if u == null or not is_instance_valid(u):
			continue
		var mods: Array = []
		if "stats" in u and u.stats != null:
			if u.stats.has_meta("mod_ids"):
				mods = u.stats.get_meta("mod_ids", [])
		if mods.is_empty():
			continue
		var card_combos: Array = ComboTactics.detect_card_combos(mods)
		for cid in card_combos:
			if not result.has(cid):
				result.append(cid)
	return result


func _get_combo_engine() -> RefCounted:
	var bm := get_node_or_null("/root/BattleManager")
	if bm == null:
		bm = get_node_or_null("/root/Main/BattleManager")
	if bm == null:
		return null
	if bm.has_method("get_combo_engine"):
		return bm.get_combo_engine()
	return null
