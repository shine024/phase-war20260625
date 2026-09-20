extends Node
## 新手教程进度管理器（A 系统）：主界面首次进入时的系统引导
##
## v4（FTUE A3 移动基地核心，2026-09-08）：以移动基地为叙事中心重排文案——
## 首战后新增「移动基地 · 你的家」步（工位/睡觉存档/行军入口），世界地图步改写为
## 行军语义（点节点=出车、停靠关=战前准备、停哪打哪），改造步改图纸消耗口径（v26.10）。
##   1. 欢迎 / 2. 背包 / 3. 装配（预装初始三卡）/ 4. 首战
##   5. 移动基地 / 6. 养成 / 7. 改造 / 8. 符文 / 9. 制造 / 10. 势力 / 11. 商店
##   12. 世界地图·行军 / 13. 相位场加点 / 14. 自由模式（教程结束）
## 枚举值保持不变（存档兼容），推进沿 STEP_ORDER 数组走；
## v3 旧档兼容：枚举值一一对应，原位续看（未看过移动基地步属预期——老玩家已在玩）。
##
## 设计要点：
##   - 每一步打开一个不同的面板，不再重复（原 step1/step2 都开背包）
##   - 推进靠 tutorial_overlay 的"下一步"按钮（complete_current_step）
##   - TutorialProgressionManager 不监听玩家操作，只记录步骤进度；
##     首战部署验证提醒（A4）在 main.gd（_start_tutorial_deploy_nudge）

## 教程步骤枚举（值与 v2 存档一致；播放顺序见 STEP_ORDER）
enum TutorialStep {
	NONE = 0,
	INTRO_WELCOME = 1,        # 欢迎：介绍游戏
	CARD_COLLECTION = 2,      # 背包：查看卡牌
	PHASE_INSTRUMENT = 3,     # 相位仪：装配卡牌
	ENHANCEMENT = 4,          # 强化：提升等级
	MODIFICATION = 5,         # 改造：安装模块
	RUNES = 6,                # 符文：符文/符文之语
	FIRST_BATTLE = 7,         # 首战：进入第1关
	TRUCK_BASE = 14,          # v4：移动基地 · 你的家（工位/睡觉存档/行军入口）
	EVOLUTION = 8,            # v9.x：制造（兵种制造线）
	FACTION_REP = 9,          # v9.x：势力声望
	SHOP = 10,                # v9.x：商店（声望购物）
	WORLD_MAP = 11,           # v9.x：世界地图选关
	PHASE_FIELD_POINTS = 12,  # v9.x：相位场加点
	FREEDOM_MODE = 13,        # 自由模式（教程结束）——v1 枚举此值为 8，旧档兼容见 load_state
}

## v4：实际播放顺序（首战提前到第 4 位；移动基地步插在首战后=战后续播首步；数组大小 = 总步数 14）
const STEP_ORDER: Array = [
	TutorialStep.INTRO_WELCOME,
	TutorialStep.CARD_COLLECTION,
	TutorialStep.PHASE_INSTRUMENT,
	TutorialStep.FIRST_BATTLE,
	TutorialStep.TRUCK_BASE,
	TutorialStep.ENHANCEMENT,
	TutorialStep.MODIFICATION,
	TutorialStep.RUNES,
	TutorialStep.EVOLUTION,
	TutorialStep.FACTION_REP,
	TutorialStep.SHOP,
	TutorialStep.WORLD_MAP,
	TutorialStep.PHASE_FIELD_POINTS,
	TutorialStep.FREEDOM_MODE,
]

var current_step: TutorialStep = TutorialStep.NONE
var completed_steps: Array = []
var tutorial_data: Dictionary = {}
## v38.3 教程节奏（用户"打开卡仓还没怎么看，就跳出准备战斗了"）：面板体验步挂起态——
## 动作打开面板后非空；玩家关闭该面板（main._close_overlay 通知）才弹下一步。
var pending_close_surface: String = ""

signal tutorial_step_changed(new_step: TutorialStep)
## tutorial_completed 已迁移至 SignalBus: SignalBus.tutorial_completed(tutorial_id)
## 批次③ Task 5：按需点播请求——链暂停期间玩家首次触达对应面板时，主场景据此拉起 overlay
signal overlay_requested

## 批次③ Task 5：首战后 10 屏按需点播开关。true=连讲暂停，玩家首次打开对应面板才
## 播当前步（见 notify_surface_opened）；战斗结束续播链（main.gd）据此不再整段倾倒。
var chain_paused: bool = false

## 步骤 → 首次触达面板键（与 truck_base._open_panel 键名 + main toggle 键对齐）
const SURFACE_FOR_STEP: Dictionary = {
	TutorialStep.TRUCK_BASE: "truck_base",
	TutorialStep.ENHANCEMENT: "growth",
	TutorialStep.MODIFICATION: "modification",
	TutorialStep.RUNES: "backpack",
	TutorialStep.EVOLUTION: "evolution",
	TutorialStep.FACTION_REP: "faction",
	TutorialStep.SHOP: "store",
	TutorialStep.WORLD_MAP: "world_map",
	TutorialStep.PHASE_FIELD_POINTS: "phase_instrument",
}

func _ready() -> void:
	pass  # SaveManager会自动调用load_state
	_initialize_tutorial_data()

## ── 批次③ Task 5 A4：教程行动验证化（三处实操门）──────────────────
## 装配（绿槽非空）/符文（starter 符文在槽）/相位场加点（真分过点）。
## 管理器不可达或字段缺失时一律放行（fail-open：门只是引导，不卡死流程）。
func _step_gate_blocked(step: TutorialStep) -> bool:
	var pim: Node = get_node_or_null("/root/PhaseInstrumentManager")
	if pim == null:
		return false
	match step:
		TutorialStep.PHASE_INSTRUMENT:
			# 绿槽至少装备 1 张战斗卡
			if pim.has_method("get_loadouts"):
				return (pim.get_loadouts() as Array).is_empty()
		TutorialStep.RUNES:
			# 符文槽至少装 1 枚符文（starter 发放后需玩家自行装配）
			var slots: Array = pim.get("_rune_slots") if "_rune_slots" in pim else []
			for s in slots:
				if s != null and str(s) != "":
					return false
			return true
		TutorialStep.PHASE_FIELD_POINTS:
			# 至少真分过 1 点（phase_field_allocations 非空）
			if pim.has_method("get_phase_field_allocations"):
				return (pim.get_phase_field_allocations() as Dictionary).is_empty()
	return false

## 按需点播：面板打开时由 main/truck_base 调用。链暂停中且面板与当前步匹配才放行一次。
func notify_surface_opened(surface_key: String) -> void:
	if not chain_paused or not should_show_tutorial():
		return
	if String(SURFACE_FOR_STEP.get(current_step, "")) != surface_key:
		return
	chain_paused = false
	overlay_requested.emit()


## ── v38.3 教程节奏：面板体验步（打开面板让玩家自由浏览，关掉才继续）──────────
## 卡仓/装配这类"打开面板看内容"的步骤，原连讲在点按钮瞬间就弹下一步——玩家还没
## 看清面板就被推着走。命中动作后挂起等待，main._close_overlay 关面板时放行。
const CLOSE_WAIT_SURFACE_FOR_ACTION: Dictionary = {
	"open_backpack": "backpack",
}


## 动作是否走"关闭面板再继续"节奏。命中=true 并挂起（overlay 自行收起，等关闭通知）。
func begin_close_wait_for_action(action_target: String) -> bool:
	var surface: String = String(CLOSE_WAIT_SURFACE_FOR_ACTION.get(action_target, ""))
	if surface.is_empty():
		return false
	pending_close_surface = surface
	return true


## 面板关闭通知（main._close_overlay 对每次面板关闭调用；战斗中由调用方守卫跳过）
func notify_surface_closed(surface_key: String) -> void:
	if pending_close_surface.is_empty() or pending_close_surface != surface_key:
		return
	pending_close_surface = ""
	if not should_show_tutorial():
		return
	overlay_requested.emit()

## 初始化教程数据（每步：标题/描述/要点/按钮文案/动作目标/高亮元素）
func _initialize_tutorial_data() -> void:
	tutorial_data = {
		# v36 实机验收：剧情化重写（用户口径）——登上基地车的开场叙事替代系统说明书腔。
		# 术语按语言宪法：「同伴」不用「伙伴」（禁用词表）、人称「你」、黑门用「关闭」；
		# 设施剧情别名后括注真实入口名，防"看不懂去哪找"。
		TutorialStep.INTRO_WELCOME: {
			"title": "欢迎登车，相位师",
			"description": "你登上了基地车。穿越前，人类把最后的家当都装了进来——\n纳米制造机，为你维护并制造战斗卡；时空交换机，联络着后方的公司与学院，换取最新的科技；深空扫描仪，探知散落在时代各处的同伴，与他们留存的战力。\n当你足够强大，就驾车向黑门进发——关闭它，完成深航计划的最终使命。愿种族意志庇佑你。",
			"highlights": [
				"纳米制造机 = 制造中心：制造与维护战斗卡",
				"时空交换机 = 后方联络：商店与各组织支持",
				"深空扫描仪 = 情报舱：敌情与同伴的线索",
				"基地车停哪打哪——100 关，终点是黑门",
			],
			"action_text": "启程",
			"action_target": "next",
			"highlight_elements": []
		},
		TutorialStep.CARD_COLLECTION: {
			"title": "清点卡仓",
			"description": "卡仓里是你拥有的所有卡牌。战斗卡用于部署作战，符文与资源在对应标签页管理。在移动基地点击「卡牌展示墙」工位也能打开同一个卡仓。",
			"highlights": ["战斗卡：部署到战场作战", "同名战斗卡各自独立养成", "符文/资源在对应标签页；卡牌墙工位即卡仓"],
			"action_text": "打开卡仓",
			"action_target": "open_backpack",
			"highlight_elements": ["backpack_button"],
			# v6.20 教程指向可视化：聚光圈住真实入口按钮（点真按钮=等效点本步动作键）
			"spotlight_key": "backpack",
			"spotlight_tip": "发光的工位就是卡仓，点它",
			"spotlight_press_advances": true,
		},
		TutorialStep.PHASE_INSTRUMENT: {
			"title": "装载战斗卡",
			"description": "初始三张卡（毛瑟步枪班/81mm迫击炮组/FT-17坦克）已预装入底部绿色装配槽，首战即可部署。之后获得新卡时，从卡仓拖到底部绿槽装备（战斗中只能部署已装配的战斗卡）。",
			"highlights": ["绿色槽：战斗卡", "初始三张基础卡已预装备", "新卡从卡仓拖到底部槽位"],
			"action_text": "查看装配",
			"action_target": "open_backpack",
			"highlight_elements": ["phase_instrument_button"],
			"spotlight_key": "backpack",
			"spotlight_tip": "相位仪装配槽就在卡仓底部",
			"spotlight_press_advances": true,
		},
		TutorialStep.ENHANCEMENT: {
			# v37（用户拍板）：成长入口直进技能树——本步从"打开整备舱"改为技能树导览；
			# 战斗卡自动升级的说明保留（战后结算与卡仓行内都有成长呈现，无需专开面板）。
			"title": "相位师技能树",
			"description": "刚才的战斗中，上阵的战斗卡已经获得了经验——战斗卡靠经验自动升级（Lv1-30），Lv5/10/15/20/25/30 各解锁一个词条，无需手动操作。\n相位师自己的成长在技能树：用技能点解锁全局强化，构建你的指挥风格。",
			"highlights": ["战斗经验→等级 Lv1-30（自动）", "关键等级解锁词条节点", "技能树：技能点换全局强化"],
			"action_text": "打开技能树",
			"action_target": "open_enhancement",
			"highlight_elements": []
		},
		TutorialStep.MODIFICATION: {
			"title": "安装改造",
			"description": "为战斗卡安装改造模块（穿甲、装甲、火力等），定向强化其战斗方式。安装一条改造 = 消耗 1 张对应图纸 + 纳米材料；图纸三路补给：战斗掉落 / 制造舱制造 / 补给舱采购。车厢「改造·词条」工位即改造舱。",
			"highlights": ["安装消耗图纸 + 纳米材料", "图纸三路补给：掉落 / 制造 / 补给舱", "改造不失败，稳定提升；同名战斗卡互不影响"],
			"action_text": "打开改造舱",
			"action_target": "open_modification",
			"highlight_elements": []
		},
		TutorialStep.RUNES: {
			"title": "符文系统",
			"description": "符文提供全局加成。把符文装进相位仪紫色槽位，满足组合条件即激活符文之语。",
			"highlights": ["符文提供全局属性加成", "特定组合激活符文之语", "在卡仓符文标签页管理"],
			"action_text": "查看符文",
			"action_target": "open_runes",
			"highlight_elements": []
		},
		TutorialStep.FIRST_BATTLE: {
			# v37 实机验收（用户"开战后不知道相位仪/卡仓在哪"）：开战描述顺带指认
			# 战斗 HUD 三块位置；进入战斗后 main 还会弹一次底部两栏的悬浮指认（9s 自散）。
			"title": "首次战斗",
			"description": "卡组已装配，出击后自动部署会自动把绿槽卡组摆上战场，单位自动攻击敌人。想手动摆位，点底部绿槽选单位再点战场格子即可。\n战场界面：底部左侧是相位仪装配槽（绿槽），底部右侧「菜单」展开功能栏（卡仓/地图/设置/存档/挂机），顶栏可看战况、环境与倍速。",
			"highlights": ["自动部署默认开启，自动上阵+阵亡补位", "手动部署：点绿槽选单位→点格子", "底部左=相位仪装配槽 / 底部右=功能栏", "保护相位场驱动器"],
			"action_text": "开始首战",
			"action_target": "start_first_battle",
			"highlight_elements": ["battlefield"]
		},
		TutorialStep.TRUCK_BASE: {
			"title": "回到移动基地 · 车厢指南",
			"description": "首战打通了！战场之外的一切都在这辆装甲卡车里：剖面车厢每个发光工位都挂着常显标牌——卡牌墙=卡仓、工作台=改造舱、3D 打印机=制造舱、售货机=补给舱、地图墙=情报舱、发电机=燃料引擎、铺位=睡觉存档。接下来去「技能树」看看相位师的成长。",
			"highlights": ["外景看驻地 / 剖面干活，顶栏可切换", "铺位睡觉 = 存档 + 回充燃料 + 恢复精神", "顶栏「战区地图」= 行军换防与选关"],
			"action_text": "收到",
			"action_target": "next",
			"highlight_elements": []
		},
		TutorialStep.EVOLUTION: {
			"title": "兵种制造",
			"description": "在制造舱用情报与资源直接生产卡牌：击败敌形积累情报，25% 解锁配方，品质随档位提升。入口在底栏「制造」键，移动基地的「3D 打印机」工位同款；工坊可降制造消耗。新档已附起始卡同族的情报，现在就能造。",
			"highlights": ["底栏「制造」/ 移动基地 3D 打印机", "情报解锁配方与品质", "资源制造，品质有下限"],
			"action_text": "打开制造舱",
			"action_target": "open_evolution",
			"highlight_elements": []
		},
		TutorialStep.FACTION_REP: {
			"title": "势力声望",
			"description": "战斗与委托提升 7 大势力的声望。声望等级解锁势力专属卡牌、相位仪与技能。",
			"highlights": ["7 大势力各有声望等级", "声望解锁专属卡牌与相位仪", "势力技能树全局生效"],
			"action_text": "打开联络台",
			"action_target": "open_faction",
			"highlight_elements": []
		},
		TutorialStep.SHOP: {
			"title": "声望采购",
			"description": "用声望在补给舱采购卡牌、资源与符文。各公司上架的物资不同；移动基地的「补给售货机」工位是同一个补给舱。",
			"highlights": ["声望 = 采购货币", "各公司物资不同", "符文亦可采购"],
			"action_text": "打开补给舱",
			"action_target": "open_store",
			"highlight_elements": []
		},
		TutorialStep.WORLD_MAP: {
			"title": "世界地图 · 行军与出击",
			"description": "战区地图上，金色光点就是你的移动基地（纯指示，点节点即可操作）。点任意节点 = 出车行军（耗燃料，按地形计价，回程半价）；点停靠的关卡 = 战前准备，一键出击——停哪打哪，行驶中无法出击。行军实时推进（1 天 ≈ 12 秒，离线也计时），到站自动停靠。",
			"highlights": ["点任意节点行军，自由停靠", "停靠关 = 战前准备 → 出击", "燃料不足 / 行驶中会被拦截并说明原因"],
			"action_text": "打开世界地图",
			"action_target": "open_world_map",
			"highlight_elements": []
		},
		TutorialStep.PHASE_FIELD_POINTS: {
			"title": "相位场加点",
			"description": "相位仪升级获得属性点，在相位仪选择面板分配到攻击/防御/能量等方向，构筑你的作战风格。",
			"highlights": ["相位仪升级→属性点", "自由分配与洗点", "点数全局生效"],
			"action_text": "打开相位仪面板",
			"action_target": "open_phase_field",
			"highlight_elements": []
		},
		TutorialStep.FREEDOM_MODE: {
			"title": "自由模式",
			"description": "核心系统已经掌握。「出击 → 行军 → 养兵」的循环就是推进战线的关键。推进受阻就回移动基地：睡觉存档、接收自动哨戒的战利品，休整后再战。",
			"highlights": ["100 关 + 黑门 · 无限模式", "回移动基地睡觉 = 存档", "合理搭配卡牌、管理资源、灵活调整战术"],
			"action_text": "自由出击",
			"action_target": "close_tutorial",
			"highlight_elements": []
		},
	}

## 检查是否应该显示教程
func should_show_tutorial() -> bool:
	return current_step != TutorialStep.FREEDOM_MODE

## v34 渐进解锁：教程是否已完成（正常走完或跳过均算）。
## LevelProgressManager.is_feature_unlocked 消费——教程已完成的存档全系统开放（老档兜底）。
func is_tutorial_completed() -> bool:
	return current_step == TutorialStep.FREEDOM_MODE

## 2026-09-19 教程×门控解卡：教程进行中，该 key 是否为教程步目标面板（含链上未来步）。
## 教程步 MODIFICATION/FACTION_REP/SHOP 要求首触对应面板才续链，而这些面板 L6/L10 才
## 解锁——门控不豁免时新档教程链实质停滞（chain_paused）。main._open_overlay 守卫豁免。
func is_tutorial_surface(key: String) -> bool:
	if not should_show_tutorial():
		return false
	for step_key in SURFACE_FOR_STEP.values():
		if String(step_key) == String(key):
			return true
	return false

## 获取当前教程内容（副作用：NONE 时推进到首步）
func get_tutorial_content() -> Dictionary:
	if current_step == TutorialStep.NONE:
		current_step = TutorialStep.INTRO_WELCOME
	return tutorial_data.get(current_step, {})

## 完成当前教程步骤（v3：沿 STEP_ORDER 推进——首战提前后枚举值不再连续递增）
## 批次③ Task 5 A4：三处实操门（装配/符文/加点）不满足时拒绝推进并 toast 反馈。
func complete_current_step() -> void:
	if _step_gate_blocked(current_step):
		SignalBus.show_toast.emit("先按引导完成这一步的实际操作，再继续")
		return
	if not completed_steps.has(current_step):
		completed_steps.append(current_step)

	var idx: int = STEP_ORDER.find(current_step)
	if idx >= 0 and idx + 1 < STEP_ORDER.size():
		current_step = STEP_ORDER[idx + 1] as TutorialStep
		# 批次③ Task 5：首战打完进入战后续播段——连讲暂停，改面板首触时点播
		chain_paused = SURFACE_FOR_STEP.has(current_step)
		tutorial_step_changed.emit(current_step)

		if current_step == TutorialStep.FREEDOM_MODE:
			SignalBus.tutorial_completed.emit("")
			# v26.6 批4b: 死信号审计 B 类补反馈链——教学完成 toast（原信号无人监听）
			SignalBus.show_toast.emit("🎓 教学完成，自由模式已解锁")

## v3：当前是否已过首战步（战后续播判定用；NONE/首战步本身返回 false）
func is_past_first_battle() -> bool:
	var idx: int = STEP_ORDER.find(current_step)
	return idx > STEP_ORDER.find(TutorialStep.FIRST_BATTLE)

## 跳过教程
func skip_tutorial() -> void:
	current_step = TutorialStep.FREEDOM_MODE
	chain_paused = false
	pending_close_surface = ""
	SignalBus.tutorial_completed.emit("")
	# v26.6 批4b: 补反馈链（与正常完成路径一致）
	SignalBus.show_toast.emit("🎓 教学完成，自由模式已解锁")

## 重置教程（设置面板调用）
func reset_tutorial() -> void:
	current_step = TutorialStep.NONE
	completed_steps.clear()
	chain_paused = false
	pending_close_surface = ""

## 获取教程进度
func get_tutorial_progress() -> Dictionary:
	return {
		"current_step": current_step,
		"completed_steps": completed_steps.size(),
		"total_steps": STEP_ORDER.size(),
		"completion_rate": float(completed_steps.size()) / float(STEP_ORDER.size())
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
		"open_evolution":
			if SignalBus and SignalBus.has_signal("toggle_evolution"):
				SignalBus.toggle_evolution.emit()
		"open_faction":
			if SignalBus and SignalBus.has_signal("toggle_faction"):
				SignalBus.toggle_faction.emit()
		"open_store":
			if SignalBus and SignalBus.has_signal("toggle_store"):
				SignalBus.toggle_store.emit()
		"open_world_map":
			if SignalBus and SignalBus.has_signal("toggle_world_map"):
				SignalBus.toggle_world_map.emit()
		"open_phase_field":
			if SignalBus and SignalBus.has_signal("open_phase_field_points"):
				SignalBus.open_phase_field_points.emit()
		"start_first_battle":
			if SignalBus and SignalBus.has_signal("start_level"):
				SignalBus.start_level.emit(1)
		"close_tutorial":
			complete_current_step()


## 保存状态（给SaveManager用）
## v4（2026-09-08 FTUE A3）：14 步制——首战后插入移动基地步（枚举值不变，仅 STEP_ORDER 插项）。
## v3 为 13 步制（首战提前到第 4 位）；v2 为旧序（首战第 7 位）；v1 为 8 步制（FREEDOM=8）。
## v6.14：chain_paused 入档——按需点播段（链暂停）中途退游戏，此前暂停态丢失，
## 旧档此后每场战斗结束都会弹一次 overlay（用户报"旧教程还跳出来"成因之一）。
func save_state() -> Dictionary:
	return {
		"version": 4,
		"current_step": current_step,
		"completed_steps": completed_steps,
		"chain_paused": chain_paused,
		# v38.3: 面板体验步挂起态（玩家关着卡仓退出游戏，读档后仍在等待关闭放行）
		"pending_close_surface": pending_close_surface,
	}

## 加载状态（给SaveManager用）
## v1 旧档为 8 步制（FREEDOM=8）——step>=8 视为已完成，防止旧完档被拉回重看；
## v2→v3 迁移：旧序停在 4-7 步（养成导览中、首战未打）的档直接跳到新序首战步
##（枚举值同为 FIRST_BATTLE=7，内容不变）；1-3/8-13 步两序一一对应，原位续看。
## v3→v4 无迁移：TRUCK_BASE=14 是新增枚举值且只插入播放序——旧档 current_step
## 枚举值全部有效，原位续看即可（老玩家跳过移动基地步属预期）。
## v6.14 修复：完成判定 `>= FREEDOM_MODE` 会把 v4 新档停在 TRUCK_BASE(14) 的存档
## 误拉回 FREEDOM_MODE(13)——点播暂停点丢失。改精确相等判定（存档值域内只有
## 13 是终态；14 是合法暂停点，走原位续看分支）。
func load_state(data: Dictionary) -> void:
	# v6.14: 空段（存档缺段）时 chain_paused 复位默认——读侧不变式"先重置再覆盖"
	if data.is_empty():
		chain_paused = false
		return
	var version: int = int(data.get("version", 1))
	var saved_step: int = int(data.get("current_step", TutorialStep.NONE))
	if version < 2 and saved_step >= 8:
		current_step = TutorialStep.FREEDOM_MODE
		completed_steps = data.get("completed_steps", [])
		return
	if version < 3 and saved_step >= int(TutorialStep.ENHANCEMENT) \
			and saved_step <= int(TutorialStep.FIRST_BATTLE):
		saved_step = int(TutorialStep.FIRST_BATTLE)
	if saved_step == int(TutorialStep.FREEDOM_MODE):
		current_step = TutorialStep.FREEDOM_MODE
	elif saved_step <= int(TutorialStep.NONE):
		current_step = TutorialStep.NONE
	else:
		current_step = saved_step as TutorialStep
	completed_steps = data.get("completed_steps", [])
	chain_paused = bool(data.get("chain_paused", false))
	# v38.3: 面板体验步挂起态（旧档无此键 → 空串 = 无挂起，行为不变）
	pending_close_surface = String(data.get("pending_close_surface", ""))

## 获取高亮元素列表
func get_highlight_elements() -> Array:
	var content = tutorial_data.get(current_step, {})
	return content.get("highlight_elements", [])
