# 卡框候选（程序化生成）

| 目录 | 风格 | 特点 |
|------|------|------|
| `set_a_neon/` | A 霓虹粗框 | 小格最醒目 |
| `set_b_heavy/` | B 重装镶边 | 双层色带 + 角饰 |
| **`set_c_luxe/`** | **C 华丽典藏 ★** | 金属渐变 + 相位电路 + 六边形带 + 角翼/顶冠/星屑 |

## 预览

- **`_mockup_set_c_luxe.png`** — C 套叠单位（推荐先看）
- **`_compare_b_vs_c.png`** — B 与 C 同稀有度对照
- `_preview_set_c_luxe.png` — C 五稀有度纯框

## 重新生成

```powershell
python tools/generate_card_frames_choice.py
```

## 部署到游戏

```powershell
Copy-Item assets\cards\frames_choice\set_c_luxe\*.png assets\cards\frames\ -Force
```

然后在 Godot 中对 `assets/cards/frames/` Reimport。
