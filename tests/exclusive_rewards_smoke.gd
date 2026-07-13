# 无 GdUnit 依赖的快速校验：v8 批次5 独占奖励系统
#   - AchievementRewards.grant 兼容新旧两种 reward 格式
#   - has_reward 兼容新旧格式
#   - 独占卡定义（5 张时代守护者）
#   - 独占改造定义（3 个相位共鸣系列）
#   - 成就挂载独占奖励（6 个关键成就）
# Usage: godot --headless --rendering-driver opengl3 --path . --script tests/exclusive_rewards_smoke.gd
extends SceneTree

const AchievementRewards = preload("res://managers/achievement/achievement_rewards.gd")
const UnifiedCardTable = preload("res://data/unified_card_table.gd")
const UniversalModifications = preload("res://data/modification_modules/universal_mods.gd")


func _initialize() -> void:
	var code := 0
	var fail := func(msg: String) -> void:
		push_error("[FAIL] " + msg)
		code = 1

	# ══════════ 独占卡定义（5 张时代守护者） ══════════
	print("=== 独占卡定义 ===")
	var guardian_ids: Array = [
		"guardian_ww1_ironclad", "guardian_ww2_blitzkrieg",
		"guardian_cold_thunder", "guardian_modern_stealth",
		"guardian_future_omega"
	]
	for card_id in guardian_ids:
		var entry: Dictionary = UnifiedCardTable.get_entry(card_id)
		if entry.is_empty():
			fail.call("独占卡未找到: %s" % card_id)
			continue
		var is_exclusive: bool = bool(entry.get("achievement_exclusive", false))
		var power: int = int(entry.get("power", 0))
		print("  %s: power=%d, exclusive=%s" % [card_id, power, is_exclusive])
		if not is_exclusive:
			fail.call("%s 应标记 achievement_exclusive" % card_id)
		if power < 1000:
			fail.call("%s 战力 %d 应 >=1000（独占卡应强力）" % [card_id, power])
	# 独占卡应被 get_player_card_entries 包含（DefaultCards 能构建）
	var player_entries: Array = UnifiedCardTable.get_player_card_entries()
	var has_guardian: bool = false
	for e in player_entries:
		if String(e.get("card_id", "")) in guardian_ids:
			has_guardian = true
			break
	print("  get_player_card_entries 包含独占卡: %s (期望 true)" % has_guardian)
	if not has_guardian:
		fail.call("独占卡应被 get_player_card_entries 包含")

	# ══════════ 独占改造定义（3 个相位共鸣） ══════════
	print("=== 独占改造定义 ===")
	var mod_ids: Array = ["gen_11_phase_resonance", "gen_12_phase_shielding", "gen_13_phase_overdrive"]
	for mod_id in mod_ids:
		var mod_data: Dictionary = UniversalModifications.get_mod_data(mod_id)
		if mod_data.is_empty():
			fail.call("独占改造未找到: %s" % mod_id)
			continue
		var is_excl: bool = bool(mod_data.get("achievement_exclusive", false))
		var rarity: String = String(mod_data.get("rarity", ""))
		print("  %s: rarity=%s, exclusive=%s" % [mod_id, rarity, is_excl])
		if not is_excl:
			fail.call("%s 应标记 achievement_exclusive" % mod_id)
		if rarity != "legendary":
			fail.call("%s 应为 legendary 稀有度" % mod_id)

	# ══════════ AchievementRewards.has_reward 兼容性 ══════════
	print("=== has_reward 格式兼容 ===")
	# 新格式
	var new_fmt: Dictionary = {"type": "card", "card_id": "guardian_future_omega", "amount": 1}
	if not AchievementRewards.has_reward(new_fmt):
		fail.call("新格式 card 应 has_reward=true")
	print("  新格式 card: has_reward=%s (期望 true)" % AchievementRewards.has_reward(new_fmt))
	# 新格式 mod_blueprint
	var mod_fmt: Dictionary = {"type": "mod_blueprint", "mod_blueprint_id": "gen_11_phase_resonance"}
	if not AchievementRewards.has_reward(mod_fmt):
		fail.call("新格式 mod_blueprint 应 has_reward=true")
	print("  新格式 mod_blueprint: has_reward=%s (期望 true)" % AchievementRewards.has_reward(mod_fmt))
	# 旧格式（nano_materials）
	var legacy_fmt: Dictionary = {"nano_materials": 100}
	if not AchievementRewards.has_reward(legacy_fmt):
		fail.call("旧格式 nano_materials 应 has_reward=true（v8 修复）")
	print("  旧格式 nano_materials: has_reward=%s (期望 true, v8修复)" % AchievementRewards.has_reward(legacy_fmt))
	# 空字典
	if AchievementRewards.has_reward({}):
		fail.call("空字典应 has_reward=false")
	print("  空字典: has_reward=%s (期望 false)" % AchievementRewards.has_reward({}))

	# ══════════ _pick_card_by_rarity 稀有度筛选 ══════════
	print("=== _pick_card_by_rarity ===")
	# mythic_card 应从 fut_ 池抽
	var picked_mythic: String = AchievementRewards._pick_card_by_rarity("mythic_card")
	print("  mythic_card → %s (应 fut_ 开头)" % picked_mythic)
	if not picked_mythic.is_empty() and not picked_mythic.begins_with("fut_"):
		# 空池回退全卡也算通过，但非空时应 fut_ 开头
		if not picked_mythic.begins_with("fut_"):
			fail.call("mythic_card 应从 fut_ 池抽，实际 %s" % picked_mythic)
	# rare_card 应从 cold_/mod_ 池抽
	var picked_rare: String = AchievementRewards._pick_card_by_rarity("rare_card")
	print("  rare_card → %s (应 cold_/mod_ 开头)" % picked_rare)

	# ══════════ 成就挂载独占奖励（数据层核对） ══════════
	print("=== 成就独占奖励挂载 ===")
	# 这里核对 achievement_definitions.gd 的数据（通过 ResourceLoader 或直接读）
	# 由于 achievement_definitions 是 const Dictionary，用 preload 读取
	var AchieveDefs = preload("res://data/achievement_definitions.gd")
	var achieve_data: Dictionary = AchieveDefs.ACHIEVEMENTS
	var checks: Array = [
		["progress_level_20", "card", "guardian_ww1_ironclad"],
		["progress_level_40", "card", "guardian_ww2_blitzkrieg"],
		["progress_level_60", "card", "guardian_cold_thunder"],
		["progress_level_80", "card", "guardian_modern_stealth"],
		["progress_level_100", "card", "guardian_future_omega"],
		["progress_all_boss", "mod_blueprint", "gen_11_phase_resonance"],
	]
	for check in checks:
		var aid: String = check[0]
		var atype: String = check[1]
		var aid_val: String = check[2]
		var a: Dictionary = achieve_data.get(aid, {})
		var reward: Dictionary = a.get("reward", {})
		var actual_type: String = String(reward.get("type", ""))
		var actual_val: String = String(reward.get("card_id", reward.get("mod_blueprint_id", "")))
		var ok: bool = (actual_type == atype and actual_val == aid_val)
		print("  %s: type=%s val=%s → %s" % [aid, actual_type, actual_val, "OK" if ok else "MISMATCH"])
		if not ok:
			fail.call("成就 %s 奖励应为 type=%s val=%s，实际 type=%s val=%s" % [aid, atype, aid_val, actual_type, actual_val])

	# ══════════ 总结 ══════════
	if code == 0:
		print("\n=== ALL PASS ===")
	else:
		print("\n=== FAILED ===")
	quit(code)
