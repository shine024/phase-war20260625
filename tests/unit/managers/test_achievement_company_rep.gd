class_name AchievementCompanyRepTest
extends GdUnitTestSuite
## v26.11(A1.5d)：成就奖励 company_rep 入账回归锁。
## 背景：v26.6 修复 achievement_rewards.gd:120 的方法名错误（此前 has_method 恒失败，
## 势力声望奖励空转整期）。本测试锁住"旧格式 company_rep 奖励 → FactionSystemManager
## 声望真实入账"链路，防止同类回归。真实 autoload 环境（GdUnit 全量启动），测完回滚声望。

const AchievementRewards = preload("res://managers/achievement/achievement_rewards.gd")
const AchievementDefinitions = preload("res://data/achievement_definitions.gd")

const TEST_FID := "iron_wall_corp"


func _get_fsm() -> Node:
	return get_node_or_null("/root/FactionSystemManager")


func test_legacy_company_rep_reward_grants_reputation() -> void:
	var fsm := _get_fsm()
	if fsm == null or not fsm.has_method("get_faction_reputation"):
		print("  FactionSystemManager 不可用，跳过")
		return
	var rep_before: int = int(fsm.get_faction_reputation(TEST_FID))
	var ok: bool = AchievementRewards.grant({"company_rep": {TEST_FID: 7}})
	var rep_after: int = int(fsm.get_faction_reputation(TEST_FID))
	print("  company_rep+7: ok=%s rep %d -> %d" % [ok, rep_before, rep_after])
	# 回滚（避免污染其他测试/全局状态）
	if rep_after != rep_before:
		fsm.add_faction_reputation(TEST_FID, rep_before - rep_after)
	assert_bool(ok).is_true()
	assert_int(rep_after - rep_before).is_equal(7)


func test_definitions_company_rep_rewards_recognized() -> void:
	# 成就定义里的 company_rep 奖励必须被 has_reward 识别（可领取），否则领取入口灰死
	var found: int = 0
	var defs: Dictionary = AchievementDefinitions.ACHIEVEMENTS
	for ach_id in defs:
		var reward: Dictionary = defs[ach_id].get("reward", {})
		if reward.has("company_rep"):
			found += 1
			assert_bool(AchievementRewards.has_reward(reward)).is_true()
	print("  company_rep 奖励成就数: %d" % found)
	assert_int(found).is_greater(0)
