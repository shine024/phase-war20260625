# 世界地图与设置分离 - 快速使用指南

## 🎯 功能说明

现在世界地图和设置功能已经完全分离，用户可以更直观地访问这两个功能。

## 🔘 按钮布局

底部功能栏现在的按钮顺序：
1. 背包
2. 合成
3. 强化
4. 法则
5. 势力
6. 任务
7. 商店
8. 蓝图
9. 排行
10. **地图** ← 新增
11. **设置** ← 修正功能

## 🗺️ 世界地图功能

### 访问方式
- 点击底部功能栏的"地图"按钮
- 世界地图在主界面上以overlay形式显示
- 不需要场景切换，响应更快

### 功能特点
- 显示100个关卡，按5个时代分组
- 显示当前关卡进度
- 点击关卡可查看详细信息
- 点击"进入该关"开始战斗
- 点击"返回"回到主界面

### 技术实现
```gdscript
// 在主场景中显示地图
_on_map_pressed():
    _toggle_overlay(map_overlay, "map")

// 地图返回处理
world_map_panel.gd:
    back_to_main.emit() // 发出信号
    隐藏overlay
```

## ⚙️ 设置功能

### 访问方式
- 点击底部功能栏的"设置"按钮
- 设置面板在主界面上以overlay形式显示

### 设置选项
- 主音量控制
- 全屏模式切换
- 设置自动保存到 user://settings.cfg

### 技术实现
```gdscript
// 在主场景中显示设置
_on_settings_pressed():
    _toggle_overlay(settings_overlay, "settings")

// 设置面板
settings_panel_popup.gd:
    继承原有的设置面板功能
    支持关闭信号
```

## 🎮 用户操作流程

### 查看世界地图
1. 在主界面点击"地图"按钮
2. 世界地图面板显示
3. 浏览关卡，查看信息
4. 点击"返回"关闭地图

### 修改设置
1. 在主界面点击"设置"按钮
2. 设置面板显示
3. 调整音量或切换全屏
4. 点击"关闭"或外部区域关闭设置

### 开始战斗
1. 在世界地图中选择关卡
2. 点击"进入该关"
3. 返回主界面，自动准备战斗
4. 点击"开始战斗"进入战斗

## 🔧 开发者注意事项

### 添加新功能按钮
如果要添加更多功能按钮，参考以下步骤：

1. 在 `bottom_function_bar.gd` 中添加配置：
```gdscript
const BTN_CONFIGS: Array = [
    // ... 现有配置
    ["new_function", "新功能", "btn_new_function_pressed"], // 添加新按钮
]
```

2. 在 `main.gd` 中连接信号：
```gdscript
bottom_function_bar.btn_new_function_pressed.connect(_on_new_function_pressed)
```

3. 在 `main.gd` 中实现处理函数：
```gdscript
func _on_new_function_pressed() -> void:
    if AudioManager and AudioManager.has_method("play_sfx"):
        AudioManager.play_sfx("button")
    _toggle_overlay(new_function_overlay, "new_function")
```

### 创建新的overlay面板
1. 在 `main.tscn` 的 PopupLayer 中添加overlay结构
2. 在 `main.gd` 中添加overlay引用
3. 在面板关闭处理中添加对应的case

## 🐛 常见问题

### Q: 地图按钮没有反应？
A: 检查 `main.tscn` 中的脚本引用是否正确，确保 `world_map_panel.gd` 被正确引用。

### Q: 设置面板无法关闭？
A: 检查 `settings_panel_popup.gd` 的关闭信号是否正确连接。

### Q: 返回按钮还是切换场景？
A: 确保使用的是新版本的 `world_map.gd`，应该发出 `back_to_main` 信号而不是切换场景。

## 📈 性能优化

### 相比之前的改进
- **无需场景切换**：减少了场景加载时间
- **内存效率**：复用主场景资源
- **响应速度**：overlay显示比场景切换更快
- **用户体验**：无缝的功能切换

### 建议使用场景
- **小面板**：使用overlay显示（如设置、地图）
- **大界面**：使用独立场景（如战斗、世界地图全屏）
- **弹窗**：使用PopupPanel（如排行榜）

## 🎉 总结

世界地图和设置的分离让界面更加清晰和易用：

✅ **功能独立**：每个按钮有明确功能
✅ **操作直观**：符合用户预期的交互方式
✅ **性能优化**：减少不必要的场景切换
✅ **扩展性强**：便于添加更多功能按钮

这个改进显著提升了用户体验，使游戏界面更加专业和完善！
