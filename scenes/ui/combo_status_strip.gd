extends PanelContainer
## v9.1 组合技状态条：底部 HUD，显示 6 套套路激活状态
## 颜色三态：灰(未激活) / 橙(单卡激活，装≥2配套改造) / 绿(全队激活，兵种组合满足)
## 每秒轮询 combo_engine + 场上单位 mods（节流，非每帧）
## v21 P2: 追加"搭档协同"指示区——单按钮 🤝n/5，tooltip 列出 5 对搭档激活态
## （宽度敏感：本面板顶部预算 472px，6 套路图标已占 348px，搭档区只加 56px 保持 404px 内）
## v6.35.2（用户拍板）：🤝n/5 与 🛡n/6 两个聚合钮移除（顶部预算被撑爆压住关卡信息
## Capsule）——条上恒 6 个套路图标（回归锁 test_combo_strip_layout）。
## 记录5#9（用户拍板）：图标改 GridContainer 两行排布（一行 5 个），图标 mouse_filter
## 打开悬停提示（此前 IGNORE=悬浮零提示）；主场景 rect 同步收窄加高。
## v6.52（记录1#15，用户新拍板推翻"恒 6 点亮"模式）：**实有几显几**——未激活的战法
## 图标不再占位（灰色图标墙=看不出哪个是哪个）；零激活时显示一枚 ⚔ 总览钮（悬停列
## 全部战法与达成条件），激活后条上只保留已达成战法的彩色图标。

const DT = preload("res://resources/design_tokens.gd")
# 批次三 B10：字号 token 引入（10px 白名单/中文升 12）
const ComboTactics = preload("res://data/combo_tactics.gd")
const PanelStyles = preload("res://scripts/ui/panel_styles.gd")
const ComboEngine = preload("res://scripts/battle/combo_engine.gd")

const _COMBO_ORDER: Array[String] = [
	ComboTactics.COMBO_INCENDIARY,
	ComboTactics.COMBO_EMP,
	ComboTactics.COMBO_NANO,
	ComboTactics.COMBO_LASER,
	ComboTactics.COMBO_RECON,
	ComboTactics.COMBO_CHEM,
]

## 记录5#9：一行图标数（第 6 个换行）
const ICONS_PER_ROW: int = 5

var _icon_buttons: Array = []  # [{btn:Button, combo_id:String, prev:int}]
var _overview_btn: Button = null  # v6.52: 零激活时的战法总览钮
var _refresh_acc: float = 0.0
const REFRESH_SEC: float = 0.6
var _dt_accum: float = 0.0  # 用于 tooltip 更新
var _cache_team_combos: Array = []
var _cache_card_combos: Array = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# v25 HUD 家族底板（对齐资源栏/战斗日志同语言）
	var bg := PanelStyles.make_hud_panel(0.4)
	bg.set_content_margin_all(4)
	add_theme_stylebox_override("panel", bg)
	# 内边距
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 6)
	margin.add_theme_constant_override("margin_right", 6)
	margin.add_theme_constant_override("margin_top", 2)
	margin.add_theme_constant_override("margin_bottom", 2)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(margin)
	# HBox：标题 + 两行网格
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
	# 记录5#9：两行网格——一行 5 个，第 6 个换行（含 🤝🛡 聚合钮已随 v6.35.2 移除）
	var grid := GridContainer.new()
	grid.columns = ICONS_PER_ROW
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(grid)
	for combo_id in _COMBO_ORDER:
		var def := ComboTactics.get_combo_def(combo_id)
		if def.is_empty():
			continue
		var btn := _make_combo_icon_button(def, combo_id)
		grid.add_child(btn)
		_icon_buttons.append({"btn": btn, "combo_id": combo_id, "prev": 0})
	# v6.52（记录1#15）：零激活总览钮——悬停列全部战法与达成条件（"有什么可攒"的入口）
	_overview_btn = _make_combo_icon_button({"icon": "⚔"}, "_overview")
	_overview_btn.tooltip_text = _build_overview_tooltip()
	grid.add_child(_overview_btn)
	# 宽度预算：标题~58 + 5×42+4×4=226 + 边距 ≈308 ≤430（Capsule 左缘 435 契约）；
	# 高：2×30+4 行距 + 边距 ≈76（main.tscn offset_bottom 同步 48→84，BuffFoldCard 下移）
	custom_minimum_size = Vector2(308, 76)


func _make_combo_icon_button(def: Dictionary, combo_id: String) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(42, 30)
	# 记录5#9：STOP——图标可悬停弹 tooltip（原 IGNORE=悬浮零提示零反馈）
	btn.mouse_filter = Control.MOUSE_FILTER_STOP
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


## v6.52（记录1#15）：零激活总览 tooltip——全部战法与达成方向一览
func _build_overview_tooltip() -> String:
	var lines := PackedStringArray()
	lines.append("战法一览（达成组合后图标亮在这里）")
	for combo_id in _COMBO_ORDER:
		var def := ComboTactics.get_combo_def(combo_id)
		if def.is_empty():
			continue
		lines.append("· %s：%s" % [String(def.get("name", combo_id)), String(def.get("desc", ""))])
	return "\n".join(lines)


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
		# 战斗未开始：全部置灰+只留总览钮
		for entry in _icon_buttons:
			var btn: Button = entry["btn"]
			_set_combo_style(btn, 0)
			btn.tooltip_text = _build_tooltip(entry["combo_id"], 0)
			entry["prev"] = 0
		_apply_visibility_rule(0)
		return
	# 全队激活 combo_id（通过 mechanisms 反推）
	var team_mechs: Array = eng.get_active_mechanisms()
	var team_combos: Array = _mechs_to_combo_ids(team_mechs)
	# 单卡激活 combo_id（扫描场上单位 mods）
	var card_combos: Array = _detect_card_combos_on_field(eng)
	_cache_team_combos = team_combos
	_cache_card_combos = card_combos
	# 更新按钮
	var active_count := 0
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
		# v30 R3：激活档位跃升瞬间弹跳（协同可见性——"图标亮了"升级为"激活时刻"）
		if level > int(entry.get("prev", 0)):
			_pop_button(btn)
		entry["prev"] = level
		if level > 0:
			active_count += 1
	_apply_visibility_rule(active_count)


## v6.52（记录1#15）：实有几显几——未激活图标隐藏，零激活只显总览钮。
## （用户新拍板推翻 v6.35.2"恒 6 点亮"：灰图标墙读不出战法，占位还挤。）
## 条底板随内容收缩（主场景 rect (8,8,320,84) 是上限，缩窄不越界）。
func _apply_visibility_rule(active_count: int) -> void:
	for entry in _icon_buttons:
		var btn: Button = entry["btn"]
		btn.visible = active_count > 0 and int(entry.get("prev", 0)) > 0
	if _overview_btn != null and is_instance_valid(_overview_btn):
		_overview_btn.visible = active_count == 0
	var shown: int = active_count if active_count > 0 else 1
	var rows: int = 1 if shown <= ICONS_PER_ROW else 2
	var w: float = 58.0 + 4.0 + float(shown) * 42.0 + float(maxi(shown - 1, 0)) * 4.0 + 16.0
	var h: float = 8.0 + float(rows) * 30.0 + float(maxi(rows - 1, 0)) * 4.0 + 6.0
	custom_minimum_size = Vector2(w, h)


## v30 R3：按钮激活弹跳（一次性 scale 脉冲；减少动效开关旁路）
func _pop_button(btn: Button) -> void:
	if btn == null or not is_instance_valid(btn) or DT.is_motion_reduce():
		return
	if btn.has_meta("pop_tween") and (btn.get_meta("pop_tween") as Tween) != null \
			and (btn.get_meta("pop_tween") as Tween).is_valid():
		return  # 上一次弹跳未完不叠发
	var tw := create_tween()
	btn.set_meta("pop_tween", tw)
	tw.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(btn, "scale", Vector2(1.3, 1.3), 0.12)
	tw.tween_property(btn, "scale", Vector2.ONE, 0.18)
	tw.finished.connect(func() -> void:
		if is_instance_valid(btn):
			btn.remove_meta("pop_tween")
	)

## 从 active mechanisms 反推 combo_id（机制名→套路映射）
## v6.35.2：聚合钮移除后只服务 6 个常驻图标（v27 新六套装的实时态经
## 底栏 NameSection 备战预示 + combo_engine 机制消费，不在本条显示）。
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
