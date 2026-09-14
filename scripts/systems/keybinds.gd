extends RefCounted
class_name KeyBinds
## R6-1（F-18 发行三硬选项）：键位重绑唯一真身。
## InputMap 运行时覆盖层：action 在此注册（不进 project.godot [input]），
## 默认键 + user://settings.cfg 覆盖值在 ensure_registered 时一并生效。
## main.gd 的 _input 全部改走 is_action，ESC(ui_cancel) 与数字槽位 1-9 固定不重绑。

const SETTINGS_PATH: String = "user://settings.cfg"
const SECTION: String = "keybinds"

## 设置面板捕捉重绑按键期间置 true——main._input 见 true 即让路（键事件归捕捉流程独占）
static var capture_active := false

## 可重绑动作表（id 与 main.gd 消费点一一对应；keys 为默认键集，多数动作一个键）
const ACTIONS: Array = [
	{"id": "pw_pause", "label": "战斗暂停 / 继续", "keys": [KEY_SPACE]},
	{"id": "pw_start_battle", "label": "开始战斗", "keys": [KEY_ENTER, KEY_SPACE]},
	{"id": "pw_open_map", "label": "世界地图", "keys": [KEY_M]},
	{"id": "pw_open_backpack", "label": "背包", "keys": [KEY_1, KEY_B]},
	{"id": "pw_open_growth", "label": "成长规划", "keys": [KEY_7]},
	{"id": "pw_open_settings", "label": "设置", "keys": [KEY_9]},
]

static func get_action_def(id: String) -> Dictionary:
	for a in ACTIONS:
		if a.id == id:
			return a
	return {}


## 注册全部动作 + 应用存档覆盖（幂等；main._ready 与设置面板改动时调用）
static func ensure_registered() -> void:
	var overrides := _load_overrides()
	for a in ACTIONS:
		var id: String = a.id
		if not InputMap.has_action(id):
			InputMap.add_action(id)
		InputMap.action_erase_events(id)
		var keys: Array = overrides.get(id, a.keys)
		for keycode in keys:
			var ev := InputEventKey.new()
			ev.keycode = int(keycode)
			InputMap.action_add_event(id, ev)


## 查询某动作当前绑定键的可读名（多键以 " / " 连接）
static func get_binding_label(id: String) -> String:
	if not InputMap.has_action(id):
		return "未绑定"
	var parts: Array = []
	for ev in InputMap.action_get_events(id):
		if ev is InputEventKey:
			parts.append(OS.get_keycode_string(ev.keycode))
	return " / ".join(parts) if not parts.is_empty() else "未绑定"


## 重绑：替换该动作全部绑定为单键并落盘（覆盖式，简单直白）
static func set_binding(id: String, keycode: int) -> void:
	assert(get_action_def(id) != {})
	if not InputMap.has_action(id):
		InputMap.add_action(id)
	InputMap.action_erase_events(id)
	var ev := InputEventKey.new()
	ev.keycode = keycode
	InputMap.action_add_event(id, ev)
	var overrides := _load_overrides()
	overrides[id] = [keycode]
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)  # 不存在也行——只为保住其它 section
	for a in ACTIONS:
		if overrides.has(a.id):
			cfg.set_value(SECTION, a.id, overrides[a.id])
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


static func _load_overrides() -> Dictionary:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK or not cfg.has_section(SECTION):
		return {}
	var out: Dictionary = {}
	for a in ACTIONS:
		var v = cfg.get_value(SECTION, a.id, [])
		if v is Array and not (v as Array).is_empty():
			out[a.id] = v
	return out
