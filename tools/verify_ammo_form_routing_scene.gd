extends Node
## v9.x 曲射炮兵弹药形态路由验证（场景模式——需 autoload 环境，card_resource.gd 引用 ModificationRegistry）
## 火箭→ROCKET(3) / 导弹→MISSILE(9) / 其余→炮弹 INDIRECT(1)；直射/空射单位不参与路由
## 用法：agent_tools run.scene_headless 或编辑器 F6；断言完成自动退出

const CardRes := preload("res://resources/card_resource.gd")

func _make(wt: int, light_name: String):
	var c = CardRes.new()
	c.weapon_type = wt
	c.attack_light = 10.0
	var names: Array[String] = [light_name, "", ""]
	c.weapon_names = names
	c._ensure_weapon_slots_initialized()
	return c

func _ready() -> void:
	var fails: Array = []

	# 1) 曲射 + 火箭名 → ROCKET(3)（低平弧+火箭弹贴图）
	var mlrs = _make(1, "227mm火箭炮")
	if int(mlrs.weapon_slots[0].weapon_type) != 3:
		fails.append("火箭→3 失败，实得 %d" % int(mlrs.weapon_slots[0].weapon_type))

	# 2) 曲射 + 导弹名 → MISSILE(9)（中弧+导弹贴图）
	var sam = _make(1, "防空导弹")
	if int(sam.weapon_slots[0].weapon_type) != 9:
		fails.append("导弹→9 失败，实得 %d" % int(sam.weapon_slots[0].weapon_type))

	# 3) 曲射 + 炮名 → 保持 INDIRECT(1)（高弧炮弹）
	var mortar = _make(1, "150mm榴弹炮")
	if int(mortar.weapon_slots[0].weapon_type) != 1:
		fails.append("炮弹应保持 1，实得 %d" % int(mortar.weapon_slots[0].weapon_type))

	# 4) 直射 + 反坦克导弹 → 保持 DIRECT(0)（ATGM 平射语义不受路由影响）
	var atgm = _make(0, "反坦克导弹")
	if int(atgm.weapon_slots[0].weapon_type) != 0:
		fails.append("直射反坦克导弹应保持 0，实得 %d" % int(atgm.weapon_slots[0].weapon_type))

	# 5) 直射 + 光束名 → SNIPER(6)（v9.4 原逻辑不回归）
	var beam = _make(0, "激光炮")
	if int(beam.weapon_slots[0].weapon_type) != 6:
		fails.append("直射光束→6 失败，实得 %d" % int(beam.weapon_slots[0].weapon_type))

	# 6) 曲射 + 光束名 → 6 优先于弹药形态（光束关键词在前，玩家侧既有次序）
	var laser_arty = _make(1, "激光炮")
	if int(laser_arty.weapon_slots[0].weapon_type) != 6:
		fails.append("曲射激光→6 失败，实得 %d" % int(laser_arty.weapon_slots[0].weapon_type))

	# 7) 霰弹精确匹配 → SHOTGUN(5)（精确表优先）
	var sg = _make(0, "霰弹枪")
	if int(sg.weapon_slots[0].weapon_type) != 5:
		fails.append("霰弹→5 失败，实得 %d" % int(sg.weapon_slots[0].weapon_type))

	# 8) 空射单位 + 导弹名 → 保持 AERIAL(2)（空射不参与弹药路由，低弧俯冲语义）
	var heli = _make(2, "地狱火导弹")
	if int(heli.weapon_slots[0].weapon_type) != 2:
		fails.append("空射导弹名应保持 2，实得 %d" % int(heli.weapon_slots[0].weapon_type))

	# 9) 等离子武器 → 光束 6（虚空领主"重型等离子加农炮"——含"等离子"不含"粒子"，v9.x 补关键词）
	var plasma = _make(0, "重型等离子加农炮")
	if int(plasma.weapon_slots[0].weapon_type) != 6:
		fails.append("等离子→6 失败，实得 %d" % int(plasma.weapon_slots[0].weapon_type))

	# 10) 精确 override：全装型机动舱对地槽"全装型导弹巢" → MISSILE(9)（与巨神主炮流区分）
	var pod = _make(0, "全装型导弹巢")
	if int(pod.weapon_slots[0].weapon_type) != 9:
		fails.append("导弹巢→9 失败，实得 %d" % int(pod.weapon_slots[0].weapon_type))

	# 11) 曲射平台 + 机枪名 → 直射曳光 0（雷霆守护者"雷霆机枪"点防不自抛物线）
	var pd_mg = _make(1, "雷霆机枪")
	if int(pd_mg.weapon_slots[0].weapon_type) != 0:
		fails.append("曲射机枪→0 失败，实得 %d" % int(pd_mg.weapon_slots[0].weapon_type))

	# 12) 曲射平台 + 近防炮名 → 直射曳光 0（风暴核心"25mm近防炮"）
	var ciws = _make(1, "25mm近防炮")
	if int(ciws.weapon_slots[0].weapon_type) != 0:
		fails.append("近防炮→0 失败，实得 %d" % int(ciws.weapon_slots[0].weapon_type))

	if fails.is_empty():
		print("[PASS] 弹药形态路由 12 项断言全部通过")
	else:
		for f in fails:
			push_error("[FAIL] " + f)
		print("[FAIL] %d 项未通过" % fails.size())
	# 附：攻击姿态参数表 + 试点攻击帧基础图路径（供 generate_attack_frames.py 使用）
	var APA := preload("res://scripts/battle/attack_pose_anim.gd")
	var p_light: Dictionary = APA._pose_params(0)
	var p_heavy: Dictionary = APA._pose_params(9)
	var p_arc: Dictionary = APA._pose_params(1)
	if float(p_light["lunge"]) != 14.0 or float(p_heavy["lunge"]) != -10.0 or not p_arc.has("lean_up"):
		print("[FAIL] 攻击姿态参数表异常: %s / %s / %s" % [str(p_light), str(p_heavy), str(p_arc)])
	else:
		print("[PASS] 攻击姿态参数表（轻武器前倾14/重型后坐-10/曲射上扬）")
	if not APA.has_attack_frames("ww1_inf_mp18"):
		print("[FAIL] ww1_inf_mp18 攻击帧未检测到")
	else:
		var _af: Array = APA._load_frames("ww1_inf_mp18")
		if _af.is_empty() or _af[0] == null:
			print("[FAIL] ww1_inf_mp18 攻击帧检测到但加载失败（缺 .import？）")
		else:
			print("[PASS] ww1_inf_mp18 攻击帧已生效（检测+ResourceLoader 加载 %d 帧 512x%d）" % [_af.size(), (_af[0].get_height() if _af[0] else 0)])
	var Manifest := preload("res://data/enemy_unit_manifest.gd")
	for uid in ["ww1_inf_mp18", "ww1_inf_rifle", "ww1_sup_mg_nest", "ww1_arty_mortar", "ww1_inf_storm_e", "ww1_inf_enfield", "ww1_sup_vickers", "ww1_inf_mp18_x", "ww2_inf_thompson", "ww2_inf_garand", "ww2_sup_mg42", "ww2_inf_para_e", "ww2_arm_garand_para", "ww2_inf_kar98k", "cold_inf_m60", "cold_inf_ak", "cold_inf_spetsnaz_e", "cold_inf_metis", "mod_inf_marine", "mod_inf_delta_e", "mod_sup_m4_carbine", "mod_arm_himars", "mod_sup_growler", "fut_inf_cyborg", "fut_inf_spectre_e", "fut_inf_neural", "fut_arm_hk07", "fut_inf_x9", "fut_inf_c96", "fut_arty_ssc1", "drop_smg_mk2", "drop_phase_lance", "drop_railgun", "drop_thunder_field"]:
		print("[PATH] %s -> %s" % [uid, Manifest.get_unit_icon_path_for_archetype(uid, false)])
	get_tree().quit(0 if fails.is_empty() else 1)
