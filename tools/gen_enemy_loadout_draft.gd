extends SceneTree
## v26 敌方固定配装表生成器（初稿）——产出 data/enemy_fixed_loadouts.gd 的 LOADOUTS 区块
##
## 流程：枚举全部敌方原型（5 时代）→ 解析源卡 id（剥 foe_ 前缀）→ 按数值画像选套路模板
## → 从该卡时代兼容+兵种适用的改造池中按模板偏好键打分选 9 条（conflict_group 去重、
## 白名单键校验）→ 排序（训练条前移）→ 写回数据文件生成区标记之间。
## 生成后需人工核对 identity（boss/精英卡建议全部手写覆写）。
##
## Usage: godot --headless --path . --script tools/gen_enemy_loadout_draft.gd

const EnemyArchetypes = preload("res://data/enemy_archetypes.gd")
const Registry = preload("res://scripts/systems/modification_registry.gd")
const Loadouts = preload("res://data/enemy_fixed_loadouts.gd")

const OUT_PATH := "res://data/enemy_fixed_loadouts.gd"
const MARK_START := "# 【GEN:LOADOUTS:START】"
const MARK_END := "# 【GEN:LOADOUTS:END】"

## 套路模板（label=档位展示词，flavor=定位一句话，keys=偏好效果键按权重降序，enh=主题训练条）
const TEMPLATES := {
	"BREAK":  {"label": "破甲攻坚", "flavor": "反装甲火力特化，专啃硬目标",
		"keys": ["attack_armor", "attack_armor_pct", "armor_penetration", "armor_pen_vs_armor", "true_damage", "attack_fort_bonus", "armor_break", "siege_bonus_pct", "crit_damage_bonus", "attack_light", "crit_chance"],
		"enh": ["enh_penetration", "enh_dmg_up"]},
	"SUPPRESS": {"label": "火力压制", "flavor": "面杀伤持续输出，压制步兵集群",
		"keys": ["attack_light", "attack_light_pct", "splash_damage", "splash_radius", "chain_chance", "attack_interval", "crit_chance", "attack_range", "kill_repair", "true_damage", "attack_armor"],
		"enh": ["enh_dmg_up", "enh_splash"]},
	"AA":     {"label": "防空特化", "flavor": "制空拦截，猎杀飞行单位",
		"keys": ["attack_air", "crit_chance", "armor_pen_vs_air", "attack_interval", "attack_range", "attack_light", "dodge_chance", "crit_damage_bonus"],
		"enh": ["enh_crit", "enh_dmg_up"]},
	"TANK":   {"label": "重装防御", "flavor": "厚甲消耗战，正面硬抗",
		"keys": ["defense_armor", "defense_armor_pct", "max_hp", "max_hp_pct", "damage_reduction", "defense_light", "defense_light_pct", "hp_regen", "dodge_chance"],
		"enh": ["enh_hp_up", "enh_def_up"]},
	"MOBILE": {"label": "机动游击", "flavor": "快速穿插，先手接敌",
		"keys": ["move_speed", "dodge_chance", "deploy_speed", "crit_chance", "attack_range", "attack_light"],
		"enh": ["enh_speed_up", "enh_dodge"]},
	"RECON":  {"label": "侦察标记", "flavor": "标记集火，为全队指目标",
		"keys": ["crit_chance", "mark_chance", "mark_vuln_bonus", "vision", "night_bonus", "crit_damage_bonus", "dodge_chance"],
		"enh": ["enh_crit", "enh_range_up"]},
	"SIEGE":  {"label": "攻城压制", "flavor": "反堡垒面轰炸，拆阵洗地",
		"keys": ["attack_fort_bonus", "attack_armor", "splash_damage", "splash_radius", "siege_bonus_pct", "true_damage", "attack_range", "attack_light"],
		"enh": ["enh_splash", "enh_dmg_up"]},
	"AIR_SUP": {"label": "制空战机", "flavor": "空优格斗，先抢制空权",
		"keys": ["attack_air", "crit_chance", "dodge_chance", "attack_light", "attack_range"],
		"enh": ["enh_crit", "enh_dmg_up"]},
	"BOMBER": {"label": "对地轰炸", "flavor": "洗地火力，一片焦土",
		"keys": ["attack_light", "attack_armor", "splash_damage", "splash_radius", "true_damage", "crit_damage_bonus", "attack_range"],
		"enh": ["enh_splash", "enh_dmg_up"]},
}

## 逐卡覆写（v27.7 新增）——审计超差卡经此强制模板/档位条数，重生成不丢。
## 依据 tools/enemy_tier_strength_audit.gd 实测（±15% 容差）：
## - fut_arm_mech_e：BREAK 在 1260 攻甲底上叠 apfsds/相位共振/炮射导弹 → 档1/2 +28%/+17%，改 TANK 降温；
## - mod_air_technical_e：MOBILE 九条全移速/闪避/护盾，攻血贡献 0.93（档4 -31%），改 SUPPRESS 补输出件。
## 已知不修（结构性小底子，cuts 已顶格）：ww1_sup_mg_nest / ww2_sup_mg42（HP 109/233，
## pct/flat 贡献天然上不去，-17~-19% 接受——固定机枪巢不该有精锐坦克级强度）。
const CARD_OVERRIDES := {
	"fut_arm_mech_e": {"tpl": "TANK"},
	"mod_air_technical_e": {"tpl": "SUPPRESS"},
}

func _initialize() -> void:
	var entries: Array[String] = []
	var stats := {"total": 0, "by_tpl": {}, "miss_pool": [], "short_pool": []}
	# v27: range(6) 纳入 era=5 星冥带（黑门无限模式 xeno_*）——era 5 的改造池
	# 兼容判定映射到近未来带（改造系统无星冥专属条目，用最高时代带）。
	for era in range(6):
		var ids: Array = EnemyArchetypes.get_ids_for_era(era)
		for aid in ids:
			var cfg: Dictionary = EnemyArchetypes.get_config(String(aid))
			var entry := _build_entry(String(aid), cfg, era, stats)
			if not entry.is_empty():
				entries.append(entry)
	_emit(entries, stats)
	quit(0)

## 按数值画像选模板
func _pick_template(cfg: Dictionary) -> String:
	var kind: int = int(cfg.get("combat_kind", 0))
	var al: float = float(cfg.get("attack_light", 0.0))
	var aa: float = float(cfg.get("attack_armor", 0.0))
	var aair: float = float(cfg.get("attack_air", 0.0))
	var tags: Array = cfg.get("tags", []) as Array
	if kind == 3:
		return "AIR_SUP" if aair >= al * 0.9 else "BOMBER"
	if aair > 0.0 and aair >= maxf(al, aa):
		return "AA"
	if kind == 4:
		return "SIEGE" if aa >= al else "TANK"
	if kind == 1:
		if aa >= al * 1.15:
			return "BREAK" if float(cfg.get("hp", 0.0)) < 900.0 else "TANK"
		return "TANK"
	if kind == 0:
		if tags.has("recon"):
			return "RECON"
		if tags.has("fast"):
			return "MOBILE"
		return "SUPPRESS"
	# kind 2 支援/火炮
	if aa >= al * 1.2:
		return "BREAK"
	return "SIEGE" if aa >= al else "SUPPRESS"

func _build_entry(aid: String, cfg: Dictionary, era: int, stats: Dictionary) -> String:
	stats["total"] += 1
	var tpl_key := _pick_template(cfg)
	# v27.7 逐卡覆写优先于画像选模板（超差卡降温/补件，见 CARD_OVERRIDES 注释）
	var ov: Dictionary = CARD_OVERRIDES.get(aid, {}) as Dictionary
	if not ov.is_empty() and String(ov.get("tpl", "")) != "":
		tpl_key = String(ov["tpl"])
	var tpl: Dictionary = TEMPLATES[tpl_key]
	stats["by_tpl"][tpl_key] = int(stats["by_tpl"].get(tpl_key, 0)) + 1
	# 池口径：按 combat_kind 取兵种模块粗池（get_for_unit_type，绕开玩家卡前缀表——
	# 敌方 UCT id 带兵种中缀如 ww1_inf_mp18，与玩家前缀 ww1_mp18 不匹配），
	# 再逐条过时代带硬门。
	var pool_ids: Array = Registry.get_for_unit_type(int(cfg.get("combat_kind", 0)))
	# v27: era=5（星冥）改造池兼容映射到近未来带（4）——改造注册表无 era5 条目
	var pool_era: int = 4 if era >= 5 else era
	var pool: Array = []
	for mid in pool_ids:
		var md0: Dictionary = Registry.get_data(String(mid))
		if not Registry.is_mod_era_compatible(md0, pool_era):
			continue
		pool.append(String(mid))
	# 打分选条（白名单键命中才入选；conflict_group 去重）
	var picked: Array = []
	var used_groups: Dictionary = {}
	var scored: Array = []
	for mid in pool:
		var md: Dictionary = Registry.get_data(String(mid))
		if md.is_empty():
			continue
		# effects 为空回落 level_effects 最高档（enhancement 词条全用 level_effects）
		var eff: Dictionary = md.get("effects", {})
		if eff.is_empty():
			var le: Dictionary = md.get("level_effects", {})
			if not le.is_empty():
				var ks: Array = le.keys()
				ks.sort()
				eff = le[int(ks[ks.size() - 1])]
		if eff.is_empty():
			continue
		var score := 0.0
		var wl_hit := false
		var pref: Array = tpl["keys"]
		for k in eff.keys():
			var ks2 := String(k)
			if Loadouts.LOADOUT_MOD_SUPPORTED_KEYS.has(ks2):
				wl_hit = true
			var idx := pref.find(ks2)
			if idx >= 0:
				score += float(pref.size() - idx)
		# 主题训练条加权（保证前两槽是训练条）
		if (tpl["enh"] as Array).has(String(mid)):
			score += 30.0
		if not wl_hit:
			continue
		scored.append({"id": String(mid), "score": score, "group": String(md.get("conflict_group", ""))})
	scored.sort_custom(func(a, b): return a.score > b.score or (a.score == b.score and String(a.id) < String(b.id)))
	for s in scored:
		var g := String(s.group)
		if not g.is_empty() and used_groups.has(g):
			continue
		used_groups[g] = true
		picked.append(String(s.id))
		if picked.size() >= 9:
			break
	if picked.size() < 9:
		stats["short_pool"].append("%s(%d条,%s)" % [aid, picked.size(), tpl_key])
	# ── 同卡差异化（确定性哈希）──
	# ① 主题训练条最前（低档先给基础=养成感），其余核心段按 id 哈希轮换 0-2 位——
	#    同模板不同卡在低档位（新兵5/老兵6-7）暴露不同改造，配装观感逐卡不同；
	# ② 哈希奇数卡把末位核心件换成下一顺位备选（"签名件"差异）；
	# ③ cuts 微差：老兵 6/7、精英 8/9 由哈希决定（用户口径 6-7/8-9）。
	var h := _id_hash(aid)
	var enh_first: Array = []
	var rest: Array = []
	for pid in picked:
		if (tpl["enh"] as Array).has(pid):
			enh_first.append(pid)
		else:
			rest.append(pid)
	if h % 2 == 1 and rest.size() >= 3:
		# 签名件替换：末位核心件 ↔ picked 之外的最高分未用条
		for s in scored:
			var sid := String(s.id)
			var sg := String(s.group)
			if not picked.has(sid) and (sg.is_empty() or not used_groups.has(sg)):
				rest[rest.size() - 1] = sid
				break
	var rot: int = h % 3
	for _i in range(rot):
		if rest.size() > 2:
			rest.push_front(rest.pop_back())
	var ordered: Array = []
	ordered.append_array(enh_first)
	ordered.append_array(rest)
	var cuts := {
		1: 5,
		2: 6 + (h / 7) % 2,
		3: 8 + (h / 11) % 2,
		4: 9,
	}
	# v27.7 逐卡覆写 cuts（缺省档走哈希；覆写不得超 9/不高于池深由 picked 长度兜底）
	var ov_cuts: Dictionary = (CARD_OVERRIDES.get(aid, {}) as Dictionary).get("cuts", {}) as Dictionary
	for t in [1, 2, 3, 4]:
		if ov_cuts.has(t):
			cuts[t] = clampi(int(ov_cuts[t]), 1, 9)
	var dn := String(cfg.get("display_name", aid))
	var tags: Array = cfg.get("tags", []) as Array
	var tag_prefix := ""
	if tags.has("boss"):
		tag_prefix = "【首领】"
	elif tags.has("elite"):
		tag_prefix = "【精英】"
	var identity := "%s%s·%s——%s" % [tag_prefix, dn, tpl["label"], tpl["flavor"]]
	return _format_entry(aid, identity, ordered, cuts)

## 确定性 id 哈希（同卡每次生成结果一致）
func _id_hash(s: String) -> int:
	var h := 0
	for c in s:
		h = (h * 31 + c.unicode_at(0)) % 1000000007
	return h

func _format_entry(aid: String, identity: String, mods: Array, cuts: Dictionary) -> String:
	var lines: Array[String] = []
	lines.append('\t"%s": {' % aid)
	lines.append('\t\tidentity = "%s",' % identity)
	lines.append('\t\tmods = [%s],' % ", ".join(mods.map(func(m): return '"%s"' % m)))
	lines.append('\t\tcuts = {1: %d, 2: %d, 3: %d, 4: %d},' % [cuts[1], cuts[2], cuts[3], cuts[4]])
	lines.append('\t},')
	return "\n".join(lines)

func _emit(entries: Array, stats: Dictionary) -> void:
	var body := "\n".join(entries)
	var src := FileAccess.get_file_as_string(OUT_PATH)
	var s0 := src.find(MARK_START)
	var s1 := src.find(MARK_END)
	if s0 < 0 or s1 < 0:
		push_error("生成区标记缺失")
		return
	var out := src.substr(0, s0 + MARK_START.length()) \
		+ "（tools/gen_enemy_loadout_draft.gd 生成区标记）\n" \
		+ "const LOADOUTS: Dictionary = {\n" + body + "\n}\n" \
		+ src.substr(s1, src.length() - s1)
	var f := FileAccess.open(OUT_PATH, FileAccess.WRITE)
	f.store_string(out)
	f.close()
	print("生成条目 %d / 模板分布 %s" % [stats.total, stats.by_tpl])
	if not (stats.miss_pool as Array).is_empty():
		print("!! 池解析失败(%d)：%s" % [(stats.miss_pool as Array).size(), ", ".join(stats.miss_pool)])
	if not (stats.short_pool as Array).is_empty():
		print("!! 池不足9条(%d)：%s" % [(stats.short_pool as Array).size(), ", ".join((stats.short_pool as Array).slice(0, 20))])
