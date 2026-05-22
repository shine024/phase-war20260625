extends RefCounted
class_name LevelInformation
## 关卡详细信息：背景故事、环境、势力控制、可用法则等
##
## 字段：
## - display_name: 关卡显示名称
## - description: 关卡背景故事简介
## - faction_id: 控制该关卡的势力ID
## - environment: 环境配置 { weather, terrain, energy_field, time_of_day }
## - available_law_families: 该关卡允许的法则家族列表（空=全部可用）
##   家族: "STEEL"|"FLAME"|"THUNDER"|"VOID"
## - difficulty_modifier: 难度倍数（影响敌人属性）
##
## 法则限制设计理念：
## - 每关至少允许1个家族（玩家总有选择）
## - Boss关卡（20/40/60/80/100）允许全部4个家族
## - 与关卡所属势力的主家族关系密切
## - 早期关卡限制较严格（1-2个），后期逐渐放宽（2-3个）
## - 特殊关卡有特殊限制（如城市关卡禁虚空等）

const LevelEras = preload("res://data/level_eras.gd")

# 关卡总数：100关 × 5时代
const LEVEL_COUNT = 100

# 关卡信息数据库
var _level_db: Dictionary = {}

func _init() -> void:
	_init_level_information()

func _init_level_information() -> void:
	"""初始化所有100关的信息"""

	# ==================== 一战时代（1-20关）====================
	_add_ww1_levels()

	# ==================== 二战时代（21-40关）====================
	_add_ww2_levels()

	# ==================== 冷战时代（41-60关）====================
	_add_cold_war_levels()

	# ==================== 现代时代（61-80关）====================
	_add_modern_levels()

	# ==================== 近未来时代（81-100关）====================
	_add_future_levels()

func _add_ww1_levels() -> void:
	"""一战（1-20关）：钢壁防务为主
	法则家族限制：
	- 钢壁防务(iron_wall_corp)主控 STEEL，前期关卡限制严格
	- 早期（1-5）仅 STEEL，中期（6-14）加入 FLAME，后期（15-19）加入 THUNDER
	- Boss关（20）全部开放"""
	var descriptions = [
		"晨曦中的索姆河，第一阶段突破作战",
		"泥泞的堡垒区，持续的炮火覆盖",
		"被摧毁的村庄，废墟中的阵地防守",
		"铁丝网阵地，手对手的肉搏战",
		"山丘阵地，视野开阔的攻防战",
		"林地密林，丛林中的游击战",
		"河道要塞，水上运输线的争夺",
		"工业区废墟，工厂遗骸中的激战",
		"平原冲锋，大规模骑兵冲锋战",
		"山谷陷阱，敌方伏击的突围战",
		"补给站争夺，后勤线的防守战",
		"机关枪阵地，死神镰刀的扫射",
		"堑壕防线，步步为营的攻坚",
		"炮火覆盖区，地狱之火的轰炸",
		"城市街道，巷战中的血战",
		"沙地要塞，沙漠中的防御",
		"森林伏击，林间突袭战",
		"鼓动全线，最后的总攻",
		"指挥中枢，敌方司令部争夺战",
		"胜利时刻，一战结束前夜的最后一战",
		# 新增多样化描述
		"沼泽地带，泥泞中的艰难推进",
		"铁路枢纽，物资转运的关键节点",
		"通讯塔楼，无线电波的秘密",
		"医疗站遗址，伤员的最后希望",
		"弹药库爆炸，连环殉爆的震撼",
		"战俘营突袭，解放被囚的战士",
		"瞭望塔防线，高处的狙击战场",
		"浮桥渡口，河流跨越的激战",
		"废弃教堂，战火中的宁静角落",
		"石油设施，燃烧的黑色黄金",
		"潜艇基地，海底威胁的源头",
		"飞艇库房，空中堡垒的停泊地",
		"毒气弥漫，化学武器的恐怖",
		"火焰喷射器，近身的炽热对决",
		"骑兵冲锋，最后的装甲力量展示",
		"狙击手对决，子弹与心跳的赛跑",
		"工兵爆破，铁丝网的撕裂声",
		"堑壕战马拉松，消耗战的极致",
		"毒刺陷阱，隐蔽杀手的狩猎场",
		"信号站劫持，情报战的制高点",
		"炊事车袭击，战争中的日常温情",
		"战地邮局，家书的珍贵传递",
		"红十字医院，中立区的生死线",
		"水塔争夺，水源控制的拉锯战",
		"桥梁保卫战，撤退路线的生死线",
		"后方医院，伤兵归途的驿站",
		"补给线切断，饥饿围困的绝望",
		"战壕足球，士兵们的片刻欢乐",
		"将军指挥所，战略决策的核心"
	]

	for i in range(1, 21):
		var level_num = i
		var faction_id = "iron_wall_corp"
		# 一战法则限制：逐步开放家族
		var families: Array = []
		if i <= 5:
			families = ["STEEL"]
		elif i <= 14:
			families = ["STEEL", "FLAME"]
		elif i <= 19:
			families = ["STEEL", "FLAME", "THUNDER"]
		else:  # Boss关
			families = ["STEEL", "FLAME", "THUNDER", "VOID"]
		# 从描述中提取短名称作为关卡名
		var desc = descriptions[i - 1]
		var short_name = desc.split("，")[0].split(" ")[0]  # 取逗号前的第一个短语
		_level_db[level_num] = {
			"display_name": "一战·%s" % short_name,
			"description": descriptions[i - 1],
			"faction_id": faction_id,
			"environment": _get_environment_for_era_level(LevelEras.Era.WW1, i),
			"available_law_families": families,
			"difficulty_modifier": 0.8 + (i - 1) * 0.02,
		}

func _add_ww2_levels() -> void:
	"""二战（21-40关）：新星兵工为主
	法则家族限制：
	- 新星兵工(nova_arms)主控 FLAME
	- 早期（21-25）仅 FLAME，中期（26-34）加入 STEEL，后期（35-39）加入 THUNDER
	- Boss关（40）全部开放"""
	var descriptions = [
		"不列颠空战，欧洲战场开启",
		"北非沙漠，隆美尔的雄狮之师",
		"苏联前线，莫斯科保卫战",
		"太平洋岛屿，日军防线",
		"诺曼底滩头，D日登陆作战",
		"莱茵河防线，德军最后堡垒",
		"太平洋反攻，岛屿争夺战",
		"柏林前夜，欧洲战场最后冲刺",
		"硫黄岛，血肉磨坊的战场",
		"荷兰冻土，冬季防线突破",
		"法国解放，巴黎光复在即",
		"德国心脏，柏林之战",
		"中国战场，日军在亚洲的最后据点",
		"东南亚，丛林中的绞肉机",
		"缅甸阵地，丛林战的极端",
		"日本本土，最终决战前的岛屿战",
		"冲绳血战，太平洋战争最后的岛屿",
		"原子弹之影，核武的威胁",
		"战争机器，二战巅峰之作",
		"世界重生，新时代的开端",
		# 新增多样化描述
		"斯大林格勒废墟，废墟中的巷战",
		"库尔斯克草原，史上最大规模坦克战",
		"中途岛海战，航母命运的转折点",
		"珍珠港突袭，太平洋战争的导火索",
		"敦刻尔克撤退，失败的胜利",
		"阿拉曼战役，沙漠之狐的陨落",
		"瓜达尔卡纳尔岛，太平洋绞肉机",
		"巴斯通突出部，魔鬼的峡谷",
		"突出部战役，圣诞节的血战",
		"市场花园行动，空降兵的悲剧",
		"布达佩斯围城，多瑙河畔的决战",
		"安特卫普港，物资补给的生命线",
		"鲁尔工业区，工业心脏的争夺",
		"维也纳攻势，纳粹的最终堡垒",
		"柏林地堡，帝国最后的巢穴",
		"波兹坦会议，战后秩序的奠定",
		"广岛与长崎，核时代的开启",
		"满洲边境，关东军的最后挣扎",
		"菲律宾群岛，麦克阿瑟的回归",
		"马里亚纳猎火鸡，空中优势的奠定",
		# 更多扩展
		"加莱海峡，登陆佯攻的掩护",
		"西西里岛，地中海的跳板",
		"卡西诺山，修道院下的血战",
		"安齐奥登陆，滩头的僵持",
		"科罗内斯海战，史上最惨烈的战列舰对决",
		"威尔士亲王号沉没，日不落帝国的落日",
		"俾斯麦号猎杀，大西洋上的追逐",
		"猎杀U艇，大西洋反潜战",
		"珊瑚海海战，航母时代的来临",
		"圣克鲁斯群岛，太平洋的拉锯",
		"塔拉瓦环礁，血腥滩头的教训",
		"塞班岛失守，日本本土门户大开",
		"关岛战役，夺回太平洋要塞",
		"莱特湾海战，史上最大规模海战",
		"神风特攻，疯狂的最后抵抗"
	]

	for i in range(1, 21):
		var level_num = 20 + i
		var faction_id = "nova_arms"
		# 二战法则限制：以FLAME为核心逐步开放
		var families: Array = []
		if i <= 5:
			families = ["FLAME"]
		elif i <= 14:
			families = ["FLAME", "STEEL"]
		elif i <= 19:
			families = ["FLAME", "STEEL", "THUNDER"]
		else:  # Boss关
			families = ["STEEL", "FLAME", "THUNDER", "VOID"]
		var desc = descriptions[i - 1]
		var short_name = desc.split("，")[0].split(" ")[0]
		_level_db[level_num] = {
			"display_name": "二战·%s" % short_name,
			"description": descriptions[i - 1],
			"faction_id": faction_id,
			"environment": _get_environment_for_era_level(LevelEras.Era.WW2, i),
			"available_law_families": families,
			"difficulty_modifier": 1.0 + (i - 1) * 0.025,
		}

func _add_cold_war_levels() -> void:
	"""冷战（41-60关）：以太动力为主
	法则家族限制：
	- 以太动力(aether_dynamics)主控 THUNDER
	- 早期（41-45）THUNDER+STEEL，中期（46-54）加入 FLAME，后期（55-59）加入 VOID
	- Boss关（60）全部开放"""
	var descriptions = [
		"铁幕降临，两极对峙开始",
		"朝鲜半岛，意识形态的冲突",
		"古巴导弹危机，核战争边缘",
		"越南丛林，非传统战争",
		"中东危机，石油与权力的争夺",
		"柏林危机，东西方的对峙",
		"中苏边界，社会主义阵营的裂隙",
		"中东战争，反复的冲突",
		"南美战火，冷战在美洲",
		"阿富汗苏联，帝国的陷阱",
		"东欧剧变，铁幕背后的咆哮",
		"印支战争，美苏代理人",
		"中越战争，同志的兵戈相见",
		"马岛争端，岛屿的血泪",
		"伊朗变革，伊斯兰的觉醒",
		"苏联衰落，帝国的黄昏",
		"古巴导弹，危险的边缘游走",
		"冷战峰值，对立的最高点",
		"苏联解体，帝国的终结",
		"新世界秩序，冷战的落幕",
		# 新增多样化描述
		"柏林墙下，穿越铁幕的逃亡",
		"核潜艇暗战，大洋深处的幽灵",
		"U-2侦察机，被击落的雄鹰",
		"猪湾入侵，切尔诺贝利的阴影",
		"太空竞赛，月球上的旗帜争夺",
		"安哥拉内战，代理人的棋盘",
		"萨尔瓦多内战，中美洲的火焰",
		"格林纳达政变，小国的大博弈",
		"巴拿马运河，战略水道的争夺",
		"乍得冲突，法国的非洲棋局",
		"埃塞俄比亚饥荒，冷战的人道危机",
		"伊朗门事件，秘密交易的曝光",
		"星球大战计划，战略防御的幻想",
		"潘兴导弹，欧洲核均衡的棋子",
		"巡航导弹，新式精确打击的诞生",
		"隐形飞机，雷达盲区的革命",
		"电子战，信息时代的雏形",
		"网络中心战概念萌芽的年代",
		"生化武器库，魔鬼的实验",
		"太空武器化，制高点的争夺",
		# 更多扩展
		"柬埔寨红色高棉，共产主义的极端",
		"尼加拉瓜桑地诺，反美武装的火种",
		"阿富汗圣战者，山地中的抵抗",
		"波兰团结工会，的铁幕裂缝",
		"罗马尼亚革命，齐奥塞斯库的末日",
		"波罗的海三国，独立运动的浪潮",
		"车臣战争，帝国的消化不良",
		"南斯拉夫解体，血腥的民族冲突",
		"两伊战争，毒气与人体盾牌",
		"黎巴嫩内战，中东的火药桶",
		"以色列黎巴嫩，占领与抵抗",
		"南非种族隔离，种族的围墙",
		"纳米比亚独立，非洲的独立浪潮",
		"莫桑比克内战，葡萄牙帝国的终结",
		"安哥拉内战终章，冷战非洲的句号"
	]

	for i in range(1, 21):
		var level_num = 40 + i
		var faction_id = "aether_dynamics"
		# 冷战法则限制：以THUNDER+STEEL为起点逐步开放
		var families: Array = []
		if i <= 5:
			families = ["THUNDER", "STEEL"]
		elif i <= 14:
			families = ["THUNDER", "STEEL", "FLAME"]
		elif i <= 19:
			families = ["THUNDER", "STEEL", "FLAME", "VOID"]
		else:  # Boss关
			families = ["STEEL", "FLAME", "THUNDER", "VOID"]
		var desc = descriptions[i - 1]
		var short_name = desc.split("，")[0].split(" ")[0]
		_level_db[level_num] = {
			"display_name": "冷战·%s" % short_name,
			"description": descriptions[i - 1],
			"faction_id": faction_id,
			"environment": _get_environment_for_era_level(LevelEras.Era.COLD_WAR, i),
			"available_law_families": families,
			"difficulty_modifier": 1.15 + (i - 1) * 0.03,
		}

func _add_modern_levels() -> void:
	"""现代（61-80关）：量子后勤为主
	法则家族限制：
	- 量子后勤(quantum_logistics)主控 STEEL+FLAME
	- 早期（61-65）STEEL+FLAME，中期（66-74）加入 THUNDER+VOID
	- Boss关（80）全部开放"""
	var descriptions = [
		"海湾战争，精准制导的革命",
		"科威特收复，沙漠风暴来临",
		"巴尔干战争，欧洲的创伤",
		"科索沃空袭，网络战争的开端",
		"阿富汗反恐，新型战争",
		"伊拉克战争，大规模杀伤武器之谎",
		"中东乱局，恐怖主义与反恐",
		"格鲁吉亚冲突，大国博弈",
		"南海争端，21世纪的新战场",
		"叙利亚内战，国际介入的复杂",
		"恐怖活动，看不见的敌人",
		"网络战争，虚拟空间的较量",
		"无人机时代，天空中的死神",
		"精准打击，高科技战争",
		"联合作战，多国部队协同",
		"中东重塑，大国游戏的棋盘",
		"核武危机，威慑的平衡",
		"现代战争，终极的高科技对抗",
		"多线作战，全球化的冲突",
		"和平的曙光，战争的可能性",
		# 新增多样化描述
		"沙漠之狐行动，夜幕下的精确打击",
		"斩首行动，无人机的外科手术",
		"网络渗透，黑暗中的较量",
		"社交媒体战争，宣传的新战线",
		"金融战，经济制裁的武器化",
		"太空博弈，卫星战的雏形",
		"极地竞争，北极资源的争夺",
		"深海采矿，蓝色边疆的冲突",
		"网络勒索，黑客的勒索战争",
		"关键基础设施，能源系统的脆弱",
		"电磁脉冲威胁，现代社会的瘫痪",
		"量子计算威胁，加密体系动摇",
		"AI武器化，智能战争的黎明",
		"外骨骼单兵，未来战士的雏形",
		"高超音速导弹，防御的噩梦",
		"激光武器，光速的毁灭打击",
		"网络战司令部，数字战场的指挥",
		"第五代战机，制空权的革命",
		"网络情报战，棱镜门的余波",
		"混合战争，旧战术新包装",
		# 更多扩展
		"阿拉伯之春，社交媒体点燃的火焰",
		"乌克兰危机，欧洲新冷战的序幕",
		"克里米亚并入，领土变更的争议",
		"伊斯兰国的崛起，恐怖组织的扩张",
		"巴黎恐袭，欧洲反恐的转折",
		"伦敦恐袭，持刀与汽车袭击",
		"斯诺登事件，监控帝国的崩塌",
		"朝鲜网络攻击，勒索软件的威胁",
		"伊朗核协议，破局与重启",
		"以巴冲突，永不愈合的伤口",
		"罗兴亚危机，人道主义灾难",
		"罗卜冲突，军事政变的轮回",
		"埃塞俄比亚提格雷内战",
		"苏丹内战，两支军队的对抗",
		"也门代理人战争，沙特与伊朗的博弈"
	]

	for i in range(1, 21):
		var level_num = 60 + i
		var faction_id = "quantum_logistics"
		# 现代法则限制：STEEL+FLAME起步，快速开放全部
		var families: Array = []
		if i <= 5:
			families = ["STEEL", "FLAME"]
		elif i <= 14:
			families = ["STEEL", "FLAME", "THUNDER", "VOID"]
		else:  # Boss关及后期
			families = ["STEEL", "FLAME", "THUNDER", "VOID"]
		var desc = descriptions[i - 1]
		var short_name = desc.split("，")[0].split(" ")[0]
		_level_db[level_num] = {
			"display_name": "现代·%s" % short_name,
			"description": descriptions[i - 1],
			"faction_id": faction_id,
			"environment": _get_environment_for_era_level(LevelEras.Era.MODERN, i),
			"available_law_families": families,
			"difficulty_modifier": 1.25 + (i - 1) * 0.035,
		}

func _add_future_levels() -> void:
	"""近未来（81-100关）：虚空相位与螺旋侦察
	法则家族限制：
	- 螺旋侦察(helix_recon)主控 THUNDER+VOID
	- 虚空相位(void_research)主控 VOID
	- 早期（81-85）3个家族，中期（86-94）4个家族
	- 最终Boss关（100）全部开放，无限制"""
	var descriptions = [
		"人工智能觉醒，机器的反抗",
		"相位折叠，空间战争的开端",
		"量子纠缠战，微观层面的对决",
		"反重力坦克，重力的解放",
		"虚空之门，异界的入侵",
		"电磁脉冲风暴，技术的崩溃",
		"时空扭曲，时间的战争",
		"纳米虫群，微观世界的杀戮",
		"幽灵协议，谍报战的极限",
		"机械生命，生与非生的界限",
		"虚拟现实战争，两个世界的碰撞",
		"相位跳跃，维度的切割",
		"能量场对撞，物理法则的突破",
		"思想控制，精神层面的战争",
		"集群智能，群体的力量",
		"终极武器，构装纪元的巅峰",
		"多维战场，高维世界的战斗",
		"相位临界，构装纪元的终章",
		"永恒战争，循环的宿命",
		"新纪元黎明，超越一切的存在",
		# 新增多样化描述
		"全息投影战场，虚实难辨的迷雾",
		"意识上传，数字永生的悖论",
		"基因武器，定制化的生物威胁",
		"气候武器，地球本身的武器化",
		"太空电梯，能源咽喉的争夺",
		"小行星采矿，宇宙资源的竞赛",
		"月球基地，前进火星的跳板",
		"轨道打击武器，天基炮的威胁",
		"反物质炸弹，万物的终结者",
		"暗物质探测器，宇宙的阴影",
		"引力波通讯，无法拦截的信息",
		"等离子护盾，能量场的壁垒",
		"相变装甲，适应性防御系统",
		"自愈金属，机械的再生能力",
		"蜂群无人机，群体的智慧",
		"战术AI指挥官，算法将军的崛起",
		"神经链接武器，脑波控制的可能",
		"量子加密通信，绝对安全的幻象",
		"增强现实战场，叠加的死亡线",
		"元宇宙冲突，虚拟领土的战争",
		# 更多扩展
		"时间循环战士，重复的战斗",
		"平行宇宙干涉，多重现实的交汇",
		"相位战士，虚实两界的行者",
		"暗能量引擎，宇宙的推进力",
		"零点能提取，真空的能量矿藏",
		"拓扑量子计算机，极致的算力",
		"情感模拟AI，有意识的武器",
		"纳米医疗舱，战地即时救治",
		"模块化机甲，可变形的杀手",
		"磁轨炮阵列，电磁加速的毁灭",
		"太空港攻防，轨道工厂的争夺",
		"卫星网络战，天基系统的瘫痪",
		"等离子刀，近身的炽白切割",
		"冷冻休眠舱，极远距离投送",
		"相位干扰器，空间稳定性的崩溃",
		"引力透镜伪装，隐形的极致",
		"熵减场，局部时间倒流",
		"真空衰变武器，宇宙的终结按钮",
		"宇宙弦切割，不可阻挡的切割",
		"暗能量装甲，宇宙级护盾"
	]

	for i in range(1, 21):
		var level_num = 80 + i
		# 81-90关螺旋侦察，91-100关虚空相位
		var faction_id = "helix_recon" if i <= 10 else "void_research"
		# 近未来法则限制：大部分关卡开放全部家族
		var families: Array = []
		if i <= 5:
			families = ["THUNDER", "VOID", "FLAME"]
		elif i <= 10:
			families = ["THUNDER", "VOID", "FLAME", "STEEL"]
		elif i <= 15:
			families = ["VOID", "FLAME", "STEEL", "THUNDER"]
		else:
			families = ["STEEL", "FLAME", "THUNDER", "VOID"]
		var desc = descriptions[i - 1]
		var short_name = desc.split("，")[0].split(" ")[0]
		_level_db[level_num] = {
			"display_name": "近未来·%s" % short_name,
			"description": descriptions[i - 1],
			"faction_id": faction_id,
			"environment": _get_environment_for_era_level(LevelEras.Era.NEAR_FUTURE, i),
			"available_law_families": families,
			"difficulty_modifier": 1.4 + (i - 1) * 0.04,
		}

func _get_environment_for_era_level(era: int, level_in_era: int) -> Dictionary:
	"""根据时代和关卡内序号生成环境配置"""
	var env = {}

	# 天气循环：晴朗→雨天→风暴→晴朗
	var weather_cycle = ["clear", "rain", "storm", "fog"]
	env["weather"] = weather_cycle[(era * 5 + level_in_era) % weather_cycle.size()]

	# 地形循环
	var terrain_cycle = ["plain", "mountain", "city", "forest", "desert"]
	env["terrain"] = terrain_cycle[(era + level_in_era) % terrain_cycle.size()]

	# 能量场循环
	var energy_cycle = ["normal", "high_field", "void_rift", "nano_fog"]
	env["energy_field"] = energy_cycle[(era * 3 + level_in_era) % energy_cycle.size()]

	# 时间循环
	var time_cycle = ["dawn", "day", "dusk", "night"]
	env["time_of_day"] = time_cycle[(level_in_era) % time_cycle.size()]

	return env

func get_level_info(level: int) -> Dictionary:
	"""获取指定关卡的详细信息"""
	if level < 1 or level > LEVEL_COUNT:
		return {}
	return _level_db.get(level, {}).duplicate(true)

func get_level_display_name(level: int) -> String:
	"""获取关卡显示名称"""
	var info = get_level_info(level)
	return info.get("display_name", "第%d关" % level)

func get_level_description(level: int) -> String:
	"""获取关卡背景故事"""
	var info = get_level_info(level)
	return info.get("description", "")

func get_level_faction(level: int) -> String:
	"""获取控制该关卡的势力ID"""
	var info = get_level_info(level)
	return info.get("faction_id", "")

func get_level_environment(level: int) -> Dictionary:
	"""获取关卡环境配置"""
	var info = get_level_info(level)
	return info.get("environment", {}).duplicate(true)

func get_available_law_families_for_level(level: int) -> Array:
	"""获取该关卡允许的法则家族列表（空数组表示全部可用）"""
	var info = get_level_info(level)
	var families = info.get("available_law_families", [])
	return families if not families.is_empty() else []

func is_law_family_available_for_level(family: String, level: int) -> bool:
	"""检查某个法则家族在该关卡是否可用"""
	var allowed = get_available_law_families_for_level(level)
	if allowed.is_empty():
		return true  # 空限制 = 全部可用
	return allowed.has(family)

## 已弃用：请使用 get_available_law_families_for_level
func get_available_laws_for_level(level: int) -> Array:
	return get_available_law_families_for_level(level)

func get_difficulty_modifier(level: int) -> float:
	"""获取关卡难度倍数"""
	var info = get_level_info(level)
	return info.get("difficulty_modifier", 1.0)

func get_levels_for_faction(faction_id: String) -> Array:
	"""获取某个势力控制的所有关卡"""
	var result = []
	for level in range(1, LEVEL_COUNT + 1):
		if get_level_faction(level) == faction_id:
			result.append(level)
	return result

func get_all_level_infos() -> Array:
	"""获取所有关卡信息"""
	var result = []
	for level in range(1, LEVEL_COUNT + 1):
		result.append(get_level_info(level))
	return result
