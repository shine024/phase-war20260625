extends RefCounted
class_name FactionWarEvents

## v6.22 贡献驱动改版：事件模板池（原战争叙事 6 模板整体重写）
## 背景=「集体穿越、人皆迷失」：事件=穿越者车队与各组织协作中的两难抉择，
## 奖励=贡献+物资；faction_a/b 结构保留（新事件=资源/人手分配两难），无战争叙事。
const EVENT_TEMPLATES: Array[Dictionary] = [
	# ─── 遇险信号救援 ───
	{
		"type": "distress",
		"name": "遇险信号：{faction_a}与{faction_b}同时求救",
		"desc": "相位风暴过境，{faction_a}的联络队与{faction_b}的采样组同时发来遇险信号，车队只能先驰援一方。支援哪一方？",
		"duration_minutes": 30,
		"weight": 30,
		"conditions": {},
		"rewards": {
			"support_a": {"reputation": 20, "skill_points": 1, "nano": 500},
			"support_b": {"reputation": 20, "skill_points": 1, "nano": 500},
			"neutral": {"nano": 100},
		},
	},
	# ─── 遗迹物资分配 ───
	{
		"type": "relic",
		"name": "遗迹物资：{faction_a}与{faction_b}的分配争议",
		"desc": "一处相位遗迹开仓，{faction_a}想要设备原型，{faction_b}想要整批物资。由车队裁断，支持哪一方？",
		"duration_minutes": 20,
		"weight": 20,
		"conditions": {"min_level": 10},
		"rewards": {
			"support_a": {"reputation": 25},
			"support_b": {"reputation": 15, "nanomaterial": 300},
			"neutral": {},
		},
	},
	# ─── 相位潮汐异常 ───
	{
		"type": "tide",
		"name": "相位潮汐：异常采样窗口",
		"desc": "潮汐异常带来短暂采样窗口，{faction_a}请求优先占用仪器，{faction_b}请求车队护航采样。优先满足谁？",
		"duration_minutes": 15,
		"weight": 12,
		"conditions": {"min_faction_level": 3},
		"rewards": {
			"support_a": {"reputation": 12, "intel": 3},
			"support_b": {"reputation": 15, "energy_block": 2},
			"neutral": {"intel": 1},
		},
	},
	# ─── 留守设施抉择 ───
	{
		"type": "facility",
		"name": "留守设施：{faction_a}的启用申请",
		"desc": "车队前方发现一座可修复的留守设施。{faction_a}申请启用为补给站，{faction_b}申请改为研究中继。支持哪种用法？",
		"duration_minutes": 60,
		"weight": 15,
		"conditions": {"min_reputation": 3000},
		"rewards": {
			"support_a": {"reputation": 30, "skill_points": 2, "exclusive_card": "random"},
			"support_b": {"reputation": 30, "intel": 3},
			"neutral": {"nano": 200},
		},
	},
	# ─── 车队维护轮值 ───
	{
		"type": "convoy",
		"name": "车队维护：{faction_a}的人手请求",
		"desc": "主车队进入例行大修，{faction_a}与{faction_b}各派了轮值方案，只能采纳一家的排程。采纳谁？",
		"duration_minutes": 45,
		"weight": 13,
		"conditions": {"min_faction_level": 5},
		"rewards": {
			"support_a": {"reputation": 25, "skill_points": 2},
			"support_b": {"reputation": 25, "nanomaterial": 500},
			"neutral": {"nanomaterial": 100},
		},
	},
	# ─── 情报共享协议 ───
	{
		"type": "intel_share",
		"name": "情报共享：{faction_a}的协议提议",
		"desc": "{faction_a}提议与车队建立情报共享协议，{faction_b}则希望保持独立核算。签字还是搁置？",
		"duration_minutes": 40,
		"weight": 10,
		"conditions": {"min_level": 20},
		"rewards": {
			"support_a": {"reputation": 25, "exclusive_card": "random"},
			"support_b": {"reputation": 25, "nanomaterial": 500},
			"neutral": {"nanomaterial": 100},
		},
	},
]

## 获取所有事件模板
static func get_event_templates() -> Array:
	return EVENT_TEMPLATES.duplicate(true)
