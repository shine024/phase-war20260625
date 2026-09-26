extends SceneTree
## v6.28 BGM 授权换曲批冒烟（--script 直跑，无 autoload 依赖）
## 断言：8 首 BGM 可加载、OggVorbis、时长与目录一致、loop 可置位；
## credits_panel.gd（本轮改动）可编译且 MUSIC 段含署名；CREDITS.md 台账零 UNVERIFIED。
## 期望输出：V628_BGM_SMOKE_OK

func _initialize() -> void:
	var failures: Array[String] = []
	var expect := {
		"bgm_title": 185.0, "bgm_hub": 91.0,
		"bgm_battle_ww1": 185.0, "bgm_battle_ww2": 153.0,
		"bgm_battle_cold": 204.0, "bgm_battle_modern": 130.0,
		"bgm_battle_future": 101.0, "bgm_boss": 272.0,
	}
	for slot: String in expect:
		var path := "res://assets/sfx/%s.ogg" % slot
		if not ResourceLoader.exists(path):
			failures.append("%s: missing at %s" % [slot, path])
			continue
		var stream := load(path)
		if stream == null:
			failures.append("%s: load returned null" % slot)
			continue
		if not (stream is AudioStreamOggVorbis):
			failures.append("%s: not AudioStreamOggVorbis (%s)" % [slot, stream.get_class()])
			continue
		var dur: float = stream.get_length()
		if absf(dur - expect[slot]) > 4.0:
			failures.append("%s: duration %.1fs off from catalog %.0fs" % [slot, dur, expect[slot]])
		stream.loop = true
		if not stream.loop:
			failures.append("%s: loop flag not settable" % slot)
		print("[smoke] %s OK %.1fs" % [slot, dur])

	var credits_script := load("res://scripts/ui/credits_panel.gd")
	if credits_script == null:
		failures.append("credits_panel.gd failed to compile")
	else:
		var sections = credits_script.get("SECTIONS")
		var joined := ""
		for sec: Dictionary in sections:
			joined += str(sec.get("title", ""))
		if not joined.contains("音乐与音效"):
			failures.append("credits_panel SECTIONS missing music section")
		print("[smoke] credits_panel compiles, sections=", joined)

	var f := FileAccess.open("res://assets/sfx/CREDITS.md", FileAccess.READ)
	if f == null:
		failures.append("CREDITS.md unreadable")
	else:
		var text := f.get_as_text()
		if text.contains("UNVERIFIED → 已退役") and not text.contains("| ❌ **UNVERIFIED"):
			pass  # 退役记录里的 UNVERIFIED 字样合法；现行表不得再有未退役 UNVERIFIED 行
		for line in text.split("\n"):
			if line.begins_with("|") and line.contains("❌") and not line.contains("退役"):
				failures.append("CREDITS.md has active UNVERIFIED row: " + line)

	if failures.is_empty():
		print("V628_BGM_SMOKE_OK")
	else:
		for msg in failures:
			print("[FAIL] ", msg)
		print("V628_BGM_SMOKE_FAILED")
	quit(1 if not failures.is_empty() else 0)
