# -*- coding: utf-8 -*-
"""§4.11 双轨商店收口：store_panel 主卡列表退役 + CompanyStore 删除 + perf_smoke 清理（势力批1）"""
import io
import re

fails = []


def rep(path, old, new, tag, count=1):
    s = io.open(path, encoding='utf-8').read()
    if old not in s:
        fails.append(tag)
        return
    s = s.replace(old, new, count)
    io.open(path, 'w', encoding='utf-8', newline='\n').write(s)


P = 'scenes/ui/store_panel.gd'

# 1. 头部 preload：删 CompanyStore + 五个孤儿化 preload
rep(P, '''const CompanyDefs = preload("res://data/company_definitions.gd")
const CompanyStore = preload("res://data/company_store.gd")
const BasicResources = preload("res://data/basic_resources.gd")
const DefaultCards = preload("res://data/default_cards.gd")
const GC = preload("res://resources/game_constants.gd")
const IntelManualItems = preload("res://data/intel_manual_items.gd")
const UnitStatsTable = preload("res://resources/unit_stats_table.gd")
const ModRegistry = preload("res://scripts/systems/modification_registry.gd")
const StoreItemRowScene = preload("res://scenes/ui/store_item_row.tscn")
const FormatUtil = preload("res://scripts/ui/format_util.gd")
const UiAssetLoader = preload("res://scripts/ui_asset_loader.gd")
const UnifiedCardTable = preload("res://data/unified_card_table.gd")  # v20.13c: 商店预览每卡部署次数
''', '''const CompanyDefs = preload("res://data/company_definitions.gd")
const BasicResources = preload("res://data/basic_resources.gd")
const DefaultCards = preload("res://data/default_cards.gd")
const IntelManualItems = preload("res://data/intel_manual_items.gd")
const ModRegistry = preload("res://scripts/systems/modification_registry.gd")
const FormatUtil = preload("res://scripts/ui/format_util.gd")
''', 'preloads')

# 2. 默认页签：CompanyStore.get_default_company_id() → CompanyDefs 首个 id
rep(P, '''	if _current_company_id.is_empty():
		_current_company_id = CompanyStore.get_default_company_id()
''', '''	if _current_company_id.is_empty():
		_current_company_id = String(companies[0].get("id", ""))
''', 'default_tab')

# 3. _buy_in_progress 变量删（唯一用点在待删的 _on_buy_pressed）
rep(P, 'var _buy_in_progress: bool = false\n', '', 'buy_in_progress_var')

# 4. _refresh_items 主卡列表整删
rep(P, '''	var items: Array[Dictionary] = CompanyStore.get_items_for_company(_current_company_id)
	if items.is_empty():
		var empty_l := Label.new()
		empty_l.text = "该公司暂未开放商品。"
		empty_l.add_theme_color_override("font_color", DT.COLOR_TEXT_DIM)
		empty_l.add_theme_font_size_override("font_size", DT.FONT_SIZE_SMALL)
		empty_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		item_list.add_child(empty_l)
		return

	var current_nano: int = BasicResourceManager.get_total(BasicResources.ID_NANO_MATERIALS)

	var fsm: Node = get_node_or_null("/root/FactionSystemManager")
	var current_rep: int = 0
	if fsm != null and fsm.has_method("get_faction_reputation"):
		current_rep = int(fsm.get_faction_reputation(_current_company_id))
	# R1-3（设计审查 F-04，2026-09-13）：声望门槛复活——company_store.json 的
	# required_rep 是 0-100 旧轴口径（旧代码 tier=rep/10），而运行时声望真轴是
	# 0-10000（起始 5000，faction_reputation.gd），直接比较恒为"已满足"，
	# 打码/锁定逻辑从未触发。此处统一按 ×100 边界换算到真轴；
	# 档位（梯度差/打码）改按声望等级（1-10）计算，与势力面板同口径。
	var current_tier: int = FactionReputation.get_level_from_reputation(current_rep) - 1

	# 检查是否启用全局访问
	var global_access: bool = _has_global_access()

	for it in items:
		if not it is Dictionary:
			continue
		var card_id: String = it.get("card_id", "")
		var frag_amount: int = int(it.get("fragment_amount", 1))
		var price_nano: int = int(it.get("price_nano_materials", 0))
		# R1-3：JSON 旧轴 0-100 → 声望真轴 0-10000（×100 边界换算，显示与判定同源）
		var required_rep: int = int(it.get("required_rep", 0)) * 100
		var item_tier: int = FactionReputation.get_level_from_reputation(required_rep) - 1
		var card_name: String = card_id
		var card = null

		# v9.x 复查清理：原"先从敌方蓝图表查找"块删除——enemy_bp 恒 null（自 5 月起死代码），
		# 两个 elif 条件重复且永不可达；商品名直接走 DefaultCards 解析
		var enemy_bp = null
		card = DefaultCards.get_card_by_id(card_id)
		if card:
			card_name = card.display_name
		elif card_id.begins_with("permit_card_"):
			var target_id: String = card_id.trim_prefix("permit_card_")
			var target_card: CardResource = DefaultCards.get_card_by_id(target_id)
			var target_name: String = target_card.display_name if target_card != null else target_id
			card_name = "改造许可函·%s专属" % target_name
		elif LEGACY_BLUEPRINT_DISPLAY_NAMES.has(card_id):
			card_name = String(LEGACY_BLUEPRINT_DISPLAY_NAMES[card_id])
		# v3 后所有战斗卡都是 COMBAT_UNIT，可以正常在商店售卖
		# 原错误代码过滤了 COMBAT_UNIT 导致所有战斗卡被隐藏，现已移除
		# var inspect_card = enemy_bp if enemy_bp != null else card
		# if inspect_card != null and int(inspect_card.card_type) == GC.CardType.COMBAT_UNIT:
		# 	continue

		# 高等级商品名称打码（梯度差 > 1 视为超出当前进度）
		var masked: bool = item_tier > current_tier + 1
		if masked:
			card_name = "？？ 未知卡牌 ？？"

		var locked: bool = current_rep < required_rep and not global_access
		var afford: bool = current_nano >= price_nano

		var row_panel: PanelContainer = _build_store_item_row(
			card_id, card_name, frag_amount, price_nano, required_rep, current_rep,
			locked, afford, enemy_bp, card, masked, item_tier - current_tier
		)
		item_list.add_child(row_panel)

	# ═══ v6.2: 符文售卖区 ═══
	_build_rune_items_section(current_rep)

	# ═══ v26.11(A1.2): 势力补给 · 声望特购区 ═══
	# FactionShop 返回四类商品，此前 UI 只渲染 RUNE——MATERIAL（纳米/合金/属性强化/
	# 情报资料包）与不在公司目录 JSON 里的 CARD（缴获卡/终赢单位）全部不可见
	_build_faction_shop_extras_section(current_rep, items)

	# ═══ v6.0: 情报道具售卖区 ═══
	_build_intel_items_section()
''', '''	var fsm: Node = get_node_or_null("/root/FactionSystemManager")
	var current_rep: int = 0
	if fsm != null and fsm.has_method("get_faction_reputation"):
		current_rep = int(fsm.get_faction_reputation(_current_company_id))
	# v6.22: CompanyStore 纳米主卡列表已随双轨商店收口整删——四区结构收敛为三区
	# （符文功勋轨 / 势力补给功勋特购 / 情报道具纳米轨），卡片获取改走制造/掉落/任务。

	# ═══ v6.2: 符文售卖区 ═══
	_build_rune_items_section(current_rep)

	# ═══ v26.11(A1.2): 势力补给 · 功勋特购区 ═══
	_build_faction_shop_extras_section(current_rep)

	# ═══ v6.0: 情报道具售卖区 ═══
	_build_intel_items_section()
''', 'refresh_items')

# 5. 特购区：删 company_items 去重参与
rep(P, '''## - CARD（type 0）：与公司目录 JSON（上方纳米购买区）按 card_id 去重，只渲染差额
##   特购（bp_ 缴获卡、omega_cannon 等），扣声望+发独立养成实例
## - 有限库存商品显示"剩余N"，归零禁购——can_purchase_item 的 out_of_stock
##   分支首次有了 UI 呈现（库存侧的上下架消费端即此；add/remove_item_to_store
##   保留为预留接口）
func _build_faction_shop_extras_section(_current_rep: int, company_items: Array) -> void:
''', '''## - CARD（type 0）：全量渲染（v6.22: 公司目录 JSON 已删，无去重对象）
## - 有限库存商品显示"剩余N"，归零禁购——can_purchase_item 的 out_of_stock
##   分支首次有了 UI 呈现（库存侧的上下架消费端即此；add/remove_item_to_store
##   保留为预留接口）
func _build_faction_shop_extras_section(_current_rep: int) -> void:
''', 'extras_sig')

rep(P, '''	var all_items: Array = fsm.get_faction_store_items(_current_company_id)
	# 公司目录已上架的卡（纳米价，上方主列表）——特购区跳过，避免同卡双轨重复售卖
	var listed_cards: Dictionary = {}
	for it in company_items:
		if it is Dictionary:
			listed_cards[String(it.get("card_id", ""))] = true
	var extras: Array = []
	for it in all_items:
		if it == null:
			continue
		var t: int = int(it.item_type)
		if t == 1:  # StoreItemType.MATERIAL
			extras.append(it)
		elif t == 0 and not listed_cards.has(String(it.item_id)):  # CARD 且不在主目录
			extras.append(it)
''', '''	var all_items: Array = fsm.get_faction_store_items(_current_company_id)
	var extras: Array = []
	for it in all_items:
		if it == null:
			continue
		var t: int = int(it.item_type)
		if t == 1:  # StoreItemType.MATERIAL
			extras.append(it)
		elif t == 0:  # StoreItemType.CARD（v6.22: 主目录已删，CARD 全量渲染）
			extras.append(it)
''', 'extras_body')

# 6. _build_store_item_row + _on_buy_pressed 整删（regex 锚定）
s = io.open(P, encoding='utf-8').read()
pat = re.compile(r'\n\nfunc _build_store_item_row\(.*?call_deferred\("_refresh_items"\)\n', re.S)
s2, n = pat.subn('\n\n', s)
if n != 1:
    fails.append('big_row_delete(n=%d)' % n)
else:
    s = s2
io.open(P, 'w', encoding='utf-8', newline='\n').write(s)

# 7. perf_smoke.gd：删 CompanyStore.ITEMS 段
Q = 'tests/perf_smoke.gd'
rep(Q, '''	# CompanyStore.ITEMS 同样验证
	var c_inited_before := CompanyStore._items_inited
	var items_data := CompanyStore.ITEMS
	var c_inited_after := CompanyStore._items_inited
	print("  ITEMS 访问前 _inited: ", c_inited_before, " → 访问后: ", c_inited_after, " / 数据量: ", items_data.size())
	if not c_inited_after:
		fail.call("ITEMS 访问后 _inited 应为 true")

	# EnemyArchetypes.ARCHETYPES
''', '''	# v6.22: CompanyStore.ITEMS 验证段已随双轨商店收口删除。

	# EnemyArchetypes.ARCHETYPES
''', 'perf_smoke')
rep(Q, 'const CompanyStore = preload("res://data/company_store.gd")\n', '', 'perf_smoke_preload')

print("FAILS:", fails if fails else "none")
