extends RefCounted
class_name PhaseMasterSkillTreeV8Extension
## ═══════════════════════════════════════════════════════════
##  相位师技能树扩展（深层节点 tier 5-15）
##
##  本文件独立于 phase_master_skill_tree.gd 主文件（基础层 tier 0-4）。
##  PhaseMasterSkillTree 通过 get_skills_for_branch() 合并本扩展：
##    主表 SKILL_TREE[branch] + V8Extension.get_extension_nodes(branch)
##
##  v9 重设计：概念武器分支解散，原 12 个深层 cw 节点按主题归位三系：
##    指挥（守护/时空系）：cw_2 形态进化 / cw_4 护盾投射 / cw_11 时间回溯 / cw_10 维度叠加
##    智能化（控制/电子系）：cw_5 无人机协同 / cw_8 时间迟缓 / cw_7a 天罚雷阵 / cw_13b 太阳耀斑
##    火力（大杀伤系）：cw_3 能量过载 / cw_1 战术核武 / cw_6 焚城 / cw_12a 焦土政策 /
##                     cw_7b 湮灭之光 / cw_12b 烈焰风暴 / cw_9 现实崩溃 / cw_13a 火焰传导
##  节点 ID 全部保留（pms_cw_ 前缀不改），旧存档零迁移。
##  奇点节点带 "capstone": true，统一以「奇点解算」（pms_cw_0，主表智能化 tier 3）
##  为门关：要求三系 tier2 全点亮；个别强节点另有跨系前置。
##
##  v9.x 修复与调价（2026-08-25）：
##    - 深层节点全面降价：cost 5→3 / 4→2 / 3→2 / 2→1（总 cost 212→147，
##      满 Lv30 的 70 点从覆盖 33% 提升到 48%；旧档读档按新表重算已花点数自动退款）
##    - 补挂 3 个无解锁途径的死内容：cps_steel_storm 钢铁风暴（指挥 t14 钢铁壁垒链）、
##      tactic_draw_deep 诱敌深入（智能 t7）、tactic_scorched_line 焦土防线（火力 t7）
##    - 改名 pms_cmd_5「闪电穿插」→「装甲穿插」：与 pms_cmd_11（战法「闪电穿插」）重名，
##      同分支面板出现两个同名节点易混淆
##
##  解锁类型（unlocks[].type）：
##    card_skill      → 卡片定时技能解锁（CardPeriodicSkillEngine 查询）
##    tactic          → 战法解锁（TacticDetector 查询）
##    unit_mechanism  → 兵种机制技能解锁（blitz_pierce/sniper_aim/demolition/jamming_field/drone_mark 等）
##
##  效果字段（effects）：
##    stat_bonus      → 累加到 get_active_effects()
##    conditional     → 条件型 Buff
##    aura            → 光环
## ═══════════════════════════════════════════════════════════

const BRANCH_COMMAND := "command"
const BRANCH_INTELLIGENCE := "intelligence"
const BRANCH_FIREPOWER := "firepower"

## 3 分支扩展节点（tier 5-15），每节点结构与 phase_master_skill_tree.gd 完全一致
const EXTENSION_NODES: Dictionary = {
	# ═══════════ 指挥分支扩展（14+4 节点）：渗透战术 / 工兵 / 战法 + 奇点（进化/护盾/时空） ═══════════
	BRANCH_COMMAND: [
		# tier 5：装甲穿插（v8.5：原 stalker_stealth 空转——兵种机制靠卡牌tags驱动与技能树无关；改为机制技能：装甲单位穿透攻击后排）
		# v9.x：原节点名「闪电穿插」与 pms_cmd_11（战法闪电穿插）重名，改名区分
		{"id": "pms_cmd_5", "name": "装甲穿插", "desc": "解锁机制：装甲单位每10秒下次攻击变为穿透弹（越过前排直击后排2个单位）",
		 "branch": BRANCH_COMMAND, "tier": 5, "cost": 1, "requires": ["pms_cmd_4"],
		 "unlocks": [{"type": "unit_mechanism", "id": "blitz_pierce"}],
		 "effects": {}},
		# tier 5 并列：形态进化（v9 归位自概念武器分支；军团养成归指挥系）
		{"id": "pms_cw_2", "name": "形态进化", "desc": "解锁卡牌进化能力（一战时代）",
		 "branch": BRANCH_COMMAND, "tier": 5, "cost": 1, "requires": ["pms_cmd_4"],
		 "unlocks": [{"type": "evolution", "era": 0}],
		 "effects": {}},
		# tier 6：坚壁清野（v8.5：原 engineer_build 空转——维修/布雷/净化均未实装；改数值加成）
		{"id": "pms_cmd_6", "name": "坚壁清野", "desc": "所有单位三维防御 +10%，暴击抗性 +10%",
		 "branch": BRANCH_COMMAND, "tier": 6, "cost": 1, "requires": ["pms_cmd_5"],
		 "unlocks": [], "effects": {"stat_bonus": {"def_light": 0.10, "def_armor": 0.10, "def_air": 0.10, "crit_resist": 0.10}}},
		# tier 7a：钳形攻势（战法）
		{"id": "pms_cmd_7a", "name": "钳形攻势", "desc": "解锁战法「钳形攻势」：≥2 ARMOR + ≥1 FAST 时 ARMOR 对最高威胁+25% 伤害",
		 "branch": BRANCH_COMMAND, "tier": 7, "cost": 2, "requires": ["pms_cmd_6"],
		 "unlocks": [{"type": "tactic", "id": "tactic_pincer"}],
		 "effects": {}},
		# tier 7b：刺猬防御（战法）
		{"id": "pms_cmd_7b", "name": "刺猬防御", "desc": "解锁战法「刺猬防御」：≥3 FORT + ≥1 ENGINEER 时全体 -25% 受伤",
		 "branch": BRANCH_COMMAND, "tier": 7, "cost": 2, "requires": ["pms_cmd_6"],
		 "unlocks": [{"type": "tactic", "id": "tactic_hedgehog"}],
		 "effects": {}},
		# tier 8：军团方阵
		{"id": "pms_cmd_8", "name": "军团方阵", "desc": "解锁战法「堡垒防线」：≥4 FORT 时全体 -35% 受伤；FORT +15% HP",
		 "branch": BRANCH_COMMAND, "tier": 8, "cost": 2, "requires": ["pms_cmd_7a"],
		 "unlocks": [{"type": "tactic", "id": "tactic_fortress_line"}],
		 "effects": {"stat_bonus": {"max_hp_fort": 0.15}}},
		# tier 8b：相位场壁垒（v8.6：单位+基地双效升级——与 pms_cmd_4b 叠加，单位与基地血量大幅成长）
		{"id": "pms_cmd_8b", "name": "相位场壁垒", "desc": "所有单位与相位场基地生命值 +30%（与「相位场强化」叠加）",
		 "branch": BRANCH_COMMAND, "tier": 8, "cost": 2, "requires": ["pms_cmd_8"],
		 "unlocks": [], "effects": {"stat_bonus": {"hp": 0.30}}},
		# tier 9a：围点打援
		{"id": "pms_cmd_9a", "name": "围点打援", "desc": "解锁战法「围点打援」：FORT 受伤 -20%，ARMOR 对新进入敌方+50%",
		 "branch": BRANCH_COMMAND, "tier": 9, "cost": 2, "requires": ["pms_cmd_8"],
		 "unlocks": [{"type": "tactic", "id": "tactic_siege_intercept"}],
		 "effects": {}},
		# tier 9b：纵深作战（v8.5：删无效 unit_limit，战法保留 + 三维攻击加成）
		{"id": "pms_cmd_9b", "name": "纵深作战", "desc": "解锁战法「纵深作战」：≥3 不同兵种时全体 +10% 全属性；所有单位三维攻击 +12%",
		 "branch": BRANCH_COMMAND, "tier": 9, "cost": 2, "requires": ["pms_cmd_8"],
		 "unlocks": [{"type": "tactic", "id": "tactic_depth_operation"}],
		 "effects": {"stat_bonus": {"atk_light": 0.12, "atk_armor": 0.12, "atk_air": 0.12}}},
		# tier 10：战术大师（强化所有战法）
		{"id": "pms_cmd_10", "name": "战术大师", "desc": "全部已解锁战法效果 +20%；全体三维防御+10%",
		 "branch": BRANCH_COMMAND, "tier": 10, "cost": 2, "requires": ["pms_cmd_9a", "pms_cmd_9b"],
		 "unlocks": [],
		 "effects": {"stat_bonus": {"tactic_effect_mult": 0.20, "def_light": 0.10, "def_armor": 0.10, "def_air": 0.10}}},
		# tier 10 并列：护盾投射（v9 奇点归位指挥系——守护系奇点链链首；需奇点解算门关）
		{"id": "pms_cw_4", "name": "护盾投射", "desc": "◈奇点 解锁机制：护盾发射器堡垒每20秒为半径250内生命最低的3个友军投射护盾；解锁所有时代进化",
		 "branch": BRANCH_COMMAND, "tier": 10, "cost": 2, "requires": ["pms_cmd_9a", "pms_cw_0"],
		 "unlocks": [{"type": "unit_mechanism", "id": "shield_projector"},
		              {"type": "evolution", "era": -1}],
		 "effects": {}, "capstone": true},
		# tier 11：闪电穿插（高级战法）
		{"id": "pms_cmd_11", "name": "闪电穿插", "desc": "解锁高级战法「闪电穿插」：≥3 FAST 时 FAST 攻速+40%、伤害+30%",
		 "branch": BRANCH_COMMAND, "tier": 11, "cost": 2, "requires": ["pms_cmd_10"],
		 "unlocks": [{"type": "tactic", "id": "tactic_blitz"}],
		 "effects": {}},
		# tier 11 并列：时间回溯（v9 奇点归位指挥系——时空系，接护盾投射链）
		{"id": "pms_cw_11", "name": "时间回溯", "desc": "◈奇点 解锁卡片技能「全体回血」：每 90s 全体恢复 30% HP+清除 debuff",
		 "branch": BRANCH_COMMAND, "tier": 11, "cost": 3, "requires": ["pms_cw_4"],
		 "unlocks": [{"type": "card_skill", "id": "cps_time_rewind"}],
		 "effects": {}, "capstone": true},
		# tier 12：天罗地网（高级战法）
		{"id": "pms_cmd_12", "name": "天罗地网", "desc": "解锁高级战法「天罗地网」：STEEL+THUNDER 时全体敌方攻速-30%、移速-30%",
		 "branch": BRANCH_COMMAND, "tier": 12, "cost": 3, "requires": ["pms_cmd_11"],
		 "unlocks": [{"type": "tactic", "id": "tactic_sky_net"}],
		 "effects": {}},
		# tier 12 并列：维度叠加（v9 奇点归位指挥系——时空系，指挥奇点链终点）
		{"id": "pms_cw_10", "name": "维度叠加", "desc": "◈奇点 解锁卡片技能「全体虚化」：每 150s 全体闪避+40%、受伤-30%（12s）",
		 "branch": BRANCH_COMMAND, "tier": 12, "cost": 2, "requires": ["pms_cw_11"],
		 "unlocks": [{"type": "card_skill", "id": "cps_dimension_overlay"}],
		 "effects": {}, "capstone": true},
		# tier 13a：钢铁壁垒（卡片技能——堡垒周期护盾，原幽灵技能补挂）
		{"id": "pms_cmd_13a", "name": "钢铁壁垒", "desc": "解锁卡片技能「堡垒护盾」：每 20s 全体堡垒+2000护盾、-10%受伤（10s）",
		 "branch": BRANCH_COMMAND, "tier": 13, "cost": 3, "requires": ["pms_cmd_12"],
		 "unlocks": [{"type": "card_skill", "id": "cps_steel_bulwark"}],
		 "effects": {}},
		# tier 13b：反坦克雷区（卡片技能——工兵周期布雷，原幽灵技能补挂）
		{"id": "pms_cmd_13b", "name": "反坦克雷区", "desc": "解锁卡片技能「工兵布雷」：每 18s 敌方密集区布雷（对装甲+50%，8s）",
		 "branch": BRANCH_COMMAND, "tier": 13, "cost": 3, "requires": ["pms_cmd_12"],
		 "unlocks": [{"type": "card_skill", "id": "cps_minefield"}],
		 "effects": {}},
		# tier 14：钢铁风暴（v9.x 补挂——全局终极技此前无解锁途径，死内容；
		# 接钢铁壁垒 steel 家族链：护盾壁垒 → 全军风暴）
		{"id": "pms_cmd_14", "name": "钢铁风暴", "desc": "解锁终极卡片技能「钢铁风暴」：每 90s 全体友军 +3000 护盾（10s）、受伤 -20%",
		 "branch": BRANCH_COMMAND, "tier": 14, "cost": 3, "requires": ["pms_cmd_13a"],
		 "unlocks": [{"type": "card_skill", "id": "cps_steel_storm"}],
		 "effects": {}},
	],

	# ═══════════ 火力分支扩展（12+8 节点）：狙击手 / 火炮协调 / 战法 + 奇点（核武/大杀伤/火焰） ═══════════
	BRANCH_FIREPOWER: [
		# tier 5：狙击大师（v8.5：原 sniper_training 空转——兵种机制靠卡牌tags驱动与技能树无关；改为机制技能：狙击单位定时瞄准必暴）
		{"id": "pms_fp_5", "name": "狙击大师", "desc": "解锁机制：狙击单位每15秒进入瞄准状态（瞄准动画），下次攻击必暴击且伤害+50%（对Boss×2）",
		 "branch": BRANCH_FIREPOWER, "tier": 5, "cost": 1, "requires": ["pms_fp_4"],
		 "unlocks": [{"type": "unit_mechanism", "id": "sniper_aim"}],
		 "effects": {}},
		# tier 6：火炮协调（卡片技能）
		{"id": "pms_fp_6", "name": "火炮协调", "desc": "解锁卡片技能「炮兵协调射击」：每 15s 对敌方密集区炮击",
		 "branch": BRANCH_FIREPOWER, "tier": 6, "cost": 1, "requires": ["pms_fp_5"],
		 "unlocks": [{"type": "card_skill", "id": "cps_artillery_coord"}],
		 "effects": {}},
		# tier 7a：交叉火力（战法）
		{"id": "pms_fp_7a", "name": "交叉火力", "desc": "解锁战法「交叉火力」：≥3 SNIPER 时 SNIPER 射程+30%、伤害+25%、必命中",
		 "branch": BRANCH_FIREPOWER, "tier": 7, "cost": 2, "requires": ["pms_fp_6"],
		 "unlocks": [{"type": "tactic", "id": "tactic_crossfire"}],
		 "effects": {}},
		# tier 7b：饱和打击（战法）
		{"id": "pms_fp_7b", "name": "饱和打击", "desc": "解锁战法「饱和打击」：≥2 ARTILLERY + ≥1 ECM 时火炮伤害+50%、射程+20%",
		 "branch": BRANCH_FIREPOWER, "tier": 7, "cost": 2, "requires": ["pms_fp_6"],
		 "unlocks": [{"type": "tactic", "id": "tactic_saturation"}],
		 "effects": {}},
		# tier 7c：能量过载（v9 归位自概念武器分支，纯数值不设门关）
		{"id": "pms_cw_3", "name": "能量过载", "desc": "所有单位三维攻击 +12%，暴击伤害 +25%",
		 "branch": BRANCH_FIREPOWER, "tier": 7, "cost": 2, "requires": ["pms_fp_6"],
		 "unlocks": [], "effects": {"stat_bonus": {"atk_light": 0.12, "atk_armor": 0.12, "atk_air": 0.12, "crit_damage_bonus": 0.25}}},
		# tier 7d：焦土防线（v9.x 补挂——基础战法此前无解锁途径，死内容；火焰系主题归火力）
		{"id": "pms_fp_7d", "name": "焦土防线", "desc": "解锁战法「焦土防线」：≥2 火焰卡片技能 + ≥1 堡垒时全体免疫燃烧、火焰伤害 +30%",
		 "branch": BRANCH_FIREPOWER, "tier": 7, "cost": 2, "requires": ["pms_fp_6"],
		 "unlocks": [{"type": "tactic", "id": "tactic_scorched_line"}],
		 "effects": {}},
		# tier 8：斩首行动（战法）
		{"id": "pms_fp_8", "name": "斩首行动", "desc": "解锁战法「斩首行动」：SNIPER+STALKER+VOID 时对 Boss/相位师伤害×2",
		 "branch": BRANCH_FIREPOWER, "tier": 8, "cost": 2, "requires": ["pms_fp_7a"],
		 "unlocks": [{"type": "tactic", "id": "tactic_decapitation"}],
		 "effects": {}},
		# tier 9a：电磁轨道炮（卡片技能）
		{"id": "pms_fp_9a", "name": "电磁轨道炮", "desc": "解锁卡片技能「电磁轨道炮」：每 30s 对最高 HP 敌方 350% 穿甲伤害",
		 "branch": BRANCH_FIREPOWER, "tier": 9, "cost": 2, "requires": ["pms_fp_8"],
		 "unlocks": [{"type": "card_skill", "id": "cps_railgun"}],
		 "effects": {}},
		# tier 9b：超视距打击（卡片技能）
		{"id": "pms_fp_9b", "name": "超视距打击", "desc": "解锁卡片技能「超视距标记」：每 18s 标记最高威胁敌方",
		 "branch": BRANCH_FIREPOWER, "tier": 9, "cost": 2, "requires": ["pms_fp_8"],
		 "unlocks": [{"type": "card_skill", "id": "cps_bvr_mark"}],
		 "effects": {}},
		# tier 9c：化学武器（v8.6 机制解锁——支援/火炮单位自带化学弹头）
		{"id": "pms_fp_9c", "name": "化学武器", "desc": "解锁机制：支援/火炮单位攻击25%概率施加化学毒剂（每秒6伤害，持续5秒）",
		 "branch": BRANCH_FIREPOWER, "tier": 9, "cost": 2, "requires": ["pms_fp_8"],
		 "unlocks": [{"type": "unit_mechanism", "id": "chemical_weapon"}],
		 "effects": {}},
		# tier 10：火力精通
		{"id": "pms_fp_10", "name": "火力精通", "desc": "全体三维攻击+10%；SNIPER 伤害+25%",
		 "branch": BRANCH_FIREPOWER, "tier": 10, "cost": 2, "requires": ["pms_fp_9a", "pms_fp_9b"],
		 "unlocks": [],
		 "effects": {"stat_bonus": {"atk_light": 0.10, "atk_armor": 0.10, "atk_air": 0.10, "sniper_damage_bonus": 0.25}}},
		# tier 11：纵火反击（高级战法）
		{"id": "pms_fp_11", "name": "纵火反击", "desc": "解锁高级战法「纵火反击」：FLAME 时全体 HP+20%，死亡 20% 复活",
		 "branch": BRANCH_FIREPOWER, "tier": 11, "cost": 2, "requires": ["pms_fp_10"],
		 "unlocks": [{"type": "tactic", "id": "tactic_inferno_counter"}],
		 "effects": {}},
		# tier 11 并列：战术核武（v9 奇点归位火力系——大杀伤奇点链链首；需火力精通+奇点解算门关）
		{"id": "pms_cw_1", "name": "战术核武", "desc": "◈奇点 解锁机制：导弹发射井堡垒每45秒发射战术核弹，弹道飞行后对敌方密集区半径200内造成35%最大生命（保底200）的范围伤害",
		 "branch": BRANCH_FIREPOWER, "tier": 11, "cost": 2, "requires": ["pms_fp_10", "pms_cw_0"],
		 "unlocks": [{"type": "unit_mechanism", "id": "nuclear_strike"}],
		 "effects": {}, "capstone": true},
		# tier 12：四维打击（高级战法）
		{"id": "pms_fp_12", "name": "四维打击", "desc": "解锁高级战法「四维打击」：4 家族技能时全体 +25% 全属性",
		 "branch": BRANCH_FIREPOWER, "tier": 12, "cost": 3, "requires": ["pms_fp_11"],
		 "unlocks": [{"type": "tactic", "id": "tactic_4d_strike"}],
		 "effects": {}},
		# tier 12 并列：焚城（v9 奇点归位火力系，接战术核武链）
		{"id": "pms_cw_6", "name": "焚城", "desc": "◈奇点 解锁卡片技能「全图火焰轰炸」：每 60s 全图 250 火伤+燃烧",
		 "branch": BRANCH_FIREPOWER, "tier": 12, "cost": 2, "requires": ["pms_cw_1"],
		 "unlocks": [{"type": "card_skill", "id": "cps_burn_city"}],
		 "effects": {}, "capstone": true},
		# tier 13a：焦土政策（v9 奇点归位火力系）
		{"id": "pms_cw_12a", "name": "焦土政策", "desc": "◈奇点 解锁卡片技能「区域燃烧」：每 16s 敌方密集区燃烧 8s",
		 "branch": BRANCH_FIREPOWER, "tier": 13, "cost": 3, "requires": ["pms_cw_6"],
		 "unlocks": [{"type": "card_skill", "id": "cps_scorched_earth"}],
		 "effects": {}, "capstone": true},
		# tier 13b：湮灭之光（v9 奇点归位火力系；额外跨系前置智能「AI 指挥」——锁定系统支撑全图打击）
		{"id": "pms_cw_7b", "name": "湮灭之光", "desc": "◈奇点 解锁卡片技能「全图虚空伤害」：3s 蓄力后全图 300% ATK，HP<30% 斩杀",
		 "branch": BRANCH_FIREPOWER, "tier": 13, "cost": 2, "requires": ["pms_cw_6", "pms_int_10"],
		 "unlocks": [{"type": "card_skill", "id": "cps_annihilate"}],
		 "effects": {}, "capstone": true},
		# tier 14a：烈焰风暴（v9 奇点归位火力系，接焦土政策链）
		{"id": "pms_cw_12b", "name": "烈焰风暴", "desc": "◈奇点 解锁卡片技能「全图燃烧」：每 80s 全图燃烧+恐慌",
		 "branch": BRANCH_FIREPOWER, "tier": 14, "cost": 3, "requires": ["pms_cw_12a"],
		 "unlocks": [{"type": "card_skill", "id": "cps_firestorm"}],
		 "effects": {}, "capstone": true},
		# tier 14b：现实崩溃（v9 奇点归位火力系，接湮灭之光链——大杀伤奇点终点）
		{"id": "pms_cw_9", "name": "现实崩溃", "desc": "◈奇点 解锁卡片技能「斩杀低 HP」：每 60s HP<15% 敌方直接斩杀",
		 "branch": BRANCH_FIREPOWER, "tier": 14, "cost": 2, "requires": ["pms_cw_7b"],
		 "unlocks": [{"type": "card_skill", "id": "cps_reality_collapse"}],
		 "effects": {}, "capstone": true},
		# tier 15：火焰传导（v9 奇点归位火力系——火焰链终点）
		{"id": "pms_cw_13a", "name": "火焰传导", "desc": "◈奇点 解锁卡片技能「燃烧传染」：每 18s 燃烧传染 5 个邻近敌方（4s）",
		 "branch": BRANCH_FIREPOWER, "tier": 15, "cost": 3, "requires": ["pms_cw_12b"],
		 "unlocks": [{"type": "card_skill", "id": "cps_combustion"}],
		 "effects": {}, "capstone": true},
	],

	# ═══════════ 智能化分支扩展（12+4 节点）：电子战 / 卡片技能 / 战法 + 奇点（控制/时空/雷系） ═══════════
	BRANCH_INTELLIGENCE: [
		# tier 5：侦察特战（v8.5：原 ecm_aura 空转——兵种机制靠卡牌tags驱动与技能树无关；改为机制技能：侦察单位定向爆破）
		{"id": "pms_int_5", "name": "侦察特战", "desc": "解锁机制：侦察单位每12秒原地发射曲射爆破弹打最近敌方堡垒/装甲，造成8%最大生命的真实伤害",
		 "branch": BRANCH_INTELLIGENCE, "tier": 5, "cost": 1, "requires": ["pms_int_4"],
		 "unlocks": [{"type": "unit_mechanism", "id": "demolition"}],
		 "effects": {}},
		# tier 6：EMP 战术（卡片技能）
		{"id": "pms_int_6", "name": "EMP 战术", "desc": "解锁卡片技能「EMP 打击」：每 12s 对最高威胁敌方攻速-60%",
		 "branch": BRANCH_INTELLIGENCE, "tier": 6, "cost": 1, "requires": ["pms_int_5"],
		 "unlocks": [{"type": "card_skill", "id": "cps_emp_strike"}],
		 "effects": {}},
		# tier 7a：声东击西（战法）
		{"id": "pms_int_7a", "name": "声东击西", "desc": "解锁战法「声东击西」：ECM+2 FAST 时 FAST 暴击+25%，ECM 受伤-25%",
		 "branch": BRANCH_INTELLIGENCE, "tier": 7, "cost": 2, "requires": ["pms_int_6"],
		 "unlocks": [{"type": "tactic", "id": "tactic_feint"}],
		 "effects": {}},
		# tier 7b：两翼包抄（战法）
		{"id": "pms_int_7b", "name": "两翼包抄", "desc": "解锁战法「两翼包抄」：2 FAST 两侧分布时 FAST 伤害+30%，中央防御+30%",
		 "branch": BRANCH_INTELLIGENCE, "tier": 7, "cost": 2, "requires": ["pms_int_6"],
		 "unlocks": [{"type": "tactic", "id": "tactic_flank_pincer"}],
		 "effects": {}},
		# tier 7c：诱敌深入（v9.x 补挂——基础战法此前无解锁途径，死内容；FAST+后排主题归智能系）
		{"id": "pms_int_7c", "name": "诱敌深入", "desc": "解锁战法「诱敌深入」：≥1 快攻（前排）+ ≥3 后排时快攻受伤 -30%、后排攻击 +25%",
		 "branch": BRANCH_INTELLIGENCE, "tier": 7, "cost": 2, "requires": ["pms_int_6"],
		 "unlocks": [{"type": "tactic", "id": "tactic_draw_deep"}],
		 "effects": {}},
		# tier 8：电子屏蔽（v8.5：原 cps_adaptive_shield 卡片技能换为机制技能：防空/电子战单位区域屏蔽）
		{"id": "pms_int_8", "name": "电子屏蔽", "desc": "解锁机制：防空/电子战单位每18秒释放屏蔽波（半径300），范围内敌方攻击失效3秒",
		 "branch": BRANCH_INTELLIGENCE, "tier": 8, "cost": 2, "requires": ["pms_int_7a"],
		 "unlocks": [{"type": "unit_mechanism", "id": "jamming_field"}],
		 "effects": {}},
		# tier 9a：智能维修（卡片技能）
		{"id": "pms_int_9a", "name": "智能维修", "desc": "解锁卡片技能「定时维修」：每 10s 全体机械+3% HP",
		 "branch": BRANCH_INTELLIGENCE, "tier": 9, "cost": 2, "requires": ["pms_int_8"],
		 "unlocks": [{"type": "card_skill", "id": "cps_repair_aura"}],
		 "effects": {}},
		# tier 9b：智能净化（卡片技能）
		{"id": "pms_int_9b", "name": "智能净化", "desc": "解锁卡片技能「定时净化」：每 18s 清除全体 debuff",
		 "branch": BRANCH_INTELLIGENCE, "tier": 9, "cost": 2, "requires": ["pms_int_8"],
		 "unlocks": [{"type": "card_skill", "id": "cps_cleanse"}],
		 "effects": {}},
		# tier 9c：纳米病毒（v8.6 机制解锁——支援/火炮单位自带纳米病毒弹头）
		{"id": "pms_int_9c", "name": "纳米病毒", "desc": "解锁机制：支援/火炮单位攻击20%概率注入纳米病毒（每秒损失1.5%最大生命值，持续6秒，打肉盾专用）",
		 "branch": BRANCH_INTELLIGENCE, "tier": 9, "cost": 2, "requires": ["pms_int_8"],
		 "unlocks": [{"type": "unit_mechanism", "id": "nano_virus"}],
		 "effects": {}},
		# tier 9d：无人机协同（v9 奇点归位智能系——侦察标记链链首；需奇点解算门关）
		{"id": "pms_cw_5", "name": "无人机协同", "desc": "◈奇点 解锁机制：无人机每14秒标记半径400内最高威胁的2个敌方，被标记目标受到+25%额外伤害（持续8秒）",
		 "branch": BRANCH_INTELLIGENCE, "tier": 9, "cost": 2, "requires": ["pms_int_8", "pms_cw_0"],
		 "unlocks": [{"type": "unit_mechanism", "id": "drone_mark"}],
		 "effects": {}, "capstone": true},
		# tier 10：AI 指挥
		{"id": "pms_int_10", "name": "AI 指挥", "desc": "全体友军攻速+15%、暴击+10%",
		 "branch": BRANCH_INTELLIGENCE, "tier": 10, "cost": 2, "requires": ["pms_int_9a", "pms_int_9b"],
		 "unlocks": [],
		 "effects": {"stat_bonus": {"attack_speed": 0.15, "crit_chance": 0.10}}},
		# tier 11：时间迟缓（v9 奇点归位智能系——时空控制链链首；需 AI 指挥+奇点解算门关）
		{"id": "pms_cw_8", "name": "时间迟缓", "desc": "◈奇点 解锁卡片技能「全场减速」：每 30s 全体敌方移速-50%、攻速-50%（4s）",
		 "branch": BRANCH_INTELLIGENCE, "tier": 11, "cost": 2, "requires": ["pms_int_10", "pms_cw_0"],
		 "unlocks": [{"type": "card_skill", "id": "cps_time_slow"}],
		 "effects": {}, "capstone": true},
		# tier 11：诸神黄昏节点已删除（原虚空降临，奇幻概念过重，用户要求移除）
		# tier 12：全面战争（高级战法）—— requires 直接接 pms_int_10（AI 指挥）
		{"id": "pms_int_12", "name": "全面战争", "desc": "解锁高级战法「全面战争」：4 终极技能时全体 +40% 全属性，敌方每秒-1% HP",
		 "branch": BRANCH_INTELLIGENCE, "tier": 12, "cost": 3, "requires": ["pms_int_10"],
		 "unlocks": [{"type": "tactic", "id": "tactic_total_war"}],
		 "effects": {}},
		# tier 12 并列：天罚雷阵（v9 奇点归位智能系，接时间迟缓链）
		{"id": "pms_cw_7a", "name": "天罚雷阵", "desc": "◈奇点 解锁卡片技能「全图雷击」：每 100s 15 道闪电，全图感电",
		 "branch": BRANCH_INTELLIGENCE, "tier": 12, "cost": 2, "requires": ["pms_cw_8"],
		 "unlocks": [{"type": "card_skill", "id": "cps_heaven_thunder"}],
		 "effects": {}, "capstone": true},
		# tier 13：闪电链（卡片技能——电子战链式雷击，原幽灵技能补挂）
		{"id": "pms_int_13", "name": "闪电链", "desc": "解锁卡片技能「链式雷击」：每 10s 弹跳 5 次雷伤（对装甲+50%）",
		 "branch": BRANCH_INTELLIGENCE, "tier": 13, "cost": 3, "requires": ["pms_int_12"],
		 "unlocks": [{"type": "card_skill", "id": "cps_chain_lightning"}],
		 "effects": {}},
		# tier 13 并列：太阳耀斑（v9 奇点归位智能系，接天罚雷阵链——时空控制链终点）
		{"id": "pms_cw_13b", "name": "太阳耀斑", "desc": "◈奇点 解锁卡片技能「全体易伤」：每 35s 全体敌方+25%易伤（5s）",
		 "branch": BRANCH_INTELLIGENCE, "tier": 13, "cost": 3, "requires": ["pms_cw_7a"],
		 "unlocks": [{"type": "card_skill", "id": "cps_solar_flare"}],
		 "effects": {}, "capstone": true},
	],
}

## 获取指定分支的扩展节点
static func get_extension_nodes(branch: String) -> Array:
	return EXTENSION_NODES.get(branch, []).duplicate(true)

## 获取所有扩展节点（扁平化）
static func get_all_extension_nodes() -> Array:
	var all: Array = []
	for branch in EXTENSION_NODES.keys():
		for node in EXTENSION_NODES[branch]:
			all.append(node)
	return all

## 根据 ID 查找扩展节点
static func get_extension_skill(skill_id: String) -> Dictionary:
	for branch in EXTENSION_NODES.keys():
		for node in EXTENSION_NODES[branch]:
			if node.get("id", "") == skill_id:
				return node.duplicate(true)
	return {}
