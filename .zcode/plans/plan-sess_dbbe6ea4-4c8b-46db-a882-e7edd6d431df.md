# 背包战斗卡不显示卡图 — 全面修复计划

## 根因分析

三个探索子代理交叉验证，确认**主根因是 `ResourceLoader.exists(path, "Texture2D")` 误用**。

Godot 4 的 `ResourceLoader.exists(path, mode)` 第二个参数应为 `CacheMode` 枚举（`CACHE_MODE_REUSE` / `CACHE_MODE_DONT_REUSE`），而非字符串 `"Texture2D"`。传入无效值导致存在性检查全部失败 → 图标路径返回空 → 纹理加载 null → 卡面空白。

### 影响链路
```
card_icon_path_for() 中 8 处 ResourceLoader.exists(..., "Texture2D") → 全部返回 false
→ card_icon_tex_path() 返回 ""
→ _get_cached_icon_texture("") 返回 null
→ icon_rect.texture = null + icon_rect.visible = false
→ CompactArtClip 内 Icon 不可见
→ 只显示纯色背景
```

---

## 修复项

### 1. ResourceLoader 参数修复（主修复，必做）

**文件**: `scripts/ui_asset_loader.gd`  
**位置**: `card_icon_path_for()` 方法内约 8 处 `ResourceLoader.exists(path, "Texture2D")`  
**修复**: 移除第二个参数，改为 `ResourceLoader.exists(path)`

| 行号 | 原代码 | 修复后 |
|------|--------|--------|
| ~373 | `ResourceLoader.exists(dedicated, "Texture2D")` | `ResourceLoader.exists(dedicated)` |
| ~385 | `ResourceLoader.exists(override_p, "Texture2D")` | `ResourceLoader.exists(override_p)` |
| ~410 | `ResourceLoader.exists(energy_by_id, "Texture2D")` | `ResourceLoader.exists(energy_by_id)` |
| ~417 | `ResourceLoader.exists(by_id, "Texture2D")` | `ResourceLoader.exists(by_id)` |
| ~424 | `ResourceLoader.exists(path, "Texture2D")` | `ResourceLoader.exists(path)` |
| ~431 | `ResourceLoader.exists(path, "Texture2D")` | `ResourceLoader.exists(path)` |
| ~201 | `_era_kind_fallback_path` 内类似调用 | 同上 |

**文件**: `scenes/ui/backpack_card_item.gd`  
**位置**: `_get_cached_icon_texture()` 第 1414 行  
**修复**: `ResourceLoader.exists(tex_path, "Texture2D")` → `ResourceLoader.exists(tex_path)`

> 注意：`FileAccess.file_exists(tex_path)` 在第 1411 行已正确检查文件存在，此处是冗余但错误的检查——两者逻辑冲突（file_exists=true 但 exists=false 导致缓存 null）。修复后两处都通过。

### 2. 布局高度微调（可选，建议一并修）

**问题**: IconRow 可用高度 132px，但内容需要 134px（CompactArtClip 90 + 间距 2 + CompactTextVBox 42），2px 赤字可能导致 VBoxContainer 压缩子节点。

**方案 A（推荐）**: 将 `COMPACT_BOTTOM_TEXT_H` 从 42 改为 **40**（减少 2px 赤字）  
- 文件: `backpack_card_item.gd` 第 21 行  
- 改动: `const COMPACT_BOTTOM_TEXT_H := 40`  
- 影响: stat-line 高度略减（原本 14+24=38px，现 14+22=36px），不影响可读性

**方案 B**: 减小 IconRow separation 从 2 到 **0**  
- 文件: `backpack_card_item.tscn` 第 63 行  
- 改动: `theme_override_constants/separation = 0`  
- 影响: CompactArtClip 和 CompactTextVBox 之间无间距

**采用方案 A**（改动最小，语义清晰）。

### 3. 缺失图标排查（可选，信息收集）

**发现**: 以下卡有 `.ctex` 编译产物但源 PNG 缺失：
- `cold_t72` → 由 `PLAYER_ICON_OVERRIDE["cold_t72"] = "vis_player_055"` 兜底显示
- `ww2_sherman` → 需检查是否有 override
- `mod_m1a1` → 需检查是否有 override
- `fut_scout_mech` → 需检查是否有 override

**结论**: 这些卡通过 `PLAYER_ICON_OVERRIDE` 或 `ERA_KIND_FALLBACK_ICON` 仍有兜底显示，不影响核心功能。仅当玩家希望看到精确对应卡图的场景才需补充源 PNG。

---

## 修改文件清单

| 文件 | 改动 |
|------|------|
| `scripts/ui_asset_loader.gd` | `card_icon_path_for()` 内 8 处 `ResourceLoader.exists(..., "Texture2D")` → `ResourceLoader.exists(...)` |
| `scenes/ui/backpack_card_item.gd` | `_get_cached_icon_texture()` 第 1414 行同修复；`COMPACT_BOTTOM_TEXT_H` 42→40 |
| （无需改动）`data/default_cards.gd` | 无 |
| （无需改动）`resources/card_resource.gd` | 无 |
| （无需改动）`scenes/ui/backpack_panel.tscn` | 无 |

## 验证步骤

1. Godot `--script` 模式语法检查（已有 `bp_syntax_check.gd`）
2. Grep 确认所有 `ResourceLoader.exists.*"Texture2D"` 已清除
3. 启动游戏，打开背包，验证战斗卡 Tab 有卡图显示
4. 检查不同时代卡（ww1/cold/mod/fut）是否都正常
5. 检查能量卡/法则卡是否不受影响

## 风险评估

- **极低风险**: 仅移除 `ResourceLoader.exists()` 的第二个参数，不改变任何逻辑流程
- `FileAccess.file_exists()` 在 `_get_cached_icon_texture()` 中已做前置检查，安全性不受影响
- 布局高度微调 2px 对视觉无实质影响