# 势力卡面底图（8 + 中立）

**规格**：500×800（5:8），与卡框、背包槽一致。  
**叠层顺序**（自下而上）：势力底 → 单位立绘 → 稀有度框 → UI 文字。

| 文件 | 势力 id | 说明 |
|------|---------|------|
| `bg_neutral.png` | `neutral` | 无势力 / 缴获卡默认 |
| `bg_iron_wall_corp.png` | `iron_wall_corp` | 钢壁防务 |
| `bg_nova_arms.png` | `nova_arms` | 新星兵工 |
| `bg_aether_dynamics.png` | `aether_dynamics` | 以太动力 |
| `bg_quantum_logistics.png` | `quantum_logistics` | 量子后勤 |
| `bg_helix_recon.png` | `helix_recon` | 螺旋侦察 |
| `bg_void_research.png` | `void_research` | 虚空相位 |
| `bg_frontier_union.png` | `frontier_union` | 边境联合 |

**预览**：`_preview_all_factions.png`

**重新生成**

```powershell
python tools/generate_faction_backgrounds.py
```

**代码**：`scripts/card_background_ui.gd` → `resolve_faction_id_for_card()`（当前缴获卡默认 `neutral`，进化分支势力可后续接 Blueprint 存档字段）。
