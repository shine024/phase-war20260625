extends RefCounted
class_name IntelRevealEvents
## v6.0: 情报揭示事件定义
## 每当某维情报达到阈值时触发的揭示事件
##
## key格式: "{enemy_type}_{dimension}_{tier}"  (tier: 0-3 对应 25%/50%/75%/100%)
## 每个事件包含标题、描述、奖励列表

const IntelDimensions = preload("res://data/intel_dimensions.gd")

# ── 揭示事件表 ────────────────────────────────────────────────────
# rewards type说明：
#   "stat_visibility"     — 属性可见性等级提升
#   "weakness_bonus"      — 对该敌人类型弱点伤害加成 (bonus_damage: float)
#   "drop_rate_bonus"      — 掉落率加成 (bonus_pct: float)
#   "eom_unlock_hint"      — 敌源MOD解锁提示
#   "eom_unlock"           — 直接解锁敌源MOD (mod_id: String)
#   "intel_branch_hint"    — 进化分支线索文字
#   "intel_branch_unlock"  — 直接解锁进化分支 (branch_id: String)
#   "lore_page"            — 解锁世界观页面

const REVEAL_EVENTS: Dictionary = {

	# ═══════════════════════════════════════════════
	#  步兵系 (infantry)
	# ═══════════════════════════════════════════════
	"infantry_basic_0": {
		"title": "侦察报告·步兵识别",
		"desc": "首次交火后，我方情报部门成功识别了敌方步兵单位的编制类型和所属时代。",
		"rewards": [{"type": "stat_visibility", "value": "name_and_type"}],
		"icon": "📋",
	},
	"infantry_basic_1": {
		"title": "侦察报告·步兵全参数",
		"desc": "通过持续侦察，已获取敌方步兵的完整属性数据：生命值、攻击力、射程、移动速度等关键参数已录入数据库。",
		"rewards": [{"type": "stat_visibility", "value": "full_stats"}],
		"icon": "📊",
	},
	"infantry_basic_2": {
		"title": "侦察报告·隐藏数据",
		"desc": "深入分析发现了步兵单位的隐藏属性：弹药容量、装填间隙、掩体利用效率等非公开参数。",
		"rewards": [{"type": "stat_visibility", "value": "hidden_stats"}, {"type": "drop_rate_bonus", "bonus_pct": 0.10}],
		"icon": "🔬",
	},
	"infantry_basic_3": {
		"title": "图鉴百科·步兵篇",
		"desc": "步兵单位情报收集完毕，已编入军事百科全书。今后对该类型单位的掉落率提升50%。",
		"rewards": [{"type": "drop_rate_bonus", "bonus_pct": 0.50}],
		"icon": "📖",
	},

	"infantry_tactical_0": {
		"title": "战术分析·行为模式",
		"desc": "初步观察到敌方步兵的战斗行为：以群体推进为主，在射程内会优先攻击轻装甲单位。",
		"rewards": [{"type": "stat_visibility", "value": "behavior_summary"}],
		"icon": "🎯",
	},
	"infantry_tactical_1": {
		"title": "战术分析·技能解析",
		"desc": "完整的技能列表已解析：包括手榴弹投掷、战壕挖掘、掩护射击等编队战术能力。",
		"rewards": [{"type": "stat_visibility", "value": "skill_list"}],
		"icon": "⚔️",
	},
	"infantry_tactical_2": {
		"title": "战术分析·弱点发现",
		"desc": "关键弱点已确认！步兵在换弹和机动转移时存在明显的防御间隙（约1.5秒），利用此窗口可造成额外25%伤害。",
		"rewards": [{"type": "weakness_bonus", "target_type": "infantry", "bonus_damage": 0.25}],
		"icon": "💥",
	},
	"infantry_tactical_3": {
		"title": "战术全解·步兵AI逻辑",
		"desc": "已完全掌握敌方步兵的AI决策树：优先级排序、战术阵型切换逻辑、撤退阈值等全部公开。战斗中对步兵单位伤害再+10%。",
		"rewards": [{"type": "weakness_bonus", "target_type": "infantry", "bonus_damage": 0.10}],
		"icon": "🧠",
	},

	"infantry_material_0": {
		"title": "素材研究·装备识别",
		"desc": "已确认步兵单位携带的装备类型和材质等级，可针对性地准备反制装备。",
		"rewards": [{"type": "stat_visibility", "value": "equipment_type"}],
		"icon": "🔧",
	},
	"infantry_material_1": {
		"title": "素材研究·专属掉落",
		"desc": "已查明步兵单位可掉落的所有专属材料：改良弹药、防弹片、战术手册等蓝图碎片掉落率提升。",
		"rewards": [{"type": "drop_rate_bonus", "bonus_pct": 0.15}],
		"icon": "📦",
	},
	"infantry_material_2": {
		"title": "素材研究·敌源改造解锁",
		"desc": "从步兵装备残骸中提炼出关键改装技术！解锁敌源改造【步兵战术套件】，可安装在轻装和支援单位的D槽。",
		"rewards": [{"type": "eom_unlock", "mod_id": "EOM_INFANTRY_01"}],
		"icon": "🧬",
	},
	"infantry_material_3": {
		"title": "素材研究·进化材料",
		"desc": "步兵的高级装备材料已完全掌握。可用于特种进化路线的材料条件已满足。",
		"rewards": [{"type": "intel_branch_hint", "text": "步兵素材似乎可以与隐匿技术结合……"}],
		"icon": "💎",
	},

	"infantry_secret_0": {
		"title": "机密档案·神秘代码",
		"desc": "在缴获的步兵通讯设备中发现了加密信息片段：'……第七计划……代号影刃……'这与什么有关？",
		"rewards": [{"type": "lore_page", "page_id": "cipher_fragment_01"}],
		"icon": "🔐",
	},
	"infantry_secret_1": {
		"title": "机密档案·进化线索",
		"desc": "破译情报表明：某些步兵单位经过特殊训练后可进化为隐匿特种兵，这条路线不在标准进化图谱中……",
		"rewards": [{"type": "intel_branch_hint", "text": "特种作战路线可能存在——需要更多隐匿单位的情报。"}],
		"icon": "🗺️",
	},
	"infantry_secret_2": {
		"title": "机密档案·秘密配方",
		"desc": "获得了一份步兵特种改造的秘密配方！配方中提到了将光学迷彩与步兵护甲结合的方案……",
		"rewards": [{"type": "lore_page", "page_id": "secret_recipe_stealth_infantry"}],
		"icon": "📜",
	},
	"infantry_secret_3": {
		"title": "机密档案·全解析",
		"desc": "步兵相关的所有机密档案已完全破译！解锁隐藏进化分支【特种作战路线】，可通过情报进化管理器查看。",
		"rewards": [{"type": "intel_branch_unlock", "branch_id": "IB_INFANTRY_SPECIAL"}],
		"icon": "🏆",
	},

	# ═══════════════════════════════════════════════
	#  火焰兵系 (flame)
	# ═══════════════════════════════════════════════
	"flame_basic_0": {
		"title": "侦察报告·火焰兵识别",
		"desc": "确认了火焰喷射兵的存在。注意：该单位对轻装甲有极高威胁。",
		"rewards": [{"type": "stat_visibility", "value": "name_and_type"}],
		"icon": "📋",
	},
	"flame_basic_1": {
		"title": "侦察报告·火焰兵全参数",
		"desc": "火焰兵完整参数已录入：极高近战伤害、中低射程、低HP。",
		"rewards": [{"type": "stat_visibility", "value": "full_stats"}],
		"icon": "📊",
	},
	"flame_basic_2": {
		"title": "侦察报告·火焰兵隐藏数据",
		"desc": "发现火焰兵的燃料消耗速率和过热冷却时间，这些信息可用于制定反制策略。",
		"rewards": [{"type": "stat_visibility", "value": "hidden_stats"}, {"type": "drop_rate_bonus", "bonus_pct": 0.10}],
		"icon": "🔬",
	},
	"flame_basic_3": {
		"title": "图鉴百科·火焰兵篇",
		"desc": "火焰兵情报收集完毕。掉落率+50%。",
		"rewards": [{"type": "drop_rate_bonus", "bonus_pct": 0.50}],
		"icon": "📖",
	},

	"flame_tactical_0": {
		"title": "战术分析·火焰兵行为",
		"desc": "火焰兵倾向于逼近至近距离再开火，移动速度中等偏快。",
		"rewards": [{"type": "stat_visibility", "value": "behavior_summary"}],
		"icon": "🎯",
	},
	"flame_tactical_1": {
		"title": "战术分析·火焰技能",
		"desc": "火焰兵具备：持续灼烧(DoT)、范围火焰喷射、燃料爆炸(死亡时)等技能。",
		"rewards": [{"type": "stat_visibility", "value": "skill_list"}],
		"icon": "⚔️",
	},
	"flame_tactical_2": {
		"title": "战术分析·火焰弱点",
		"desc": "火焰兵的燃料罐是致命弱点！对火焰兵的穿甲/爆炸伤害+30%。",
		"rewards": [{"type": "weakness_bonus", "target_type": "flame", "bonus_damage": 0.30}],
		"icon": "💥",
	},
	"flame_tactical_3": {
		"title": "战术全解·火焰AI",
		"desc": "完全掌握火焰兵AI逻辑。额外+10%伤害。",
		"rewards": [{"type": "weakness_bonus", "target_type": "flame", "bonus_damage": 0.10}],
		"icon": "🧠",
	},

	"flame_material_0": {
		"title": "素材研究·燃料识别",
		"desc": "已确认火焰兵使用的燃料类型——凝胶燃料，遇水不可扑灭。",
		"rewards": [{"type": "stat_visibility", "value": "equipment_type"}],
		"icon": "🔧",
	},
	"flame_material_1": {
		"title": "素材研究·火焰掉落",
		"desc": "火焰兵可掉落凝胶燃料样本、耐热合金片、火焰武器部件等。",
		"rewards": [{"type": "drop_rate_bonus", "bonus_pct": 0.15}],
		"icon": "📦",
	},
	"flame_material_2": {
		"title": "素材研究·热能改造解锁",
		"desc": "从火焰兵装备中提炼出了热防护技术！解锁敌源改造【热能抗性装甲】。",
		"rewards": [{"type": "eom_unlock", "mod_id": "EOM_FLAME_01"}],
		"icon": "🧬",
	},
	"flame_material_3": {
		"title": "素材研究·火焰进化材料",
		"desc": "火焰系高级材料已完全掌握。可用于装甲进化路线的特殊条件。",
		"rewards": [{"type": "intel_branch_hint", "text": "热能技术与纳米装甲似乎有融合可能……"}],
		"icon": "💎",
	},

	"flame_secret_0": {
		"title": "机密档案·代号燃烬",
		"desc": "截获通讯：'……燃烬计划启动……纳米核心注入成功……'",
		"rewards": [{"type": "lore_page", "page_id": "cipher_fragment_02"}],
		"icon": "🔐",
	},
	"flame_secret_1": {
		"title": "机密档案·纳米火焰线索",
		"desc": "火焰技术正被与纳米技术融合——这可能通往一条特殊的装甲进化路线。",
		"rewards": [{"type": "intel_branch_hint", "text": "需要纳米核心BOSS的素材情报来验证这条路线。"}],
		"icon": "🗺️",
	},
	"flame_secret_2": {
		"title": "机密档案·纳米火焰配方",
		"desc": "获得纳米火焰合金的秘密配方！这种材料可以将装甲的耐火性提升到极端水平。",
		"rewards": [{"type": "lore_page", "page_id": "secret_recipe_nano_flame"}],
		"icon": "📜",
	},
	"flame_secret_3": {
		"title": "机密档案·火焰全解",
		"desc": "火焰相关机密全部破译！解锁隐藏进化分支【自适应装甲路线】的部分条件。",
		"rewards": [{"type": "intel_branch_unlock", "branch_id": "IB_ADAPTIVE_ARMOR"}],
		"icon": "🏆",
	},

	# ═══════════════════════════════════════════════
	#  重装甲系 (heavy_armor)
	# ═══════════════════════════════════════════════
	"heavy_armor_basic_0": {
		"title": "侦察报告·重装甲识别",
		"desc": "确认敌方重装甲单位的存在。该单位具备极高的防御力和生命值。",
		"rewards": [{"type": "stat_visibility", "value": "name_and_type"}],
		"icon": "📋",
	},
	"heavy_armor_basic_1": {
		"title": "侦察报告·重装甲全参数",
		"desc": "重装甲完整参数已获取：超高HP、高护甲、中等伤害、低机动性。",
		"rewards": [{"type": "stat_visibility", "value": "full_stats"}],
		"icon": "📊",
	},
	"heavy_armor_basic_2": {
		"title": "侦察报告·重装甲隐藏数据",
		"desc": "发现了重装甲的装甲厚度分布和弱点区域的精确位置。",
		"rewards": [{"type": "stat_visibility", "value": "hidden_stats"}, {"type": "drop_rate_bonus", "bonus_pct": 0.10}],
		"icon": "🔬",
	},
	"heavy_armor_basic_3": {
		"title": "图鉴百科·重装甲篇",
		"desc": "重装甲情报收集完毕。掉落率+50%。",
		"rewards": [{"type": "drop_rate_bonus", "bonus_pct": 0.50}],
		"icon": "📖",
	},

	"heavy_armor_tactical_0": {
		"title": "战术分析·重装甲行为",
		"desc": "重装甲以缓慢但稳定的速度推进，优先攻击最近的单位。",
		"rewards": [{"type": "stat_visibility", "value": "behavior_summary"}],
		"icon": "🎯",
	},
	"heavy_armor_tactical_1": {
		"title": "战术分析·重装甲技能",
		"desc": "重装甲具备：主炮轰击、碾压冲锋、紧急维修等技能。",
		"rewards": [{"type": "stat_visibility", "value": "skill_list"}],
		"icon": "⚔️",
	},
	"heavy_armor_tactical_2": {
		"title": "战术分析·重装甲弱点",
		"desc": "重装甲的侧面和后方装甲显著薄弱！从侧后方攻击可造成额外30%伤害。",
		"rewards": [{"type": "weakness_bonus", "target_type": "heavy_armor", "bonus_damage": 0.30}],
		"icon": "💥",
	},
	"heavy_armor_tactical_3": {
		"title": "战术全解·重装甲AI",
		"desc": "完全掌握重装甲AI。额外+10%伤害。",
		"rewards": [{"type": "weakness_bonus", "target_type": "heavy_armor", "bonus_damage": 0.10}],
		"icon": "🧠",
	},

	"heavy_armor_material_0": {
		"title": "素材研究·装甲材质",
		"desc": "确认重装甲使用复合装甲材质，包含反应装甲层。",
		"rewards": [{"type": "stat_visibility", "value": "equipment_type"}],
		"icon": "🔧",
	},
	"heavy_armor_material_1": {
		"title": "素材研究·重装甲掉落",
		"desc": "重装甲可掉落：复合装甲板、反应装甲模块、重型履带部件等。",
		"rewards": [{"type": "drop_rate_bonus", "bonus_pct": 0.15}],
		"icon": "📦",
	},
	"heavy_armor_material_2": {
		"title": "素材研究·反应装甲解锁",
		"desc": "从重装甲残骸中成功提取反应装甲技术！解锁敌源改造【反应装甲模块】。",
		"rewards": [{"type": "eom_unlock", "mod_id": "EOM_ARMOR_01"}],
		"icon": "🧬",
	},
	"heavy_armor_material_3": {
		"title": "素材研究·装甲进化材料",
		"desc": "重装甲系高级材料完全掌握。可用于破甲猎手进化路线。",
		"rewards": [{"type": "intel_branch_hint", "text": "反坦克技术与装甲弱点知识可以融合……"}],
		"icon": "💎",
	},

	"heavy_armor_secret_0": {
		"title": "机密档案·代号铁壁",
		"desc": "截获通讯：'……铁壁协议……全领域防御系统……不可渗透……'",
		"rewards": [{"type": "lore_page", "page_id": "cipher_fragment_03"}],
		"icon": "🔐",
	},
	"heavy_armor_secret_1": {
		"title": "机密档案·破甲线索",
		"desc": "情报显示：结合重装甲弱点分析和反坦克技术，可以开辟一条特殊的进化路线。",
		"rewards": [{"type": "intel_branch_hint", "text": "破甲猎手路线需要更多重装甲的战术情报。"}],
		"icon": "🗺️",
	},
	"heavy_armor_secret_2": {
		"title": "机密档案·穿甲配方",
		"desc": "获得了超穿甲弹头的秘密配方，可将对重装甲的伤害提升到极端水平。",
		"rewards": [{"type": "lore_page", "page_id": "secret_recipe_ap_rounds"}],
		"icon": "📜",
	},
	"heavy_armor_secret_3": {
		"title": "机密档案·重装甲全解",
		"desc": "重装甲相关机密全部破译！解锁隐藏进化分支【破甲猎手路线】。",
		"rewards": [{"type": "intel_branch_unlock", "branch_id": "IB_ARMOR_BREAKER"}],
		"icon": "🏆",
	},

	# ═══════════════════════════════════════════════
	#  火炮系 (artillery)
	# ═══════════════════════════════════════════════
	"artillery_basic_0": {
		"title": "侦察报告·火炮识别",
		"desc": "确认敌方火炮单位存在。射程极远，可覆盖全图。",
		"rewards": [{"type": "stat_visibility", "value": "name_and_type"}],
		"icon": "📋",
	},
	"artillery_basic_1": {
		"title": "侦察报告·火炮全参数",
		"desc": "火炮完整参数已录入：超高射程、高爆发伤害、极低HP、低机动。",
		"rewards": [{"type": "stat_visibility", "value": "full_stats"}],
		"icon": "📊",
	},
	"artillery_basic_2": {
		"title": "侦察报告·火炮隐藏数据",
		"desc": "发现火炮的最小射程盲区和装填周期，近战单位可利用此间隙。",
		"rewards": [{"type": "stat_visibility", "value": "hidden_stats"}, {"type": "drop_rate_bonus", "bonus_pct": 0.10}],
		"icon": "🔬",
	},
	"artillery_basic_3": {
		"title": "图鉴百科·火炮篇",
		"desc": "火炮情报收集完毕。掉落率+50%。",
		"rewards": [{"type": "drop_rate_bonus", "bonus_pct": 0.50}],
		"icon": "📖",
	},

	"artillery_tactical_0": {
		"title": "战术分析·火炮行为",
		"desc": "火炮倾向于停留在后方，优先攻击我方高价值目标（装甲单位）。",
		"rewards": [{"type": "stat_visibility", "value": "behavior_summary"}],
		"icon": "🎯",
	},
	"artillery_tactical_1": {
		"title": "战术分析·火炮技能",
		"desc": "火炮具备：曲射炮击、烟雾弹遮蔽、集束炸弹等技能。",
		"rewards": [{"type": "stat_visibility", "value": "skill_list"}],
		"icon": "⚔️",
	},
	"artillery_tactical_2": {
		"title": "战术分析·火炮弱点",
		"desc": "火炮在开火后的装填窗口（约3秒）防御降至最低！此时攻击+30%伤害。",
		"rewards": [{"type": "weakness_bonus", "target_type": "artillery", "bonus_damage": 0.30}],
		"icon": "💥",
	},
	"artillery_tactical_3": {
		"title": "战术全解·火炮AI",
		"desc": "完全掌握火炮AI逻辑。额外+10%伤害。",
		"rewards": [{"type": "weakness_bonus", "target_type": "artillery", "bonus_damage": 0.10}],
		"icon": "🧠",
	},

	"artillery_material_0": {
		"title": "素材研究·炮弹识别",
		"desc": "确认火炮使用的弹药类型——高爆弹和穿甲弹交替使用。",
		"rewards": [{"type": "stat_visibility", "value": "equipment_type"}],
		"icon": "🔧",
	},
	"artillery_material_1": {
		"title": "素材研究·火炮掉落",
		"desc": "火炮可掉落：炮管部件、弹道计算仪、高爆弹药样本等。",
		"rewards": [{"type": "drop_rate_bonus", "bonus_pct": 0.15}],
		"icon": "📦",
	},
	"artillery_material_2": {
		"title": "素材研究·弹道校准解锁",
		"desc": "从火炮瞄准系统中提取了弹道校准数据！解锁敌源改造【弹道校准系统】。",
		"rewards": [{"type": "eom_unlock", "mod_id": "EOM_ARTILLERY_01"}],
		"icon": "🧬",
	},
	"artillery_material_3": {
		"title": "素材研究·火炮进化材料",
		"desc": "火炮系高级材料完全掌握。空中炮艇进化路线的部分条件已满足。",
		"rewards": [{"type": "intel_branch_hint", "text": "如果将火炮装载到飞行平台……"}],
		"icon": "💎",
	},

	"artillery_secret_0": {
		"title": "机密档案·代号天罚",
		"desc": "截获通讯：'……天罚系统……空中炮艇计划……跨域打击……'",
		"rewards": [{"type": "lore_page", "page_id": "cipher_fragment_04"}],
		"icon": "🔐",
	},
	"artillery_secret_1": {
		"title": "机密档案·空中炮艇线索",
		"desc": "情报显示敌方正在研发空中炮艇——将火炮装载到飞行平台上的跨类型武器。",
		"rewards": [{"type": "intel_branch_hint", "text": "空中炮艇路线需要更多空中单位和火炮的秘密情报。"}],
		"icon": "🗺️",
	},
	"artillery_secret_2": {
		"title": "机密档案·空中装载配方",
		"desc": "获得空中炮艇装载系统的秘密配方——如何在飞行器上稳定发射重型火炮。",
		"rewards": [{"type": "lore_page", "page_id": "secret_recipe_air_gunship"}],
		"icon": "📜",
	},
	"artillery_secret_3": {
		"title": "机密档案·火炮全解",
		"desc": "火炮相关机密全部破译！解锁隐藏进化分支【空中炮艇路线】的部分条件。",
		"rewards": [{"type": "intel_branch_hint", "text": "还需要空中单位和隐匿单位的情报来完全解锁。"}],
		"icon": "🏆",
	},

	# ═══════════════════════════════════════════════
	#  隐匿系 (stealth)
	# ═══════════════════════════════════════════════
	"stealth_basic_0": {
		"title": "侦察报告·隐匿单位识别",
		"desc": "确认存在隐匿型敌方单位——极难被发现，但在暴露时有短暂的脆弱期。",
		"rewards": [{"type": "stat_visibility", "value": "name_and_type"}],
		"icon": "📋",
	},
	"stealth_basic_1": {
		"title": "侦察报告·隐匿全参数",
		"desc": "隐匿单位参数：中低HP、中高伤害、高闪避、短时间隐身能力。",
		"rewards": [{"type": "stat_visibility", "value": "full_stats"}],
		"icon": "📊",
	},
	"stealth_basic_2": {
		"title": "侦察报告·隐匿隐藏数据",
		"desc": "发现隐匿单位的冷却间隙——每次隐身结束后的3秒内无法再次激活。",
		"rewards": [{"type": "stat_visibility", "value": "hidden_stats"}, {"type": "drop_rate_bonus", "bonus_pct": 0.10}],
		"icon": "🔬",
	},
	"stealth_basic_3": {
		"title": "图鉴百科·隐匿篇",
		"desc": "隐匿单位情报收集完毕。掉落率+50%。",
		"rewards": [{"type": "drop_rate_bonus", "bonus_pct": 0.50}],
		"icon": "📖",
	},

	"stealth_tactical_0": {
		"title": "战术分析·隐匿行为",
		"desc": "隐匿单位倾向于先侦察再突袭，优先攻击我方孤立单位。",
		"rewards": [{"type": "stat_visibility", "value": "behavior_summary"}],
		"icon": "🎯",
	},
	"stealth_tactical_1": {
		"title": "战术分析·隐匿技能",
		"desc": "隐匿单位具备：光学迷彩、瞬移突击、后背刺杀等技能。",
		"rewards": [{"type": "stat_visibility", "value": "skill_list"}],
		"icon": "⚔️",
	},
	"stealth_tactical_2": {
		"title": "战术分析·隐匿弱点",
		"desc": "隐匿单位在攻击瞬间会解除隐身！在攻击判定后的0.5秒内造成+30%伤害。",
		"rewards": [{"type": "weakness_bonus", "target_type": "stealth", "bonus_damage": 0.30}],
		"icon": "💥",
	},
	"stealth_tactical_3": {
		"title": "战术全解·隐匿AI",
		"desc": "完全掌握隐匿AI逻辑。额外+10%伤害。",
		"rewards": [{"type": "weakness_bonus", "target_type": "stealth", "bonus_damage": 0.10}],
		"icon": "🧠",
	},

	"stealth_material_0": {
		"title": "素材研究·光学材料",
		"desc": "确认隐匿单位使用光学迷彩涂层——可在特定波段下被探测。",
		"rewards": [{"type": "stat_visibility", "value": "equipment_type"}],
		"icon": "🔧",
	},
	"stealth_material_1": {
		"title": "素材研究·隐匿掉落",
		"desc": "隐匿单位可掉落：光学涂层样本、隐蔽行动手册、暗杀工具等。",
		"rewards": [{"type": "drop_rate_bonus", "bonus_pct": 0.15}],
		"icon": "📦",
	},
	"stealth_material_2": {
		"title": "素材研究·迷彩涂层解锁",
		"desc": "从隐匿单位残骸中提取光学迷彩技术！解锁敌源改造【光学迷彩涂层】。",
		"rewards": [{"type": "eom_unlock", "mod_id": "EOM_STEALTH_01"}],
		"icon": "🧬",
	},
	"stealth_material_3": {
		"title": "素材研究·隐匿进化材料",
		"desc": "隐匿系高级材料完全掌握。特种作战路线的条件更近一步。",
		"rewards": [{"type": "intel_branch_hint", "text": "光学迷彩技术与步兵战术的结合已经可行了。"}],
		"icon": "💎",
	},

	"stealth_secret_0": {
		"title": "机密档案·代号影刃",
		"desc": "截获通讯：'……影刃特种部队……从无败绩……终极隐匿计划……'",
		"rewards": [{"type": "lore_page", "page_id": "cipher_fragment_05"}],
		"icon": "🔐",
	},
	"stealth_secret_1": {
		"title": "机密档案·特种线索",
		"desc": "隐匿技术与步兵战术的结合——这是一条被刻意隐藏的进化路线。",
		"rewards": [{"type": "intel_branch_hint", "text": "特种作战路线需要步兵精英的秘密情报来完全解锁。"}],
		"icon": "🗺️",
	},
	"stealth_secret_2": {
		"title": "机密档案·影刃配方",
		"desc": "获得影刃特种兵的完整改装配方——终极隐匿步兵的技术蓝本。",
		"rewards": [{"type": "lore_page", "page_id": "secret_recipe_shadow_blade"}],
		"icon": "📜",
	},
	"stealth_secret_3": {
		"title": "机密档案·隐匿全解",
		"desc": "隐匿相关机密全部破译！空中炮艇路线的隐匿条件已满足。",
		"rewards": [{"type": "intel_branch_hint", "text": "空中炮艇路线的隐匿战术条件已满足！"}],
		"icon": "🏆",
	},

	# ═══════════════════════════════════════════════
	#  纳米BOSS系 (boss_nano)
	# ═══════════════════════════════════════════════
	"boss_nano_basic_0": {
		"title": "侦察报告·纳米核心识别",
		"desc": "确认纳米核心BOSS的存在——一种前所未见的纳米技术构造体。",
		"rewards": [{"type": "stat_visibility", "value": "name_and_type"}],
		"icon": "📋",
	},
	"boss_nano_basic_1": {
		"title": "侦察报告·纳米核心全参数",
		"desc": "纳米核心参数：极高HP、极高自修复能力、多种攻击模式。",
		"rewards": [{"type": "stat_visibility", "value": "full_stats"}],
		"icon": "📊",
	},
	"boss_nano_basic_2": {
		"title": "侦察报告·纳米核心隐藏数据",
		"desc": "发现纳米核心的弱化周期——每60秒会有5秒的纳米再生中断窗口。",
		"rewards": [{"type": "stat_visibility", "value": "hidden_stats"}, {"type": "drop_rate_bonus", "bonus_pct": 0.10}],
		"icon": "🔬",
	},
	"boss_nano_basic_3": {
		"title": "图鉴百科·纳米核心篇",
		"desc": "纳米核心情报收集完毕。掉落率+50%。",
		"rewards": [{"type": "drop_rate_bonus", "bonus_pct": 0.50}],
		"icon": "📖",
	},

	"boss_nano_tactical_0": {
		"title": "战术分析·纳米行为",
		"desc": "纳米核心以自适应AI运作——会根据我方阵容动态调整攻击策略。",
		"rewards": [{"type": "stat_visibility", "value": "behavior_summary"}],
		"icon": "🎯",
	},
	"boss_nano_tactical_1": {
		"title": "战术分析·纳米技能",
		"desc": "纳米核心具备：纳米脉冲波、自修复场、纳米吞噬、相位转换等技能。",
		"rewards": [{"type": "stat_visibility", "value": "skill_list"}],
		"icon": "⚔️",
	},
	"boss_nano_tactical_2": {
		"title": "战术分析·纳米弱点",
		"desc": "纳米核心在自修复时会暂时降低防御！修复期间造成+30%额外伤害。",
		"rewards": [{"type": "weakness_bonus", "target_type": "boss_nano", "bonus_damage": 0.30}],
		"icon": "💥",
	},
	"boss_nano_tactical_3": {
		"title": "战术全解·纳米AI",
		"desc": "完全掌握纳米核心AI逻辑。额外+10%伤害。",
		"rewards": [{"type": "weakness_bonus", "target_type": "boss_nano", "bonus_damage": 0.10}],
		"icon": "🧠",
	},

	"boss_nano_material_0": {
		"title": "素材研究·纳米材质",
		"desc": "确认纳米核心由自组装纳米材料构成——这种材料理论上可以被复制。",
		"rewards": [{"type": "stat_visibility", "value": "equipment_type"}],
		"icon": "🔧",
	},
	"boss_nano_material_1": {
		"title": "素材研究·纳米掉落",
		"desc": "纳米核心可掉落：纳米粒子样本、自修复模块、相位碎片等稀有材料。",
		"rewards": [{"type": "drop_rate_bonus", "bonus_pct": 0.20}],
		"icon": "📦",
	},
	"boss_nano_material_2": {
		"title": "素材研究·纳米再生解锁",
		"desc": "从纳米核心中提取了自修复技术！解锁敌源改造【纳米再生核心】。",
		"rewards": [{"type": "eom_unlock", "mod_id": "EOM_BOSS_NANO"}],
		"icon": "🧬",
	},
	"boss_nano_material_3": {
		"title": "素材研究·纳米进化材料",
		"desc": "纳米系高级材料完全掌握。自适应装甲进化路线的纳米条件已满足！",
		"rewards": [{"type": "intel_branch_hint", "text": "纳米再生技术与装甲融合——自适应装甲路线已可行！"}],
		"icon": "💎",
	},

	"boss_nano_secret_0": {
		"title": "机密档案·代号创世纪",
		"desc": "截获通讯：'……创世纪计划……纳米与人类融合……终极进化……'",
		"rewards": [{"type": "lore_page", "page_id": "cipher_fragment_06"}],
		"icon": "🔐",
	},
	"boss_nano_secret_1": {
		"title": "机密档案·终极进化线索",
		"desc": "纳米核心的存在暗示了一种超越常规进化的可能性——人类与纳米的终极融合。",
		"rewards": [{"type": "intel_branch_hint", "text": "终极进化路线可能需要所有BOSS的秘密情报。"}],
		"icon": "🗺️",
	},
	"boss_nano_secret_2": {
		"title": "机密档案·创世纪配方",
		"desc": "获得创世纪计划的秘密配方——将纳米核心植入战斗单位的完整方案。",
		"rewards": [{"type": "lore_page", "page_id": "secret_recipe_genesis"}],
		"icon": "📜",
	},
	"boss_nano_secret_3": {
		"title": "机密档案·纳米全解",
		"desc": "纳米核心相关机密全部破译！自适应装甲路线的纳米条件已满足。",
		"rewards": [{"type": "intel_branch_hint", "text": "纳米机密完全掌握——与火焰技术结合即可开启自适应装甲！"}],
		"icon": "🏆",
	},

	# ═══════════════════════════════════════════════
	#  空中系 (air)
	# ═══════════════════════════════════════════════
	"air_basic_0": {
		"title": "侦察报告·空中单位识别",
		"desc": "确认敌方空中单位存在——高速移动，可从全图发动攻击。",
		"rewards": [{"type": "stat_visibility", "value": "name_and_type"}],
		"icon": "📋",
	},
	"air_basic_1": {
		"title": "侦察报告·空中全参数",
		"desc": "空中单位完整参数：中HP、中高伤害、超高机动、全图射程。",
		"rewards": [{"type": "stat_visibility", "value": "full_stats"}],
		"icon": "📊",
	},
	"air_basic_2": {
		"title": "侦察报告·空中隐藏数据",
		"desc": "发现空中单位在俯冲攻击后有固定的爬升恢复期。",
		"rewards": [{"type": "stat_visibility", "value": "hidden_stats"}, {"type": "drop_rate_bonus", "bonus_pct": 0.10}],
		"icon": "🔬",
	},
	"air_basic_3": {
		"title": "图鉴百科·空中篇",
		"desc": "空中单位情报收集完毕。掉落率+50%。",
		"rewards": [{"type": "drop_rate_bonus", "bonus_pct": 0.50}],
		"icon": "📖",
	},

	"air_tactical_0": {
		"title": "战术分析·空中行为",
		"desc": "空中单位在飞行中持续攻击，优先打击我方防空能力最弱的单位。",
		"rewards": [{"type": "stat_visibility", "value": "behavior_summary"}],
		"icon": "🎯",
	},
	"air_tactical_1": {
		"title": "战术分析·空中技能",
		"desc": "空中单位具备：俯冲轰炸、空对地导弹、电子干扰等技能。",
		"rewards": [{"type": "stat_visibility", "value": "skill_list"}],
		"icon": "⚔️",
	},
	"air_tactical_2": {
		"title": "战术分析·空中弱点",
		"desc": "空中单位在爬升恢复期防御显著降低！此时防空攻击+30%伤害。",
		"rewards": [{"type": "weakness_bonus", "target_type": "air", "bonus_damage": 0.30}],
		"icon": "💥",
	},
	"air_tactical_3": {
		"title": "战术全解·空中AI",
		"desc": "完全掌握空中AI逻辑。额外+10%伤害。",
		"rewards": [{"type": "weakness_bonus", "target_type": "air", "bonus_damage": 0.10}],
		"icon": "🧠",
	},

	"air_material_0": {
		"title": "素材研究·航空材料",
		"desc": "确认空中单位使用轻量化航空合金和先进航电系统。",
		"rewards": [{"type": "stat_visibility", "value": "equipment_type"}],
		"icon": "🔧",
	},
	"air_material_1": {
		"title": "素材研究·空中掉落",
		"desc": "空中单位可掉落：航空合金、航电模块、喷气引擎部件等。",
		"rewards": [{"type": "drop_rate_bonus", "bonus_pct": 0.15}],
		"icon": "📦",
	},
	"air_material_2": {
		"title": "素材研究·航电系统",
		"desc": "从空中单位残骸中提取了先进航电技术！解锁敌源改造【精确打击模块】。",
		"rewards": [{"type": "eom_unlock", "mod_id": "EOM_AIR_01"}],
		"icon": "🧬",
	},
	"air_material_3": {
		"title": "素材研究·空中进化材料",
		"desc": "空中系高级材料完全掌握。空中炮艇进化路线的航空条件已满足。",
		"rewards": [{"type": "intel_branch_hint", "text": "航空技术与火炮装载结合——空中炮艇越来越近了。"}],
		"icon": "💎",
	},

	"air_secret_0": {
		"title": "机密档案·代号天罚",
		"desc": "截获通讯：'……天罚计划需要空中平台……火炮整合……跨域打击能力……'",
		"rewards": [{"type": "lore_page", "page_id": "cipher_fragment_07"}],
		"icon": "🔐",
	},
	"air_secret_1": {
		"title": "机密档案·空中炮艇线索",
		"desc": "敌方正在研发空中炮艇——将重型火炮装载到飞行平台上的疯狂计划。",
		"rewards": [{"type": "intel_branch_hint", "text": "空中炮艇路线还需要更多火炮和隐匿的秘密情报。"}],
		"icon": "🗺️",
	},
	"air_secret_2": {
		"title": "机密档案·空中火力配方",
		"desc": "获得空中火力装载系统的秘密配方——如何在飞行中稳定发射重型火炮。",
		"rewards": [{"type": "lore_page", "page_id": "secret_recipe_aerial_firepower"}],
		"icon": "📜",
	},
	"air_secret_3": {
		"title": "机密档案·空中全解",
		"desc": "空中相关机密全部破译！空中炮艇路线的航空条件已满足。",
		"rewards": [{"type": "intel_branch_hint", "text": "空中炮艇路线已接近完成！"}],
		"icon": "🏆",
	},
}

# ── 工具函数 ───────────────────────────────────────────────────────

## 构建揭示事件key
static func make_event_key(enemy_type: String, dimension: String, tier: int) -> String:
	return "%s_%s_%d" % [enemy_type, dimension, tier]

## 获取揭示事件
static func get_event(enemy_type: String, dimension: String, tier: int) -> Dictionary:
	var key: String = make_event_key(enemy_type, dimension, tier)
	return REVEAL_EVENTS.get(key, {})

## 检查揭示事件是否存在
static func has_event(enemy_type: String, dimension: String, tier: int) -> bool:
	var key: String = make_event_key(enemy_type, dimension, tier)
	return REVEAL_EVENTS.has(key)

## 获取某敌人类型所有已定义的揭示事件
static func get_all_events_for_type(enemy_type: String) -> Dictionary:
	var result: Dictionary = {}
	var prefix: String = enemy_type + "_"
	for key in REVEAL_EVENTS:
		if key.begins_with(prefix):
			result[key] = REVEAL_EVENTS[key]
	return result

## 获取所有已定义的敌人类型
static func get_defined_enemy_types() -> Array[String]:
	var types: Array[String] = []
	for key in REVEAL_EVENTS:
		var parts: PackedStringArray = key.split("_")
		if parts.size() >= 3:
			var etype: String = parts[0]
			if not types.has(etype):
				types.append(etype)
	return types
