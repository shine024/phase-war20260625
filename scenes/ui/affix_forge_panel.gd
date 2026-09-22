extends PanelContainer
## 词条工坊 v26.11(A1.1) —— 词缀洗练 / 锁定 / Boss 词条池面板
##
## 背景：洗练计费/锁定/批量重随逻辑（纳米 500~10000 档）在 AffixManager 全齐但零 UI，
## 最大数值 sink 完全闲置（TODO_BACKLOG 高价值#1）。仿 modification_panel 范式：
## 左=卡牌列表（InstanceRegistry 实例全集，铁律#2 数据源），右=词条详情与操作。
## Boss 词条池（boss_1/2/3 共 8 条）：第 1/2/3 次击败相位师渐进解锁
## （battle_manager._deferred_end_battle_finalize 接线，本面板只读展示）。

signal closed()

const DT = preload("res://resources/design_tokens.gd")
const GC = preload("res://resources/game_constants.gd")
const PanelStyles = preload("res://scripts/ui/panel_styles.gd")
const PanelChrome = preload("res://scenes/ui/components/panel_chrome.gd")
const AffixDefs = preload("res://data/affix_definitions.gd")

const TYPE_NAMES := ["机体词条", "武器词条"]
const TYPE_HINTS := [
	"卡牌升级里程碑（Lv5/10/15/20/25/30）自动获得",
	"技能树 / 强化系统授予",
]
const BOSS_TIERS := [
	{"cond": "boss_1", "label": "词条池Ⅰ", "need": "击败第 1 位相位师"},
	{"cond": "boss_2", "label": "词条池Ⅱ", "need": "击败第 2 位相位师"},
	{"cond": "boss_3", "label": "词条池Ⅲ", "need": "击败第 3 位相位师"},
]

var _card_list_box: VBoxContainer = null
var _detail_box: VBoxContainer = null
var _nano_label: Label = null
var _current_identity: String = ""

func _ready() -> void:
	var accent: Color = DT.get_panel_accent("purple")
	add_theme_stylebox_override("panel", PanelStyles.make_panel_frame_textured(accent))
	var vbox := get_node_or_null("Margin/VBoxMain") as VBoxContainer
	if vbox:
		var chrome = PanelChrome.attach_to(vbox, "词条工坊", accent, "词条改装")
		chrome.closed.connect(_on_close)
	_build_layout()
	_refresh_all()

## 基地嵌入面板协议（bunker_main._open_embedded_panel 调 refresh()）
func refresh() -> void:
	_refresh_all()

func _on_close() -> void:
	visible = false
	closed.emit()

# ── 布局 ─────────────────────────────────────────────────────
func _build_layout() -> void:
	var main := get_node_or_null("Margin/VBoxMain") as VBoxContainer
	if main == null:
		return
	# 顶栏：纳米余额 + 当前选中卡
	_nano_label = Label.new()
	_nano_label.add_theme_font_size_override("font_size", DT.FONT_SIZE_SMALL)
	_nano_label.add_theme_color_override("font_color", DT.COLOR_GOLD)
	main.add_child(_nano_label)
	var split := HSplitContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.collapsed = false
	main.add_child(split)
	# 左：卡列表
	var list_scroll := ScrollContainer.new()
	list_scroll.custom_minimum_size = Vector2(250, 0)
	list_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.add_child(list_scroll)
	_card_list_box = VBoxContainer.new()
	_card_list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_card_list_box.add_theme_constant_override("separation", 4)
	list_scroll.add_child(_card_list_box)
	# 右：详情
	var detail_scroll := ScrollContainer.new()
	detail_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.add_child(detail_scroll)
	_detail_box = VBoxContainer.new()
	_detail_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail_box.add_theme_constant_override("separation", 6)
	detail_scroll.add_child(_detail_box)

func _refresh_all() -> void:
	_refresh_nano()
	_refresh_card_list()
	_refresh_detail()
	_refresh_boss_pools()

func _refresh_nano() -> void:
	# v27.2: 按当前选中卡切换货币显示——星冥卡洗练扣星髓，普通卡扣纳米
	var am: Node = get_node_or_null("/root/AffixManager")
	var is_xeno: bool = am != null and am.has_method("is_xeno_card_identity") \
			and not _current_identity.is_empty() \
			and bool(am.is_xeno_card_identity(_current_identity))
	if is_xeno:
		var marrow: int = 0
		var brm: Node = get_node_or_null("/root/BasicResourceManager")
		if brm and brm.has_method("get_total"):
			marrow = int(brm.get_total(BasicResources.ID_STAR_MARROW))
		if _nano_label:
			_nano_label.text = "星髓：%d（星冥卡洗练消耗，锁定词条会抬高批量费用）" % marrow
		return
	var nano: int = 0
	var bm: Node = get_node_or_null("/root/BlueprintManager")
	if bm and bm.has_method("get_nano_materials"):
		nano = int(bm.get_nano_materials())
	# v30 R2b：晶体余额同显（普通卡洗练 = 纳米 + 晶体双计费）
	var crystal: int = 0
	var brm_c: Node = get_node_or_null("/root/BasicResourceManager")
	if brm_c and brm_c.has_method("get_total"):
		crystal = int(brm_c.get_total(BasicResources.ID_CRYSTAL))
	if _nano_label:
		_nano_label.text = "纳米材料：%d ｜ 晶体：%d（洗练双计费，锁定词条会抬高批量费用）" % [nano, crystal]

# ── 卡列表（铁律#2：InstanceRegistry 实例全集）─────────────────
func _refresh_card_list() -> void:
	if _card_list_box == null:
		return
	for c in _card_list_box.get_children():
		c.queue_free()
	var ir: Node = get_node_or_null("/root/InstanceRegistry")
	if ir == null or not ir.has_method("get_all_instance_ids"):
		var empty := Label.new()
		empty.text = "卡牌系统未初始化"
		_card_list_box.add_child(empty)
		return
	var ids: Array = ir.get_all_instance_ids()
	ids.sort()
	if _current_identity.is_empty() and not ids.is_empty():
		_current_identity = String(ids[0])
	var am: Node = get_node_or_null("/root/AffixManager")
	for iid in ids:
		var card = ir.get_instance(String(iid)) if ir.has_method("get_instance") else null
		if card == null:
			continue
		var affix_n: int = 0
		if am and am.has_method("get_affix_count"):
			affix_n = int(am.get_affix_count("%s_%d" % [String(iid), 0])) \
				+ int(am.get_affix_count("%s_%d" % [String(iid), 1]))
		var btn := Button.new()
		btn.text = "%s（词条%d）" % [String(card.display_name), affix_n]
		btn.add_theme_font_size_override("font_size", DT.FONT_SIZE_SMALL)
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		var selected: bool = (String(iid) == _current_identity)
		var styles := PanelStyles.make_button_styles(
			DT.COLOR_VIOLET if selected else DT.COLOR_TEXT_DIM)
		btn.add_theme_color_override("font_color",
			DT.COLOR_TEXT_BRIGHT if selected else DT.COLOR_TEXT_MID)
		btn.add_theme_color_override("font_hover_color", DT.COLOR_HOVER_WHITE)
		btn.add_theme_color_override("font_pressed_color", DT.COLOR_HOVER_WHITE)
		btn.add_theme_color_override("font_focus_color", DT.COLOR_HOVER_WHITE)
		for state in ["normal", "hover", "pressed", "disabled", "focus"]:
			if styles.has(state):
				btn.add_theme_stylebox_override(state, styles[state])
		var captured := String(iid)
		btn.pressed.connect(func() -> void:
			_current_identity = captured
			_refresh_card_list()
			_refresh_detail()
			_refresh_nano()  # v27.2: 选中卡切换后顶栏货币跟随
		)
		_card_list_box.add_child(btn)

# ── 词条详情 ─────────────────────────────────────────────────
func _refresh_detail() -> void:
	if _detail_box == null:
		return
	for c in _detail_box.get_children():
		c.queue_free()
	if _current_identity.is_empty():
		var hint := Label.new()
		hint.text = "左侧选择卡牌查看词条。"
		hint.add_theme_color_override("font_color", DT.COLOR_TEXT_DIM)
		_detail_box.add_child(hint)
		return
	var am: Node = get_node_or_null("/root/AffixManager")
	if am == null:
		return
	var ir: Node = get_node_or_null("/root/InstanceRegistry")
	var card = null
	if ir and ir.has_method("get_instance"):
		card = ir.get_instance(_current_identity)
	# 头部只显示卡名——原始实例 ID（ww1_arm_ft17#1）是技术标识，玩家不可读
	# （2026-09-20 全矩阵报告 P3 核销）；与左侧列表同口径。
	var name_line: String = "未知卡牌"
	if card != null:
		name_line = String(card.display_name)
	var header := Label.new()
	header.text = name_line
	header.add_theme_font_size_override("font_size", DT.FONT_SIZE_LARGE)
	header.add_theme_color_override("font_color", DT.COLOR_TEXT_BRIGHT)
	_detail_box.add_child(header)
	for type in range(2):
		var key := "%s_%d" % [_current_identity, type]
		var section := Label.new()
		section.text = "— %s —" % TYPE_NAMES[type]
		section.add_theme_font_size_override("font_size", DT.FONT_SIZE_MEDIUM)
		section.add_theme_color_override("font_color", DT.COLOR_VIOLET)
		_detail_box.add_child(section)
		var affixes: Array = am.get_card_affixes(key) if am.has_method("get_card_affixes") else []
		if affixes.is_empty():
			var mh := Label.new()
			mh.text = "（暂无词条：%s）" % TYPE_HINTS[type]
			mh.add_theme_font_size_override("font_size", DT.FONT_SIZE_SMALL)
			mh.add_theme_color_override("font_color", DT.COLOR_TEXT_DIM)
			_detail_box.add_child(mh)
			continue
		for i in range(affixes.size()):
			_detail_box.add_child(_build_affix_row(am, key, affixes[i], i))
		# 批量重随条（该类型有未锁定词条才显示）
		_detail_box.add_child(_build_batch_bar(am, key))

func _build_affix_row(am: Node, key: String, a, idx: int) -> PanelContainer:
	var row := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	var rarity_col: Color = GC.get_rarity_color(String(a.rarity))
	sb.bg_color = Color(rarity_col.r, rarity_col.g, rarity_col.b, 0.07)
	sb.border_color = Color(rarity_col.r, rarity_col.g, rarity_col.b, 0.45)
	sb.set_border_width_all(1)
	sb.corner_radius_top_left = 4
	sb.corner_radius_top_right = 4
	sb.corner_radius_bottom_left = 4
	sb.corner_radius_bottom_right = 4
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	row.add_theme_stylebox_override("panel", sb)
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	row.add_child(hbox)
	# 锁定开关（锁定→批量重随时保留）
	var lock_btn := Button.new()
	lock_btn.toggle_mode = false
	lock_btn.custom_minimum_size = Vector2(34, 30)
	lock_btn.add_theme_font_size_override("font_size", DT.FONT_SIZE_SMALL)
	if bool(a.is_locked):
		lock_btn.text = "🔒"
		lock_btn.tooltip_text = "已锁定：批量重随保留此词条（会抬高批量费用）\n点击解除锁定"
	else:
		lock_btn.text = "🔓"
		lock_btn.tooltip_text = "未锁定：批量重随会一起重随\n点击锁定（重随时不被替换）"
	var l_styles := PanelStyles.make_button_styles(
		DT.COLOR_GOLD if not bool(a.is_locked) else DT.COLOR_GREEN_UP)
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		if l_styles.has(state):
			lock_btn.add_theme_stylebox_override(state, l_styles[state])
	lock_btn.pressed.connect(func() -> void:
		if bool(a.is_locked):
			if am.has_method("unlock_affix"):
				am.unlock_affix(key, idx)
		else:
			if am.has_method("lock_affix"):
				am.lock_affix(key, idx)
		_refresh_detail()
	)
	hbox.add_child(lock_btn)
	# 名称 + 等级
	var name_lbl := Label.new()
	name_lbl.text = "%s Lv%d" % [String(a.affix_name), int(a.level)]
	name_lbl.add_theme_font_size_override("font_size", DT.FONT_SIZE_SMALL)
	name_lbl.add_theme_color_override("font_color", rarity_col)
	name_lbl.custom_minimum_size = Vector2(170, 0)
	hbox.add_child(name_lbl)
	# 效果描述（悬停详情）
	var desc_lbl := Label.new()
	desc_lbl.text = String(a.description)
	desc_lbl.add_theme_font_size_override("font_size", DT.FONT_SIZE_SMALL)
	desc_lbl.add_theme_color_override("font_color", DT.COLOR_TEXT_MID)
	desc_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	desc_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	var detailed: String = String(a.get_detailed_description()) if a.has_method("get_detailed_description") else ""
	if not detailed.is_empty():
		desc_lbl.tooltip_text = detailed
	hbox.add_child(desc_lbl)
	# 单条重随（v27.2: 计费货币按卡身份路由——星冥卡星髓 / 普通卡纳米；
	# v30 R2b: 普通卡纳米+晶体双计费）
	var cost: int = int(am.get_reroll_cost_for(key, idx)) if am.has_method("get_reroll_cost_for") else int(am.get_reroll_cost(idx))
	var crystal_cost: int = int(am.get_reroll_crystal_cost(key, idx)) if am.has_method("get_reroll_crystal_cost") else 0
	var cur_label: String = String(am.get_reroll_currency_label(key)) if am.has_method("get_reroll_currency_label") else "纳米材料"
	if crystal_cost > 0:
		cur_label = "%d纳米+%d晶体" % [cost, crystal_cost]
	var reroll_btn := Button.new()
	reroll_btn.text = "重随 %d" % cost
	reroll_btn.add_theme_font_size_override("font_size", DT.FONT_SIZE_SMALL)
	reroll_btn.custom_minimum_size = Vector2(90, 30)
	reroll_btn.disabled = bool(a.is_locked) or not _can_pay_for(key, cost, crystal_cost)
	var r_styles := PanelStyles.make_button_styles(DT.COLOR_VIOLET)
	reroll_btn.add_theme_color_override("font_color", DT.COLOR_TEXT_BRIGHT)
	reroll_btn.add_theme_color_override("font_hover_color", DT.COLOR_HOVER_WHITE)
	reroll_btn.add_theme_color_override("font_pressed_color", DT.COLOR_HOVER_WHITE)
	reroll_btn.add_theme_color_override("font_focus_color", DT.COLOR_HOVER_WHITE)
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		if r_styles.has(state):
			reroll_btn.add_theme_stylebox_override(state, r_styles[state])
	reroll_btn.tooltip_text = "同稀有度重随此词条（等级重置为 1）\n消耗：%s%s" % [cur_label,
		"\n晶体由战斗掉落积累——洗练是晶体的主要去向" if crystal_cost > 0 else ""]
	reroll_btn.pressed.connect(func() -> void:
		if am.has_method("reroll_affix") and am.reroll_affix(key, idx):
			if SignalBus.has_signal("show_toast"):
				SignalBus.show_toast.emit("词条已重随（-%s）" % cur_label)
		else:
			if SignalBus.has_signal("show_toast"):
				SignalBus.show_toast.emit("⚠ 重随失败：%s不足或词条已锁定" % cur_label)
		_refresh_nano()
		_refresh_detail()
	)
	hbox.add_child(reroll_btn)
	return row

func _build_batch_bar(am: Node, key: String) -> Control:
	var cost_info: Dictionary = am.get_batch_reroll_cost(key) if am.has_method("get_batch_reroll_cost") else {}
	var reroll_n: int = int(cost_info.get("reroll_count", 0))
	var total: int = int(cost_info.get("total_cost", 0))
	if reroll_n <= 0 or total <= 0:
		return HSeparator.new()
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 10)
	var info := Label.new()
	var lock_n: int = int(cost_info.get("locked_count", 0))
	var extra: int = int(cost_info.get("extra_lock_cost", 0))
	# v27.2: 货币文案按卡身份（星冥卡星髓 / 普通卡纳米）；v30 R2b: 普通卡加晶体分量
	var cur_label: String = String(am.get_reroll_currency_label(key)) if am != null and am.has_method("get_reroll_currency_label") else "纳米材料"
	var crystal_total: int = int(cost_info.get("crystal_cost", 0))
	var cur_full: String = cur_label if crystal_total <= 0 else "%d%s+%d晶体" % [total, cur_label, crystal_total]
	info.text = "批量重随未锁定 %d 条%s：共 %s" % [
		reroll_n,
		("（已锁定 %d 条，附加 +%d）" % [lock_n, extra]) if lock_n > 0 else "",
		cur_full,
	]
	info.add_theme_font_size_override("font_size", DT.FONT_SIZE_SMALL)
	info.add_theme_color_override("font_color", DT.COLOR_TEXT_SOFT)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(info)
	var btn := Button.new()
	btn.text = "批量重随"
	btn.custom_minimum_size = Vector2(110, 32)
	btn.add_theme_font_size_override("font_size", DT.FONT_SIZE_SMALL)
	btn.disabled = not _can_pay_for(key, total, crystal_total)
	var b_styles := PanelStyles.make_button_styles(DT.COLOR_VIOLET)
	btn.add_theme_color_override("font_color", DT.COLOR_TEXT_BRIGHT)
	btn.add_theme_color_override("font_hover_color", DT.COLOR_HOVER_WHITE)
	btn.add_theme_color_override("font_pressed_color", DT.COLOR_HOVER_WHITE)
	btn.add_theme_color_override("font_focus_color", DT.COLOR_HOVER_WHITE)
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		if b_styles.has(state):
			btn.add_theme_stylebox_override(state, b_styles[state])
	btn.pressed.connect(func() -> void:
		if am.has_method("batch_reroll_affixes") and am.batch_reroll_affixes(key):
			if SignalBus.has_signal("show_toast"):
				SignalBus.show_toast.emit("批量重随完成（-%s）" % cur_full)
		else:
			if SignalBus.has_signal("show_toast"):
				SignalBus.show_toast.emit("⚠ 批量重随失败：%s不足" % cur_label)
		_refresh_nano()
		_refresh_detail()
	)
	bar.add_child(btn)
	return bar

func _can_afford(cost: int) -> bool:
	var bm: Node = get_node_or_null("/root/BlueprintManager")
	if bm and bm.has_method("get_nano_materials"):
		return int(bm.get_nano_materials()) >= cost
	return false

## v27.2: 按词条 key 判定余额（星冥卡查星髓 / 普通卡查纳米），管理器路由判定优先
func _can_pay_for(key: String, cost: int, crystal_cost: int = 0) -> bool:
	var am: Node = get_node_or_null("/root/AffixManager")
	if am and am.has_method("can_pay_reroll"):
		return bool(am.can_pay_reroll(key, cost, crystal_cost))
	return _can_afford(cost)

# ── Boss 词条池（只读展示；解锁在战斗结算侧渐进触发）────────────
func _refresh_boss_pools() -> void:
	if _detail_box == null:
		return
	_detail_box.add_child(HSeparator.new())
	var title := Label.new()
	title.text = "◆ Boss 词条池（击败相位师解锁，重随可刷出）"
	title.add_theme_font_size_override("font_size", DT.FONT_SIZE_MEDIUM)
	title.add_theme_color_override("font_color", DT.COLOR_GOLD)
	_detail_box.add_child(title)
	var am: Node = get_node_or_null("/root/AffixManager")
	var unlocked: Array = am.get_unlocked_bosses() if am and am.has_method("get_unlocked_bosses") else []
	# 池内容：AFFIX_TABLE 里 unlock_condition 非-none 的词条按条件分组
	var pools: Dictionary = {}
	for affix_id in AffixDefs.AFFIX_TABLE:
		var def: Dictionary = AffixDefs.AFFIX_TABLE[affix_id]
		var cond := String(def.get("unlock_condition", "none"))
		if cond == "none" or cond.is_empty():
			continue
		if not pools.has(cond):
			pools[cond] = []
		pools[cond].append(def)
	for tier in BOSS_TIERS:
		var cond := String(tier["cond"])
		var is_unlocked: bool = unlocked.has(cond)
		var line := Label.new()
		line.add_theme_font_size_override("font_size", DT.FONT_SIZE_SMALL)
		var names: Array[String] = []
		for def in pools.get(cond, []):
			names.append(String(def.get("affix_name", "?")))
		if is_unlocked:
			line.text = "✓ %s 已解锁：%s" % [String(tier["label"]), "、".join(names)]
			line.add_theme_color_override("font_color", DT.COLOR_GREEN_UP)
		else:
			line.text = "🔒 %s 未解锁（%s）：%s" % [String(tier["label"]), String(tier["need"]), "、".join(names)]
			line.add_theme_color_override("font_color", DT.COLOR_TEXT_DIM)
		line.autowrap_mode = TextServer.AUTOWRAP_WORD
		_detail_box.add_child(line)
