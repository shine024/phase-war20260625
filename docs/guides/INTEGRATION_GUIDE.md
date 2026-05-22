# 快速参考指南：新系统集成

## 🎯 如何在游戏中使用新的UI面板

### 1. 显示卡牌强化面板
```gdscript
# 加载并显示卡牌强化面板
var enhancement_panel = load("res://scenes/ui/card_enhancement_panel.tscn").instantiate()
add_child(enhancement_panel)
enhancement_panel.show()
```

### 2. 显示势力系统面板
```gdscript
# 加载并显示势力面板
var faction_panel = load("res://scenes/ui/faction_panel.tscn").instantiate()
add_child(faction_panel)
faction_panel.show()
```

### 3. 显示关卡信息面板
```gdscript
# 加载并设置关卡信息面板
var level_panel = load("res://scenes/ui/level_info_panel.tscn").instantiate()
add_child(level_panel)
level_panel.set_level(5)  # 显示第5关的信息
level_panel.show()
```

---

## 📝 任务定义中如何添加势力奖励

### 修改任务定义格式
在 `res://data/quest_definitions.gd` 中，为任务添加 `faction_reputation` 字段：

```gdscript
# 例子：与钢壁防务相关的任务
{
    "id": "defend_fortress",
    "name": "防守要塞",
    "description": "帮助钢壁防务守卫要塞",
    "objective_type": "win_battles",
    "target": 3,
    "rewards": {
        "faction_reputation": {
            "iron_wall_corp": 100,    # 增加钢壁防务100声望
        },
        "blueprint_fragments": {
            "platform_ww1_fort": 10,
        },
        "nano_materials": 50,
    }
}
```

### 多个势力奖励
```gdscript
{
    "id": "complex_mission",
    "name": "复杂任务",
    "rewards": {
        "faction_reputation": {
            "iron_wall_corp": 50,
            "nova_arms": 30,
            "aether_dynamics": 20,
        },
        # ... 其他奖励
    }
}
```

---

## 🎮 游戏主菜单中集成UI

### 添加菜单按钮
在主菜单中添加按钮以打开各个系统面板：

```gdscript
# 在菜单脚本中
var menu_buttons = {
    "卡牌强化": func():
        _show_panel("card_enhancement"),
    "势力系统": func():
        _show_panel("faction"),
    "关卡浏览": func():
        _show_panel("level_info"),
}

func _show_panel(panel_name: String):
    match panel_name:
        "card_enhancement":
            var panel = load("res://scenes/ui/card_enhancement_panel.tscn").instantiate()
            add_child(panel)
        "faction":
            var panel = load("res://scenes/ui/faction_panel.tscn").instantiate()
            add_child(panel)
        "level_info":
            var panel = load("res://scenes/ui/level_info_panel.tscn").instantiate()
            add_child(panel)
```

---

## 🔍 调试和验证

### 验证系统初始化
```gdscript
# 检查是否正确加载
func _verify_systems():
    assert(FactionSystemManager != null, "FactionSystemManager未加载")
    assert(CardEnhancementManager != null, "CardEnhancementManager未加载")
    
    # 检查初始数据
    print("势力数量: ", FactionSystemManager.get_all_factions_info().size())
    print("样本卡牌强化等级: ", CardEnhancementManager.get_card_enhancement_level("platform_ww1_fort"))
```

### 测试势力声望增加
```gdscript
# 手动增加势力声望测试
FactionSystemManager.add_faction_reputation("iron_wall_corp", 100)

# 获取势力信息验证
var faction_info = FactionSystemManager.get_faction_info("iron_wall_corp")
print("钢壁防务声望: ", faction_info["reputation"])
print("钢壁防务等级: ", faction_info["level"])
```

### 测试卡牌强化
```gdscript
# 手动测试强化
var success = CardEnhancementManager.enhance("platform_ww1_fort", BlueprintManager)
print("强化成功: ", success)

# 检查新等级
var level = CardEnhancementManager.get_card_enhancement_level("platform_ww1_fort")
print("新强化等级: ", level)
```

### 测试关卡信息
```gdscript
# 测试关卡信息查询
var level_info = LevelInformation.new()
var info = level_info.get_level_info(1)
print("关卡1名称: ", info["display_name"])
print("关卡1势力: ", info["faction_id"])
print("关卡1描述: ", info["description"])
```

---

## 💾 保存和加载

### 手动保存游戏
```gdscript
if SaveManager:
    SaveManager.save_game()
    print("游戏已保存")
```

### 手动加载游戏
```gdscript
if SaveManager:
    var success = SaveManager.load_game()
    if success:
        print("游戏已加载")
        # 刷新UI显示
        faction_panel.refresh() if faction_panel else null
```

---

## 🎨 UI 自定义选项

### 修改 CardEnhancementPanel 的外观
在 `card_enhancement_panel.gd` 中修改：

```gdscript
func _get_card_display_name(card_id: String, card_data: Dictionary) -> String:
    """自定义卡牌显示名称"""
    var name_str = card_data.get("card_name", card_id)
    var level = CardEnhancementManager.get_card_enhancement_level(card_id) if CardEnhancementManager else 1
    
    # 可修改这里改变显示格式
    return "🔨 %s ⭐ Lv.%d" % [name_str, level]  # 示例：添加emoji
```

### 修改势力等级显示颜色
在 `faction_panel.gd` 中修改：

```gdscript
var level_label = Label.new()
level_label.text = "等级：%d" % level
# 根据等级改变颜色
match level:
    1,2: level_label.add_theme_color_override("font_color", Color.GRAY)
    3,4,5: level_label.add_theme_color_override("font_color", Color.WHITE)
    6,7,8: level_label.add_theme_color_override("font_color", Color.YELLOW)
    9,10: level_label.add_theme_color_override("font_color", Color.GOLD)
faction_detail.add_child(level_label)
```

---

## 🐛 常见问题

### Q: 卡牌强化面板显示不了？
**A**: 检查以下几点：
1. `CardEnhancementManager` 是否在 project.godot 的 autoload 中
2. `BlueprintManager` 是否已初始化
3. 卡牌数据是否正确加载

### Q: 势力声望不增加？
**A**: 检查：
1. 任务奖励格式是否包含 `faction_reputation` 字段
2. 势力ID是否正确（`iron_wall_corp` 等）
3. `QuestManager._grant_rewards()` 是否被调用

### Q: 关卡信息显示为空？
**A**: 检查：
1. 是否调用了 `set_level(level_num)`
2. `LevelInformation` 是否初始化完成
3. level_num 是否在 1-100 之间

### Q: 游戏加载后数据丢失？
**A**: 检查：
1. SaveManager 是否在 autoload 中
2. `load_game()` 是否在游戏启动时被调用
3. save.json 是否存在且可读

---

## 📊 性能优化建议

### 1. 延迟加载面板
```gdscript
# 而不是一次加载所有面板，改为按需加载
var cached_panels = {}

func get_panel(panel_name: String):
    if not cached_panels.has(panel_name):
        cached_panels[panel_name] = load("res://scenes/ui/%s_panel.tscn" % panel_name).instantiate()
    return cached_panels[panel_name]
```

### 2. 优化卡牌列表渲染
```gdscript
# 使用虚拟滚动而不是一次加载所有卡牌
@onready var card_list = $VBoxContainer/ScrollContainer/CardListContainer
card_list.custom_minimum_size = Vector2(0, 400)  # 限制显示高度
# ScrollContainer 会自动处理超出部分
```

### 3. 减少信号连接
```gdscript
# 使用信号去重
var _reputation_changed_pending = false

func _on_faction_reputation_changed(...) -> void:
    if _reputation_changed_pending:
        return
    _reputation_changed_pending = true
    await get_tree().process_frame
    _update_faction_detail()
    _reputation_changed_pending = false
```

---

## 🚀 下一步扩展

### 添加势力商店购买系统
```gdscript
# 在 FactionSystemManager 中添加
func can_purchase_from_faction(faction_id: String, card_id: String) -> bool:
    var level = get_faction_level(faction_id)
    # 实现等级限制逻辑
    return level >= required_level_for_card(card_id)

func purchase_from_faction(faction_id: String, card_id: String) -> bool:
    if not can_purchase_from_faction(faction_id, card_id):
        return false
    # 实现购买逻辑（消耗资源、添加到背包等）
    return true
```

### 添加关卡难度调整
```gdscript
# 在 LevelInformation 中添加动态难度
func get_adjusted_difficulty(level_num: int, player_level: int) -> float:
    var base_diff = get_level_info(level_num).get("difficulty_modifier", 1.0)
    var player_factor = max(0.5, min(2.0, float(player_level) / 10.0))
    return base_diff * player_factor
```

---

**最后更新**: 2026-03-18  
**维护者**: Phase War 开发团队
