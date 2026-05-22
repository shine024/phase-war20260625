# Phase War 快速集成指南

## 🚀 立即集成新系统到主游戏

### 第1步：注册管理器（5分钟）

在 `main.gd` 的 `_ready()` 函数中添加：

```gdscript
func _ready() -> void:
    # ... 现有代码 ...

    # 注册新管理器
    _setup_new_managers()

func _setup_new_managers() -> void:
    var managers_to_register = [
        ["TutorialProgressionManager", "res://managers/tutorial_progression_manager.gd"],
        ["DailyTaskManager", "res://managers/daily_task_manager.gd"],
        ["ChallengeModeManager", "res://managers/challenge_mode_manager.gd"],
        ["CardCollectionManager", "res://managers/card_collection_manager.gd"],
        ["StoryManager", "res://managers/story_manager.gd"],
        ["CharacterManager", "res://managers/character_manager.gd"]
    ]

    for manager_info in managers_to_register:
        var name = manager_info[0]
        var path = manager_info[1]

        var existing = get_node_or_null("/root/" + name)
        if not existing:
            var script = load(path)
            if script:
                var node = script.new()
                node.name = name
                get_tree().root.add_child(node)
                print("[Main] Registered manager: ", name)
```

### 第2步：在新游戏中启动教程（2分钟）

在 `GameManager.start_new_game()` 中添加：

```gdscript
func start_new_game() -> void:
    # ... 现有代码 ...

    # 启动新手教程
    _start_tutorial_if_needed()

    # 初始化日常任务
    _init_daily_tasks()

func _start_tutorial_if_needed() -> void:
    var tutorial_manager = get_node_or_null("/root/TutorialProgressionManager")
    if tutorial_manager and tutorial_manager.should_show_tutorial():
        var tutorial_scene = preload("res://scenes/ui/tutorial_overlay.tscn")
        if tutorial_scene:
            var tutorial = tutorial_scene.instantiate()
            get_tree().root.add_child(tutorial)

func _init_daily_tasks() -> void:
    var task_manager = get_node_or_null("/root/DailyTaskManager")
    if task_manager:
        task_manager.refresh_daily_tasks()
```

### 第3步：在战斗中添加反馈（3分钟）

在 `BattleManager` 中添加：

```gdscript
# 在单位受伤时
func on_unit_damaged(unit: Node, damage: int, is_critical: bool) -> void:
    if battlefield and unit.global_position:
        DamageNumberDisplay.create_damage_number(
            battlefield,
            unit.global_position,
            damage,
            is_critical
        )

        var camera = battlefield.get_node_or_null("Camera2D")
        if is_critical:
            ScreenShake.medium_shake(camera)
        else:
            ScreenShake.light_shake(camera)

# 在相位法则施放时
func on_phase_law_cast(law_id: String, position: Vector2) -> void:
    if battlefield:
        var law_data = PhaseLawManager.get_law_by_id(law_id)
        if not law_data.is_empty():
            var family = law_data.get("family", "")
            match family:
                "钢铁": PhaseLawCastEffect.create_steel_effect(battlefield, position)
                "烈焰": PhaseLawCastEffect.create_flame_effect(battlefield, position)
                "雷霆": PhaseLawCastEffect.create_thunder_effect(battlefield, position)
                "虚空": PhaseLawCastEffect.create_void_effect(battlefield, position)
```

### 第4步：战斗胜利后更新任务（2分钟）

在 `BattleManager.end_battle()` 中添加：

```gdscript
func end_battle(player_won: bool) -> void:
    # ... 现有代码 ...

    if player_won:
        # 更新日常任务
        var task_manager = get_node_or_null("/root/DailyTaskManager")
        if task_manager:
            task_manager.update_task_progress(DailyTaskManager.TaskType.BATTLE_VICTORY, 1)

        # 更新卡牌收集
        var collection_manager = get_node_or_null("/root/CardCollectionManager")
        if collection_manager:
            for card_id in _obtained_cards:
                collection_manager.update_card_status(card_id)

        # 检查成就
        var achievement_manager = get_node_or_null("/root/AchievementManager")
        if achievement_manager:
            achievement_manager.check_achievement("first_victory")
```

### 第5步：添加UI按钮（5分钟）

在底部功能栏添加新按钮：

```gdscript
# bottom_instrument_bar.gd
func _add_new_buttons() -> void:
    # 日常任务按钮
    var daily_task_btn = create_function_button("日常任务", "打开日常任务面板")
    daily_task_btn.pressed.connect(_open_daily_task_panel)
    add_child(daily_task_btn)

    # 挑战模式按钮
    var challenge_btn = create_function_button("挑战", "打开挑战模式面板")
    challenge_btn.pressed.connect(_open_challenge_panel)
    add_child(challenge_btn)

    # 卡牌图鉴按钮
    var collection_btn = create_function_button("图鉴", "打开卡牌图鉴")
    collection_btn.pressed.connect(_open_collection_panel)
    add_child(collection_btn)

func _open_daily_task_panel() -> void:
    var panel = preload("res://scenes/ui/daily_task_panel.tscn").instantiate()
    get_tree().root.add_child(panel)

func _open_challenge_panel() -> void:
    # 创建挑战模式面板
    var panel = preload("res://scenes/ui/challenge_mode_panel.tscn").instantiate()
    get_tree().root.add_child(panel)

func _open_collection_panel() -> void:
    # 创建卡牌图鉴面板
    var panel = preload("res://scenes/ui/card_collection_panel.tscn").instantiate()
    get_tree().root.add_child(panel)
```

---

## ⚡ 快速测试清单

### 测试新手引导
- [ ] 启动新游戏，看到欢迎教程
- [ ] 完成第一步，看到卡牌收藏教程
- [ ] 跳过教程，能正常进入游戏

### 测试日常任务
- [ ] 打开日常任务面板
- [ ] 看到7个任务（3简单+2普通+1困难+1专家）
- [ ] 完成战斗，任务进度更新
- [ ] 领取任务奖励

### 测试战斗反馈
- [ ] 战斗中看到伤害数字
- [ ] 暴击时看到红色大数字
- [ ] 屏幕轻微震动
- [ ] 法则施放看到特效

### 测试卡牌收集
- [ ] 打开图鉴面板
- [ ] 看到收集进度
- [ ] 获得新卡牌，状态更新

---

## 🎯 优先级建议

### 现在就做
1. **注册管理器** - 必须先做，其他都依赖
2. **测试新手引导** - 最直接影响新用户体验
3. **测试战斗反馈** - 最直接影响战斗体验

### 本周完成
4. **集成日常任务** - 提升留存
5. **添加UI按钮** - 让用户能访问新功能

### 本月完成
6. **创建UI场景文件** - 完整的用户界面
7. **添加美术资源** - 图标、肖像等
8. **完善数据配置** - 成就、任务、故事

---

## 📊 预期效果

集成这些系统后，你的游戏将立即获得：

✅ **更好的新手体验** - 教程引导
✅ **更强的战斗反馈** - 伤害数字+震动+特效
✅ **更高的留存率** - 日常任务系统
✅ **更多的游戏内容** - 挑战模式+图鉴系统
✅ **更深的情感投入** - 故事+角色系统

**立即开始集成，让你的游戏成为4.9星高分游戏！** 🚀
