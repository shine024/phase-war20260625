extends Node
## v6.41 全解锁档探针（窗口化真 autoload 链，--script 无 autoload 跑不了安装链）：
## ① 技能树免前置免点数（PhaseMasterSkillManager.can_unlock_node / unlock_node）
## ② 改造免战力档（BlueprintManager.install_modification 真实安装链，神话件×era0 弱卡）
## ③ 出厂默认档（编辑器跑=无 pw_playtest feature）门槛仍在 = 回归断言
## 跑法：Godot.exe --path . res://tests/_tmp_v641_unlock_probe.tscn
## ⚠️ 探针会动真档数据（技能树/背包/资源/卡实例）——跑前备份 user:// 存档目录，跑后还原。

const GameCfg = preload("res://resources/game_config.gd")
const BlueprintDefinitions = preload("res://data/blueprint_definitions.gd")
const ShopResIds = preload("res://data/basic_resources.gd")
const PowerTiers = preload("res://data/power_tiers.gd")
const SkillTreeRef = preload("res://data/phase_master_skill_tree.gd")

const WEAK_CARD_ID := "ww1_mp18"            # era0 弱卡（测试既有用例同款）
const MYTHIC_MOD_ID := "gen_21_vanguard_repair"  # v27 mythic 通用件（min tier=OVERLORD）
const DEEP_NODE_ID := "pms_cmd_4"           # requires pms_cmd_3 的深链节点

var errs := 0

func _fail(msg: String) -> void:
	errs += 1
	print("[probe][FAIL] " + msg)

func _ready() -> void:
	# 等 autoload 链稳定一帧再动数据
	await get_tree().process_frame
	await _run()
	print("V641_UNLOCK_PROBE_%s errs=%d" % ["OK" if errs == 0 else "FAIL", errs])
	get_tree().quit(0 if errs == 0 else 1)

func _run() -> void:
	var cfg: Resource = GameCfg.get_default()
	# ── 出厂默认档断言：两个新开关（编辑器跑无 pw_playtest feature）
	if bool(cfg.debug_skill_tree_free):
		_fail("debug_skill_tree_free 出厂应为 false")
	if bool(cfg.debug_mod_ignore_power_tier):
		_fail("debug_mod_ignore_power_tier 出厂应为 false")

	# ═══ ② 改造战力档 ═══
	var bm: Node = get_node("/root/BlueprintManager")
	var bag: Node = get_node("/root/IntelItemBag")
	var brm: Node = get_node("/root/BasicResourceManager")
	var ir: Node = get_node("/root/InstanceRegistry")
	if bm == null or bag == null or brm == null or ir == null:
		_fail("autoload 缺失 bm/bag/brm/ir"); return
	if String(ModificationRegistryRef.get_data(MYTHIC_MOD_ID).get("rarity", "")) != "mythic":
		_fail("探针目标件 %s 应为 mythic 档" % MYTHIC_MOD_ID)
	var min_tier: int = ModManagerRef.get_min_power_tier_for_mod(MYTHIC_MOD_ID)
	if min_tier != PowerTiers.Tier.OVERLORD:
		_fail("mythic 件 min tier 应为 OVERLORD，实际 %d" % min_tier)

	var bp_id: String = BlueprintDefinitions.get_mod_blueprint_id(MYTHIC_MOD_ID)
	if bp_id.is_empty():
		_fail("mythic 件蓝图 id 为空")
		return
	bag.add_item(bp_id, 1)
	brm.add_resource(ShopResIds.ID_NANO_MATERIALS, 99999)

	# flag off：弱卡装神话件被战力档拦
	var inst: CardResource = ir.create_instance(WEAK_CARD_ID)
	if inst == null or String(inst.instance_id).is_empty():
		_fail("create_instance(%s) 失败" % WEAK_CARD_ID); return
	var res: Dictionary = bm.install_modification(inst, MYTHIC_MOD_ID)
	if bool(res.get("success", false)):
		_fail("flag off 弱卡装神话件应被战力档拦（实装成功=%s）" % [res])
	elif not String(res.get("message", "")).contains("战力"):
		_fail("flag off 拦截原因应含'战力'，实际: %s" % res.get("message", ""))

	# flag on：同一张弱卡（战力不变）直接装成功
	cfg.debug_mod_ignore_power_tier = true
	var res2: Dictionary = bm.install_modification(inst, MYTHIC_MOD_ID)
	if not bool(res2.get("success", false)):
		_fail("flag on 弱卡装神话件应成功，实际: %s" % res2.get("message", ""))
	elif inst.mods.size() != 1:
		_fail("flag on 安装后 mods.size()=%d 应为 1" % inst.mods.size())
	cfg.debug_mod_ignore_power_tier = false

	# ═══ ① 技能树 ═══
	var psm: Node = get_node("/root/PhaseMasterSkillManager")
	if psm == null:
		_fail("PhaseMasterSkillManager autoload 缺失"); return
	var psm_snapshot: Dictionary = psm.save_state()
	psm._unlocked_nodes = []
	psm._spent_points = 0
	# flag off：深链节点被前置拦
	var can: Dictionary = psm.can_unlock_node(DEEP_NODE_ID)
	if String(can.get("reason", "")) != "requires_not_met":
		_fail("flag off 深链节点应 requires_not_met，实际 %s" % [can])
	# flag off：前置满足但点数耗尽 → not_enough_points
	psm._unlocked_nodes = ["pms_cmd_3"]
	psm._spent_points = 99999
	can = psm.can_unlock_node(DEEP_NODE_ID)
	if String(can.get("reason", "")) != "not_enough_points":
		_fail("flag off 点数耗尽应 not_enough_points，实际 %s" % [can])
	# flag on：前置+点数全免，深链节点直接解锁成功
	cfg.debug_skill_tree_free = true
	if not bool(psm.can_unlock_node(DEEP_NODE_ID).get("ok", false)):
		_fail("flag on 深链节点 can_unlock 应 ok")
	if not psm.unlock_node(DEEP_NODE_ID):
		_fail("flag on unlock_node 应成功")
	elif not psm.is_unlocked(DEEP_NODE_ID):
		_fail("解锁后 is_unlocked 应为 true")
	# flag on：真实补库链端到端——save_manager._grant_debug_test_stock ⑥步应自动全加点
	psm._unlocked_nodes = []
	psm._spent_points = 0
	var save: Node = get_node("/root/SaveManager")
	if save == null or not save.has_method("_grant_debug_test_stock"):
		_fail("SaveManager 缺失或无 _grant_debug_test_stock")
	else:
		var grant_flag_prev: bool = bool(cfg.debug_grant_all_blueprints)
		cfg.debug_grant_all_blueprints = true
		save._grant_debug_test_stock()
		cfg.debug_grant_all_blueprints = grant_flag_prev
		for nid in SkillTreeRef.get_all_node_ids():
			if not psm.is_unlocked(String(nid)):
				_fail("补库链跑完后 %s 仍未解锁（⑥钩子未生效？）" % nid)
				break
	# flag on：直调幂等——全解锁状态下再调应零新解锁
	if psm.debug_unlock_all_nodes() != 0:
		_fail("自动加点幂等失败：全解锁后再调仍有新解锁")
	cfg.debug_skill_tree_free = false
	# 还原技能树真档状态
	psm.load_state(psm_snapshot)

## ModificationRegistry 静态表（无 autoload，preload 直用）
const ModificationRegistryRef = preload("res://scripts/systems/modification_registry.gd")
const ModManagerRef = preload("res://managers/evolution/mod_manager.gd")
