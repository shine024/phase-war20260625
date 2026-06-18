extends RefCounted
class_name StoryChapters
## 剧情模式章节定义（8章，覆盖一战→近未来）
##
## 章节结构：
##   - 普通章(battle_type=level_map)：映射到现有关卡，复用关卡数据
##   - Boss章(battle_type=custom)：自定义 PhaseMaster 配置
##
## 对话格式：
##   {"speaker": "角色名", "portrait_id": "portrait_xxx", "text": "对话内容"}

# ── 战斗类型 ───────────────────────────────────────────────────────

const BATTLE_LEVEL_MAP: String = "level_map"  ## 映射到现有关卡
const BATTLE_CUSTOM: String = "custom"        ## 自定义Boss战（PhaseMaster配置）

# ── 8个剧情章节 ───────────────────────────────────────────────────

const ALL_CHAPTERS: Array[Dictionary] = [
	# ═══════════ 第1章：序章 — 一战 ═══════════
	{
		"id": "chapter_1",
		"chapter_num": 1,
		"title": "序章：战争黎明",
		"subtitle": "一战 · 1916 · 索姆河",
		"era": "ww1",
		"battle_type": BATTLE_LEVEL_MAP,
		"level_override": 5,
		"custom_battle": null,
		"is_boss_chapter": false,
		"unlock_next": "chapter_2",
		"pre_battle_dialogues": [
			{"speaker": "旁白", "portrait_id": "", "text": "1916年，索姆河。炮火撕裂了黎明的宁静，你从相位裂缝中跌落在这片焦土之上。"},
			{"speaker": "参谋长", "portrait_id": "", "text": "你是……从哪里来的？这身装备……罢了，前线告急！敌方正在集结，我们需要一切能用的力量。"},
			{"speaker": "指挥官", "portrait_id": "", "text": "我是相位指挥官。给我一支队伍，我能扭转这场战役。"},
			{"speaker": "参谋长", "portrait_id": "", "text": "好大的口气。那就证明给我看——守住索姆河防线！"},
		],
		"post_battle_dialogues": [
			{"speaker": "参谋长", "portrait_id": "", "text": "难以置信……你的'相位技术'竟然能让部队协同到这种程度。"},
			{"speaker": "指挥官", "portrait_id": "", "text": "这只是开始。我感知到更深处的相位波动……战争远未结束。"},
		],
	},

	# ═══════════ 第2章：铁血洪流 — 一战 ═══════════
	{
		"id": "chapter_2",
		"chapter_num": 2,
		"title": "铁血洪流",
		"subtitle": "一战 · 1918 · 凡尔登",
		"era": "ww1",
		"battle_type": BATTLE_LEVEL_MAP,
		"level_override": 15,
		"custom_battle": null,
		"is_boss_chapter": false,
		"unlock_next": "chapter_3",
		"pre_battle_dialogues": [
			{"speaker": "旁白", "portrait_id": "", "text": "凡尔登，绞肉机。你的名声已在前线传开，但真正的考验才刚刚开始。"},
			{"speaker": "情报官", "portrait_id": "", "text": "指挥官，敌方调来了重型火炮阵列。常规部队恐怕扛不住。"},
			{"speaker": "指挥官", "portrait_id": "", "text": "重型火炮？正好，让我的相位装甲单位去会会它们。"},
		],
		"post_battle_dialogues": [
			{"speaker": "情报官", "portrait_id": "", "text": "敌军溃退了！但侦察兵报告，敌方后方有异常的能量反应……"},
			{"speaker": "指挥官", "portrait_id": "", "text": "相位反应……难道这个时代也有相位师？全员戒备，准备迎击！"},
		],
	},

	# ═══════════ 第3章：堑壕终结者 — 一战Boss ═══════════
	{
		"id": "chapter_3",
		"chapter_num": 3,
		"title": "堑壕终结者",
		"subtitle": "一战Boss · 相位师遭遇战",
		"era": "ww1",
		"battle_type": BATTLE_CUSTOM,
		"level_override": 20,
		"custom_battle": {
			"master_name": "铁血男爵",
			"faction": "void",
			"era": 0,
			"stats": {"max_hp": 8000, "attack_power": 400, "defense": 300, "energy_regen": 8, "unit_limit": 6},
			"description": "一战时代的相位师，驾驭着蒸汽朋克风格的重型战争机器。",
		},
		"is_boss_chapter": true,
		"unlock_next": "chapter_4",
		"pre_battle_dialogues": [
			{"speaker": "旁白", "portrait_id": "", "text": "战场中央，一台巨大的蒸汽战争机器轰鸣着启动。它的驾驶舱里，坐着一个眼神疯狂的男人。"},
			{"speaker": "铁血男爵", "portrait_id": "", "text": "又来一个相位师？哈哈哈！这个时代的相位能量归我所有！"},
			{"speaker": "指挥官", "portrait_id": "", "text": "你扭曲了相位场，制造了这场无谓的屠杀。到此为止了。"},
			{"speaker": "铁血男爵", "portrait_id": "", "text": "那就来试试——看是你的未来技术强，还是我的蒸汽铁兽凶！"},
		],
		"post_battle_dialogues": [
			{"speaker": "旁白", "portrait_id": "", "text": "蒸汽巨兽轰然倒塌。铁血男爵的相位核心碎裂，释放出一道时空裂缝。"},
			{"speaker": "指挥官", "portrait_id": "", "text": "这道裂缝……通向二十年后。看来命运的齿轮还在转动。"},
			{"speaker": "参谋长", "portrait_id": "", "text": "指挥官，时空稳定了。我们获得了大量的相位数据和……符文。"},
		],
	},

	# ═══════════ 第4章：闪电战 — 二战 ═══════════
	{
		"id": "chapter_4",
		"chapter_num": 4,
		"title": "闪电战",
		"subtitle": "二战 · 1939 · 波兰",
		"era": "ww2",
		"battle_type": BATTLE_LEVEL_MAP,
		"level_override": 25,
		"custom_battle": null,
		"is_boss_chapter": false,
		"unlock_next": "chapter_5",
		"pre_battle_dialogues": [
			{"speaker": "旁白", "portrait_id": "", "text": "1939年。你穿越时空裂缝，来到了一个钢铁与火焰的新时代。"},
			{"speaker": "指挥官", "portrait_id": "", "text": "坦克集群、俯冲轰炸机……闪电战的雏形。这个时代的战争节奏快得惊人。"},
			{"speaker": "当地抵抗军", "portrait_id": "", "text": "你是来帮忙的？太好了！敌人的装甲矛头正在突破防线！"},
		],
		"post_battle_dialogues": [
			{"speaker": "当地抵抗军", "portrait_id": "", "text": "你的部队部署太快了！敌人根本反应不过来。"},
			{"speaker": "指挥官", "portrait_id": "", "text": "速度就是一切。但我感应到更危险的相位波动正在酝酿……"},
		],
	},

	# ═══════════ 第5章：钢铁洪流 — 二战 ═══════════
	{
		"id": "chapter_5",
		"chapter_num": 5,
		"title": "钢铁洪流",
		"subtitle": "二战 · 1943 · 库尔斯克",
		"era": "ww2",
		"battle_type": BATTLE_LEVEL_MAP,
		"level_override": 35,
		"custom_battle": null,
		"is_boss_chapter": false,
		"unlock_next": "chapter_6",
		"pre_battle_dialogues": [
			{"speaker": "旁白", "portrait_id": "", "text": "库尔斯克，人类历史上最大的坦克会战即将爆发。"},
			{"speaker": "参谋长", "portrait_id": "", "text": "指挥官，情报显示敌方集结了前所未有的装甲力量。"},
			{"speaker": "指挥官", "portrait_id": "", "text": "正好。让我的相位装甲集群和他们正面对决——看谁的钢铁更硬！"},
		],
		"post_battle_dialogues": [
			{"speaker": "参谋长", "portrait_id": "", "text": "胜利！但敌方主力相位师现身了。这是一个比铁血男爵更强的存在。"},
			{"speaker": "指挥官", "portrait_id": "", "text": "我感应到了。他的相位核心已经接近……觉醒。准备最终决战。"},
		],
	},

	# ═══════════ 第6章：帝国陨落 — 二战Boss ═══════════
	{
		"id": "chapter_6",
		"chapter_num": 6,
		"title": "帝国陨落",
		"subtitle": "二战Boss · 钢铁相位师",
		"era": "ww2",
		"battle_type": BATTLE_CUSTOM,
		"level_override": 40,
		"custom_battle": {
			"master_name": "钢铁元帅",
			"faction": "void",
			"era": 1,
			"stats": {"max_hp": 15000, "attack_power": 700, "defense": 500, "energy_regen": 10, "unit_limit": 7},
			"description": "掌控整个二战相位网络的元帅，他的意志能驱动整个装甲集团军。",
		},
		"is_boss_chapter": true,
		"unlock_next": "chapter_7",
		"pre_battle_dialogues": [
			{"speaker": "钢铁元帅", "portrait_id": "", "text": "你就是那个搅乱时空的虫子？我等你好久了。"},
			{"speaker": "指挥官", "portrait_id": "", "text": "你用相位力量发动战争，无数人因你而死。"},
			{"speaker": "钢铁元帅", "portrait_id": "", "text": "弱者才在意伤亡。强者……重塑世界！受死吧！"},
		],
		"post_battle_dialogues": [
			{"speaker": "旁白", "portrait_id": "", "text": "钢铁元帅倒下了。他的相位核心爆炸，撕裂出通往冷战时代的裂缝。"},
			{"speaker": "指挥官", "portrait_id": "", "text": "两个相位师倒下了，但相位波动越来越强。源头在……未来。"},
			{"speaker": "参谋长", "portrait_id": "", "text": "前方发现新的时空通道。指挥官，我们继续前行。"},
		],
	},

	# ═══════════ 第7章：冷战暗影 — 冷战 ═══════════
	{
		"id": "chapter_7",
		"chapter_num": 7,
		"title": "冷战暗影",
		"subtitle": "冷战 · 1962 · 古巴",
		"era": "cold_war",
		"battle_type": BATTLE_LEVEL_MAP,
		"level_override": 50,
		"custom_battle": null,
		"is_boss_chapter": false,
		"unlock_next": "chapter_8",
		"pre_battle_dialogues": [
			{"speaker": "旁白", "portrait_id": "", "text": "1962年。核阴影笼罩世界，而相位战争在暗中悄然升级。"},
			{"speaker": "情报官", "portrait_id": "", "text": "指挥官，这个时代的相位技术已经高度军事化。导弹、卫星、电子战……"},
			{"speaker": "指挥官", "portrait_id": "", "text": "有意思。让我看看冷战双方的相位博弈是什么水平。"},
		],
		"post_battle_dialogues": [
			{"speaker": "情报官", "portrait_id": "", "text": "我们截获了关键情报——相位波的源头指向近未来！"},
			{"speaker": "指挥官", "portrait_id": "", "text": "终于接近真相了。最终Boss……就在那里等着我们。全员准备穿越！"},
		],
	},

	# ═══════════ 第8章：相位觉醒 — 最终Boss ═══════════
	{
		"id": "chapter_8",
		"chapter_num": 8,
		"title": "相位觉醒",
		"subtitle": "最终Boss · 近未来 · 相位源头",
		"era": "future",
		"battle_type": BATTLE_CUSTOM,
		"level_override": 100,
		"custom_battle": {
			"master_name": "相位之主",
			"faction": "void",
			"era": 4,
			"stats": {"max_hp": 30000, "attack_power": 1200, "defense": 800, "energy_regen": 15, "unit_limit": 8},
			"description": "操纵所有相位裂缝的终极存在，它的觉醒将终结一切时间线。",
		},
		"is_boss_chapter": true,
		"unlock_next": null,  # 最终章，无后续
		"pre_battle_dialogues": [
			{"speaker": "旁白", "portrait_id": "", "text": "近未来。时空裂缝的交汇点。一个巨大的相位核心悬浮在城市废墟上空。"},
			{"speaker": "相位之主", "portrait_id": "", "text": "你跨越了整个时间线来找我？愚蠢的相位师……你不过是我的实验品。"},
			{"speaker": "指挥官", "portrait_id": "", "text": "你制造了所有战争，收割每个时代的相位能量。今天一切终结！"},
			{"speaker": "相位之主", "portrait_id": "", "text": "终结？不。我即是相位本身。与我融合，还是——毁灭？"},
		],
		"post_battle_dialogues": [
			{"speaker": "旁白", "portrait_id": "", "text": "相位核心崩塌。时空裂缝逐一愈合，战争的阴霾终于散去。"},
			{"speaker": "参谋长", "portrait_id": "", "text": "指挥官……我们做到了。所有时间线的相位波动都消失了。"},
			{"speaker": "指挥官", "portrait_id": "", "text": "不，相位不会消失。它只是回归了平衡。而我们——守护这份平衡。"},
			{"speaker": "旁白", "portrait_id": "", "text": "【剧情模式完成】感谢游玩！自由模式中，你解锁的全部卡牌和符文将继续陪伴你。"},
		],
	},
]

# ── 查询接口 ───────────────────────────────────────────────────────

## 按ID获取章节定义
static func get_chapter(chapter_id: String) -> Dictionary:
	for ch in ALL_CHAPTERS:
		if ch["id"] == chapter_id:
			return ch
	return {}

## 获取第一章ID
static func get_first_chapter_id() -> String:
	if ALL_CHAPTERS.is_empty():
		return ""
	return ALL_CHAPTERS[0]["id"]

## 获取下一章ID（无则返回空字符串）
static func get_next_chapter_id(chapter_id: String) -> String:
	var ch := get_chapter(chapter_id)
	if ch.is_empty():
		return ""
	return ch.get("unlock_next", "")

## 获取所有章节ID（按顺序）
static func get_all_chapter_ids() -> Array[String]:
	var ids: Array[String] = []
	for ch in ALL_CHAPTERS:
		ids.append(ch["id"])
	return ids

## 获取章节总数
static func get_chapter_count() -> int:
	return ALL_CHAPTERS.size()

## 判断是否为最终章
static func is_final_chapter(chapter_id: String) -> bool:
	var ch := get_chapter(chapter_id)
	return ch.get("unlock_next", "") == ""

## 获取章节序号（1-based）
static func get_chapter_number(chapter_id: String) -> int:
	var ch := get_chapter(chapter_id)
	return int(ch.get("chapter_num", 0))
