extends Node
## 新手教程进度管理器（A 系统）：主界面首次进入时的系统引导
##
## v7.x 重构（8 步完整引导）：
##   1. 欢迎            — 介绍游戏目标（纯展示，无动作）
##   2. 背包            — 查看卡牌收藏
##   3. 相位仪          — 装配战斗卡到相位仪绿/黄槽
##   4. 强化            — 用纳米材料强化卡牌等级
##   5. 改造            — 安装改造模块
##   6. 符文            — 查看符文 / 符文之语
##   7. 首战            — 进入第 1 关战斗
##   8. 自由模式        — 教程结束，自由探索
##
## 设计要点：
##   - 每一步打开一个不同的面板，不再重复（原 step1/step2 都开背包）
##   - 推进靠 tutorial_overlay 的"下一步"按钮（complete_current_step）
##   - TutorialProgressionManager 不监听玩家操作，只记录步骤进度

## 教程步骤枚举（连续整数，complete_current_step 用 current_step + 1 推进）
enum TutorialStep {
	NONE = 0,
	INTRO_WELCOME = 1,        # 欢迎：介绍游戏
	CARD_COLLECTION = 2,      # 背包：查看卡牌
	PHASE_INSTRUMENT = 3,     # 相位仪：装配卡牌
	ENHANCEMENT = 4,          # 强化：提升等级
	MODIFICATION = 5,         # 改造：安装模块
	RUNES = 6,                # 符文：符文/符文之语
	FIRST_BATTLE = 7,         # 首战：进入第1关
	FREEDOM_MODE = 8,         # 自由模式（教程结束）
}

var current_step: TutorialStep = TutorialStep.NONE
var completed_steps: Array = []
var tutorial_data: Dictionary = {}

signal tutorial_step_changed(new_step: TutorialStep)
## tutorial_completed 已迁移至 SignalBus: SignalBus.tutorial_completed(tutorial_id)

func _ready() -> void:
	pass  # SaveManager会自动调用load_state
	_initialize_tutorial_data()

## 初始化教程数据（每步：标题/描述/要点/按钮文案/动作目标/高亮元素）
func _initialize_tutorial_data() -> void:
	tutorial_data = {
		TutorialStep.INTRO_WELCOME: {
			"title": "欢迎来到 Phase War",
			"description": "你将指挥跨越 5 个时代的军事力量，通过策略和卡牌组合击败敌人，守护相位场驱动器。",
			"highlights": ["100 个关卡（一战 → 近未来）", "300+ 卡牌组合", "7 大势力"],
			"action_text": "开始旅程",
			"action_target": "next",
			"highlight_elements": []
		},
		TutorialStep.CARD_COLLECTION: {
			"title": "卡牌收藏",
			"description": "背包里是你拥有的所有卡牌。战斗单位卡用于部署作战，能量卡提供部署资源。",
			"highlights": ["战斗卡：部署到战场作战", "能量卡：提供部署能量", "符文/资源在对应标签页"],
			"action_text": "查看背包",
			"action_target": "open_backpack",
			"highlight_elements": ["backpack_button"]
		},
		TutorialStep.PHASE_INSTRUMENT: {
			"title": "装配卡牌",
			"description": "把战斗卡装进相位仪的绿色槽位，能量卡装进黄色槽位。战斗中只能部署已装配的卡。",
			"highlights": ["绿色槽：战斗单位卡", "黄色槽：能量卡", "拖拽背包卡到对应槽位"],
			"action_text": "打开符文/装配",
			"action_target": "open_phase_instrument",
			"highlight_elements": ["phase_instrument_button"]
		},
		TutorialStep.ENHANCEMENT: {
			"title": "强化卡牌",
			"description": "消耗纳米材料提升卡牌强化等级。等级越高，单位属性越强，还会解锁词条槽位。",
			"highlights": ["强化提升基础属性", "Lv2/4/6/8/10 解锁词条槽", "消耗纳米材料"],
			"action_text": "打开强化",
			"action_target": "open_enhancement",
			"highlight_elements": []
		},
		TutorialStep.MODIFICATION: {
			"title": "改造卡牌",
			"description": "给卡牌安装改造模块（穿甲、装甲、火力等），每个模块改变一张卡的战斗方式。",
			"highlights": ["改造槽位与模块类型匹配", "消耗合金/材料", "改造不失败，稳定提升"],
			"action_text": "打开改造",
			"action_target": "open_modification",
			"highlight_elements": []
		},
		TutorialStep.RUNES: {
			"title": "符文系统",
			"description": "符文提供全局加成。把符文装进相位仪紫色槽位，满足条件可激活强大的符文之语。",
			"highlights": ["符文提供全局属性加成", "特定组合激活符文之语", "在背包符文标签页管理"],
			"action_text": "查看符文",
			"action_target": "open_runes",
			"highlight_elements": []
		},
		TutorialStep.FIRST_BATTLE: {
			"title": "首次战斗",
			"description": "装配好卡牌后进入战斗。点击底部绿槽选中单位，再点战场格子部署。单位会自动攻击敌人。",
			"highlights": ["点底部绿槽选单位", "点战场格子部署", "保护相位场驱动器"],
			"action_text": "开始首战",
			"action_target": "start_first_battle",
			"highlight_elements": ["battlefield"]
		},
		TutorialStep.FREEDOM_MODE: {
			"title": "自由探索",
			"description": "你已经掌握了核心系统！合理搭配卡牌、管理资源、灵活调整战术是通关的关键。",
			"highlights": ["100 关等你征服", "7 势力声望系统", "关卡掉落卡牌与改造"],
			"action_text": "开始冒险",
			"action_target": "close_tutorial",
			"highlight_elements": []
		},
	}

## 检查是否应该显示教程
func should_show_tutorial() -> bool:
	return current_step != TutorialStep.FREEDOM_MODE

## 获取当前教程内容（副作用：NONE 时推进到首步）
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

## 重置教程（设置面板调用）
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

## 执行教程动作（打开对应面板/进首关/纯推进）
## "next" = 不打开面板，只推进到下一步（欢迎页/自由模式页用）
func execute_tutorial_action(action_target: String) -> void:
	match action_target:
		"next":
			pass  # 纯推进，由 complete_current_step 处理
		"open_backpack":
			if SignalBus and SignalBus.has_signal("toggle_backpack"):
				SignalBus.toggle_backpack.emit()
		"open_phase_instrument":
			if SignalBus and SignalBus.has_signal("toggle_phase_instrument"):
				SignalBus.toggle_phase_instrument.emit()
		"open_enhancement":
			if SignalBus and SignalBus.has_signal("toggle_enhancement"):
				SignalBus.toggle_enhancement.emit()
		"open_modification":
			if SignalBus and SignalBus.has_signal("toggle_modification"):
				SignalBus.toggle_modification.emit()
		"open_runes":
			# 符文管理在背包 RunesTab，复用相位仪入口（_open_backpack_runes_tab）
			if SignalBus and SignalBus.has_signal("toggle_phase_instrument"):
				SignalBus.toggle_phase_instrument.emit()
		"start_first_battle":
			if SignalBus and SignalBus.has_signal("start_level"):
				SignalBus.start_level.emit(1)
		"close_tutorial":
			complete_current_step()


## 保存状态（给SaveManager用）
func save_state() -> Dictionary:
	return {
		"current_step": current_step,
		"completed_steps": completed_steps
	}

## 加载状态（给SaveManager用）
## 兼容：旧版枚举 FREEDOM_MODE=9，新版=8。旧档 step>=8 一律视为已完成（FREEDOM_MODE），
## 避免映射错乱；越界值同样归到 FREEDOM_MODE。
func load_state(data: Dictionary) -> void:
	if not data.is_empty():
		var saved_step: int = int(data.get("current_step", TutorialStep.NONE))
		if saved_step >= int(TutorialStep.FREEDOM_MODE):
			current_step = TutorialStep.FREEDOM_MODE
		elif saved_step <= int(TutorialStep.NONE):
			current_step = TutorialStep.NONE
		else:
			current_step = saved_step as TutorialStep
		completed_steps = data.get("completed_steps", [])

## 获取高亮元素列表
func get_highlight_elements() -> Array:
	var content = tutorial_data.get(current_step, {})
	return content.get("highlight_elements", [])
