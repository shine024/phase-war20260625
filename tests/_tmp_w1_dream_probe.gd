extends Node
## W1 battle_bg 实机验证探针（2026-09-14 收尾计划 W1 验收"游戏内序章战斗实机目视"）。
## 挂 dream_battle（dry-run 压缩时间线）→ 等 FIGHT 段稳定 → 全视口截图 → 退出。
## 输出：res://.godot/agent_tools/w1_dream_battle.png

const OUT := "res://.godot/agent_tools/w1_dream_battle.png"
const META_DRY_RUN := "bunker_intro_dry_run"


func _ready() -> void:
	_run()


func _run() -> void:
	await _wait_frames(20)
	Engine.set_meta(META_DRY_RUN, true)
	var scene: Node = (load("res://scenes/intro/dream_battle.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(scene)
	get_tree().current_scene = scene
	print("[DreamProbe] dream_battle mounted (dry-run)")
	# 等 FIGHT 段演出稳定（标题淡入后），避开 FADE_IN 黑幕
	await _wait_sec(7.0)
	var tex := get_tree().root.get_viewport().get_texture()
	var img: Image = tex.get_image()
	if img != null and not img.is_empty():
		var err := img.save_png(OUT)
		print("[DreamProbe] saved ", OUT, " err=", err, " size=", img.get_size())
	else:
		print("[DreamProbe] EMPTY capture")
	Engine.remove_meta(META_DRY_RUN)
	get_tree().quit()


func _wait_frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _wait_sec(s: float) -> void:
	await get_tree().create_timer(s).timeout
