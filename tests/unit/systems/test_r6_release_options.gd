class_name R6ReleaseOptionsTest
extends GdUnitTestSuite
## v31 R6（F-18/F-16/F-20）回归锁
## 覆盖：KeyBinds 注册/重绑往返/覆盖持久化、settings.cfg 保全（_save 先 load 再写，
## 不得抹 keybinds 段）、色盲档读写、战功榜死榜不复活。
## ⚠️ 用例会写 user://settings.cfg——before/after 全程备份还原，不落真档痕迹。

const KeyBindsScript = preload("res://scripts/systems/keybinds.gd")
const _LB_DEFS := preload("res://data/leaderboard_definitions.gd")
const _CFG := "user://settings.cfg"

var _cfg_backup: String = ""
var _cfg_existed := false


func before_test() -> void:
	_cfg_existed = FileAccess.file_exists(_CFG)
	if _cfg_existed:
		_cfg_backup = FileAccess.get_file_as_string(_CFG)


func after_test() -> void:
	if _cfg_existed:
		var f := FileAccess.open(_CFG, FileAccess.WRITE)
		f.store_string(_cfg_backup)
		f.close()
	elif FileAccess.file_exists(_CFG):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(_CFG))
	# InputMap 恢复默认注册态（按还原后的 cfg 重新应用覆盖）
	KeyBindsScript.ensure_registered()


func test_keybinds_register_all_actions_with_defaults() -> void:
	KeyBindsScript.reset_all()
	for a in KeyBindsScript.ACTIONS:
		assert_bool(InputMap.has_action(a.id)).is_true()
	var space_ev := InputEventKey.new()
	space_ev.keycode = KEY_SPACE
	assert_bool(InputMap.action_has_event("pw_pause", space_ev)).is_true()
	var enter_ev := InputEventKey.new()
	enter_ev.keycode = KEY_ENTER
	assert_bool(InputMap.action_has_event("pw_start_battle", enter_ev)).is_true()


func test_keybinds_rebind_roundtrip_and_persist() -> void:
	KeyBindsScript.reset_all()
	KeyBindsScript.set_binding("pw_open_map", KEY_P)
	var ev := InputEventKey.new()
	ev.keycode = KEY_P
	assert_bool(InputMap.action_has_event("pw_open_map", ev)).is_true()
	var old_ev := InputEventKey.new()
	old_ev.keycode = KEY_M
	assert_bool(InputMap.action_has_event("pw_open_map", old_ev)).is_false()
	# 覆盖持久化到 settings.cfg keybinds 段
	var cfg := ConfigFile.new()
	assert_int(cfg.load(_CFG)).is_equal(OK)
	var saved: Array = cfg.get_value("keybinds", "pw_open_map", [])
	assert_array(saved).contains([KEY_P])
	# 恢复默认后回到 M
	KeyBindsScript.reset_all()
	assert_str(KeyBindsScript.get_binding_label("pw_open_map")).contains("M")


func test_keybinds_override_applied_on_register() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("keybinds", "pw_open_growth", [KEY_G])
	cfg.save(_CFG)
	KeyBindsScript.ensure_registered()
	var ev := InputEventKey.new()
	ev.keycode = KEY_G
	assert_bool(InputMap.action_has_event("pw_open_growth", ev)).is_true()


func test_settings_save_preserves_keybinds_section() -> void:
	# 预置 keybinds 段（模拟 KeyBinds.set_binding 落盘后的现场）
	var cfg := ConfigFile.new()
	cfg.set_value("keybinds", "pw_open_map", [KEY_P])
	cfg.save(_CFG)
	# 面板不入树实例化（@onready 成员为 null 走缺省分支），直接调 _save()
	var panel: PanelContainer = (load("res://scenes/ui/settings_panel.tscn") as PackedScene).instantiate()
	panel._save()
	panel.free()
	var cfg2 := ConfigFile.new()
	assert_int(cfg2.load(_CFG)).is_equal(OK)
	# 保全断言：keybinds 段未被设置面板覆写抹掉（v31 修复的存量 bug 回归锁）
	assert_array(cfg2.get_value("keybinds", "pw_open_map", [])).contains([KEY_P])
	# 面板未入树时 R6-1 新控件为 null、新键不落（守卫生效），但既有 settings 段正常写入
	assert_bool(cfg2.has_section("settings")).is_true()


func test_color_grade_cb_mode_read_write() -> void:
	var cgs := load("res://managers/color_grade.gd")
	var cfg := ConfigFile.new()
	cfg.set_value("settings", "color_blind_mode", 3)
	cfg.save(_CFG)
	assert_int(cgs._load_cb_mode_from_settings()).is_equal(3)
	var cg_node: Node = get_tree().root.get_node("ColorGrade")
	cg_node.set_color_blind_mode(2)
	assert_int(cg_node.get_color_blind_mode()).is_equal(2)
	var mat: ShaderMaterial = cg_node._mat
	assert_float(float(mat.get_shader_parameter("color_blind_mode"))).is_equal(2.0)


func test_leaderboard_dead_board_not_resurrected() -> void:
	assert_bool(_LB_DEFS.LEADERBOARDS.has("survival_highscore")).is_true()
	assert_bool(_LB_DEFS.LEADERBOARDS.has("time_attack_best")).is_false()
	var cmap: Dictionary = (_LB_DEFS as Script).get_script_constant_map()
	assert_bool(cmap.has("LEADERBOARD_CATEGORIES")).is_false()
	assert_dict(_LB_DEFS.get_leaderboard("time_attack_best")).is_empty()
