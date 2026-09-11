extends RefCounted
## 序章漫画开场 · 分格数据（docs/开场剧情_10方案.md 方案1）
## 深航计划版（2026-09 重写）：删去"梦中未来的我"时间线，改为"深航计划"主线（12 格）——
##   旧日和平 → 暗能星域 → 天空裂开入侵 → 无力 → 生灵 → 并肩希望 → 相位仪与卡牌 →
##   黑门降临（太晚了）→ 深航计划 → 千人回溯出发 → 时空乱流失散 → 找同伴。
## v27.12 参考战火使命：第七夜（失眠梦，旧稿遗留无回报）换"旧日"和平日常格——
##   先给理所当然的日常，再砸异变，对比更强且无梦设定坑。
## v27.13 重排：星域格（b5_nebula 旧图复用）插入侵前交代宇宙级成因；卡牌格挪太迟后
##   （希望→武装化）；"但力量觉醒得，太晚了"并入黑门格作转折。
## 核心设定锚点：战场上交火的不是敌人，是同批回溯、迷失在时代里的相位师同伴。
## 暗能/卡牌/迷失/符文体系见 docs/暗能卡牌世界观.md（设定真身，b4/b9/b10 文案取源于它）。
## motif 对应 scenes/intro/comic_art.gd 的程序化画格绘制器（新格复用既有 motif 作兜底）；
## 可选 "texture" 字段填贴图路径即用真图替换程序化画格。
## ⚠️ 待生成真图（FLOW，缺图自动退化为 motif 程序画格）：
##   b6_black_gates / b7_deep_voyage / b8_sacrifice / b10_rift_stream（.png，1280×720）

const PANELS: Array = [
	{
		"id": "b1_peace",
		"texture": "res://assets/intro/comic/b1_peace.png",
		"motif": "nebula",
		"accent": Color(1.0, 0.82, 0.5),
		"title": "旧日",
		"text": "和平得太久，久到人们以为那是理所当然——灯火如常，车水马龙，岁月无声。",
	},
	{
		"id": "b1a_cosmos",
		"texture": "res://assets/intro/comic/b5_nebula.png",
		"motif": "nebula",
		"accent": Color(0.55, 0.5, 0.9),
		"title": "星域",
		"text": "随着星系的运转，地球滑入了一片暗能星域。正与反的空间彼此侵触——而交汇处，只能存续一个。",
	},
	{
		"id": "b2_invasion",
		"texture": "res://assets/intro/comic/b2_invasion.png",
		"motif": "invasion",
		"accent": Color(0.95, 0.45, 0.18),
		"title": "入侵",
		"text": "然后，天空裂开了。一座黑门悬在天际——门后的东西，正一点点吞掉这个世界。",
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
		"text": "绝望中，有人第一次驯服了入侵精神的暗能——不屈的意志，化作看得见的形状。人们叫它们：生灵。",
	},
	{
		"id": "b2c_too_late",
		"texture": "res://assets/intro/comic/b2c_hope.png",
		"motif": "nebula",
		"accent": Color(1.0, 0.8, 0.45),
		"title": "太迟",
		"text": "人与生灵并肩，人类第一次有了希望。",
	},
	{
		"id": "b9_instrument",
		"texture": "res://assets/intro/comic/b6_cards.png",
		"motif": "cards",
		"accent": Color(1.0, 0.72, 0.32),
		"title": "相位仪与卡牌",
		"text": "科技把这份驾驭解析成式，封入特制卡牌。战斗时以卡为核、相位仪为锚，实体应念具现——这是人类最后的凭仗。",
	},
	{
		"id": "b6_black_gates",
		"texture": "res://assets/intro/comic/b6_black_gates.png",
		"motif": "invasion",
		"accent": Color(0.5, 0.3, 0.85),
		"title": "黑门",
		"text": "但力量觉醒得，太晚了。黑门不止一座——它们在全球成百上千地降临。人类与生灵的一切抵抗，都只是延缓结局。",
	},
	{
		"id": "b7_deep_voyage",
		"texture": "res://assets/intro/comic/b7_deep_voyage.png",
		"motif": "timeline",
		"accent": Color(1.0, 0.84, 0.4),
		"title": "深航计划",
		"text": "大陆种族会议做出最后的决议：启动「深航计划」——回到黑门初立之时，将它们尽数关闭。",
	},
	{
		"id": "b8_departure",
		"texture": "res://assets/intro/comic/b8_sacrifice.png",
		"motif": "nebula",
		"accent": Color(0.95, 0.4, 0.25),
		"title": "出发",
		"text": "光焰照亮夜空。千名相位师的车队发动引擎，逆着时间驶入光中——而你，就在车队之中。",
	},
	{
		"id": "b10_rift_stream",
		"texture": "res://assets/intro/comic/b10_rift_stream.png",
		"motif": "overlap",
		"accent": Color(0.65, 0.5, 0.95),
		"title": "时空乱流",
		"text": "传送途中，暗能量不断撕碎记忆与精神，战士们的理智逐渐消散——迷失的同伴，散落在时代各处。",
	},
	{
		"id": "b11_comrades",
		"texture": "res://assets/intro/comic/b7_comrades.png",
		"motif": "timeline",
		"accent": Color(0.75, 0.55, 0.7),
		"title": "同伴",
		"text": "去找到他们。还记得自己的，就请他们并肩同行；已经迷失的——就战胜他们，带着他们的力量，继续前进。",
	},
]

static func count() -> int:
	return PANELS.size()
