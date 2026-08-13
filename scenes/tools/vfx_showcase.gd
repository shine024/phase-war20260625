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
		var peak: int = 8 if wt in [0, 1, 2, 4, 5, 6] else 12
		_entries.append({
			"id": "impact_wt%d" % wt,
			"category": "命中特效",
			"desc": wt_desc[wt] + " 命中金属装甲目标产生的火花/冲击",
			"era": "现代",
			"ref": wt_names[wt],
			"span": SPAN_DEFAULT,
			"peaks": [peak],
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
	return func(): ProjVfx.spawn_impact_with_kind(_bf, Vector2.ZERO, wt, true, -1, {}, wname)

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
