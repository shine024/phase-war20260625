extends RefCounted
class_name MainStoryNodes
## v6.4 主线节点定义 — 365天循环剧情模式的关键剧情点
##
## 不需要为365天每天设节点，只设关键天数。
## 中间的天数靠城市任务板填充。
##
## 节点类型：
##   dialogue   — 纯对话（剧情推进）
##   battle     — 战斗（映射现有关卡）
##   boss       — Boss战（自定义PhaseMaster配置）
##   unlock     — 解锁内容（新地点/新势力/新商店）
##   ending     — 结局（好/坏）

# ── 节点类型 ───────────────────────────────────────────────────────

const TYPE_DIALOGUE: String = "dialogue"
const TYPE_BATTLE: String = "battle"
const TYPE_BOSS: String = "boss"
const TYPE_UNLOCK: String = "unlock"
const TYPE_ENDING: String = "ending"

# ── 12个主线关键节点 ──────────────────────────────────────────────

const STORY_NODES: Array[Dictionary] = [
	# ═══════════ 第1天：序章 ═══════════
	{
		"id": "node_day_1",
		"trigger_day": 1,
		"trigger_phase": 0,
		"type": TYPE_DIALOGUE,
		"force_location": "command_center",
		"title": "序章：降临",
		"dialogues": [
			{"speaker": "旁白", "text": "相位裂缝将你抛入一座不属于任何时代的城市。天空下，蒸汽管道与全息投影交错闪烁。"},
			{"speaker": "参谋长", "text": "你终于来了，相位指挥官。这座城市是时间线的交汇点——365天后，相位之主将彻底觉醒。"},
			{"speaker": "指挥官", "text": "365天……也就是说我有一年的时间阻止他？"},
			{"speaker": "参谋长", "text": "是的。城市中有多个据点，去探索、去战斗、去变强。每天的时间有限——善用它。"},
		],
		"unlock_content": null,
	},

	# ═══════════ 第7天：第一次接触 ═══════════
	{
		"id": "node_day_7",
		"trigger_day": 7,
		"trigger_phase": 0,
		"type": TYPE_BATTLE,
		"force_location": "training_ground",
		"title": "第一次接触",
		"level_override": 10,
		"dialogues": [
			{"speaker": "教官", "text": "新手？来训练场练练手。对面是一战时期的敌军，不算强。"},
			{"speaker": "指挥官", "text": "正好试试相位战术。"},
		],
		"post_battle_dialogues": [
			{"speaker": "教官", "text": "不错！有潜力。情报局那边应该已经对你开放了，去看看吧。"},
		],
		"unlock_content": {"location": "intel_agency"},
	},

	# ═══════════ 第30天：势力崛起 ═══════════
	{
		"id": "node_day_30",
		"trigger_day": 30,
		"trigger_phase": 0,
		"type": TYPE_UNLOCK,
		"force_location": "command_center",
		"title": "势力崛起",
		"dialogues": [
			{"speaker": "参谋长", "text": "指挥官，七大势力已经注意到你的实力。他们都想拉拢你。"},
			{"speaker": "参谋长", "text": "去市场和市场区域转转，各势力的据点也开放了。选择你的盟友——但要小心，每个选择都有代价。"},
			{"speaker": "指挥官", "text": "是时候扩大影响力了。"},
		],
		"unlock_content": {"location": "aether_tower", "note": "势力据点和高级商店开放"},
	},

	# ═══════════ 第60天：中章Boss ═══════════
	{
		"id": "node_day_60",
		"trigger_day": 60,
		"trigger_phase": 3,
		"type": TYPE_BOSS,
		"force_location": "void_rift",
		"title": "中章危机：铁血男爵",
		"custom_battle": {
			"master_name": "铁血男爵",
			"faction": "void",
			"era": 0,
			"stats": {"max_hp": 12000, "attack_power": 500, "defense": 350, "energy_regen": 9, "unit_limit": 6},
		},
		"dialogues": [
			{"speaker": "旁白", "text": "虚空裂隙深处，一台蒸汽巨兽轰鸣启动。"},
			{"speaker": "铁血男爵", "text": "又一个来送死的相位师？我的蒸汽铁兽已经碾碎了无数挑战者！"},
			{"speaker": "指挥官", "text": "你的时代结束了，男爵。"},
		],
		"post_battle_dialogues": [
			{"speaker": "旁白", "text": "铁血男爵倒下，他的相位核心碎裂，释放出通往更深处的能量。"},
			{"speaker": "参谋长", "text": "干得漂亮。但情报显示，更强大的相位师正在未来等着你。"},
		],
	},

	# ═══════════ 第100天：时代跨越 ═══════════
	{
		"id": "node_day_100",
		"trigger_day": 100,
		"trigger_phase": 0,
		"type": TYPE_BATTLE,
		"force_location": "border_zone",
		"title": "时代跨越：二战风暴",
		"level_override": 30,
		"dialogues": [
			{"speaker": "旁白", "text": "时间线的波动将你推向二战时代。钢铁洪流席卷大地。"},
			{"speaker": "情报官", "text": "指挥官，敌方的装甲集群正在边境集结！这是全新的战争形态。"},
			{"speaker": "指挥官", "text": "装甲集群？正好检验我的相位战术能否对抗现代战争。"},
		],
		"post_battle_dialogues": [
			{"speaker": "情报官", "text": "胜利！但侦察发现，敌方主力相位师——钢铁元帅——已经现身。"},
		],
	},

	# ═══════════ 第150天：二战Boss ═══════════
	{
		"id": "node_day_150",
		"trigger_day": 150,
		"trigger_phase": 3,
		"type": TYPE_BOSS,
		"force_location": "void_rift",
		"title": "钢铁洪流：钢铁元帅",
		"custom_battle": {
			"master_name": "钢铁元帅",
			"faction": "void",
			"era": 1,
			"stats": {"max_hp": 20000, "attack_power": 850, "defense": 600, "energy_regen": 12, "unit_limit": 7},
		},
		"dialogues": [
			{"speaker": "钢铁元帅", "text": "你击败了男爵？有趣。但我是完全不同级别的对手。"},
			{"speaker": "指挥官", "text": "你用相位力量发动战争，屠杀了无数人。到此为止。"},
			{"speaker": "钢铁元帅", "text": "弱者的道德！让我看看你的相位有多强！"},
		],
		"post_battle_dialogues": [
			{"speaker": "旁白", "text": "钢铁元帅陨落。时空裂缝扩展，通向更远的未来。"},
			{"speaker": "指挥官", "text": "两个了……但相位波动还在增强。源头在更前方。"},
		],
	},

	# ═══════════ 第200天：冷战暗影 ═══════════
	{
		"id": "node_day_200",
		"trigger_day": 200,
		"trigger_phase": 0,
		"type": TYPE_BATTLE,
		"force_location": "intel_agency",
		"title": "冷战暗影",
		"level_override": 55,
		"dialogues": [
			{"speaker": "旁白", "text": "冷战时代。核阴影下，相位战争转入暗处。"},
			{"speaker": "情报官", "text": "指挥官，这个时代的相位技术已经高度军事化。电子战、卫星、导弹……"},
			{"speaker": "指挥官", "text": "有意思。让我看看冷战的相位博弈。"},
		],
		"post_battle_dialogues": [
			{"speaker": "情报官", "text": "截获关键情报——相位波的源头已锁定。就在365天的尽头。"},
		],
	},

	# ═══════════ 第250天：真相揭示 ═══════════
	{
		"id": "node_day_250",
		"trigger_day": 250,
		"trigger_phase": 0,
		"type": TYPE_DIALOGUE,
		"force_location": "aether_tower",
		"title": "真相揭示",
		"dialogues": [
			{"speaker": "旁白", "text": "以太塔顶层，你终于看清了时间线的全貌。"},
			{"speaker": "参谋长", "text": "指挥官，我们查明了相位之主的真身——他就是这座城市的创造者，一个试图通过收割所有时间线的相位能量来重塑现实的疯子。"},
			{"speaker": "指挥官", "text": "365天……他选这个时间是有原因的。相位能量在那天达到峰值。"},
			{"speaker": "参谋长", "text": "没错。你还有115天准备。去变强，收集符文，集结盟友。这是最后的冲刺。"},
		],
	},

	# ═══════════ 第300天：最终准备 ═══════════
	{
		"id": "node_day_300",
		"trigger_day": 300,
		"trigger_phase": 0,
		"type": TYPE_UNLOCK,
		"force_location": "command_center",
		"title": "最终准备",
		"dialogues": [
			{"speaker": "参谋长", "text": "指挥官，距离最终决战还有65天。城市商店全部开放最高级商品，所有训练场解锁最高难度。"},
			{"speaker": "参谋长", "text": "把你的一切准备就绪。这一战，没有退路。"},
			{"speaker": "指挥官", "text": "我已经等这一天很久了。"},
		],
		"unlock_content": {"note": "全部内容解锁，最终冲刺"},
	},

	# ═══════════ 第360天：决战前夜 ═══════════
	{
		"id": "node_day_360",
		"trigger_day": 360,
		"trigger_phase": 3,
		"type": TYPE_DIALOGUE,
		"force_location": "command_center",
		"title": "决战前夜",
		"dialogues": [
			{"speaker": "旁白", "text": "午夜。城市上空的相位裂缝已经肉眼可见，像一道撕裂苍穹的紫色闪电。"},
			{"speaker": "参谋长", "text": "明天就是第365天。相位之主将完全觉醒。"},
			{"speaker": "指挥官", "text": "我已经准备好了。符文、卡牌、盟友——全都就位。"},
			{"speaker": "参谋长", "text": "记住，无论胜负，时间线都会重置。但你携带的力量——符文——会留存。"},
			{"speaker": "指挥官", "text": "那就让它留存得更多一些。明天，终结一切。"},
		],
	},

	# ═══════════ 第365天：最终Boss ═══════════
	{
		"id": "node_final_boss",
		"trigger_day": 365,
		"trigger_phase": 0,
		"type": TYPE_BOSS,
		"force_location": "void_rift",
		"title": "相位觉醒：最终决战",
		"is_final": true,
		"custom_battle": {
			"master_name": "相位之主",
			"faction": "void",
			"era": 4,
			"stats": {"max_hp": 40000, "attack_power": 1500, "defense": 1000, "energy_regen": 18, "unit_limit": 8},
		},
		"dialogues": [
			{"speaker": "旁白", "text": "第365天。虚空裂隙中心，一个巨大的相位核心悬浮在破碎的城市上空。"},
			{"speaker": "相位之主", "text": "你穿越了整条时间线来找我？一年了，你变强了不少……但还不够。"},
			{"speaker": "指挥官", "text": "你收割了无数时间线，制造了无尽的战争。今天，这一切终结！"},
			{"speaker": "相位之主", "text": "终结？我就是相位本身。你无法终结自己存在的根基。来吧——让我看看你的答案！"},
		],
	},

	# ═══════════ 结局（好/坏由战斗结果决定） ═══════════
	{
		"id": "node_good_ending",
		"trigger_day": 365,
		"type": TYPE_ENDING,
		"ending_type": "good",
		"title": "好结局：相位平衡",
		"dialogues": [
			{"speaker": "旁白", "text": "相位核心崩塌。时空裂缝逐一愈合。战争的阴霾从所有时代散去。"},
			{"speaker": "参谋长", "text": "指挥官……我们做到了。所有时间线的相位波动都消失了。"},
			{"speaker": "指挥官", "text": "不。相位不会消失，它只是回归了平衡。而我们——是守护这份平衡的人。"},
			{"speaker": "旁白", "text": "但时间线终将再次循环。你的符文力量，将伴随你进入下一个轮回……"},
		],
	},
	{
		"id": "node_bad_ending",
		"trigger_day": 365,
		"type": TYPE_ENDING,
		"ending_type": "bad",
		"title": "坏结局：相位崩溃",
		"dialogues": [
			{"speaker": "旁白", "text": "你的防线崩溃了。相位之主的力量远超预期。"},
			{"speaker": "相位之主", "text": "看到了吗？这就是反抗命运的下场。你的时间线——归零。"},
			{"speaker": "指挥官", "text": "还不……还没结束……符文还在……"},
			{"speaker": "旁白", "text": "时间线重置。但你的符文力量穿越了轮回——下一个365天，你会更强。"},
		],
	},
]

# ── 查询接口 ───────────────────────────────────────────────────────

## 获取指定天数的所有节点
static func get_nodes_for_day(day: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for node in STORY_NODES:
		if int(node.get("trigger_day", 0)) == day:
			result.append(node)
	return result

## 获取指定天数和时段的节点
static func get_node_at(day: int, phase: int) -> Dictionary:
	for node in STORY_NODES:
		if int(node.get("trigger_day", 0)) == day:
			# 如果没有指定 trigger_phase，则在该天任意时段触发
			var tp: int = int(node.get("trigger_phase", -1))
			if tp < 0 or tp == phase:
				return node
	return {}

## 判断今天是否有主线节点
static func has_story_node_on_day(day: int) -> bool:
	return not get_nodes_for_day(day).is_empty()

## 获取所有天数列表（有节点的天）
static func get_all_story_days() -> Array[int]:
	var days: Array[int] = []
	for node in STORY_NODES:
		var d: int = int(node.get("trigger_day", 0))
		if d > 0 and not days.has(d):
			days.append(d)
	days.sort()
	return days

## 获取最终Boss节点
static func get_final_boss_node() -> Dictionary:
	for node in STORY_NODES:
		if bool(node.get("is_final", false)):
			return node
	return {}

## 获取结局节点
static func get_ending_node(is_good: bool) -> Dictionary:
	var target_type: String = "good" if is_good else "bad"
	for node in STORY_NODES:
		if node.get("type", "") == TYPE_ENDING and node.get("ending_type", "") == target_type:
			return node
	return {}

## 获取下一个主线节点（在当前天数之后）
static func get_next_node_after(day: int) -> Dictionary:
	var next_day: int = 0
	var next_node: Dictionary = {}
	for node in STORY_NODES:
		var d: int = int(node.get("trigger_day", 0))
		if d > day:
			if next_day == 0 or d < next_day:
				next_day = d
				next_node = node
	return next_node

## 获取节点总数
static func get_node_count() -> int:
	return STORY_NODES.size()
