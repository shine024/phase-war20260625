# AI 关卡背景生成工作流（可复用）

> **用途**：当需要（重新）生成或调整战斗关卡背景图（`assets/backgrounds/bg_level_NN.png`）时，从 prompt 设计到出图、审核、部署、后处理的一站式流程。
> **建立日期**：2026-07-31 | **关联**：100 关现成 prompt 见 `docs/level_background_ai_prompts_1-100(生图).md`；卡图流程见 `docs/ART_PIPELINE_AI_ICON_GENERATION.md`
> **实战验证**：第一关背景迭代 8 版（v1-v8），本文档浓缩了全部踩坑经验。

---

## 一、背景系统现状（改之前必读）

| 项 | 现状 | 位置 |
|----|------|------|
| 背景图命名 | `bg_level_NN.png`（01~100） | `assets/backgrounds/` |
| 现有图尺寸 | 1376×768（实测） | — |
| 加载逻辑 | `Battlefield.gd` 按 `LEVEL_BG_PATH_FMT="res://assets/backgrounds/bg_level_%02d.png"` 异步加载，缺失按 era 回退到 `bg_level_01/02/03/default`，再不行程序生成渐变图 | `scenes/battlefield/Battlefield.gd:17,135-167` |
| 选关缩略图 | `world_map.gd` 用**同一格式串**显示关卡缩略图 | `scenes/world_map.gd:906` |
| 战斗车道 | 单条横向车道，X 范围 40~1240（宽 1200px），Y 车道带按背景纹理比例推导（`BATTLE_LANE_CENTER_RATIO=0.80`） | `scripts/card_grid_battle_layout.gd:8-13` / `Battlefield.gd:23-24` |
| 战斗视口 | 1280×580（底部 124px 留 HUD） | `scenes/main.tscn:97` |
| 三层构图（设计意图） | 上 65% 天空远景 / 中 20% 过渡带 / 下 15% 战斗车道 | `docs/level_background_ai_prompts_1-100(生图).md` |

**关键约束**：背景图只影响**视觉**，不影响实际可部署区域（那是代码里的固定槽位）。如果要让战场"实际加宽/加高"，必须同时改 `card_grid_battle_layout.gd` + `Battlefield.gd` 的部署范围，光换图没用。

---

## 二、API 配置

| 项 | 值 |
|----|-----|
| 端点 | `https://apihub.agnes-ai.cn/v1/images/generations` ⚠️ 注意是 `.cn`，与卡图流程文档里的 `.com` 不同 |
| 模型 | `agnes-image-2.0-flash` |
| Key 文件 | `tools/_api_keys_level1.txt`（3 个 key，脚本内轮换） |
| 推荐尺寸 | `1792x1024`（真 16:9，贴合原图 1376×768 比例）；`1536x1024` 次选；`1024x1024` 兜底 |
| 响应 | `data[0].url`（需二次 curl 下载）或 `data[0].b64_json`（直接解码） |

**请求体**（关键：负面词必须走**独立 `negative_prompt` 字段**，见 §4.2）：
```json
{"model":"agnes-image-2.0-flash","prompt":"...","size":"1792x1024","n":1,"negative_prompt":"..."}
```

---

## 三、Prompt 模板（第 1 关索姆河为范例）

### 3.1 固定结构（中性叙事 + 时代 + 势力配色）

```text
16:9 horizontal 2D mobile game scene, side-scrolling battlefield background.
ABSOLUTELY NO PEOPLE, NO SOLDIERS, NO HUMANS, NO FIGURES — EMPTY scenery background only.

LAYOUT (strict): GROUND / combat lane is the dominant element taking the lower three-quarters.
Sky COMPRESSED to a thin band at the top.
CRITICAL: MIDGROUND transition sits strictly ABOVE the ground lane, hugging the horizon line
from above — must NOT spill/drop/extend downward into the ground lane area.

SKY (thin): <天空描述 — 时代天气 + 远山 + 科幻电雾>
MIDGROUND (stays above horizon): <中景描述 — 时代地貌元素，贴在地平线上方>
COMBAT LANE (bottom 3/4, open & flat): single continuous flat ground band, straight
left-to-right, near side-view, sharp edges, unbroken, exactly ONE lane only.
ENTRY ZONES: both LEFT and RIGHT edges completely CLEAR — nothing blocks unit entry.
BOTTOM EDGE: only a VERY THIN scattering of tiny details along the bottommost edge.

Era: <时代>. <势力> style: <配色>. <时段光线>.
Narrative: Phase War Stage N "<关卡文案>" (no text, no people).
Style: bright, clean, polished 2D side-scrolling mobile game background, 16:9 horizontal.
```

### 3.2 时代 × 势力配色表（替换模板变量）

| 时代 | 势力 | 配色 |
|------|------|------|
| WW1（1-20） | Iron Wall Corp 钢壁防务 | steel-blue + earthy brown + khaki |
| WW2（21-40） | Nova Arms 新星兵工 | olive drab + rust orange + steel gray |
| Cold War（41-60） | Aether Dynamics 以太动力 | gunmetal + teal cyan + amber |
| Modern（61-80） | Quantum Forge 量子熔炉 | graphite + electric blue + neon green |
| Near-Future（81-100） | Void Research 虚空研究 | obsidian + violet + magenta |

### 3.3 完整负面词（直接复用，已扩写）

⚠️ **必须作为独立 `negative_prompt` 字段传，不要只拼在 prompt 文本里**（见 §4.2）。

```text
any person, people, human, humans, man, men, woman, women, soldier, soldiers, infantry,
troops, fighter, fighters, warrior, warriors, gunman, riflemen, officer, commander, scout,
human silhouette, human figure, human shape, human shadow, human face, face, head,
person standing/walking/running/crouching/kneeling, any humanoid form, limbs, arms, legs, torso, body,
enemies, monsters, creatures, animals, horses,
weapons held by figures, rifles, pistols, MP18, bayonets, swords,
combat effects, blood, corpses,
aircraft, airplanes, helicopters, drones, tanks, armored vehicles, warships, missiles,
skill VFX, muzzle flashes, explosions with debris,
UI, HUD, buttons, text, letters, numbers, watermark, logo,
curved road, S-shaped path, broken path, blocked lane,
midground spilling onto the lane, midground dropping into the ground,
vegetation growing down onto the lane, trench extending into the lane,
obstacles at the lane entries, barricades at the left/right edge, barbed wire blocking entry,
thick debris band at the bottom, wide crater strip, large rubble pile at the bottom,
huge sky, dominant sky, mostly sky,
top-down view, isometric, strong perspective distortion, fisheye,
photorealistic 3D render, unreal engine screenshot, dark horror, gore, blur,
low resolution, messy composition, duplicate lanes
```

---

## 四、关键经验（v1-v8 踩坑，★★★ 核心价值 ★★★）

> 以下是 8 轮迭代用真金白银的 API 调用换来的教训。**再生关卡背景前务必通读本节**，可省去 5-6 轮无效迭代。

### 4.1 模型几乎不执行"百分比数字"指令 ❌

**坑**：v1-v3 在 prompt 里写 `lane occupies about 30%/40%/50%`、`top 45%/55%`，结果 5 张图构图**几乎没变化**——模型读懂的只是"一战战场背景"这个大意，对空间百分比**基本无视**。

**解法**：
- 放弃百分比，改用**强视觉形容词**：`BROAD → VERY WIDE → MASSIVE → ENORMOUS → COLOSSAL`
- 或用**直白几何描述**：`horizon line at the upper third`、`ground takes the lower three-quarters`、`fills the whole lower half from left edge to right edge`
- 想要差异化（让多张图明显不同），每档必须用**截然不同**的描述档次，不是改数字

### 4.2 负面词必须走独立 `negative_prompt` 字段 ❌

**坑**：v2 把负面词当普通文本拼在 prompt 末尾（`Negative prompt: characters, ...`），模型把它当描述忽略了，人物/坦克照样出现。

**解法**：
- API 请求体里**单独** `"negative_prompt": "..."` 字段
- 自检方法：先发一个测试请求（如 `prompt="a red square", negative_prompt="red"`），看返回是否受负面词影响
- **文本里也保留一份**做双保险（部分端点只认字段，部分混用）

### 4.3 模型系统性把车道做小（约打 8 折）⚠️

**实测**（v5→v6）：要求"地平线在垂直中线 = 车道 50%"，模型实际只给了 **天空 50% / 中景 10% / 车道 40%**——系统性偏小。

**解法（反向超额）**：
- 想要车道 50% → 要求"地面占下 2/3"
- 想要车道 60% → 要求"地面占下 3/4"
- 想要车道 70%+ → 要求"地面占下 4/5 / 几乎全屏，地平线近顶部"
- 5 档把地平线**逐档往上推**，强制每张车道都比上一张大

### 4.4 中景容易挤进车道 ❌

**坑**：v7 把中景"加厚"，模型把过渡带（树林/废墟/战壕）往下挤进了车道区域，侵蚀可战斗地面。

**解法**：
- 硬约束：`midground sits strictly ABOVE the ground lane, hugging the horizon line from above`
- 明确：`must NOT spill, drop, or extend downward into the ground lane area`
- 中景与地面之间是 `clean horizon line`
- **不要无脑"加厚"中景**——加厚和"挤进车道"是连带风险，要同步加约束

### 4.5 人物会偷跑进来（即使负面词写了 soldiers）❌

**坑**：v7 负面词有 `soldiers, infantry`，画面还是出现了人。根因：prompt 里有一句 `Stage 1 — Infantry Squad · MP18`（关卡 roster 主题），可能误导模型画了步兵。

**解法（正面 + 负面双保险）**：
- **正面 prompt 开头连发**：`ABSOLUTELY NO PEOPLE, NO SOLDIERS, NO HUMANS, NO FIGURES... EMPTY scenery only... Nothing alive, nothing with a face, nothing humanoid`
- **负面词大幅扩写人物**：不只是 soldier/infantry，还要 person/people/human/man/woman/troops/fighter/officer/face/head/limbs/arms/legs/torso/body/person standing/walking/running 等（见 §3.3）
- **改写 roster 那句**：`do NOT depict the squad or the MP18 — scenery only`（原句是诱因）

### 4.6 左右车道入口易被障碍挡 ❌

**坑**：模型喜欢在画面左右两端（单位进出入口）放沙袋/铁丝网/木桩，挡住部署通道。

**解法**：
- 正面：`both LEFT and RIGHT edges of the lane are completely CLEAR and open — nothing blocks unit entry`
- 负面：`obstacles at the lane entries, barricades at the left/right edge, barbed wire blocking entry`
- 这类**空间位置约束**模型执行度有限，严重时需后处理（见 §6）

### 4.7 底缘装饰容易过厚 ❌

**坑**：v6 允许"底缘有点缀"，模型画了一大条弹坑/碎石带，占掉太多地面。

**解法**：
- 正面：`only a VERY THIN scattering of tiny details right along the bottommost edge`、`keep this band NARROW`
- 负面：`thick debris band at the bottom, wide crater strip, large rubble pile at the bottom`

### 4.8 临时故障：520 / 内容审核拒绝 / curl exit 28

| 故障 | 现象 | 解法 |
|------|------|------|
| Cloudflare 520 | `响应非 JSON: error code: 520` | 服务器临时故障，**换 key 重试**或等几秒重试（第4/5张常遇，换 key 即过） |
| 内容审核拒绝 | `无 data: Unable to generate this content` | 微调 prompt（可能某个词触发了审核），或换 key（不同 key 审核松紧不同） |
| curl exit 28 | 下载超时 | 加大 `--max-time`，或重试 |

**脚本必备**：每个候选 3 个 key 轮换重试 + 失败间隔递增（`time.sleep(4 + ki*2)`）。

### 4.9 尺寸 16:9 优先级

`1792x1024`（真 16:9，最贴合原图 1376×768）→ `1536x1024`（3:2）→ `1024x1024`（正方形，最后兜底）。自检时按此顺序试，第一个通的就用。

---

## 五、可复用生成脚本

| 脚本 | 用途 | 复用方式 |
|------|------|---------|
| `tools/generate_level1_bg_candidates_v8.py` | **最新最佳模板**（含本流程所有经验） | 改 `CANDIDATES` 列表的时代/势力/中景内容即可复用到其他关 |
| `tools/generate_level1_bg_candidates_v6.py` | 反向超额车道宽度参考（要宽车道时抄这版） | — |
| `tools/_api_keys_level1.txt` | 3 个 key | 用完可补充 |
| `docs/level_background_ai_prompts_1-100(生图).md` | **100 关现成 prompt**（纯文本，手动复制用） | 脚本化时把对应关的 prompt 块提取出来 |

**脚本核心结构**（照抄即可）：
```python
# 1. 载入 3 key + 轮换重试（应对 520/审核）
# 2. negative_prompt 走独立字段（§4.2）
# 3. 自检尺寸（1792x1024 优先，§4.9）
# 4. 每候选 3 key 各试一次，失败间隔递增
# 5. 输出到 docs/关卡候选_N张/ 供审核
```

---

## 六、后处理兜底（确定性，不依赖模型）★

> 文生图对"精确比例/绝对无人/入口清空"的执行有硬上限。**当 prompt 已优化到极限仍剩局部瑕疵时，用后处理脚本确定性修复，比继续生图碰运气可靠得多。**

| 瑕疵 | 后处理方法 |
|------|----------|
| 天空偏高 | 顶部裁切一截，或整体向下挤压（PIL `Image.crop` / resize） |
| 有小人影 | 局部擦除，用周围地形纹理覆盖（PIL 粘贴干净区块） |
| 中景挤进车道 | 把被挤那段的地面，从干净区域复制覆盖 |
| 入口有障碍 | 用画面中段的干净地面纹理，覆盖左右两端 |
| 底缘装饰太厚 | 把最底部薄薄一层裁掉 |
| 尺寸不对 | 等比缩放裁剪到 1376×768（与现有图一致） |

**部署到项目**：后处理完 → 保存为 `assets/backgrounds/bg_level_NN.png` → `Battlefield.gd` 和 `world_map.gd` 自动识别（无需改代码）。

---

## 七、复用 Checklist（新增/重做一关背景）

- [ ] 查 `docs/level_background_ai_prompts_1-100(生图).md` 取该关现成 prompt（时代/天气/势力配色）
- [ ] 用 §3 模板套该关变量（时代配色表见 §3.2）
- [ ] 负面词用 §3.3 完整版，走**独立 `negative_prompt` 字段**（§4.2）
- [ ] 车道宽度：按 §4.3 反向超额（想 50% 要 2/3，想 60% 要 3/4）
- [ ] 中景加 `hugging horizon from above, must NOT spill into lane`（§4.4）
- [ ] 正面 + 负面双保险禁人物（§4.5）
- [ ] 左右入口清空 + 底缘薄装饰（§4.6/§4.7）
- [ ] 脚本：3 key 轮换重试 + 自检尺寸（§4.8/§4.9）
- [ ] 输出到 `docs/关卡候选_N张/` 审核
- [ ] 剩余瑕疵用 §6 后处理确定性修复
- [ ] 部署为 `assets/backgrounds/bg_level_NN.png`（1376×768）
- [ ] Godot `--check-only` 验证无语法错误
