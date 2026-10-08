extends GdUnitTestSuite
## v6.51 回归锁：成就/委托奖励显示全键覆盖。
##
## 实机主诉"成就应该给一些奖励 / 委托任务没写会获得什么"根因在显示层：
## ① achievement_panel._format_rewards 旧版只认 nano_materials/company_rep——
##    定义表 61 纳米/13 神话卡/9 稀有卡/10 称号/1 经验里，后四类全部显示为空；
## ② quest_panel._make_quest_row 旧版查 company_rep（数据用 faction_rep，恒空）
##    且没有奖励行。
## 宪法 C3：展示口径与发放链（achievement_rewards._grant_legacy_format /
## quest_manager._grant_rewards）对齐——这里锁"每种可发放键都能显示成中文"。

const AchievementPanelScript := preload("res://scenes/ui/achievement_panel.gd")
const QuestPanelScript := preload("res://scenes/ui/quest_panel.gd")


## 注意：两个面板的 _ready 需要完整场景骨架（PanelChrome 等），不能挂树实例化——
## 只测纯格式化函数，裸实例（不进树）调方法后手动 free。
func _ap() -> Control:
	return AchievementPanelScript.new()


func _qp() -> Control:
	return QuestPanelScript.new()


## 成就：纳米+经验+称号组合（achievements_combat 真实键形）
func test_achievement_format_covers_xp_and_title() -> void:
	var ap := _ap()
	var text: String = ap.call("_format_rewards", {"nano_materials": 50, "xp": 100, "title": "神射手"})
	assert_str(text).contains("50纳米材料")
	assert_str(text).contains("100相位经验")
	assert_str(text).contains("称号「神射手」")
	ap.free()


## 成就：卡牌键（collection/special 表在用，旧版显示为空的主诉键）
func test_achievement_format_covers_cards_and_merit() -> void:
	var ap := _ap()
	var text: String = ap.call("_format_rewards", {"mythic_card": 5, "rare_card": 2, "merit": 10})
	assert_str(text).contains("神话卡 ×5")
	assert_str(text).contains("稀有卡 ×2")
	assert_str(text).contains("10功勋")
	ap.free()


## 成就：新格式 stub 表 {type, amount}
func test_achievement_format_new_type_schema() -> void:
	var ap := _ap()
	var text: String = ap.call("_format_rewards", {"type": "basic_nano", "amount": 100})
	assert_str(text).contains("纳米材料")
	assert_str(text).contains("100")
	ap.free()


## 成就：faction_rep 字典键（数据真身键）+ 空奖励空串
func test_achievement_format_faction_rep_and_empty() -> void:
	var ap := _ap()
	var text: String = ap.call("_format_rewards", {"faction_rep": {"iron_wall_corp": 10}})
	assert_str(text).contains("贡献+10")
	assert_str(ap.call("_format_rewards", {})).is_empty()
	ap.free()


## 委托：奖励行文本（quest_definitions.json 全部 57 条都是 nano_materials+faction_rep）
func test_quest_format_rewards_line() -> void:
	var qp := _qp()
	var text: String = qp.call("_format_quest_rewards", {"nano_materials": 60, "faction_rep": {"iron_wall_corp": 10}})
	assert_str(text).contains("纳米材料 ×60")
	assert_str(text).contains("贡献 +10")
	assert_str(qp.call("_format_quest_rewards", {})).is_empty()
	qp.free()
