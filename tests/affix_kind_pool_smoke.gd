# v19 词条系统兵种分池 + 特殊兵种独特词条 smoke test
# 验证：
#   1) 改动文件全部可编译加载
#   2) AFFIX_TABLE 新增 15 词条的结构（combat_kinds / min_tier / 槽类型）
#   3) is_affix_available_for / get_ids_for_combat_kind 过滤正确性
#   4) roll_unlocked_affix_id 兵种/tier 过滤（统计验证：不串池、独特词条档位门槛）
#   5) _roll_milestone_affix 兵种参数全链路（AffixManager 层）
#   6) 空转 effect_key 修复（defense / dodge_chance / crit_damage_bonus 写入 UnitStats）
#   7) CardResource.tier 透传（UCT 构建 / clone / 势力专属卡映射）
#
# 不依赖 GdUnit，直接 extends SceneTree。
# 注：--script 模式下 autoload 不初始化——on_card_level_up_instance 取不到实例卡时
#     combat_kind 回退 -1（通用池），行为与 v18.c 完全一致（向后兼容）。
#
# Usage: godot --headless --rendering-driver opengl3 --path . --script tests/affix_kind_pool_smoke.gd
extends SceneTree

const AffixDefs = preload("res://data/affix_definitions.gd")
const AffixManagerScript = preload("res://managers/affix_manager.gd")
const AffixResourceScript = preload("res://resources/affix_resource.gd")
const UnitStatsScript = preload("res://resources/unit_stats.gd")
const CardResourceScript = preload("res://resources/card_resource.gd")
const UnifiedCardTable = preload("res://data/unified_card_table.gd")
const FactionExclusiveCards = preload("res://data/faction_exclusive_cards.gd")

## v19 新增词条 ID → {combat_kinds, min_tier, card_type_filter}
const NEW_AFFIXES: Dictionary = {
	# 兵种专属（每兵种 2 个）
	"light_skirmish":    {"kinds": [0], "tier": 0, "filter": 0},
	"light_evasion":     {"kinds": [0], "tier": 0, "filter": 0},
	"armor_column":      {"kinds": [1], "tier": 0, "filter": 0},
	"armor_plating":     {"kinds": [1], "tier": 0, "filter": 0},
	"air_dive":          {"kinds": [3], "tier": 0, "filter": 1},
	"air_supremacy":     {"kinds": [3], "tier": 0, "filter": 1},
	"support_outrange":  {"kinds": [2], "tier": 0, "filter": 1},
	"support_repair":    {"kinds": [2], "tier": 0, "filter": 0},
	"fort_bulwark":      {"kinds": [4], "tier": 0, "filter": 0},
	"fort_crossfire":    {"kinds": [4], "tier": 0, "filter": 1},
	# 特殊兵种独特（min_tier=3 CHAMPION）
	"light_executioner": {"kinds": [0], "tier": 3, "filter": 1},
	"armor_titan":       {"kinds": [1], "tier": 3, "filter": 0},
	"air_reaper":        {"kinds": [3], "tier": 3, "filter": 1},
	"support_orbital":   {"kinds": [2], "tier": 3, "filter": 1},
	"fort_protocol":     {"kinds": [4], "tier": 3, "filter": 0},
}

const GENERIC_COUNT: int = 16  # v19 前 AFFIX_TABLE 已有 16 个通用词条


func _initialize() -> void:
	var code := [0]
	var fail := func(msg: String) -> void:
		push_error("[FAIL] " + msg)
		code[0] = 1
	randomize()

	print("═══════════════════════════════════════════════════════════")
	print("  v19 词条兵种分池 + 特殊兵种独特词条 验证")
	print("═══════════════════════════════════════════════════════════")

	# ══════════ 1. 编译加载 ══════════
	print("\n[1] 编译加载 6 个改动文件")
	for p in [
		"res://data/affix_definitions.gd",
		"res://managers/affix_manager.gd",
		"res://resources/card_resource.gd",
		"res://resources/affix_resource.gd",
		"res://data/unified_card_table.gd",
		"res://data/faction_exclusive_cards.gd",
	]:
		if load(p) == null:
			fail.call("无法加载 %s" % p)
	print("  加载全部 OK")

	# ══════════ 2. 新词条结构 ══════════
	print("\n[2] AFFIX_TABLE 新增 15 词条结构")
	if AffixDefs.AFFIX_TABLE.size() != GENERIC_COUNT + NEW_AFFIXES.size():
		fail.call("词条总数应为 %d，实得 %d" % [GENERIC_COUNT + NEW_AFFIXES.size(), AffixDefs.AFFIX_TABLE.size()])
	for id in NEW_AFFIXES:
		var expect: Dictionary = NEW_AFFIXES[id]
		var def: Dictionary = AffixDefs.get_definition(String(id))
		if def.is_empty():
			fail.call("缺少词条定义 %s" % id)
			continue
		var kinds: Array = def.get("combat_kinds", []) as Array
		if kinds != expect.kinds:
			fail.call("%s combat_kinds 应为 %s，实得 %s" % [id, str(expect.kinds), str(kinds)])
		if int(def.get("min_tier", -1)) != expect.tier:
			fail.call("%s min_tier 应为 %d，实得 %d" % [id, expect.tier, int(def.get("min_tier", -1))])
		if int(def.get("card_type_filter", -1)) != expect.filter:
			fail.call("%s card_type_filter 应为 %d，实得 %d" % [id, expect.filter, int(def.get("card_type_filter", -1))])
		if not (AffixDefs.MUTATION_TABLE as Dictionary).has(String(id)):
			fail.call("%s 缺少变异描述" % id)
	# 旧 15 词条不得带兵种限定（向后兼容）
	for id in AffixDefs.AFFIX_TABLE.keys():
		if not NEW_AFFIXES.has(String(id)):
			var kinds_old: Array = (AffixDefs.AFFIX_TABLE[id] as Dictionary).get("combat_kinds", []) as Array
			if not kinds_old.is_empty():
				fail.call("旧词条 %s 不应带 combat_kinds 限定" % id)
	print("  结构 OK（15 新词条字段齐全，旧 15 词条保持通用）")

	# ══════════ 3. 过滤查询 ══════════
	print("\n[3] is_affix_available_for / get_ids_for_combat_kind")
	# 兵种不匹配 → 不可用
	if AffixDefs.is_affix_available_for("armor_column", 0, 5):
		fail.call("armor_column 对轻装不应可用")
	if AffixDefs.is_affix_available_for("light_skirmish", 1, 5):
		fail.call("light_skirmish 对装甲不应可用")
	# tier 不足 → 独特词条不可用
	if AffixDefs.is_affix_available_for("armor_titan", 1, 2):
		fail.call("armor_titan 对 ELITE(2) 不应可用")
	if not AffixDefs.is_affix_available_for("armor_titan", 1, 3):
		fail.call("armor_titan 对 CHAMPION(3) 应可用")
	# 通用词条全兵种可用
	for kind in range(5):
		if not AffixDefs.is_affix_available_for("platform_hp_up", kind, 0):
			fail.call("platform_hp_up 对兵种 %d 应可用" % kind)
	# 池计数：LIGHT tier0 = 15 通用 + 2 专属；tier3 = +1 独特
	if AffixDefs.get_ids_for_combat_kind(0, 0).size() != GENERIC_COUNT + 2:
		fail.call("轻装 tier0 池应为 %d，实得 %d" % [GENERIC_COUNT + 2, AffixDefs.get_ids_for_combat_kind(0, 0).size()])
	if AffixDefs.get_ids_for_combat_kind(0, 3).size() != GENERIC_COUNT + 3:
		fail.call("轻装 tier3 池应为 %d，实得 %d" % [GENERIC_COUNT + 3, AffixDefs.get_ids_for_combat_kind(0, 3).size()])
	print("  过滤 OK（兵种互斥 / tier 门槛 / 通用兜底 / 池计数）")

	# ══════════ 4. roll 兵种/tier 过滤统计 ══════════
	print("\n[4] roll_unlocked_affix_id 兵种过滤统计")
	# AIR(tier0) 武器稀有 roll：永不出现其它兵种专属 / 任何独特词条
	var leak_count: int = 0
	var air_kind_hit: int = 0
	for i in range(400):
		var rid: String = AffixDefs.roll_unlocked_affix_id(1, "rare", [], 3, 0)
		if rid.is_empty():
			fail.call("roll 不应返回空（池非空）")
			break
		if ["light_skirmish", "light_evasion", "armor_column", "armor_plating",
			"support_outrange", "support_repair", "fort_bulwark", "fort_crossfire",
			"light_executioner", "armor_titan", "air_reaper", "support_orbital", "fort_protocol"].has(rid):
			leak_count += 1
		if rid == "air_dive" or rid == "air_supremacy":
			air_kind_hit += 1
	if leak_count != 0:
		fail.call("AIR tier0 roll 出现 %d 次串池/越权词条" % leak_count)
	# 两段式权重：专属命中率理论 ~55%（0.55 × kind池内稀有度过滤全过），阈值放宽到 35%
	if air_kind_hit < 140:
		fail.call("AIR 专属命中率过低：%d/400（预期 >140）" % air_kind_hit)
	# AIR tier3 epic roll：独特词条 air_reaper 应可出现
	var reaper_hit: int = 0
	for i in range(400):
		if AffixDefs.roll_unlocked_affix_id(1, "epic", [], 3, 3) == "air_reaper":
			reaper_hit += 1
	if reaper_hit == 0:
		fail.call("AIR tier3 epic roll 应能抽到 air_reaper")
	print("  roll OK（串池 0 次，专属命中 %d/400，air_reaper 命中 %d/400）" % [air_kind_hit, reaper_hit])

	# ══════════ 5. _roll_milestone_affix 兵种参数（AffixManager 层） ══════════
	print("\n[5] AffixManager._roll_milestone_affix 兵种参数")
	var am: Node = AffixManagerScript.new()
	var am_leak: int = 0
	for i in range(60):
		var key: String = "smk_air_%d_1" % i
		if not am._roll_milestone_affix(key, 1, 25, 3, 0):
			fail.call("_roll_milestone_affix 应成功（空槽）")
			break
		var got: Array = am.get_card_affixes(key)
		if got.size() != 1:
			fail.call("单次 roll 应恰好 1 个词条")
			break
		var res = got[0]
		var aid: String = String(res.affix_id)
		var def5: Dictionary = AffixDefs.get_definition(aid)
		var kinds5: Array = def5.get("combat_kinds", []) as Array
		if not kinds5.is_empty() and not kinds5.has(3):
			am_leak += 1
		if int(def5.get("min_tier", 0)) > 0:
			am_leak += 1
	if am_leak != 0:
		fail.call("AffixManager 层 roll 串池/越权 %d 次" % am_leak)
	# 向后兼容：无兵种上下文（combat_kind=-1）→ 通用池行为不变
	var am2: Node = AffixManagerScript.new()
	am2.on_card_level_up_instance("smk_compat#1", 1, 30)
	if am2.get_affix_count("smk_compat#1_0") != 6:
		fail.call("无实例上下文时 6 节点应产生 6 词条（向后兼容）")
	am.free()
	am2.free()
	print("  AffixManager OK（60 次兵种 roll 零串池；无上下文回退通用池）")

	# ══════════ 6. 空转 effect_key 修复 ══════════
	print("\n[6] defense / dodge_chance / crit_damage_bonus 写入 UnitStats")
	var am3: Node = AffixManagerScript.new()
	var stats = UnitStatsScript.new()
	stats.max_hp = 1000.0
	stats.defense = 10.0
	stats.defense_light = 10.0
	stats.defense_armor = 10.0
	stats.defense_air = 10.0
	stats.dodge_chance = 0.0
	stats.crit_damage_bonus = 0.0
	# rare Lv1：fort_bulwark def = 4.0×1.3 = 5.2；light_evasion dodge = 0.08×1.3 = 0.104
	# light_executioner crit_dmg = 0.30×1.7 = 0.51（epic）
	am3._card_affixes["smk_fix_0"] = [
		AffixDefs.build_affix("fort_bulwark", "rare", 1),
		AffixDefs.build_affix("light_evasion", "rare", 1),
	]
	am3._card_affixes["smk_fix_1"] = [AffixDefs.build_affix("light_executioner", "epic", 1)]
	am3._apply_card_affixes(stats, "smk_fix_0")
	am3._apply_card_affixes(stats, "smk_fix_1")
	if absf(stats.defense - 15.2) > 0.001:
		fail.call("defense 应 +5.2（10→15.2），实得 %f" % stats.defense)
	if absf(stats.defense_light - 15.2) > 0.001 or absf(stats.defense_armor - 15.2) > 0.001 or absf(stats.defense_air - 15.2) > 0.001:
		fail.call("三维防御应各 +5.2，实得 %.2f/%.2f/%.2f" % [stats.defense_light, stats.defense_armor, stats.defense_air])
	if absf(stats.dodge_chance - 0.104) > 0.0001:
		fail.call("dodge_chance 应 +0.104，实得 %f" % stats.dodge_chance)
	if absf(stats.crit_damage_bonus - 0.51) > 0.001:
		fail.call("crit_damage_bonus 应 +0.51，实得 %f" % stats.crit_damage_bonus)
	am3.free()
	print("  修复 OK（防御 15.2 / 闪避 0.104 / 暴伤 +0.51 全部写入）")

	# ══════════ 7. CardResource.tier 透传 ══════════
	print("\n[7] tier 透传（UCT / clone / 势力专属卡）")
	var tier_ge3: int = 0
	var total: int = 0
	var sample_champion: CardResource = null
	for entry in UnifiedCardTable.get_player_card_entries():
		total += 1
		var card: CardResource = UnifiedCardTable.build_card_resource(String(entry.get("card_id", "")))
		if card == null:
			continue
		if card.tier != int(entry.get("tier", 0)):
			fail.call("UCT %s tier 透传不一致：%d vs %d" % [card.card_id, card.tier, int(entry.get("tier", 0))])
			break
		if card.tier >= 3:
			tier_ge3 += 1
			if sample_champion == null:
				sample_champion = card
	if tier_ge3 < 20 or tier_ge3 > 40:
		fail.call("tier>=3 玩家卡应在 20-40 张（CHAMPION 11 + ULTIMATE 9 + FORT 11 = 31），实得 %d" % tier_ge3)
	# clone 保留 tier
	if sample_champion != null:
		var cloned: CardResource = sample_champion.clone()
		if cloned.tier != sample_champion.tier:
			fail.call("clone() 未保留 tier（%d vs %d）" % [cloned.tier, sample_champion.tier])
	# 势力专属卡映射：epic→2 / legendary→3
	var checked_fe: int = 0
	for cfg in FactionExclusiveCards.EXCLUSIVE_CARDS:
		var fe: CardResource = FactionExclusiveCards.create_card(cfg)
		if fe == null:
			continue
		checked_fe += 1
		var expect_tier: int = 3 if String(cfg.get("rarity", "")) == "legendary" else 2
		if fe.tier != expect_tier:
			fail.call("势力专属 %s tier 应为 %d，实得 %d" % [fe.card_id, expect_tier, fe.tier])
	if checked_fe == 0:
		fail.call("势力专属卡一张都没构建出来")
	print("  透传 OK（玩家卡 %d 张，tier>=3 共 %d 张，clone 保留，势力专属映射正确）" % [total, tier_ge3])

	# ══════════ 8. 身份解析兜底链 ══════════
	print("\n[8] _get_instance_card_by_identity 兜底链")
	# --script 模式无 InstanceRegistry → 裸 card_id 回退到 DefaultCards 模板（只读）
	var am4: Node = AffixManagerScript.new()
	var tpl = am4._get_instance_card_by_identity("ww1_mark4")
	if tpl == null:
		fail.call("裸 card_id 应回退到 DefaultCards 模板（ww1_mark4）")
	elif int(tpl.combat_kind) != 1:
		fail.call("ww1_mark4 模板 combat_kind 应为 1(装甲)，实得 %d" % int(tpl.combat_kind))
	var ctx4: Array = am4._combat_context_for_identity("ww1_mark4")
	if int(ctx4[0]) != 1 or int(ctx4[1]) < 0:
		fail.call("ww1_mark4 兵种上下文应为 [1, tier>=0]，实得 %s" % str(ctx4))
	# 查无此卡 → 通用池上下文 [-1, 0]
	var ctx5: Array = am4._combat_context_for_identity("nonexistent_card_xyz")
	if int(ctx5[0]) != -1 or int(ctx5[1]) != 0:
		fail.call("查无此卡应回退 [-1, 0]，实得 %s" % str(ctx5))
	am4.free()
	print("  兜底 OK（裸 card_id→模板兵种上下文；查无此卡→通用池）")

	# ══════════ 9. UI 格式化层（敌我词条/词缀显示） ══════════
	print("\n[9] UI 词条/词缀格式化（AffixDisplayFormat）")
	# 注：card_info_panel.gd 依赖链裸引用 ModificationRegistry 等 autoload，--script 模式无法整链编译
	# （项目既有测试环境限制，游戏内正常）——格式化逻辑抽在零依赖的 AffixDisplayFormat 里单独验证。
	const ADF = preload("res://scripts/affix_display_format.gd")
	if load("res://scripts/card_grid_unit_visuals.gd") == null:
		fail.call("card_grid_unit_visuals.gd 编译失败（产兵角标 meta 回退）")
	# 玩家真词条格式化：手工塞 2 词条（不同稀有度/等级）
	var am9: Node = AffixManagerScript.new()
	am9._card_affixes["uifmt_0"] = [
		AffixDefs.build_affix("platform_hp_up", "rare", 2),
		AffixDefs.build_affix("crit_chance", "legendary", 3),
	]
	var p_tags: Array = ADF.fmt_player_affix_tags("uifmt", am9)
	if p_tags.size() != 2:
		fail.call("玩家词条标签应 2 个，实得 %d" % p_tags.size())
	else:
		if not String(p_tags[0].text).contains("铁甲强化") or not String(p_tags[0].text).contains("Lv2"):
			fail.call("词条标签0 应含名称+Lv2：%s" % String(p_tags[0].text))
		if not String(p_tags[1].text).begins_with("✦"):
			fail.call("legendary 词条前缀应为 ✦：%s" % String(p_tags[1].text))
	# 防御回退：无词条身份 / am 为 null → 空标签
	if not ADF.fmt_player_affix_tags("nobody", am9).is_empty():
		fail.call("无词条身份应返回空标签")
	if not ADF.fmt_player_affix_tags("uifmt", null).is_empty():
		fail.call("am=null 应返回空标签")
	# 敌方词缀格式化（含敌方稀有度档色）
	var e_tags: Array = ADF.fmt_enemy_affix_tags([
		{"name": "幽灵步伐", "description": "闪避率 +25%", "rarity": 0},
		{"name": "泰坦装甲", "description": "生命值 +100%", "rarity": 2},
	])
	if e_tags.size() != 2:
		fail.call("敌方词缀标签应 2 个，实得 %d" % e_tags.size())
	else:
		if not String(e_tags[0].text).contains("幽灵步伐") or not String(e_tags[0].text).contains("闪避率"):
			fail.call("词缀标签0 应含名称+描述：%s" % String(e_tags[0].text))
		if not String(e_tags[1].text).begins_with("★"):
			fail.call("ELITE_ONLY 词缀前缀应为 ★：%s" % String(e_tags[1].text))
	# 合并文本：词条行置顶 + 摘要保留；空词条只留摘要
	var merged: String = ADF.merge_affix_text(p_tags, "减伤 10%", "词条")
	if not merged.begins_with("词条：") or not merged.contains("减伤 10%"):
		fail.call("合并文本应词条行置顶+摘要保留：%s" % merged)
	if ADF.merge_affix_text([], "减伤 10%", "词条") != "减伤 10%":
		fail.call("空词条合并应只保留摘要")
	am9.free()
	print("  格式化 OK（玩家 2 标签 / 词缀 2 标签 / 合并文本 / 防御回退）")

	print("\n═══════════════════════════════════════════════════════════")
	if code[0] == 0:
		print("  ✅ 全部通过")
	else:
		print("  ❌ 存在失败项")
	print("═══════════════════════════════════════════════════════════")
	quit(code[0])
