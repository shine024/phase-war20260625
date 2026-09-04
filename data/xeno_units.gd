extends RefCounted
class_name XenoUnits
## 星冥族 20 单位静态数据（v27 黑门无限模式）
##
## 设计文档：docs/无限模式_异族设定（草案）.md（v0.2 定案版）
## 数据流：EnemyUnitManifest.get_entries() F 段 → EnemyArchetypes._ensure_manifest_merged
##         → CapturedUnitCards 自动注册 captured_xeno_* 缴获卡（20 张全部可缴获）。
##
## 数值口径：era=5（星冥带），基准 = 近未来敌方档 ×1.35（设计 §5.3）。
## 战场难度乘区（档位/波数/势力/难度）由 enemy_stat_resolver 照常叠加——
## 本表只给 base 值，与其它段 manifest 同口径。
##
## 三新机制字段（enemy_unit / EndlessBlackgateManager 消费）：
##   psi_shield_frac  灵能护盾层（占最终 HP 比例；5s 未受击后 10%/s 回复，不占 HP）
##   communion        共感网络成员（受网络节点数攻击加成；见 enemy_unit._update_communion）
##   communion_node   共感网络节点（在场时为全星冥单位提供攻击加成；被杀则全网失效）
## 单位特化字段（enemy_unit 消费，v27 首发三件）：
##   death_burst {radius, dmg_frac, hit_allies}  死亡爆裂（龙骑残躯折射自爆/异变体酸血双向）
##   mimic_rewind                                 拟时者死亡回溯（每场一次，半血复活）
##   psi_intercept_chance                         猎能碟无限拦截（intercept_charges=-1）
##
## 视觉：visual_fallback 为占位卡图——v27.2 起全部选用带 unit_anims 雪碧条资产的卡
## （UnitFrameAnim 经 visual_id 继承该卡 idle ping-pong + attack 帧动画；卡面=动画同图）。
## AI 生图管线产出 vis_xeno_* 后替换，届时改本字段 + 跑 tools/generate_card_foot_anchors.py
## + 补 unit_anims/xeno_* 帧资产 + 美术打包铁律。

const XENO_ERA: int = 5

const UNITS: Dictionary = {
	# ── A 段 · 基础战线（8）drop 8% ──
	"xeno_swarmling": {
		"display_name": "蚀群幼体",
		"role": "basic",
		"combat_kind": 0,
		"hp": 260.0,
		"speed": -95.0,
		"attack_light": 95.0, "attack_armor": 30.0, "attack_air": 0.0,
		"attack_range": 110.0, "attack_interval": 0.55,
		"weapon_type": 0, "weapon_label": "蚀爪",
		"defense_light": 18.0, "defense_armor": 8.0, "defense_air": 6.0,
		"tags": ["infantry", "frontline", "fast"],
		"psi_shield_frac": 0.15, "communion": true,
		"visual_fallback": "cold_inf_metis", "visual_scale": 0.55,
		"drop_chance": 0.08, "power": 140,
	},
	"xeno_probe": {
		"display_name": "晶工探测器",
		"role": "basic",
		"combat_kind": 2,
		"hp": 420.0,
		"speed": -55.0,
		"attack_light": 40.0, "attack_armor": 15.0, "attack_air": 0.0,
		"attack_range": 160.0, "attack_interval": 1.2,
		"weapon_type": 0, "weapon_label": "晶钻",
		"defense_light": 30.0, "defense_armor": 25.0, "defense_air": 20.0,
		"tags": ["turret", "sustained", "communion_node"],
		"psi_shield_frac": 0.25, "communion": false, "communion_node": true,
		"visual_fallback": "fut_sup_nrepair", "visual_scale": 0.7,
		"drop_chance": 0.08, "power": 160,
	},
	"xeno_zealot": {
		"display_name": "渡暮狂战士",
		"role": "basic",
		"combat_kind": 0,
		"hp": 880.0,
		"speed": -105.0,
		"attack_light": 330.0, "attack_armor": 120.0, "attack_air": 0.0,
		"attack_range": 110.0, "attack_interval": 0.7,
		"weapon_type": 0, "weapon_label": "双光刃",
		"defense_light": 52.0, "defense_armor": 88.0, "defense_air": 15.0,
		"tags": ["infantry", "frontline"],
		"psi_shield_frac": 0.40, "communion": true,
		"visual_fallback": "ww1_inf_mp18_x", "visual_scale": 0.75,
		"drop_chance": 0.08, "power": 320,
	},
	"xeno_stalker": {
		"display_name": "影跃猎者",
		"role": "basic",
		"combat_kind": 0,
		"hp": 640.0,
		"speed": -85.0,
		"attack_light": 250.0, "attack_armor": 95.0, "attack_air": 0.0,
		"attack_range": 240.0, "attack_interval": 0.9,
		"weapon_type": 0, "weapon_label": "折射棱镜",
		"defense_light": 40.0, "defense_armor": 70.0, "defense_air": 12.0,
		"tags": ["infantry", "fast"],
		"psi_shield_frac": 0.30, "communion": true,
		"visual_fallback": "mod_sup_growler", "visual_scale": 0.75,
		"drop_chance": 0.08, "power": 300,
	},
	"xeno_adept": {
		"display_name": "灵裔侍从",
		"role": "basic",
		"combat_kind": 0,
		"hp": 560.0,
		"speed": -70.0,
		"attack_light": 300.0, "attack_armor": 60.0, "attack_air": 0.0,
		"attack_range": 220.0, "attack_interval": 1.0,
		"weapon_type": 0, "weapon_label": "灵能冲击波",
		"defense_light": 36.0, "defense_armor": 60.0, "defense_air": 10.0,
		"tags": ["infantry"],
		"psi_shield_frac": 0.25, "communion": true,
		"visual_fallback": "fut_inf_neural", "visual_scale": 0.7,
		"drop_chance": 0.08, "power": 270,
	},
	"xeno_sentinel": {
		"display_name": "哨兵浮棱",
		"role": "basic",
		"combat_kind": 2,
		"hp": 700.0,
		"speed": 0.0,
		"attack_light": 120.0, "attack_armor": 90.0, "attack_air": 100.0,
		"attack_range": 260.0, "attack_interval": 1.1,
		"weapon_type": 0, "weapon_label": "棱光束",
		"defense_light": 60.0, "defense_armor": 55.0, "defense_air": 50.0,
		"tags": ["turret", "sustained", "communion_node"],
		"psi_shield_frac": 0.35, "communion": false, "communion_node": true,
		"visual_fallback": "fut_arty_hel30", "visual_scale": 0.9,
		"drop_chance": 0.08, "power": 290,
	},
	"xeno_dragoon": {
		"display_name": "龙骑残躯",
		"role": "basic",
		"combat_kind": 1,
		"hp": 900.0,
		"speed": -60.0,
		"attack_light": 210.0, "attack_armor": 480.0, "attack_air": 0.0,
		"attack_range": 300.0, "attack_interval": 1.0,
		"weapon_type": 0, "weapon_label": "相位炮",
		"defense_light": 55.0, "defense_armor": 210.0, "defense_air": 40.0,
		"tags": ["vehicle", "armored"],
		"psi_shield_frac": 0.30, "communion": true,
		"death_burst": {"radius": 140.0, "dmg_frac": 0.6, "hit_allies": false},
		"visual_fallback": "fut_arm_hk07", "visual_scale": 1.1,
		"drop_chance": 0.08, "power": 380,
	},
	"xeno_plasma_bug": {
		"display_name": "等离囊虫",
		"role": "basic",
		"combat_kind": 2,
		"hp": 620.0,
		"speed": -35.0,
		"attack_light": 190.0, "attack_armor": 260.0, "attack_air": 220.0,
		"attack_range": 460.0, "attack_interval": 1.6,
		"weapon_type": 1, "weapon_label": "等离子抛射",
		"defense_light": 38.0, "defense_armor": 66.0, "defense_air": 18.0,
		"tags": ["turret", "artillery"],
		"psi_shield_frac": 0.20, "communion": true,
		"visual_fallback": "fut_arty_ssc1", "visual_scale": 0.85,
		"drop_chance": 0.08, "power": 300,
	},

	# ── B 段 · 精英战线（6）drop 22% ──
	"xeno_tripod": {
		"display_name": "三足行者",
		"role": "elite",
		"combat_kind": 1,
		"hp": 1500.0,
		"speed": -50.0,
		"attack_light": 340.0, "attack_armor": 950.0, "attack_air": 300.0,
		"attack_range": 340.0, "attack_interval": 1.2,
		"weapon_type": 0, "weapon_label": "热射线",
		"defense_light": 90.0, "defense_armor": 260.0, "defense_air": 60.0,
		"tags": ["vehicle", "armored", "elite"],
		"psi_shield_frac": 0.35, "communion": true,
		"visual_fallback": "mod_arm_himars", "visual_scale": 1.5,
		"drop_chance": 0.22, "power": 720,
	},
	"xeno_hunter": {
		"display_name": "隐面猎手",
		"role": "elite",
		"combat_kind": 0,
		"hp": 700.0,
		"speed": -95.0,
		"attack_light": 380.0, "attack_armor": 90.0, "attack_air": 0.0,
		"attack_range": 280.0, "attack_interval": 1.3,
		"weapon_type": 0, "weapon_label": "肩炮",
		"defense_light": 48.0, "defense_armor": 75.0, "defense_air": 14.0,
		"tags": ["infantry", "stealth", "elite"],
		"psi_shield_frac": 0.25, "communion": true,
		"visual_fallback": "fut_inf_x9", "visual_scale": 0.8,
		"drop_chance": 0.22, "power": 460,
	},
	"xeno_mimic": {
		"display_name": "拟时者",
		"role": "elite",
		"combat_kind": 0,
		"hp": 750.0,
		"speed": -80.0,
		"attack_light": 260.0, "attack_armor": 85.0, "attack_air": 0.0,
		"attack_range": 210.0, "attack_interval": 0.9,
		"weapon_type": 0, "weapon_label": "时棘",
		"defense_light": 42.0, "defense_armor": 72.0, "defense_air": 12.0,
		"tags": ["infantry", "fast", "elite"],
		"psi_shield_frac": 0.30, "communion": true,
		"mimic_rewind": true,
		"visual_fallback": "mod_sup_m4_carbine", "visual_scale": 0.7,
		"drop_chance": 0.22, "power": 430,
	},
	"xeno_biomorph": {
		"display_name": "异变体",
		"role": "elite",
		"combat_kind": 0,
		"hp": 680.0,
		"speed": -130.0,
		"attack_light": 420.0, "attack_armor": 70.0, "attack_air": 0.0,
		"attack_range": 100.0, "attack_interval": 0.6,
		"weapon_type": 0, "weapon_label": "利爪",
		"defense_light": 30.0, "defense_armor": 55.0, "defense_air": 8.0,
		"tags": ["infantry", "fast", "elite"],
		"psi_shield_frac": 0.0, "communion": true,
		"death_burst": {"radius": 130.0, "dmg_frac": 0.8, "hit_allies": true},
		"visual_fallback": "fut_inf_c96", "visual_scale": 0.7,
		"drop_chance": 0.22, "power": 440,
	},
	"xeno_dark_templar": {
		"display_name": "暗影执刃",
		"role": "elite",
		"combat_kind": 0,
		"hp": 820.0,
		"speed": -90.0,
		"attack_light": 520.0, "attack_armor": 110.0, "attack_air": 0.0,
		"attack_range": 120.0, "attack_interval": 1.8,
		"weapon_type": 0, "weapon_label": "虚空折刃",
		"defense_light": 44.0, "defense_armor": 78.0, "defense_air": 13.0,
		"tags": ["infantry", "stealth", "elite"],
		"psi_shield_frac": 0.15, "communion": true,
		"visual_fallback": "ww2_arty_hummel", "visual_scale": 0.78,
		"drop_chance": 0.22, "power": 560,
	},
	"xeno_reaver": {
		"display_name": "蚀甲虫",
		"role": "elite",
		"combat_kind": 1,
		"hp": 1100.0,
		"speed": -30.0,
		"attack_light": 380.0, "attack_armor": 820.0, "attack_air": 0.0,
		"attack_range": 500.0, "attack_interval": 2.2,
		"weapon_type": 1, "weapon_label": "蠕虫弹药",
		"defense_light": 70.0, "defense_armor": 230.0, "defense_air": 45.0,
		"tags": ["vehicle", "armored", "artillery", "elite"],
		"psi_shield_frac": 0.25, "communion": true,
		"visual_fallback": "ww2_arty_pak40", "visual_scale": 1.2,
		"drop_chance": 0.22, "power": 640,
	},

	# ── C 段 · 王牌（3）drop 35% ──
	"xeno_interceptor": {
		"display_name": "拦截机群",
		"role": "ace",
		"combat_kind": 3,
		"hp": 380.0,
		"speed": -150.0,
		"attack_light": 150.0, "attack_armor": 110.0, "attack_air": 130.0,
		"attack_range": 300.0, "attack_interval": 0.5,
		"weapon_type": 2, "weapon_label": "脉冲机炮",
		"defense_light": 26.0, "defense_armor": 38.0, "defense_air": 24.0,
		"tags": ["aircraft", "fast", "elite"],
		"psi_shield_frac": 0.15, "communion": true,
		"visual_fallback": "mod_arty_rq7", "visual_scale": 0.6,
		"drop_chance": 0.35, "power": 320,
	},
	"xeno_carrier": {
		"display_name": "蚀空母舰",
		"role": "ace",
		"combat_kind": 3,
		"hp": 2600.0,
		"speed": -35.0,
		"attack_light": 280.0, "attack_armor": 240.0, "attack_air": 200.0,
		"attack_range": 420.0, "attack_interval": 1.4,
		"weapon_type": 2, "weapon_label": "拦截机群",
		"defense_light": 120.0, "defense_armor": 180.0, "defense_air": 150.0,
		"tags": ["aircraft", "elite", "communion_node"],
		"psi_shield_frac": 0.35, "communion": false, "communion_node": true,
		"visual_fallback": "cold_sup_bmp1_x", "visual_scale": 1.8,
		"drop_chance": 0.35, "power": 980,
	},
	"xeno_saucer": {
		"display_name": "猎能碟",
		"role": "ace",
		"combat_kind": 3,
		"hp": 2200.0,
		"speed": -45.0,
		"attack_light": 420.0, "attack_armor": 700.0, "attack_air": 380.0,
		"attack_range": 480.0, "attack_interval": 2.0,
		"weapon_type": 2, "weapon_label": "聚能主炮",
		"defense_light": 110.0, "defense_armor": 160.0, "defense_air": 130.0,
		"tags": ["aircraft", "elite"],
		"psi_shield_frac": 0.50, "communion": true,
		"psi_intercept_chance": 0.30,
		"visual_fallback": "mod_inf_patriot", "visual_scale": 1.5,
		"drop_chance": 0.35, "power": 1100,
	},

	# ── D 段 · 首领（3）drop 55% ──
	"xeno_templar": {
		"display_name": "渡师·风暴",
		"role": "boss",
		"combat_kind": 2,
		"hp": 3600.0,
		"speed": -20.0,
		"attack_light": 520.0, "attack_armor": 680.0, "attack_air": 560.0,
		"attack_range": 520.0, "attack_interval": 1.8,
		"weapon_type": 1, "weapon_label": "灵能风暴",
		"defense_light": 130.0, "defense_armor": 220.0, "defense_air": 180.0,
		"tags": ["turret", "sustained", "boss", "communion_node"],
		"psi_shield_frac": 0.45, "communion": false, "communion_node": true,
		"visual_fallback": "cold_arty_bmd1", "visual_scale": 1.6,
		"drop_chance": 0.55, "power": 1600,
	},
	"xeno_thing": {
		"display_name": "拟形之惧",
		"role": "boss",
		"combat_kind": 1,
		"hp": 3000.0,
		"speed": -70.0,
		"attack_light": 640.0, "attack_armor": 900.0, "attack_air": 300.0,
		"attack_range": 300.0, "attack_interval": 1.1,
		"weapon_type": 0, "weapon_label": "拟形触刃",
		"defense_light": 110.0, "defense_armor": 280.0, "defense_air": 70.0,
		"tags": ["vehicle", "armored", "boss", "fast"],
		"psi_shield_frac": 0.25, "communion": true,
		"visual_fallback": "fut_sup_ps9", "visual_scale": 1.4,
		"drop_chance": 0.55, "power": 1700,
	},
	"xeno_mothership": {
		"display_name": "蚀冕方舟",
		"role": "boss",
		"combat_kind": 3,
		"hp": 5000.0,
		"speed": -25.0,
		"attack_light": 700.0, "attack_armor": 1100.0, "attack_air": 650.0,
		"attack_range": 560.0, "attack_interval": 2.4,
		"weapon_type": 2, "weapon_label": "湮灭光炮",
		"defense_light": 160.0, "defense_armor": 240.0, "defense_air": 200.0,
		"tags": ["aircraft", "boss", "communion_node"],
		"psi_shield_frac": 0.50, "communion": false, "communion_node": true,
		"visual_fallback": "cold_arm_p18", "visual_scale": 2.0,
		"drop_chance": 0.55, "power": 2400,
	},
}

## 稳定 id 序（A→D 段顺序，名册/缴获图鉴展示用）
const ID_ORDER: Array[String] = [
	"xeno_swarmling", "xeno_probe", "xeno_zealot", "xeno_stalker",
	"xeno_adept", "xeno_sentinel", "xeno_dragoon", "xeno_plasma_bug",
	"xeno_tripod", "xeno_hunter", "xeno_mimic", "xeno_biomorph",
	"xeno_dark_templar", "xeno_reaver",
	"xeno_interceptor", "xeno_carrier", "xeno_saucer",
	"xeno_templar", "xeno_thing", "xeno_mothership",
]

## 角色中文（战前摘要/结算展示用）
const ROLE_LABELS: Dictionary = {
	"basic": "基础", "elite": "精英", "ace": "王牌", "boss": "首领",
}


static func is_xeno(archetype_id: String) -> bool:
	return String(archetype_id).begins_with("xeno_")


static func get_config(archetype_id: String) -> Dictionary:
	return UNITS.get(String(archetype_id), {}).duplicate(true)


static func get_ids() -> Array[String]:
	return ID_ORDER.duplicate()


## 按角色取 id 列表（endless 波次构成用：basic 常规波 / elite 每 5 波 / boss 每 10 波；
## ace 归入精英波的高端补充池——首版不单设王牌波，由精英池按权重混入）
static func get_ids_for_role(role: String) -> Array[String]:
	var out: Array[String] = []
	for id in ID_ORDER:
		if String(UNITS[id].get("role", "")) == role:
			out.append(id)
	return out


static func get_display_name(archetype_id: String) -> String:
	return String(UNITS.get(String(archetype_id), {}).get("display_name", archetype_id))


## 共感网络节点 id 集（endless 战场统计节点数用）
static func get_communion_node_ids() -> Array[String]:
	var out: Array[String] = []
	for id in ID_ORDER:
		if bool(UNITS[id].get("communion_node", false)):
			out.append(id)
	return out
