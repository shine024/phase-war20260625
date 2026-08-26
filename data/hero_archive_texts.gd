extends RefCounted
class_name HeroArchiveTexts
## 余烬要塞 P3 · 英雄档案文案（30 位牺牲相位师）
## 数据源：data/enemy_phase_masters_*.gd（姓名/称号/等级/系别现成），
## 本文件补"生前事迹 + 遗言"两组叙事文本。
## P3 首批：001-010 十位 bespoke；其余走 GENERIC 兜底（后续批次补齐）。
##
## 基调：敌方相位师 = 曾经牺牲的英雄。他们的"敌对"只是时间线的回响——
## 每一句遗言都写给未来读到它的人（陈末）。

## 系别显示名
const FACTION_NAMES := {
	"steel": "钢铁系",
	"flame": "烈焰系",
	"thunder": "雷霆系",
	"void": "虚空系",
	"all": "全能",
}

static func faction_display(faction: String) -> String:
	if FACTION_NAMES.has(faction):
		return FACTION_NAMES[faction]
	if faction.begins_with("steel_"):
		return "钢铁混融系"
	if faction.begins_with("thunder_"):
		return "雷霆混融系"
	if faction.begins_with("void_"):
		return "虚空混融系"
	if faction.begins_with("flame_"):
		return "烈焰混融系"
	return "混融系"

## 编号 → 时代（对齐 enemy_phase_masters 分文件：每时代 6 位）
static func era_display(master_id: String) -> String:
	var num := 0
	for c in master_id.replace("enemy_master_", ""):
		if not c.is_valid_int():
			break
		num = num * 10 + int(c)
	if num <= 0:
		return "未知时代"
	if num <= 6:
		return "一战回响"
	elif num <= 12:
		return "二战回响"
	elif num <= 18:
		return "冷战回响"
	elif num <= 24:
		return "现代回响"
	return "近未来回响"

## ── 十位 bespoke（P3 首批）──
## deed: 生前事迹一句 / last_words: 遗言一句（陈末在档案室读到的）
const BESPOKE := {
	"enemy_master_001": {
		"deed": "他在自己的时间线守住了最后一条防线十七天。援军始终没有来，防线始终没破。",
		"last_words": "「如果还有下一个守防线的人——请替我看看战争结束后的天空。」",
	},
	"enemy_master_002": {
		"deed": "她把烈焰相位仪的输出功率推到了理论极限的百分之一百四十。那天她烧穿了一整个虫巢。",
		"last_words": "「火焰熄灭之前，请告诉我，它亮过。」",
	},
	"enemy_master_003": {
		"deed": "他能在 0.3 秒内完成七目标闪电链分配。战友说那不是反应快，是他提前替所有人想好了。",
		"last_words": "「雷声是天空在数名字。别把我数漏了。」",
	},
	"enemy_master_004": {
		"deed": "他撕开过一道稳定了 41 秒的维度裂口，让两个基地的人互道了再见。没有人知道他怎么做到的。",
		"last_words": "「门的两边都是家。可惜我只能守一边。」",
	},
	"enemy_master_005": {
		"deed": "「不可破之盾」的名号来自一场败仗——盾碎了，他没退。后来的记录停在第三页。",
		"last_words": "「盾牌的意义不是不死，是身后的人多活一秒。」",
	},
	"enemy_master_006": {
		"deed": "她焚毁了自己的相位核心，只为把虫潮从撤离走廊引开。撤离名单上有 4003 个名字。",
		"last_words": "「毁灭之焰烧完之后，灰烬里也能种东西。我试过。」",
	},
	"enemy_master_007": {
		"deed": "万钧雷霆落下之前，他先把三支平民车队引出了雷区。他的战斗日志最后一行是坐标，不是遗言。",
		"last_words": "「跟着坐标走。别回头看我放电的地方。」",
	},
	"enemy_master_008": {
		"deed": "他把维度撕裂者的能力用来做了一件小事：把一条被切断的通讯，重新接通了 4 分钟。",
		"last_words": "「听见了吗？那 4 分钟里，所有人都在说活下去。」",
	},
	"enemy_master_009": {
		"deed": "钢铁军团在他身后重组了十一次。第十一次，军团还在，统帅的位置空了。",
		"last_words": "「军团不是我。军团是每一个站过夜岗的人。」",
	},
	"enemy_master_010": {
		"deed": "永恒烈焰烧了三天三夜，护住了冬眠库的电力。人们从冬眠中醒来时，火已熄，人已冷。",
		"last_words": "「我用最后一根火柴点了个大的。值得。」",
	},
}

## 未撰写 bespoke 的英雄走此兜底（按系别给不同文本）
const GENERIC_BY_FACTION := {
	"steel": {
		"deed": "一名钢铁系的守望者。他的记录残缺，只知道防线多守了一夜。",
		"last_words": "「墙还在。这就够了。」",
	},
	"flame": {
		"deed": "一名烈焰系的突击者。冲锋的坐标至今仍在战报里闪烁。",
		"last_words": "「烧到最后一刻，就不算输。」",
	},
	"thunder": {
		"deed": "一名雷霆系的支援者。雷光落下的地方，队友曾三次突围成功。",
		"last_words": "「听雷。那是我在替你们数敌人。」",
	},
	"void": {
		"deed": "一名虚空系的观测者。她在裂缝边缘写下了大量笔记，笔迹越来越轻。",
		"last_words": "「深渊我替你们看过了。别怕，它也会累。」",
	},
}
const GENERIC_DEFAULT := {
	"deed": "一位被时间线记住的守望者。事迹散佚，名字犹存。",
	"last_words": "「轮到你了。往前走。」",
}

## 统一查询：返回 {deed, last_words, bespoke: bool}
static func get_texts(master_id: String, faction: String) -> Dictionary:
	if BESPOKE.has(master_id):
		var b: Dictionary = BESPOKE[master_id]
		return {"deed": b["deed"], "last_words": b["last_words"], "bespoke": true}
	if GENERIC_BY_FACTION.has(faction):
		var g: Dictionary = GENERIC_BY_FACTION[faction]
		return {"deed": g["deed"], "last_words": g["last_words"], "bespoke": false}
	return {"deed": GENERIC_DEFAULT["deed"], "last_words": GENERIC_DEFAULT["last_words"], "bespoke": false}

## 情感阶段切换字幕（bunker_main 全屏渐黑播报）
const STAGE_TITLES := {
	1: "第一阶段 · 麻木\n「反正……只是个梦吧。」",
	2: "第二阶段 · 投入\n「也许……我该认真对待这件事。」",
	3: "第三阶段 · 羁绊\n「我记得你们每一个人的名字。」",
	4: "第四阶段 · 选择\n「所有的灯都亮着。是时候了。」",
}

## 通讯室预录来电（随进度变化；fragments=已集碎片数, reactor=反应堆是否上线）
static func comms_latest_call(fragments: int, reactor_online: bool) -> String:
	if reactor_online:
		return "「反应堆的嗡鸣声，和你那边一样吗？……不。你那边的，还活着。」"
	if fragments >= 5:
		return "「新星的兄弟们撑住了东线。如果你听到这条留言——我们没能等到答复。」"
	return "「这里是钢壁防务……你那边，还好吗？」——信号在此处中断"
