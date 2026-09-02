extends SceneTree
## tests/_tmp_v27_audio_ftue_check.gd — v27 P0 批次（音频补课 + FTUE）验证
## ① 8 首 BGM .import loop=true（导入源头）+ AudioStreamOggVorbis 运行时置 loop 后可读回 true
## ② SFX_NAMES 含 ultimate_ready/base_alarm；sound_generator 合成兜底可取到（含 button_hover）
## ③ audio_manager 关键实现存在：hover 钩子 / 基地告警 / BGM 运行时循环
## Usage: godot --headless --rendering-driver opengl3 --path . --script tests/_tmp_v27_audio_ftue_check.gd

func _initialize() -> void:
	var errs: Array[String] = []

	# ── ① BGM 循环（.import 源头 + 运行时置位） ──
	var bgms: Array[String] = [
		"bgm_title", "bgm_hub", "bgm_battle_ww1", "bgm_battle_ww2",
		"bgm_battle_cold", "bgm_battle_modern", "bgm_battle_future", "bgm_boss",
	]
	for b in bgms:
		var f := FileAccess.open("res://assets/sfx/%s.ogg.import" % b, FileAccess.READ)
		if f == null:
			errs.append("缺 .import: " + b)
			continue
		if f.get_as_text().find("loop=true") < 0:
			errs.append("%s.import 未设 loop=true" % b)
		f = null
		var stream = load("res://assets/sfx/%s.ogg" % b)
		if stream is AudioStreamOggVorbis:
			stream.loop = true  # 与 play_music 内同款置位
			if not bool(stream.loop):
				errs.append("%s 运行时 loop 置位失败" % b)
		else:
			errs.append("%s 非 AudioStreamOggVorbis: %s" % [b, stream.get_class()])

	# ── ② 新音效名 + 合成兜底 ──
	var am: Node = root.get_node("AudioManager")
	if am == null:
		_print_fail(["AudioManager autoload 缺失"])
		return
	for n in ["ultimate_ready", "base_alarm"]:
		if not (n in am.SFX_NAMES):
			errs.append("SFX_NAMES 缺 " + n)
	# _initialize 早于 autoload _ready：直接实例化生成器并手动生成（与 _ready 内同路径）
	var sgs = load("res://managers/sound_generator.gd").new()
	if sgs.has_method("_generate_all_sounds"):
		sgs._generate_all_sounds()
	for n in ["ultimate_ready", "base_alarm", "button_hover"]:
		if sgs.get_sound(n) == null:
			errs.append("合成兜底缺 " + n)

	# ── ③ 关键实现存在（源码级断言） ──
	var src := FileAccess.open("res://managers/audio_manager.gd", FileAccess.READ).get_as_text()
	for needle in [
		"node_added.connect(_on_node_added_hover_sfx)",
		"BASE_ALARM_RATIO",
		"stream.loop = true",
		"_on_phase_driver_hp_changed_alarm",
	]:
		if src.find(needle) < 0:
			errs.append("audio_manager 缺关键实现: " + needle)

	if errs.is_empty():
		print("V27 AUDIO/FTUE CHECK: ALL PASS")
		quit(0)
	else:
		_print_fail(errs)
		quit(1)

func _print_fail(errs: Array) -> void:
	for e in errs:
		printerr("FAIL: " + String(e))
