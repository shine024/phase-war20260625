extends Node

func _ready():
    print("HUD Test Runner: starting")
    var hud_scene = preload("res://scenes/ui/battle_hud.tscn").instantiate()
    get_tree().get_root().add_child(hud_scene)
    yield(get_tree(), "idle_frame")
    print("HUD Test Runner: HUD scene instantiated")
    # Basic assertion: ensure BattleHUD exists
    if hud_scene:
        print("HUD Scene exists: OK")
    else:
        print("HUD Scene missing: FAIL")
    get_tree().quit()
