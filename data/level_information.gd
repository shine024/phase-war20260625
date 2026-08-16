extends RefCounted
class_name LevelInformation
## 关卡详细信息：背景故事、势力控制、可用法则等
##
## 字段：
## - display_name: 关卡显示名称
## - description: 关卡背景故事简介
## - faction_id: 控制该关卡的势力ID
## - available_law_families: 该关卡允许的法则家族列表（空=全部可用）
##   家族: "STEEL"|"FLAME"|"THUNDER"|"VOID"
## - special_rules: v8 批次3 特殊规则（见 _apply_special_rules，仅部分关卡挂载）
##
## 2026-08-16 关卡设计审查（单源真理收敛）：
## - 环境单一真源 = data/battle_environments.gd（BattleEnvironments.get_for_level，
##   被 phase_law_manager / battle_damage_system 消费）。本表原程序循环生成的
##   environment 字段与战斗环境双源不同步（如第10关本表显示"风暴"、战斗实为"雨"），已删除。
## - 难度显示单一真源 = data/enemy_loadout_tiers.gd（时代内进度→档位系数 1.30/1.75/2.00，
##   即战斗链真实乘区）。本表原 difficulty_modifier（0.8+level×0.014 线性公式）
##   自 v8.2 起不在任何战斗乘区链中，沦为纯展示误导，已删除。
##
## 法则限制设计理念：
## - 每关至少允许1个家族（玩家总有选择）
## - Boss关卡（20/40/60/80/100）允许全部4个家族
## - 与关卡所属势力的主家族关系密切
## - 早期关卡限制较严格（1-2个），后期逐渐放宽（2-3个）
## - 特殊关卡有特殊限制（如城市关卡禁虚空等）

const PhaseMasterGarrison = preload("res://data/phase_master_garrison.gd")

# 关卡总数：100关 × 5时代
const LEVEL_COUNT = 100

# 关卡信息数据库
var _level_db: Dictionary = {}

# v7.x 性能：全局共享单例。_init() 会重建全部 100 关字典（657 行构造代码），
# 战斗中 _check_win_lose 每帧都会读关卡规则，反复 new() 是进战卡 + 战斗掉帧的主因。
# 数据为构造期一次性写入、运行期纯只读查询，故用单例复用安全。
static var _shared: LevelInformation = null

## 返回全局共享单例（首次构造后复用，避免反复重建 100 关字典）。
static func get_shared() -> LevelInformation:
	if _shared == null:
		_shared = LevelInformation.new()
	return _shared

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

	# v8 批次3: 关卡特殊机制（限定兵种/能量惩罚/特殊胜利/部署上限）
	# 集中挂载，不侵入 100 关字典定义。字段全可选，缺省=普通关（向后兼容）。
	_apply_special_rules()

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
	]

	for i in range(1, 21):
		var level_num = i
		# v6.9: 前20关（一战教学时代）为无主之地，无势力占领/势力加成/势力相位师
		# 21关起启用势力占领机制（见 faction_conquest_buffs.gd + enemy_stat_resolver.gd）
		var faction_id = ""
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
			"available_law_families": families,
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
			"available_law_families": families,
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
			"available_law_families": families,
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
			"available_law_families": families,
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
			"available_law_families": families,
		}

func get_level_info(level: int) -> Dictionary:
	"""获取指定关卡的详细信息"""
	if level < 1 or level > LEVEL_COUNT:
		return {}
	return _level_db.get(level, {}).duplicate(true)

## v8 批次3: 获取关卡特殊规则。缺省空字典=普通关（向后兼容）。
## 结构示例：
##   {
##     "restrict_platforms": [0,1],   # 限定可部署 platform_type 白名单（空/缺省=不限）
##     "energy_mult": 0.5,             # 能量上限/开局乘率（1.0=正常）
##     "energy_regen_mult": 0.5,       # 能量回复乘率（1.0=正常）
##   }
## win_type=survive_waves 机制保留（battle_manager/_format_special_rules 通用路径），
## 但【只能挂在非驻守相位师关】——见 _set_rules 守卫说明。
func get_special_rules(level: int) -> Dictionary:
	if level < 1 or level > LEVEL_COUNT:
		return {}
	var info = _level_db.get(level, {})
	return info.get("special_rules", {})

## v8 批次3: 集中挂载关卡特殊规则。
## 给关键关（每时代 Boss 关 + 时代首关 + 中段关卡）挂规则。
## 字段全可选；未挂规则的关卡 get_special_rules 返回空字典=普通关。
## 2026-08-16 关卡设计审查修复：
## - 移除 20/40/60/80/100 的 survive_waves——这 5 关全是驻守相位师关（100% 遭遇，
##   见 phase_master_garrison.gd），战斗胜负由基地销毁驱动（battle_manager._check_win_lose
##   对 _is_phase_master_battle 提前 return），survive_waves 永远不会被评估，
##   属"死规则 + UI 误导读"（world_map 会显示"胜利条件: 坚守N波"但实际必须拆基地）。
## - 第85关 restrict_platforms [3,7]→[2]：7 不在 CombatKind(0-4)，3=AIR 非 SUPPORT，
##   原值实际效果="仅空军可部署"，与"阵地防御战·限支援/工兵"意图完全相反。
##   工兵卡（如 ww1_sup_engineer）combat_kind=2=SUPPORT，修正为 [2] 即覆盖支援+工兵。
func _apply_special_rules() -> void:
	# 注：deploy_limit（关卡部署上限）已移除——可上场单位数现由相位仪实际装备的战斗卡数决定。
	# ─── 一战时代（1-20）───
	# 第5关：能量受限（教学"能量管理"，回复减半）
	_set_rules(5, {"energy_regen_mult": 0.5})
	# 第15关：限定步兵（巷战，重装备无法展开）—— platform_type 0=CombatKind.LIGHT
	_set_rules(15, {"restrict_platforms": [0]})

	# ─── 二战时代（21-40）───
	# 第25关：能量减半（资源匮乏战场）
	_set_rules(25, {"energy_mult": 0.5})
	# 第30关：限定装甲（装甲突击战）—— platform_type 1=CombatKind.ARMOR
	_set_rules(30, {"restrict_platforms": [1]})

	# ─── 冷战时代（41-60）───
	# 第50关：回复减半
	_set_rules(50, {"energy_regen_mult": 0.5})
	# 第55关：限定支援/空军（机动战）—— 2=SUPPORT, 3=AIR（CombatKind）
	_set_rules(55, {"restrict_platforms": [2, 3]})

	# ─── 现代时代（61-80）───
	# 第65关：能量减半 + 回复减半（双压）
	_set_rules(65, {"energy_mult": 0.5, "energy_regen_mult": 0.5})
	# 第80关 Boss：能量减半（胜负=摧毁驻守相位师基地）
	_set_rules(80, {"energy_mult": 0.5})

	# ─── 近未来时代（81-100）───
	# 第85关：限定支援/工兵（阵地防御战）—— 工兵卡 combat_kind=2=SUPPORT
	_set_rules(85, {"restrict_platforms": [2]})
	# 第90关：能量减半
	_set_rules(90, {"energy_mult": 0.5})
	# 第100关 终局：能量减半（胜负=摧毁奥米伽基地）
	_set_rules(100, {"energy_mult": 0.5})


## v8 批次3: 给指定关卡挂 special_rules（内部辅助，合并到已有字典）。
## 2026-08-16 守卫：win_type 类特殊胜利依赖 battle_manager._check_win_lose 的普通关路径；
## 驻守相位师关（PhaseMasterGarrison）胜负由基地销毁信号驱动、提前 return，
## 挂上去就是死规则 + UI 误导读，故拒绝挂载。
func _set_rules(level: int, rules: Dictionary) -> void:
	if not _level_db.has(level):
		return
	if rules.has("win_type") and PhaseMasterGarrison.is_garrison_level(level):
		push_warning("[LevelInformation] 关卡 %d 是驻守相位师关（胜负=摧毁基地），不支持 win_type 特殊胜利，已拒绝挂载。" % level)
		return
	var entry: Dictionary = _level_db[level]
	entry["special_rules"] = rules
	_level_db[level] = entry

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
