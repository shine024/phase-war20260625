class_name AchievementCompanyRepTest
extends GdUnitTestSuite
## v26.11(A1.5d)：成就奖励 company_rep 入账回归锁（原锁"company_rep→声望"链路）。
## v6.22 改版：声望轴改贡献语义后，成就奖励不再发 company_rep，改直发功勋 merit
## （achievement_rewards.gd merit 分支 + achievement_definitions.gd 5 处 merit: N）。
## 本套件随批1 §4.9 改锁新契约："merit 奖励 → FactionSystemManager 功勋真实入账"。
## 真实 autoload 环境（GdUnit 全量启动），测完回滚功勋。

const AchievementRewards = preload("res://managers/achievement/achievement_rewards.gd")
const AchievementDefinitions = preload("res://data/achievement_definitions.gd")


func _get_fsm() -> Node:
	return get_node_or_null("/root/FactionSystemManager")


func test_merit_reward_grants_merit_points() -> void:
	var fsm := _get_fsm()
	if fsm == null or not fsm.has_method("add_merit") or not fsm.has_method("get_merit_points"):
		print("  FactionSystemManager 不可用，跳过")
		return
	var merit_before: int = int(fsm.get_merit_points())
	var ok: bool = AchievementRewards.grant({"merit": 7})
	var merit_after: int = int(fsm.get_merit_points())
	print("  merit+7: ok=%s merit %d -> %d" % [ok, merit_before, merit_after])
	# 回滚（避免污染其他测试/全局状态）
	if merit_after != merit_before:
		fsm.add_merit(merit_before - merit_after)
	assert_bool(ok).is_true()
	assert_int(merit_after - merit_before).is_equal(7)


func test_definitions_merit_rewards_recognized() -> void:
	# 成就定义里的 merit 奖励必须被 has_reward 识别（可领取），否则领取入口灰死
	var found: int = 0
	var defs: Dictionary = AchievementDefinitions.ACHIEVEMENTS
	for ach_id in defs:
		var reward: Dictionary = defs[ach_id].get("reward", {})
		if reward.has("merit"):
			found += 1
			assert_bool(AchievementRewards.has_reward(reward)).is_true()
	print("  merit 奖励成就数: %d" % found)
	assert_int(found).is_greater(0)


func test_no_company_rep_rewards_remain() -> void:
	# v6.22 批1 清理锁：成就定义不再有 company_rep（声望轴已退役为贡献，成就改发功勋）
	var defs: Dictionary = AchievementDefinitions.ACHIEVEMENTS
	var leftovers: PackedStringArray = PackedStringArray()
	for ach_id in defs:
		var reward: Dictionary = defs[ach_id].get("reward", {})
		if reward.has("company_rep"):
			leftovers.append(String(ach_id))
	assert_array(leftovers).is_empty()
