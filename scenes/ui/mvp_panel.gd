extends Control
## v7.x 整合结算面板（MVP 战绩 + 缴获明细合并）
## v30.1 R3（设计审查 F-13）：单列长滚动拆三页签——战报（横幅/数据/协同/败因）、
## 缴获（经验/奖励/情报/战利品）、养成（基地状态默认折叠 + 二周目入口）。
##
## 战斗结束瞬间一次性弹出，展示完整结算：
##   战报页：战绩横幅（胜利/失败 + 时长 + 星级 + 核心数据 + 击杀分布）
##   缴获页：缴获明细（本关缴获 / 相位场经验 / 战斗缴获 / 相位仪缴获 / 情报揭示）
##
## 合并自原 mvp_panel + battle_result_dialog，消除"两次弹窗 + 切换动画"割裂感。
##
## 内容（团队 MVP，不做 per-unit——普通单位伤害走 CombatFeedback 直调不经过 SignalBus，无法准确采集）：
##   - 战绩横幅（胜利/失败 + 时长）
##   - 核心数据（击毁 X · 损失 Y · 伤害 Z）
##   - 击杀类型（前 3 类敌人，来自 BattleManager._defeated_enemies）
##   - 星级评定（★1~3，基于击杀比/损失比/时长）
##   - 缴获摘要（能量块/纳米材料/战斗卡）
##   - 相位场经验结算
##   - 战斗缴获列表（DropManager 待接收）
##   - 相位仪掉落（独立展示）
##   - 情报揭示（IntelHarvestDisplay + IntelRevealPopup）
##   - 关闭按钮 → 接收全部 + 返回准备界面
##
## 数据来源：BattleInfoDisplay.get_battle_stats() + BattleManager._defeated_enemies + GameManager.last_battle_reward_summary

const DT = preload("res://resources/design_tokens.gd")
const GC = preload("res://resources/game_constants.gd")   # v23.6.1 稀有度色单一源
const PanelStyles = preload("res://scripts/ui/panel_styles.gd")   # v23.6.1 按钮工厂
const DefaultCards = preload("res://data/default_cards.gd")
const FormatUtil = preload("res://scripts/ui/format_util.gd")
const BattleUnitRecord = preload("res://scripts/battle/battle_unit_record.gd")
const MobileBaseFacilities = preload("res://data/mobile_base_facilities.gd")   # v22.4 要塞反馈行
const EnemyPhaseMasters = preload("res://data/enemy_phase_masters.gd")   # 批次③ T2 败仗英雄名

signal result_confirmed(player_won: bool)

## ── 批次③ Task 2：结算战报体文案池（军语克制体，零数值虚构、零运营腔）──
## 胜利 4 句 / 失败 3 句 / 撤退 3 句，按结果态取池随机轮换。
const ComboTacticsRef = preload("res://data/combo_tactics.gd")   # v30 R3: 本局协同小结

## v30 R3：本局协同小结的检阅顺序（12 组合/套装 + 5 搭档，与 combo_status_strip 同源口径）
const _SYNERGY_COMBO_ORDER: Array[String] = [
	ComboTacticsRef.COMBO_INCENDIARY, ComboTacticsRef.COMBO_EMP, ComboTacticsRef.COMBO_NANO,
	ComboTacticsRef.COMBO_LASER, ComboTacticsRef.COMBO_RECON, ComboTacticsRef.COMBO_CHEM,
	ComboTacticsRef.COMBO_ARMOR_PHALANX, ComboTacticsRef.COMBO_FLAK_CURTAIN,
	ComboTacticsRef.COMBO_MEDIC_CHAIN, ComboTacticsRef.COMBO_SATURATION,
	ComboTacticsRef.COMBO_ENGINEER_LINE, ComboTacticsRef.COMBO_FORTRESS_HOLD,
]
const _SYNERGY_PAIR_ORDER: Array[String] = [
	"pair_recon_artillery", "pair_engineer_infantry", "pair_aa_air",
	"pair_armor_infantry", "pair_fort_support",
]

const BANNER_LINES_VICTORY: Array[String] = [
	"阵地拿下。车轮继续向前。",
	"这一仗打完了。下一处坐标已经标好。",
	"枪声停了。路还在。",
	"守住的就是阵地。继续开进。",
]
const BANNER_LINES_DEFEAT: Array[String] = [
	"阵地没守住。收拢队伍，清点损失。",
	"这一仗输了。输账记下，下次讨回。",
	"战线退了一步。人还在，就还有下一仗。",
]
const BANNER_LINES_RETREAT: Array[String] = [
	"车队脱离接触。装备点清，人员归位。",
	"今天不在这里打。会有更合适的地方。",
	"保存力量不是丢掉阵地，是把它记在账上。",
]
## 撤退标记：main.gd 撤退确认链写入，本面板一次性消费（防串到下一场败仗）
const META_RETREATED := "battle_retreated"
## 败仗低概率挂一位牺牲相位师名字（找同伴主旨；名册同 hero_archive 30 位）
const HERO_LINE_CHANCE := 0.25

## v22.4（P0-2）：从基地出击时，结算面板提供"返回基地"直达按钮
var _bunker_return_available := false
## v34 B1 再战回路：胜利且下一关就绪时 >0（主按钮位让给「出击下一关」直通键）
var _next_level: int = 0


static func create(parent: Node, player_won: bool, blueprints: Array, \
		phase_field_xp_before: int, phase_field_level_before: int, \
		reward_summary: Dictionary, is_afk: bool = false) -> Control:
	var panel: Control = load("res://scenes/ui/mvp_panel.tscn").instantiate()
	panel.player_won = player_won
	panel._blueprints = blueprints
	panel._xp_before = phase_field_xp_before
	panel._level_before = phase_field_level_before
	panel._reward_summary = reward_summary
	panel._is_afk = is_afk
	parent.add_child(panel)
	panel._build()
	return panel


var player_won: bool = true
var _blueprints: Array = []
var _xp_before: int = 0
var _level_before: int = 0
var _reward_summary: Dictionary = {}
var _is_afk: bool = false
# 星级 Label 引用，供逐个亮起动画使用
var _star_lbl: Label = null
# v30.1 R3（F-13）：三页签容器 + 基地状态折叠态（标题头/内容体/去箭头基文）
var _tabs: TabContainer = null
var _bunker_head: Button = null
var _bunker_body: VBoxContainer = null
var _bunker_title_base: String = ""
# 批次③ T2：横幅叙事落档（冒烟断言用）——title=「胜利/失败/撤退」文案，desc=战报体正文
var last_banner_title: String = ""
var last_banner_text: String = ""


func _ready() -> void:
	anchors_preset = Control.PRESET_FULL_RECT
	mouse_filter = Control.MOUSE_FILTER_STOP


func _build() -> void:
	# 关键：自带 CanvasLayer（layer=200），渲染层级高于 HudLayer(40)/InfoPanelLayer(90)/PopupLayer(100)。
	# 否则面板加到 main（layer=0）会被相位仪底栏（HudLayer 40）盖住底部按钮。
	# 面板节点仍加到 main（保持 _on_continue_pressed → parent._on_result_confirmed 调用链），
	# 但视觉上通过这个 CanvasLayer 提升到最顶层。
	var overlay_layer := CanvasLayer.new()
	overlay_layer.name = "MvpPanelOverlay"
	overlay_layer.layer = 200
	add_child(overlay_layer)
	# 背景遮罩（放在 overlay_layer 内，确保遮罩也在最顶层）
	var backdrop := ColorRect.new()
	backdrop.color = Color(0, 0, 0, 0.65)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay_layer.add_child(backdrop)
	# 主面板：用普通 Panel（非 Container），纯 anchors 固定到屏幕中央留边区域。
	# 关键：不能用 PanelContainer/VBoxContainer——Container 会按子节点 minimum_size
	# 自动撑大自己，ScrollContainer 的内容高度会传上来把面板顶出屏幕。
	# Panel 不参与 minimum_size 传播，offset 锚定的边界就是面板的真实边界，绝不会被撑开。
	var panel := Panel.new()
	panel.name = "Panel"
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	# 居中面板：宽 920（左右各 460），高 600（上下各 300），1280×720 屏幕内留足边距
	panel.offset_left = -460
	panel.offset_right = 460
	panel.offset_top = -300
	panel.offset_bottom = 300
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay_layer.add_child(panel)
	# 面板样式（v28 T2 质感版：SDF 圆角渐变底 + 烘焙 accent 边框，胜/败底色语义保留）
	var style: StyleBox
	if player_won:
		style = PanelStyles.make_result_frame(
			Color(0.0, 0.9, 0.7), Color(0.04, 0.12, 0.10, 0.98))
	else:
		style = PanelStyles.make_result_frame(
			Color(0.9, 0.2, 0.2), Color(0.14, 0.04, 0.04, 0.98))
	panel.add_theme_stylebox_override("panel", style)

	# ═══ v30.1 R3（设计审查 F-13）：三页签内容区——战报/缴获/养成 ═══
	# 原单列长滚动（战绩+缴获+基地+NG+ 六段连排）每场战后都要滚一遍，重复百次疲劳；
	# 拆页签后默认页=战报，缴获按需翻看，养成段（基地状态）默认折叠。
	# TabContainer 走全局主题（quest_panel/card_info_panel 同款观感），切页微过渡同批次2惯例。
	_tabs = TabContainer.new()
	_tabs.set_anchors_preset(Control.PRESET_FULL_RECT)
	_tabs.anchor_right = 1.0
	_tabs.anchor_bottom = 1.0
	_tabs.offset_left = 20.0        # 左内边距
	_tabs.offset_right = -20.0      # 右内边距
	_tabs.offset_top = 16.0         # 上内边距
	_tabs.offset_bottom = -70.0     # 底部留 70px 给按钮区（按钮高44 + 分隔 + margin）
	panel.add_child(_tabs)
	_tabs.tab_changed.connect(_on_result_tab_changed)

	# 战报页（挂机模式无战绩内容，整页隐藏）
	var vbox := _make_result_tab("战报", "胜败横幅、核心数据、星级、本局协同与迷失者讯息")
	if not _is_afk:
		_render_victory_banner(vbox)
		_render_battle_stats(vbox)
		# v30 R3（设计审查 F-07）：本局协同小结——组合/套装/搭档的战斗内贡献在结算收口
		_render_synergy_summary(vbox)
		# v30.2 R4（设计审查 F-08）：驻守关战胜后的迷失者遗言——叙事收口
		if player_won:
			_render_master_epilogue(vbox)
		# v27: 败因分析——失败要产出知识（残存敌军构成 + 克制建议 + 情报提示）
		if not player_won:
			_render_defeat_analysis(vbox)
		# v30.2 R4（F-08）：L100 通关结局演出（独白+致谢+黑门钩子；NG+ 入口在养成页）
		_render_ending(vbox)

	# 缴获页
	var loot_vbox := _make_result_tab("缴获", "首通奖励、本关缴获、战斗卡成长、情报揭示与战利品清单")
	_render_first_clear(loot_vbox)
	_render_phase_field_xp(loot_vbox)
	_render_card_growth(loot_vbox)
	if player_won:
		_render_reward_summary(loot_vbox)
	_render_intel_harvest(loot_vbox)
	if player_won:
		_render_drops(loot_vbox)
		_render_phase_instrument_drop(loot_vbox)
		# v7.x 胜利面板漏显修复：本局缴获与战利品（战中击杀卡/符文/相位师全部缴获）
		_render_collected_rewards(loot_vbox)

	# 养成页：基地状态（v30.1 默认折叠）+ 二周目入口
	var growth_vbox := _make_result_tab("养成", "移动基地修复进度与战役后入口")
	# v22.4（P0-2）：要塞反馈行——修复进度/精神/回基地入口（未进过基地的玩家不显示）
	_render_bunker_status(growth_vbox)
	# ═══ 二周目入口（v26.6 断链补链：start_ng_plus 此前零入口） ═══
	_render_ng_plus_entry(growth_vbox)

	# 空页隐藏（挂机无战报/极端空段）+ 默认页：挂机直落缴获，否则战报
	for i in range(_tabs.get_tab_count()):
		var page := _tabs.get_tab_control(i)
		var col: Container = page.get_child(0) as Container \
				if page != null and page.get_child_count() > 0 else null
		if col == null or col.get_child_count() == 0:
			_tabs.set_tab_hidden(i, true)
	var preferred := 1 if _is_afk else 0
	if _tabs.is_tab_hidden(preferred):
		preferred = 0
	if _tabs.is_tab_hidden(preferred):
		for i in range(_tabs.get_tab_count()):
			if not _tabs.is_tab_hidden(i):
				preferred = i
				break
	_tabs.current_tab = preferred

	# ═══ 关闭按钮：anchors 钉在面板底部，永远可见 ═══
	_render_close_button_anchored(panel)

	# 整体淡入（panel 是 Control，有 modulate；CanvasLayer 没有 modulate 属性）
	# C7: 时长走 DT.MOTION_FADE_IN + SINE（原 0.3 裸 linear，与全项目弹窗节奏不一致）
	panel.modulate.a = 0.0
	if not DT.is_motion_reduce():
		var tw := create_tween()
		tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tw.tween_property(panel, "modulate:a", 1.0, DT.MOTION_FADE_IN)

	# 星级逐个亮起动画（胜利时）
	if not _is_afk and player_won and _star_lbl != null:
		_animate_stars()


# =========================================================================
#  v30.1 R3：三页签辅助
# =========================================================================

## 建一个页签页（ScrollContainer + 内容列），返回内容列。
## 沿用原单列滚动的全部防顶开约束（横向禁滚/纵向自动/min_size=0）。
func _make_result_tab(title: String, tip: String) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.name = title
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	# 关键：设为 0，防止 ScrollContainer 用内容高度作为自身 min_size 顶开布局
	scroll.custom_minimum_size = Vector2(0, 0)
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tabs.add_child(scroll)
	_tabs.set_tab_title(_tabs.get_tab_count() - 1, title)
	if not tip.is_empty():
		_tabs.set_tab_tooltip(_tabs.get_tab_count() - 1, tip)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(col)
	return col


## 切页微过渡（批次2 tab 淡入惯例；减少动效时 fade_content_in 内部短路）
func _on_result_tab_changed(_tab: int) -> void:
	var page := _tabs.get_current_tab_control() if _tabs != null else null
	if page is Control:
		PanelAnim.fade_content_in(page)


# =========================================================================
#  战绩区域
# =========================================================================

## v30 R3：本局协同小结——战末读 BattleManager 组合引擎，列出本场激活过的
## 组合/套装（全队满档）与搭档；无激活则整节不渲染（信息密度守门）。
## 数据源与战场组合条同一引擎实例（get_active_mechanisms / is_pair_active）。
func _render_synergy_summary(vbox: VBoxContainer) -> void:
	var bm := get_node_or_null("/root/BattleManager")
	if bm == null or not bm.has_method("get_combo_engine"):
		return
	var eng = bm.get_combo_engine()
	if eng == null or not eng.has_method("get_active_mechanisms"):
		return
	var mechs: Array = eng.get_active_mechanisms()
	var lines: Array[String] = []
	for combo_id in _SYNERGY_COMBO_ORDER:
		var def: Dictionary = ComboTacticsRef.get_combo_def(String(combo_id))
		if def.is_empty():
			continue
		var combo_mechs: Array = def.get("mechanisms", [])
		var hit := false
		for m in combo_mechs:
			if mechs.has(String(m)):
				hit = true
				break
		if hit:
			lines.append("✦ %s %s — %s" % [
				String(def.get("icon", "")), String(def.get("name", String(combo_id))),
				String(def.get("desc", ""))])
	var pair_hits: int = 0
	if eng.has_method("is_pair_active"):
		for pid in _SYNERGY_PAIR_ORDER:
			if bool(eng.is_pair_active(String(pid))):
				pair_hits += 1
	if lines.is_empty() and pair_hits == 0:
		return
	var title := Label.new()
	title.text = "⚔ 本局协同（%d 组合 · %d/5 搭档）" % [lines.size(), pair_hits]
	title.add_theme_font_size_override("font_size", DT.FONT_SIZE_SMALL)
	title.add_theme_color_override("font_color", Color(0.55, 0.95, 0.65, 0.95))
	vbox.add_child(title)
	var body := Label.new()
	body.text = "\n".join(lines) if not lines.is_empty() else "（本场无组合/套装满档激活）"
	body.add_theme_font_size_override("font_size", DT.FONT_SIZE_SMALL)
	body.add_theme_color_override("font_color", DT.COLOR_TEXT_MID)
	vbox.add_child(body)


## v30.2 R4（设计审查 F-08）：驻守关遗言——战胜驻守相位师（迷失的同伴）后的
## 一句讯息，收在战报页协同小结之后。非驻守关/台词未注入 → 整节不渲染（守门）。
## 文风口径：LANGUAGE_BIBLE 迷失者条——战胜=带回其力量，不是消灭。
func _render_master_epilogue(vbox: VBoxContainer) -> void:
	var lvl := 1
	if GameManager != null:
		lvl = int(GameManager.current_level)
	var epilogue := CampaignNarrative.get_post_battle_line(lvl)
	if epilogue.is_empty():
		return
	var master_name := CampaignNarrative.get_post_battle_master_name(lvl)
	vbox.add_child(_make_separator())
	var title := Label.new()
	title.text = ("🕯 来自 %s 的讯息" % master_name) if not master_name.is_empty() else "🕯 迷失者的讯息"
	title.add_theme_font_size_override("font_size", DT.FONT_SIZE_BODY)
	title.add_theme_color_override("font_color", Color(1.0, 0.72, 0.32))
	vbox.add_child(title)
	var body := Label.new()
	body.text = epilogue
	body.add_theme_font_size_override("font_size", DT.FONT_SIZE_SMALL)
	body.add_theme_color_override("font_color", DT.COLOR_TEXT_MID)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(body)
	var hint := Label.new()
	hint.text = "他的生平与遗言已录入同伴档案——移动基地 · 同伴档案 / 纪念墙"
	hint.add_theme_font_size_override("font_size", DT.FONT_SIZE_SMALL)
	hint.add_theme_color_override("font_color", Color(0.6, 0.62, 0.66, 1.0))
	vbox.add_child(hint)


## v30.2 R4（设计审查 F-08）：L100 结局演出——通关独白 + 致谢 + 黑门钩子，
## 收在战报页尾部（胜利高潮处）；NG+ 入口留在养成页不动。仅最终关胜利且
## 非挂机渲染；通关低频，二周目重通允许重播（重温语义）。
func _render_ending(vbox: VBoxContainer) -> void:
	if _is_afk or not player_won:
		return
	if GameManager == null or GameManager.current_level < LevelInformation.LEVEL_COUNT:
		return
	var ending := CampaignNarrative.get_ending()
	vbox.add_child(_make_separator())
	var wrap := VBoxContainer.new()
	wrap.add_theme_constant_override("separation", 8)
	vbox.add_child(wrap)
	for line in ending.get("monologue", []):
		var ml := Label.new()
		ml.text = String(line)
		ml.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		ml.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		ml.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		ml.add_theme_font_size_override("font_size", DT.FONT_SIZE_BODY)
		ml.add_theme_color_override("font_color", DT.COLOR_TEXT_BRIGHT)
		wrap.add_child(ml)
	var credits := Label.new()
	credits.text = String(ending.get("credits", ""))
	credits.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	credits.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	credits.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	credits.add_theme_font_size_override("font_size", DT.FONT_SIZE_SMALL)
	credits.add_theme_color_override("font_color", DT.COLOR_GOLD)
	wrap.add_child(credits)
	var hook := Label.new()
	hook.text = String(ending.get("hook", ""))
	hook.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hook.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hook.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hook.add_theme_font_size_override("font_size", DT.FONT_SIZE_SMALL)
	hook.add_theme_color_override("font_color", Color(0.5, 0.9, 0.85, 0.95))
	wrap.add_child(hook)


func _render_victory_banner(vbox: VBoxContainer) -> void:
	# 批次③ Task 2：三态叙事——胜利池 / 撤退池（meta 一次性消费）/ 失败池；
	# 撤退标题不复用「失败」红字，走中性色，避免"撤退被判失败"的文案打架。
	var retreated := false
	if not player_won:
		retreated = Engine.has_meta(META_RETREATED)
		if retreated:
			Engine.remove_meta(META_RETREATED)
	# 战绩横幅（大标题）
	var title := Label.new()
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var title_ls := LabelSettings.new()
	if player_won:
		title.text = "✓ 胜  利"
		title_ls.font_color = DT.COLOR_GOLD
		title_ls.font_size = DT.FONT_SIZE_HUGE
		last_banner_title = "胜利"
	elif retreated:
		title.text = "✕ 撤  退"
		title_ls.font_color = DT.COLOR_TEXT_BRIGHT
		title_ls.font_size = DT.FONT_SIZE_TITLE
		last_banner_title = "撤退"
	else:
		title.text = "✗ 失  败"
		title_ls.font_color = Color(1, 0.3, 0.3, 1)
		title_ls.font_size = DT.FONT_SIZE_TITLE
		last_banner_title = "失败"
	title_ls.outline_color = Color(0, 0, 0, 0.85)
	title_ls.outline_size = 4
	# v28 T2: 大标题落地影——胜利染金辉、败/撤染深影，把"高光时刻"从纯平文字里托出来
	if player_won:
		title_ls.shadow_color = Color(DT.COLOR_GOLD.r, DT.COLOR_GOLD.g, DT.COLOR_GOLD.b, 0.30)
	else:
		title_ls.shadow_color = Color(0, 0, 0, 0.45)
	title_ls.shadow_offset = Vector2(0, 3)
	title.label_settings = title_ls
	vbox.add_child(title)
	# 副标题描述（战报体轮换池；败仗低概率挂牺牲相位师名）
	var desc := Label.new()
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var pool: Array = BANNER_LINES_VICTORY if player_won else (
		BANNER_LINES_RETREAT if retreated else BANNER_LINES_DEFEAT)
	desc.text = _pick_banner_line(pool)
	if not player_won and not retreated:
		var hero_line := _render_field_report()
		if hero_line != "":
			desc.text += "\n" + hero_line
	desc.add_theme_font_size_override("font_size", DT.FONT_SIZE_SMALL)
	desc.add_theme_color_override("font_color", DT.COLOR_TEXT_BRIGHT)
	vbox.add_child(desc)
	last_banner_text = desc.text


## 批次③ Task 2：战报体取句（池内随机轮换）
func _pick_banner_line(pool: Array) -> String:
	if pool.is_empty():
		return ""
	return String(pool[randi() % pool.size()])


## 批次③ Task 2：败仗专属叙事段——低概率记下一位牺牲相位师的名字（找同伴主旨）。
## 撤退态不挂（人没牺牲，只是离开）；名册取不到时静默降级为无此行。
func _render_field_report() -> String:
	if randf() >= HERO_LINE_CHANCE:
		return ""
	var masters: Array = EnemyPhaseMasters.ENEMY_MASTERS
	if masters.is_empty():
		return ""
	var hero_name := String(masters[randi() % masters.size()].get("name", ""))
	if hero_name.is_empty():
		return ""
	return "记下这个名字：%s。" % hero_name


func _render_battle_stats(vbox: VBoxContainer) -> void:
	var stats: Dictionary = _collect_stats()
	# 战斗时长 + 星级（同一行）
	var top_row := HBoxContainer.new()
	top_row.alignment = BoxContainer.ALIGNMENT_CENTER
	top_row.add_theme_constant_override("separation", 32)
	vbox.add_child(top_row)
	# 时长
	var time_lbl := Label.new()
	time_lbl.text = "战斗时长  %s" % _format_time(stats.get("battle_time", 0.0))
	time_lbl.add_theme_font_size_override("font_size", DT.FONT_SIZE_MEDIUM)
	time_lbl.add_theme_color_override("font_color", DT.COLOR_TEXT_BRIGHT)
	time_lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top_row.add_child(time_lbl)
	# 星级
	var stars: int = _compute_stars(stats)
	_star_lbl = Label.new()
	_star_lbl.text = _star_text(stars)
	_star_lbl.add_theme_font_size_override("font_size", DT.FONT_SIZE_TITLE)
	_star_lbl.add_theme_color_override("font_color", DT.COLOR_GOLD if stars >= 2 else DT.COLOR_TEXT_DIM)
	_star_lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top_row.add_child(_star_lbl)

	# 核心数据网格
	vbox.add_child(_make_separator())
	var data_grid := GridContainer.new()
	data_grid.columns = 2
	data_grid.add_theme_constant_override("h_separation", 32)
	data_grid.add_theme_constant_override("v_separation", 6)
	vbox.add_child(data_grid)
	# v26.13(gameplay) 修复：两行此前读反——"击毁敌方"读的是 enemy_kills（敌方击杀数）、
	# "我方损失"读的是 player_kills（我方击杀数），败局/胜局核心数据恒显示反值。
	_add_data_row(data_grid, "击毁敌方", str(stats.get("player_kills", 0)), DT.COLOR_GREEN_BRIGHT)
	_add_data_row(data_grid, "我方损失", str(stats.get("enemy_kills", 0)), DT.COLOR_DANGER)
	_add_data_row(data_grid, "造成伤害", FormatUtil.format_thousands(int(stats.get("damage_dealt", 0))), DT.COLOR_ACCENT_CYAN)
	_add_data_row(data_grid, "承受伤害", FormatUtil.format_thousands(int(stats.get("damage_taken", 0))), DT.COLOR_ENERGY)

	# v32.0 B1-3: 本场最佳（每单位战斗记录——输出/击杀/承伤各 Top1）
	var mvp: Dictionary = BattleUnitRecord.get_top_entries()
	if not mvp.is_empty():
		vbox.add_child(_make_separator())
		var mvp_title := Label.new()
		mvp_title.text = "本场最佳"
		mvp_title.add_theme_font_size_override("font_size", DT.FONT_SIZE_SMALL)
		mvp_title.add_theme_color_override("font_color", DT.COLOR_TEXT_DIM)
		vbox.add_child(mvp_title)
		var mvp_grid := GridContainer.new()
		mvp_grid.columns = 2
		mvp_grid.add_theme_constant_override("h_separation", 32)
		mvp_grid.add_theme_constant_override("v_separation", 6)
		vbox.add_child(mvp_grid)
		if mvp.has("top_dealer"):
			var d: Dictionary = mvp["top_dealer"]
			_add_data_row(mvp_grid, "输出最佳", "%s（%s）" % [d["label"], FormatUtil.format_thousands(int(d["value"]))], DT.COLOR_ACCENT_CYAN)
		if mvp.has("top_killer"):
			var k: Dictionary = mvp["top_killer"]
			_add_data_row(mvp_grid, "击杀最多", "%s（%d 杀）" % [k["label"], int(k["value"])], DT.COLOR_GREEN_BRIGHT)
		if mvp.has("top_tank"):
			var t: Dictionary = mvp["top_tank"]
			_add_data_row(mvp_grid, "承伤最坚", "%s（%s）" % [t["label"], FormatUtil.format_thousands(int(t["value"]))], DT.COLOR_ENERGY)

	# 击杀类型分布
	var kill_breakdown := _kill_type_breakdown()
	if not kill_breakdown.is_empty():
		var kb_lbl := Label.new()
		kb_lbl.text = "击破分布"
		kb_lbl.add_theme_font_size_override("font_size", DT.FONT_SIZE_SMALL)
		kb_lbl.add_theme_color_override("font_color", DT.COLOR_TEXT_DIM)
		kb_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(kb_lbl)
		var kb_val := Label.new()
		kb_val.text = ", ".join(kill_breakdown)
		kb_val.add_theme_font_size_override("font_size", DT.FONT_SIZE_SMALL)
		kb_val.add_theme_color_override("font_color", DT.COLOR_TEXT_BRIGHT)
		kb_val.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(kb_val)


# =========================================================================
#  缴获明细区域
# =========================================================================

## v34 B3：首通奖励仪式化区块——此前只有一行 Toast，"打完新关的大额回报"无感知。
## 金色标题 + 三资源行逐项亮起（与星级动画同语言；减少动效直接显示）。
func _render_first_clear(vbox: VBoxContainer) -> void:
	var fc: Dictionary = _reward_summary.get("first_clear", {})
	var reward: Dictionary = fc.get("reward", {}) if fc is Dictionary else {}
	if reward.is_empty():
		return
	var sep := HSeparator.new()
	sep.add_theme_color_override("color", Color(1.0, 0.85, 0.4, 0.35))
	vbox.add_child(sep)
	var title := Label.new()
	title.text = "★ 首次通关奖励（第 %d 关）" % int(fc.get("level", 0))
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", DT.COLOR_GOLD)
	vbox.add_child(title)
	var res_names := {"crystal": "晶体", "nano_materials": "纳米材料", "energy_block": "能量块"}
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 3)
	var delay := 0.0
	for id in reward:
		var lbl := Label.new()
		lbl.text = "  ★ %s +%d" % [String(res_names.get(String(id), String(id))), int(reward[id])]
		lbl.add_theme_font_size_override("font_size", DT.FONT_SIZE_SMALL)
		lbl.add_theme_color_override("font_color", DT.COLOR_TEXT_BRIGHT)
		list.add_child(lbl)
		if not DT.is_motion_reduce():
			lbl.modulate.a = 0.0
			var tw := create_tween()
			tw.tween_interval(delay)
			tw.tween_property(lbl, "modulate:a", 1.0, 0.25)
		delay += 0.18
	vbox.add_child(list)

## v34 B2：战斗卡成长区块——卡牌经验此前静默入账（升级回调零玩家可见反馈），
## "打完变强了"的数字被藏起来。本区块逐行展示上阵卡 +XP，升级行金色高亮。
func _render_card_growth(vbox: VBoxContainer) -> void:
	var rows: Array = _reward_summary.get("card_growth", [])
	if rows.is_empty():
		return
	var sep := HSeparator.new()
	sep.add_theme_color_override("color", Color(DT.COLOR_AMBER.r, DT.COLOR_AMBER.g, DT.COLOR_AMBER.b, 0.25))
	vbox.add_child(sep)
	var title := Label.new()
	title.text = "◆ 战斗卡成长"
	title.add_theme_font_size_override("font_size", 13)
	title.add_theme_color_override("font_color", DT.COLOR_AMBER)
	vbox.add_child(title)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 3)
	var leveled_count := 0
	for row in rows:
		if not (row is Dictionary):
			continue
		var lv: int = int(row.get("lv", 0))
		var lv_txt: String = ("Lv.%d" % lv) if lv > 0 else "未成长"
		var lbl := Label.new()
		if bool(row.get("leveled", false)):
			leveled_count += 1
			lbl.text = "  ▲ %s  升级 → %s（经验 +%d）" % [String(row.get("name", "?")), lv_txt, int(row.get("xp", 0))]
			lbl.add_theme_color_override("font_color", DT.COLOR_GOLD)
		else:
			lbl.text = "  ▸ %s  %s（经验 +%d）" % [String(row.get("name", "?")), lv_txt, int(row.get("xp", 0))]
			lbl.add_theme_color_override("font_color", DT.COLOR_TEXT_MID)
		lbl.add_theme_font_size_override("font_size", DT.FONT_SIZE_SMALL)
		list.add_child(lbl)
	vbox.add_child(list)
	if leveled_count > 0:
		var sum_lbl := Label.new()
		sum_lbl.text = "上阵 %d 张卡获得经验，%d 张升级" % [rows.size(), leveled_count]
		sum_lbl.add_theme_font_size_override("font_size", DT.FONT_SIZE_XSMALL)
		sum_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4, 0.85))
		vbox.add_child(sum_lbl)

func _render_phase_field_xp(vbox: VBoxContainer) -> void:
	var pim: Node = Engine.get_main_loop().root.get_node_or_null("PhaseInstrumentManager")
	if pim == null or not pim.has_method("get_phase_field_xp_progress"):
		return
	var phase_prog: Dictionary = pim.get_phase_field_xp_progress()
	var phase_xp_after: int = int(phase_prog.get("xp", 0))
	var phase_level_after: int = int(phase_prog.get("level", 1))
	var phase_xp_gain: int = max(0, phase_xp_after - _xp_before)
	var phase_info := Label.new()
	phase_info.add_theme_font_size_override("font_size", DT.FONT_SIZE_SMALL)
	phase_info.add_theme_color_override("font_color", Color(DT.COLOR_CYAN_TECH.r, DT.COLOR_CYAN_TECH.g, DT.COLOR_CYAN_TECH.b, 0.95))
	if player_won:
		var lv_up_text: String = ""
		if phase_level_after > _level_before:
			lv_up_text = "  (Lv.%d → Lv.%d)" % [_level_before, phase_level_after]
		phase_info.text = "相位场经验 +%d%s" % [phase_xp_gain, lv_up_text]
	else:
		# v26.13(gameplay)：败局现发 30% 相位场经验——显示真实增量而非硬编码 +0
		var lv_up_text2: String = ""
		if phase_level_after > _level_before:
			lv_up_text2 = "  (Lv.%d → Lv.%d)" % [_level_before, phase_level_after]
		phase_info.text = "相位场经验 +%d%s（败局 30%%）" % [phase_xp_gain, lv_up_text2]
	vbox.add_child(phase_info)


func _render_reward_summary(vbox: VBoxContainer) -> void:
	if _reward_summary.is_empty():
		return
	var reward_sep := HSeparator.new()
	reward_sep.add_theme_color_override("color", Color(0, 0.9, 0.7, 0.25))
	vbox.add_child(reward_sep)
	var reward_title := Label.new()
	reward_title.text = "◆ 本关缴获"
	reward_title.add_theme_font_size_override("font_size", 13)
	reward_title.add_theme_color_override("font_color", DT.COLOR_GREEN_BRIGHT)
	vbox.add_child(reward_title)
	var reward_list := VBoxContainer.new()
	reward_list.add_theme_constant_override("separation", 3)
	# 扫描 pending drops 中已汇总的 MATERIAL 资源，合并到顶部显示（避免与掉落列表重复）
	ManagerLazyLoader.ensure_loaded("drop")  # DropManager 为 autoload+别名双层（ensure_loaded 幂等）
	var dm_for_summary: Node = Engine.get_main_loop().root.get_node_or_null("DropManager")
	var pending_mats: Dictionary = _summarize_pending_materials(dm_for_summary)
	var energy_gain: int = int(_reward_summary.get("energy_block_gain", 0)) + int(pending_mats.get("energy_block", 0))
	# 纳米材料统一显示一行（固定关卡缴获 + 随机掉落，合并总量）
	var basic_nano_gain: int = int(_reward_summary.get("basic_nano_gain", 0)) + int(pending_mats.get("nano_materials", 0))
	var fragment_gain_total: int = int(_reward_summary.get("fragment_gain_total", 0))
	var recon_bonus_percent: int = int(_reward_summary.get("recon_fragment_bonus_percent", 0))
	var reward_lines: Array[String] = [
		"  ▸ 能量块 +%d" % energy_gain,
		"  ▸ 纳米材料 +%d" % basic_nano_gain,
		"  ▸ 战斗卡 +%d（侦察加成 %+d%%）" % [fragment_gain_total, recon_bonus_percent],
		]
	for line_text in reward_lines:
		var reward_lbl := Label.new()
		reward_lbl.text = line_text
		reward_lbl.add_theme_font_size_override("font_size", DT.FONT_SIZE_SMALL)
		reward_lbl.add_theme_color_override("font_color", DT.COLOR_TEXT_BRIGHT)
		reward_list.add_child(reward_lbl)
	vbox.add_child(reward_list)


func _render_intel_harvest(vbox: VBoxContainer) -> void:
	var intel_harvest: Dictionary = _reward_summary.get("intel_harvest", {})
	if intel_harvest.is_empty():
		return
	var intel_sep := HSeparator.new()
	intel_sep.add_theme_color_override("color", Color(DT.COLOR_VIOLET.r, DT.COLOR_VIOLET.g, DT.COLOR_VIOLET.b, 0.25))
	vbox.add_child(intel_sep)
	var IHD = preload("res://scenes/ui/intel_harvest_display.gd")
	var harvest_ui = IHD.new()
	harvest_ui.set_data(intel_harvest)
	vbox.add_child(harvest_ui)
	# 有新揭示事件时，延迟弹出 IntelRevealPopup 精致展示
	var reveal_events: Array = intel_harvest.get("reveal_events", [])
	if not reveal_events.is_empty():
		call_deferred("_show_intel_reveal_popup", reveal_events)
	# 改造解锁：结算时批量展示（避免战斗中多次弹窗）
	var mod_unlocks: Array = intel_harvest.get("mod_unlock_events", [])
	if not mod_unlocks.is_empty():
		var lines: Array[String] = []
		for entry in mod_unlocks:
			if entry is Dictionary:
				var card: String = String(entry.get("card_name", ""))
				var mod: String = String(entry.get("mod_name", ""))
				lines.append("「%s」→ %s" % [card, mod])
		var title := "改造情报解锁"
		var desc := "本关共解锁 %d 项改造模块：\n%s" % [lines.size(), "\n".join(lines)]
		call_deferred("_show_mod_unlock_popup", title, desc)


func _render_drops(vbox: VBoxContainer) -> void:
	ManagerLazyLoader.ensure_loaded("drop")  # DropManager 为 autoload+别名双层（ensure_loaded 幂等）
	var dm: Node = Engine.get_main_loop().root.get_node_or_null("DropManager")
	if dm == null or not dm.has_method("get_pending_drops"):
		return
	var drops: Array = dm.get_pending_drops()
	if drops.is_empty():
		return
	var drop_sep := HSeparator.new()
	drop_sep.add_theme_color_override("color", Color(DT.COLOR_CYAN_TECH.r, DT.COLOR_CYAN_TECH.g, DT.COLOR_CYAN_TECH.b, 0.25))
	vbox.add_child(drop_sep)
	var drop_title := Label.new()
	drop_title.text = "◆ 战斗缴获（继续后自动接收）"
	drop_title.add_theme_font_size_override("font_size", 13)
	drop_title.add_theme_color_override("font_color", DT.COLOR_CYAN_TECH)
	vbox.add_child(drop_title)
	# 性能优化：get_drop_info 内部会查 DefaultCards(133卡表)/PhaseLaws，
	# 每次 sort 比较重复调用是 O(n²) 量级。一次性预建每个 drop 的 info 缓存。
	var primary_drops: Array = []
	var secondary_drops: Array = []
	var info_cache: Dictionary = {}  # instance_id -> info Dictionary
	var has_get_info: bool = dm != null and dm.has_method("get_drop_info")
	for dr in drops:
		if not (dr is DropTables.DropResult):
			continue
		# 过滤已在"本关获得"区汇总的 MATERIAL 资源（nano_materials/energy_block）
		if _is_summarized_material(dr):
			continue
		var info0: Dictionary = dm.get_drop_info(dr) if has_get_info else {}
		info_cache[dr.get_instance_id()] = info0
		var t0: int = int(info0.get("type", -1))
		if _drop_type_is_card_lane(t0):
			primary_drops.append(dr)
		else:
			secondary_drops.append(dr)
	# 排序比较器只查缓存
	var _sort_by_name := func(a, b) -> bool:
		var ia: Dictionary = info_cache.get(a.get_instance_id(), {})
		var ib: Dictionary = info_cache.get(b.get_instance_id(), {})
		return String(ia.get("name", "")) < String(ib.get("name", ""))
	primary_drops.sort_custom(_sort_by_name)
	secondary_drops.sort_custom(_sort_by_name)
	var drop_list := VBoxContainer.new()
	drop_list.add_theme_constant_override("separation", 3)
	var _append_drop_rows := func(rows: Array, subhdr: String) -> void:
		if rows.is_empty():
			return
		var sh := Label.new()
		sh.text = subhdr
		sh.add_theme_font_size_override("font_size", DT.FONT_SIZE_SMALL)
		sh.add_theme_color_override("font_color", Color(DT.COLOR_TEXT_MID.r, DT.COLOR_TEXT_MID.g, DT.COLOR_TEXT_MID.b, 0.95))
		drop_list.add_child(sh)
		for dr in rows:
			var line_text: String = "  ▸ 未知掉落"
			var info: Dictionary = info_cache.get(dr.get_instance_id(), {})
			var n: String = String(info.get("name", "未知"))
			var c: int = int(info.get("count", 1))
			var s: String = String(info.get("source", "battle"))
			# v9.x（P2-7）：能量类掉落随科研点退役，claim 时静默跳过（drop_manager 无效果臂）；
			# 旧档 pending 若仍出现，如实标注跳过（原"研究点 ×N"文案随科研点退役失实，v26.4 清理）。
			var t_int: int = int(info.get("type", -1))
			if t_int == DropTables.DropType.ENERGY_CARD or t_int == DropTables.DropType.ENERGY_DATA or t_int == DropTables.DropType.ENERGY_BLUEPRINT:
				line_text = "  ▸ 旧版本掉落（已自动跳过）"
			else:
				line_text = "  ▸ %s ×%d（%s）" % [n, c, s]
			var dl := Label.new()
			dl.text = line_text
			dl.add_theme_font_size_override("font_size", DT.FONT_SIZE_SMALL)
			dl.add_theme_color_override("font_color", DT.COLOR_TEXT_BRIGHT)
			drop_list.add_child(dl)
	_append_drop_rows.call(primary_drops, "  ▸ 缴获 / 研发类")
	_append_drop_rows.call(secondary_drops, "  ▸ 物资 / 情报类")
	vbox.add_child(drop_list)


func _render_phase_instrument_drop(vbox: VBoxContainer) -> void:
	var pi_drop: Dictionary = _reward_summary.get("phase_instrument_drop", {})
	if not (pi_drop is Dictionary) or pi_drop.is_empty():
		return
	var pi_sep := HSeparator.new()
	pi_sep.add_theme_color_override("color", Color(DT.COLOR_CYAN_TECH.r, DT.COLOR_CYAN_TECH.g, DT.COLOR_CYAN_TECH.b, 0.25))
	vbox.add_child(pi_sep)
	var pi_title := Label.new()
	pi_title.text = "◆ 相位仪缴获"
	pi_title.add_theme_font_size_override("font_size", 13)
	pi_title.add_theme_color_override("font_color", DT.COLOR_CYAN_TECH)
	vbox.add_child(pi_title)
	var pi_name: String = String(pi_drop.get("name", "未知相位仪"))
	var pi_star: int = int(pi_drop.get("star", 1))
	var pi_line := Label.new()
	pi_line.text = "  ▸ %s ★%d（已加入相位仪库）" % [pi_name, pi_star]
	pi_line.add_theme_font_size_override("font_size", DT.FONT_SIZE_SMALL)
	pi_line.add_theme_color_override("font_color", DT.COLOR_TEXT_BRIGHT)
	vbox.add_child(pi_line)
	var pi_props: Array = pi_drop.get("properties", [])
	if pi_props is Array and not pi_props.is_empty():
		var show_n: int = mini(5, pi_props.size())
		for i in range(show_n):
			var p: Variant = pi_props[i]
			if not (p is Dictionary):
				continue
			var p_display: String = String((p as Dictionary).get("display", ""))
			if p_display.is_empty():
				continue
			var p_line := Label.new()
			p_line.text = "    · %s" % p_display
			p_line.add_theme_font_size_override("font_size", DT.FONT_SIZE_SMALL)
			p_line.add_theme_color_override("font_color", Color(DT.COLOR_TEXT_MID.r, DT.COLOR_TEXT_MID.g, DT.COLOR_TEXT_MID.b, 0.95))
			vbox.add_child(p_line)
		if pi_props.size() > show_n:
			var more_line := Label.new()
			more_line.text = "    · 另有 %d 条属性" % (pi_props.size() - show_n)
			more_line.add_theme_font_size_override("font_size", DT.FONT_SIZE_SMALL)
			more_line.add_theme_color_override("font_color", Color(DT.COLOR_TEXT_DIM.r, DT.COLOR_TEXT_DIM.g, DT.COLOR_TEXT_DIM.b, 0.95))
			vbox.add_child(more_line)


# =========================================================================
#  v7.x 胜利面板漏显修复：本局缴获与战利品
#  渲染绕过 DropManager.pending_drops 直接入背包/库存的缴获：
#  战中击杀卡 / 战中符文 / 相位师 Boss掉落卡 / 缴获平台卡 / 相位师符文 /
#  相位师改造图纸 / 特殊相位仪 / 相位师额外材料
# =========================================================================

func _render_collected_rewards(vbox: VBoxContainer) -> void:
	var collected: Array = _reward_summary.get("collected_rewards", [])
	if collected.is_empty():
		return
	# 按 category 分组（保留首次出现顺序）
	var grouped: Dictionary = {}  # category -> Array[entry]
	var order: Array[String] = []
	for entry in collected:
		if not (entry is Dictionary):
			continue
		var cat: String = String(entry.get("category", ""))
		if cat.is_empty():
			continue
		if not grouped.has(cat):
			grouped[cat] = []
			order.append(cat)
		grouped[cat].append(entry)
	if grouped.is_empty():
		return
	var col_sep := HSeparator.new()
	col_sep.add_theme_color_override("color", Color(DT.COLOR_GOLD.r, DT.COLOR_GOLD.g, DT.COLOR_GOLD.b, 0.3))
	vbox.add_child(col_sep)
	var col_title := Label.new()
	col_title.text = "◆ 本局缴获与战利品"
	col_title.add_theme_font_size_override("font_size", 13)
	col_title.add_theme_color_override("font_color", DT.COLOR_GOLD)
	vbox.add_child(col_title)
	var col_list := VBoxContainer.new()
	col_list.add_theme_constant_override("separation", 3)
	# 按固定顺序渲染各分组（缺失则跳过）
	var section_order: Array[String] = ["card", "rune", "mod_blueprint", "instrument", "resource"]
	for cat in section_order:
		if not grouped.has(cat):
			continue
		_render_collected_section(col_list, cat, grouped[cat])
	vbox.add_child(col_list)


## 渲染单个分类区块（卡牌/符文/改造图纸/特殊相位仪/资源）
func _render_collected_section(parent_vbox: VBoxContainer, cat: String, entries: Array) -> void:
	var section_title: String = _collected_section_title(cat)
	var sh := Label.new()
	sh.text = "  ▸ %s（共%d）" % [section_title, entries.size()]
	sh.add_theme_font_size_override("font_size", DT.FONT_SIZE_SMALL)
	sh.add_theme_color_override("font_color", Color(DT.COLOR_GOLD.r, DT.COLOR_GOLD.g, DT.COLOR_GOLD.b, 0.95))
	parent_vbox.add_child(sh)
	for entry in entries:
		if not (entry is Dictionary):
			continue
		var line_text: String = _collected_entry_line(cat, entry)
		var line_lbl := Label.new()
		line_lbl.text = "      · " + line_text
		line_lbl.add_theme_font_size_override("font_size", DT.FONT_SIZE_SMALL)
		line_lbl.add_theme_color_override("font_color", _collected_entry_color(cat, entry))
		parent_vbox.add_child(line_lbl)


## 分类中文标题
static func _collected_section_title(cat: String) -> String:
	match cat:
		"card": return "缴获卡牌"
		"rune": return "符文"
		"mod_blueprint": return "改造图纸"
		"instrument": return "特殊相位仪"
		"resource": return "相位师额外战利品"
		_: return cat


## 单项行文本
static func _collected_entry_line(cat: String, entry: Dictionary) -> String:
	var name: String = String(entry.get("name", entry.get("id", "?")))
	var source: String = String(entry.get("source", ""))
	var src_suffix: String = "（%s）" % source if not source.is_empty() else ""
	match cat:
		"card":
			var count: int = int(entry.get("count", 1))
			if count > 1:
				return "%s ×%d%s" % [name, count, src_suffix]
			return "%s%s" % [name, src_suffix]
		"rune":
			var rarity: String = _collected_rarity_name(String(entry.get("rarity", "")))
			return "%s%s%s" % [name, ("（" + rarity + "）") if not rarity.is_empty() else "", src_suffix]
		"mod_blueprint":
			var rarity: String = _collected_rarity_name(String(entry.get("rarity", "")))
			return "%s%s%s" % [name, ("（" + rarity + "）") if not rarity.is_empty() else "", src_suffix]
		"instrument":
			var star: int = int(entry.get("star", 1))
			return "%s ★%d%s" % [name, star, src_suffix]
		"resource":
			var res_name: String = _collected_resource_name(String(entry.get("id", "")))
			var amount: int = int(entry.get("amount", 0))
			return "%s +%d%s" % [res_name, amount, src_suffix]
		_:
			return name + src_suffix


## 单项颜色（按 category / 稀有度区分）
static func _collected_entry_color(cat: String, entry: Dictionary) -> Color:
	match cat:
		"card": return DT.COLOR_TEXT_BRIGHT
		"instrument": return DT.COLOR_GOLD
		"resource": return DT.COLOR_GREEN_BRIGHT
		"rune", "mod_blueprint":
			return _collected_rarity_color(String(entry.get("rarity", "")))
		_: return DT.COLOR_TEXT_BRIGHT


## 稀有度中文名（符文/改造图纸用）
static func _collected_rarity_name(rarity: String) -> String:
	match rarity:
		"common": return "普通"
		"uncommon": return "优秀"
		"rare": return "稀有"
		"epic": return "史诗"
		"legendary": return "传说"
		"mythic": return "神话"
		_: return rarity


## 稀有度配色（v23.6.1：收口到 GC.get_rarity_color 单一源，删除本地平行表）
static func _collected_rarity_color(rarity: String) -> Color:
	return GC.get_rarity_color(rarity)


## 资源 id → 中文名
static func _collected_resource_name(res_id: String) -> String:
	match res_id:
		"nano_materials": return "纳米材料"
		"energy_block": return "能量块"
		"alloy": return "合金"
		"crystal": return "晶体"
		_: return res_id


## 关闭按钮：用 anchors 钉在面板底部，独立于 ScrollContainer，内容再多也永远可见
## v26.6: 断链补链——二周目入口。战役最终关（LevelInformation.LEVEL_COUNT）胜利后
## 显示"进入二周目"按钮，接通 SaveManager.start_ng_plus（符文/相位仪保留、进度重置、敌方 ×1.2）。
## 此前该函数全链活（enemy_unit ×1.2、ng_plus 存档键、DayClock.reset_for_new_loop）但零调用方。
func _render_ng_plus_entry(vbox: VBoxContainer) -> void:
	if not player_won or _is_afk:
		return
	if GameManager.ng_plus_active:
		return  # 已在二周目，不重复提供入口
	if GameManager.current_level < LevelInformation.LEVEL_COUNT:
		return  # 未通关最终关
	vbox.add_child(_make_separator())
	var wrap := VBoxContainer.new()
	wrap.add_theme_constant_override("separation", 8)
	vbox.add_child(wrap)
	var head := Label.new()
	head.text = "∞ 战役已通关——二周目已解锁"
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.add_theme_font_size_override("font_size", DT.FONT_SIZE_TITLE)
	head.add_theme_color_override("font_color", DT.COLOR_GOLD)
	wrap.add_child(head)
	var hint := Label.new()
	hint.text = "符文与相位仪将保留，战役进度与资源重置，敌方全员强化（×1.2）"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", DT.FONT_SIZE_SMALL)
	hint.add_theme_color_override("font_color", DT.COLOR_TEXT_MID)
	wrap.add_child(hint)
	var btn := Button.new()
	btn.text = "进入二周目"
	btn.custom_minimum_size = Vector2(220, 42)
	var styles := PanelStyles.make_button_styles(DT.COLOR_GOLD, "solid")
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		btn.add_theme_stylebox_override(state, styles[state])
	btn.pressed.connect(_show_ng_plus_confirm)
	var center := CenterContainer.new()
	center.add_child(btn)
	wrap.add_child(center)


## v26.6: 二周目确认框——自绘全屏遮罩（AcceptDialog 在 CanvasLayer 下不可显示，
## 同 main.gd 撤退确认框模式），挂独立 CanvasLayer(layer=210) 压过结算面板(200)。
var _ng_confirm_layer: CanvasLayer = null
func _show_ng_plus_confirm() -> void:
	if _ng_confirm_layer != null and is_instance_valid(_ng_confirm_layer):
		return
	var layer := CanvasLayer.new()
	layer.layer = 210
	add_child(layer)
	_ng_confirm_layer = layer
	var overlay := Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(overlay)
	var dim := ColorRect.new()
	dim.color = DT.COLOR_BACKDROP
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(420, 0)
	var sb := PanelStyles.make_panel_frame_textured(DT.COLOR_GOLD)
	sb.content_margin_left = 20
	sb.content_margin_right = 20
	sb.content_margin_top = 18
	sb.content_margin_bottom = 18
	panel.add_theme_stylebox_override("panel", sb)
	center.add_child(panel)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	panel.add_child(vbox)
	var title := Label.new()
	title.text = "进入二周目"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", DT.COLOR_GOLD)
	vbox.add_child(title)
	var body := Label.new()
	body.text = "战役进度与资源将重置，符文与相位仪保留，敌方全员强化（×1.2）。\n确定开启新周目吗？"
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_theme_font_size_override("font_size", 14)
	body.add_theme_color_override("font_color", Color(0.88, 0.9, 0.94, 1.0))
	vbox.add_child(body)
	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 16)
	vbox.add_child(btn_row)
	var confirm_btn := Button.new()
	confirm_btn.text = "确认开启"
	confirm_btn.custom_minimum_size = Vector2(120, 38)
	var c_styles := PanelStyles.make_button_styles(DT.COLOR_GOLD, "solid")
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		confirm_btn.add_theme_stylebox_override(state, c_styles[state])
	btn_row.add_child(confirm_btn)
	var cancel_btn := Button.new()
	cancel_btn.text = "取消"
	cancel_btn.custom_minimum_size = Vector2(120, 38)
	var n_styles := PanelStyles.make_button_styles(DT.COLOR_TEXT_MID)
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		cancel_btn.add_theme_stylebox_override(state, n_styles[state])
	btn_row.add_child(cancel_btn)
	# 关闭确认框
	var close := func() -> void:
		if _ng_confirm_layer != null and is_instance_valid(_ng_confirm_layer):
			_ng_confirm_layer.queue_free()
		_ng_confirm_layer = null
	confirm_btn.pressed.connect(func():
		close.call()
		# 重置进度并保存（符文/相位仪保留、ng_plus 激活），回标题屏以新周目重新开始
		SaveManager.start_ng_plus()
		SceneTransition.change(get_tree(), "res://scenes/title_screen.tscn")
	)
	cancel_btn.pressed.connect(close)


func _render_close_button_anchored(panel: Control) -> void:
	# v34 B1 再战回路：胜利且下一关就绪 → 主按钮位让给「▶ 出击下一关」直通键，
	# 旧「继 续」降级为左侧次按钮（接收掉落+回整备语义不变，文案改「返回整备」）
	_next_level = _compute_next_level()
	var next_mode: bool = player_won and not _is_afk and _next_level > 0
	var btn := Button.new()
	if _is_afk:
		btn.text = "自动继续 →"
	elif next_mode:
		btn.text = "▶ 出击下一关（第 %d 关）" % _next_level
	elif player_won:
		btn.text = "继  续"
	else:
		btn.text = "返回整备"
	# anchors：钉在面板底部，距左右边各留 100px 居中，距底 16px
	btn.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	btn.anchor_left = 0.0
	btn.anchor_right = 1.0
	btn.anchor_top = 1.0
	btn.anchor_bottom = 1.0
	btn.offset_left = 100.0
	btn.offset_right = -100.0
	btn.offset_top = -60.0   # 按钮 top 距面板底 60px（按钮高 44 + 16px 底边距）
	btn.offset_bottom = -16.0
	# v22.4（P0-2）：从基地出击时，左下角加"返回基地"直达按钮，主按钮让位右移
	if _bunker_return_available:
		var home_btn := Button.new()
		home_btn.text = "← 返回移动基地"
		home_btn.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
		home_btn.anchor_top = 1.0
		home_btn.anchor_bottom = 1.0
		home_btn.offset_left = 24.0
		home_btn.offset_right = 224.0
		home_btn.offset_top = -60.0
		home_btn.offset_bottom = -16.0
		home_btn.custom_minimum_size = Vector2(0, 44)
		# v23.6.1：走 PanelStyles 工厂四态（替换手写单态，圆角归按钮档 6）；v28 T2 迁渐变版
		var home_styles: Dictionary = PanelStyles.make_button_styles_graded(Color(1.0, 0.72, 0.32), "solid")
		for key in ["normal", "hover", "pressed", "disabled", "focus"]:
			home_btn.add_theme_stylebox_override(key, home_styles[key])
		home_btn.add_theme_color_override("font_color", Color(0.09, 0.07, 0.04))
		home_btn.add_theme_font_size_override("font_size", DT.FONT_SIZE_MEDIUM)
		home_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		home_btn.pressed.connect(_on_return_bunker_pressed)
		panel.add_child(home_btn)
		if not next_mode:
			btn.offset_left = 260.0
	if next_mode:
		# 主键收窄靠右；左侧补「返回整备」次键（旧继续路径：接收掉落 + 回整备）
		btn.offset_left = 460.0
		btn.offset_right = -24.0
		var prep_btn := Button.new()
		prep_btn.text = "返回整备"
		prep_btn.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
		prep_btn.anchor_top = 1.0
		prep_btn.anchor_bottom = 1.0
		prep_btn.offset_left = 240.0 if _bunker_return_available else 100.0
		prep_btn.offset_right = 440.0 if _bunker_return_available else 300.0
		prep_btn.offset_top = -60.0
		prep_btn.offset_bottom = -16.0
		prep_btn.custom_minimum_size = Vector2(0, 44)
		var prep_styles: Dictionary = PanelStyles.make_button_styles_graded(Color(0.58, 0.64, 0.60), "solid")
		for key in ["normal", "hover", "pressed", "disabled", "focus"]:
			prep_btn.add_theme_stylebox_override(key, prep_styles[key])
		prep_btn.add_theme_color_override("font_color", Color(0.88, 0.92, 0.90))
		prep_btn.add_theme_font_size_override("font_size", DT.FONT_SIZE_MEDIUM)
		prep_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		prep_btn.pressed.connect(_on_continue_pressed)
		panel.add_child(prep_btn)
	btn.grow_horizontal = Control.GROW_DIRECTION_BOTH
	btn.custom_minimum_size = Vector2(0, 44)
	# v23.6.1：走 PanelStyles 工厂四态（原仅 normal 有样式，无 hover/按下反馈）；v28 T2 渐变版
	var btn_accent: Color = DT.COLOR_GREEN_BRIGHT if next_mode else (DT.COLOR_GOLD if player_won else DT.COLOR_BORDER)
	var btn_styles: Dictionary = PanelStyles.make_button_styles_graded(btn_accent, "solid")
	for key in ["normal", "hover", "pressed", "disabled", "focus"]:
		btn.add_theme_stylebox_override(key, btn_styles[key])
	btn.add_theme_color_override("font_color", DT.COLOR_VOID)
	btn.add_theme_font_size_override("font_size", DT.FONT_SIZE_MEDIUM)
	if next_mode:
		btn.pressed.connect(_on_next_level_pressed)
	else:
		btn.pressed.connect(_on_continue_pressed)
	panel.add_child(btn)

## v34 B1：下一关直通条件——胜利 · 非挂机 · 教程已完（教程期战后要回基地续播）·
## 本战关号+1 在 1-100 且已解锁。下一关取 _pending_battle_level（本战实际打的关），
## 防"重打旧关后 current_level 已被推进到最高解锁关"时按钮指向跳变。
func _compute_next_level() -> int:
	if not player_won or _is_afk:
		return 0
	var root: Node = Engine.get_main_loop().root if Engine.get_main_loop() != null else null
	if root == null:
		return 0
	var tpm: Node = root.get_node_or_null("TutorialProgressionManager")
	if tpm != null and tpm.has_method("should_show_tutorial") and tpm.should_show_tutorial():
		return 0
	var gm: Node = root.get_node_or_null("GameManager")
	var lpm: Node = root.get_node_or_null("LevelProgressManager")
	if gm == null or lpm == null:
		return 0
	var played: int = int(gm.get("_pending_battle_level")) if "_pending_battle_level" in gm else int(gm.get("current_level"))
	var next: int = played + 1
	if next < 1 or next > 100:
		return 0
	if lpm.has_method("is_level_unlocked") and not lpm.is_level_unlocked(next):
		return 0
	return next

## v34 B1：下一关直通——接收掉落 + 淡出 + main.launch_next_level_from_settlement
## （清场/推进关号/出战报拍点/run_start_battle_sequence 开打，与挂机连续开战同管线）
func _on_next_level_pressed() -> void:
	result_confirmed.emit(player_won)
	ManagerLazyLoader.ensure_loaded("drop")  # DropManager 为 autoload+别名双层（ensure_loaded 幂等）
	var dm_claim: Node = Engine.get_main_loop().root.get_node_or_null("DropManager")
	if dm_claim != null and dm_claim.has_method("claim_drops"):
		dm_claim.claim_drops()
	var panel: Control = get_node_or_null("MvpPanelOverlay/Panel")
	var tw := create_tween()
	if panel != null:
		if DT.is_motion_reduce():
			panel.modulate.a = 0.0
		else:
			tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
			tw.tween_property(panel, "modulate:a", 0.0, DT.MOTION_FADE_OUT)
	tw.tween_callback(func():
		var parent: Node = get_parent()
		if parent != null and parent.has_method("launch_next_level_from_settlement"):
			parent.launch_next_level_from_settlement(_next_level)
		elif parent != null and parent.has_method("_on_result_confirmed"):
			parent._on_result_confirmed()
		queue_free()
	)


# =========================================================================
#  v22.4 要塞反馈区（P0-2：战斗→基地循环闭合）
# =========================================================================

## 打完仗的基地一览：修复进度推进/今日完工/精神状态（低精神折损提示）。
## v6.14：底部"返回移动基地"直达按钮不再要求从基地出击——移动基地是现役主枢纽，
## 任何手动战斗的结算都给（挂机结算仍不给，自动链无需中断）。从未进过基地的玩家
## （/root/BunkerManager 不存在）整区不显示，零干扰。
func _render_bunker_status(vbox: VBoxContainer) -> void:
	var bunker: Node = Engine.get_main_loop().root.get_node_or_null("BunkerManager") \
		if Engine.get_main_loop() != null else null
	if bunker == null or not bunker.has_method("get_day"):
		return
	_bunker_return_available = not _is_afk

	var mult: float = bunker.get_drop_reward_multiplier() \
		if bunker.has_method("get_drop_reward_multiplier") else 1.0
	var sanity_txt: String = "精神 %d" % int(round(bunker.get_sanity()))
	if mult < 1.0:
		sanity_txt += "（低精神：缴获 ×%.2f）" % mult
	# v30.1 R3（F-13）：标题行改可点折叠头（默认收起）——基地状态是每场都重复的
	# 长尾段，滚动疲劳主因；摘要信息（天数/精神/同伴数）留在标题行常显不丢。
	_bunker_title_base = "移动基地 · 第 %d 天 · %s · 同伴档案 %d/30" % [
		bunker.get_day(), sanity_txt, bunker.get_hero_fragment_count()]
	var head := Button.new()
	head.flat = true
	head.text = "▸ " + _bunker_title_base
	head.alignment = HORIZONTAL_ALIGNMENT_LEFT
	head.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	head.tooltip_text = "修复进度与精神状态——点击展开/收起"
	head.focus_mode = Control.FOCUS_NONE
	head.add_theme_font_size_override("font_size", DT.FONT_SIZE_BODY)
	head.add_theme_color_override("font_color", Color(1.0, 0.72, 0.32))
	head.add_theme_color_override("font_hover_color", Color(1.0, 0.85, 0.55))
	head.add_theme_color_override("font_pressed_color", Color(1.0, 0.72, 0.32))
	head.add_theme_color_override("font_focus_color", Color(1.0, 0.72, 0.32))
	head.pressed.connect(_toggle_bunker_body)
	vbox.add_child(head)
	_bunker_head = head

	_bunker_body = VBoxContainer.new()
	_bunker_body.visible = false   # v30.1：默认折叠
	_bunker_body.add_theme_constant_override("separation", 6)
	vbox.add_child(_bunker_body)

	# 低精神本战折损（game_manager 已实际扣除，这里只展示）
	var pen: Dictionary = _reward_summary.get("sanity_penalty", {})
	if not pen.is_empty():
		var pen_l := Label.new()
		pen_l.text = "  ⚠ 低精神折损：纳米材料 -%d · 能量块 -%d（医疗室/休整可恢复）" % [
			int(pen.get("nano", 0)), int(pen.get("energy", 0))]
		pen_l.add_theme_font_size_override("font_size", DT.FONT_SIZE_SMALL)
		pen_l.add_theme_color_override("font_color", Color(0.95, 0.55, 0.35))
		_bunker_body.add_child(pen_l)

	# 施工中的房间（进度已含本场推进）+ 今日完工
	var detail := Label.new()
	var parts: Array[String] = []
	for def in MobileBaseFacilities.get_all_rooms():
		var rid: String = def.get("id", "")
		if bunker.get_room_state(rid) == MobileBaseFacilities.STATE_REPAIRING:
			var pct: int = int(round(bunker.get_room_progress(rid) * 100.0))
			var frozen_txt: String = "（冻结·需反应堆）" if bunker.is_repair_frozen(rid) else ""
			parts.append("%s +%d%%%s" % [str(def.get("name", rid)), pct, frozen_txt])
	var done_names: Array[String] = []
	for entry in bunker.get_completed_today():
		done_names.append(MobileBaseFacilities.completed_entry_label(str(entry)))
	if not done_names.is_empty():
		parts.append("✔ 完工：" + "、".join(done_names))
	detail.text = "  " + ("；".join(parts) if not parts.is_empty() else "暂无施工中的房间——回移动基地可开工新修复")
	detail.add_theme_font_size_override("font_size", DT.FONT_SIZE_SMALL)
	detail.add_theme_color_override("font_color", Color(0.85, 0.78, 0.62))
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bunker_body.add_child(detail)


## v30.1 R3（F-13）：基地状态折叠头切换（▸ 收起 / ▾ 展开）
func _toggle_bunker_body() -> void:
	if _bunker_body == null or not is_instance_valid(_bunker_body):
		return
	_bunker_body.visible = not _bunker_body.visible
	if _bunker_head != null and is_instance_valid(_bunker_head):
		_bunker_head.text = ("▾ " if _bunker_body.visible else "▸ ") + _bunker_title_base

# =========================================================================
#  按钮回调（统一接收 + 返回准备界面）
# =========================================================================

func _on_continue_pressed() -> void:
	result_confirmed.emit(player_won)
	# 接收全部掉落
	ManagerLazyLoader.ensure_loaded("drop")  # DropManager 为 autoload+别名双层（ensure_loaded 幂等）
	var dm_claim: Node = Engine.get_main_loop().root.get_node_or_null("DropManager")
	if dm_claim != null and dm_claim.has_method("claim_drops"):
		dm_claim.claim_drops()
	# 淡出后返回准备界面。注意：CanvasLayer 没有 modulate 属性（见 _build 注释），
	# 因此淡出必须作用于面板内的 Control（Panel），不能作用于 overlay_layer。
	var panel: Control = get_node_or_null("MvpPanelOverlay/Panel")
	var tw := create_tween()
	if panel != null:
		if DT.is_motion_reduce():
			panel.modulate.a = 0.0
		else:
			# C7: 淡出统一 DT.MOTION_FADE_OUT + SINE
			tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
			tw.tween_property(panel, "modulate:a", 0.0, DT.MOTION_FADE_OUT)
	tw.tween_callback(func():
		var parent: Node = get_parent()
		if parent != null and parent.has_method("_on_result_confirmed"):
			parent._on_result_confirmed()
		queue_free()
	)

## v22.4（P0-2）：直接回移动基地——接收掉落 + 存档 + 清 meta + 切场景。
## 不走 main 的 _on_result_confirmed（那是"返回整备"路径），场景切换自然拆除战斗态。
func _on_return_bunker_pressed() -> void:
	ManagerLazyLoader.ensure_loaded("drop")
	var dm: Node = Engine.get_main_loop().root.get_node_or_null("DropManager")
	if dm != null and dm.has_method("claim_drops"):
		dm.claim_drops()
	if SaveManager and SaveManager.has_method("save_game"):
		SaveManager.save_game()
	if Engine.has_meta("launch_from_bunker"):
		Engine.remove_meta("launch_from_bunker")
	var panel: Control = get_node_or_null("MvpPanelOverlay/Panel")
	var tw := create_tween()
	if panel != null:
		if DT.is_motion_reduce():
			panel.modulate.a = 0.0
		else:
			tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
			tw.tween_property(panel, "modulate:a", 0.0, DT.MOTION_FADE_OUT)
	tw.tween_callback(func():
		# v26.12d：固定主基地停用，返回落移动基地（出击链 truck_base 设置本 meta）
		SceneTransition.change(get_tree(), "res://scenes/bunker/truck_base.tscn"))


# =========================================================================
#  战绩数据采集
# =========================================================================

func _collect_stats() -> Dictionary:
	# 优先从 BattleInfoDisplay.get_battle_stats() 取（实时统计）
	var bid: Node = get_node_or_null("/root/Main/HudLayer/BattleTopStatusBar/BattleInfoDisplay")
	if bid == null:
		# fallback：尝试全局查找
		var tree := get_tree()
		if tree != null:
			bid = _find_node_by_name(tree.root, "BattleInfoDisplay")
	if bid != null and bid.has_method("get_battle_stats"):
		return bid.get_battle_stats()
	return {}


func _find_node_by_name(root: Node, name: String) -> Node:
	if root.name == name:
		return root
	for c in root.get_children():
		var found := _find_node_by_name(c, name)
		if found != null:
			return found
	return null


## 击杀类型分布（前 3 类），来自 BattleManager._defeated_enemies
func _kill_type_breakdown() -> Array:
	var bm: Node = get_node_or_null("/root/BattleManager")
	if bm == null:
		return []
	var defeated: Array = []
	if "_defeated_enemies" in bm:
		defeated = bm.get("_defeated_enemies")
	if defeated.is_empty():
		return []
	# 按 enemy_type 聚合
	var counts: Dictionary = {}
	for e in defeated:
		var et: String = e.get("enemy_type", "infantry") if e is Dictionary else "infantry"
		counts[et] = int(counts.get(et, 0)) + 1
	# 排序取前 3
	var sorted: Array = counts.keys()
	sorted.sort_custom(func(a, b): return counts[a] > counts[b])
	var out: Array = []
	for i in range(mini(3, sorted.size())):
		out.append("%s ×%d" % [_type_display_name(sorted[i]), counts[sorted[i]]])
	return out


## v26.13(gameplay)：把 {type: count} 快照格式化为前 3 名文案（同 _kill_type_breakdown 输出）
func _format_type_counts(counts: Dictionary) -> Array:
	var sorted: Array = counts.keys()
	sorted.sort_custom(func(a, b): return counts[a] > counts[b])
	var out: Array = []
	for i in range(mini(3, sorted.size())):
		out.append("%s ×%d" % [_type_display_name(str(sorted[i])), int(counts[sorted[i]])])
	return out


func _type_display_name(t: String) -> String:
	match t:
		"infantry": return "步兵"
		"armor", "tank": return "装甲"
		"artillery": return "火炮"
		"anti_air": return "防空"
		"air": return "空军"
		"recon": return "侦察"
		"engineer": return "工兵"
		"fort": return "堡垒"
		_: return t


# =========================================================================
#  败因分析（v27：失败产出知识——productive failure）
# =========================================================================

## 残存敌军构成：结算面板存活期（战场在确认后才清理）扫描 EnemyUnits。
## 敌方兵种判定复用 BattleManager._guess_enemy_type_from_archetype（同 _defeated_enemies 口径）。
func _alive_enemy_breakdown() -> Dictionary:
	var main := get_parent()
	if main == null or not is_instance_valid(main) or not main.has_method("_get_battlefield"):
		return {}
	var bf: Node2D = main._get_battlefield()
	if bf == null:
		return {}
	var eu: Node = bf.get_node_or_null("EnemyUnits")
	if eu == null:
		return {}
	var bm: Node = get_node_or_null("/root/BattleManager")
	var counts: Dictionary = {}
	for c in eu.get_children():
		if c == null or not is_instance_valid(c):
			continue
		var hp_val = c.get("hp")
		if hp_val != null and float(hp_val) <= 0.0:
			continue
		var aid = c.get("archetype_id")
		if aid == null or str(aid).is_empty():
			continue
		var et: String = "infantry"
		if bm != null and bm.has_method("_guess_enemy_type_from_archetype"):
			et = str(bm.call("_guess_enemy_type_from_archetype", str(aid), []))
		counts[et] = int(counts.get(et, 0)) + 1
	return counts

## 克制建议（按残存敌军构成给最多 3 条；口径与战斗克制链一致：对空封锁/装甲碾压/曲射压制）
const _COUNTER_ADVICE: Dictionary = {
	"armor": "装甲单位多——部署火炮/反坦克单位，或给主力安装穿甲类改造",
	"air": "空中单位多——需要防空单位（对空特化 +25%），其余地面单位无法对空",
	"infantry": "轻步兵集群——机枪/范围伤害类单位清扫效率最高",
	"fort": "堡垒/重装单位——用曲射单位（迫击炮/火炮）在对方射程外压制",
	"artillery": "敌方火炮威胁大——高机动单位快速突进斩首，避免战线僵持对轰",
	"anti_air": "敌方防空压制我方空军——先以地面单位拔点，再投入空中战斗卡",
	"recon": "侦察渗透骚扰后排——增补前排防线单位，堵住缺口",
	"engineer": "工兵近身爆破——优先提升前排防护（堡垒/装甲）",
}

func _render_defeat_analysis(vbox: VBoxContainer) -> void:
	var sec_title := Label.new()
	sec_title.text = "▍败因分析"
	sec_title.add_theme_font_size_override("font_size", DT.FONT_SIZE_MEDIUM)
	sec_title.add_theme_color_override("font_color", Color(1.0, 0.55, 0.35, 1.0))
	vbox.add_child(sec_title)

	var body := Label.new()
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_theme_font_size_override("font_size", DT.FONT_SIZE_SMALL)
	body.add_theme_color_override("font_color", DT.COLOR_TEXT_BRIGHT)

	var lines: Array = []
	# v26.13(gameplay)：优先读 end_battle 定格的败因快照（实机 P1：渲染窗口里
	# 战场/数组已脱离可读状态，活读恒空）；快照缺失时回退活读。
	var bm: Node = get_node_or_null("/root/BattleManager")
	var res_snap = bm.get("_battle_result") if bm != null else null
	var snap_alive: Dictionary = (res_snap.get("defeat_alive_by_type", {}) if res_snap is Dictionary else {})
	var alive: Dictionary = snap_alive if not snap_alive.is_empty() else _alive_enemy_breakdown()
	if alive.is_empty():
		lines.append("· 敌军构成：未能记录（战场已清场）")
	else:
		var keys: Array = alive.keys()
		keys.sort_custom(func(a, b): return alive[a] > alive[b])
		var parts: Array = []
		for i in range(mini(4, keys.size())):
			parts.append("%s×%d" % [_type_display_name(str(keys[i])), int(alive[keys[i]])])
		lines.append("· 残存敌军：" + "　".join(parts))
		# 克制建议：按残存数量取构成前 3 的兵种
		var advised: int = 0
		for k in keys:
			var tip: String = str(_COUNTER_ADVICE.get(str(k), ""))
			if not tip.is_empty():
				lines.append("· 建议：" + tip)
				advised += 1
				if advised >= 3:
					break
	var snap_kills: Dictionary = (res_snap.get("defeat_kills_by_type", {}) if res_snap is Dictionary else {})
	var killed: Array = _format_type_counts(snap_kills) if not snap_kills.is_empty() else _kill_type_breakdown()
	lines.append("· 本场击杀：" + ("、".join(killed) if not killed.is_empty() else "无"))
	lines.append("· 情报：在情报舱把对应敌种情报推到 75%+ 可解锁弱点/抗性提示")
	lines.append("· 整备：提升卡牌等级/改造/制造高品质卡后再战，或稍后以大招手动模式蓄势攻坚 Boss 波")
	body.text = "\n".join(lines)
	vbox.add_child(body)


## 星级评定：基于击杀比/损失比/时长（1~3 星）
func _compute_stars(stats: Dictionary) -> int:
	if not player_won:
		return 1
	# v26.13(gameplay) 修复：此前 kills 读 enemy_kills（敌方击杀我方数）当击杀门槛、
	# losses 读 player_kills 当损失——星级评定与实际战果相反。
	var kills: int = int(stats.get("player_kills", 0))
	var losses: int = int(stats.get("enemy_kills", 0))
	var time_s: float = float(stats.get("battle_time", 0.0))
	var stars: int = 1
	# 击杀数门槛
	if kills >= 8:
		stars += 1
	if kills >= 20:
		stars += 1
	# 损失扣星
	if losses > kills * 0.8 and kills > 0:
		stars = max(1, stars - 1)
	# 时长加成（速胜）
	if time_s > 0 and time_s < 60 and kills >= 5:
		stars = min(3, stars + 1)
	return clampi(stars, 1, 3)


func _star_text(stars: int) -> String:
	var s := ""
	for i in range(3):
		s += "★" if i < stars else "☆"
	return s


## 星级逐个亮起动画（胜利时增强仪式感）
func _animate_stars() -> void:
	if _star_lbl == null:
		return
	# 解析星数（"★" 个数）
	var lit_count: int = 0
	for ch in _star_lbl.text:
		if ch == "★":
			lit_count += 1
	# 预构建每个亮起阶段的状态字符串，避免闭包捕获循环变量
	var states: Array[String] = []
	for i in range(lit_count + 1):
		var s := ""
		for j in range(3):
			s += "★" if j < i else "☆"
		states.append(s)
	# 初始全暗
	_star_lbl.text = states[0]
	_star_lbl.add_theme_color_override("font_color", DT.COLOR_TEXT_DIM)
	# 逐个亮起（每阶段用循环内局部变量捕获，确保各自独立）
	var tw := create_tween()
	for i in range(1, lit_count + 1):
		var target_text: String = states[i]
		tw.tween_callback(func():
			_star_lbl.text = target_text
		)
		tw.tween_interval(0.12)
	# 全部亮起后恢复金色
	tw.tween_callback(func():
		_star_lbl.add_theme_color_override("font_color", DT.COLOR_GOLD)
	)


# =========================================================================
#  掉落辅助方法（从 battle_result_dialog.gd 移植）
# =========================================================================

static func _drop_type_is_card_lane(t: int) -> bool:
	return (
		t == DropTables.DropType.CARD_DATA
		or t == DropTables.DropType.DROPPED_CARD
		or t == DropTables.DropType.CARD_REWARD
		or t == DropTables.DropType.ENERGY_CARD
		or t == DropTables.DropType.STAT_BOOST
		or t == DropTables.DropType.LAW_CARD
		or t == DropTables.DropType.LAW_DATA
		or t == DropTables.DropType.LAW_BLUEPRINT
		or t == DropTables.DropType.ENERGY_DATA
		or t == DropTables.DropType.ENERGY_BLUEPRINT
		or t == DropTables.DropType.BLUEPRINT_FRAGMENT
	)


## 扫描 DropManager 待接收掉落，统计已在"本关缴获"区汇总的 MATERIAL 资源总量。
## 这些资源（nano_materials / energy_block）会合并到顶部汇总行显示，
## 故需从"战斗掉落"列表中过滤掉，避免同一资源在面板上重复出现。
## 返回 {"nano_materials": int, "energy_block": int}
static func _summarize_pending_materials(dm: Node) -> Dictionary:
	var totals: Dictionary = {"nano_materials": 0, "energy_block": 0}
	if dm == null or not dm.has_method("get_pending_drops"):
		return totals
	for dr in dm.get_pending_drops():
		if not (dr is DropTables.DropResult):
			continue
		if dr.drop.type != DropTables.DropType.MATERIAL:
			continue
		var item_id: String = String(dr.drop.item_id)
		# basic_nano 是旧 ID，映射到 nano_materials（与 drop_manager._add_material 一致）
		if item_id == "basic_nano":
			item_id = "nano_materials"
		if totals.has(item_id):
			totals[item_id] = int(totals[item_id]) + int(dr.count)
	return totals


## 判断某掉落是否属于"已在顶部汇总的 MATERIAL 资源"（需从掉落列表过滤掉）
static func _is_summarized_material(dr) -> bool:
	if not (dr is DropTables.DropResult):
		return false
	if dr.drop.type != DropTables.DropType.MATERIAL:
		return false
	var item_id: String = String(dr.drop.item_id)
	return item_id == "nano_materials" or item_id == "energy_block" or item_id == "basic_nano"


# =========================================================================
#  情报揭示弹窗（从 battle_result_dialog.gd 移植）
# =========================================================================

func _show_intel_reveal_popup(reveal_events: Array) -> void:
	if reveal_events.is_empty():
		return
	# 找到 PopupLayer 挂载点
	var tree := get_tree()
	if tree == null:
		return
	var main_scene := tree.current_scene
	var popup_layer: Node = null
	if main_scene:
		popup_layer = main_scene.get_node_or_null("PopupLayer")
	if popup_layer == null:
		popup_layer = tree.root  # 兜底
	# 创建并展示揭示弹窗
	var IntelRevealPopupClass = load("res://scenes/ui/intel_reveal_popup.gd")
	if IntelRevealPopupClass == null:
		return
	var popup = IntelRevealPopupClass.create(popup_layer)
	popup.show_reveals(reveal_events)


## 改造解锁批量弹窗（结算时调用，与 _show_intel_reveal_popup 同模式）
func _show_mod_unlock_popup(title: String, description: String) -> void:
	FeatureUnlockPopup.show_now(title, description)


# =========================================================================
#  辅助 UI
# =========================================================================

func _make_separator() -> HSeparator:
	var sep := HSeparator.new()
	sep.add_theme_constant_override("separation", 4)
	return sep


func _add_data_row(grid: GridContainer, label: String, value: String, color: Color) -> void:
	var l := Label.new()
	l.text = label
	l.add_theme_font_size_override("font_size", DT.FONT_SIZE_SMALL)
	l.add_theme_color_override("font_color", DT.COLOR_TEXT_DIM)
	grid.add_child(l)
	var v := Label.new()
	v.text = value
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	v.add_theme_font_size_override("font_size", DT.FONT_SIZE_MEDIUM)
	v.add_theme_color_override("font_color", color)
	grid.add_child(v)


func _format_time(sec: float) -> String:
	var m: int = int(sec) / 60
	var s: int = int(sec) % 60
	return "%d:%02d" % [m, s]
