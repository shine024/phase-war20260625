extends RefCounted
class_name BunkerRoomDefs
## 余烬要塞（EMBER BUNKER）房间静态定义 v21 P1
## 设计文档：docs/design_ember_bunker.md
## 本文件是房间布局/成本/文案的唯一真身；BunkerManager 与 bunker_main 只读此处。
##
## 布局（v3 胶囊版，1280×720 单屏：上半屏星空+地表废土，下半屏地下岩层紧凑分层）：
##   地表半地上四房：气象站 / 纪念碑墙 / 入口闸塔 / 观星台
##   地下一排·生活 y366-440：宿舍 / 食堂 / 医疗 / 仓库
##   地下二排·战备 y452-522：兵棋 / 工坊 / 档案 / 通讯
##   底部双厅 y566-684：荣誉陈列室（左 500 宽）/ 反应堆核心（右 520 宽）
##   寻路三式：via 门连锁（同层穿门）→ 竖井电梯 → 水平隧道（tunnel_y）

## 房间三态（四态中的"升级"由 level 字段表达，不占状态位）
const STATE_LOCKED := 0
const STATE_REPAIRING := 1
const STATE_ACTIVE := 2

## 网格几何（bunker_main / bunker_ambient / 生成脚本共用；与烘焙图逐像素对齐）
## 房间矩形/门位直接写在每条房间定义里（rect/side/tunnel_y/via/door_y/conn_y）
const GRID := {
	"world_size": Vector2(1280.0, 720.0),
	"surface_y": 336.0,                                    # 地表土带中心线
	"shaft": {"x1": 615.0, "x2": 665.0, "top_y": 262.0, "bottom_y": 638.0},  # 主竖井（电梯）
	## 地下两排（原生比例 232×130，零裁剪；竖井贯穿两排，中央房为直通中枢）：
	##   一排 y364-494：宿舍 / 食堂 / 档案(中枢) / 医疗 / 仓库
	##   二排 y508-638：兵棋 / 工坊 / 反应堆(中枢) / 荣誉 / 通讯
}

## 资源 ID 短名（对齐 data/basic_resources.gd）
const RES := {
	"nano": "nano_materials",
	"alloy": "alloy",
	"crystal": "crystal",
	"energy": "energy_block",
}

## 房间定义。字段：
##   name: 显示名 / rect: 房间矩形 / side: L|R|C（C=竖井直通房）
##   tunnel_y: 接竖井的水平隧道中心线（via 房与 C 房无此字段）
##   via + door_y: 同层门连锁——穿向 via 房（door_y 为门中心线）
##   conn_y: C 房与竖井的竖直接口中心线
##   initial: 初始状态 / cost: 修复成本（资源ID短名→数量）/ battles: 修复耗时（场）
##   tag: 功能短标签（房间节点角标）/ flavor: 房间描述（面板正文）
##   function_note: 可用后功能说明（P1 占位说明也写这里）
##   needs_power: 深层设施——反应堆未上线时修复进度冻结（上层靠备用电池供电）
static func get_all_rooms() -> Array[Dictionary]:
	return [
		{
			"id": "weather_station",
			"name": "气象站",
			"rect": Rect2(60, 232, 210, 110), "side": "L", "via": "monument", "door_y": 287.0,			"initial": STATE_LOCKED,
			"cost": {"nano": 120},
			"battles": 1,
			"tag": "地表·观测",
			"flavor": "半埋在陨石尘里的旧气象阵列，风速计还在无风处缓慢转动。",
			"function_note": "地表探索事件难度调节（P3 开放）。",
		},
		{
			"id": "depot",
			"name": "仓库",
			"rect": Rect2(1038, 364, 232, 130), "side": "R", "tunnel_y": 429.0,
			"initial": STATE_LOCKED,
			"cost": {"alloy": 150},
			"battles": 1,
			"tag": "地表·仓储",
			"flavor": "上一位守望者留下的金属货架，大部分格子空着，落满灰。",
			"function_note": "资源存储上限提升（P3 规划）。",
		},
		{
			"id": "monument",
			"name": "纪念碑墙",
			"rect": Rect2(270, 255, 170, 90), "side": "L", "via": "entry_hall", "door_y": 300.0,
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
			"rect": Rect2(440, 192, 350, 150), "side": "C", "conn_y": 280.0,
			"initial": STATE_ACTIVE,
			"cost": {},
			"battles": 0,
			"tag": "枢纽",
			"flavor": "重型闸门后的第一间。墙上挂着一帧歪斜蒙尘的照片——某个老旧两居室的客厅。电梯井从这里垂直向下。",
			"function_note": "设置与帮助入口。在这里站一会儿，会想起一些事。",
		},
		{
			"id": "dormitory",
			"name": "陈末的宿舍",
			"rect": Rect2(30, 364, 232, 130), "side": "L", "tunnel_y": 429.0,
			"initial": STATE_ACTIVE,
			"cost": {},
			"battles": 0,
			"tag": "起居·睡眠",
			"flavor": "一张行军床，一张瘸腿的桌子。整个避难所里唯一属于「我」的地方。",
			"function_note": "睡觉：推进天数、恢复精神值 +20、自动存档。背包就在床底。",
		},
		{
			"id": "mess_hall",
			"name": "食堂",
			"rect": Rect2(282, 364, 232, 130), "side": "L", "tunnel_y": 429.0,
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
			"rect": Rect2(786, 364, 232, 130), "side": "R", "tunnel_y": 429.0,
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
			"rect": Rect2(30, 508, 232, 130), "side": "L", "via": "dormitory", "door_y": 573.0,
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
			"rect": Rect2(282, 508, 232, 130), "side": "L", "via": "mess_hall", "door_y": 573.0,
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
			"rect": Rect2(534, 364, 232, 130), "side": "C", "conn_y": 429.0,
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
			"rect": Rect2(1038, 508, 232, 130), "side": "R", "via": "depot", "door_y": 573.0,
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
			"rect": Rect2(534, 508, 232, 130), "side": "C", "conn_y": 573.0,
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
			"rect": Rect2(786, 508, 232, 130), "side": "R", "via": "medical", "door_y": 573.0,
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
			"rect": Rect2(950, 231, 290, 127), "side": "R", "tunnel_y": 352.0,
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
## 2026-08-26 扩充 3/3/3/2 → 8/8/8/6：情绪递进 麻木→投入→羁绊→选择
const STAGE_MONOLOGUES := {
	1: [
		"陈末盯着黑暗深处：「反正……只是个梦吧。」",
		"脚步声在空走廊里荡了很远。这里安静得过分。",
		"「完成任务，拿奖励。就这样。」他对自己说。",
		"他数了数亮着的房间，又很快放弃：「统计这些有什么用。」",
		"修复的火花溅起来时，他下意识后退了半步。",
		"「别想太多。灯亮了，就是进度。」",
		"他在入口大厅站了一会儿，忘了自己要干什么。",
		"夜里的风声像某种指令。他没有听懂，也不打算听懂。",
	],
	2: [
		"陈末在全息沙盘前站了很久，手指无意识地在桌沿敲。",
		"「也许……我该认真对待这件事。」",
		"他开始记得哪个房间的门轴会响。",
		"修复工具被摆回了固定的位置——三天前他还随手乱放。",
		"「今天修哪间？」他问自己时，语气不再像在念任务。",
		"他在医疗室的镜子前停了停，把脸上的灰擦掉了。",
		"食堂的灯亮起那晚，他多坐了十分钟。",
		"「这座基地……好像开始需要我了。」",
	],
	3: [
		"「我记得你们每一个人的名字。」陈末轻声说。",
		"他放慢脚步走过陈列室——灯一盏一盏亮着，像有人在等。",
		"「我不想忘记。哪怕代价是记得。」",
		"档案室的灯他每天都去擦，尽管那里并不脏。",
		"读到某句遗言时，他停了很久，然后轻轻说：「收到。」",
		"「你们守完了你们的。剩下的路我走。」",
		"纪念碑上的名字又多了一个。他伸手描了一遍笔画。",
		"夜里他会把电台音量调大一格，让那些声音陪着他。",
	],
	4: [
		"风声从最深处传来。门后有什么在等他做完决定。",
		"所有的灯都亮了。是时候了。",
		"「三十年前你们没等到的答案，我来给。」",
		"他把基地的每间房都走了一遍，像在道别，又像在确认。",
		"「无论门后是什么——这次，是我自己选的。」",
		"观星台的门缝里透出微光。他坐在门口，等到天亮。",
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
