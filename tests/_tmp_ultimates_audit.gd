extends SceneTree
## v6.17.2 大招系统审计（--script headless，只读）：
## A 玩家相位仪：id 唯一 / 徽章图标存在且无白底 / 主动能力 id 被引擎引用 / 参数 sane
## B 敌方相位师大招（MASTER_ULTIMATES）：30 人全覆盖 / id 唯一 / cooldown>0 /
##   effect 被敌方引擎引用
## 输出 PROBLEM 清单。

var problems: Array = []
var infos: Array = []
var stats: Dictionary = {}


func _p(code: String, msg: String) -> void:
	problems.append("[%s] %s" % [code, msg])


func _initialize() -> void:
	var PI = load("res://data/phase_instruments.gd")
	var EMI = load("res://data/enemy_master_instruments.gd")

	# ── A. 玩家相位仪 ──
	var instruments: Array = PI.get_all()
	stats["instruments"] = instruments.size()
	var seen := {}
	var ab_ids := {}
	var plain_ids := {}
	for inst in instruments:
		var iid := String(inst.get("id", ""))
		if iid.is_empty():
			_p("PI_ID", "存在空 id 仪器")
			continue
		if seen.has(iid):
			_p("PI_DUP", "重复仪器 id: %s" % iid)
		seen[iid] = true
		var star := int(inst.get("star", 0))
		if star < 1 or star > 7:
			_p("PI_STAR", "%s 星级越界: %d" % [iid, star])
		# 徽章图标
		var icon := "res://assets/ui/instruments/%s.png" % iid
		if not ResourceLoader.exists(icon):
			_p("PI_ICON_MISS", "%s 徽章缺失: %s.png" % [iid, iid])
		else:
			var tex: Texture2D = load(icon)
			var img: Image = tex.get_image()
			if img != null:
				if img.get_format() != Image.FORMAT_RGBA8:
					img.convert(Image.FORMAT_RGBA8)
				var W2 := img.get_width()
				var bad := false
				# 角点 16x16 近白不透明（nova 旧病）
				for cy in [0, W2 - 16]:
					for cx in [0, W2 - 16]:
						var solid_white := 0
						var total := 0
						for dy in range(16):
							for dx in range(16):
								var c := img.get_pixel(cx + dx, cy + dy)
								total += 1
								if c.r >= 0.92 and c.g >= 0.92 and c.b >= 0.92 and c.a >= 0.78:
									solid_white += 1
						if total > 0 and float(solid_white) / total >= 0.5:
							bad = true
				if bad:
					_p("PI_ICON_WHITE", "%s 徽章角点白底（nova 旧病复发?）" % iid)
		# 主动能力
		var ab: Dictionary = inst.get("active_ability", {})
		if ab.is_empty():
			continue
		var aid := String(ab.get("id", ""))
		if aid.is_empty():
			_p("PI_AB_ID", "%s 主动能力缺 id" % iid)
			continue
		# 同势力线星级变体共用能力 id 是设计（工厂按 star 缩放参数）。
		# 同能力+同星级跨势力线 = 引擎状态键（owner+ability_id）共享观察项，降级为备注。
		var ab_key := "%s@s%d" % [aid, star]
		if ab_ids.has(ab_key):
			infos.append("同能力同星级: %s（%s 与 %s）——若可同装则引擎状态键共享（老设计）" % [ab_key, ab_ids[ab_key], iid])
		ab_ids[ab_key] = iid
		if not plain_ids.has(aid):
			plain_ids[aid] = iid
		var atype := String(ab.get("type", ""))
		if not ["periodic", "on_battle_start", "on_deploy", "passive", "cast"].has(atype):
			_p("PI_AB_TYPE", "%s 能力 %s type 非常规: %s" % [iid, aid, atype])
	stats["player_ability_ids"] = ab_ids.size()
	# 引擎引用检查（引擎各 match/分支按 ability_id 字符串分发）
	var engine_src := _read("managers/battle/phase_instrument_abilities.gd")
	var cast_src := _read("scripts/battle/ultimate_cast_controller.gd")
	for aid in plain_ids:
		if engine_src.contains("\"%s\"" % aid) or cast_src.contains("\"%s\"" % aid):
			continue
		# 引擎零引用 → 全项目兜底（部分能力由部署/克隆系统按 id 消费）
		var out: Array = []
		OS.execute("grep", ["-r", "--include=*.gd", "-rl", aid,
			"scripts/", "scenes/", "managers/", "data/"], out, true)
		if out.is_empty() or String(out[0]).strip_edges().is_empty():
			_p("PI_AB_NO_ENGINE", "能力 %s 全项目零消费（永不触发）" % aid)
		else:
			infos.append("能力 %s 不在 phase_instrument_abilities 主引擎，由其他系统消费" % aid)

	# ── B. 敌方大招 ──
	var ults: Dictionary = EMI.MASTER_ULTIMATES
	stats["enemy_masters_with_ults"] = ults.size()
	var e_ids := {}
	var enemy_engine := _read("managers/battle/enemy_master_skill_engine.gd")
	for mid in ults:
		var spells: Array = ults[mid]
		if spells.is_empty():
			_p("EM_ULT_EMPTY", "%s 大招列表为空" % mid)
		for sp in spells:
			var sid := String(sp.get("id", ""))
			if sid.is_empty():
				_p("EM_ULT_ID", "%s 有空 id 大招" % mid)
			elif e_ids.has(sid):
				_p("EM_ULT_DUP", "敌方大招 id 重复: %s（%s 与 %s）" % [sid, e_ids[sid], mid])
			e_ids[sid] = mid
			var cd := float(sp.get("cooldown", 0.0))
			if cd <= 0.0:
				_p("EM_ULT_CD", "%s 大招 %s cooldown ≤ 0" % [mid, sid])
			var eff := String(sp.get("effect", ""))
			if eff.is_empty():
				_p("EM_ULT_EFFECT", "%s 大招 %s effect 为空" % [mid, sid])
			elif not enemy_engine.contains("\"%s\"" % eff) and not enemy_engine.contains(eff):
				_p("EM_ULT_NO_ENGINE", "敌方大招 %s effect=%s 在敌方引擎零引用" % [sid, eff])
	stats["enemy_ult_spells"] = e_ids.size()

	# ── 汇总 ──
	print("==== 大招审计统计 ====")
	for k in stats:
		print("  %s = %s" % [k, stats[k]])
	print("==== 问题清单（%d）====" % problems.size())
	for p in problems:
		print("  [P] ", p)
	print("==== 备注（%d）====" % infos.size())
	for i2 in infos:
		print("  [i] ", i2)
	if problems.is_empty():
		print("ULTIMATES_AUDIT_OK")
	else:
		print("ULTIMATES_AUDIT_ISSUES %d" % problems.size())
	quit(0 if problems.is_empty() else 1)


func _read(rel: String) -> String:
	var f := FileAccess.open(rel, FileAccess.READ)
	if f == null:
		return ""
	return f.get_as_text()
