## 改造效果 key → 中文显示的**唯一权威翻译表**（简短词口径）。
##
## 背景：原先 card_info_panel / modification_panel / card_enhancement_panel 各维护一份
## 翻译表（分简短/完整两套口径 + 一份仅 25 key 的不全表），导致同一张卡在不同面板
## 显示的改造效果文案不一致。v7.x 统一为情报面板的简短词口径，三处调用方都走本表。
##
## 用法：ModEffectLabels.translate("attack_light") → "轻攻"
## 未命中的 key 原样返回（不裸露英文也不崩，方便新 key 上线时显示）。
extends RefCounted
class_name ModEffectLabels


## 翻译改造效果 key 为简短中文显示名。
## 覆盖全部标准 effect key + 7 个武器槽 slot_* key（与 modification_registry._apply_single_mod_effects 的 match 分支对齐，含 crit_mark_* 暴击标注系列）。
static func translate(key: String) -> String:
	match key:
		# ── 主属性 ──（维度语义 = 目标类型，与 unit_stats.gd 字段注释、attack_calculator 战斗逻辑对齐）
		"attack_light": return "轻攻"
		"attack_armor": return "重攻"
		"attack_air": return "防空"
		"attack_fort": return "攻坚"
		"defense_light": return "轻防"
		"defense_armor": return "重防"
		"defense_air": return "空防"
		"max_hp": return "生命"
		"move_speed": return "部署"
		"deploy_speed": return "部署"
		"deploy_delay_bonus": return "部署"
		"attack_range": return "射程"
		"attack_interval": return "攻速"
		# ── 暴击/闪避/穿透 ──
		"crit_chance": return "暴击"
		"crit_resist": return "暴抗"
		"crit_damage_bonus": return "暴伤"
		"dodge_chance": return "闪避"
		"armor_penetration": return "穿甲"
		"armor_pen_vs_light": return "穿甲(轻)"
		"armor_pen_vs_armor": return "穿甲(重)"
		"armor_pen_vs_air": return "穿甲(空)"
		# ── 生存/吸血/护盾 ──
		"damage_reduction": return "减伤"
		"lifesteal": return "吸血"
		"hp_regen": return "回血"
		"shield_on_kill": return "护盾"
		"splash_damage": return "溅射"
		"splash_radius": return "溅射范围"
		"single_target_penalty": return "主目标"
		"chain_chance": return "连锁"
		# ── 命中/还击/持续射击 ──
		"accuracy_bonus": return "命中"
		"accuracy_penalty": return "命中惩罚"
		"counter_bonus": return "还击"
		"sustained_fire": return "持续射击"
		# ── 视野/射程/侦测 ──
		"vision": return "视野"
		"vision_bonus": return "视野加成"
		"combat_range": return "作战半径"
		"detection_range": return "侦测范围"
		"detection_reduce": return "隐蔽"
		"stealth_detect": return "隐身侦测"
		"intel_speed": return "情报速度"
		# ── 夜视/烟雾/热防护/三防 ──
		"night_bonus": return "夜战"
		"smoke_ignore": return "烟雾无视"
		"thermal_immunity": return "热成像"
		"heat_resist": return "HEAT抗性"
		"heat_immunity_once": return "HEAT首免"
		"mine_immunity": return "避雷"
		"mine_damage_reduction": return "地雷减伤"
		"nbq_immunity": return "三防"
		# ── 反装甲/近战/拦截 ──
		"enemy_armor_slow": return "敌甲减速"
		"approach_damage": return "近距伤害"
		"urban_attack_bonus": return "巷战攻击"
		"urban_move_bonus": return "巷战机动"
		"missile_intercept": return "拦截"
		"missile_dodge": return "反导"
		# ── 弹药/持续作战/移动射击 ──
		"ammo_capacity": return "弹药容量"
		"sustained_combat": return "持续作战"
		"infinite_ammo": return "无限弹药"
		"mobile_fire": return "行进射击"
		# ── 隐蔽/反锁定 ──
		"lock_reduction": return "锁定降低"
		"fire_exposure": return "开火暴露"
		"aggro_reduce": return "仇恨降低"
		"close_accuracy": return "近距精度"
		"enemy_confusion": return "敌方混乱"
		# ── 指挥/阵型/盟友协同 ──
		"command_efficiency": return "指挥效率"
		"formation_bonus": return "阵型"
		"ally_bonus": return "盟友加成"
		"ally_hit_bonus": return "盟友命中"
		"ally_ammo": return "盟友弹药"
		"ally_hp_regen": return "盟友回血"
		"ally_fort_regen": return "堡垒回血"
		"ally_detection": return "盟友侦测"
		"ally_river_bonus": return "盟友涉渡"
		"ally_arty_bonus": return "盟友炮火"
		"ifak_heal": return "急救包"
		# ── 武器型号 ──
		"weapon_type": return "武器型号"
		"legacy_weapon_type": return "武器型号"
		# ── 武器槽类(slot_*)──
		"slot_damage_mult": return "槽位伤害倍率"
		"slot_damage_add": return "槽位伤害"
		"slot_attack_speed_mult": return "槽位攻速"
		"slot_range_bonus": return "槽位射程"
		"slot_windup_reduce": return "起射缩短"
		"slot_active_reduce": return "激活缩短"
		"slot_weapon_type": return "弹道型号"
		# ── v7.x 新机制（成长型/debuff型/兵种专属）──
		"combo_system": return "连击阈值"
		"combo_bonus": return "连击爆发"
		"rage_system": return "怒气阈值"
		"rage_bonus": return "怒气加成"
		"armor_break": return "破甲叠加"
		"armor_break_stacks": return "破甲层数"
		"target_marking": return "标记概率"
		"mark_vuln": return "标记易伤"
		"mark_duration": return "标记持续"
		"crit_mark_chance": return "暴击标注"
		"crit_mark_bonus": return "标注暴伤"
		"crit_mark_duration": return "标注持续"
		"siege_bonus": return "爆破百分比"
		"urban_defense": return "巷战免伤"
		"counter_battery": return "反击标记"
		# ── v7.x 第二批新机制 ──
		"ifak_revive": return "濒死复活"
		"reactive_armor": return "爆反反伤"
		"reflect_charges": return "反伤层数"
		"intercept_system": return "拦截概率"
		"intercept_charges": return "拦截次数"
		"death_heal": return "亡语治疗"
		"death_heal_radius": return "治疗范围"
		"minefield": return "雷场伤害"
		"slow_aura": return "区域减速"
		"slow_aura_radius": return "减速范围"
		"command_aura": return "指挥光环"
		"phase_shield": return "相位护盾"
		"phase_shield_regen": return "护盾回复"
		"laser_marker": return "激光标记"
		# 卡牌强化面板历史兼容（attack_damage/defense/faction_accuracy_bonus 非改造 effect key，但强化面板 name_map 曾覆盖）
		"attack_damage": return "攻击"
		"defense": return "防御"
		"faction_accuracy_bonus": return "命中"
		_: return key


## 格式化 grant_slot（赋予新攻击维度）为简短展示文本。
## 复用自 modification_panel._format_grant_slot 的核心逻辑，文案改为简短风格。
## grant = {slot, base_damage, damage_ratio, display_name, ...}
static func format_grant_slot(grant: Dictionary) -> String:
	const SLOT_NAMES := {0: "轻装", 1: "装甲", 2: "对空"}
	var slot_idx: int = int(grant.get("slot", -1))
	var slot_name: String = SLOT_NAMES.get(slot_idx, "未知")
	var dn: String = String(grant.get("display_name", "新武器"))
	var base_field: String = String(grant.get("base_damage", "attack_armor"))
	var ratio: int = int(round(float(grant.get("damage_ratio", 0.7)) * 100.0))
	# base_damage 字段名转简短中文（复用本表 translate；attack_damage 等已覆盖）
	var base_cn: String = translate(base_field)
	return "✦赋予%s攻击：%s（%s×%d%%）" % [slot_name, dn, base_cn, ratio]
