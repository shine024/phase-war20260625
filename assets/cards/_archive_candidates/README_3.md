# 卡框 v2 预览（程序化生成）

**规格**：500×800（5:8）、圆角 50px、中心全透明，颜色对齐 `game_constants.gd` → `get_rarity_color`。

| 文件 | 稀有度 | 线宽 | 特征 |
|------|--------|------|------|
| `frame_common.png` | 普通 | 12px | 金属渐变 + 角括号 |
| `frame_uncommon.png` | 优秀 | 14px | + 相位电路纹 + 内发光 |
| `frame_rare.png` | 稀有 | 16px | + 三重内沿 + 六边形晶格带 |
| `frame_epic.png` | 史诗 | 18px | + 四角宝石 + 高亮内rim |
| `frame_legendary.png` | 传说 | 22px | + 角翼/顶冠 + 星屑 + 金内沿 |

**预览图**

- `_preview_all_rarities.png` — 仅边框
- `_mockup_stacked.png` — 叠示例单位图（`elite_cold_t72`）

**重新生成**

```powershell
python tools/generate_card_frames_v2.py
python tools/generate_card_frame_mockup.py
```

**替换旧资源**：满意后可将本目录 `frame_*.png` 复制为 `assets/cards/frames/{common,uncommon,...}.png`（或改代码指向 `frames_v2`）。

旧版 AI 大图约 0.5–2.6 MB/张；v2 约 3–15 KB/张，更适合 UI 缩放。
