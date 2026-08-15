extends Node2D

## ============================================================
## VFX 真实度诊断 - 干净展示场景 (Phase 1)
## 逐个触发战斗视觉特效(命中/特殊伤害/核爆/技能/炮口火),峰值帧自截 PNG,
## 写 user://vfx_shots/manifest.json,播完自动退出。
## 纯 VfxImpactFactory/WeaponProjectileVfx 静态调用,0 autoload 依赖。
## 用法:经 run_scene_headless(resolution=1280x720 + 一个占位 screenshot 强制窗口化渲染器)驱动。
## ============================================================

const VfxFactory := preload("res://scripts/battle/vfx_impact_factory.gd")
const ProjVfx := preload("res://scripts/weapon_projectile_vfx.gd")

const OUTPUT_DIR := "user://vfx_shots/"
const MANIFEST_PATH := "user://vfx_shots/manifest.json"
const SPAN_DEFAULT := 65      # 两特效间隔帧(让粒子消散 ~1.1s)
const SPAN_NUCLEAR := 95      # 核爆更长(蘑菇云帧动画 ~1.1s + 焦痕)

const TEX_SHIELD := preload("res://assets/effects/spell_burst/player_shield.png")
const TEX_RAGE := preload("res://assets/effects/spell_burst/player_rage.png")
const TEX_ULT_NUKE := preload("res://assets/effects/ultimate_projectiles/ult_nuke_player.png")
const TEX_INFERNO := preload("res://assets/effects/spell_burst/inferno_hell.png")
# v11 上下文层：VFX 不再画在虚空灰底上,而是叠在真实战场背景 + 敌方装甲目标之上。
# 这是视觉评分的最大杠杆——模型从"廉价弹窗"读成"一次真实命中"。
const TEX_BG := preload("res://assets/backgrounds/bg_level_05.png")            # 现代/近未来战场底
const TEX_TARGET := preload("res://assets/card_icons/enemy/mod_arm_himars.png") # 命中点:敌方装甲
const TEX_SHADOW := preload("res://assets/effects/particle_textures/smoke_generic.png") # 复用软烟贴图做接地阴影
const TARGET_SCALE := 0.58                                                       # 512px 贴图 → 约 300px 战场单位(够大让火花溅在车体上而非漂浮外侧)
const TEX_INF := preload("res://assets/card_icons/enemy/cold_inf_metis.png")    # v12d: 步兵参照单位(大小对比)
const INF_SCALE := 0.26                                                          # 步兵比装甲小很多(0.26 vs 0.58),让特效尺寸有参照
const TEX_SHIELD_BUBBLE := preload("res://assets/effects/spell_burst/player_fortress.png") # v12e: 护盾罩贴图(单位有盾时常驻覆盖)
const TEX_AIR := preload("res://assets/card_icons/player/fe_helix_phantom.png")            # v12e: 空中单位(演示整球罩 vs 地面贴地罩)
# v13 全量覆盖:相位仪大招 / boss 技能电影化 / 状态 / 弹道
const PIA := preload("res://managers/battle/phase_instrument_abilities.gd")
const DotVfx := preload("res://scripts/battle/dot_vfx_manager.gd")
const TEX_BARRAGE := preload("res://assets/effects/spell_burst/player_barrage.png")
const TEX_APOC_METEOR := preload("res://assets/effects/spell_burst/apocalypse_meteor.png")
const TEX_APOC_VOID := preload("res://assets/effects/spell_burst/apocalypse_void.png")
const TEX_CHAIN := preload("res://assets/effects/spell_burst/chain_lightning.png")
const TEX_DARK := preload("res://assets/effects/spell_burst/debuff_dark.png")
const TEX_PORTAL := preload("res://assets/effects/spell_burst/summon_portal.png")
const TEX_ULT_SPEAR := preload("res://assets/effects/ultimate_projectiles/ult_divine_spear.png")
const TEX_ULT_INFERNO := preload("res://assets/effects/ultimate_projectiles/ult_inferno_bomb.png")
const TEX_ULT_METEOR := preload("res://assets/effects/ultimate_projectiles/ult_meteor.png")
const TEX_ULT_ORBITAL := preload("res://assets/effects/ultimate_projectiles/ult_orbital.png")

var _bf: Node2D
var _frame: int = 0
var _entries: Array = []          # 播放列表(每条含 id/category/desc/era/ref/span/peaks/trigger)
var _events: Array = []           # 排序后 {frame,kind,idx,peak?}
var _ev_ptr: int = 0
var _manifest: Array = []         # 与 _entries 对齐的输出清单
var _capture_count: int = 0
var _finished: bool = false

func _ready() -> void:
	var vp := get_viewport_rect().size
	var center := vp * 0.5
	_bf = $Battlefield
	_bf.position = center
	# 背景:真实战场贴图 cover 铺满 + 轻微暗化(压暗让 VFX 高亮更突出,读起来更像"命中")
	var bg_layer: CanvasLayer = $Bg
	var bg_tex: TextureRect = TextureRect.new()
	bg_tex.name = "BgTex"
	bg_tex.texture = TEX_BG
	bg_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg_tex.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg_layer.add_child(bg_tex)
	var dim: ColorRect = ColorRect.new()
	dim.name = "BgDim"
	dim.color = Color(0.08, 0.08, 0.10, 0.32)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg_layer.add_child(dim)
	# 目标:敌方装甲 + 接地阴影。先于 VFX 加入 Battlefield → 渲染在下层(VFX 叠在其上)
	var shadow: Sprite2D = Sprite2D.new()
	shadow.name = "TargetShadow"
	shadow.texture = TEX_SHADOW
	shadow.modulate = Color(0.0, 0.0, 0.0, 0.42)
	shadow.scale = Vector2(3.6, 1.15)
	shadow.position = Vector2(0, 78)
	_bf.add_child(shadow)
	var target: Sprite2D = Sprite2D.new()
	target.name = "Target"
	target.texture = TEX_TARGET
	target.scale = Vector2(TARGET_SCALE, TARGET_SCALE)
	target.position = Vector2(0, -6)   # 微抬让阴影落在脚下
	_bf.add_child(target)
	# v12d: 大小对比——装甲右下方放一个步兵参照(0.26 缩放,远小于装甲 0.58),让特效尺寸有参照。
	var inf_shadow: Sprite2D = Sprite2D.new()
	inf_shadow.name = "InfShadow"
	inf_shadow.texture = TEX_SHADOW
	inf_shadow.modulate = Color(0.0, 0.0, 0.0, 0.38)
	inf_shadow.scale = Vector2(1.6, 0.5)
	inf_shadow.position = Vector2(215, 96)
	_bf.add_child(inf_shadow)
	var inf: Sprite2D = Sprite2D.new()
	inf.name = "InfantryRef"
	inf.texture = TEX_INF
	inf.scale = Vector2(INF_SCALE, INF_SCALE)
	inf.position = Vector2(215, 76)   # 装甲右下,远离主特效区不干扰
	_bf.add_child(inf)
	# v12d: 方向指示——左侧画一条淡来弹轨迹线 + 射手点,标明"攻击从左方来"。
	# (签名特效现已按来弹方向定向:轨道炮贯穿左→右、激光/欧米茄来弹光束从左射来)
	var tracer: Line2D = Line2D.new()
	tracer.name = "IncomingTracer"
	tracer.width = 2.0
	tracer.default_color = Color(1.0, 0.95, 0.5, 0.28)  # 淡黄虚意,不抢特效
	tracer.joint_mode = Line2D.LINE_JOINT_ROUND
	tracer.end_cap_mode = Line2D.LINE_CAP_ROUND
	tracer.add_point(Vector2(-340, 0))
	tracer.add_point(Vector2(-70, 0))   # 到目标左侧
	_bf.add_child(tracer)
	var shooter_dot: Sprite2D = Sprite2D.new()  # 射手标记(小亮点)
	shooter_dot.name = "ShooterMark"
	shooter_dot.texture = TEX_SHADOW
	shooter_dot.modulate = Color(1.0, 0.9, 0.4, 0.5)
	shooter_dot.scale = Vector2(0.6, 0.6)
	shooter_dot.position = Vector2(-345, 0)
	_bf.add_child(shooter_dot)
	# 输出目录(新建 + 清旧)
	DirAccess.make_dir_recursive_absolute(OUTPUT_DIR)
	_clear_dir(OUTPUT_DIR)
	# 建播放列表
	_build_entries()
	# 累加起播帧,生成 trigger/capture 事件 + manifest 骨架
	var start_f: int = 6   # 让前几帧渲染稳定再开拍
	for i in _entries.size():
		var e: Dictionary = _entries[i]
		var id: String = e["id"]
		var peaks: Array = e["peaks"]
		_events.append({"frame": start_f, "kind": "trigger", "idx": i})
		var caps: Array = []
		for pi in peaks.size():
			var f: int = start_f + int(peaks[pi])
			_events.append({"frame": f, "kind": "capture", "idx": i, "peak": pi})
			caps.append({"peak_index": pi, "file": "%s_%d.png" % [id, pi], "frame": f})
		_manifest.append({
			"id": id,
			"category": e["category"],
			"description": e["desc"],
			"era": e["era"],
			"ref_weapon": e["ref"],
			"captures": caps,
		})
		start_f += int(e["span"])
	_events.sort_custom(func(a, b): return int(a["frame"]) < int(b["frame"]))
	print("[VfxShowcase] entries=%d events=%d total_frames~%d (~%.1fs)" % [_entries.size(), _events.size(), start_f, start_f / 60.0])

func _process(_delta: float) -> void:
	if _finished:
		return
	_frame += 1
	while _ev_ptr < _events.size() and int(_events[_ev_ptr]["frame"]) <= _frame:
		_fire_event(_events[_ev_ptr])
		_ev_ptr += 1
	if _ev_ptr >= _events.size() and not _finished:
		_finish()

func _fire_event(ev: Dictionary) -> void:
	var idx: int = ev["idx"]
	if ev["kind"] == "trigger":
		# 清屏:移除上一特效的非池化残留(池化节点自带 tween 自回收)
		get_tree().call_group("battle_vfx", "queue_free")
		var cb: Callable = _entries[idx]["trigger"]
		if cb.is_valid():
			cb.call()
	else: # capture
		var peak: int = ev["peak"]
		var path: String = OUTPUT_DIR + "%s_%d.png" % [_entries[idx]["id"], peak]
		var img := get_viewport().get_texture().get_image()
		if img != null:
			var err := img.save_png(path)
			if err == OK:
				_capture_count += 1
			else:
				push_warning("[VfxShowcase] save_png err=%d path=%s" % [err, path])
		else:
			push_warning("[VfxShowcase] get_image() null at frame %d" % _frame)

func _finish() -> void:
	_finished = true
	var f := FileAccess.open(MANIFEST_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify({"shots": _manifest, "frame_rate": 60}, "\t"))
		f.close()
		print("[VfxShowcase] manifest=%s captures=%d" % [MANIFEST_PATH, _capture_count])
	else:
		push_error("[VfxShowcase] cannot write manifest!")
	print("[VfxShowcase] done, quitting.")
	get_tree().quit()

func _clear_dir(dir_path: String) -> void:
	var d := DirAccess.open(dir_path)
	if d == null:
		return
	d.list_dir_begin()
	var fname := d.get_next()
	while fname != "":
		if not d.current_is_dir():
			d.remove(fname)
		fname = d.get_next()
	d.list_dir_end()

# ---- 核爆贴图包(镜像 phase_instrument_abilities._load_nuke_texture_pack L505) ----
func _load_nuke_texture_pack() -> Dictionary:
	var pack: Dictionary = {}
	var dir := "res://assets/effects/nuclear/"
	for key in ["fireball", "shockwave", "burn", "mushroom"]:
		var path: String = dir + "nuke_" + str(key) + ".png"
		if ResourceLoader.exists(path):
			pack[key] = load(path)
	var frames: Array = []
	for i in 9:
		var fpath := dir + "nuke_mushroom_f" + str(i) + ".png"
		if ResourceLoader.exists(fpath):
			var tex = load(fpath)
			if tex != null:
				frames.append(tex)
			else:
				frames.clear()
				break
		else:
			frames.clear()
			break
	if not frames.is_empty():
		pack["mushroom_frames"] = frames
	return pack

# ============================================================
# 播放列表
# ============================================================
func _build_entries() -> void:
	# --- 命中特效 ×12 武器类型 ---
	var wt_names := {0:"冲锋枪SMG",1:"步枪RIFLE",2:"机枪MG",3:"火箭弹ROCKET",4:"手枪PISTOL",5:"霰弹SHOTGUN",6:"狙击SNIPER",7:"高射炮FLAK",8:"激光LASER",9:"导弹MISSILE",10:"欧米茄粒子炮OMEGA",11:"电磁轨道炮RAIL"}
	var wt_desc := {0:"9mm冲锋枪子弹",1:"7.62mm步枪弹",2:"7.62mm机枪弹",3:"RPG破甲火箭弹",4:"9mm手枪弹",5:"12号霰弹",6:"12.7mm大口径狙击弹",7:"40mm高射炮榴弹",8:"战术激光束",9:"反坦克导弹",10:"欧米茄粒子炮",11:"电磁轨道炮动能弹"}
	for wt in range(12):
		# v11: 直射系(SMG/RIFLE/MG)必须用 weapon_type=DIRECT(0)+weapon_name 走正确的步枪/机枪
		# 亚类配方,否则 wt1/wt2 会撞到新枚举 INDIRECT(1)/AERIAL(2) 的曲射扬尘/导弹大爆炸配方。
		var m: Array = IMPACT_WT_MAP[wt]
		# v11c: 动能火花提速后散得更开,峰值帧 8(~0.13s)——火花已散开(独立不融合)且因延长
		# 的亮黄梯度仍处亮黄阶段,弹痕锚点此时也可见(blob 已散去)。重型/能量发育慢用 12。
		# v12b: 轨道炮(wt11)签名穿透——全亮保持延到 0.10s + spall 飞出需时间,峰值帧从 3 改 8
		# (0.13s):光迹仍亮(w~7) + 出口碎片已飞出 65px + 冲击环展开,三锚同时可见(原 frame3
		# 只有光迹像激光,无 spall = 读不出"穿透")。
		var peak: int
		if wt == 11:
			peak = 8
		elif wt == 8:
			peak = 8  # v12d: 激光签名灼烧——紧焦斑冷却到光束色 + 焦痕扩到超光斑 + 熔融火星上飞
		elif wt == 10:
			peak = 7  # v12d: 欧米茄径向放电——大核爆开+星芒射线+外向电火花同时可见
		elif wt in [0, 1, 2, 4, 5, 6]:
			peak = 8
		else:
			peak = 12
		var peaks_arr: Array = [peak]
		_entries.append({
			"id": "impact_wt%d" % wt,
			"category": "命中特效",
			"desc": wt_desc[wt] + " 命中金属装甲目标产生的火花/冲击",
			"era": "现代",
			"ref": wt_names[wt],
			"span": SPAN_DEFAULT,
			"peaks": peaks_arr,
			"trigger": _trig_impact(int(m[0]), str(m[1])),
		})
	# --- 威力档位变体(wt=3 火箭, LIGHT/MEDIUM/HEAVY) ---
	_entries.append({"id":"tier_wt3_light","category":"威力档位","desc":"火箭弹命中 轻威力档(纯粒子无爆炸半径)","era":"现代","ref":"ROCKET power_tier LIGHT","span":SPAN_DEFAULT,"peaks":[12],"trigger":_trig_impact_tier(3,0)})
	_entries.append({"id":"tier_wt3_medium","category":"威力档位","desc":"火箭弹命中 中威力档(96px帧动画火球)","era":"现代","ref":"ROCKET power_tier MEDIUM","span":SPAN_DEFAULT,"peaks":[18],"trigger":_trig_impact_tier(3,1)})
	_entries.append({"id":"tier_wt3_heavy","category":"威力档位","desc":"火箭弹命中 重威力档(160px帧动画+1.4x缩放)","era":"现代","ref":"ROCKET power_tier HEAVY","span":SPAN_DEFAULT,"peaks":[22],"trigger":_trig_impact_tier(3,2)})
	# --- 特殊伤害 ---
	_entries.append({"id":"crit_aura","category":"特殊伤害","desc":"暴击命中 金色脉动光环+辐射火花","era":"通用","ref":"CRITICAL HIT","span":SPAN_DEFAULT,"peaks":[8],"trigger":_trig_crit()})
	_entries.append({"id":"pierce_beam","category":"特殊伤害","desc":"穿甲增强 紫色穿透光线(贯穿多个目标)","era":"通用","ref":"PIERCE enhanced","span":SPAN_DEFAULT,"peaks":[1],"trigger":_trig_pierce()})
	_entries.append({"id":"shockwave","category":"特殊伤害","desc":"溅射冲击波 橙色地面扩散环","era":"通用","ref":"SHOCKWAVE r80","span":SPAN_DEFAULT,"peaks":[10],"trigger":_trig_shock()})
	_entries.append({"id":"lightning_arc","category":"特殊伤害","desc":"闪电链 锯齿电弧跨越双目标","era":"能量","ref":"LIGHTNING ARC","span":SPAN_DEFAULT,"peaks":[3],"trigger":_trig_lightning()})
	_entries.append({"id":"laser_beam","category":"特殊伤害","desc":"激光命中 青蓝色光束余晖","era":"近未来","ref":"LASER BEAM","span":SPAN_DEFAULT,"peaks":[3],"trigger":_trig_laser()})
	# v12e: 护盾罩预览——player_fortress 贴图叠在单位上(shield>0 常驻),比卡图大一圈,步兵/装甲自动缩放
	_entries.append({"id":"shield_bubble","category":"护盾状态","desc":"单位有能量盾时常驻护盾罩(贴图叠卡图上,比卡图大一圈;步兵小装甲大自动缩放)","era":"近未来","ref":"SHIELD BUBBLE","span":SPAN_DEFAULT,"peaks":[4],"trigger":_trig_shield_bubble()})
	# --- 核爆(双帧:火球+冲击波 / 蘑菇云) ---
	_entries.append({"id":"nuclear_explosion","category":"核爆","desc":"战术核武器地面爆炸(火球+双冲击波+蘑菇云帧动画+地面焦痕)","era":"近未来","ref":"NUCLEAR size1.0","span":SPAN_NUCLEAR,"peaks":[25,45],"trigger":_trig_nuclear()})
	# --- 技能演出 ---
	_entries.append({"id":"skill_shield_dome","category":"技能演出","desc":"巨型能量罩 蓝色护盾爆发术","era":"近未来","ref":"MEGA SHIELD","span":SPAN_DEFAULT,"peaks":[24],"trigger":_trig_spell(TEX_SHIELD, Color(0.3,0.7,1.0,1.0))})
	_entries.append({"id":"skill_rage_aura","category":"技能演出","desc":"狂暴激涌 金红色光环术","era":"通用","ref":"RAGE BUFF","span":SPAN_DEFAULT,"peaks":[22],"trigger":_trig_spell(TEX_RAGE, Color(1.0,0.4,0.2,1.0))})
	_entries.append({"id":"skill_inferno","category":"技能演出","desc":"地狱火术 橙红大招命中爆裂","era":"能量","ref":"INFERNO HELL","span":SPAN_DEFAULT,"peaks":[22],"trigger":_trig_spell(TEX_INFERNO, Color(1.0,0.5,0.1,1.0))})
	_entries.append({"id":"skill_summon_portal","category":"技能演出","desc":"幻影克隆召唤 青色螺旋传送门","era":"近未来","ref":"SUMMON PORTAL","span":SPAN_DEFAULT,"peaks":[12],"trigger":_trig_portal()})
	_entries.append({"id":"skill_energy_pillar","category":"技能演出","desc":"从天而降能量光柱","era":"能量","ref":"ENERGY PILLAR","span":SPAN_DEFAULT,"peaks":[6],"trigger":_trig_pillar()})
	_entries.append({"id":"skill_ult_projectile","category":"技能演出","desc":"大招核弹飞行体(抛物线弹道+橙黄拖尾)","era":"近未来","ref":"ULTIMATE NUKE","span":SPAN_DEFAULT,"peaks":[12],"trigger":_trig_ult()})
	# --- 炮口火 ---
	_entries.append({"id":"muzzle_light","category":"炮口火","desc":"轻武器枪口火焰(冲锋枪,短促轻焰)","era":"现代","ref":"MUZZLE wt0","span":SPAN_DEFAULT,"peaks":[4],"trigger":_trig_muzzle(0)})
	_entries.append({"id":"muzzle_rocket","category":"炮口火","desc":"火箭筒枪口火焰(重型尾焰)","era":"现代","ref":"MUZZLE wt3","span":SPAN_DEFAULT,"peaks":[4],"trigger":_trig_muzzle(3)})
	_entries.append({"id":"muzzle_missile","category":"炮口火","desc":"导弹发射口火焰(重型发射烟)","era":"近未来","ref":"MUZZLE wt9","span":SPAN_DEFAULT,"peaks":[4],"trigger":_trig_muzzle(9)})
	# --- v13 全量覆盖:相位仪大招 ---
	_entries.append({"id":"pi_artillery_barrage","category":"相位仪大招","desc":"炮击弹幕(冲击波100+火箭命中+200px弹幕爆裂,真实生产参数)","era":"现代","ref":"ARTILLERY BARRAGE","span":SPAN_DEFAULT,"peaks":[14],"trigger":_trig_pi_barrage()})
	_entries.append({"id":"pi_nuclear_bombardment","category":"相位仪大招","desc":"核子轰炸完整序列(导弹arc飞行→核爆蘑菇云0.6)","era":"近未来","ref":"NUCLEAR BOMBARDMENT","span":150,"peaks":[18,55,90],"trigger":_trig_pi_nuclear()})
	_entries.append({"id":"pi_nano_swarm","category":"相位仪大招","desc":"纳米虫群降临(owner配色虫群云覆盖战场)","era":"近未来","ref":"NANO SWARM","span":SPAN_DEFAULT,"peaks":[20],"trigger":_trig_pi_nano()})
	_entries.append({"id":"pi_mega_shield","category":"相位仪大招","desc":"巨型能量罩(260px/1.2s 真实参数,全队护盾)","era":"近未来","ref":"MEGA SHIELD 260","span":SPAN_DEFAULT,"peaks":[24],"trigger":_trig_spell(TEX_SHIELD, Color(0.3,0.7,1.0,1.0))})
	# --- v13 全量覆盖:相位师(boss)技能电影化 ---
	_entries.append({"id":"boss_apocalypse","category":"boss技能演出","desc":"天降毁灭(陨石vertical飞行→360px毁灭爆裂)","era":"近未来","ref":"APOCALYPSE","span":90,"peaks":[14,40],"trigger":_trig_boss("apocalypse")})
	_entries.append({"id":"boss_inferno","category":"boss技能演出","desc":"地狱火(燃烧弹dive俯冲→340px地狱火+次级150px溅射)","era":"能量","ref":"HELL INFERNO","span":90,"peaks":[12,38],"trigger":_trig_boss("inferno")})
	_entries.append({"id":"boss_chain","category":"boss技能演出","desc":"连锁闪电(300px闪电核心+双跳锯齿电弧)","era":"能量","ref":"TESLA CHAIN","span":SPAN_DEFAULT,"peaks":[10],"trigger":_trig_boss("chain")})
	_entries.append({"id":"boss_divine_spear","category":"boss技能演出","desc":"神圣之矛(vertical天降→增强穿透光束)","era":"能量","ref":"DIVINE SPEAR","span":80,"peaks":[12,34],"trigger":_trig_boss("spear")})
	_entries.append({"id":"boss_summon","category":"boss技能演出","desc":"幻影召唤(280px传送门爆裂+三层螺旋门环)","era":"近未来","ref":"SUMMON CLONE","span":SPAN_DEFAULT,"peaks":[20],"trigger":_trig_boss("summon")})
	_entries.append({"id":"boss_debuff_dark","category":"boss技能演出","desc":"暗蚀debuff(380px暗紫蚀刻,大尺度)","era":"虚空","ref":"DARK DEBUFF","span":SPAN_DEFAULT,"peaks":[26],"trigger":_trig_boss("dark")})
	_entries.append({"id":"boss_void_orbital","category":"boss技能演出","desc":"虚空轨道炮(orbital弹vertical→apocalypse_void 380px)","era":"虚空","ref":"VOID ORBITAL","span":90,"peaks":[14,40],"trigger":_trig_boss("orbital")})
	# --- v13 全量覆盖:状态附加 ---
	_entries.append({"id":"dot_burn","category":"状态附加","desc":"燃烧dot(单位挂火圈+动态火焰余烬)","era":"通用","ref":"DOT BURN","span":SPAN_DEFAULT,"peaks":[12],"trigger":_trig_dot("burn")})
	_entries.append({"id":"dot_chem","category":"状态附加","desc":"化学毒雾dot(绿色毒雾环绕)","era":"通用","ref":"DOT CHEM","span":SPAN_DEFAULT,"peaks":[12],"trigger":_trig_dot("chem")})
	_entries.append({"id":"dot_emp","category":"状态附加","desc":"EMP dot(蓝色电弧麻痹环)","era":"近未来","ref":"DOT EMP","span":SPAN_DEFAULT,"peaks":[12],"trigger":_trig_dot("emp")})
	_entries.append({"id":"dot_nano","category":"状态附加","desc":"纳米侵蚀dot(青色纳米粒环绕)","era":"近未来","ref":"DOT NANO","span":SPAN_DEFAULT,"peaks":[12],"trigger":_trig_dot("nano")})
	_entries.append({"id":"combo_weakpoint","category":"状态附加","desc":"弱点暴露指示器(红色X十字脉动3s)","era":"通用","ref":"WEAKPOINT","span":SPAN_DEFAULT,"peaks":[15],"trigger":_trig_combo("weakpoint")})
	_entries.append({"id":"combo_radar_lock","category":"状态附加","desc":"雷达锁定环(目标锁定指示6s)","era":"通用","ref":"RADAR LOCK","span":SPAN_DEFAULT,"peaks":[20],"trigger":_trig_combo("radar")})
	_entries.append({"id":"combo_resonance","category":"状态附加","desc":"激光共鸣环(3层堆叠共振环)","era":"能量","ref":"RESONANCE x3","span":SPAN_DEFAULT,"peaks":[18],"trigger":_trig_combo("resonance")})
	_entries.append({"id":"combo_banner","category":"状态附加","desc":"组合技激活横幅(全队激活+震动)","era":"通用","ref":"COMBO BANNER","span":SPAN_DEFAULT,"peaks":[18],"trigger":_trig_banner()})
	_entries.append({"id":"death_burst","category":"状态附加","desc":"单位死亡爆散(阵营色冲击波+碎片血雾)","era":"通用","ref":"DEATH BURST","span":SPAN_DEFAULT,"peaks":[10],"trigger":_trig_death()})
	_entries.append({"id":"hit_blood","category":"状态附加","desc":"受击血溅(弹道反向血雾+金色火花高光)","era":"通用","ref":"HIT BLOOD","span":SPAN_DEFAULT,"peaks":[8],"trigger":_trig_blood()})
	# --- v13 全量覆盖:大招弹道轨迹(arc 已有,补 dive/vertical) ---
	_entries.append({"id":"traj_dive","category":"弹道轨迹","desc":"俯冲弹道(燃烧弹从右上俯冲+拖尾)","era":"能量","ref":"TRAJECTORY dive","span":70,"peaks":[12,38],"trigger":_trig_traj("dive")})
	_entries.append({"id":"traj_vertical","category":"弹道轨迹","desc":"垂直天降弹道(轨道弹从天而降+拖尾)","era":"虚空","ref":"TRAJECTORY vertical","span":70,"peaks":[12,38],"trigger":_trig_traj("vertical")})

# ============================================================
# 触发器工厂(每个返回独立 Callable,避免循环闭包捕获问题)
# ============================================================
# v11: 展示索引 → (真实 weapon_type, weapon_name)。直射系(SMG/RIFLE/MG)统一走 DIRECT(0)
# + 武器名触发步枪/机枪亚类;wt1/wt2 不再用 legacy 1/2(会撞新枚举 INDIRECT/AERIAL)。
const IMPACT_WT_MAP := [
	[0, ""],         # 0 SMG   → DIRECT GENERIC
	[0, "突击步枪"],  # 1 RIFLE → DIRECT + RIFLE 亚类(窄锥高速)
	[0, "重机枪"],    # 2 MG    → DIRECT + MG 亚类(密集弹痕)
	[3, ""],         # 3 ROCKET
	[4, ""],         # 4 PISTOL
	[5, ""],         # 5 SHOTGUN
	[6, ""],         # 6 SNIPER
	[7, ""],         # 7 FLAK
	[8, ""],         # 8 LASER
	[9, ""],         # 9 MISSILE
	[10, ""],        # 10 OMEGA
	[11, ""],        # 11 RAIL
]

func _trig_impact(wt: int, wname: String = "") -> Callable:
	# v12d: 传 direction=RIGHT(攻击从左方来)→ 签名特效按来弹方向定向(贯穿/来弹光束朝右)。
	return func(): ProjVfx.spawn_impact_with_kind(_bf, Vector2.ZERO, wt, true, -1, {"direction": Vector2.RIGHT}, wname)

func _trig_impact_tier(wt: int, tier: int) -> Callable:
	return func(): ProjVfx.spawn_impact_with_kind(_bf, Vector2.ZERO, wt, true, -1, {"power_tier": tier})

func _trig_crit() -> Callable:
	return func():
		VfxFactory.spawn_crit_aura(_bf, Vector2.ZERO)
		VfxFactory.spawn_crit_sparks(_bf, Vector2.ZERO, true)

func _trig_pierce() -> Callable:
	return func(): VfxFactory.spawn_pierce_beam(_bf, Vector2.ZERO, Vector2.RIGHT, Color(0.85, 0.55, 1.0, 1.0), true)

func _trig_shock() -> Callable:
	return func(): VfxFactory.spawn_shockwave(_bf, Vector2.ZERO, 80.0)

func _trig_lightning() -> Callable:
	return func(): VfxFactory.spawn_lightning_arc(_bf, Vector2(-160, 0), Vector2(160, 0))

func _trig_laser() -> Callable:
	return func(): VfxFactory.spawn_laser_beam(_bf, Vector2(-180, 0), Vector2(180, 0))

# v12e: 护盾罩预览——按单位【真实内容边界】(alpha 扫描)的 max(宽,高)定罩,
#   宽坦克按宽、高步兵按高,左右+上下都罩住。地面=底贴脚(球坐地上);空中=整球居中。
func _trig_shield_bubble() -> Callable:
	return func():
		var col := Color(0.60, 0.85, 1.0, 1.0)  # 全 alpha,靠贴图自带薄度(×0.6)
		# 地面单位:坦克(宽)+ 步兵(高),都底贴脚
		var tank: Sprite2D = _bf.get_node_or_null("Target") as Sprite2D
		if tank != null:
			_spawn_shield_on(tank, col, true)
		var inf: Sprite2D = _bf.get_node_or_null("InfantryRef") as Sprite2D
		if inf != null:
			_spawn_shield_on(inf, col, true)
		# 空中单位(浮空):整球居中
		var air := Sprite2D.new()
		air.texture = TEX_AIR; air.centered = true; air.scale = Vector2(0.42, 0.42)
		air.position = Vector2(240, -150); air.z_index = 4
		_bf.add_child(air); air.add_to_group("battle_vfx")
		_spawn_shield_on(air, col, false)

# alpha 扫描单位贴图的内容边界(脚/头/左右),返回世界坐标 {center,w,h,bottom_y(脚)}。
func _content_bbox_world(spr: Sprite2D) -> Dictionary:
	if spr == null or spr.texture == null:
		return {}
	var img := spr.texture.get_image()
	var tw := img.get_width(); var th := img.get_height()
	var minx := tw; var maxx := -1; var miny := th; var maxy := -1
	var found := false
	var y := 0
	while y < th:
		var x := 0
		while x < tw:
			if img.get_pixel(x, y).a > 0.12:
				found = true
				if x < minx: minx = x
				if x > maxx: maxx = x
				if y < miny: miny = y
				if y > maxy: maxy = y
			x += 4
		y += 4
	if not found:
		return {}
	var tc := Vector2(tw / 2.0, th / 2.0)
	var s := spr.scale
	var p := spr.position
	var off := spr.offset
	var to_world := func(tx: float, ty: float) -> Vector2:
		return p + (Vector2(tx, ty) - tc + off) * s
	var wl: Vector2 = to_world.call(minx, maxy)  # 脚-左(maxy=纹理底=脚)
	var wr: Vector2 = to_world.call(maxx, miny)  # 头-右(miny=纹理顶=头)
	var center: Vector2 = (wl + wr) * 0.5
	return {"center": center, "w": absf(wr.x - wl.x), "h": absf(wr.y - wl.y), "bottom_y": wl.y}

# 给单位生成护盾罩:dia=max(宽,高)×1.2。ground=true→底贴脚;false→整球居中。
func _spawn_shield_on(spr: Sprite2D, col: Color, ground: bool) -> void:
	var bb := _content_bbox_world(spr)
	if bb.is_empty():
		return
	var bw: float = float(bb["w"])
	var bh: float = float(bb["h"])
	var dia := maxf(bw, bh) * 1.2
	var cen: Vector2 = bb["center"]
	var by: float = float(bb["bottom_y"])
	var b := Sprite2D.new()
	b.texture = TEX_SHIELD_BUBBLE; b.centered = true
	b.scale = Vector2.ONE * (dia / 1024.0)
	if ground:
		b.position = Vector2(cen.x, by - dia * 0.5)  # 底贴脚
	else:
		b.position = cen  # 整球居中
	b.modulate = col; b.z_index = 5
	_bf.add_child(b); b.add_to_group("battle_vfx")

func _trig_nuclear() -> Callable:
	var pack := _load_nuke_texture_pack()
	var colors := {"shock": Color(1.0, 0.85, 0.5, 0.9), "aftershock": Color(0.6, 0.7, 1.0, 0.5), "smoke": Color(0.35, 0.32, 0.30, 0.6)}
	return func(): VfxFactory.spawn_nuclear_explosion(_bf, Vector2.ZERO, pack, colors, 1.0)

func _trig_spell(tex: Texture2D, tint: Color) -> Callable:
	return func(): VfxFactory.spawn_spell_burst(_bf, Vector2.ZERO, tex, tint, 320.0, 0.9)

func _trig_portal() -> Callable:
	return func(): VfxFactory.spawn_summon_portal(_bf, Vector2.ZERO, Color(0.45, 0.85, 1.0, 0.9), 0.9)

func _trig_pillar() -> Callable:
	return func(): VfxFactory.spawn_energy_pillar(_bf, Vector2.ZERO, Color(0.5, 0.6, 1.0, 0.8), 400.0, 0.7)

func _trig_ult() -> Callable:
	return func(): VfxFactory.spawn_ultimate_projectile(_bf, Vector2(-220, -180), Vector2.ZERO, TEX_ULT_NUKE, "arc", 56.0, Color.WHITE, Color(1.0, 0.8, 0.3, 0.9), 0.6)

func _trig_muzzle(wt: int) -> Callable:
	return func(): VfxFactory.spawn_muzzle_flash(_bf, Vector2.ZERO, true, wt)

# ============================================================
# v13 全量覆盖触发器(相位仪大招 / boss 技能 / 状态 / 弹道)
# 参数对齐生产代码(phase_instrument_abilities / enemy_master_skill_engine)
# ============================================================

## 炮击弹幕:对齐 _fire_artillery_shot(冲击波100 + 火箭命中 + 200px弹幕爆裂)
func _trig_pi_barrage() -> Callable:
	return func():
		VfxFactory.spawn_shockwave(_bf, Vector2.ZERO, 100.0, Color(1.0, 0.4, 0.2, 0.85))
		VfxFactory.spawn_layered_impact(_bf, Vector2.ZERO, 3, false, -1)
		VfxFactory.spawn_spell_burst(_bf, Vector2.ZERO, TEX_BARRAGE, Color(1.0, 0.4, 0.2), 200.0, 0.6)

## 核子轰炸:对齐 _fire_nuclear_bombardment(核弹arc飞行 0.6s → 蘑菇云核爆 0.6)
func _trig_pi_nuclear() -> Callable:
	return func():
		var pack: Dictionary = _load_nuke_texture_pack()
		var colors := {"shock": Color(1.0, 0.85, 0.5, 0.9), "aftershock": Color(0.6, 0.7, 1.0, 0.5), "smoke": Color(0.35, 0.32, 0.30, 0.6)}
		VfxFactory.spawn_ultimate_projectile(_bf, Vector2(-260, -200), Vector2.ZERO, TEX_ULT_NUKE, "arc", 52.0, Color.WHITE, Color(1.0, 0.8, 0.3, 0.9), 0.6,
			func(_p: Vector2): VfxFactory.spawn_nuclear_explosion(_bf, Vector2.ZERO, pack, colors, 0.6))

## 纳米虫群:对齐 on_battle_start nano_swarm(owner=PLAYER 配色虫群云)
func _trig_pi_nano() -> Callable:
	return func(): PIA._create_nano_swarm_cloud(_bf.global_position, 0)

## boss 技能电影化:对齐 enemy_master_skill_engine._play_*_cinematic 的 VFX 序列
func _trig_boss(kind: String) -> Callable:
	match kind:
		"apocalypse":
			return func():
				VfxFactory.spawn_ultimate_projectile(_bf, Vector2(60, -320), Vector2.ZERO, TEX_ULT_METEOR, "vertical", 64.0, Color(1.0, 0.55, 0.2), Color(1.0, 0.5, 0.2, 0.95), 0.55,
					func(_p: Vector2): VfxFactory.spawn_spell_burst(_bf, Vector2.ZERO, TEX_APOC_METEOR, Color(1.0, 0.5, 0.2), 360.0, 0.9))
		"inferno":
			return func():
				VfxFactory.spawn_ultimate_projectile(_bf, Vector2(240, -240), Vector2.ZERO, TEX_ULT_INFERNO, "dive", 56.0, Color(1.0, 0.3, 0.1), Color(1.0, 0.45, 0.1, 0.95), 0.5,
					func(_p: Vector2):
						VfxFactory.spawn_spell_burst(_bf, Vector2.ZERO, TEX_INFERNO, Color(1.0, 0.3, 0.1), 340.0, 0.9)
						VfxFactory.spawn_spell_burst(_bf, Vector2(-90, 40), TEX_INFERNO, Color(1.0, 0.35, 0.12), 150.0, 0.6))
		"chain":
			return func():
				VfxFactory.spawn_spell_burst(_bf, Vector2.ZERO, TEX_CHAIN, Color(0.5, 0.75, 1.0), 300.0, 0.7)
				VfxFactory.spawn_lightning_arc(_bf, Vector2.ZERO, Vector2(-110, -60), Color(0.5, 0.7, 1.0))
				VfxFactory.spawn_lightning_arc(_bf, Vector2(-110, -60), Vector2(-200, 10), Color(0.5, 0.7, 1.0))
		"spear":
			return func():
				VfxFactory.spawn_ultimate_projectile(_bf, Vector2(0, -300), Vector2.ZERO, TEX_ULT_SPEAR, "vertical", 50.0, Color(1.0, 0.85, 0.5), Color(1.0, 0.85, 0.4, 0.95), 0.4,
					func(_p: Vector2): VfxFactory.spawn_pierce_beam(_bf, Vector2.ZERO, Vector2(1, 0), Color(1.0, 0.9, 0.6, 1.0), true, 1.4))
		"summon":
			return func():
				VfxFactory.spawn_spell_burst(_bf, Vector2.ZERO, TEX_PORTAL, Color(0.7, 0.35, 1.0), 280.0, 1.0)
				VfxFactory.spawn_summon_portal(_bf, Vector2.ZERO, Color(0.7, 0.3, 1.0, 0.9), 0.9)
		"dark":
			return func():
				VfxFactory.spawn_spell_burst(_bf, Vector2.ZERO, TEX_DARK, Color(0.4, 0.15, 0.6), 380.0, 1.2)
				VfxFactory.spawn_lingering_debuff_ring(_bf, Vector2.ZERO, Color(0.45, 0.18, 0.65), 4.0)
		"orbital":
			return func():
				VfxFactory.spawn_ultimate_projectile(_bf, Vector2(0, -300), Vector2.ZERO, TEX_ULT_ORBITAL, "vertical", 48.0, Color(0.7, 0.4, 1.0), Color(0.6, 0.4, 1.0, 0.9), 0.45,
					func(_p: Vector2): VfxFactory.spawn_spell_burst(_bf, Vector2.ZERO, TEX_APOC_VOID, Color(0.5, 0.25, 0.8), 380.0, 1.2))
	return func(): pass

## dot 状态:挂在参照坦克单位上(生产中挂在受 debuff 单位)
func _trig_dot(dot_type: String) -> Callable:
	return func():
		var tank: Sprite2D = _bf.get_node_or_null("Target") as Sprite2D
		if tank != null:
			DotVfx.attach_dot_vfx(tank, dot_type)

## 组合技指示器
func _trig_combo(kind: String) -> Callable:
	match kind:
		"weakpoint":
			return func(): VfxFactory.spawn_weakpoint_indicator(_bf, Vector2.ZERO, 3.0)
		"radar":
			return func(): VfxFactory.spawn_radar_lock_ring(_bf, Vector2.ZERO, 6.0)
		"resonance":
			return func(): VfxFactory.spawn_resonance_ring(_bf, Vector2.ZERO, 3, 5.0)
	return func(): pass

func _trig_banner() -> Callable:
	return func(): VfxFactory.show_combo_activate_banner("组合技·铁壁突袭", 1.6, true)

func _trig_death() -> Callable:
	return func(): VfxFactory.spawn_death_burst(_bf, Vector2.ZERO, false)

func _trig_blood() -> Callable:
	return func(): VfxFactory.spawn_hit_blood(_bf, Vector2.ZERO, Vector2(-1, 0), 8.0, false)

## 大招弹道轨迹(飞行中+命中 两个峰值)
func _trig_traj(mode: String) -> Callable:
	if mode == "dive":
		return func():
			VfxFactory.spawn_ultimate_projectile(_bf, Vector2(230, -230), Vector2.ZERO, TEX_ULT_INFERNO, "dive", 56.0, Color(1.0, 0.3, 0.1), Color(1.0, 0.45, 0.1, 0.95), 0.5,
				func(_p: Vector2): VfxFactory.spawn_spell_burst(_bf, Vector2.ZERO, TEX_INFERNO, Color(1.0, 0.3, 0.1), 300.0, 0.8))
	return func():
		VfxFactory.spawn_ultimate_projectile(_bf, Vector2(0, -300), Vector2.ZERO, TEX_ULT_ORBITAL, "vertical", 48.0, Color(0.7, 0.4, 1.0), Color(0.6, 0.4, 1.0, 0.9), 0.45,
			func(_p: Vector2): VfxFactory.spawn_spell_burst(_bf, Vector2.ZERO, TEX_APOC_VOID, Color(0.5, 0.25, 0.8), 300.0, 0.8))
