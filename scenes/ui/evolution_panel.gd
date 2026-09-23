extends Control
class_name EvolutionPanel
## 制造中心（v26：进化退役后接管本面板；文件名/场景/挂载点保留以兼容
## UILazyLoader "evolution" / card_info_panel TabEvolve 嵌入 / toggle_evolution 信号链）
##
## 三栏布局语义重映射（.tscn 节点不动）：
##   左栏 名册   → 配方目录（38 个可制造卡种：名称 + 时代 + 情报%）
##   中栏 进化树 → 品质概率池（当前配方，含暗保底后的有效权重）
##   右栏 详情   → 条件行（情报档/时代授权/资源）+ 模板属性 + 消耗 + 制造按钮
##
## 数据源：ManufactureManager（managers/manufacture_manager.gd，懒加载）

signal closed

const DefaultCards = preload("res://data/default_cards.gd")
const ManufacturePools = preload("res://data/manufacture_pools.gd")
const ModManufactureRef = preload("res://data/mod_manufacture.gd")
const GC = preload("res://resources/game_constants.gd")
# v7.x UI 重设计基建
const DT = preload("res://resources/design_tokens.gd")
const PanelStyles = preload("res://scripts/ui/panel_styles.gd")
# v37.1 改造图纸缩略图收口到统一图标座（稀有度发光底座）
const ModIconTileRef = preload("res://scripts/ui/mod_icon_tile.gd")

const THEME_VIOLET := DT.COLOR_VIOLET
const THEME_VIOLET_SOFT := DT.COLOR_VIOLET_SOFT
const THEME_GOLD := DT.COLOR_GOLD
const THEME_CYAN := DT.COLOR_ACCENT_CYAN
const THEME_GREEN := DT.COLOR_GREEN_BRIGHT
const THEME_RED := DT.COLOR_RED_DOWN
const THEME_TEXT := DT.COLOR_TEXT_BRIGHT
const THEME_TEXT_DIM := DT.COLOR_TEXT_DIM

## 筛选模式（chip 复用：全部 / 可制造 / 情报未达标）
const FILTER_ALL := "all"
const FILTER_OK := "ok"        # 原 FILTER_EVO
const FILTER_LOCKED := "locked"  # 原 FILTER_FINAL

## v26.x 改造消耗品化：制造站双模式（兵种卡 / 改造图纸补给）
const MODE_CARD := "card"
const MODE_MOD := "mod"
## mod 模式的"随机补给箱"选中哨兵——不能用空串（空串=未选中，
## 默认选中逻辑会 refresh→select→refresh 无限递归）
const MOD_BOX_SEL := "__mod_box__"

## 时代显示名（下标 = GameConstants.Era）
const ERA_NAMES := ["一战", "二战", "冷战", "现代", "近未来"]

## 资源栏四标签 → 完整资源 id
const RES_SLOTS := [
	{"label_ref": "power", "id": "nano_materials", "name": "纳米"},
	{"label_ref": "energy", "id": "energy_block", "name": "能量块"},
	{"label_ref": "alloy", "id": "alloy", "name": "合金"},
	{"label_ref": "crystal", "id": "crystal", "name": "晶体"},
]

# UI 组件引用（v7.x 重构：改用 % unique_name）
var evolution_tree: VBoxContainer = null       # 中栏：品质池容器（节点名保留）
var detail_content: VBoxContainer = null
var result_label: Label = null
var no_selection_label: Label = null
var target_name_label: Label = null
var info_details: Label = null
var req_list: VBoxContainer = null
var resource_details: Label = null
var evolve_button: Button = null               # 制造按钮（节点名保留）
# v6.19.4 右栏死区复活：五分节 + 卡面预览的显隐统一口管理
# （tscn 默认隐藏=无选择初态；写入内容后按分支亮起，见 _set_detail_sections_visible）
var target_name_panel: PanelContainer = null
var info_panel: PanelContainer = null
var requirements_panel: PanelContainer = null
var stats_panel: PanelContainer = null
var resource_panel: PanelContainer = null
var preview_panel: PanelContainer = null
var preview_texture: TextureRect = null

# 资源栏
var power_label: Label = null
var enhance_label: Label = null
var mods_label: Label = null
var status_line_label: Label = null
var meta_label: Label = null

# 左栏（配方目录）
var card_list_container: VBoxContainer = null
var col_head_count: Label = null
var path_head_count: Label = null
var chip_all: Button = null
var chip_evo: Button = null
var chip_final: Button = null
var left_panel: PanelContainer = null

# 统计标签（9 个）
var stat_hp: Label = null
var stat_attack_light: Label = null
var stat_attack_armor: Label = null
var stat_attack_air: Label = null
var stat_defense_light: Label = null
var stat_defense_armor: Label = null
var stat_defense_air: Label = null
var stat_range: Label = null
var stat_speed: Label = null

var selected_card: CardResource = null   # 嵌入模式注入的当前卡（兼容旧接口名）
var selected_recipe_id: String = ""
var _embedded_mode: bool = false
var _filter_mode: String = FILTER_ALL
# v26.x 改造消耗品化：模式与图纸选择（mod 模式下 _selected_mod_id 为空 = 选中随机补给箱）
var _craft_mode: String = MODE_CARD
var _selected_mod_id: String = ""
var _mode_btn_card: Button = null
var _mode_btn_mod: Button = null
# v8.x 性能：on_overlay_opened 拆帧重入守卫
var _open_refresh_inflight: bool = false
# v27.12 性能：面板不可见期间的配方目录重建请求只置脏不重建，
# 恢复可见时由 _on_visibility_refresh 统一补刷
var _recipe_list_dirty: bool = false

func _ready() -> void:
	# D1: 根框架统一 PanelStyles 签名框
	var bg_panel := get_node_or_null("BgPanel")
	if bg_panel is Control:
		(bg_panel as Control).add_theme_stylebox_override("panel",
			PanelStyles.make_panel_frame_textured(DT.COLOR_VIOLET))
	# UI 四级标准修复 R-D3 子批3：标题栏归一 PanelChrome（进化·紫）——旧手写
	# TitleRow 隐藏留档（%MetaLabel/%CloseButton 引用保活），✕ 关闭走 chrome.closed
	# → 既有 _on_close → closed 信号（main._on_panel_closed 接线不变）。
	var old_title_row := get_node_or_null("VBoxContainer/TitleRow")
	if old_title_row is Control:
		(old_title_row as Control).visible = false
	var content_vbox := get_node_or_null("VBoxContainer") as BoxContainer
	if content_vbox != null:
		var chrome := PanelChrome.attach_to(content_vbox, "制造舱", DT.COLOR_VIOLET, "EVOLUTION FORGE")
		chrome.closed.connect(_on_close)
	# 节点绑定（% unique_name；中/左栏标题为普通路径节点）
	evolution_tree = get_node_or_null("%EvolutionTree")
	detail_content = get_node_or_null("%DetailContent")
	result_label = get_node_or_null("%ResultLabel")
	no_selection_label = get_node_or_null("%NoSelectionLabel")
	target_name_label = get_node_or_null("%TargetNameLabel")
	info_details = get_node_or_null("%InfoDetails")
	req_list = get_node_or_null("%ReqList")
	resource_details = get_node_or_null("%ResourceDetails")
	evolve_button = get_node_or_null("%EvolveButton")
	target_name_panel = get_node_or_null("%TargetNamePanel")
	info_panel = get_node_or_null("%InfoPanel")
	requirements_panel = get_node_or_null("%RequirementsPanel")
	stats_panel = get_node_or_null("%StatsPanel")
	resource_panel = get_node_or_null("%ResourcePanel")
	preview_panel = get_node_or_null("%PreviewPanel")
	preview_texture = get_node_or_null("%PreviewTexture")

	stat_hp = get_node_or_null("%StatHP")
	stat_attack_light = get_node_or_null("%StatAttackLight")
	stat_attack_armor = get_node_or_null("%StatAttackArmor")
	stat_attack_air = get_node_or_null("%StatAttackAir")
	stat_defense_light = get_node_or_null("%StatDefenseLight")
	stat_defense_armor = get_node_or_null("%StatDefenseArmor")
	stat_defense_air = get_node_or_null("%StatDefenseAir")
	stat_range = get_node_or_null("%StatRange")
	stat_speed = get_node_or_null("%StatSpeed")

	power_label = get_node_or_null("%PowerLabel")
	enhance_label = get_node_or_null("%EnhanceLabel")
	mods_label = get_node_or_null("%ModsLabel")
	status_line_label = get_node_or_null("%StatusLineLabel")
	meta_label = get_node_or_null("%MetaLabel")

	card_list_container = get_node_or_null("%CardListContainer")
	col_head_count = get_node_or_null("%ColHeadCount")
	path_head_count = get_node_or_null("%PathHeadCount")
	chip_all = get_node_or_null("%ChipAll")
	chip_evo = get_node_or_null("%ChipEvo")
	chip_final = get_node_or_null("%ChipFinal")
	left_panel = get_node_or_null("%LeftPanel")

	# 栏目标题改语义（普通路径节点）
	var title_label = get_node_or_null("%TitleLabel")
	if title_label:
		title_label.text = "制造舱"
	var title_sub = get_node_or_null("VBoxContainer/TitleRow/TitleHBox/TitleSub")
	if title_sub:
		title_sub.text = "情报 × 资源 → 兵种卡"
	var col_head_title = get_node_or_null("VBoxContainer/BodyHBox/LeftPanel/LeftVBox/ColHead/ColHeadHBox/ColHeadTitle")
	if col_head_title:
		col_head_title.text = "配方目录"
	var path_head_title = get_node_or_null("VBoxContainer/BodyHBox/MiddlePanel/MiddleVBox/PathHead/PathHeadHBox/PathHeadTitle")
	if path_head_title:
		path_head_title.text = "品质概率池"

	# 按钮
	var close_btn = get_node_or_null("%CloseButton")
	if close_btn:
		close_btn.pressed.connect(_on_close)
	var back_btn = get_node_or_null("%BackToGrowthButton")
	if back_btn:
		back_btn.pressed.connect(_on_back_to_growth)

	# v26.16 视觉批次：主制造按钮走按钮工厂（solid 档 + 补齐 disabled/focus 四态）
	if evolve_button:
		var bstyles: Dictionary = PanelStyles.make_button_styles(DT.COLOR_VIOLET, "solid")
		for state in ["normal", "hover", "pressed", "disabled", "focus"]:
			evolve_button.add_theme_stylebox_override(state, bstyles[state])

	# chip 筛选
	if chip_all:
		chip_all.pressed.connect(_on_filter_pressed.bind(FILTER_ALL))
		chip_all.text = "全部"
	if chip_evo:
		chip_evo.pressed.connect(_on_filter_pressed.bind(FILTER_OK))
		chip_evo.text = "可制造"
	if chip_final:
		chip_final.pressed.connect(_on_filter_pressed.bind(FILTER_LOCKED))
		chip_final.text = "未解锁"

	# 批次三 B2c 惯例：就地解释
	if chip_all:
		chip_all.tooltip_text = "显示全部可制造配方"
	if chip_evo:
		chip_evo.tooltip_text = "只显示当前情报/授权/资源全部达标的配方"
	if chip_final:
		chip_final.tooltip_text = "只显示情报未达 25% 的配方（击败敌形/分析仪烧缴获卡可积累情报）"
	if evolve_button:
		evolve_button.text = "制造一张"
		evolve_button.tooltip_text = "扣除资源后按品质概率池掷出稀有度，生成一张全新的该卡（不重置任何已有卡）"
	if power_label:
		power_label.tooltip_text = "纳米材料：战斗/日常产出，制造主要消耗"
	if enhance_label:
		enhance_label.tooltip_text = "能量块：基地运转与制造消耗"
	if mods_label:
		mods_label.tooltip_text = "合金：冷战时代起制造消耗的高级材料"
	if status_line_label:
		status_line_label.tooltip_text = "晶体：近未来时代制造消耗的稀缺材料"

	# 9 项统计 tooltip（沿用旧面板文案）
	var stat_tips := {
		stat_hp: "耐久（HP）：归零即被摧毁",
		stat_attack_light: "对轻装目标（步兵等）的攻击伤害",
		stat_attack_armor: "对装甲目标（坦克等）的攻击伤害",
		stat_attack_air: "对空中目标的攻击伤害",
		stat_defense_light: "对轻装攻击的防御减免",
		stat_defense_armor: "对装甲攻击的防御减免",
		stat_defense_air: "对空中攻击的防御减免",
		stat_range: "射程：单位开始攻击的距离",
		stat_speed: "攻击速度：主武器每秒攻击次数",
	}
	for lbl in stat_tips:
		if lbl:
			lbl.tooltip_text = stat_tips[lbl]

	_apply_title_fonts()
	_update_chip_styles()
	_build_mode_switch()

	if evolve_button:
		evolve_button.pressed.connect(_on_manufacture_pressed)

	if _embedded_mode:
		_apply_embedded_layout()

	# v27.12 性能：隐藏期间置脏的配方目录在恢复可见时统一补刷
	if not visibility_changed.is_connected(_on_visibility_refresh):
		visibility_changed.connect(_on_visibility_refresh)

## v8.x 性能：外部打开面板时调用（main.gd._open_overlay 分发，拆帧避尖峰）
func on_overlay_opened() -> void:
	if _embedded_mode:
		return
	if _open_refresh_inflight:
		return
	_open_refresh_inflight = true
	call_deferred("_run_open_refresh_pipeline")

func _run_open_refresh_pipeline() -> void:
	if not is_visible_in_tree():
		_open_refresh_inflight = false
		return
	await get_tree().process_frame
	if not is_visible_in_tree():
		_open_refresh_inflight = false
		return
	_refresh_all()
	_open_refresh_inflight = false


## v27.12 性能：恢复可见时补刷隐藏期间置脏的配方目录
func _on_visibility_refresh() -> void:
	if is_visible_in_tree() and _recipe_list_dirty:
		_refresh_recipe_list()

## ───────────────────────── 外部接口（兼容保留） ─────────────────────────

## 嵌入模式：card_info_panel TabEvolve 注入当前卡
func set_selected_card(card: CardResource) -> void:
	selected_card = card
	selected_recipe_id = ""
	# 嵌入上下文是"当前卡怎么进化/制造"——强制回兵种卡模式（模式切换按钮在嵌入布局里不可见）
	if _craft_mode != MODE_CARD:
		_craft_mode = MODE_CARD
		_selected_mod_id = ""
		_update_mode_button_styles()
		_update_title_sub()
	if card != null and _mgr() != null and _mgr().is_manufacturable(card.card_id):
		selected_recipe_id = card.card_id
	_refresh_resource_bar()
	_update_recipe_detail()

## 内嵌模式：隐藏标题/资源栏/左栏
func set_embedded_mode(p_embedded: bool) -> void:
	_embedded_mode = p_embedded
	if is_inside_tree():
		_apply_embedded_layout()

func show_panel() -> void:
	visible = true
	if not _embedded_mode:
		_refresh_all()

func _on_close() -> void:
	closed.emit()

## v9.x: 返回成长面板首页
func _on_back_to_growth() -> void:
	closed.emit()
	var main = get_node_or_null("/root/Main")
	if main and main.has_method("_toggle_overlay"):
		var overlay = main._overlay_for_panel_key("growth") if main.has_method("_overlay_for_panel_key") else null
		if overlay:
			main._toggle_overlay(overlay, "growth")

func _apply_embedded_layout() -> void:
	var title_row = get_node_or_null("VBoxContainer/TitleRow")
	if title_row:
		title_row.visible = false
	if left_panel:
		left_panel.visible = false
	var resource_bar = get_node_or_null("VBoxContainer/ResourceBar")
	if resource_bar:
		resource_bar.visible = false
	custom_minimum_size = Vector2.ZERO

## ───────────────────────── 内部工具 ─────────────────────────

func _mgr() -> Node:
	ManagerLazyLoader.ensure_loaded("manufacture")
	return ManagerLazyLoader.get_manager("manufacture")

func _era_name(era: int) -> String:
	return ERA_NAMES[clampi(era, 0, ERA_NAMES.size() - 1)]

## v6.19.4 复活右栏死区：五分节 + 卡面预览的显隐唯一口。
## 纪律：任何写入右栏内容的分支必须显式亮起要展示的分节；
## 无选择/无内容分支保持隐藏（tscn 默认隐藏=无选择初态）。
func _set_detail_sections_visible(v: bool) -> void:
	for p in [target_name_panel, info_panel, requirements_panel, stats_panel,
			resource_panel, preview_panel]:
		if p:
			p.visible = v

## 卡面预览：UiAssetLoader 全回退链（缩略 384 档足够 ~150px 预览）；无图整块隐藏
func _refresh_card_preview(card: CardResource) -> void:
	if preview_panel == null:
		return
	var tex: Texture2D = UiAssetLoader.card_icon_for_list(card) if card != null else null
	if preview_texture:
		preview_texture.texture = tex
	preview_panel.visible = tex != null

func _apply_title_fonts() -> void:
	var title_label = get_node_or_null("%TitleLabel")
	if title_label:
		title_label.add_theme_font_override("font", DT.get_title_font_bold())
	if target_name_label:
		target_name_label.add_theme_font_override("font", DT.get_title_font_bold())
	if evolve_button:
		evolve_button.add_theme_font_override("font", DT.get_title_font())
	for stat in [stat_hp, stat_attack_light, stat_attack_armor, stat_attack_air,
			stat_defense_light, stat_defense_armor, stat_defense_air, stat_range, stat_speed]:
		if stat:
			stat.add_theme_font_override("font", DT.get_body_font())

## 统一 toggle-chip 四态（筛选 chip 与模式切换共用；选中=紫描边亮字，未选=灰）
## v26.16 视觉批次：原先筛选 chip / 模式按钮两处手写样式仅 padding/hover 微差，收敛为一个 helper
func _style_toggle_chip(btn: Button, selected: bool) -> void:
	if btn == null:
		return
	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(3)
	sb.set_border_width_all(1)
	sb.content_margin_left = 8
	sb.content_margin_top = 3
	sb.content_margin_right = 8
	sb.content_margin_bottom = 3
	if selected:
		sb.bg_color = Color(DT.COLOR_VIOLET.r, DT.COLOR_VIOLET.g, DT.COLOR_VIOLET.b, 0.14)
		sb.border_color = DT.COLOR_VIOLET
		btn.add_theme_color_override("font_color", DT.COLOR_VIOLET_SOFT)
	else:
		sb.bg_color = Color(0.075, 0.102, 0.165, 0.5)
		sb.border_color = DT.COLOR_BORDER
		btn.add_theme_color_override("font_color", DT.COLOR_TEXT_DIM)
	btn.add_theme_stylebox_override("normal", sb)
	var sb_h := sb.duplicate() as StyleBoxFlat
	sb_h.bg_color = Color(DT.COLOR_VIOLET.r, DT.COLOR_VIOLET.g, DT.COLOR_VIOLET.b, 0.2 if selected else 0.08)
	btn.add_theme_stylebox_override("hover", sb_h)
	var sb_p := sb.duplicate() as StyleBoxFlat
	sb_p.bg_color = Color(DT.COLOR_VIOLET.r, DT.COLOR_VIOLET.g, DT.COLOR_VIOLET.b, 0.2)
	btn.add_theme_stylebox_override("pressed", sb_p)

func _update_chip_styles() -> void:
	var chips := {FILTER_ALL: chip_all, FILTER_OK: chip_evo, FILTER_LOCKED: chip_final}
	for mode in chips:
		_style_toggle_chip(chips[mode], mode == _filter_mode)

func _on_filter_pressed(mode: String) -> void:
	_filter_mode = mode
	_update_chip_styles()
	_refresh_recipe_list()

## ───────────────────────── 双模式切换（v26.x 改造图纸补给） ─────────────────────────

## 运行期往 TitleHBox 注入"兵种卡 / 改造图纸"切换（.tscn 不动）。
## 嵌入模式标题行隐藏，切换随之不可见（卡上下文只造卡，set_selected_card 会强制回卡模式）。
func _build_mode_switch() -> void:
	var title_hbox = get_node_or_null("VBoxContainer/TitleRow/TitleHBox")
	if title_hbox == null or not (title_hbox is HBoxContainer):
		return
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 4)
	_mode_btn_card = _make_mode_button("兵种卡", "制造兵种卡：情报 × 资源 → 按品质池掷出新卡")
	_mode_btn_mod = _make_mode_button("改造图纸", "补给改造图纸：得到过即可补给（安装改造时每张卡消耗 1 张图纸）")
	_mode_btn_card.pressed.connect(_set_craft_mode.bind(MODE_CARD))
	_mode_btn_mod.pressed.connect(_set_craft_mode.bind(MODE_MOD))
	hbox.add_child(_mode_btn_card)
	hbox.add_child(_mode_btn_mod)
	(title_hbox as HBoxContainer).add_child(hbox)
	_update_mode_button_styles()

func _make_mode_button(text: String, tip: String) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.tooltip_text = tip
	btn.add_theme_font_size_override("font_size", DT.FONT_SIZE_SMALL)
	return btn

func _set_craft_mode(mode: String) -> void:
	if _craft_mode == mode:
		return
	_craft_mode = mode
	_selected_mod_id = ""
	selected_recipe_id = ""
	if SignalBus and SignalBus.has_signal("play_sound"):
		SignalBus.play_sound.emit("button")
	_update_mode_button_styles()
	_update_title_sub()
	if evolve_button:
		evolve_button.text = "制造一张" if mode == MODE_CARD else "补给一张"
	_refresh_recipe_list()
	_update_recipe_detail()

func _update_mode_button_styles() -> void:
	var btns := {MODE_CARD: _mode_btn_card, MODE_MOD: _mode_btn_mod}
	for mode in btns:
		_style_toggle_chip(btns[mode], mode == _craft_mode)

func _update_title_sub() -> void:
	var title_sub = get_node_or_null("VBoxContainer/TitleRow/TitleHBox/TitleSub")
	if title_sub:
		title_sub.text = "情报 × 资源 → 兵种卡" if _craft_mode == MODE_CARD else "补给已获得的改造图纸"

## ───────────────────────── 刷新链 ─────────────────────────

func _refresh_all() -> void:
	_refresh_resource_bar()
	_refresh_recipe_list()

## 资源栏：四资源实时存量 + 工坊折扣
func _refresh_resource_bar() -> void:
	var labels := {"power": power_label, "energy": enhance_label, "alloy": mods_label, "crystal": status_line_label}
	for slot in RES_SLOTS:
		var lbl: Label = labels[String(slot["label_ref"])]
		if lbl == null:
			continue
		var total: int = BasicResourceManager.get_total(String(slot["id"]))
		lbl.text = "%s %d" % [slot["name"], total]
	if meta_label:
		var mgr: Node = _mgr()
		var disc_text := "—"
		if mgr != null:
			var cost_ref: Dictionary = mgr.get_cost("ww1_mp18")
			var base: Dictionary = mgr.get_base_cost("ww1_mp18")
			if not base.is_empty() and not cost_ref.is_empty():
				var bn: int = int(base.get("nano_materials", 0))
				var cn: int = int(cost_ref.get("nano_materials", 0))
				if bn > 0:
					disc_text = "工坊折扣 %d%%" % int(round(float(cn) / float(bn) * 100.0))
		meta_label.text = disc_text

## 配方目录（左栏）
func _refresh_recipe_list() -> void:
	if card_list_container == null:
		return
	# v27.12 性能：面板不可见时只置脏不重建（筛选/选中/制造回调可能穿透到隐藏态），恢复可见时补刷
	if not is_visible_in_tree():
		_recipe_list_dirty = true
		return
	_recipe_list_dirty = false
	var mgr: Node = _mgr()
	if mgr == null:
		return
	for child in card_list_container.get_children():
		child.queue_free()
	if _craft_mode == MODE_MOD:
		_refresh_mod_recipe_list(mgr)
		return
	var recipes: Array = mgr.get_recipe_ids()
	var shown := 0
	for rid in recipes:
		var card: CardResource = DefaultCards.get_card_by_id(String(rid))
		if card == null:
			continue
		# v32.3 E2：0 情报行不再隐藏——改为锁定行"？？？+情报数"（实机验收：玩家要
		# 看得到目标与差距；解锁后行内显示战力/属性）
		var tier: int = mgr.get_pool_tier(String(rid))
		if _filter_mode == FILTER_OK and not bool(mgr.can_manufacture(String(rid)).get("ok", false)):
			continue
		if _filter_mode == FILTER_LOCKED and tier >= 1:
			continue
		card_list_container.add_child(_create_recipe_row(String(rid), card))
		shown += 1
	if col_head_count:
		col_head_count.text = "%d / %d" % [shown, recipes.size()]
	# 默认选中第一个可见配方
	if shown > 0 and selected_recipe_id.is_empty():
		for child in card_list_container.get_children():
			if child is Button and child.has_meta("recipe_id"):
				_on_recipe_selected(String(child.get_meta("recipe_id")))
				break

func _create_recipe_row(card_id: String, card: CardResource) -> Button:
	var tier: int = _mgr().get_pool_tier(card_id)
	var selected := card_id == selected_recipe_id
	var row := Button.new()
	row.set_meta("recipe_id", card_id)
	_apply_list_row_style(row, selected)
	row.custom_minimum_size = Vector2(0, 48)
	row.tooltip_text = "点击查看配方详情与品质概率"
	row.pressed.connect(_on_recipe_selected.bind(card_id))

	# v26.16 视觉批次：缩略卡图 + 两行信息（对齐改造面板的列表缩略语言）
	var hbox := HBoxContainer.new()
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_theme_constant_override("separation", 8)
	hbox.add_child(_make_card_thumb(card))
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info.add_theme_constant_override("separation", 1)
	var name_lbl := Label.new()
	var meta_lbl := Label.new()
	# v32.3 E2：行信息按情报状态分流（实机验收："一战 · 直入目录"零信息量；玩家要看
	# 战力/属性，未解锁显示问号+情报数）
	var intel_pct := 0
	var mgr_ref: Node = _mgr()
	if mgr_ref != null and not mgr_ref.is_direct_pool_card(card_id):
		intel_pct = int(round(mgr_ref.get_intel_base(card_id) * 100.0))
	if tier == 0:
		# 情报未达 25%（含 0）：名字问号遮罩 + 情报数与解锁门槛
		name_lbl.text = "？？？"
		meta_lbl.text = "情报 %d%%（25%% 解锁配方）" % intel_pct
		row.tooltip_text = "情报不足 25%：击败该敌形提升情报，解锁配方与属性查看"
	else:
		name_lbl.text = card.display_name
		meta_lbl.text = "战力 %d · HP %d · 攻 %d/%d/%d" % [
			int(card.power), int(card.base_hp),
			int(card.attack_light), int(card.attack_armor), int(card.attack_air)]
		row.tooltip_text = "战力为白板基准（不含养成）；点击查看配方详情与品质概率"
		if mgr_ref != null and mgr_ref.is_direct_pool_card(card_id):
			row.tooltip_text = "直入目录卡：无需情报门，制造即得白板\n" + row.tooltip_text
	name_lbl.add_theme_font_override("font", DT.get_title_font())
	name_lbl.add_theme_font_size_override("font_size", DT.FONT_SIZE_SMALL)
	# 旧语义保留：品质池未开放（tier 0）整行降为暗色
	name_lbl.add_theme_color_override("font_color",
		DT.COLOR_TEXT if selected else (DT.COLOR_TEXT_DIM if tier == 0 else Color(0.85, 0.88, 0.94, 1)))
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info.add_child(name_lbl)
	meta_lbl.add_theme_font_size_override("font_size", DT.FONT_SIZE_SMALL)
	meta_lbl.add_theme_color_override("font_color", DT.COLOR_SLATE_DIM_A85)
	meta_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info.add_child(meta_lbl)
	hbox.add_child(info)
	row.add_child(hbox)
	return row

## 列表缩略卡图（40×44，兵种色边框；无图回退兵种 glyph——与 modification_panel 同款）
func _make_card_thumb(card: CardResource) -> PanelContainer:
	var thumb := PanelContainer.new()
	thumb.custom_minimum_size = Vector2(40, 44)
	thumb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	# 按钮内嵌图块必须 IGNORE：PanelContainer 默认 STOP 会吃掉整行点击（死区）
	thumb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = DT.COLOR_SLOT_LOCKED
	sb.border_color = DT.get_kind_color(card.combat_kind)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(3)
	thumb.add_theme_stylebox_override("panel", sb)
	var tex: Texture2D = UiAssetLoader.card_icon_for_list(card)
	if tex != null:
		var icon := TextureRect.new()
		icon.texture = tex
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.size_flags_horizontal = Control.SIZE_FILL
		icon.size_flags_vertical = Control.SIZE_FILL
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		thumb.add_child(icon)
	else:
		var glyph := Label.new()
		glyph.text = _kind_glyph(card.combat_kind)
		glyph.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		glyph.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		glyph.add_theme_font_size_override("font_size", DT.FONT_SIZE_MEDIUM)
		glyph.add_theme_color_override("font_color", Color(1, 1, 1, 0.55))
		glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
		thumb.add_child(glyph)
	return thumb

func _kind_glyph(combat_kind: int) -> String:
	match combat_kind:
		0: return "⚔"
		1: return "◈"
		2: return "◎"
		3: return "✈"
		4: return "■"
		_: return "⚔"

func _on_recipe_selected(card_id: String) -> void:
	selected_recipe_id = card_id
	if SignalBus and SignalBus.has_signal("play_sound"):
		SignalBus.play_sound.emit("button")
	_refresh_recipe_list()
	_update_recipe_detail()

## ───────────────────────── 改造图纸模式（v26.x 消耗品化） ─────────────────────────

## 左栏：随机补给箱置顶 + 定向兑换目录（见过集合 ∩ 普通/优秀/稀有）。
## chip 复用：全部 / 可补给（资源达标）/ 库存 0（待补货）。
func _refresh_mod_recipe_list(mgr: Node) -> void:
	var shown := 0
	var pool_size: int = mgr.get_mod_box_pool().size()
	card_list_container.add_child(_make_mod_box_row(pool_size))
	shown += 1
	var recipes: Array = mgr.get_mod_direct_recipes()
	for entry in recipes:
		var mod_id := String(entry.get("mod_id", ""))
		if _filter_mode == FILTER_OK and not bool(mgr.can_craft_mod_direct(mod_id).get("ok", false)):
			continue
		if _filter_mode == FILTER_LOCKED and int(entry.get("stock", 0)) > 0:
			continue
		card_list_container.add_child(_make_mod_recipe_row(entry))
		shown += 1
	if col_head_count:
		# v26.16 修复：原显示 total/total，筛选后计数永远不变；改为 shown（含随机箱行）/ 总数
		col_head_count.text = "%d / %d" % [shown, recipes.size() + 1]
	# 默认选中随机补给箱（哨兵常量非空，选中后 is_empty 为 false——递归终止）
	if _selected_mod_id.is_empty() and shown > 0:
		_on_mod_selected(MOD_BOX_SEL)

func _apply_list_row_style(row: Button, selected: bool) -> void:
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.alignment = HORIZONTAL_ALIGNMENT_LEFT
	row.custom_minimum_size = Vector2(0, 34)
	row.add_theme_font_size_override("font_size", DT.FONT_SIZE_SMALL)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.075, 0.102, 0.165, 0.5)
	sb.set_corner_radius_all(3)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	if selected:
		sb.border_width_left = 2
		sb.border_color = DT.COLOR_VIOLET
	row.add_theme_stylebox_override("normal", sb)
	var sb_h := sb.duplicate() as StyleBoxFlat
	sb_h.bg_color = Color(0.653, 0.546, 0.98, 0.08)
	row.add_theme_stylebox_override("hover", sb_h)
	row.add_theme_stylebox_override("pressed", sb)

func _make_mod_box_row(pool_size: int) -> Button:
	var row := Button.new()
	row.set_meta("mod_box", true)
	_apply_list_row_style(row, _selected_mod_id == MOD_BOX_SEL)
	row.custom_minimum_size = Vector2(0, 44)
	row.tooltip_text = "从已获得的史诗+改造图纸中按稀有度加权随机补给一张（传说+有暗保底）"
	row.pressed.connect(_on_mod_selected.bind(MOD_BOX_SEL))
	var hbox := HBoxContainer.new()
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_theme_constant_override("separation", 8)
	hbox.add_child(_make_box_thumb())
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info.add_theme_constant_override("separation", 1)
	var name_lbl := Label.new()
	name_lbl.text = "随机补给箱"
	name_lbl.add_theme_font_override("font", DT.get_title_font())
	name_lbl.add_theme_font_size_override("font_size", DT.FONT_SIZE_SMALL)
	name_lbl.add_theme_color_override("font_color", DT.COLOR_VIOLET_SOFT)
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info.add_child(name_lbl)
	var meta_lbl := Label.new()
	meta_lbl.text = "史诗+ · 图鉴 %d 种" % pool_size
	meta_lbl.add_theme_font_size_override("font_size", DT.FONT_SIZE_SMALL)
	meta_lbl.add_theme_color_override("font_color", DT.COLOR_SLATE_DIM_A85)
	meta_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info.add_child(meta_lbl)
	hbox.add_child(info)
	row.add_child(hbox)
	return row

## 随机箱缩略块（26×26 紫框 + 号，补给语义）
func _make_box_thumb() -> Control:
	var ph := PanelContainer.new()
	ph.custom_minimum_size = Vector2(26, 26)
	ph.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ph.mouse_filter = Control.MOUSE_FILTER_IGNORE  # 按钮内嵌图块：默认 STOP 会吃点击
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(DT.COLOR_VIOLET.r, DT.COLOR_VIOLET.g, DT.COLOR_VIOLET.b, 0.10)
	sb.border_color = DT.COLOR_VIOLET
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(3)
	ph.add_theme_stylebox_override("panel", sb)
	var lbl := Label.new()
	lbl.text = "+"
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_override("font", DT.get_title_font_bold())
	lbl.add_theme_font_size_override("font_size", DT.FONT_SIZE_MEDIUM)
	lbl.add_theme_color_override("font_color", DT.COLOR_VIOLET_SOFT)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ph.add_child(lbl)
	return ph

func _make_mod_recipe_row(entry: Dictionary) -> Button:
	var mod_id := String(entry.get("mod_id", ""))
	var rarity := String(entry.get("rarity", "common"))
	var stock := int(entry.get("stock", 0))
	var row := Button.new()
	row.set_meta("mod_id", mod_id)
	_apply_list_row_style(row, mod_id == _selected_mod_id)
	row.custom_minimum_size = Vector2(0, 44)
	row.tooltip_text = "定向兑换该改造图纸（消耗品：安装改造时每张卡消耗 1 张）"
	row.pressed.connect(_on_mod_selected.bind(mod_id))
	var hbox := HBoxContainer.new()
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_theme_constant_override("separation", 8)
	hbox.add_child(_make_mod_thumb(mod_id, rarity))
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info.add_theme_constant_override("separation", 1)
	var name_lbl := Label.new()
	name_lbl.text = String(entry.get("name", mod_id))
	name_lbl.add_theme_font_override("font", DT.get_title_font())
	name_lbl.add_theme_font_size_override("font_size", DT.FONT_SIZE_SMALL)
	# 名字按稀有度着色；库存耗尽整行降暗（旧灰显语义保留）
	name_lbl.add_theme_color_override("font_color",
		DT.COLOR_TEXT_DIM if stock <= 0 else GC.get_rarity_color(rarity))
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info.add_child(name_lbl)
	var meta_lbl := Label.new()
	meta_lbl.text = "%s · 库存×%d" % [GC.get_rarity_name(rarity), stock]
	meta_lbl.add_theme_font_size_override("font_size", DT.FONT_SIZE_SMALL)
	meta_lbl.add_theme_color_override("font_color", DT.COLOR_SLATE_DIM_A85)
	meta_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info.add_child(meta_lbl)
	hbox.add_child(info)
	row.add_child(hbox)
	return row

## 改造图纸缩略图标（26×26）——v37.1 收口到 ModIconTile 稀有度发光底座
## （原裸贴暗色贴图/字母框，与改造面板旧款同病；rarity 形参保留给调用方签名）
func _make_mod_thumb(mod_id: String, rarity: String) -> Control:
	return ModIconTileRef.make(ModificationRegistry.get_data(mod_id), 26)

func _on_mod_selected(mod_id: String) -> void:
	_selected_mod_id = mod_id
	if SignalBus and SignalBus.has_signal("play_sound"):
		SignalBus.play_sound.emit("button")
	_refresh_recipe_list()
	_update_recipe_detail()

func _update_mod_detail(mgr: Node) -> void:
	if mgr == null:
		return
	# 图纸无卡面/无单位属性：亮名/情报/条件/消耗四块，卡面预览与统计九格保持隐藏
	_set_detail_sections_visible(false)
	for p in [target_name_panel, info_panel, requirements_panel, resource_panel]:
		if p:
			p.visible = true
	if _selected_mod_id == MOD_BOX_SEL:
		_update_mod_box_detail(mgr)
	else:
		_update_mod_direct_detail(mgr, _selected_mod_id)

## 定向兑换详情（右栏条件 + 中栏改造说明）
func _update_mod_direct_detail(mgr: Node, mod_id: String) -> void:
	var mod_data: Dictionary = ModificationRegistry.get_data(mod_id)
	if mod_data.is_empty():
		return
	if no_selection_label:
		no_selection_label.visible = false
	if target_name_label:
		target_name_label.text = "%s 改造图纸（%s）" % [
			String(mod_data.get("name", mod_id)),
			GC.get_rarity_name(String(mod_data.get("rarity", "common")))]
	if info_details:
		info_details.text = "库存 ×%d\n消耗品：安装改造时每张卡消耗 1 张图纸" % mgr.get_mod_blueprint_stock(mod_id)
	_render_mod_conditions(mgr.can_craft_mod_direct(mod_id))
	# 中栏：改造说明
	_clear_pool_bars()
	if evolution_tree:
		var desc_lbl := Label.new()
		desc_lbl.text = String(mod_data.get("description", ""))
		desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc_lbl.add_theme_font_size_override("font_size", DT.FONT_SIZE_SMALL)
		desc_lbl.add_theme_color_override("font_color", DT.COLOR_TEXT_DIM)
		evolution_tree.add_child(desc_lbl)
		if path_head_count:
			path_head_count.text = "改造说明"
	_clear_template_stats()
	if resource_details:
		resource_details.text = ManufacturePools.cost_text(mgr.get_mod_direct_cost(mod_id))
	if evolve_button:
		evolve_button.text = "补给一张"
		evolve_button.disabled = not bool(mgr.can_craft_mod_direct(mod_id).get("ok", false))

## 随机箱详情（右栏条件 + 中栏出率池条）
func _update_mod_box_detail(mgr: Node) -> void:
	if no_selection_label:
		no_selection_label.visible = false
	if target_name_label:
		target_name_label.text = "随机补给箱（史诗+）"
	var pity: int = mgr.get_mod_box_pity()
	if info_details:
		var pool_size: int = mgr.get_mod_box_pool().size()
		var desc := "图鉴 %d 种可补给——掉落负责发现，制造负责补给" % pool_size
		# v6.19 P1-T1.1 概率可见化：保底口径唯一文案源在 ModManufacture（数值读常量）
		desc += "\n%s" % ModManufactureRef.describe_box_pity(pity)
		info_details.text = desc
	_render_mod_conditions(mgr.can_craft_mod_random())
	# 中栏：稀有度出率池条
	_clear_pool_bars()
	if evolution_tree:
		# v6.19 P1-T1.1 概率可见化：随机箱保底进度行放中栏可见区顶（右栏 InfoPanel 死隐藏，同卡牌模式）
		var box_pity_lbl := Label.new()
		box_pity_lbl.text = ModManufactureRef.describe_box_pity(pity)
		box_pity_lbl.add_theme_font_size_override("font_size", DT.FONT_SIZE_SMALL)
		box_pity_lbl.add_theme_color_override("font_color", DT.COLOR_GOLD)
		box_pity_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box_pity_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		evolution_tree.add_child(box_pity_lbl)
		var odds: Array = mgr.get_mod_box_odds()
		if path_head_count:
			path_head_count.text = "%d 档" % odds.size()
		if odds.is_empty():
			var lbl := Label.new()
			lbl.text = "图鉴中尚无史诗+改造图纸——先经战斗掉落获得"
			lbl.add_theme_font_size_override("font_size", DT.FONT_SIZE_SMALL)
			lbl.add_theme_color_override("font_color", DT.COLOR_TEXT_DIM)
			evolution_tree.add_child(lbl)
		else:
			for e in odds:
				evolution_tree.add_child(_make_pool_bar(String(e.get("r", "")), float(e.get("pct", 0.0))))
	_clear_template_stats()
	if resource_details:
		resource_details.text = ManufacturePools.cost_text(mgr.get_mod_box_cost())
	if evolve_button:
		evolve_button.text = "开一次箱"
		evolve_button.disabled = not bool(mgr.can_craft_mod_random().get("ok", false))
	# v32.0 B3-S2 UI: 晶体垫保底（占位 80/次）——兄弟节点挂 evolve_button 后，防重复构建
	if evolve_button != null and mgr.has_method("advance_mod_box_pity_with_crystals"):
		var pity_parent: Node = evolve_button.get_parent()
		if pity_parent != null and pity_parent.get_node_or_null("PityAdvanceBtn") == null:
			var pity_btn := Button.new()
			pity_btn.name = "PityAdvanceBtn"
			pity_btn.text = "晶体垫保底（%d/次）" % mgr.CRYSTAL_PER_PITY
			pity_btn.add_theme_font_size_override("font_size", DT.FONT_SIZE_SMALL)
			# v6.19 P1-T1.1 概率可见化：tooltip 数值读常量 + 保底口径同源（宪法 C3）；
			# v6.19.1 封顶后补"垫至激活线前"语义
			pity_btn.tooltip_text = "每 %d 晶体推进保底计数 1 次（垫至激活线前封顶，不直接给保底）%s%s" % [
				mgr.CRYSTAL_PER_PITY, String.chr(10), ModManufactureRef.describe_box_pity(pity)]
			pity_btn.pressed.connect(func():
				var r: Dictionary = mgr.advance_mod_box_pity_with_crystals(1)
				if bool(r.get("ok", false)):
					SignalBus.show_toast.emit("暗保底推进 +%d（晶体 -%d），当前连续 %d 次" % [int(r.get("advanced", 1)), int(r.get("crystal_spent", 0)), int(r.get("pity", 0))])
				else:
					SignalBus.show_toast.emit(String(r.get("reason", "垫付失败"))))
			pity_parent.add_child(pity_btn)

## 条件行渲染（seen/zone/pool/resources 四键，复用卡牌制造的条件行样式）
func _render_mod_conditions(check: Dictionary) -> void:
	if req_list == null:
		return
	for child in req_list.get_children():
		child.queue_free()
	for cond in check.get("conditions", []):
		if not cond is Dictionary:
			continue
		var met := bool(cond.get("met", false))
		var text := ""
		match String(cond.get("key", "")):
			"seen":
				text = "制造资格：%s（得到过才可补给）" % cond.get("current_text", "?")
			"zone":
				text = "兑换区：%s（需 普通/优秀/稀有）" % cond.get("current_text", "?")
			"pool":
				text = "图鉴史诗+图纸：%s（需 %s）" % [cond.get("current_text", "?"), cond.get("required_text", "?")]
			"resources":
				text = "资源（需 %s）：%s" % [cond.get("required_text", "?"), cond.get("current_text", "?")]
		req_list.add_child(_make_cond_row("✔" if met else "✘",
			DT.COLOR_GREEN_UP if met else DT.COLOR_RED_DOWN, text))

## 图纸无单位属性——统计九格清空为占位
func _clear_template_stats() -> void:
	for lbl in [stat_hp, stat_attack_light, stat_attack_armor, stat_attack_air,
			stat_defense_light, stat_defense_armor, stat_defense_air, stat_range, stat_speed]:
		if lbl:
			lbl.text = "—"

## ───────────────────────── 配方详情（右栏 + 中栏品质池） ─────────────────────────

func _update_recipe_detail() -> void:
	var mgr: Node = _mgr()
	if _craft_mode == MODE_MOD:
		_update_mod_detail(mgr)
		return
	# 无选择 / 面板未就绪
	if mgr == null or selected_recipe_id.is_empty():
		_set_detail_sections_visible(false)
		if no_selection_label:
			no_selection_label.visible = true
		if target_name_label:
			target_name_label.text = ""
		if info_details:
			info_details.text = ""
		if resource_details:
			resource_details.text = ""
		if evolve_button:
			evolve_button.disabled = true
		_clear_pool_bars()
		return
	if no_selection_label:
		no_selection_label.visible = false
	# 正常路径：右栏五分节 + 卡面预览全部亮起（v6.19.4 复活死区）
	_set_detail_sections_visible(true)

	var card_id := selected_recipe_id
	var card: CardResource = DefaultCards.get_card_by_id(card_id)
	if card == null:
		return

	# 嵌入模式注入的卡若不可制造（selected_card 与配方不一致时兜底）
	if not mgr.is_manufacturable(card_id):
		# 本分支只写名/情报两块：条件行已清空、属性/消耗是陈旧内容，保持隐藏
		_set_detail_sections_visible(false)
		if target_name_panel:
			target_name_panel.visible = true
		if info_panel:
			info_panel.visible = true
		_refresh_card_preview(card)
		if target_name_label:
			target_name_label.text = card.display_name
		if info_details:
			info_details.text = "该卡种无敌形原型，无法制造。\n仅可通过掉落 / 势力 / 商店渠道获取。"
		if req_list:
			for child in req_list.get_children():
				child.queue_free()
		if evolve_button:
			evolve_button.disabled = true
		_clear_pool_bars()
		return

	if target_name_label:
		target_name_label.text = "%s（%s）" % [card.display_name, _era_name(card.era)]

	# 情报说明（v6.14：直入卡显示免情报语义，不再展示"情报 0%"）
	var base_pct := int(round(mgr.get_intel_base(card_id) * 100.0))
	var pity: int = mgr.get_pity(card_id)
	if info_details:
		var desc := ""
		if mgr.is_direct_pool_card(card_id):
			desc = "直接入目录（免情报门，白板品质起步）"
		else:
			desc = "情报 %d%%（击败敌形 / 分析仪烧缴获卡 / 获取缴获卡积累）" % base_pct
		# v6.19 P1-T1.1 概率可见化：保底口径唯一文案源在 ManufacturePools（数值读常量）
		desc += "\n%s" % ManufacturePools.describe_card_pity(pity)
		info_details.text = desc

	# 条件行
	if req_list:
		for child in req_list.get_children():
			child.queue_free()
		var check: Dictionary = mgr.can_manufacture(card_id)
		for cond in check.get("conditions", []):
			if not cond is Dictionary:
				continue
			var met := bool(cond.get("met", false))
			var text := ""
			match String(cond.get("key", "")):
				"intel":
					if mgr.is_direct_pool_card(card_id):
						text = "情报门：直接入目录（免情报，白板起步）"
					else:
						text = "情报 %s（需 %s）" % [cond.get("current_text", "?"), cond.get("required_text", "?")]
				"skill_tree_era":
					text = "技能树制造授权：%s" % cond.get("current_text", "?")
				"resources":
					text = "资源（需 %s）：%s" % [cond.get("required_text", "?"), cond.get("current_text", "?")]
			req_list.add_child(_make_cond_row("✔" if met else "✘",
				DT.COLOR_GREEN_UP if met else DT.COLOR_RED_DOWN, text))

	# 卡面预览（复活右栏后新增：制造前看得到要造的卡）
	_refresh_card_preview(card)

	# 模板属性（制造出的新卡以此为基础）
	_fill_template_stats(card)

	# 消耗
	if resource_details:
		var cost: Dictionary = mgr.get_cost(card_id)
		var lines: PackedStringArray = []
		for rid in cost:
			var nm: String = String(ManufacturePools.RESOURCE_NAMES.get(String(rid), String(rid)))
			lines.append("%s ×%d（现有 %d）" % [nm, int(cost[rid]), BasicResourceManager.get_total(String(rid))])
		resource_details.text = "\n".join(lines)

	# 品质池（中栏）
	_rebuild_pool_bars(mgr, card_id)

	# 按钮可用性
	if evolve_button:
		evolve_button.disabled = not bool(mgr.can_manufacture(card_id).get("ok", false))

func _make_cond_row(status_text: String, status_col: Color, text: String) -> PanelContainer:
	var row := PanelContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.075, 0.102, 0.165, 0.5)
	sb.border_width_left = 2
	sb.border_color = status_col
	sb.set_corner_radius_all(3)
	sb.content_margin_left = 8
	sb.content_margin_top = 4
	sb.content_margin_right = 8
	sb.content_margin_bottom = 4
	row.add_theme_stylebox_override("panel", sb)
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 6)
	var tag := Label.new()
	tag.text = status_text
	tag.add_theme_font_size_override("font_size", DT.FONT_SIZE_SMALL)
	tag.add_theme_color_override("font_color", status_col)
	tag.custom_minimum_size = Vector2(28, 0)
	hbox.add_child(tag)
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", DT.FONT_SIZE_SMALL)
	lbl.add_theme_color_override("font_color", Color(0.9, 0.92, 0.96, 1))
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(lbl)
	row.add_child(hbox)
	return row

func _fill_template_stats(card: CardResource) -> void:
	if stat_hp:
		stat_hp.text = "耐久 %d" % int(card.base_hp)
	if stat_attack_light:
		stat_attack_light.text = "攻轻 %d" % int(card.attack_light)
	if stat_attack_armor:
		stat_attack_armor.text = "攻甲 %d" % int(card.attack_armor)
	if stat_attack_air:
		stat_attack_air.text = "攻空 %d" % int(card.attack_air)
	if stat_defense_light:
		stat_defense_light.text = "防轻 %d" % int(card.defense_light)
	if stat_defense_armor:
		stat_defense_armor.text = "防甲 %d" % int(card.defense_armor)
	if stat_defense_air:
		stat_defense_air.text = "防空 %d" % int(card.defense_air)
	if stat_range:
		stat_range.text = "射程 %d" % int(card.range_value)
	if stat_speed:
		stat_speed.text = "攻速 %.2f/秒" % card.attack_light_speed

## 中栏：品质概率池横条（有效权重含暗保底，归一化）
func _rebuild_pool_bars(mgr: Node, card_id: String) -> void:
	_clear_pool_bars()
	if evolution_tree == null:
		return
	# v6.19 P1-T1.1 概率可见化：保底进度行放中栏可见区顶——右栏 InfoPanel 在 tscn 里
	# 默认隐藏且无显示路径（v6.19 探针实证死区），保底文案必须落在可见容器
	# v38.x N 条: 保底行套 320 限宽居中容器（与 _make_pool_bar 同式）——原 EXPAND_FILL
	# 占满中栏 600px，与 320 限宽的概率条形成"上宽下窄"断层（实机验收⑦）。
	# 文案仍唯一源 ManufacturePools.describe_card_pity（宪法 C3）。
	var pity_wrap := VBoxContainer.new()
	pity_wrap.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	pity_wrap.custom_minimum_size = Vector2(320.0, 0.0)
	var pity_lbl := Label.new()
	pity_lbl.text = ManufacturePools.describe_card_pity(mgr.get_pity(card_id))
	pity_lbl.add_theme_font_size_override("font_size", DT.FONT_SIZE_SMALL)
	pity_lbl.add_theme_color_override("font_color", DT.COLOR_GOLD)
	pity_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pity_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pity_wrap.add_child(pity_lbl)
	evolution_tree.add_child(pity_wrap)
	var pool: Array = mgr.get_effective_pool(card_id)
	if path_head_count:
		path_head_count.text = "%d 档" % pool.size()
	if pool.is_empty():
		var lbl := Label.new()
		lbl.text = "情报未达 25%——品质池未开放"
		lbl.add_theme_font_size_override("font_size", DT.FONT_SIZE_SMALL)
		lbl.add_theme_color_override("font_color", DT.COLOR_TEXT_DIM)
		evolution_tree.add_child(lbl)
		return
	var total := 0.0
	for e in pool:
		total += float(e["w"])
	for e in pool:
		var rarity := String(e["r"])
		var pct := float(e["w"]) / total
		evolution_tree.add_child(_make_pool_bar(rarity, pct))

func _make_pool_bar(rarity: String, pct: float) -> Control:
	var wrap := VBoxContainer.new()
	# v38.x N 条: 品质概率条限宽 320 + 居中——原 EXPAND_FILL 吃满中栏剩余宽（~660px），
	# "中间品质概率池太宽"主诉（实机验收⑨）。不挪 tscn 节点层级（宪法红线）。
	wrap.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	wrap.custom_minimum_size = Vector2(320.0, 0.0)
	var head := HBoxContainer.new()
	var name_lbl := Label.new()
	name_lbl.text = GC.get_rarity_name(rarity)
	name_lbl.add_theme_font_size_override("font_size", DT.FONT_SIZE_SMALL)
	name_lbl.add_theme_color_override("font_color", GC.get_rarity_color(rarity))
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(name_lbl)
	var pct_lbl := Label.new()
	pct_lbl.text = "%d%%" % int(round(pct * 100.0))
	pct_lbl.add_theme_font_size_override("font_size", DT.FONT_SIZE_SMALL)
	pct_lbl.add_theme_color_override("font_color", DT.COLOR_TEXT_DIM)
	head.add_child(pct_lbl)
	wrap.add_child(head)
	var bar := ProgressBar.new()
	bar.min_value = 0.0
	bar.max_value = 100.0
	bar.value = pct * 100.0
	bar.custom_minimum_size = Vector2(0, 8)
	bar.show_percentage = false
	var bg_sb := StyleBoxFlat.new()
	bg_sb.bg_color = Color(0.03, 0.06, 0.11, 0.9)
	bg_sb.set_corner_radius_all(3)
	bar.add_theme_stylebox_override("background", bg_sb)
	var fill_sb := StyleBoxFlat.new()
	fill_sb.bg_color = GC.get_rarity_color(rarity)
	fill_sb.set_corner_radius_all(3)
	bar.add_theme_stylebox_override("fill", fill_sb)
	wrap.add_child(bar)
	return wrap

func _clear_pool_bars() -> void:
	if evolution_tree == null:
		return
	for child in evolution_tree.get_children():
		child.queue_free()
	if path_head_count:
		path_head_count.text = ""

func _show_result(text: String, is_ok: bool) -> void:
	if result_label == null:
		return
	result_label.text = text
	result_label.add_theme_color_override("font_color",
		DT.COLOR_GREEN_UP if is_ok else DT.COLOR_RED_DOWN)

## ───────────────────────── 制造 ─────────────────────────

func _on_manufacture_pressed() -> void:
	var mgr: Node = _mgr()
	if _craft_mode == MODE_MOD:
		_on_mod_craft_pressed(mgr)
		return
	if mgr == null or selected_recipe_id.is_empty():
		return
	var card: CardResource = DefaultCards.get_card_by_id(selected_recipe_id)
	var result: Dictionary = mgr.manufacture(selected_recipe_id)
	if bool(result.get("ok", false)):
		var rarity := String(result.get("rarity", ""))
		_show_result("✔ 制造成功：%s（%s）" % [card.display_name if card else selected_recipe_id, GC.get_rarity_name(rarity)], true)
		# v26.16 反馈链：新卡入包=全局事件，toast 播报 + card_place 音（原为 button）
		if SignalBus and SignalBus.has_signal("play_sound"):
			SignalBus.play_sound.emit("card_place")
		if SignalBus and SignalBus.has_signal("show_toast"):
			SignalBus.show_toast.emit("制造成功：%s（%s）" % [card.display_name if card else selected_recipe_id, GC.get_rarity_name(rarity)])
	else:
		_show_result("✘ 制造失败：%s" % String(result.get("reason_zh", "条件未满足")), false)
		if SignalBus and SignalBus.has_signal("play_sound"):
			SignalBus.play_sound.emit("error")
	# 刷新资源/条件/品质池（暗保底变化）
	_refresh_resource_bar()
	_update_recipe_detail()

## 改造图纸补给/开箱（v26.x 消耗品化）
func _on_mod_craft_pressed(mgr: Node) -> void:
	if mgr == null:
		return
	var result: Dictionary
	if _selected_mod_id == MOD_BOX_SEL:
		result = mgr.craft_mod_blueprint_random()
	else:
		result = mgr.craft_mod_blueprint_direct(_selected_mod_id)
	if bool(result.get("ok", false)):
		var mod_data: Dictionary = ModificationRegistry.get_data(String(result.get("mod_id", "")))
		var rarity := String(result.get("rarity", mod_data.get("rarity", "")))
		var ok_msg := "✔ 补给成功：%s 改造图纸（%s）" % [
			String(mod_data.get("name", result.get("mod_id", "?"))), GC.get_rarity_name(rarity)]
		_show_result(ok_msg, true)
		# v26.16 反馈链：图纸入包=card_place 音 + toast（原为 button）
		if SignalBus and SignalBus.has_signal("play_sound"):
			SignalBus.play_sound.emit("card_place")
		if SignalBus and SignalBus.has_signal("show_toast"):
			SignalBus.show_toast.emit("补给成功：%s 改造图纸（%s）" % [
				String(mod_data.get("name", result.get("mod_id", "?"))), GC.get_rarity_name(rarity)])
	else:
		_show_result("✘ 补给失败：%s" % String(result.get("reason_zh", "条件未满足")), false)
		if SignalBus and SignalBus.has_signal("play_sound"):
			SignalBus.play_sound.emit("error")
	# 刷新资源/库存/条件（暗保底变化）
	_refresh_resource_bar()
	_refresh_recipe_list()
	_update_recipe_detail()
