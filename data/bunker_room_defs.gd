extends RefCounted
class_name BunkerRoomDefs
## 余烬要塞（EMBER BUNKER）房间静态定义 v21 P1
## 设计文档：docs/design_ember_bunker.md
## 本文件是房间布局/成本/文案的唯一真身；BunkerManager 与 bunker_main 只读此处。
##
## 布局（v3 胶囊版，1280×720 单屏：上半屏星空+地表废土，下半屏地下岩层紧凑分层）：
##   地表半上一排 y293-411 五房：气象站 / 纪念碑墙 / 入口大厅 / 相位实验室 / 观星台
##   地下一排 y421-551 五房：宿舍 / 食堂 / 档案(中枢) / 医疗 / 仓库
##   地下二排 y551-681 五房：兵棋 / 工坊 / 反应堆(中枢) / 荣誉 / 通讯
##   寻路三式：via 门连锁（同层穿门）→ 竖井电梯 → 水平隧道（tunnel_y）

## 房间三态。升级不占状态位：ACTIVE 房间通过 upgrades 数组付费升级（level 1-3），
## 升级进度同样以"场"计，升级进行中不影响房间功能（v26 制造系统批次1）。
const STATE_LOCKED := 0
const STATE_REPAIRING := 1
const STATE_ACTIVE := 2

## 网格几何（bunker_main / bunker_ambient / 生成脚本共用；与烘焙图逐像素对齐）
## 几何真身 = scenes/bunker/bunker_main.tscn 的同名占位块（编辑器拖拽调整）；
## 本文件保留拓扑（side/via）+ rect 兜底。门位/隧道线由矩形实时推导，无需手填。
const GRID := {
	"world_size": Vector2(1280.0, 720.0),
	"surface_y": 336.0,                                    # 地表土带中心线
	"shaft": {"x1": 615.0, "x2": 665.0, "top_y": 262.0, "bottom_y": 638.0},  # 主竖井（电梯）
	## 地下两排（原生比例 232×130，零裁剪；竖井贯穿两排，中央房为直通中枢）：
	##   一排 y421-551：宿舍 / 食堂 / 档案(中枢) / 医疗 / 仓库
	##   二排 y551-681：兵棋 / 工坊 / 反应堆(中枢) / 荣誉 / 通讯
	##   水平均匀分布：5间 x=20/272/524/776/1028，宽232，间距20
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
##   via: 同层门连锁——穿向相邻的 via 房（门位由两房共边自动推导）
##   tunnel_y/door_y/conn_y 已废弃：全部由场景矩形实时推导
##   initial: 初始状态 / cost: 修复成本（资源ID短名→数量）/ battles: 修复耗时（场）
##   tag: 功能短标签（房间节点角标）/ flavor: 房间描述（面板正文）
##   function_note: 可用后功能说明（P1 占位说明也写这里）
##   upgrades: 升级档数组（[0]=升 Lv2，[1]=升 Lv3）；项 = {cost, battles, note}。
##     效果数值由 BunkerManager 按等级查询（get_daily_ration / get_sleep_recovery 等），
##     note 供房间面板升级区展示； analyzer/卡墙/探索等新功能随批次3 实装。
##   needs_power: 深层设施——反应堆未上线时修复/升级进度冻结（上层靠备用电池供电）
static func get_all_rooms() -> Array[Dictionary]:
	return [
		{
			"id": "weather_station",
			"name": "气象站",
			"rect": Rect2(20, 293, 232, 118), "side": "L", "via": "monument",
			"initial": STATE_LOCKED,
			"cost": {"nano": 120},
			"battles": 1,
			"tag": "地表·观测",
			"flavor": "半埋在陨石尘里的旧气象阵列，风速计还在无风处缓慢转动。",
			"function_note": "地表观测阵列。升级后解锁天气预报与地表探索。",
			"upgrades": [
				{"cost": {"nano": 180}, "battles": 1, "note": "天气预报：出击前可锁定 1 个有利环境加成"},
				{"cost": {"nano": 360}, "battles": 2, "note": "地表探索：每日 1 次派遣，带回资源或缴获卡"},
			],
		},
		{
			"id": "depot",
			"name": "仓库",
			"rect": Rect2(1028, 421, 232, 130), "side": "R",
			"initial": STATE_LOCKED,
			"cost": {"alloy": 150},
			"battles": 1,
			"tag": "卡仓·打印",
			"flavor": "卡墙一格一格亮着，旁边那台纳米打印机还在轻声运转——每一张卡，都是被重新打印出来的。",
			"function_note": "纳米打印台：以纳米材料与能量块为原料打印战利品（缴获卡，喂分析仪）。",
			"upgrades": [
				{"cost": {"alloy": 220}, "battles": 1, "note": "卡墙：拥有过的卡种逐一点亮陈列"},
				{"cost": {"alloy": 450}, "battles": 2, "note": "战利品打印：每日领取 1 张随机缴获卡"},
			],
		},
		{
			"id": "monument",
			"name": "纪念碑墙",
			"rect": Rect2(272, 293, 232, 118), "side": "L", "via": "entry_hall",
			"initial": STATE_ACTIVE,
			"cost": {},
			"battles": 0,
			"tag": "地表·纪念",
			"flavor": "一面风化的石墙，刻着一些名字。有些刻痕很深，有些只起了一半。",
			"function_note": "逝者的名字安放于此。随同伴档案解锁逐一点亮。",
		},
		{
			"id": "entry_hall",
			"name": "入口大厅",
			"rect": Rect2(524, 293, 232, 118), "side": "C",
			"initial": STATE_ACTIVE,
			"cost": {},
			"battles": 0,
			"tag": "枢纽",
			"flavor": "重型闸门后的第一间。墙上挂着一帧歪斜蒙尘的照片——某个老旧两居室的客厅。电梯井从这里垂直向下。",
			"function_note": "设置与帮助入口。在这里站一会儿，会想起一些事。",
			"upgrades": [
				{"cost": {"nano": 150}, "battles": 1, "note": "布告栏：每日动态任务 +1"},
				{"cost": {"nano": 300}, "battles": 1, "note": "居住增益：精神值上限 100→110"},
			],
		},
		{
			"id": "dormitory",
			"name": "陈末的宿舍",
			"rect": Rect2(20, 421, 232, 130), "side": "L",
			"initial": STATE_ACTIVE,
			"cost": {},
			"battles": 0,
			"tag": "起居·睡眠",
			"flavor": "一张行军床，一张瘸腿的桌子。整个避难所里唯一属于「我」的地方。",
			"function_note": "睡觉：推进天数、恢复精神值（随宿舍等级提升）、自动存档。背包就在床底。",
			"upgrades": [
				{"cost": {"nano": 120}, "battles": 1, "note": "床垫升级：睡觉回精神 20→30"},
				{"cost": {"nano": 250}, "battles": 2, "note": "落地窗：睡觉回精神 30→40"},
			],
		},
		{
			"id": "mess_hall",
			"name": "食堂",
			"rect": Rect2(272, 421, 232, 130), "side": "L",
			"initial": STATE_LOCKED,
			"cost": {"nano": 200, "alloy": 100},
			"battles": 1,
			"tag": "起居·配给",
			"flavor": "长桌纵贯整个房间。桌上只有一把椅子，朝向门口。",
			"function_note": "每日配给：每天可领取一次（量随食堂等级提升）。挂机战利品会暂存到各房间，看到发光气泡点击即可收取。修复后，空椅子会被灯照亮。",
			"upgrades": [
				{"cost": {"nano": 300, "alloy": 150}, "battles": 1, "note": "加菜：每日配给 +50%（纳米材料 180 · 合金 60）"},
				{"cost": {"nano": 600, "alloy": 300}, "battles": 2, "note": "丰收：每日配给翻倍（纳米材料 240 · 合金 80）"},
			],
		},
		{
			"id": "medical",
			"name": "医疗室",
			"rect": Rect2(776, 421, 232, 130), "side": "R",
			"initial": STATE_LOCKED,
			"cost": {"nano": 150, "alloy": 80},
			"battles": 1,
			"tag": "起居·医疗",
			"flavor": "一只蒙布的治疗舱，舱旁的镜子上有人用手指写过字又擦掉了。",
			"function_note": "消耗纳米材料治疗：效果与费用随等级提升（基础 纳米材料 50 · 精神+40）。",
			"upgrades": [
				{"cost": {"nano": 220, "alloy": 120}, "battles": 1, "note": "疗效提升：治疗精神 +40→+60"},
				{"cost": {"nano": 450, "alloy": 240}, "battles": 2, "note": "战地药品：治疗费用 50→30 纳米材料"},
			],
		},
		{
			"id": "war_room",
			"name": "兵棋室",
			"rect": Rect2(20, 551, 232, 130), "side": "L", "via": "dormitory",
			# v22.1（用户 2026-08-28 报告"无法直接进入战斗"）：初始锁定造成 FTUE 死锁——
			# 兵棋室是基地唯一的出击入口，锁死时新玩家从基地无法进第一关（修复别的房间
			# 也要打赢战斗才完工，同样被堵死）。改为初始点亮：新档从基地一步直达战区地图。
			"initial": STATE_ACTIVE,
			"cost": {"nano": 200},
			"battles": 1,
			"tag": "作战·出击",
			"flavor": "中央是一张积灰的全息沙盘。接通电源的瞬间，一百个节点在桌面上空亮起。",
			"function_note": "前往战场：打开战区地图，选择关卡出击。",
			"upgrades": [
				{"cost": {"nano": 300}, "battles": 1, "note": "战前简报：出击胜利精神消耗 10→8"},
				{"cost": {"nano": 600}, "battles": 2, "note": "沙盘演武：每日 1 张未上阵卡获得 50% 上阵经验"},
			],
		},
		{
			"id": "workshop",
			"name": "维修工坊",
			"rect": Rect2(272, 551, 232, 130), "side": "L", "via": "mess_hall",
			"initial": STATE_LOCKED,
			"cost": {"nano": 300, "crystal": 50},
			"battles": 2,
			"tag": "作战·整备",
			"flavor": "工作台上的工具还保持着上次使用后的摆放——有人打算回来继续。",
			"function_note": "改造 / 制造 / 成长面板。",
			"upgrades": [
				{"cost": {"nano": 450, "crystal": 75}, "battles": 2, "note": "制造流水线：制造资源消耗 -10%"},
				{"cost": {"nano": 900, "crystal": 150}, "battles": 2, "note": "大师工位：制造消耗 -20% · 改造安装费折扣"},
			],
		},
		{
			"id": "archive",
			"name": "档案室",
			"rect": Rect2(524, 421, 232, 130), "side": "C",
			"initial": STATE_LOCKED,
			"cost": {"nano": 100, "energy": 60},
			"battles": 1,
			"tag": "作战·情报",
			"flavor": "档案屏一列列立在黑暗里，屏幕幽光映出浮尘。有些条目永远停在了某一天。",
			"function_note": "情报中心与同伴档案。升级解锁分析仪（烧缴获卡得情报）。",
			"upgrades": [
				{"cost": {"nano": 150, "energy": 90}, "battles": 1, "note": "分析仪上线：放入缴获卡，2 场后烧出情报（每日 3 张）"},
				{"cost": {"nano": 300, "energy": 180}, "battles": 2, "note": "深度解析：高品质制造权重 ×1.5 · 全局情报获取 +10%"},
			],
		},
		{
			"id": "comms",
			"name": "通讯室",
			"rect": Rect2(1028, 551, 232, 130), "side": "R", "via": "depot",
			"initial": STATE_LOCKED,
			"cost": {"nano": 250, "crystal": 80},
			"battles": 2,
			"tag": "深层·通讯",
			"flavor": "通讯台上还亮着一盏待听指示灯——不知等了多久，也不知留言的人还在不在。",
			"function_note": "商店 / 势力 / 战功榜（P2 迁入）；预录来电（P3）。",
			"upgrades": [
				{"cost": {"nano": 380, "crystal": 120}, "battles": 2, "note": "商业频道：商店每日免费刷新 +1"},
				{"cost": {"nano": 750, "crystal": 240}, "battles": 2, "note": "势力热线：势力声望获取 +15%"},
			],
			"needs_power": true,
		},
		{
			"id": "reactor",
			"name": "反应堆核心",
			"rect": Rect2(524, 551, 232, 130), "side": "C",
			"initial": STATE_LOCKED,
			"cost": {"alloy": 500, "energy": 200},
			"battles": 3,
			"tag": "深层·电力",
			"flavor": "整个基地的心脏。它沉默的时候，黑暗是完整的。",
			"function_note": "全基地电力：未上线时深层设施（通讯室/荣誉室）修复/升级进度冻结。",
			"upgrades": [
				{"cost": {"alloy": 750, "energy": 300}, "battles": 2, "note": "电网增容：全基地生产类效果 +10%"},
				{"cost": {"alloy": 1500, "energy": 600}, "battles": 3, "note": "应急协议：低精神掉落惩罚减半 · 心跳氛围音"},
			],
		},
		{
			"id": "honor_hall",
			"name": "荣誉陈列室",
			"rect": Rect2(776, 551, 232, 130), "side": "R", "via": "medical",
			"initial": STATE_LOCKED,
			"cost": {"nano": 400},
			"battles": 2,
			"tag": "荣誉·符文圣所",
			"flavor": "三十盏灯照着一面墙。先辈的精神没有散去——它们凝成了符文，在灯下轻轻发亮。",
			"function_note": "纪念墙（30 位牺牲相位师）· 符文圣所：装备符文、搭配符文之语（先辈精神的凝结）· 成就 / 收藏。",
			"upgrades": [
				{"cost": {"nano": 600}, "battles": 2, "note": "纪念铭牌：已纪念同伴可回看完整档案与遗言"},
				{"cost": {"nano": 1200}, "battles": 2, "note": "出征仪式：每日一次敬礼，本场战斗掉落 +10%"},
			],
			"needs_power": true,
		},
		{
			"id": "phase_lab",
			"name": "相位实验室",
			"rect": Rect2(776, 293, 232, 118), "side": "R", "via": "entry_hall",
			# v22.2（用户 2026-08-28 定调）：配卡/配相位仪属于前期必备功能，不设修复门槛——
			# 符文（荣誉室）/改造（工坊）等养成功能后置，背包在宿舍、出击在兵棋室同样开局即用。
			"initial": STATE_ACTIVE,
			"cost": {"nano": 250, "energy": 50},
			"battles": 1,
			"tag": "科技·实验",
			"flavor": "示波器的辉纹还停在昨夜那道波形上。有人在板子上焊完了最后一个芯片。",
			"function_note": "相位师技能树（电路板主板）+ 相位仪调试（装备槽管理）。",
			"upgrades": [
				{"cost": {"nano": 380, "energy": 75}, "battles": 1, "note": "校准工装：属性点洗点费用 -50%"},
				{"cost": {"nano": 750, "energy": 150}, "battles": 2, "note": "自动校准：每日 1 次免费洗点"},
			],
		},
		{
			"id": "observatory",
			"name": "观星台",
			"rect": Rect2(1028, 293, 232, 118), "side": "R",
			"initial": STATE_LOCKED,
			"cost": {},
			"battles": 0,
			"tag": "终局·？？？",
			"flavor": "最深处的一扇门。门后有风声——但这里不该有风。",
			"function_note": "终局：全房间修复 + 通关 + 集齐同伴档案后开启，三选一抉择（重写/守望/远行）。",
			"is_terminal": true,
		},
	]

static func get_room(id: String) -> Dictionary:
	for r in get_all_rooms():
		if r.get("id", "") == id:
			return r
	push_warning("[BunkerRoomDefs] 未知房间 id: %s" % id)
	return {}

## 房间升级档数组（无升级的房间返回空数组）
static func get_upgrades(room_id: String) -> Array:
	return get_room(room_id).get("upgrades", [])

## 升到 target_level（2/3）的升级定义；不存在返回 {}
static func get_upgrade_def(room_id: String, target_level: int) -> Dictionary:
	var ups := get_upgrades(room_id)
	var idx := target_level - 2
	if idx < 0 or idx >= ups.size():
		return {}
	return ups[idx]

## 房间最高等级（1 + 升级档数）
static func get_max_level(room_id: String) -> int:
	return 1 + get_upgrades(room_id).size()

## 完工条目 → 展示名。升级完工条目带 "#up" 后缀（BunkerManager 写入），
## 解析为"名称（升级）"；修复完工条目原样返回名称。
static func completed_entry_label(entry: String) -> String:
	if entry.ends_with("#up"):
		var rid := entry.trim_suffix("#up")
		return "%s（升级）" % str(get_room(rid).get("name", rid))
	return str(get_room(entry).get("name", entry))

## 短名资源 → 完整资源 ID（对齐 basic_resources.gd）
static func res_full_id(short: String) -> String:
	return RES.get(short, short)

## 成本字典（短名）→ 可读文本，如 "纳米材料 ×200 合金 ×100"
static func cost_text(cost: Dictionary) -> String:
	const NAMES := {"nano": "纳米材料", "alloy": "合金", "crystal": "晶体", "energy": "能量块"}
	var parts: Array[String] = []
	for k in cost:
		parts.append("%s ×%d" % [NAMES.get(k, k), int(cost[k])])
	return " ".join(parts) if not parts.is_empty() else "免费"

## ── 房间情报文本（tooltip 与面板共用，升级情报单一真身）──────────────

## 单档升级行："Lv2 天气预报：…（纳米×180 · 1 场）"；无该档返回空串
static func upgrade_line(room_id: String, target_level: int) -> String:
	var upg := get_upgrade_def(room_id, target_level)
	if upg.is_empty():
		return ""
	return "Lv%d %s（%s · %d 场）" % [
		target_level, str(upg.get("note", "")),
		cost_text(upg.get("cost", {})), int(upg.get("battles", 1))]

## 升级线预览："修复后可升级：Lv2 … / Lv3 …"；无升级档返回空串
static func upgrade_lines_preview(room_id: String) -> String:
	var parts: Array[String] = []
	for i in range(get_upgrades(room_id).size()):
		parts.append(upgrade_line(room_id, i + 2))
	if parts.is_empty():
		return ""
	return "修复后可升级：" + " / ".join(parts)

## 悬停情报：按状态给"功能 + 升级线"完整说明（房间瓦片 tooltip 唯一数据源）。
## 废弃/修复中 → 修复条件 + 修好后有什么用 + 升级线；
## 运转中 → 功能 + 下一档升级预告（满级/升级中分别收口）。
static func hover_tooltip_text(room_id: String, state: int, level: int,
		frozen: bool, upgrade_tag: String, progress := 0.0) -> String:
	var def := get_room(room_id)
	if def.is_empty():
		return ""
	var fn := str(def.get("function_note", ""))
	match state:
		STATE_LOCKED:
			if bool(def.get("is_terminal", false)):
				return "终局房间：需满足特定条件后开启"
			var lines: Array[String] = [
				"废弃房间——修复需 %s，进度靠完成战斗推进" % cost_text(def.get("cost", {}))]
			if not fn.is_empty():
				lines.append("修复后：%s" % fn)
			var ups := upgrade_lines_preview(room_id)
			if not ups.is_empty():
				lines.append(ups)
			return "\n".join(lines)
		STATE_REPAIRING:
			var head := ("修复进度冻结：反应堆上线后继续" if frozen
				else "修复中 %d%%：每完成一场战斗推进一格" % int(round(progress * 100.0)))
			if not fn.is_empty():
				head += "\n修复后：%s" % fn
			return head
		_:
			if not upgrade_tag.is_empty():
				var line := upgrade_line(room_id, level + 1)
				if line.is_empty():
					return "%s：点击打开房间面板查看详情" % upgrade_tag
				return "%s\n目标：%s" % [upgrade_tag, line]
			var base := fn if not fn.is_empty() else str(def.get("tag", ""))
			if level >= 2:
				base += " · Lv%d" % level
			var next_line := upgrade_line(room_id, level + 1)
			if not next_line.is_empty():
				base += "\n▲ 可升级——%s" % next_line
			return base

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
