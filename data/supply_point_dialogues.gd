extends RefCounted
class_name SupplyPointDialogues
## 补给点对话池（v6.71 动态补给网 M5 对话三层·第二层）。
##
## 三层对话口径（拍板）：
##   ① 驻守/时代锚关 = data/campaign_narrative.gd GARRISON_LINES/ERA_RITES 原样
##   ② 本文件：时代 5 池×6 条，关卡弹窗副句槽按 (day+level) seed 轮换
##   ③ 状态播报（告急/陷落/收复/回溯/迷失/评分刷新）走 SignalBus.feed_message
##
## 文案纪律：纯文本无 emoji（CJK 字体豆腐块教训）；「相位师」称谓全局改「相位师」；
## 总纲——所有相位师（玩家与地图 30 位）都是各时代穿越来的战友，共同目标：抵达黑门、
## 进入并关闭它。普通士兵不能成长，只能固守各关补给点。

const POOLS: Dictionary = {
	1: [
		"补给点的水是安全的，放心喝。",
		"前沿的弟兄换了一茬又一茬，番号没变。",
		"铁丝网昨天又拉了一层，渗透的家伙不吃这套也得绕。",
		"要是打到黑门了，替我们看一眼那是什么。",
		"弹药账本差一颗子弹都过不了关，别怪补给官啰嗦。",
		"我们守的不是这条战线，是你们回家的路。",
	],
	2: [
		"码头的箱子堆到了天际线，全是往黑门方向去的。",
		"无线电里全是杂音，但密码台每晚都亮着。",
		"上次渗透来的时候，探照灯把夜空切成了格子。",
		"老兵说：补给线就是第二条生命。",
		"别信 shortcut，地图上没有的路都是陷阱。",
		"我们在后方守着，你们在前方打赢，这买卖不亏。",
	],
	3: [
		"警戒级别又提了一档，渗透的信号在图上爬。",
		"冷战没有硝烟，但威胁值是真的。",
		"预警雷达每多扫一圈，我们就多睡十分钟。",
		"隧道里存了三个月的给养，希望用不上。",
		"说好了，谁先到黑门，谁给其他人留个信。",
		"这里安静，安静得像暴风雨前。",
	],
	4: [
		"数据链全线通畅，威胁评估每小时刷新一次。",
		"无人机传回来的画面里，黑门比上个月又大了。",
		"补给算法说这个缺口该补了，它通常是对的。",
		"渗透点清一处少一处，别让它们连成片。",
		"我们不太会说话，但账目从不出错。",
		"守住补给点，就是守住你们冲锋的姿态。",
	],
	5: [
		"时空回溯的窗口还开着，但人救不回来，设备可以。",
		"曲率引擎预热完成，随时可以再进一步。",
		"黑门的引力在变大，我们都在同一张网上。",
		"观测站记录到迷失者的信号，他们还在门里走。",
		"补给网是最后的防线，比任何武器都可靠。",
		"到了门前，记得回头看看——整条战线都亮着灯。",
	],
}

## 取某时代一条对话（纯函数，day+level 决定性轮换，无状态）
static func pick_line(era: int, day: int, level: int) -> String:
	var pool: Array = POOLS.get(era, [])
	if pool.is_empty():
		return ""
	var idx: int = absi(hash("%d_%d" % [day, level])) % pool.size()
	return String(pool[idx])

## 弹窗副句槽优先级（M5 三层口径）：驻守相位师在场 → 叙事层原话；否则 → 本池轮换句。
## narrative_line 由调用方从 campaign_narrative 查得后传入，空串表示无驻守语。
static func popup_subtitle(level: int, era: int, day: int, narrative_line: String) -> String:
	if not narrative_line.is_empty():
		return narrative_line
	return pick_line(era, day, level)
