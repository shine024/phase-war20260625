# 游戏应用系统 - 完整使用指南

## 🎯 系统概述

完善和强大的游戏应用系统为《Phase War》提供了全面的应用层管理功能，包括启动管理、设置控制、通知系统、教程引导、数据统计、版本管理和模组支持。

## 🏗️ 系统架构

```
游戏应用系统
├── 游戏应用管理器 (GameApplicationManager)
│   ├── 系统初始化和生命周期管理
│   ├── 应用状态监控
│   └── 核心服务协调
├── 设置管理器 (SettingsManager)
│   ├── 游戏设置控制
│   ├── 图形和音频设置
│   └── 控制和辅助功能
├── 通知管理器 (NotificationManager)
│   ├── 通知显示系统
│   ├── 消息分类和优先级
│   └── 通知历史记录
├── 教程进度管理器 (TutorialProgressionManager)
│   ├── 新手引导流程
│   ├── 交互式教程步骤
│   └── 进度追踪
├── 统计管理器 (StatisticsManager)
│   ├── 游戏数据收集
│   ├── 性能分析
│   └── 统计报告生成
├── 版本管理器 (VersionManager)
│   ├── 版本控制
│   ├── 更新检查
│   └── 兼容性管理
└── 模组管理器 (ModManager) [计划中]
    ├── 模组加载系统
    ├── 内容扩展支持
    └── 社区内容集成
```

## 🚀 核心功能

### 1. 游戏应用管理器

#### 应用生命周期管理
```gdscript
# 获取应用管理器
var app_mgr = get_node_or_null("/root/GameApplicationManager")

# 获取应用信息
var app_info = app_mgr.get_application_info()
# 返回: 应用名称、版本、会话ID、运行时间等

# 获取系统信息
var sys_info = app_mgr.get_system_info()
# 返回: 操作系统、处理器、内存等信息

# 设置游戏模式
app_mgr.set_game_mode("hardcore")  # normal, hardcore, creative, tutorial
```

#### 会话管理
- **会话跟踪**: 每次启动生成唯一会话ID
- **运行时间统计**: 精确记录游戏运行时长
- **状态监控**: 实时监控应用状态变化
- **优雅关闭**: 安全清理和保存数据

### 2. 设置管理器

#### 设置分类

**通用设置**
- 语言选择（中文、英文、日文、韩文）
- 自动保存配置
- 存档间隔设置

**音频设置**
- 主音量、音乐音量、音效音量、界面音量
- 实时音量调节
- 独立音量控制

**图形设置**
- 全屏模式、垂直同步
- 帧率限制（30-144 FPS）
- 界面缩放（0.5x - 2.0x）
- 粒子效果、屏幕震动

**游戏设置**
- 难度等级（教程、简单、普通、困难、专家、终极）
- 铁人模式
- 伤害数字显示
- 战斗速度调节
- 自动战斗模式

**控制设置**
- 键盘布局（QWERTY、AZERTY、QWERTZ）
- 鼠标灵敏度
- 手柄支持和震动

**辅助功能**
- 高对比度模式
- 色盲模式（红色盲、绿色盲、蓝色盲）
- 字体大小调节
- 屏幕阅读器支持

**高级设置**
- 调试模式
- 帧率显示
- 日志级别
- 模组启用

#### 设置API使用
```gdscript
var settings_mgr = get_node_or_null("/root/SettingsManager")

# 获取设置值
var volume = settings_mgr.get_setting("master_volume")

# 修改设置值
settings_mgr.set_setting("fullscreen", true)

# 重置分类设置
settings_mgr.reset_category(SettingsManager.SettingCategory.AUDIO)

# 导出/导入设置
settings_mgr.export_settings("user://settings_backup.json")
settings_mgr.import_settings("user://settings_backup.json")

# 获取设置摘要
var summary = settings_mgr.get_settings_summary()
```

### 3. 通知管理器

#### 通知类型和优先级

**通知类型**
- **信息** (ℹ️): 一般信息提示
- **成功** (✅): 操作成功确认
- **警告** (⚠️): 警告提示
- **错误** (❌): 错误信息
- **成就** (🏆): 成就解锁通知
- **任务** (📜): 任务更新通知
- **系统** (⚙️): 系统消息
- **社交** (👥): 社交通知

**优先级级别**
- **低**: 不重要的信息
- **普通**: 标准通知
- **高**: 重要通知
- **紧急**: 需要立即处理

#### 通知API使用
```gdscript
var notification_mgr = get_node_or_null("/root/NotificationManager")

# 显示不同类型的通知
notification_mgr.show_info("提示", "游戏已保存")
notification_mgr.show_success("成功", "设置已更新")
notification_mgr.show_warning("警告", "存档空间不足")
notification_mgr.show_error("错误", "无法连接到服务器")

# 特殊通知
notification_mgr.show_achievement("成就解锁", "初战告捷")
notification_mgr.show_quest("任务更新", "新任务可用")

# 自定义通知
notification_mgr.show_notification({
    "title": "自定义通知",
    "message": "通知内容",
    "type": NotificationManager.NotificationType.INFO,
    "priority": NotificationManager.NotificationPriority.HIGH,
    "duration": 10.0,
    "action": {
        "type": "open_panel",
        "data": {"panel": "settings"}
    }
})

# 管理通知
notification_mgr.dismiss_all_notifications()
notification_mgr.mark_all_notifications_read()
var unread_count = notification_mgr.get_unread_count()
```

### 4. 教程管理器

#### 教程系统

**内置教程**
- **基础玩法教程**: 游戏基本操作和界面介绍
- **高级战术教程**: 连击系统、资源管理、敌人弱点
- **装备系统教程**: 强化、合成系统详解
- **BOSS战攻略**: BOSS机制分析和应对策略

**教程功能**
- 交互式步骤引导
- UI元素高亮显示
- 实时演示和练习
- 进度自动保存
- 前置条件检查
- 奖励发放

#### 教程API使用
```gdscript
var tutorial_mgr = get_node_or_null("/root/TutorialProgressionManager")

# 开始教程
tutorial_mgr.start_tutorial("basic_gameplay")

# 教程进度控制
tutorial_mgr.next_step()  # 下一步
tutorial_mgr.skip_tutorial("advanced_tactics")  # 跳过教程

# 查询教程状态
var progress = tutorial_mgr.get_tutorial_progress("basic_gameplay")
var completion_rate = tutorial_mgr.get_tutorial_completion_rate()

# 获取推荐教程
var recommended = tutorial_mgr.get_recommended_tutorials()

# 重置教程
tutorial_mgr.reset_tutorial("basic_gameplay")
tutorial_mgr.reset_all_tutorials()
```

### 5. 统计管理器

#### 统计分类

**游戏统计**
- 总游戏时间（小时）
- 会话数量
- 最长会话时长

**战斗统计**
- 总战斗场次
- 胜率和败场
- 总击杀数
- 伤害输出/承受
- 最快胜利时间
- 最高单次伤害

**收藏统计**
- 解锁蓝图数量
- 收集卡牌数量
- 各稀有度卡牌统计

**进度统计**
- 最高关卡等级
- 总星数获得
- 完美通关数量

**经济统计**
- 纳米颗粒收入/支出
- 能量块收入/支出
- 最高持有量

**系统统计**
- 存档/读档次数
- 设置修改次数
- 成就解锁数
- 任务完成数

#### 统计API使用
```gdscript
var stats_mgr = get_node_or_null("/root/StatisticsManager")

# 记录游戏事件
stats_mgr.record_battle_result({
    "victory": true,
    "kills": 50,
    "damage_dealt": 10000,
    "battle_time": 120.0
})

stats_mgr.record_resource_change("nano", 1000, true)  # 获得资源
stats_mgr.record_collection_change("card", "legendary", true)  # 获得传说卡牌
stats_mgr.record_progress_change("level", 25)  # 到达25关

# 获取统计数据
var summary = stats_mgr.get_statistics_summary()
var combat_stats = stats_mgr.get_category_statistics(StatisticsManager.StatCategory.COMBAT)

# 生成统计报告
var report = stats_mgr.generate_statistics_report()
print(report)

# 导出统计数据
stats_mgr.export_statistics("user://my_statistics.json")
```

### 6. 版本管理器

#### 版本控制功能

**版本信息管理**
- 当前版本跟踪
- 版本历史记录
- 版本兼容性检查
- 数据迁移支持

**更新系统**
- 自动更新检查
- 更新下载管理
- 版本升级处理
- 回滚支持

#### 版本API使用
```gdscript
var version_mgr = get_node_or_null("/root/VersionManager")

# 获取版本信息
var version_info = version_mgr.get_version_info()
print("当前版本: ", version_info["version_string"])

# 检查更新
version_mgr.check_updates()

# 版本比较
var comparison = version_mgr.compare_versions("1.0.0", "1.1.0")
# 返回: -1 (小于), 0 (等于), 1 (大于)

# 兼容性检查
var compatible = version_mgr.is_version_compatible("1.0.0")

# 获取版本历史
var history = version_mgr.get_version_history()

# 生成诊断报告
var report = version_mgr.generate_diagnostic_report()
version_mgr.export_diagnostic_report("user://diagnostics.json")
```

### 7. 模组管理器

#### 模组系统

**模组功能**
- 模组发现和加载
- 依赖关系管理
- 冲突检测
- 版本兼容性验证
- 启用/禁用控制
- 模组模板创建

**模组结构**
```
mods/
├── my_mod/
│   ├── mod_info.json       # 模组信息
│   ├── mod_main.gd         # 主脚本
│   ├── content/            # 模组内容
│   └── assets/             # 模组资源
```

#### 模组API使用
```gdscript
var mod_mgr = get_node_or_null("/root/ModManager")

# 获取所有模组
var all_mods = mod_mgr.get_all_mods()

# 加载/卸载模组
mod_mgr.load_mod("my_mod")
mod_mgr.unload_mod("my_mod")

# 启用/禁用模组
mod_mgr.enable_mod("my_mod")
mod_mgr.disable_mod("my_mod")

# 安装/卸载模组
mod_mgr.install_mod("path/to/mod.zip")
mod_mgr.uninstall_mod("my_mod")

# 创建模组模板
var template_path = mod_mgr.create_mod_template("我的模组", "作者名")

# 模组验证
var is_valid = mod_mgr.validate_mod("my_mod")
var conflicts = mod_mgr.check_mod_conflicts("my_mod")

# 获取模组统计
var stats = mod_mgr.get_mod_statistics()
```

## 🔧 集成使用

### 游戏启动流程

```gdscript
# 游戏启动时自动调用
func _ready():
    # 1. 应用管理器自动初始化
    var app_mgr = get_node_or_null("/root/GameApplicationManager")

    # 2. 连接应用信号
    app_mgr.application_ready.connect(_on_application_ready)

    # 3. 等待应用就绪
    await app_mgr.application_ready

    # 4. 显示主菜单
    show_main_menu()

func _on_application_ready():
    print("游戏应用已就绪！")

    # 检查新版本
    var version_mgr = get_node_or_null("/root/VersionManager")
    version_mgr.check_updates()

    # 检查未读通知
    var notification_mgr = get_node_or_null("/root/NotificationManager")
    var unread_count = notification_mgr.get_unread_count()
    if unread_count > 0:
        show_notification_button()
```

### 战斗系统集成

```gdscript
# 战斗结束时记录数据
func on_battle_completed(battle_result):
    var stats_mgr = get_node_or_null("/root/StatisticsManager")
    var achievement_mgr = get_node_or_null("/root/AchievementManager")
    var notification_mgr = get_node_or_null("/root/NotificationManager")

    # 记录战斗统计
    stats_mgr.record_battle_result(battle_result)

    # 更新成就进度
    if battle_result.victory:
        achievement_mgr.record_battle_victory(battle_result)

        # 显示胜利通知
        notification_mgr.show_success("战斗胜利", "恭喜获得胜利！")
    else:
        notification_mgr.show_warning("战斗失败", "再接再厉！")

    # 自动保存
    var save_mgr = get_node_or_null("/root/SaveManager")
    save_mgr.perform_auto_save()
```

### 设置界面集成

```gdscript
# 创建设置界面
func create_settings_panel():
    var settings_mgr = get_node_or_null("/root/SettingsManager")

    # 音频设置
    create_audio_settings(settings_mgr)

    # 图形设置
    create_graphics_settings(settings_mgr)

    # 游戏设置
    create_gameplay_settings(settings_mgr)

    # 连接设置变化信号
    settings_mgr.setting_changed.connect(_on_setting_changed)

func _on_setting_changed(setting_name, old_value, new_value):
    print("设置变更: %s 从 %s 变为 %s" % [setting_name, old_value, new_value])

    # 应用设置变更
    match setting_name:
        "master_volume":
            apply_volume_change(new_value)
        "fullscreen":
            apply_fullscreen_change(new_value)
```

## 📊 性能优化

### 系统性能优化
- **延迟加载**: 按需加载系统组件
- **缓存机制**: 缓存常用数据
- **异步处理**: 避免阻塞主线程
- **批量操作**: 合并多个操作

### 内存管理
- **自动清理**: 定期清理过期数据
- **资源释放**: 及时释放不用的资源
- **内存监控**: 实时监控内存使用

## 🐛 故障排除

### 常见问题

**1. 应用启动失败**
- 检查必需的单例是否正确加载
- 验证系统文件完整性
- 查看错误日志

**2. 设置无法保存**
- 检查文件写入权限
- 确保目录存在
- 验证JSON格式

**3. 通知不显示**
- 检查通知管理器是否初始化
- 验证UI组件连接
- 确认音效设置

**4. 教程卡住**
- 重置教程进度
- 检查步骤条件
- 验证UI路径

**5. 模组加载失败**
- 检查模组兼容性
- 验证依赖关系
- 查看模组日志

## 🎉 总结

完善和强大的游戏应用系统为《Phase War》提供了：

### 核心优势
- ✅ **统一的应用管理**: 集中管理所有应用功能
- ✅ **丰富的设置选项**: 100+ 个可配置设置
- ✅ **智能通知系统**: 8种通知类型和优先级
- ✅ **完善的教程系统**: 交互式新手引导
- ✅ **详细的数据统计**: 6大类统计追踪
- ✅ **可靠的版本管理**: 自动更新和兼容性
- ✅ **灵活的模组支持**: 社区内容扩展

### 开发友好
- 📝 完整的API文档
- 🔧 易于集成和扩展
- 🛡️ 错误处理和恢复
- 📊 详细的诊断信息

这个应用系统为游戏提供了坚实的技术基础，大大提升了开发效率和用户体验！
