extends SceneTree
## 2026-08-22 UI 优化批次验证脚本（--script 模式，秒级）
## 用法：godot --headless --path . --script tests/ui_p1_validation.gd
##
## 覆盖：本批次改动的全部 .gd 文件编译加载 + 关键新 API 运行时断言。

const CHANGED_SCRIPTS: Array[String] = [
	"res://scenes/ui/resource_bar.gd",
	"res://scenes/ui/backpack_card_item_drag.gd",
	"res://scenes/ui/instrument_bar_drag.gd",
	"res://scenes/ui/backpack/backpack_presenter.gd",
	"res://scenes/ui/unit_hover_info.gd",
	"res://scripts/affix_display_format.gd",
	"res://scenes/ui/card_info_panel.gd",
	"res://scripts/ui/panel_styles.gd",
	"res://scenes/main.gd",
	"res://scenes/ui/bottom_instrument_bar.gd",
	"res://scenes/ui/backpack_card_item.gd",
	"res://scenes/ui/store_panel.gd",
	"res://managers/basic_resource_manager.gd",
	"res://managers/toast_manager.gd",
	"res://scripts/toast_utils.gd",
	"res://resources/design_tokens.gd",
	"res://scenes/title_screen.gd",
	"res://scenes/ui/intelligence_hub_panel.gd",
	"res://scenes/ui/intel_harvest_display.gd",
	"res://scenes/ui/feature_unlock_popup.gd",
	"res://managers/ui_lazy_loader.gd",
	"res://scripts/signal_bus.gd",
	"res://managers/battle/battle_damage_system.gd",
	"res://managers/audio_manager.gd",
]

var _fails: Array[String] = []
var _skipped: Array[String] = []

# --script 模式不注册 autoload 全局标识符，引用它们的脚本在此模式必然编译失败（环境限制非错误）。
# 这些文件交给 --check-only 全项目检查兜底。
const AUTOLOAD_NAMES: Array[String] = [
	"SignalBus", "BattleInputState", "EnergyManager", "PhaseInstrumentManager",
	"BattleManager", "GameManager", "BlueprintManager", "DropManager", "SaveManager",
	"AudioManager", "PhaseLawManager", "BasicResourceManager", "ObjectPoolManager",
	"UILazyLoader", "ManagerLazyLoader", "PerformanceMetricsManager", "ModificationRegistry",
	"EvolutionPathRegistry", "DayClock", "AuraManager", "IntelItemBag", "IntelManual",
	"QuestManager", "FactionSystemManager", "AffixManager", "LevelProgressManager",
	"CardEnhancementManager", "InstanceRegistry", "PhaseMasterSkillManager",
	"TutorialProgressionManager", "BattleSpectacle",
]


func _init() -> void:
	_check_compile_all()
	_check_resource_delta_signal()
	_check_affix_tooltip_helper()
	_check_cjk_fallback()
	_check_font_floor()
	_report()
	quit(0 if _fails.is_empty() else 1)


func _references_autoload(source: String) -> bool:
	for name in AUTOLOAD_NAMES:
		if source.contains(name):
			return true
	return false


func _check_compile_all() -> void:
	for sp in CHANGED_SCRIPTS:
		var s: GDScript = load(sp)
		if s != null:
			continue  # 编译通过
		# 编译失败：若源码引用了 autoload 全局名，--script 模式必然失败（环境限制），归入跳过；
		# 否则是真编译错误。
		var fa := FileAccess.open(sp, FileAccess.READ)
		if fa == null:
			_fails.append("无法读取: %s" % sp)
			continue
		var source := fa.get_as_text()
		fa.close()
		if _references_autoload(source):
			_skipped.append(sp)
		else:
			_fails.append("编译失败: %s" % sp)


## P1-6: resource_delta 信号 + 别名规范化 + clamp 语义
func _check_resource_delta_signal() -> void:
	var brm_script: GDScript = load("res://managers/basic_resource_manager.gd")
	if brm_script == null:
		return
	var brm: Node = brm_script.new()
	var got: Array = []
	brm.resource_delta.connect(func(id: String, applied: int) -> void: got.append([id, applied]))
	brm.add_resource("nano_materials", 7)
	if brm.get_total("nano_materials") != 7:
		_fails.append("resource_delta: nano 入账错误")
	if got.size() != 1 or got[0][0] != "nano_materials" or got[0][1] != 7:
		_fails.append("resource_delta: 信号负载错误 %s" % str(got))
	# 别名 basic_nano 应规范化为 nano_materials
	brm.add_resource("basic_nano", 3)
	if got.size() != 2 or got[1][0] != "nano_materials" or got[1][1] != 3:
		_fails.append("resource_delta: 别名规范化错误 %s" % str(got))
	# add_basic_resource 委托等价
	brm.add_basic_resource("alloy", 5)
	if brm.get_total("alloy") != 5:
		_fails.append("add_basic_resource 委托失败")
	# clamp 语义：5 - 100 → 实际 -5（非零应发信号），总量夹到 0
	got.clear()
	brm.add_resource("alloy", -100)
	if brm.get_total("alloy") != 0 or got.size() != 1 or got[0][0] != "alloy" or got[0][1] != -5:
		_fails.append("resource_delta: clamp/负增量语义错误 %s total=%d" % [str(got), brm.get_total("alloy")])
	# 已为 0 再扣：applied=0 不应发信号
	got.clear()
	brm.add_resource("alloy", -10)
	if not got.is_empty():
		_fails.append("resource_delta: 零增量不应发信号 %s" % str(got))
	brm.free()


## P0-4: tags_tooltip 合并辅助
func _check_affix_tooltip_helper() -> void:
	var ADF: GDScript = load("res://scripts/affix_display_format.gd")
	var out: String = ADF.tags_tooltip([{"text": "a", "tooltip": "精准打击 +10%"}, {"text": "b"}])
	if out != "精准打击 +10%":
		_fails.append("tags_tooltip 输出错误: '%s'" % out)
	if ADF.tags_tooltip([]) != "":
		_fails.append("tags_tooltip 空输入应返回空串")


## P1-9: CJK fallback 静态函数可执行
func _check_cjk_fallback() -> void:
	var DT: GDScript = load("res://resources/design_tokens.gd")
	DT.ensure_cjk_fallback()
	var body: Font = load("res://assets/fonts/Rajdhani-Regular.ttf") as Font
	if body == null or body.fallbacks.is_empty():
		_fails.append("ensure_cjk_fallback: 正文字体未挂 fallback")
	# 二次调用幂等（fallback 数不翻倍）
	var before: int = body.fallbacks.size()
	DT.ensure_cjk_fallback()
	if body.fallbacks.size() != before:
		_fails.append("ensure_cjk_fallback: 非幂等")


## P1-9: 字号下限——scenes/scripts 下不再有 <10 的 font_size 字面量
func _check_font_floor() -> void:
	var cmd := "grep -rn 'font_size\\\", [0-9])' --include=*.gd scenes scripts"
	var output: Array = []
	var exit_code := OS.execute("bash", ["-c", cmd], output)
	if exit_code != 0:
		return  # bash 不可用则跳过该项
	var hits: Array[String] = []
	for line in String(output[0]).split("\n"):
		var l: String = line.strip_edges()
		if l.is_empty():
			continue
		var r := l.rfind("\"font_size\", ")
		if r < 0:
			continue
		var num_txt: String = l.substr(r + 14, 1)
		if num_txt.is_valid_int() and int(num_txt) < 10:
			hits.append(l)
	if not hits.is_empty():
		_fails.append("字号下限: 仍有 <10px 的 font_size：\n  " + "\n  ".join(hits))


func _report() -> void:
	if _fails.is_empty():
		print("[UI-P1-VALIDATION] ALL PASS — compiled %d, skipped(autoload-dep, 走 --check-only) %d, runtime checks 4" % [
			CHANGED_SCRIPTS.size() - _skipped.size(), _skipped.size()])
		for sp in _skipped:
			print("  ↷ skip: %s" % sp)
	else:
		print("[UI-P1-VALIDATION] FAILED x%d:" % _fails.size())
		for f in _fails:
			print("  ✗ %s" % f)
		for sp in _skipped:
			print("  ↷ skip: %s" % sp)
