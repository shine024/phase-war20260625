extends RefCounted
## v37.3 战法件单位贴花映射（唯一真身）——形象类/keystone 改造在战场单位身上的外挂贴片。
## 设计：不碰 unit_spr.texture（v26.9 描边契约零触发），贴花为单位根下的兄弟 Sprite2D。
## 敌我同构：enemy_unit 读 get_meta("loadout_mods")，我方读 card.mods；offset.x 与
## directional 贴花对敌方自动镜像（敌方卡图朝左）。
## 范围（用户拍板 2026-09-17）：只做关键战法/具象装备件——keystone 里有形的 + 伪装/街垒/
## 烟幕/电磁/外骨骼/扫雷犁等看得见的装备，共 11 种贴花；纯数值/算法件不上贴花。

## 贴花配置：decal_id → 贴图/挂点类型/相对偏移(单位躯干高宽占比)/宽度系数/透明度/是否方向性
const DECALS := {
	"camo_net": {
		"tex": "res://assets/ui/icons/unit_decals/camo_net.png",
		"type": "drape", "off": Vector2(0.0, -0.05), "w": 1.18, "alpha": 0.78, "dir": false,
	},
	"sandbags": {
		"tex": "res://assets/ui/icons/unit_decals/sandbags.png",
		"type": "foot", "off": Vector2(0.0, -0.06), "w": 1.12, "alpha": 1.0, "dir": false,
	},
	"smoke_pods": {
		"tex": "res://assets/ui/icons/unit_decals/smoke_pods.png",
		"type": "side", "off": Vector2(0.42, 0.02), "w": 0.42, "alpha": 1.0, "dir": true,
	},
	"emp_mast": {
		"tex": "res://assets/ui/icons/unit_decals/emp_mast.png",
		"type": "mast", "off": Vector2(0.38, -0.42), "w": 0.38, "alpha": 1.0, "dir": true,
	},
	"mine_plow": {
		"tex": "res://assets/ui/icons/unit_decals/mine_plow.png",
		"type": "side", "off": Vector2(0.5, 0.18), "w": 0.5, "alpha": 1.0, "dir": true,
	},
	"spaced_plates": {
		"tex": "res://assets/ui/icons/unit_decals/spaced_plates.png",
		"type": "side", "off": Vector2(0.4, -0.02), "w": 0.46, "alpha": 1.0, "dir": true,
	},
	"aps_turret": {
		"tex": "res://assets/ui/icons/unit_decals/aps_turret.png",
		"type": "mast", "off": Vector2(0.34, -0.46), "w": 0.36, "alpha": 1.0, "dir": false,
	},
	"reactive_blocks": {
		"tex": "res://assets/ui/icons/unit_decals/reactive_blocks.png",
		"type": "side", "off": Vector2(-0.34, 0.0), "w": 0.5, "alpha": 1.0, "dir": true,
	},
	"cb_radar": {
		"tex": "res://assets/ui/icons/unit_decals/cb_radar.png",
		"type": "mast", "off": Vector2(-0.36, -0.44), "w": 0.4, "alpha": 1.0, "dir": true,
	},
	"laser_lens": {
		"tex": "res://assets/ui/icons/unit_decals/laser_lens.png",
		"type": "mast", "off": Vector2(0.4, -0.4), "w": 0.34, "alpha": 1.0, "dir": true,
	},
	"exo_frame": {
		"tex": "res://assets/ui/icons/unit_decals/exo_frame.png",
		"type": "side", "off": Vector2(0.3, -0.08), "w": 0.44, "alpha": 1.0, "dir": true,
	},
}

## mod_id → decal_id（一个贴花可挂多个改造；单位多件命中时按此表序去重，最多 2 枚）
const MOD_MAP := {
	# ── 伪装/隐蔽 ──
	"gen_03_camouflage": "camo_net",
	"rec_01_optical_camouflage": "camo_net",
	# ── 街垒/工事 ──
	"for_15_sandbag": "sandbags",
	"art_12_fortification": "sandbags",
	"inf_24_urban_warfare": "sandbags",
	# ── 烟幕/电磁 ──
	"aa_09_smoke_launcher": "smoke_pods",
	"gen_16_emp_pulse": "emp_mast",
	"gen_17_electronic_hijack": "emp_mast",
	# ── 具象装备（敌方配装已引用：外骨骼×11 间隙装甲×10 火炮掩体×7 扫雷犁×7）──
	"arm_14_mine_plow": "mine_plow",
	"arm_17_spacer_armor": "spaced_plates",
	"arm_03_reactive_armor": "reactive_blocks",
	"eng_12_reactive_engineering": "reactive_blocks",
	"inf_16_exoskeleton": "exo_frame",
	# ── keystone 有形件 ──
	"arm_04_aps": "aps_turret",
	"art_14_counter_battery": "cb_radar",
	"aa_06_laser": "laser_lens",
	"for_11_advanced_minefield": "sandbags",
}


static func decals_for_mods(mod_ids: Array) -> Array[String]:
	var out: Array[String] = []
	for mid in mod_ids:
		var d: String = MOD_MAP.get(String(mid), "")
		if d != "" and not out.has(d) and DECALS.has(d):
			out.append(d)
		if out.size() >= 2:
			break
	return out
