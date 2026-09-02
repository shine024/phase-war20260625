extends SceneTree
## v25.0 四通道+时代适配 全面平衡核查（一次性分析脚本）
## 回答：改完这些机制是否削弱？——逐项量化新旧值、安装面收缩、实战伤害变化。
## Usage: godot --headless --path . --script tests/_tmp_v22_balance_check.gd

const Registry = preload("res://scripts/systems/modification_registry.gd")
const UST = preload("res://resources/unit_stats_table.gd")
const DefaultCards = preload("res://data/default_cards.gd")
const UCT = preload("res://data/unified_card_table.gd")

func _initialize() -> void:
	print("════════ v25.0 平衡核查 ════════")
	section_a_install_surface()
	section_b_pilot_deltas()
	section_c_flat_extremes()
	section_d_weapon_sync()
	print("════════ 核查完毕 ════════")
	quit(0)

# ── A. era_band 安装面收缩量化 ──────────────────────
func section_a_install_surface() -> void:
	print("\n── A. era_band 安装面（各时代×兵种：可装改造 前→后）──")
	# 每 (era, kind) 取一张玩家卡作代表
	var rep: Dictionary = {}
	for entry in UCT.get_player_card_entries():
		var era: int = int(entry.get("era", -1))
		var kind: int = int(entry.get("combat_kind", -1))
		var cid: String = String(entry.get("card_id", ""))
		if era < 0 or cid.is_empty():
			continue
		if not rep.has([era, kind]):
			rep[[era, kind]] = cid
	for key in rep.keys():
		var era: int = key[0]
		var kind: int = key[1]
		var cid: String = rep[key]
		var before: int = Registry.get_mods_for_card(cid).size()
		var after: int = Registry.get_installable_mods_for_card(cid, era).size()
		var pct: float = (float(after) / float(before) * 100.0) if before > 0 else 0.0
		var tag: String = "  ⚠收缩>40%" if pct < 60.0 and before > 0 else ""
		print("  era%d kind%d %-24s %3d → %3d（%3.0f%%）%s" % [era, kind, cid, before, after, pct, tag])

# ── B. 试点改造逐级 新旧对比 ──────────────────────
func section_b_pilot_deltas() -> void:
	print("\n── B. 试点改造新旧对比（旧=解析值，新=registry 实测）──")
	# B1 倾斜装甲：era0 坦克 / era2 坦克
	for pair in [["ww1_arm_ft17", 0], ["cold_arm_t55", 2]]:
		var cid: String = pair[0]
		var era: int = pair[1]
		var base: float = UST.build_stats_from_card(DefaultCards.get_card_by_id(cid).clone(), era).defense_armor
		var old_flats: Array = [20, 35, 50]
		var new_flats: Array = [15, 25, 35]
		var new_pcts: Array = [0.08, 0.12, 0.18]
		print("  [arm_01 倾斜装甲 @ %s(era%d) 基础防甲 %.0f]" % [cid, era, base])
		for i in range(3):
			var old_v: float = base + old_flats[i]
			var r: Dictionary = Registry.apply_with_level(
				{"defense_armor": base}, [{"id": "arm_01_sloped_armor", "level": i + 1}], {"era": era})
			var new_v: float = float(r["defense_armor"])
			# 实际承伤换算 100/(100+def)
			var old_mit: float = 100.0 / (100.0 + old_v)
			var new_mit: float = 100.0 / (100.0 + new_v)
			print("    Lv%d 防: 旧 %.0f → 新 %.0f（%+.0f%%）| 承伤系数 %.3f→%.3f" % [
				i + 1, old_v, new_v, (new_v / old_v - 1.0) * 100.0, old_mit, new_mit])
	# B2 突击步枪化：仅玩家卡（era1 两张 + era2 一张）
	var b2_cards: Array = []
	for entry in UCT.get_player_card_entries():
		if int(entry.get("combat_kind", -1)) != 0:
			continue
		if int(entry.get("era", -1)) in [1, 2]:
			b2_cards.append(String(entry.get("card_id", "")))
	b2_cards = b2_cards.slice(0, 5)
	for cid in b2_cards:
		var card = DefaultCards.get_card_by_id(cid)
		if card == null:
			continue
		var era: int = int(card.era)
		var base_atk: float = float(card.attack_light)
		var r: Dictionary = Registry.apply_with_level(
			{"attack_light": base_atk}, [{"id": "inf_02_assault_rifle", "level": 3}], {"era": era})
		var new_v: float = float(r["attack_light"])
		var old_v: float = base_atk + 21  # 旧 Lv3 flat
		print("  [inf_02 突击步枪化 Lv3 @ %s(era%d) base=%.0f] 旧 %.0f（%+.0f%%）→ 新 %.0f（%+.0f%%）" % [
			cid, era, base_atk, old_v, (old_v / base_atk - 1.0) * 100.0,
			new_v, (new_v / base_atk - 1.0) * 100.0])
	# B3 瞄准镜 true_damage 各时代
	var td: Array = []
	for era in range(4):
		var r: Dictionary = Registry.apply_with_level(
			{"true_damage": 0.0}, [{"id": "inf_07_optical_scope", "level": 1}], {"era": era})
		td.append(int(float(r["true_damage"])))
	print("  [inf_07 瞄准镜 true_damage Lv1] era0-3: %s（旧恒 8；era4 已不可装）" % str(td))
	# B4 复合装甲（pct 不变，仅确认）
	var r2: Dictionary = Registry.apply_with_level(
		{"defense_armor": 100}, [{"id": "arm_02_composite_armor", "level": 1}], {"era": 2})
	print("  [arm_02 复合装甲 @ 防甲100] → %.0f（旧同为 +30%%，值不变；era0-1 新增硬门不可装）" % float(r2["defense_armor"]))

# ── C. flat 时代缩放极端扫描（兵种适用 + 时代兼容过滤后的真实可装组合）──────────
func section_c_flat_extremes() -> void:
	print("\n── C. 攻击/HP 族 int flat 缩放极端（真实可装组合：era0 / era4）──")
	for host_era in [0, 4]:
		var worst: Array = []
		for entry in UCT.get_player_card_entries():
			if int(entry.get("era", -1)) != host_era:
				continue
			var cid: String = String(entry.get("card_id", ""))
			var card = DefaultCards.get_card_by_id(cid)
			if card == null:
				continue
			# 该卡真实可装的改造（兵种前缀 + 时代带）
			var mod_ids: Array = Registry.get_installable_mods_for_card(cid, host_era)
			for mod_id in mod_ids:
				var md: Dictionary = Registry.get_data(String(mod_id))
				var eff: Dictionary = md.get("effects", {})
				var ref_era: int = Registry.get_mod_reference_era(md)
				for key in eff.keys():
					if not Registry.ERA_SCALED_FLAT_KEYS.has(key):
						continue
					var val = eff[key]
					if not (val is int) or int(val) <= 0:
						continue
					var stat_field: String = "base_hp" if key == "max_hp" else key
					var gv = card.get(stat_field)
					if gv == null:
						continue
					var host_v: float = float(gv)
					if host_v <= 0.0:
						continue
					var factor: float = Registry._era_flat_factor(key, ref_era, host_era)
					var ratio: float = float(val) * factor / host_v
					worst.append({"mod": String(mod_id), "key": key, "raw": int(val),
						"host": cid, "host_v": host_v, "ratio": ratio})
		worst.sort_custom(func(a, b): return a.ratio > b.ratio)
		print("  [era%d 宿主] 缩放后相对加成 Top6（真实可装组合）：" % host_era)
		for w in worst.slice(0, 6):
			print("    %s %s +%d @%s(%.0f) = +%.0f%%%s" % [
				w.mod, w.key, w.raw, w.host, w.host_v, w.ratio * 100.0,
				"  ⚠超45%" if w.ratio > 0.45 else ""])

# ── D. 武器槽同步修复的实战幅度 ──────────────────────
func section_d_weapon_sync() -> void:
	print("\n── D. 武器槽同步修复（改造前实战=0 效果 → 现真实生效）──")
	var card = DefaultCards.get_card_by_id("ww1_arm_ft17").clone()
	# D1 攻击改造：enh_dmg_up Lv1/Lv3
	var base = UST.build_stats_from_card(card, 0)
	var w0: float = float(base.weapon_slots[1].damage)
	for lv in [1, 3]:
		var c2 = DefaultCards.get_card_by_id("ww1_arm_ft17").clone()
		c2.mods = [{"id": "enh_dmg_up", "level": lv, "enabled": true}]
		var s2 = UST.build_stats_from_card(c2, 0)
		var w: float = float(s2.weapon_slots[1].damage)
		print("  [ft17 对甲武器] enh_dmg_up Lv%d：旧实战 %.0f（改造无效）→ 新 %.0f（DPS %+.0f%%）" % [
			lv, w0, w, (w / w0 - 1.0) * 100.0])
	# D2 兵种固定机制（kind bonus 死代码修复）：装甲碾压 +20% 对轻
	var light_w0: float = float(base.weapon_slots[0].damage)
	print("  [ft17 对轻武器·装甲碾压+20%%] 旧实战 %.1f（机制死代码）→ 新 %.1f（%+.0f%%）" % [
		light_w0 / 1.2 if false else 61.0, light_w0, (light_w0 / 61.0 - 1.0) * 100.0])
	# D3 set 通道实战
	var c3 = DefaultCards.get_card_by_id("ww2_inf_bazooka").clone()
	c3.mods = [{"id": "inf_02_assault_rifle", "level": 1, "enabled": true}]
	var s3 = UST.build_stats_from_card(c3, 1)
	print("  [bazooka 对轻武器·换装] 旧实战 60.0（+8 flat 无效）→ 新 %.0f（set 90 落地）" % [
		float(s3.weapon_slots[0].damage)])
