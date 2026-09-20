extends RefCounted
class_name KeyBinds
## R6-1（F-18 发行三硬选项）：键位重绑唯一真身。
## InputMap 运行时覆盖层：action 在此注册（不进 project.godot [input]），
## 默认键 + user://settings.cfg 覆盖值在 ensure_registered 时一并生效。
## main.gd 的 _input 全部改走 is_action，ESC(ui_cancel) 与数字槽位 1-9 固定不重绑。
##
## S4/S2 手柄支持批（2026-09-20）：每动作双设备绑定——键盘 keys + 手柄 joy 各自独立
## 重绑、互不覆盖（键盘玩家换手柄即插即用，反向同理）。settings.cfg 覆盖值 v2 格式
## 为 Dictionary {"keys": [...], "joy": [...]}；旧格式（纯 int Array）按"仅键盘"读取，
## 手柄回落默认值，零迁移成本。ESC 关面板 = ui_cancel（Godot 默认含手柄 B），
## 数字 1-9 部署槽仅键盘固定。

const SETTINGS_PATH: String = "user://settings.cfg"
const SECTION: String = "keybinds"

## 设置面板捕捉重绑按键期间置 true——main._input 见 true 即让路（键事件归捕捉流程独占）
static var capture_active := false

## 手柄按键可读名（Xbox 布局命名；PS 手柄玩家可在重绑界面实按适配）
const JOY_BUTTON_LABELS: Dictionary = {
	JOY_BUTTON_A: "Ⓐ", JOY_BUTTON_B: "Ⓑ", JOY_BUTTON_X: "Ⓧ", JOY_BUTTON_Y: "Ⓨ",
	JOY_BUTTON_BACK: "SELECT", JOY_BUTTON_START: "MENU", JOY_BUTTON_GUIDE: "GUIDE",
	JOY_BUTTON_LEFT_SHOULDER: "LB", JOY_BUTTON_RIGHT_SHOULDER: "RB",
	JOY_BUTTON_LEFT_STICK: "LS", JOY_BUTTON_RIGHT_STICK: "RS",
	JOY_BUTTON_DPAD_UP: "十字键↑", JOY_BUTTON_DPAD_DOWN: "十字键↓",
	JOY_BUTTON_DPAD_LEFT: "十字键←", JOY_BUTTON_DPAD_RIGHT: "十字键→",
}

## 可重绑动作表（id 与 main.gd 消费点一一对应）。
## keys = 键盘默认键集（多数动作一个键）；joy = 手柄默认键（Godot 4 JOY_BUTTON 枚举）。
## 手柄默认布局首拍：A=确认/开战、MENU=暂停、SELECT=地图、LB/RB=背包/技能、X=设置；
## 不合手的可在设置面板实按重绑。
const ACTIONS: Array = [
	{"id": "pw_pause", "label": "战斗暂停 / 继续", "keys": [KEY_SPACE], "joy": [JOY_BUTTON_START]},
	{"id": "pw_start_battle", "label": "开始战斗", "keys": [KEY_ENTER, KEY_SPACE], "joy": [JOY_BUTTON_A]},
	{"id": "pw_open_map", "label": "世界地图", "keys": [KEY_M], "joy": [JOY_BUTTON_BACK]},
	{"id": "pw_open_backpack", "label": "背包", "keys": [KEY_1, KEY_B], "joy": [JOY_BUTTON_LEFT_SHOULDER]},
	{"id": "pw_open_growth", "label": "技能树", "keys": [KEY_7], "joy": [JOY_BUTTON_RIGHT_SHOULDER]},
	{"id": "pw_open_settings", "label": "设置", "keys": [KEY_9], "joy": [JOY_BUTTON_X]},
]

static func get_action_def(id: String) -> Dictionary:
	for a in ACTIONS:
		if a.id == id:
			return a
	return {}


## 注册全部动作（键盘+手柄）+ 应用存档覆盖（幂等；main._ready 与设置面板改动时调用）
static func ensure_registered() -> void:
	var overrides := _load_overrides()
	for a in ACTIONS:
		var id: String = a.id
		if not InputMap.has_action(id):
			InputMap.add_action(id)
		InputMap.action_erase_events(id)
		var ov: Dictionary = overrides.get(id, {})
		for keycode in ov.get("keys", a.keys):
			var ev := InputEventKey.new()
			ev.keycode = int(keycode)
			InputMap.action_add_event(id, ev)
		for jb in ov.get("joy", a.get("joy", [])):
			var je := InputEventJoypadButton.new()
			je.button_index = int(jb)
			InputMap.action_add_event(id, je)


## 查询某动作当前绑定（键盘 + 手柄）的可读名，设备间以 " ｜ " 分隔
static func get_binding_label(id: String) -> String:
	if not InputMap.has_action(id):
		return "未绑定"
	var keys: Array = []
	var joys: Array = []
	for ev in InputMap.action_get_events(id):
		if ev is InputEventKey:
			keys.append(OS.get_keycode_string((ev as InputEventKey).keycode))
		elif ev is InputEventJoypadButton:
			joys.append(joypad_button_label((ev as InputEventJoypadButton).button_index))
	var parts: Array = []
	if not keys.is_empty():
		parts.append(" / ".join(keys))
	if not joys.is_empty():
		parts.append("+".join(joys))
	return " ｜ ".join(parts) if not parts.is_empty() else "未绑定"


static func joypad_button_label(button_index: int) -> String:
	return JOY_BUTTON_LABELS.get(button_index, "手柄%d" % button_index)


## 动作主绑定键名（键帽角标用：优先键盘首键，无键盘绑定才示手柄键）
static func primary_binding_text(action_id: String) -> String:
	if not InputMap.has_action(action_id):
		return ""
	for ev in InputMap.action_get_events(action_id):
		if ev is InputEventKey:
			return OS.get_keycode_string((ev as InputEventKey).keycode)
	for ev in InputMap.action_get_events(action_id):
		if ev is InputEventJoypadButton:
			return joypad_button_label((ev as InputEventJoypadButton).button_index)
	return ""


## 重绑键盘：替换该动作键盘绑定为单键（手柄绑定不动）并落盘
static func set_binding(id: String, keycode: int) -> void:
	assert(get_action_def(id) != {})
	_apply_binding(id, keycode, -1)


## 重绑手柄：替换该动作手柄绑定为单键（键盘绑定不动）并落盘
static func set_binding_joy(id: String, joy_button: int) -> void:
	assert(get_action_def(id) != {})
	_apply_binding(id, -1, joy_button)


## v6.20.2：菜单返回/关闭事件判定——ESC 键或手柄 B（ui_cancel 默认含手柄 B，
## 但手写 `is InputEventKey` 过滤的面板会丢手柄事件，改用本助手放行）。
## 调用方无需再查 is_pressed。
static func is_back_event(event: InputEvent) -> bool:
	if event is InputEventJoypadButton:
		return event.pressed and event.button_index == JOY_BUTTON_B
	return event is InputEventKey and event.pressed and event.is_action("ui_cancel")


static func _apply_binding(id: String, keycode: int, joy_button: int) -> void:
	if not InputMap.has_action(id):
		InputMap.add_action(id)
	var a := get_action_def(id)
	var overrides := _load_overrides()
	var ov: Dictionary = overrides.get(id, {})
	var keys: Array = ov.get("keys", a.keys)
	var joys: Array = ov.get("joy", a.get("joy", []))
	InputMap.action_erase_events(id)
	if keycode >= 0:
		keys = [keycode]
	for kc in keys:
		var ev := InputEventKey.new()
		ev.keycode = int(kc)
		InputMap.action_add_event(id, ev)
	if joy_button >= 0:
		joys = [joy_button]
	for jb in joys:
		var je := InputEventJoypadButton.new()
		je.button_index = int(jb)
		InputMap.action_add_event(id, je)
	# 落盘（读-改-写保住 settings 段；v2 格式整体写入该动作键值）
	overrides[id] = {"keys": keys, "joy": joys}
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)  # 不存在也行——只为保住其它 section
	for act in ACTIONS:
		if overrides.has(act.id):
			cfg.set_value(SECTION, act.id, overrides[act.id])
	cfg.save(SETTINGS_PATH)


## 全部恢复默认（清覆盖段 + 重注册默认键）
static func reset_all() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK and cfg.has_section(SECTION):
		for a in ACTIONS:
			if cfg.has_section_key(SECTION, a.id):
				cfg.erase_section_key(SECTION, a.id)
		cfg.save(SETTINGS_PATH)
	ensure_registered()


## 覆盖值统一读成 {"keys": [...], "joy": [...]}；旧格式（int Array）按"仅键盘"兼容
static func _load_overrides() -> Dictionary:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK or not cfg.has_section(SECTION):
		return {}
	var out: Dictionary = {}
	for a in ACTIONS:
		var v = cfg.get_value(SECTION, a.id, null)
		if v is Array and not (v as Array).is_empty():
			out[a.id] = {"keys": v}
		elif v is Dictionary and not (v as Dictionary).is_empty():
			out[a.id] = v
	return out
