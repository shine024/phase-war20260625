extends RefCounted
class_name TutorialDefinitions
## 新手引导系统定义：引导玩家了解游戏机制
##
## 引导类型：
## - basic: 基础操作引导
## - system: 系统功能引导
## - battle: 战斗机制引导
## - advanced: 高级功能引导

## 引导步骤定义
const TUTORIALS: Dictionary = {
	# ==================== 基础操作 ====================

	"tutorial_welcome": {
		"id": "tutorial_welcome",
		"name": "欢迎来到Phase War",
		"type": "basic",
		"steps": [
			{
				"text": "欢迎来到Phase War！这是一个卡牌战斗游戏。",
				"position": "center",
				"highlight": null
			},
			{
				"text": "你需要收集战斗卡并培养它们，组成强大的战斗编队。",
				"position": "center",
				"highlight": null
			},
			{
				"text": "通过战斗获得资源，获取新的卡牌并持续成长。",
				"position": "center",
				"highlight": null
			},
			{
				"text": "准备好了吗？让我们开始第一场战斗！",
				"position": "center",
				"highlight": null
			}
		],
		"completion_trigger": "first_battle",
		"reward": {"nano_materials": 50}
	},

	"tutorial_backpack": {
		"id": "tutorial_backpack",
		"name": "背包系统",
		"type": "system",
		"steps": [
			{
				"text": "这里是你的背包，里面有你所有的卡片。",
				"position": "top-right",
				"highlight": "backpack_button"
			},
			{
				"text": "点击卡片可以查看详细信息和属性。",
				"position": "center",
				"highlight": null
			},
			{
				"text": "战斗卡决定单位能力，能量卡提供额外节奏支持。",
				"position": "center",
				"highlight": null
			},
			{
				"text": "能量卡可以在战斗中提供额外能量。",
				"position": "center",
				"highlight": null
			}
		],
		"completion_trigger": "open_backpack",
		"reward": {}
	},

	# ==================== 强化系统 ====================

	"tutorial_enhancement": {
		"id": "tutorial_enhancement",
		"name": "卡片强化",
		"type": "system",
		"steps": [
			{
				"text": "强化可以让你的卡片变得更强大！",
				"position": "top-right",
				"highlight": "enhancement_button"
			},
			{
				"text": "选择要强化的卡片，查看预览效果。",
				"position": "center",
				"highlight": null
			},
			{
				"text": "强化需要消耗纳米材料。",
				"position": "bottom",
				"highlight": "cost_label"
			},
			{
				"text": "强化等级越高，单位在战斗中越强（满级 Lv.10）。后续可通过进化系统升阶形态！",
				"position": "center",
				"highlight": null
			}
		],
		"completion_trigger": "first_enhancement",
		"reward": {"nano_materials": 100}
	},

	# ==================== 战斗机制 ====================

	"tutorial_battle_basics": {
		"id": "tutorial_battle_basics",
		"name": "战斗基础",
		"type": "battle",
		"steps": [
			{
				"text": "战斗开始后，你的单位会自动攻击敌人。",
				"position": "top",
				"highlight": "battle_area"
			},
			{
				"text": "点击能量卡可以使用特殊技能。",
				"position": "bottom-right",
				"highlight": "energy_cards"
			},
			{
				"text": "击败所有敌人即可获得胜利！",
				"position": "center",
				"highlight": null
			},
			{
				"text": "注意保护你的单位，避免被敌人击毁。",
				"position": "center",
				"highlight": null
			}
		],
		"completion_trigger": "win_battle",
		"reward": {"nano_materials": 30}
	},

	"tutorial_law": {
		"id": "tutorial_law",
		"name": "战争法则",
		"type": "advanced",
		"steps": [
			{
				"text": "法则是强大的战争魔法，可以改变战局！",
				"position": "top-right",
				"highlight": "law_button"
			},
			{
				"text": "被动法则在战斗开始时自动生效。",
				"position": "center",
				"highlight": null
			},
			{
				"text": "主动法则可以在战斗中手动施放。",
				"position": "center",
				"highlight": null
			},
			{
				"text": "法则卡也属于卡牌体系，可同样升星、改装与进化！",
				"position": "bottom",
				"highlight": "card_detail"
			}
		],
		"completion_trigger": "first_law",
		"reward": {"nano_materials": 60}
	},

	# ==================== 关卡系统 ====================

	"tutorial_level_select": {
		"id": "tutorial_level_select",
		"name": "关卡选择",
		"type": "basic",
		"steps": [
			{
				"text": "选择关卡开始你的征程！",
				"position": "top-right",
				"highlight": "level_select_button"
			},
			{
				"text": "游戏分为5个时代，每个时代20关。",
				"position": "center",
				"highlight": "era_tabs"
			},
			{
				"text": "Boss关卡（每时代第20关）有特殊奖励！",
				"position": "center",
				"highlight": "boss_level"
			},
			{
				"text": "通关关卡获得经验和奖励。",
				"position": "bottom",
				"highlight": null
			}
		],
		"completion_trigger": "clear_first_level",
		"reward": {"nano_materials": 40}
	},

	# ==================== 相位仪装配 ====================

	"tutorial_phase_instrument": {
		"id": "tutorial_phase_instrument",
		"name": "相位仪装配",
		"type": "system",
		"steps": [
			{
				"text": "相位仪是你的核心装备，决定战斗中的出战配置。",
				"position": "top-right",
				"highlight": "instrument_button"
			},
			{
				"text": "相位仪拥有多个装备槽位，可以搭载不同的卡片。",
				"position": "center",
				"highlight": "slot_panel"
			},
			{
				"text": "将战斗卡拖入对应槽位即可完成装配。",
				"position": "left",
				"highlight": "equipment_slots"
			},
			{
				"text": "能量卡可以提供特殊效果，合理搭配能大幅提升战斗力！",
				"position": "bottom",
				"highlight": "energy_slot"
			},
			{
				"text": "配置满意后别忘了保存，下次战斗将自动使用该配置。",
				"position": "bottom",
				"highlight": "save_button"
			}
		],
		"completion_trigger": "first_equipment",
		"reward": {"nano_materials": 30}
	},

	# ==================== 势力系统 ====================

	"tutorial_faction": {
		"id": "tutorial_faction",
		"name": "势力系统",
		"type": "advanced",
		"steps": [
			{
				"text": "游戏中存在多个势力，加入势力可以解锁专属内容。",
				"position": "top-right",
				"highlight": "faction_button"
			},
			{
				"text": "通过完成任务和战斗可以积累势力声望。",
				"position": "center",
				"highlight": "reputation_bar"
			},
			{
				"text": "声望达到一定等级后，可以在势力商店兑换稀有物品。",
				"position": "left",
				"highlight": "faction_shop"
			},
			{
				"text": "势力任务提供额外奖励，是提升声望的主要途径。",
				"position": "center",
				"highlight": "faction_missions"
			}
		],
		"completion_trigger": "join_faction",
		"reward": {"nano_materials": 50}
	},

	# ==================== 商店系统 ====================

	"tutorial_shop": {
		"id": "tutorial_shop",
		"name": "商店系统",
		"type": "system",
		"steps": [
			{
				"text": "商店是获取卡片和资源的重要途径！",
				"position": "top-right",
				"highlight": "shop_button"
			},
			{
				"text": "游戏中有多种货币，不同商店使用不同货币购买。",
				"position": "center",
				"highlight": "currency_panel"
			},
			{
				"text": "选择心仪的物品，确认购买即可入账。",
				"position": "left",
				"highlight": "shop_items"
			},
			{
				"text": "商店每天会刷新商品，记得经常来看看有什么新货！",
				"position": "bottom",
				"highlight": "refresh_timer"
			}
		],
		"completion_trigger": "first_purchase",
		"reward": {"energy_block": 5}
	},
}

## 获取引导定义
static func get_tutorial(tutorial_id: String) -> Dictionary:
	if TUTORIALS.has(tutorial_id):
		return TUTORIALS[tutorial_id]
	return {}

## 获取所有引导
static func get_all_tutorials() -> Array:
	return TUTORIALS.values()

## 根据类型获取引导
static func get_tutorials_by_type(type: String) -> Array:
	var result: Array = []
	for tutorial in TUTORIALS.values():
		if tutorial.get("type", "") == type:
			result.append(tutorial)
	return result

## 检查引导是否完成
static func is_tutorial_completed(tutorial_id: String) -> bool:
	var mgr = Engine.get_main_loop() if Engine.get_main_loop() else null
	if mgr is SceneTree:
		var tpm = mgr.root.get_node_or_null("TutorialProgressionManager")
		if tpm and tpm.has_method("is_tutorial_completed"):
			return tpm.is_tutorial_completed(tutorial_id)
	return false

## 获取引导完成进度
static func get_tutorial_progress() -> Dictionary:
	var total: int = TUTORIALS.size()
	var completed: int = 0

	for tutorial_id in TUTORIALS.keys():
		if is_tutorial_completed(tutorial_id):
			completed += 1

	return {
		"total": total,
		"completed": completed,
		"percentage": int(float(completed) / float(total) * 100.0) if total > 0 else 0
	}
