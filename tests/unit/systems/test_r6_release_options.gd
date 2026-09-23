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
	# 覆盖持久化到 settings.cfg keybinds 段（v6.20.2 起 v2 格式：{"keys": [...], "joy": [...]}）
	var cfg := ConfigFile.new()
	assert_int(cfg.load(_CFG)).is_equal(OK)
	var saved: Dictionary = cfg.get_value("keybinds", "pw_open_map", {})
	assert_dict(saved).is_not_empty()
	assert_array(saved.get("keys", [])).contains([KEY_P])
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


## S4/S2 手柄支持批（v6.20.2）：双设备绑定回归锁
func test_keybinds_joy_defaults_registered() -> void:
	KeyBindsScript.reset_all()
	var joy_ev := InputEventJoypadButton.new()
	joy_ev.button_index = JOY_BUTTON_START
	assert_bool(InputMap.action_has_event("pw_pause", joy_ev)).is_true()
	var joy_a := InputEventJoypadButton.new()
	joy_a.button_index = JOY_BUTTON_A
	assert_bool(InputMap.action_has_event("pw_start_battle", joy_a)).is_true()
	# 双设备并存：键盘默认键不因手柄注册而丢（OS.get_keycode_string(KEY_SPACE)="Space"）
	assert_str(KeyBindsScript.get_binding_label("pw_pause")).contains("Space")
	assert_str(KeyBindsScript.get_binding_label("pw_pause")).contains("MENU")


func test_keybinds_joy_rebind_keeps_keyboard() -> void:
	KeyBindsScript.reset_all()
	KeyBindsScript.set_binding_joy("pw_open_map", JOY_BUTTON_Y)
	var joy_ev := InputEventJoypadButton.new()
	joy_ev.button_index = JOY_BUTTON_Y
	assert_bool(InputMap.action_has_event("pw_open_map", joy_ev)).is_true()
	var old_joy := InputEventJoypadButton.new()
	old_joy.button_index = JOY_BUTTON_BACK
	assert_bool(InputMap.action_has_event("pw_open_map", old_joy)).is_false()
	# 手柄重绑不波及键盘绑定
	var key_ev := InputEventKey.new()
	key_ev.keycode = KEY_M
	assert_bool(InputMap.action_has_event("pw_open_map", key_ev)).is_true()
	# 落盘为 v2 字典且 joy 键持久化（ensure_registered 重读存档仍生效）
	var cfg := ConfigFile.new()
	assert_int(cfg.load(_CFG)).is_equal(OK)
	var saved: Dictionary = cfg.get_value("keybinds", "pw_open_map", {})
	assert_array(saved.get("joy", [])).contains([JOY_BUTTON_Y])
	KeyBindsScript.ensure_registered()
	assert_bool(InputMap.action_has_event("pw_open_map", joy_ev)).is_true()


func test_keybinds_legacy_array_override_still_works() -> void:
	# 旧格式（纯 int Array）= 仅键盘覆盖，手柄回落默认值（零迁移成本回归锁）
	var cfg := ConfigFile.new()
	cfg.set_value("keybinds", "pw_open_map", [KEY_P])
	cfg.save(_CFG)
	KeyBindsScript.ensure_registered()
	var key_ev := InputEventKey.new()
	key_ev.keycode = KEY_P
	assert_bool(InputMap.action_has_event("pw_open_map", key_ev)).is_true()
	var joy_ev := InputEventJoypadButton.new()
	joy_ev.button_index = JOY_BUTTON_BACK
	assert_bool(InputMap.action_has_event("pw_open_map", joy_ev)).is_true()


func test_keybinds_back_event_helper() -> void:
	# is_back_event：ESC 键与手柄 Ⓑ 均为返回；Ⓐ 不是
	var esc := InputEventKey.new()
	esc.keycode = KEY_ESCAPE
	esc.pressed = true
	assert_bool(KeyBindsScript.is_back_event(esc)).is_true()
	var joy_b := InputEventJoypadButton.new()
	joy_b.button_index = JOY_BUTTON_B
	joy_b.pressed = true
	assert_bool(KeyBindsScript.is_back_event(joy_b)).is_true()
	var joy_a := InputEventJoypadButton.new()
	joy_a.button_index = JOY_BUTTON_A
	joy_a.pressed = true
	assert_bool(KeyBindsScript.is_back_event(joy_a)).is_false()
	# 未按下不触发
	joy_b.pressed = false
	assert_bool(KeyBindsScript.is_back_event(joy_b)).is_false()


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


## S17/S13（v6.20.2）：发行导出必须排除两个开发桥插件的编辑器侧文件——
## 但 runtime/ 的 autoload 桥脚本要保留（有 OS.is_debug_build 自守卫，release 零行为），
## 整目录排除 runtime = 导出包 autoload 断链启动炸。
func test_export_excludes_dev_addons_but_keeps_runtime_bridges() -> void:
	var f := FileAccess.open("res://export_presets.cfg", FileAccess.READ)
	assert_object(f).is_not_null()
	var text := f.get_as_text()
	f.close()
	var excludes := ""
	for line in text.split("\n"):
		if line.begins_with("exclude_filter="):
			excludes = line
			break
	assert_str(excludes).is_not_empty()
	for must in ["addons/agent_tools/tools/*", "addons/agent_tools/server.gd*",
			"addons/godot_ai/clients/*", "addons/godot_ai/plugin.gd*", "addons/opencode.json"]:
		assert_str(excludes).contains(must)
	assert_bool(excludes.contains("addons/agent_tools/runtime")).is_false()
	assert_bool(excludes.contains("addons/godot_ai/runtime")).is_false()
