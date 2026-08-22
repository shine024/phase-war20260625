extends SceneTree
## tests/_tmp_batch2a_law_chain_check.gd — 批次2a（P2-7 范围A 法则卡链路退役）验证
## ① 全部 12 个改动文件可加载（语法层）
## ② 势力商店无法则卡在售、4 张断链蓝图已下架、符文商品仍在（正路径）
## ③ 背包数据层：旧档法则 id 静默跳过、战斗卡正常解析
## ④ 拖拽校验：红/蓝槽不再接受法则卡，绿槽战斗卡不受影响
## ⑤ 源文本：掉落/发放/迁移函数族已移除；create_law_card_resource 按计划保留（2b/2c 用）
## Usage: godot --headless --rendering-driver opengl3 --path . --script tests/_tmp_batch2a_law_chain_check.gd

const BROKEN_BP_IDS: Array[String] = ["bp_cold_014", "bp_cold_020", "bp_modern_011", "bp_near_012"]
const FACTIONS: Array[String] = [
	"iron_wall_corp", "nova_arms", "aether_dynamics",
	"quantum_logistics", "helix_recon", "void_research", "frontier_union",
]

func _is_law_id(id: String) -> bool:
	# 用 PhaseLaws 权威表判定（前缀法会误伤 void_research 势力符文 id 如 void_01）
	var PhaseLawsRef = load("res://data/phase_laws.gd")
	return not PhaseLawsRef.get_by_id(id).is_empty()

func _read_file(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return ""
	var s := f.get_as_text()
	f.close()
	return s

func _initialize() -> void:
	var errs: Array[String] = []

	# ── ① 改动文件加载 ──
	var files: Array[String] = [
		"res://managers/faction/faction_shop.gd",
		"res://managers/drop_manager.gd",
		"res://scripts/card_drop_grants.gd",
		"res://scenes/ui/backpack/backpack_data.gd",
		"res://scenes/ui/backpack/backpack_presenter.gd",
		"res://scenes/ui/backpack_card_item.gd",
		"res://scenes/ui/card_info_panel.gd",
		"res://scenes/ui/store_panel.gd",
		"res://scenes/ui/instrument_bar_drag.gd",
		"res://managers/phase_instrument_loadout_sync.gd",
		"res://managers/phase_instrument_manager.gd",
		"res://managers/save_manager.gd",
	]
	for fp in files:
		var scr = load(fp)
		if scr == null:
			errs.append("加载失败: " + fp)

	var FactionShop = load("res://managers/faction/faction_shop.gd")
	var DefaultCards = load("res://data/default_cards.gd")
	var BackpackData = load("res://scenes/ui/backpack/backpack_data.gd")
	var Drag = load("res://scenes/ui/instrument_bar_drag.gd")

	# ── ② 商店：无法则卡、无断链蓝图、符文正路径 ──
	for fid in FACTIONS:
		var items: Array = FactionShop.get_faction_store_items(fid, 5)
		if items.is_empty():
			errs.append("商店商品为空: %s" % fid)
		var rune_count: int = 0
		var rune_type: int = FactionShop.StoreItemType.RUNE
		for it in items:
			if _is_law_id(it.item_id):
				errs.append("商店仍在售法则卡: %s -> %s" % [fid, it.item_id])
			if BROKEN_BP_IDS.has(it.item_id):
				errs.append("断链蓝图未下架: %s -> %s" % [fid, it.item_id])
			if int(it.item_type) == rune_type:
				rune_count += 1
		if rune_count <= 0:
			errs.append("符文商品缺失（正路径）: %s" % fid)
		var inv: Array = FactionShop.get_default_store_inventory(fid)
		for iid in inv:
			if _is_law_id(String(iid)):
				errs.append("默认库存仍含法则 id: %s -> %s" % [fid, iid])

	# ── ③ 背包数据层：法则 id 静默跳过 ──
	var bd = BackpackData.new()
	bd.restore_extra_cards(["ww1_mp18", "steel_phase_armor", "law:thunder_emp_storm"])
	var cards: Array = bd.get_all_cards()
	if cards.size() != 1:
		errs.append("背包应只剩 1 张战斗卡（法则 id 应被跳过），实际 %d" % cards.size())
	elif String(cards[0].card_id) != "ww1_mp18":
		errs.append("背包剩余卡非 ww1_mp18: %s" % String(cards[0].card_id))
	var stats: Dictionary = bd.get_statistics()
	if stats.has("law_cards"):
		errs.append("stats 仍含 law_cards 死字段")

	# ── ④ 拖拽校验 ──
	var law_card = DefaultCards.create_law_card_resource("thunder_emp_storm")
	var combat_card = DefaultCards.get_card_by_id("ww1_mp18")
	if law_card == null or combat_card == null:
		errs.append("create_law_card_resource（应保留）/get_card_by_id 返回 null")
	else:
		if Drag.card_matches_slot_color(law_card, "red"):
			errs.append("红槽仍接受法则卡")
		if Drag.card_matches_slot_color(law_card, "blue"):
			errs.append("蓝槽仍接受法则卡")
		if not Drag.card_matches_slot_color(combat_card, "green"):
			errs.append("绿槽战斗卡正路径受影响")

	# ── ⑤ 源文本：函数族移除 + 保留项 ──
	var src_checks: Array = [
		["res://managers/drop_manager.gd", "func _add_law_card", false],
		["res://managers/drop_manager.gd", "func _add_law_blueprint", false],
		["res://managers/drop_manager.gd", "func _pick_random_law_blueprint", false],
		["res://scripts/card_drop_grants.gd", "func grant_law_cards_to_backpack", false],
		["res://managers/save_manager.gd", "func migrate_law_slots_from_phase_law_manager_if_empty", false],
		["res://managers/phase_instrument_manager.gd", "func migrate_law_slots_from_phase_law_manager_if_empty", false],
		["res://managers/phase_instrument_loadout_sync.gd", "func migrate_law_slots_from_phase_law_manager_if_empty", false],
		["res://data/default_cards.gd", "func create_law_card_resource", true],
	]
	for ck in src_checks:
		var src := _read_file(String(ck[0]))
		var found: bool = src.find(String(ck[1])) >= 0
		if found != bool(ck[2]):
			errs.append("源文本断言失败: %s 含 '%s' 期望 %s" % [ck[0], ck[1], ck[2]])

	if errs.is_empty():
		print("BATCH2A CHECK: ALL PASS")
		quit(0)
	else:
		for e in errs:
			printerr("FAIL: " + e)
		quit(1)
