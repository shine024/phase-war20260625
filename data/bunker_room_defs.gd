extends RefCounted
class_name BunkerRoomDefs
## 余烬要塞（EMBER BUNKER）房间静态定义 v21 P1
## 设计文档：docs/design_ember_bunker.md
## 本文件是房间布局/成本/文案的唯一真身；BunkerManager 与 bunker_main 只读此处。
##
## 布局（侧视横剖面，1280×720 单屏）：
##   Row0 地表层（气象站/仓库/纪念碑墙）
##   Row1 电梯枢纽（入口大厅，宽间）
##   Row2 生活层（宿舍/食堂/医疗室）
##   Row3 功能层（兵棋室/维修工坊/档案室）
##   Row4 深层（通讯室/反应堆/荣誉室）
##   Row5 终局（观星台，宽间，P4 前不可修复）

## 房间三态（四态中的"升级"由 level 字段表达，不占状态位）
const STATE_LOCKED := 0
const STATE_REPAIRING := 1
const STATE_ACTIVE := 2

## 网格几何（bunker_main 按此摆放；列 x 坐标 = COL_X[col]，宽间居中）
const GRID := {
	"row_y": [80.0, 184.0, 288.0, 392.0, 496.0, 600.0],  # Row0..Row5 顶边 y
	"col_x": [40.0, 445.0, 850.0],                        # 三列左边 x
	"room_size": Vector2(390.0, 88.0),
	"wide_size": Vector2(420.0, 88.0),
	"elevator_x": 640.0,                                  # 电梯井 x（恰为中列中心）
}

## 资源 ID 短名（对齐 data/basic_resources.gd）
const RES := {
	"nano": "nano_materials",
	"alloy": "alloy",
	"crystal": "crystal",
	"energy": "energy_block",
}

## 房间定义。字段：
##   name: 显示名 / row+col: 网格位（col=-1 表示宽间居中）
##   initial: 初始状态 / cost: 修复成本（资源ID短名→数量）/ battles: 修复耗时（场）
##   tag: 功能短标签（房间节点角标）/ flavor: 房间描述（面板正文）
##   function_note: 可用后功能说明（P1 占位说明也写这里）
##   needs_power: 深层设施——反应堆未上线时修复进度冻结（上层靠备用电池供电）
static func get_all_rooms() -> Array[Dictionary]:
	return [
		{
			"id": "weather_station",
			"name": "气象站",
			"row": 0, "col": 0,
			"initial": STATE_LOCKED,
			"cost": {"nano": 120},
			"battles": 1,
			"tag": "地表·观测",
			"flavor": "半埋在陨石尘里的旧气象阵列，风速计还在无风处缓慢转动。",
			"function_note": "地表探索事件难度调节（P3 开放）。",
		},
		{
			"id": "depot",
			"name": "仓库",
			"row": 0, "col": 1,
			"initial": STATE_LOCKED,
			"cost": {"alloy": 150},
			"battles": 1,
			"tag": "地表·仓储",
			"flavor": "上一位守望者留下的金属货架，大部分格子空着，落满灰。",
			"function_note": "资源存储上限提升（P2 开放）。",
		},
		{
			"id": "monument",
			"name": "纪念碑墙",
			"row": 0, "col": 2,
			"initial": STATE_ACTIVE,
			"cost": {},
			"battles": 0,
			"tag": "地表·纪念",
			"flavor": "一面风化的石墙，刻着一些名字。有些刻痕很深，有些只起了一半。",
			"function_note": "逝者的名字安放于此。随英雄档案解锁逐一点亮（P3）。",
		},
		{
			"id": "entry_hall",
			"name": "入口大厅",
			"row": 1, "col": -1,
			"initial": STATE_ACTIVE,
			"cost": {},
			"battles": 0,
			"tag": "枢纽",
			"flavor": "重型闸门后的第一间。墙上挂着一帧歪斜蒙尘的照片——某个老旧两居室的客厅。电梯井从这里垂直向下。",
			"function_note": "设置与帮助入口（P2 迁入）。在这里站一会儿，会想起一些事。",
		},
		{
			"id": "dormitory",
			"name": "陈末的宿舍",
			"row": 2, "col": 0,
			"initial": STATE_ACTIVE,
			"cost": {},
			"battles": 0,
			"tag": "起居·睡眠",
			"flavor": "一张行军床，一张瘸腿的桌子。整个避难所里唯一属于「我」的地方。",
			"function_note": "睡觉：推进天数、恢复精神值 +20、自动存档。背包（P2 迁入）。",
		},
		{
			"id": "mess_hall",
			"name": "食堂",
			"row": 2, "col": 1,
			"initial": STATE_LOCKED,
			"cost": {"nano": 200, "alloy": 100},
			"battles": 1,
			"tag": "起居·配给",
			"flavor": "长桌纵贯整个房间。桌上只有一把椅子，朝向门口。",
			"function_note": "每日配给与 AFK 离线收益（P2 开放）。修复后，空椅子会被灯照亮。",
		},
		{
			"id": "medical",
			"name": "医疗室",
			"row": 2, "col": 2,
			"initial": STATE_LOCKED,
			"cost": {"nano": 150, "alloy": 80},
			"battles": 1,
			"tag": "起居·医疗",
			"flavor": "一只蒙布的治疗舱，舱旁的镜子上有人用手指写过字又擦掉了。",
			"function_note": "消耗纳米材料 50，大量恢复精神值 +40（P2 开放）。",
		},
		{
			"id": "war_room",
			"name": "兵棋室",
			"row": 3, "col": 0,
			"initial": STATE_LOCKED,
			"cost": {"nano": 200},
			"battles": 1,
			"tag": "作战·出击",
			"flavor": "中央是一张积灰的全息沙盘。接通电源的瞬间，一百个节点在桌面上空亮起。",
			"function_note": "前往战场：打开战区地图，选择关卡出击。",
		},
		{
			"id": "workshop",
			"name": "维修工坊",
			"row": 3, "col": 1,
			"initial": STATE_LOCKED,
			"cost": {"nano": 300, "crystal": 50},
			"battles": 2,
			"tag": "作战·整备",
			"flavor": "工作台上的工具还保持着上次使用后的摆放——有人打算回来继续。",
			"function_note": "改造 / 进化 / 成长面板（P2 迁入）。",
		},
		{
			"id": "archive",
			"name": "档案室",
			"row": 3, "col": 2,
			"initial": STATE_LOCKED,
			"cost": {"nano": 100, "energy": 60},
			"battles": 1,
			"tag": "作战·情报",
			"flavor": "档案屏一列列立在黑暗里，屏幕幽光映出浮尘。有些条目永远停在了某一天。",
			"function_note": "情报中心与英雄档案（P3 迁入）。",
		},
		{
			"id": "comms",
			"name": "通讯室",
			"row": 4, "col": 0,
			"initial": STATE_LOCKED,
			"cost": {"nano": 250, "crystal": 80},
			"battles": 2,
			"tag": "深层·通讯",
			"flavor": "通讯台上还亮着一盏待听指示灯——不知等了多久，也不知留言的人还在不在。",
			"function_note": "商店 / 势力 / 排行榜（P2 迁入）；预录来电（P3）。",
			"needs_power": true,
		},
		{
			"id": "reactor",
			"name": "反应堆核心",
			"row": 4, "col": 1,
			"initial": STATE_LOCKED,
			"cost": {"alloy": 500, "energy": 200},
			"battles": 3,
			"tag": "深层·电力",
			"flavor": "整个基地的心脏。它沉默的时候，黑暗是完整的。",
			"function_note": "全基地电力：未上线时深层设施（通讯室/荣誉室）修复进度冻结。",
		},
		{
			"id": "honor_hall",
			"name": "荣誉陈列室",
			"row": 4, "col": 2,
			"initial": STATE_LOCKED,
			"cost": {"nano": 400},
			"battles": 2,
			"tag": "深层·纪念",
			"flavor": "一面三十格的灯阵墙。每一格下面都有一行空白的名牌。",
			"function_note": "成就 / 收藏（P3 迁入）；纪念墙：为 30 位牺牲的英雄逐一点亮（P3）。",
			"needs_power": true,
		},
		{
			"id": "observatory",
			"name": "观星台",
			"row": 5, "col": -1,
			"initial": STATE_LOCKED,
			"cost": {},
			"battles": 0,
			"tag": "终局·？？？",
			"flavor": "最深处的一扇门。门后有风声——但这里不该有风。",
			"function_note": "终局内容（P4）：全房间修复 + 通关 + 集齐英雄档案后开启。",
			"is_terminal": true,
		},
	]

static func get_room(id: String) -> Dictionary:
	for r in get_all_rooms():
		if r.get("id", "") == id:
			return r
	push_warning("[BunkerRoomDefs] 未知房间 id: %s" % id)
	return {}

## 短名资源 → 完整资源 ID（对齐 basic_resources.gd）
static func res_full_id(short: String) -> String:
	return RES.get(short, short)

## 成本字典（短名）→ 可读文本，如 "纳米×200 合金×100"
static func cost_text(cost: Dictionary) -> String:
	const NAMES := {"nano": "纳米", "alloy": "合金", "crystal": "水晶", "energy": "能量块"}
	var parts: Array[String] = []
	for k in cost:
		parts.append("%s×%d" % [NAMES.get(k, k), int(cost[k])])
	return " ".join(parts) if not parts.is_empty() else "免费"

## 情感四阶段 × 发呆独白池（阶段号 1-4；bunker_main 停留 5s 触发）
const STAGE_MONOLOGUES := {
	1: [
		"陈末盯着黑暗深处：「反正……只是个梦吧。」",
		"脚步声在空走廊里荡了很远。这里安静得过分。",
		"「完成任务，拿奖励。就这样。」他对自己说。",
	],
	2: [
		"陈末在全息沙盘前站了很久，手指无意识地在桌沿敲。",
		"「也许……我该认真对待这件事。」",
		"他开始记得哪个房间的门轴会响。",
	],
	3: [
		"「我记得你们每一个人的名字。」陈末轻声说。",
		"他放慢脚步走过陈列室——灯一盏一盏亮着，像有人在等。",
		"「我不想忘记。哪怕代价是记得。」",
	],
	4: [
		"风声从最深处传来。门后有什么在等他做完决定。",
		"所有的灯都亮了。是时候了。",
	],
}

## 情感阶段阈值（按天数推进；P3 接英雄档案后加入第二判据）
static func narrative_stage_for_day(day: int) -> int:
	if day <= 15:
		return 1
	elif day <= 40:
		return 2
	elif day <= 70:
		return 3
	return 4
