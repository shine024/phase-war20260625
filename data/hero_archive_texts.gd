extends RefCounted
class_name HeroArchiveTexts
## 余烬要塞 P3 · 英雄档案文案（30 位牺牲相位师）
## 数据源：data/enemy_phase_masters_*.gd（姓名/称号/等级/系别现成），
## 本文件补"生前事迹 + 遗言"两组叙事文本。
## 2026-08-26 补齐：001-030 全部 bespoke（011-030 第二批，按时代风味撰写：
## 011-012 二战 / 013-018 冷战 / 019-024 现代 / 025-030 近未来）。
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
	"enemy_master_011": {
		"deed": "城市攻防战第七夜，他把整片雷暴云压在敌军机场上空一整夜。凌晨，己方运输机群无声过境。",
		"last_words": "「最响的雷，是我一声没响的那道。」",
	},
	"enemy_master_012": {
		"deed": "他把整座野战医院折进一道空间夹层，四十天后战争路过那里——医院完好，他没能出来。",
		"last_words": "「我走进去的地方没有昼夜。你们替我晒晒太阳。」",
	},
	"enemy_master_013": {
		"deed": "寒潮切断补给的那个月，他把缴获的装甲熔成犁头与炉栅。阵地慢慢变成了村子。",
		"last_words": "「熔掉的是钢铁，铸出来的是日子。」",
	},
	"enemy_master_014": {
		"deed": "他让电磁装甲反向吞下三次核爆级电磁脉冲，保住了一座地下指挥所的电台，和人心。",
		"last_words": "「挡不住的东西，就吃下来，变成电。」",
	},
	"enemy_master_015": {
		"deed": "她烧的不是敌人，是熵——一台停摆三十年的净水机组，被她的熵减之焰重新点燃。",
		"last_words": "「一切都会冷掉。所以火才显得贵重。」",
	},
	"enemy_master_016": {
		"deed": "掩体主梁震断的那夜，他以装甲形态顶住塌方四个小时。所有人都出来了，他保持着顶举的姿势。",
		"last_words": "「别搬开石头找我。我在的位置，现在是根柱子。」",
	},
	"enemy_master_017": {
		"deed": "追兵距撤离渡口只剩九分钟。他烧掉了那座桥，连同自己的退路。",
		"last_words": "「黄昏烧完了，明天照样升起。替我看。」",
	},
	"enemy_master_018": {
		"deed": "他的雷全部落在阵地外围，围出一圈谁也不敢踏入的焦土。那年冬天，圈内圈外没死一个人。",
		"last_words": "「雷停的时候，记得回家。」",
	},
	"enemy_master_019": {
		"deed": "「世界吞噬者」的战绩档案只有一行加粗记录：吞掉三枚来袭的巡航导弹。",
		"last_words": "「我吞下过最苦的东西，是那天的天空。」",
	},
	"enemy_master_020": {
		"deed": "全频段电磁压制下，他把装甲当成天线，替七座孤岛阵地中转了最后一批家书。",
		"last_words": "「电波会衰减。话不会。」",
	},
	"enemy_master_021": {
		"deed": "他把混沌之焰压进一支信号弹射向夜空。那一晚，全城提前看见了黎明。",
		"last_words": "「乱糟糟的火也是火。黑暗才没有形状。」",
	},
	"enemy_master_022": {
		"deed": "钢铁风暴扫过之处敌军装备尽数瘫痪——战后统计，无一人员死亡。他说这叫拆解，不叫歼灭。",
		"last_words": "「机器拆了能重装。人不行。」",
	},
	"enemy_master_023": {
		"deed": "她三次从自己的灰烬里重新燃起。第四次，她把余温留给了身旁十二名重伤的新兵。",
		"last_words": "「重生没什么好羡慕的。会疼，而且要重来。」",
	},
	"enemy_master_024": {
		"deed": "他以自身雷场为航道，引着一场雷暴绕开了难民车队。气象卫星把那晚的云图命名为「让路」。",
		"last_words": "「风替我到过很多地方。你们也算。」",
	},
	"enemy_master_025": {
		"deed": "他把整支巡逻队藏进自己的影子里八小时。影子里很黑——他说，黑，但安全。",
		"last_words": "「怕黑的话，就把黑收进怀里养。」",
	},
	"enemy_master_026": {
		"deed": "停战前夜，他的锻造炉没有赶制武器——两百把锄头，在炉火熄灭前列完了清单。",
		"last_words": "「神不打铁的日子，就只是个铁匠。」",
	},
	"enemy_master_027": {
		"deed": "炼狱之焰她收放自如——最低一档恒温三十七度，曾为医疗队烘干过全部绷带。",
		"last_words": "「地狱之火的正确用法，是暖手。」",
	},
	"enemy_master_028": {
		"deed": "轨道武器坠落的最后三秒，他把雷霆全部引向自己。地面的人只看见一场很近、无害的雷雨。",
		"last_words": "「神迹不稀奇。稀奇的是你们把战争熬成了日子。」",
	},
	"enemy_master_029": {
		"deed": "长夜最难熬的那半年，她把星空折叠到了地表。孩子们第一次在战区看见了银河。",
		"last_words": "「夜不是空的。夜是还没点亮的屋子。」",
	},
	"enemy_master_030": {
		"deed": "四系融合的第一人。可她的实验日志里写满的不是功率参数，而是三十个没能等到停战的名字。",
		"last_words": "「我是第三十一个。往后每一个，都算我们赢。」",
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

## 通讯室预录来电（随碎片进度渐变；fragments=已集碎片数, reactor=反应堆是否上线）
## 声音设定：另一条时间线里的幸存者电台——陈末集齐的遗物越多，
## 那头的战争越接近尾声，留言也从呼救渐变为告别。
static func comms_latest_call(fragments: int, reactor_online: bool) -> String:
	if reactor_online:
		return "「反应堆的嗡鸣声，和你那边一样吗？……不。你那边的，还活着。」"
	if fragments >= 30:
		return "「三十个名字，一个不少。留言到此为止——接下来的路，你自己走。风停了。」"
	if fragments >= 25:
		return "「就差最后几位了。等你们都到齐，我们就把电台关掉，去过日子。」"
	if fragments >= 20:
		return "「名单过半了。孩子问纪念碑刻得下吗——我说，刻不下就刻两遍。」"
	if fragments >= 15:
		return "「东线的灯又少了一盏。但我们学会了自己发电。」"
	if fragments >= 10:
		return "「十位了。」留言的尾声有孩子们在合唱，跑调，但很响。"
	if fragments >= 5:
		return "「新星的兄弟们撑住了东线。如果你听到这条留言——我们没能等到答复。」"
	if fragments >= 1:
		return "第一个名字被念出来的时候，电台那头沉默了很久。「……原来还有人记得。」"
	return "「这里是钢壁防务……你那边，还好吗？」——信号在此处中断"

## ── P4 预备：观星台终局三选一文案（文本先行定稿，UI 待 P4 接线）──
## 前提：全房间修复 + 通关 100 关 + 集齐 30 英雄遗物 → 观星台开门。
const OBSERVATORY_PROLOGUE := "门开了。\n门的另一边不是战场，是三十个人用一生守出来的答案。\n现在，轮到陈末回答。"

## 三选一：rewrite=拨回时间线 / keep=接过守望 / depart=走进门远行
const OBSERVATORY_ENDINGS := {
	"rewrite": {
		"title": "重写",
		"choice": "拨回时间线——让三十次牺牲从未发生。\n代价：不会再有人记得他们。",
		"resolution": "他松开手，任凭光流冲刷记忆。名字一个一个变淡，像退潮。\n最后一刻他笑了：没关系。\n他们做过的事，时间线会替他们记得。",
		"emblem": "结局徽记 · 忘却之环",
	},
	"keep": {
		"title": "守望",
		"choice": "留下来——接过第三十一个名字的位置，\n把这座基地的灯守下去。",
		"resolution": "「收到。」他说。\n从今往后的每一夜，基地的灯都会亮着。\n有人迷路了，就朝这里走。",
		"emblem": "结局徽记 · 持灯者",
	},
	"depart": {
		"title": "远行",
		"choice": "走进门——带着在这里学会的一切，\n去另一条还在打仗的时间线。",
		"resolution": "他最后看了一眼灯全亮着的基地，跨过门。\n身后，三十盏灯同时亮了一下，\n像挥手。",
		"emblem": "结局徽记 · 启程之星",
	},
}

static func observatory_ending(id: String) -> Dictionary:
	return OBSERVATORY_ENDINGS.get(id, {}).duplicate(true)
