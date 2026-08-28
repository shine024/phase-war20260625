# v21.0 敌方战斗卡情报系统 smoke test（不依赖 GdUnit）
# 覆盖：双轨同步（base=max(intel,获取下限)）/ 部署记账 / 击败 mod 点数 /
#       获取下限 50% / 满情报全池解锁（含浮点容差）/ 低进化选项与 intel_base 条件 /
#       存档往返 / 旧档迁移
#
# ⚠️ --script 模式实证（2026-08-28）：autoload 单例【会】被实例化为空状态节点
# （SaveManager 不装档、BattleManager._ready 可能报脚本模式噪音——非本测试问题）。
# 因此：① 直接取 /root/IntelManual 使用（手动 new 一个同名节点会被自动重命名，
# 导致 can_evolve_blueprint 读到空 autoload——首跑 FAIL 19 的根因）；
# ② 开头 reset_progress() 保证对本地存档密闭；③ BlueprintManager 用桩替代
# （level/mods 条件与战力估算需要 bpm_ref.blueprint_* 字段）。
#
# Usage: godot --headless --rendering-driver opengl3 --path . --script tests/intel_v21_smoke.gd
extends SceneTree

const IntelManualScript = preload("res://scripts/systems/intel_manual.gd")
const EnemyCardModMapC = preload("res://data/enemy_card_mod_map.gd")
const CardEvolutionManager = preload("res://managers/evolution/card_evolution_manager.gd")
const CapturedUnitCards = preload("res://data/captured_unit_cards.gd")

## BlueprintManager 桩：can_evolve_blueprint 的 level/mods 条件与战力估算需要 bpm_ref 字段
class BPMStub extends Node:
	var blueprint_mods: Dictionary = {}
	var blueprint_inherit_bonus: Dictionary = {}
	var blueprint_intel_branch_bonus: Dictionary = {}
	var blueprint_evolution_hp_floor: Dictionary = {}

var code: Array = [0]
var checks: int = 0

func ok(cond: bool, msg: String) -> void:
	checks += 1
	if cond:
		print("  ok  %2d) %s" % [checks, msg])
	else:
		code[0] = 1
		print("[FAIL] %2d) %s" % [checks, msg])

func _initialize() -> void:
	print("=== v21.0 敌方战斗卡情报系统 smoke ===")
	randomize()

	# 取真 autoload（--script 模式为空状态实例）；极端环境缺失时兜底新建
	var im: Node = root.get_node_or_null("IntelManual")
	if im == null:
		im = IntelManualScript.new()
		im.name = "IntelManual"
		root.add_child(im)
	if im.has_method("reset_progress"):
		im.reset_progress()  # 密闭性：清掉本地存档可能残留的条目

	# ── T1 旧档迁移：base_progress 键缺失时缺省取 intel_progress ──
	print("\n[T1] 旧档迁移（v3 存档无 base_progress 键）")
	var raw_entry: Dictionary = {
		"card_id": "legacy_card", "intel_progress": 0.8, "is_unlocked": false,
		"first_encounter": true, "defeat_count": 5, "recon_bonus": 0.0,
		"decompose_bonus": 0.0, "migrated": true,
	}
	var e1 = IntelManualScript.IntelEntry.from_dict(raw_entry)
	ok(absf(e1.base_progress - 0.8) < 0.001, "base_progress 缺省取 intel_progress = 0.8")
	ok(e1.defeat_count == 5, "旧字段（defeat_count）无损读取")

	# ── T2 击败：intel 增长 + base 同步 + mod 点数 ──
	print("\n[T2] 击败情报 + mod 点数")
	var arch := "ww1_inf_mp18"
	var d2: Dictionary = im.register_defeat(arch, "normal", "infantry", 0)
	ok(float(d2.get("intel", 0.0)) > 0.001, "击败普通敌给情报增量（首杀 12%）")
	ok(absf(im.get_base_progress(arch) - im.get_intel_progress(arch)) < 0.001,
		"base 与 intel 单调同步（base==intel）")
	var mp2: int = im.add_defeat_mod_points(arch, "elite")
	ok(mp2 == 2, "精英击败 +2 mod 点入池")
	ok(im.get_all_mod_intel_points(arch).size() >= 1, "点数已落入该形态专属池")

	# ── T3 部署：deploy_count + base+4% + 2~5 点 ──
	print("\n[T3] 部署记账")
	var b0: float = im.get_base_progress(arch)
	var r3: Dictionary = im.register_deploy(arch, "infantry")
	ok(im.get_deploy_count(arch) == 1, "deploy_count = 1")
	ok(absf(im.get_base_progress(arch) - (b0 + 0.04)) < 0.005, "部署 base +4%（固定不衰减）")
	var mp3: int = int(r3.get("mod_points", -1))
	ok(mp3 >= 2 and mp3 <= 5, "部署 mod 点数 ∈ [2,5]（实际 %d）" % mp3)

	# ── T4 获取下限：base 与 intel 同时抬到 50% ──
	print("\n[T4] 获取缴获卡 → 情报下限 50%")
	var arch4 := "ww1_sup_mg_nest"
	im.set_acquired_base_progress(arch4)
	ok(im.get_base_progress(arch4) >= 0.5 - 0.001, "base ≥ 50%")
	ok(im.get_intel_progress(arch4) >= 0.5 - 0.001, "intel 同步过半（属性揭示档联动）")

	# ── T5 满情报：base=100% + 全池解锁 ──
	print("\n[T5] 满情报全池解锁")
	var arch5 := "ww1_arm_rolls_mk2"
	for i in range(30):
		im.register_deploy(arch5, "")
	ok(im.get_base_progress(arch5) >= 1.0 - 0.001, "连续部署推满 base = 100%")
	var pool5: Array = EnemyCardModMapC.get_unlockable_mods(arch5)
	ok(pool5.size() == 2, "前置数据：ww1_arm_rolls_mk2 mod_pool = 2 个（实际 %d）" % pool5.size())
	ok(im.get_unlocked_mod_ids(arch5).size() == pool5.size(),
		"满情报全池无条件解锁（%d/%d）" % [im.get_unlocked_mod_ids(arch5).size(), pool5.size()])

	# ── T6 点数达标解锁（不经满情报） ──
	print("\n[T6] 点数达标单独解锁")
	var arch6 := "cold_inf_ak"
	var added6: int = im._add_mod_points(arch6, 120)
	ok(added6 == 120, "单次大额点数入池成功")
	var unlocked6: Array = im.get_unlocked_mod_ids(arch6)
	ok(unlocked6.size() >= 1, "点数 ≥ 阈值即解锁（阈值最高 120）")
	if unlocked6.size() >= 1:
		ok(im.is_mod_unlocked(arch6, String(unlocked6[0])), "is_mod_unlocked 查询一致")
		ok(absf(im.get_mod_unlock_progress(arch6, String(unlocked6[0])) - 1.0) < 0.001,
			"get_mod_unlock_progress 已解锁 = 1.0")

	# ── T6b 满档容差：0.99995 视为满（直接调 _check_mods_full_unlock 确定性触发） ──
	print("\n[T6b] 满档浮点容差")
	var arch6b := "ww1_sup_vickers"
	var raw6b: Dictionary = {
		"_version": 3,
		arch6b: {"card_id": arch6b, "intel_progress": 0.99995, "base_progress": 0.99995,
			"is_unlocked": true, "migrated": true},
	}
	var im6b: Node = IntelManualScript.new()  # 不挂树：纯数据操作，避免与 autoload 重名
	im6b.load_state(raw6b)
	im6b._check_mods_full_unlock(arch6b)
	var pool6b: Array = EnemyCardModMapC.get_unlockable_mods(arch6b)
	ok(pool6b.size() >= 1 and im6b.get_unlocked_mod_ids(arch6b).size() == pool6b.size(),
		"base=99.995%% 容差内 → 全池解锁（%d/%d）" % [im6b.get_unlocked_mod_ids(arch6b).size(), pool6b.size()])

	# ── T7 低进化选项 ──
	print("\n[T7] 低进化选项（get_evolution_options）")
	CapturedUnitCards.register_into_default_cards_cache()
	var opts7: Dictionary = CardEvolutionManager.get_evolution_options("captured_ww1_inf_mp18")
	var low7: Dictionary = opts7.get("low_evolution", {})
	ok(String(low7.get("target_card_id", "")) == "ww1_mp18", "缴获卡低进化目标 = ww1_mp18")
	var opts7b: Dictionary = CardEvolutionManager.get_evolution_options("ww1_mp18")
	ok(not opts7b.has("low_evolution"), "普通玩家卡不输出 low_evolution")

	# ── T8 低进化条件（intel_base） ──
	print("\n[T8] can_evolve_blueprint 低进化条件")
	var bpm := BPMStub.new()
	root.add_child(bpm)
	# 正例：T2/T3 已把 ww1_inf_mp18 推到 16%，再获取下限抬到 50%
	im.set_acquired_base_progress(arch)
	var info8: Dictionary = CardEvolutionManager.can_evolve_blueprint("captured_ww1_inf_mp18", "ww1_mp18", bpm)
	ok(String(info8.get("reason", "")) != "target_not_in_path", "低进化目标被放行（不在常规链上也可）")
	var cond8: Dictionary = _find_cond(info8, "intel_base")
	ok(not cond8.is_empty() and bool(cond8.get("met", false)),
		"intel_base 条件达成（base=%.4f ≥ 50%%）" % im.get_base_progress(arch))
	ok(not _has_cond(info8, "evo_blueprint"), "低进化对跳过图纸条件")
	# 反例：从未接触的形态 → intel_base 未达成
	var info8b: Dictionary = CardEvolutionManager.can_evolve_blueprint("captured_ww1_inf_storm_e", "ww1_storm", bpm)
	var cond8b: Dictionary = _find_cond(info8b, "intel_base")
	ok(not cond8b.is_empty() and not bool(cond8b.get("met", false)), "情报不足时 intel_base 未达成")

	# ── T9 存档往返 ──
	print("\n[T9] 存档往返（save_state → load_state）")
	var saved: Dictionary = im.save_state()
	var im2: Node = IntelManualScript.new()  # 不挂树：纯数据校验
	im2.load_state(saved)
	ok(absf(im2.get_base_progress(arch5) - 1.0) < 0.001, "base_progress 无损")
	ok(im2.get_deploy_count(arch5) == 30, "deploy_count 无损")
	ok(im2.get_unlocked_mod_ids(arch5).size() == pool5.size(), "unlocked_mod_ids 无损")
	ok(im2.get_all_mod_intel_points(arch).size() >= 1, "card_mod_intels 无损")

	print("\n═══════════════════════════════════════════════════════════")
	if code[0] == 0:
		print("✅ 全部 PASS（%d 项断言）" % checks)
	else:
		print("❌ 存在失败断言，见上方 [FAIL]")
	print("═══════════════════════════════════════════════════════════")
	quit(code[0])

func _find_cond(info: Dictionary, key: String) -> Dictionary:
	for c in info.get("conditions", []):
		if c is Dictionary and String(c.get("key", "")) == key:
			return c
	return {}

func _has_cond(info: Dictionary, key: String) -> bool:
	return not _find_cond(info, key).is_empty()
