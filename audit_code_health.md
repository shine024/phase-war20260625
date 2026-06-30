# Phase War - 代码健康审计报告

**日期**: 2026-06-28
**项目路径**: D:\godotplay\godot fair duel\phase-war

## 概览

- 扫描脚本: 432 个 (项目代码, 不含 addons)
- 场景文件: 110 个
- 主场景: res://scenes/title_screen.tscn (存在)
- Autoload: 42 个 (全部 lazy *)
- res:// 引用: 478 个, 缺失 6 个
- TODO: 11, HACK/XXX: 10

## 问题清单

### 1. Godot 4 兼容性问题 (1处)
- `scenes/ui/help_panel.gd`: 使用 `TRANS_FADE` — Godot 4 已移除此枚举,fade 效果会自动处理

### 2. 缺失的资源引用 (6个)
- assets/sfx/button.ogg
- assets/unit_sprites/omega_platform.png
- audio/sfx/interface_sound.tres
- models/characters/player_model.tscn
- textures/ui/ui_theme.tres
- assets/backgrounds/*.png (通配符,实际有131个背景图)

### 3. 数据层 print() 调用 (2处)
数据文件中使用 print() 而非 push_warning(),热路径中会造成控制台刷屏

## 修复优先级

1. **P0** - 修复 scenes/ui/help_panel.gd 中的 TRANS_FADE
2. **P1** - 补全缺失的资源文件或修改引用路径
3. **P1** - 数据层 print() 改为 push_warning()
4. **P2** - 清理 TODO/HACK 标记
