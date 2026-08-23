extends RefCounted
class_name UnlockLabels
## ═══════════════════════════════════════════════════════════
##  v8.x 解锁内容玩家可读标签表
##
##  统一管理技能树 unlocks[].id → 玩家可读文案的映射。
##  供 phase_master_skill_panel 显示、Toast 通知、card_info_panel 兵种描述使用。
##
##  覆盖 4 种 unlock_type：
##    unit_mechanism → 兵种机制技能（v8.5：定向爆破/瞄准狙击/闪电穿插/电子屏蔽/战术核武/护盾投射/定时标记）
##    card_skill     → 卡片定时技能（炮兵协调/EMP/钢铁风暴 等 21 个）
##    tactic         → 战法（钳形攻势/刺猬防御 等 18 个）
##    unit_ability   → 兵种能力（穿甲/暴击/吸血，现有 20 节点沿用）
## ═══════════════════════════════════════════════════════════

## 兵种机制标签（unit_mechanism）
# v8.5：原 stalker_stealth/sniper_training/ecm_aura/engineer_build/command_aura/smart_targeting 6 个空转机制
#       已替换为 7 个真实生效的兵种机制技能（meta+timer+VFX 范式）
const UNIT_MECHANISM_LABELS: Dictionary = {
	# v8.5 兵种机制技能（7 个，对应技能树 unit_mechanism 解锁节点）
	"demolition": {
		"name": "定向爆破",
		"short": "爆破",
		"desc": "侦察单位每12秒原地发射曲射爆破弹打最近敌方堡垒/装甲，造成8%最大生命的真实伤害",
		"icon": "💥"
	},
	"sniper_aim": {
		"name": "瞄准狙击",
		"short": "瞄准",
		"desc": "狙击单位每15秒进入瞄准状态，下次攻击必暴击且伤害+50%（对Boss×2）",
		"icon": "🎯"
	},
	"blitz_pierce": {
		"name": "闪电穿插",
		"short": "穿插",
		"desc": "装甲单位每10秒下次攻击变为穿透弹，越过前排堡垒直击后排2个单位",
		"icon": "⚡"
	},
	"jamming_field": {
		"name": "电子屏蔽",
		"short": "屏蔽",
		"desc": "防空/电子战单位每18秒释放屏蔽波（半径300），范围内敌方攻击失效3秒",
		"icon": "📡"
	},
		"nuclear_strike": {
			"name": "战术核武",
			"short": "核武",
			"desc": "导弹发射井堡垒每45秒发射战术核弹，弹道飞行后对敌方密集区半径200内造成35%最大生命（保底200）的范围伤害",
			"icon": "☢"
		},
	"shield_projector": {
		"name": "护盾投射",
		"short": "护盾",
		"desc": "护盾发射器堡垒每20秒为半径250内生命最低的3个友军投射护盾（吸收20%自身最大生命）",
		"icon": "🛡"
	},
	"drone_mark": {
		"name": "定时标记",
		"short": "标记",
		"desc": "无人机每14秒标记半径400内最高威胁的2个敌方，被标记目标受到+25%额外伤害（持续8秒）",
		"icon": "📍"
	},
	# v8.6 现实/科幻伤害类型机制
	"chemical_weapon": {
		"name": "化学武器",
		"short": "化学",
		"desc": "支援/火炮单位攻击25%概率施加化学毒剂：每秒6伤害，持续5秒（绿色毒雾）",
		"icon": "☣"
	},
	"nano_virus": {
		"name": "纳米病毒",
		"short": "纳米",
		"desc": "支援/火炮单位攻击20%概率注入纳米病毒：目标每秒损失1.5%最大生命值，持续6秒（紫色粒子，打肉盾专用）",
		"icon": "🧬"
	},
}

## 兵种能力标签（unit_ability）
const UNIT_ABILITY_LABELS: Dictionary = {
	"armor_pen": {"name": "穿甲弹道", "short": "穿甲", "desc": "装甲单位对装甲目标穿透+20%", "icon": "⚔"},
	"light_crit": {"name": "精确射击", "short": "暴击", "desc": "步兵单位暴击率+15%", "icon": "✦"},
	"lifesteal_unlock": {"name": "纵深打击", "short": "回收", "desc": "射程+10%，击杀回复自身6%最大HP", "icon": "🔧"},
}

## 卡片定时技能标签（card_skill）
const CARD_SKILL_LABELS: Dictionary = {
	# 钢铁家族
	"cps_artillery_coord": {"name": "炮兵协调射击", "desc": "每15秒对敌方密集区炮击（友军ATK×1.5）", "icon": "💥", "family": "steel"},
	"cps_steel_bulwark": {"name": "钢铁壁垒", "desc": "每20秒全体堡垒+2000护盾", "icon": "🛡", "family": "steel"},
	"cps_minefield": {"name": "反坦克雷区", "desc": "每18秒敌方密集区布雷（对装甲+50%）", "icon": "💣", "family": "steel"},
	"cps_repair_aura": {"name": "机械维修站", "desc": "每10秒全体机械单位+3%最大HP", "icon": "🔧", "family": "steel"},
	"cps_cleanse": {"name": "工程抢修", "desc": "每18秒清除全体debuff+800护盾", "icon": "✨", "family": "steel"},
	"cps_steel_storm": {"name": "钢铁风暴", "desc": "每90秒全体友军+3000护盾+20%减伤（10秒）", "icon": "🛡", "family": "steel", "is_ultimate": true},
	# 火焰家族
	"cps_scorched_earth": {"name": "焦土政策", "desc": "每16秒敌方密集区燃烧8秒", "icon": "🔥", "family": "flame"},
	"cps_burn_city": {"name": "焚城", "desc": "每60秒全图轰炸250火伤+燃烧", "icon": "🌋", "family": "flame", "is_ultimate": true},
	"cps_firestorm": {"name": "烈焰风暴", "desc": "每80秒全图燃烧+恐慌", "icon": "🌪", "family": "flame", "is_ultimate": true},
	"cps_solar_flare": {"name": "太阳耀斑", "desc": "每35秒全体敌方+25%易伤", "icon": "☀", "family": "flame"},
	"cps_combustion": {"name": "火焰传导", "desc": "每18秒燃烧传染5个邻近敌方", "icon": "🔗", "family": "flame"},
	# 雷霆家族
	"cps_emp_strike": {"name": "EMP瘫痪", "desc": "每12秒最高威胁敌方攻速-60%（4秒）", "icon": "⚡", "family": "thunder"},
	"cps_chain_lightning": {"name": "闪电链", "desc": "每10秒弹跳5次雷伤（对装甲+50%）", "icon": "⚡", "family": "thunder"},
	"cps_heaven_thunder": {"name": "天罚雷阵", "desc": "每100秒全图15道闪电+感电", "icon": "🌩", "family": "thunder", "is_ultimate": true},
	"cps_railgun": {"name": "电磁轨道炮", "desc": "每30秒对最高HP敌方350%穿甲伤害", "icon": "🔫", "family": "thunder"},
	"cps_bvr_mark": {"name": "超视距打击", "desc": "每18秒标记最高威胁敌方+30%易伤", "icon": "🎯", "family": "thunder"},
	# 虚空家族
	"cps_time_slow": {"name": "时间迟缓", "desc": "每30秒全体敌方移速-50%、攻速-50%（4秒）", "icon": "⏰", "family": "void"},
	"cps_reality_collapse": {"name": "现实崩溃", "desc": "每60秒斩杀HP<15%敌方", "icon": "🕳", "family": "void"},
	"cps_annihilate": {"name": "湮灭之光", "desc": "每120秒全图300%虚空伤+斩杀低血", "icon": "💀", "family": "void", "is_ultimate": true},
	"cps_time_rewind": {"name": "时间回溯", "desc": "每90秒全体恢复30%HP+清除debuff", "icon": "🔄", "family": "void", "is_ultimate": true},
	"cps_dimension_overlay": {"name": "维度叠加", "desc": "每150秒全体闪避+40%、受伤-30%（12秒）", "icon": "🌌", "family": "void", "is_ultimate": true},
	# v8.5 清理：cps_adaptive_shield（已废弃改为 jamming_field 机制）、
	# cps_smart_repair（cps_repair_aura 旧别名）、cps_smart_cleanse（cps_cleanse 旧别名）
	# 三个孤儿标签无对应技能定义，删除避免 UI 误显示。
}

## 战法标签（tactic）
const TACTIC_LABELS: Dictionary = {
	# 基础战法（12）
	"tactic_pincer": {"name": "钳形攻势", "desc": "≥2装甲+1快攻：装甲对最高威胁+25%伤害", "icon": "🔱", "tier": 1},
	"tactic_hedgehog": {"name": "刺猬防御", "desc": "≥3堡垒+1工兵：全体-25%受伤", "icon": "🦔", "tier": 1},
	"tactic_flank_pincer": {"name": "两翼包抄", "desc": "≥2快攻：快攻+30%伤害，中央+30%防御", "icon": "⚔️", "tier": 1},
	"tactic_crossfire": {"name": "交叉火力", "desc": "≥3狙击：狙击射程+30%、伤害+25%、必中", "icon": "🎯", "tier": 1},
	"tactic_fortress_line": {"name": "堡垒防线", "desc": "≥4堡垒：全体-35%受伤", "icon": "🛡️", "tier": 1},
	"tactic_draw_deep": {"name": "诱敌深入", "desc": "1快攻+3后排：快攻-30%受伤，后排+25%攻击", "icon": "🎣", "tier": 1},
	"tactic_scorched_line": {"name": "焦土防线", "desc": "2火焰+1堡垒：免疫燃烧，火焰+30%", "icon": "🔥", "tier": 1},
	"tactic_saturation": {"name": "饱和打击", "desc": "≥2火炮+1电子战：火炮+50%伤害、+20%射程", "icon": "💥", "tier": 1},
	"tactic_decapitation": {"name": "斩首行动", "desc": "狙击+渗透+虚空：对Boss/相位师伤害×2", "icon": "⚔", "tier": 1},
	"tactic_feint": {"name": "声东击西", "desc": "电子战+2快攻：快攻+25%暴击，电子战-25%受伤", "icon": "🎭", "tier": 1},
	"tactic_siege_intercept": {"name": "围点打援", "desc": "≥2堡垒+1装甲：堡垒-20%受伤，装甲+50%反援", "icon": "🏰", "tier": 1},
	"tactic_depth_operation": {"name": "纵深作战", "desc": "≥3不同兵种：全体全属性+10%", "icon": "🌐", "tier": 1},
	# 高级战法（5）
	"tactic_blitz": {"name": "闪电穿插", "desc": "≥3快攻：快攻+40%攻速、+30%伤害", "icon": "⚡", "tier": 2},
	"tactic_sky_net": {"name": "天罗地网", "desc": "钢铁+雷霆：全体敌方-30%攻速/移速", "icon": "🕸", "tier": 2},
	"tactic_inferno_counter": {"name": "纵火反击", "desc": "≥2火焰：全体+20%HP，死亡20%复活", "icon": "🔥", "tier": 2},
	"tactic_4d_strike": {"name": "四维打击", "desc": "4家族各1技能：全体+25%全属性", "icon": "✨", "tier": 2},
	"tactic_total_war": {"name": "全面战争", "desc": "4终极技能：全体+40%全属性，敌方每秒-1%HP", "icon": "☢️", "tier": 2},
}

## 卡牌标签翻译表（card.tags → 中文）
const CARD_TAG_LABELS: Dictionary = {
	# 现有标签
	"infantry": "步兵",
	"vehicle": "车辆",
	"armored": "装甲",
	"support": "支援",
	"aircraft": "空中",
	"fortress": "堡垒",
	"immobile": "固定",
	"boss": "Boss",
	"elite": "精英",
	# v8.x 新兵种标签
	"stalker": "渗透者",
	"sniper": "狙击手",
	"ecm": "电子战",
	"engineer": "工程兵",
	"stealth": "潜行",
	# 战术标签
	"fast": "快攻",
	"artillery": "火炮",
	"antitank": "反坦克",
	"command": "指挥",
	"recon": "侦察",
}

## 根据 unlock_type + id 获取玩家可读标签
## 返回 {"name": String, "desc": String, "icon": String}，找不到返回空字典
static func get_unlock_label(unlock_type: String, content_id: String) -> Dictionary:
	var table: Dictionary = {}
	match unlock_type:
		"unit_mechanism": table = UNIT_MECHANISM_LABELS
		"unit_ability": table = UNIT_ABILITY_LABELS
		"card_skill": table = CARD_SKILL_LABELS
		"tactic": table = TACTIC_LABELS
		_: return {}
	if table.has(content_id):
		return table[content_id]
	return {}

## 根据 card tag 获取中文标签（找不到返回原 tag）
static func get_card_tag_label(tag: String) -> String:
	return String(CARD_TAG_LABELS.get(tag, tag))

## 获取所有解锁内容用于"已解锁总览"显示
## 返回 [{type, id, name, desc, icon}] 数组
static func get_unlocked_summary(unlocked_nodes: Array) -> Array:
	var SkillTree = preload("res://data/phase_master_skill_tree.gd")
	var summary: Array = []
	for node_id in unlocked_nodes:
		var node: Dictionary = SkillTree.get_skill(node_id)
		if node.is_empty():
			continue
		var unlocks: Array = node.get("unlocks", [])
		for u in unlocks:
			if not (u is Dictionary):
				continue
			var u_type: String = u.get("type", "")
			var u_id: String = str(u.get("id", ""))
			var label: Dictionary = get_unlock_label(u_type, u_id)
			if not label.is_empty():
				summary.append({
					"type": u_type,
					"id": u_id,
					"name": String(label.get("name", u_id)),
					"desc": String(label.get("desc", "")),
					"icon": String(label.get("icon", "•")),
					"node_name": String(node.get("name", "")),
				})
			elif u_type == "phase_instrument":
				# 相位仪解锁：查 PhaseInstruments 取中文名，查不到回退原始 ID
				var PhaseInstrumentsCls = preload("res://data/phase_instruments.gd")
				var inst_cfg: Dictionary = PhaseInstrumentsCls.get_by_id(u_id)
				var inst_name: String = String(inst_cfg.get("name", u_id))
				summary.append({
					"type": u_type,
					"id": u_id,
					"name": "相位仪：" + inst_name,
					"desc": "已解锁相位仪装备",
					"icon": "🔮",
					"node_name": String(node.get("name", "")),
				})
			elif u_type == "affix":
				summary.append({
					"type": u_type,
					"id": u_id,
					"name": "词条系统解锁",
					"desc": "解锁 affix 词条池",
					"icon": "📊",
					"node_name": String(node.get("name", "")),
				})
			elif u_type == "evolution":
				# era: -1=全时代, 0-4=一战/二战/冷战/现代/近未来
				var era: int = int(u.get("era", -1))
				var era_names: Array = ["一战", "二战", "冷战", "现代", "近未来"]
				var era_label: String = "全时代" if era == -1 else (era_names[clampi(era, 0, 4)] if era >= 0 and era < 5 else "时代%d" % era)
				summary.append({
					"type": u_type,
					"id": u_id,
					"name": "进化：" + era_label,
					"desc": "解锁卡牌进化形态",
					"icon": "🧬",
					"node_name": String(node.get("name", "")),
				})
			elif u_type == "concept_weapon":
				summary.append({
					"type": u_type,
					"id": u_id,
					"name": "概念武器：" + u_id,
					"desc": "解锁概念武器",
					"icon": "☢",
					"node_name": String(node.get("name", "")),
				})
			elif u_type == "special_card":
				summary.append({
					"type": u_type,
					"id": u_id,
					"name": "特殊卡：" + u_id,
					"desc": "解锁特殊卡牌",
					"icon": "🌟",
					"node_name": String(node.get("name", "")),
				})
	return summary
