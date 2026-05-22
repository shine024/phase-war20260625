extends Node
## 教程进度管理器：管理新手教程的进度和状态

## 教程步骤枚举
enum TutorialStep {
	NONE = 0,
	INTRO_WELCOME = 1,           # 欢迎界面
	CARD_COLLECTION_INTRO = 2,   # 卡牌收集介绍
	CARD_EQUIP_INTRO = 3,        # 卡牌装备介绍
	FIRST_BATTLE_INTRO = 4,      # 首次战斗介绍
	FACTION_INTRO = 6,           # 势力介绍
	PHASE_LAWS_INTRO = 7,        # 法则卡介绍
	ADVANCED_TACTICS = 8,        # 高级战术
	FREEDOM_MODE = 9             # 自由模式（教程结束）
}

var current_step: TutorialStep = TutorialStep.NONE
var completed_steps: Array = []
var tutorial_data: Dictionary = {}

signal tutorial_step_changed(new_step: TutorialStep)
## tutorial_completed 已迁移至 SignalBus: SignalBus.tutorial_completed(tutorial_id)

func _ready() -> void:
	pass  # SaveManager会自动调用load_state
	_initialize_tutorial_data()

## 初始化教程数据
func _initialize_tutorial_data() -> void:
	tutorial_data = {
		TutorialStep.INTRO_WELCOME: {
			"title": "欢迎来到 Phase War",
			"description": "你将指挥跨越5个时代的军事力量，通过策略和卡牌组合击败敌人。",
			"highlights": ["100个关卡", "300+卡牌组合", "7个势力"],
			"action_text": "开始你的旅程",
			"action_target": "open_card_collection",
			"highlight_elements": []
		},
		TutorialStep.CARD_COLLECTION_INTRO: {
			"title": "卡牌收藏",
			"description": "收集战斗卡与法则卡，构建稳定的作战配置并持续成长。",
			"highlights": ["战斗卡决定单位能力", "法则卡提供战术变化", "成长提升强度"],
			"action_text": "查看卡牌",
			"action_target": "open_backpack",
			"highlight_elements": ["backpack_button"]
		},
		TutorialStep.CARD_EQUIP_INTRO: {
			"title": "装备卡牌",
			"description": "将卡牌装备到相位仪槽位中。绿色槽位装备战斗卡，黄色槽位装备能量卡。",
			"highlights": ["绿色槽位：战斗卡", "黄色槽位：能量卡", "法则卡与普通卡统一培养"],
			"action_text": "装备一张卡牌",
			"action_target": "open_phase_instrument",
			"highlight_elements": ["phase_instrument_button"]
		},
		TutorialStep.FIRST_BATTLE_INTRO: {
			"title": "首次战斗",
			"description": "点击战场部署你的单位。单位会自动攻击敌人，保护你的相位场驱动器不被摧毁。",
			"highlights": ["点击战场部署单位", "保护相位场驱动器", "击败所有敌人"],
			"action_text": "开始战斗",
			"action_target": "start_first_battle",
			"highlight_elements": ["battlefield"]
	},
	TutorialStep.FACTION_INTRO: {
			"title": "势力系统",
			"description": "7个势力各自拥有独特的相位仪和加成。通过提升声望等级解锁专属相位仪。",
			"highlights": ["7个势力", "专属相位仪", "声望等级系统"],
			"action_text": "查看势力",
			"action_target": "open_factions",
			"highlight_elements": ["faction_button"]
		},
		TutorialStep.PHASE_LAWS_INTRO: {
			"title": "法则卡",
			"description": "法则作为一种卡牌参与战斗与成长，不再使用独立法则面板。",
			"highlights": ["12种法则", "4大家族", "环境限制"],
			"action_text": "查看背包",
			"action_target": "open_backpack",
			"highlight_elements": ["backpack_button"]
		},
		TutorialStep.ADVANCED_TACTICS: {
			"title": "高级战术",
			"description": "你已经掌握了基础！现在可以自由探索游戏。记住：合理的卡牌组合、明智的资源管理、灵活的战术调整是胜利的关键。",
			"highlights": ["卡牌组合策略", "资源管理", "战术调整"],
			"action_text": "开始冒险",
			"action_target": "close_tutorial",
			"highlight_elements": []
		}
	}

## 检查是否应该显示教程
func should_show_tutorial() -> bool:
	return current_step != TutorialStep.FREEDOM_MODE

## 获取当前教程内容
func get_tutorial_content() -> Dictionary:
	if current_step == TutorialStep.NONE:
		current_step = TutorialStep.INTRO_WELCOME

	return tutorial_data.get(current_step, {})

## 完成当前教程步骤
func complete_current_step() -> void:
	if not completed_steps.has(current_step):
		completed_steps.append(current_step)

	var next_step = current_step + 1
	if next_step <= TutorialStep.FREEDOM_MODE:
		current_step = next_step as TutorialStep
		tutorial_step_changed.emit(current_step)

		if current_step == TutorialStep.FREEDOM_MODE:
			SignalBus.tutorial_completed.emit("")

## 跳过教程
func skip_tutorial() -> void:
	current_step = TutorialStep.FREEDOM_MODE
	SignalBus.tutorial_completed.emit("")

## 重置教程
func reset_tutorial() -> void:
	current_step = TutorialStep.NONE
	completed_steps.clear()

## 获取教程进度
func get_tutorial_progress() -> Dictionary:
	return {
		"current_step": current_step,
		"completed_steps": completed_steps.size(),
		"total_steps": TutorialStep.FREEDOM_MODE,
		"completion_rate": float(completed_steps.size()) / float(TutorialStep.FREEDOM_MODE)
	}

## 执行教程动作
func execute_tutorial_action(action_target: String) -> void:
	match action_target:
		"open_card_collection", "open_backpack":
			if SignalBus and SignalBus.has_signal("toggle_backpack"):
				SignalBus.toggle_backpack.emit()
		"open_phase_instrument":
			if SignalBus and SignalBus.has_signal("toggle_phase_instrument"):
				SignalBus.toggle_phase_instrument.emit()
		"start_first_battle":
			if SignalBus and SignalBus.has_signal("start_level"):
				SignalBus.start_level.emit(1)
		"open_factions":
			if SignalBus and SignalBus.has_signal("toggle_factions"):
				SignalBus.toggle_factions.emit()
		"open_phase_laws":
			if SignalBus and SignalBus.has_signal("toggle_backpack"):
				SignalBus.toggle_backpack.emit()
		"close_tutorial":
			# 关闭教程，让玩家自由探索
			complete_current_step()


## 保存状态（给SaveManager用）
func save_state() -> Dictionary:
	return {
		"current_step": current_step,
		"completed_steps": completed_steps
	}

## 加载状态（给SaveManager用）
func load_state(data: Dictionary) -> void:
	if not data.is_empty():
		current_step = data.get("current_step", TutorialStep.NONE)
		completed_steps = data.get("completed_steps", [])

## 获取高亮元素列表
func get_highlight_elements() -> Array:
	var content = tutorial_data.get(current_step, {})
	return content.get("highlight_elements", [])
