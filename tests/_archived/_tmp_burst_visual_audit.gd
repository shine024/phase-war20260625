extends SceneTree
## 临时审计（只读）：枚举玩家卡池中"一次攻击=1次伤害结算、N 发视觉弹"的 (卡,槽)。
## 复刻 construct_unit_ai.do_attack_with_damage 的弹道路由 + v20.18 点射判定：
##   曲射族(1/2/3/7/9) → batch（无点射）
##   DIRECT(0) 且射速>2 且非坦克炮 → batch（无点射）
##   其余 → 单发 bullet 路径；玩家侧 wt==0 时 burst_count_for(flavor)：MG=3 RIFLE=2 其余=1
##   （v38.3：GENERIC 兜底已撤出点射；线膛炮已归 TANK_GUN）
## 伤害只在首波结算（construct_unit_ai.gd:794 _is_visual_round），后续波 bullet.visual_only=true。

const DefaultCards = preload("res://data/default_cards.gd")
const DWF = preload("res://data/direct_weapon_flavor.gd")
const WPV = preload("res://scripts/weapon_projectile_vfx.gd")
const GC = preload("res://resources/game_constants.gd")

func _init() -> void:
	var cards: Array = DefaultCards.create_all()
	var multi_rows: Array[String] = []
	var single_rows: Array[String] = []
	var n_cards := 0
	for c in cards:
		if not (c is CardResource):
			continue
		n_cards += 1
		c._ensure_weapon_slots_initialized()
		var speeds: Array = [c.attack_light_speed, c.attack_armor_speed, c.attack_air_speed]
		var slot_names: Array[String] = ["轻装", "装甲", "对空"]
		for i in 3:
			var w = c.weapon_slots[i]
			if w == null or not w.enabled:
				continue
			var wt: int = int(w.weapon_type)
			var nm: String = String(w.display_name)
			var spd: float = float(speeds[i])
			var flv: int = DWF.classify(nm, wt)
			var path := "single"
			var burst_n := 1
			if GC.is_indirect_weapon_type(wt):
				path = "batch-indirect"
			elif wt == 0 and spd > 2.0 and flv != DWF.Flavor.TANK_GUN:
				path = "batch-direct"
			else:
				if wt == 0:
					burst_n = WPV.burst_count_for(flv)
			var row := "%-22s %-14s %s槽 武器[%s] wt=%d 射速%.2f flavor=%d -> %s 视觉%d发/伤害1次" % [
				c.card_id, c.display_name, slot_names[i], nm, wt, spd, flv, path, burst_n]
			if burst_n > 1:
				multi_rows.append(row)
			elif path == "single":
				single_rows.append(row)
	print("=== 玩家卡池 %d 张 ===" % n_cards)
	print("=== [症状命中] 单发路径视觉多发（伤害1次/视觉N发）共 %d 项 ===" % multi_rows.size())
	for r in multi_rows:
		print(r)
	print("")
	print("=== [对照] 单发路径但视觉单发 共 %d 项 ===" % single_rows.size())
	for r in single_rows:
		print(r)
	quit()
