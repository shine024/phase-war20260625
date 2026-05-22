# 势力底图候选

## Set v2 — 高区分（当前推荐预览）

| 目录 | 说明 |
|------|------|
| `set_distinct_v2/` | 8 张势力底 + neutral |

**预览文件**

- `_preview_factions_v2.png` — 8 张纯底图一览
- `_mockup_factions_v2.png` — 叠单位 + epic 框（接近游戏效果）
- `_compare_factions_old_vs_v2.png` — 旧版 vs 新版对照

**重新生成**

```powershell
python tools/generate_faction_backgrounds_v2.py
```

**部署到游戏**（确认满意后）

```powershell
Copy-Item assets\cards\backgrounds_choice\set_distinct_v2\*.png assets\cards\backgrounds\ -Force
```

然后在 Godot 中对 `assets/cards/backgrounds/` Reimport。

## 设计要点（相对旧版）

- 基色提亮（不再 14–30 的「纯黑」区间）
- 左右侧色带 + 顶部高光环，势力主色一眼可辨
- 中央大号纹章水印（盾/焰/涡轮/物流网/螺旋/虚空眼/联合星）
- 轻暗角（20%），保留 UI 上下安全条
