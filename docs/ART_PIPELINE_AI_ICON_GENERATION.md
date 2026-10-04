# AI 卡图自动生成工作流（可复用）

> **用途**：当新增卡牌单位缺少卡面图（`vis_enemy/player_NNN.png`）时，用本流程从代码到图片一键补全。
> **建立日期**：2026-07-16 | **验证状态**：已跑通 11 张（082~087 + 110~114）
> **关联文档**：规格规范见 `docs/ART_EXPORT_CHECKLIST_GREENSCREEN.md`；卡图审计见 `docs/CARD_ICON_AUDIT_2026-07-16.md`；审查清单见 `tools/enemy_card_review.html`

---

## 一、编号体系（分配规则）

卡面图命名 `vis_enemy_NNN.png`（敌方原图）/ `vis_player_NNN.png`（我方=水平翻转版），编号 NNN 按段分配：

| 段 | 编号范围 | 内容 | 文件位置 |
|----|---------|------|---------|
| A段 | 001~028 | 平台卡/新时代单位（FOE_PLATFORM 源ID） | enemy/ + player/ |
| B段 | 030~035 | 精英掉落卡（FOE_SPECIAL，029预留） | enemy/ + player/ |
| C段 | 036~071 | 固定敌人（含 Boss，36张） | enemy/ + player/ |
| D段 | 专属命名 | 补充池卡，用 card_id.png（非编号，如 ww1_inf_enfield.png） | enemy/ + player/ |
| E段 | 072~081 | 堡垒类别（10张） | enemy/ + player/ |
| **F段** | **082~087** | **平台卡变种（无源ID映射的 radar/scout/siege 等）** | enemy/ + player/ |
| 预留 | 088~109 | 待分配 | — |
| **G段** | **110~114** | **守护者成就卡（5张，各时代终极Boss奖励）** | enemy/ + player/ |

**编号分配原则**：
- 同段连续编号，预留空位给未来扩展（如 B段 029、F段 088~109）
- 新增卡图时取当前段最大编号 +1
- D段例外：用 card_id 直接做文件名（不走编号），适合数量不固定的补充池

---

## 二、图片规格（与现有 vis_001~081 完全一致）

| 项目 | 要求 |
|------|------|
| 尺寸 | **512×512** px |
| 模式 | **RGBA**（PNG，含 alpha 透明通道） |
| 背景 | **透明**（角落 alpha=0；AI 生成的是白底，部署脚本自动转透明） |
| 朝向 | 敌方图朝左（鼻/炮口/正面朝左边缘）；我方图=敌方图水平翻转 |
| 主体占比 | 约 70~90%，四周留 8~12% 边距，居中 |

---

## 三、完整工作流（5 步）

### 步骤 0：确认缺图

```bash
# 查看哪些 card_id 走 era_kind 通用回退（即缺专属图）
# 用 tools/probe_card_icon_usage_v2.gd 或对照 docs/CARD_ICON_AUDIT_2026-07-16.md
```

### 步骤 1：分配编号 + 配置代码映射

在 `scripts/ui_asset_loader.gd` 的 `PLAYER_ICON_OVERRIDE` 字典追加映射：

```gdscript
"card_id": "vis_player_NNN",   # 卡名 → 编号
```

**重要**：先检查该卡是否已有源ID映射（`enemy_unit_manifest.gd` 的 `_FOE_ID_TO_PLATFORM`）。若有，复用已有 001~028 编号，**不要**分配新编号。

### 步骤 2：生成图片

**前置依赖**：
- Python 3.10+
- API Key：`tools/_api_key.txt`（agnes-ai 图片生成 API）
- 可选 `numpy`（加速白底转透明，无则用纯 PIL fallback）

**生成脚本**：`tools/generate_missing_card_icons_11.py`（参考模板）

核心是调用 API：
```python
# API 端点
POST https://apihub.agnes-ai.com/v1/images/generations
Header: Authorization: Bearer <tools/_api_key.txt 内容>
Body: {"model":"agnes-image-2.0-flash","prompt":"...","size":"1024x1024","n":1}
# 返回 data[0].url，再 curl 下载图片
```

**Prompt 模板**（严格 2D 侧视 + 白底 + 科幻硬表面风格）：

```
STRICT_PREFIX = (
    "STRICTLY a pure 2D side profile silhouette view, absolutely NO front view, "
    "NO three-quarter view, NO perspective depth, flat orthographic game sprite, "
    "single subject only centered, clean pure white background with NO ground, "
    "NO shadow, NO floor, NO reflection, NO watermark, NO signature, NO text, "
    "NO extra sketches, NO character faces visible, NO environment, "
    "studio isolated product shot style. "
)
NEGATIVE = "不要：三分之四视角、斜侧视、透视 perspective、... 文字、水印、logo、人物。"

# 组合：<时代> <兵种> <单位名>，主体描述 + 轮廓清晰 + 主色 + 蓝色能量点发光 + 干净棚拍纯白背景
prompt = STRICT_PREFIX + (
    "<时代><单位名>，严格2D正侧视，正交投影，游戏单位立绘/精灵图姿态，"
    "科幻硬表面<兵种>设定图，以【<时代>·<兵种>】<单位名>为主体，"
    "完整单位居中入镜，<关键部件>轮廓清晰，<结构细节>结构明确，<磨损程度>，"
    "低饱和<主色>，局部蓝色能量<发光点>发光，干净棚拍纯白背景，无地面无场景无杂物，高清。" + NEGATIVE
)
```

**输出目录**：`docs/待生成卡图_11张/`（原始白底 1024×1024，供审核）

### 步骤 3：审核图片

打开 `tools/enemy_card_review.html` 在浏览器查看，或直接看 `docs/待生成卡图_11张/*.png`。
不满意 → 修改 prompt 重新生成单张。

### 步骤 4：部署（白底转透明 + 缩放 + 翻转）

**部署脚本**：`tools/deploy_card_icons_11.py`（参考模板）

对每张图执行：
1. 白底转透明（亮度 ≥240 → alpha=0，≤200 → alpha=255，中间平滑过渡）
2. 裁剪到内容边界 + 等比缩放到 512×512（居中，88% 留白）
3. 保存到 `assets/card_icons/enemy/vis_enemy_NNN.png`（原图）
4. 水平翻转保存到 `assets/card_icons/player/vis_player_NNN.png`（我方版）

### 步骤 5：手动修正后重新翻转

如果手动修了 `enemy/` 里的原图，需重新生成对应的 `player/` 翻转版：

```python
from PIL import Image
img = Image.open('assets/card_icons/enemy/vis_enemy_NNN.png')
flipped = img.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
flipped.save('assets/card_icons/player/vis_player_NNN.png', 'PNG')
```

---

## ⚠️ 硬约定：512×512 正方形 + 88% 留白（2026-08-15 踩坑）

卡图部署**必须**用 `deploy_card_icons_11.py` 的 `fit_square`（裁边 → 等比缩放到 88% → **居中填充到 512×512 正方形画布**，透明补边）。
自定义脚本若只裁边+等比缩放（产出 512×332 之类非正方形图），卡框叠加层与战场立绘会**拉伸变形且溢出边框**——整个消费体系（card_frame_ui/翻转图/战场脚部 anchor）都假定正方形。缩略图生成同理，不要对成品二次裁边。

## 四、注意事项（踩过的坑）

### 4.1 编号分配前先查源ID映射

**坑**：曾误以为 28 张 `platform_*` 卡全部缺图，分配了 082~109 新编号。
**真相**：22 张能通过 `_FOE_ID_TO_PLATFORM`（enemy_unit_manifest.gd）关联到已有 001~028 图。
**教训**：分配新编号前，必须先检查 `PLAYER_ICON_OVERRIDE` 和 `_FOE_ID_TO_PLATFORM`，能复用就不新建。

### 4.2 生成图是白底，现有图是透明底

**坑**：API 生成的图是 RGB 白底 1024×1024，直接放入项目会导致背景不透明。
**解决**：部署脚本做白底转透明（numpy 向量化处理，`brightness ≥240 → alpha 0`）。不要跳过此步。

### 4.3 敌方朝左，我方=翻转

**坑**：API 生成的图朝向不定，需在 prompt 强制"朝左"。
**规范**：`vis_enemy_NNN.png` = 原图（朝左）；`vis_player_NNN.png` = 水平翻转（朝右）。两者编号相同，仅前缀不同。

### 4.4 Python 后台运行无输出

**坑**：`python script.py` 放后台（run_in_background）日志一直为空。
**解决**：用 `python -u script.py`（unbuffered）前台运行，或加 `flush=True`。

### 4.5 修改 enemy 原图后需重翻 player

**坑**：手动修了 `enemy/vis_enemy_NNN.png` 后，`player/vis_player_NNN.png` 还是旧的翻转版。
**解决**：见步骤 5，对修改过的图重新做 `FLIP_LEFT_RIGHT`。

### 4.6 .import 文件

Godot 会为每个 PNG 生成 `.import` 文件。新图放入 `assets/` 后，下次用 Godot 编辑器打开会自动生成。headless `--check-only` 也会触发导入。无需手动创建 `.import`。

---

## 五、脚本索引

| 脚本 | 用途 |
|------|------|
| `tools/generate_missing_card_icons_11.py` | 调 API 生成卡图（模板，改 UNITS 列表即可复用） |
| `tools/deploy_card_icons_11.py` | 白底转透明+缩放+翻转部署（模板，改 FILES 列表即可复用） |
| `tools/gen_drone_icons.py` | 2026-08-17 无人机系列 5 张（fut_air_drone/fe_aether_swarm_queen/fut_swarm/fut_attack_drone/fut_nano_drone），card_id 直接做文件名（不走编号），同款模板 |
| `tools/deploy_drone_icons.py` | 上批配套部署：白底转透明+512+88%留白+敌我成对落盘 `enemy|player/{card_id}.png` |
| `tools/enemy_card_review.html` | 卡图审查清单（浏览器查看全部卡面，支持批量重生） |
| `tools/_api_key.txt` | API Key（agnes-ai 图片生成） |
| `tools/regenerate_7_sprites.py` | 旧版生成脚本（prompt 风格参考） |
| `tools/_b4_card_gen.py` | B4 批生成器：中文 STRICT 串+轴控制四件套+【单一主体·硬性】（正/负例都在 FAM/AXIS/POSE 表） |
| `tools/_b4_gain_loop.py` | 暗图 gain 收敛循环（raw 上迭代、单轮 ≤1.35、白点吸附、lit_gate 白底门） |
| `tools/_b4_regen_r2.py` | **R2 参考实现（2026-10-04）**：全英文 STRICT 串（PLAT_EN/CONVERT_EN/FAM_EN/AXIS_EN/POSE_EN 五表）+ 断点续跑 `.r2done` + 旧图转 `_raw_prev` + 审阅页快标清单驱动 |
| `tools/_b4_deploy.py` | B4 批部署：flood@238 泛洪+fit 512×0.88+player 直出/enemy 翻转+备份+md5 覆盖门 |
| `tools/_b4_review_page.py` | B4 暂存审阅页（中文名+描线/半身/星战风快标+重掷清单导出 `b4_regen_list.json`） |

---

## 七、agnes 提示词用法速查（2026-10-04 R2 轮 24 案实证，细则归 STYLE_BIBLE §6.1）

1. **英文提示词**（用户拍板）：同结构下英文出图更准；结构规则 1:1 保留（正交构图/单一主体/白底/厚涂/轴控）。
2. **视角写横纵轴描述，不写术语**：`orthographic side view` 控不准 → `the camera is exactly at the subject's own side, level with its midline; the subject's long axis stretches horizontally across the whole image, its upright parts stay vertical`；载具再加重叠句（履带/轮 overlap into one single line）——重叠句最灵。
3. **禁负面词**（写了=召唤）：mp18「严禁战场」三连败、「禁剪影」出剪影、「无描边」有描线风险；全部改写正向——白底=`seamless pure white studio background`、厚涂=`forms shaped by color masses and value transitions`。
4. **单一主体必须显式**：`exactly ONE subject in the whole frame; the white studio backdrop contains nothing else`，漏写则 16/30 案背景混车。
5. **星战先验塌缩**：泛化"装甲兵/板甲头盔"→暴风兵脸；写具体装具时代锚（modern modular tactical gear / fire-proximity suit / chitin exoskeleton）。
6. **贴边/裁切**：追加 `Zoomed-out wide framing: ... fully inside the frame, generous white space on all four sides ... far from the canvas edges.`
7. **暗图回收**：gain 收敛循环（无注入面）；**双图 relight 会把参考图内容注入，禁用**；单图 relight 仅兜底。
8. **朝向口径**（宪法版）：生成一律朝右 → player=直出、enemy=FLIP_LEFT_RIGHT（4.3 节为旧口径，新批次勿再按 enemy 直出生成）。
9. **部署配方**：`flood_white_to_alpha(238)`（边界泛洪，保主体内高光）→ `fit_square(512, 0.88)`（先泛洪后裁切，顺序不可倒）→ `.png.import` 由 `godot --headless --editor --quit` 生成（`--import` 直跑会崩）。

---

## 八、复用 Checklist（新增 N 张卡图）

- [ ] 确认缺图卡列表（对照 `CARD_ICON_AUDIT` 报告）
- [ ] 检查能否复用已有编号（查 `_FOE_ID_TO_PLATFORM` + `PLAYER_ICON_OVERRIDE`）
- [ ] 分配新编号（取段内 max+1，记录到本文档编号表）
- [ ] 复制 `generate_missing_card_icons_11.py` → 改名为 `_gen_<批次>.py`，修改 UNITS 列表
- [ ] 运行生成脚本，输出到 `docs/待生成卡图_<批次>/`
- [ ] 审核图片质量（浏览器查看）
- [ ] 复制 `deploy_card_icons_11.py` → 改名，修改 FILES 列表
- [ ] 运行部署脚本（自动转透明+缩放+翻转）
- [ ] 在 `ui_asset_loader.gd` 的 `PLAYER_ICON_OVERRIDE` 追加映射
- [ ] 补入 `tools/enemy_card_review.html` 审查清单
- [ ] 更新 `docs/CARD_ICON_AUDIT_*.md` 审计报告
- [ ] Godot `--check-only` 验证无语法错误
