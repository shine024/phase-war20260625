extends RefCounted
## 序章漫画开场 · 分格数据（docs/开场剧情_10方案.md 方案1）
## v24.5：7 格 → 11 格（7+4）——B2 摘掉可玩战斗钩，改纯讲述：
##   新增 B2a 无力 / B2b 生灵 / B2c 希望（力量起源）+ B7 战友（"你打的不是敌人"核心设定）。
## 每格对应一个剧情节拍（B1–B8）；B8 之后的"醒来"由 bunker_main 的醒来演出承接。
## motif 对应 scenes/intro/comic_art.gd 的程序化画格绘制器（新格复用既有 motif 作兜底）；
## 可选 "texture" 字段填贴图路径即用真图替换程序化画格（FLOW 生成，comic_intro 已留位）。

const PANELS: Array = [
	{
		"id": "b1_insomnia",
		"texture": "res://assets/intro/comic/b1_insomnia.png",
		"motif": "insomnia",
		"accent": Color(0.85, 0.25, 0.22),
		"title": "第七夜",
		"text": "连续七天，同一个梦。头痛、失眠——闹钟又一次停在 03:47。",
	},
	{
		"id": "b2_invasion",
		"texture": "res://assets/intro/comic/b2_invasion.png",
		"motif": "invasion",
		"accent": Color(0.95, 0.45, 0.18),
		"title": "入侵",
		"text": "梦里，天空是裂开的。不属于任何已知的东西，正一点点地吞掉这个世界。",
	},
	{
		"id": "b2a_powerless",
		"texture": "res://assets/intro/comic/b2a_powerless.png",
		"motif": "invasion",
		"accent": Color(0.5, 0.52, 0.58),
		"title": "无力",
		"text": "在那片天空下，人类没有反抗之力。城市一座接一座地暗下去，逃亡的人群里，连呼喊都是徒劳。",
	},
	{
		"id": "b2b_spirits",
		"texture": "res://assets/intro/comic/b2b_spirits.png",
		"motif": "nebula",
		"accent": Color(0.55, 0.9, 0.85),
		"title": "生灵",
		"text": "直到不甘与执念烧到了尽头——强烈的精神，第一次化作看得见的形状。人们叫它们：生灵。",
	},
	{
		"id": "b2c_hope",
		"texture": "res://assets/intro/comic/b2c_hope.png",
		"motif": "nebula",
		"accent": Color(1.0, 0.8, 0.45),
		"title": "希望",
		"text": "人与生灵并肩站上战场。从那一刻起，人类有了战斗的希望。",
	},
	{
		"id": "b3_future_self",
		"texture": "res://assets/intro/comic/b3_future_self.png",
		"motif": "future_self",
		"accent": Color(0.35, 0.85, 0.95),
		"title": "梦中的“我”",
		"text": "「想活下去的话——我给你一次机会，获得保护自己的力量。」梦里出现了另一个“我”，向我伸出了手。",
	},
	{
		"id": "b5_nebula",
		"texture": "res://assets/intro/comic/b5_nebula.png",
		"motif": "nebula",
		"accent": Color(0.55, 0.5, 0.98),
		"title": "暗能量星域",
		"text": "地球驶入暗能量活跃的星域。在这里，精神可以直接支配能量和物质。",
	},
	{
		"id": "b4_overlap",
		"texture": "res://assets/intro/comic/b4_overlap.png",
		"motif": "overlap",
		"accent": Color(0.65, 0.45, 0.95),
		"title": "空间重叠",
		"text": "暗物质扭曲着空间。当两个空间完全重合，最终只会剩下一个——这就是它们入侵的原因。",
	},
	{
		"id": "b6_cards",
		"texture": "res://assets/intro/comic/b6_cards.png",
		"motif": "cards",
		"accent": Color(1.0, 0.72, 0.32),
		"title": "卡牌",
		"text": "人们在战斗中发现：对如今的普通人而言，以对战斗与科技的理解，结合精神力——卡牌是具现生灵的最佳方式。",
	},
	{
		"id": "b8_timeline",
		"texture": "res://assets/intro/comic/b8_timeline.png",
		"motif": "timeline",
		"accent": Color(1.0, 0.84, 0.4),
		"title": "毁灭的时间线",
		"text": "那个“我”来自一条已经毁灭的时间线——他只来得及抢救下几块时空碎片。而我的时空，那个未来也近了。",
	},
	{
		"id": "b7_comrades",
		"texture": "res://assets/intro/comic/b7_comrades.png",
		"motif": "timeline",
		"accent": Color(0.75, 0.55, 0.7),
		"title": "战友",
		"text": "我将进入时空碎片中，与其中的生灵战斗。他们不是敌人——他们曾是过去或未来并肩作战过的战友。但我要战胜他们，并获得他们的力量。",
	},
]

static func count() -> int:
	return PANELS.size()
