extends SceneTree
## 敌方卡武器配置审查（一次性审计工具，2026-08-17）
## 用法：Godot --headless --path . --script tools/audit_enemy_weapon_config.gd
## 审查对象：统一卡牌表（unified_card_table.gd）中敌方使用条目 + 无覆盖 archetype

const UCT = preload("res://data/unified_card_table.gd")
const GC = preload("res://resources/game_constants.gd")
const EArch = preload("res://data/enemy_archetypes.gd")

const ERA_LABEL := ["一战", "二战", "冷战", "现代", "近未来"]
const KIND_LABEL := ["轻装", "装甲", "支援", "空中", "堡垒"]
const WT_LABEL := ["直射0", "曲射1", "空射2", "支援3"]

# 曲射语义武器关键词（主武器含这些词 → weapon_type 应为 1 INDIRECT）
const INDIRECT_KEYWORDS := ["迫击炮", "榴弹炮", "火箭炮", "多管火箭", "MLRS", "火箭发射", "弹道导弹", "地地导弹"]
# 导弹类（legacy MISSILE→INDIRECT 惯例，不符仅 WARN）
const MISSILE_KEYWORDS := ["导弹"]
# 支援定位关键词
const SUPPORT_KEYWORDS := ["支援", "医疗", "补给", "维修", "后勤", "电子", "雷达", "运输", "通讯", "侦查设备"]

var fails: Array = []
var warns: Array = []
var notes: Array = []

func _init() -> void:
	_audit()
	_print_report()
	quit(0)

func _audit() -> void:
	var all_entries: Array = UCT.get_all_entries()
	# 敌方使用的条目 = enemy_only ∪ card_id 命中 archetype 清单
	var arch_ids: Array = []
	var arch_err: String = ""
	# archetype 清单聚合可能依赖较多数据类，失败则退化为仅 enemy_only 口径
	var merged: Dictionary = {}
	var src: = FileAccess.open("res://data/json/enemy_archetypes.json", FileAccess.READ)
	if src != null:
		var parsed = JSON.parse_string(src.get_as_text())
		if typeof(parsed) == TYPE_DICTIONARY:
			merged = parsed.get("data", {})
			src.close()
	for k in merged.keys():
		arch_ids.append(String(k))

	var enemy_entries: Array = []
	for e in all_entries:
		var cid: String = String(e.get("card_id", ""))
		if bool(e.get("enemy_only", false)) or cid in arch_ids:
			enemy_entries.append(e)
	notes.append("统一表总条目 %d，敌方使用条目 %d（enemy_only 或命中 archetype JSON）" % [all_entries.size(), enemy_entries.size()])

	# ── 覆盖率：JSON archetype 有多少没有统一表条目（武器走 legacy 值） ──
	var uncovered: Array = []
	var legacy_wt_dist: Dictionary = {}
	for aid in arch_ids:
		if not UCT.has_card(aid):
			uncovered.append(aid)
			var cfg: Dictionary = merged.get(aid, {})
			var wt_v: int = int(cfg.get("weapon_type", -1))
			legacy_wt_dist[wt_v] = int(legacy_wt_dist.get(wt_v, 0)) + 1
	notes.append("archetype JSON 共 %d 条，其中 %d 条无统一表覆盖（weapon_type 走 legacy 值，分布 %s）" % [arch_ids.size(), uncovered.size(), str(legacy_wt_dist)])
	# legacy 值 1(RIFLE) 与新枚举 INDIRECT(1) 冲突：会走全槽曲射+索敌按曲射
	var collide_1: Array = []
	var collide_3: Array = []
	for aid in uncovered:
		var cfg: Dictionary = merged.get(aid, {})
		var wt_v: int = int(cfg.get("weapon_type", -1))
		if wt_v == 1:
			collide_1.append("%s(%s)" % [aid, String(cfg.get("weapon_label", cfg.get("display_name", "")))])
		elif wt_v == 3:
			collide_3.append("%s(%s)" % [aid, String(cfg.get("weapon_label", cfg.get("display_name", "")))])
	if not collide_1.is_empty():
		fails.append("[枚举冲突] 无覆盖 archetype 的 legacy weapon_type=1(RIFLE) 与新枚举 INDIRECT(1) 撞值，索敌/槽位全按曲射处理：%s" % ", ".join(collide_1))
	if not collide_3.is_empty():
		warns.append("[枚举冲突] 无覆盖 archetype 的 legacy weapon_type=3(ROCKET) 与新枚举 SUPPORT(3) 撞值（槽位走默认直射，影响小）：%s" % ", ".join(collide_3))

	# ── 逐条目检查 ──
	var per_era_aa: Dictionary = {}
	var per_era_total: Dictionary = {}
	var wt_dist: Dictionary = {}
	for e in enemy_entries:
		var cid: String = String(e.get("card_id", ""))
		var name: String = String(e.get("display_name", cid))
		var era: int = int(e.get("era", 0))
		var ck: int = int(e.get("combat_kind", 0))
		var wt: int = int(e.get("weapon_type", 0))
		var label: String = String(e.get("weapon_label", ""))
		var rng_v: int = int(e.get("range_value", 3))
		var atk_l: float = float(e.get("atk_l", 0.0))
		var atk_a: float = float(e.get("atk_a", 0.0))
		var atk_air: float = float(e.get("atk_air", 0.0))
		var spd_l: float = float(e.get("atk_l_speed", 0.0))
		var spd_a: float = float(e.get("atk_a_speed", 0.0))
		var spd_air: float = float(e.get("atk_air_speed", 0.0))
		var w_l: String = String(e.get("w_light", ""))
		var w_a: String = String(e.get("w_armor", ""))
		var w_air: String = String(e.get("w_air", ""))
		var who: String = "%s|%s|%s时代%s" % [cid, name, ERA_LABEL[era] if era >= 0 and era < 5 else str(era), KIND_LABEL[ck] if ck >= 0 and ck < 5 else str(ck)]

		wt_dist[wt] = int(wt_dist.get(wt, 0)) + 1
		per_era_total[era] = int(per_era_total.get(era, 0)) + 1
		if atk_air > 0.0:
			per_era_aa[era] = int(per_era_aa.get(era, 0)) + 1

		# R1 值域
		if wt < 0 or wt > 3:
			fails.append("[值域] %s weapon_type=%d 超出 0-3" % [who, wt])

		# R2 曲射语义
		var has_indirect_kw: String = ""
		for kw in INDIRECT_KEYWORDS:
			if label.find(kw) >= 0:
				has_indirect_kw = kw
				break
		if not has_indirect_kw.is_empty() and wt != 1:
			fails.append("[曲射语义] %s 主武器「%s」含「%s」应为曲射(1)，实际 %s" % [who, label, has_indirect_kw, WT_LABEL[wt] if wt >= 0 and wt < 4 else str(wt)])
		var has_missile_kw := false
		for kw in MISSILE_KEYWORDS:
			if label.find(kw) >= 0:
				has_missile_kw = true
				break
		if has_missile_kw and wt != 1:
			warns.append("[导弹弹道] %s 主武器「%s」含导弹，legacy 惯例映射曲射，实际 %s（若为直射反坦克导弹可接受）" % [who, label, WT_LABEL[wt] if wt >= 0 and wt < 4 else str(wt)])

		# R3 空中单位应为 AERIAL(2)
		if ck == 3 and wt != 2:
			warns.append("[空射] %s 空中单位 weapon_type=%d，惯例应 AERIAL(2)" % [who, wt])
		if ck != 3 and wt == 2:
			warns.append("[空射] %s 非空中单位 weapon_type=2(AERIAL)，地面单位弹道全走空射" % who)

		# R4 SUPPORT(3) 定位核对
		if wt == 3:
			var is_support_named := false
			for kw in SUPPORT_KEYWORDS:
				if name.find(kw) >= 0 or label.find(kw) >= 0:
					is_support_named = true
					break
			if not is_support_named:
				warns.append("[支援武器] %s weapon_type=3(SUPPORT) 但名称/武器无支援语义（%s / %s）" % [who, name, label])

		# R5 射程与武器类型匹配
		if wt == 1 and rng_v < 6:
			warns.append("[射程] %s 曲射武器射程仅 %d 格（火炮类通常 ≥6 或 99）" % [who, rng_v])
		if wt == 0 and rng_v >= 9:
			warns.append("[射程] %s 直射武器射程 %d 格（直射通常 ≤8，99=全图直射）" % [who, rng_v])

		# R6 槽位命名与三维攻击一致性（有名字没伤害=FAIL；有伤害没名字=WARN 统计）
		if not w_air.is_empty() and atk_air <= 0.0:
			fails.append("[槽位空转] %s w_air=「%s」但对空攻击=0，武器名空转" % [who, w_air])
		if not w_a.is_empty() and atk_a <= 0.0:
			fails.append("[槽位空转] %s w_armor=「%s」但对装甲攻击=0，武器名空转" % [who, w_a])
		if not w_l.is_empty() and atk_l <= 0.0:
			fails.append("[槽位空转] %s w_light=「%s」但对轻装攻击=0，武器名空转" % [who, w_l])

		# R7 主武器名应出现在某个槽位
		if not label.is_empty():
			if label != w_l and label != w_a and label != w_air:
				var slots_txt: String = "[%s|%s|%s]" % [w_l, w_a, w_air]
				if w_l.is_empty() and w_a.is_empty() and w_air.is_empty():
					warns.append("[主武器缺槽] %s weapon_label=「%s」但三槽全空" % [who, label])
				else:
					warns.append("[主武器缺槽] %s weapon_label=「%s」未出现在任何武器槽 %s" % [who, label, slots_txt])

		# R8 武器名与定位明显错配（copy-paste 检测）：轻武器单位 w_light 却是火炮名
		if ck == 0 and (w_l.find("火炮") >= 0 or w_l.find("榴弹炮") >= 0 or w_l.find("迫击炮") >= 0):
			warns.append("[槽位错配] %s 步兵单位 w_light=「%s」（火炮名装在对轻装槽，疑似复制错位）" % [who, w_l])
		if ck == 2 and w_l.find("火炮") >= 0 and label.find("机枪") >= 0:
			warns.append("[槽位错配] %s 主武器「%s」（机枪）但 w_light=「%s」（火炮名，疑似复制错位）" % [who, label, w_l])

		# R9 攻速合法性
		if atk_l > 0.0 and spd_l <= 0.0:
			fails.append("[攻速] %s 对轻装有攻击(%d)但攻速<=0" % [who, int(atk_l)])
		if atk_a > 0.0 and spd_a <= 0.0:
			fails.append("[攻速] %s 对装甲有攻击(%d)但攻速<=0" % [who, int(atk_a)])
		if atk_air > 0.0 and spd_air <= 0.0:
			fails.append("[攻速] %s 对空有攻击(%d)但攻速<=0" % [who, int(atk_air)])
		for pair in [["对轻装", atk_l, spd_l], ["对装甲", atk_a, spd_a], ["对空", atk_air, spd_air]]:
			if float(pair[2]) > 4.0 and float(pair[1]) > 0.0:
				warns.append("[攻速偏高] %s %s攻速 %.1f 次/秒" % [who, String(pair[0]), float(pair[2])])

		# R10 三维全零却非支援（打不了任何目标）
		if atk_l <= 0.0 and atk_a <= 0.0 and atk_air <= 0.0 and wt != 3:
			fails.append("[无武装] %s 三维攻击全 0 且非支援型，战场无法输出" % who)

	# 有伤害没武器名统计（约定性，只计数）
	var no_air_name := 0
	var no_armor_name := 0
	for e in enemy_entries:
		if float(e.get("atk_air", 0.0)) > 0.0 and String(e.get("w_air", "")).is_empty():
			no_air_name += 1
		if float(e.get("atk_a", 0.0)) > 0.0 and String(e.get("w_armor", "")).is_empty():
			no_armor_name += 1
	notes.append("有对空攻击但 w_air 为空：%d 条；有对装甲攻击但 w_armor 为空：%d 条（约定性缺名，影响仅显示层）" % [no_air_name, no_armor_name])

	# 每时代防空覆盖
	var aa_line := ""
	for era in range(5):
		var total: int = int(per_era_total.get(era, 0))
		var aa: int = int(per_era_aa.get(era, 0))
		aa_line += "%s:%d/%d(%.0f%%) " % [ERA_LABEL[era], aa, total, (100.0 * aa / total) if total > 0 else 0.0]
	notes.append("各时代具备对空攻击的敌方单位比例：" + aa_line)
	notes.append("敌方条目 weapon_type 分布（新枚举）：" + str(wt_dist))

func _print_report() -> void:
	print("════════ 敌方卡武器配置审查 ════════")
	for n in notes:
		print("[NOTE] " + n)
	print("── WARN %d 项 ──" % warns.size())
	for w in warns:
		print("  " + w)
	print("── FAIL %d 项 ──" % fails.size())
	for f in fails:
		print("  " + f)
	print("════════ 审查结束：FAIL %d / WARN %d ════════" % [fails.size(), warns.size()])
