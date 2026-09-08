# Phase War 风格宪法（STYLE_BIBLE）

> 唯一权威源。任何生图（agnes/Flow）与资产修改动笔前先查本文档。
> 挑定方向：〔B 末世工业·荒芜史诗 为主锚，缝合 D 的青色 rim-light 恒定规则〕
> 依据：`docs/统一化/风格方向候选.md`（复审定稿 75604e2）· `resources/design_tokens.gd`（UI 色板唯一权威）· `tools/_agnes_image_api.md`（生图行为三轮实测）。2026-09-08 制定。
> 适用资产域：卡图立绘 356 张（白底→透明管线，占 96%，最大战场）· 战场背景 · 序章漫画 11 格 · 相位仪徽章（1024×1024 深底纹章，6 阵营族）· 基地房间三图管线（5 时代 × 3 图）· 后续一切新增生图。
> 串即法规：凡标〔卡图/场景/徽章〕的 prompt 片段只在其标注域内拼装，跨域拼装即违规（天空句进卡图串=灰天空=泛洪报废，此类事故见禁则章）。
> 参考系：《Frostpunk》冷灰蓝雪原 × 暖橙炉火 ·《This War of Mine》炭笔渲染 ·《FTL》宏大叙事插画。

## 一、色板（主色/辅色/点缀/禁用色，含 hex 值）

**与 UI token 的关系**：下表凡标「UI 共用」的色，数值以 `resources/design_tokens.gd` 对应常量为唯一权威（括注常量名），token 改动时本表必须同步修订；标「资产专用」的色只存在于生图 prompt 与调色 LUT，不进 UI 代码。资产层复用 UI 共用色的目的：画面固有色沉入 UI 底色、点缀色与 UI 强调色同一色环——卡图与 UI 从"两张皮"变成同一张皮。

### 主色（基调层，画面面积 60%~75%）

| 色 | hex | 用途域 | 用法 |
|----|-----|--------|------|
| 深空黑 | #0A121F | UI 共用 `COLOR_BG` | 一切深底呈现层（UI 底 / 徽章底 / 漫画夜空）；透明底卡图叠在其上，"背景"即此色 |
| 深灰蓝 | #2B3A4A | 资产专用 | 主体固有色基调：装甲板、钢构、雪原暗部、徽章底纹；允许一档明度带浮动（暗端 ≈#22303E，亮端 ≈#33455A） |
| 冷灰 | #808CA6 | UI 共用 `COLOR_SLATE_A80` | 次级金属面、雪面亮部、中景过渡（更亮一档 #99A8C7 = `COLOR_TEXT_DIM`） |

### 辅色（明度阶梯层，20%~30%——只做主色族的深浅，不引入新色相）

| 色 | hex | 用途域 | 用法 |
|----|-----|--------|------|
| 深渊黑 | #060912 | UI 共用 `COLOR_VOID` | 场景最暗部、门体暗面（比 UI 底更深一档的景深色） |
| 面板灰蓝 | #262B40 | UI 共用 `COLOR_PANEL` | 场景中景钢构、室内墙面中间调 |
| 冰天青 | #99D9FF | UI 共用 `COLOR_ICE_TEXT` | 雪面反光、阴天天空亮部；兼历史写实系卡图 rim 色（见第二章条件树） |

### 点缀色（对撞层，总面积 ≤15%——一图恰好一种暖色，紫青按语义取用）

| 色 | hex | 用途域 | 用法 |
|----|-----|--------|------|
| 暖橙 | #E69919 | UI 共用 `COLOR_ENERGY` | 唯一暖叙事光源：炉火 / 车灯 / 油灯 / 枪口焰 |
| 琥珀 | #F59E0B | UI 共用 `COLOR_AMBER` | 暖光源近核提亮档（同一橙谱系，不另起新暖色相；再亮一档 #FBBF24 = `COLOR_AMBER_SOFT`） |
| 黑门紫 | #8C59F5 | UI 共用 `COLOR_ACCENT_PURPLE` | 专属黑门 / 相位异常 / 生灵语义；兼 xeno 系卡图 rim（见第二章）——禁做装饰紫 |
| 霓虹青 | #00F0FF | UI 共用 `COLOR_ACCENT_CYAN` | 科幻系卡图 rim 与能量要素发光；UI 层恒定强调色 |

### 饱和度与对撞公式

- 全图饱和度中低（25%~40%），唯暖光源近核与紫晕允许高饱和小面积。
- **一图一冷暖对撞**：冷灰蓝世界 × 一点暖橙（现状序章漫画 b6"暖橙火光 × 冷紫门光"即合规样板）；暖色总面积 ≤15%。
- 时代差不换色相：五个时代的卡图共用本色板，时代识别度全部由装备细节与剪形表达（era 词插槽见第四章）。

### 禁用色（封闭清单）

| 禁用 | 为什么禁 |
|------|---------|
| 大面积高饱和绿（#22C55E 级亮绿 >10% 面积） | 不在"冷灰蓝 × 暖橙 × 紫"色环内；绿在 UI 是血量/提升语义（`COLOR_HEALTH` / `COLOR_GREEN_BRIGHT`），资产大绿块与 UI 语义抢戏；末世冷调世界里亮绿=植被生机=氛围破功。低饱和军械橄榄（军绿 / 卡其压冷后）视为主色合规变体，不在此列（橄榄是异色相，作合规变体处理，非明度带延伸） |
| 高饱和正红大面积（血红 / 红旗主导画面） | 红是 UI `COLOR_DANGER` 语义专属；资产暖点缀只走橙琥珀谱系；大面积红还会把 agnes 拉向血腥 gore 场景暗示 |
| 暖黄 / 卡其黄作主调（>30% 面积） | 违反"暖点缀 ≤15%"对撞公式——现状 ww1 步兵卡其黄高饱和暖调即整改对象（压冷归队） |
| 粉 / 品红 / 荧光黄等无 token 色 | 无 UI 锚点、无叙事语义，进来就是杂色——拼凑感回潮 |
| 大面积纯黑 #000000 / 纯白 #FFFFFF 色块 | 黑必须黑得发蓝（沉向 #0A121F / #060912）才与 UI 底同环，纯黑死块还违反暗部保细节规则；纯白大面积与白底转透明管线相撞（泛洪误抠风险，另见第五章第 12 条） |

### 色板章 prompt 片段（按域取用，可直接粘贴）

〔场景〕

```
muted cold palette of deep blue-grey steel and cold grey, one small warm
ember-orange accent, flat overcast sky
```

〔卡图〕基色句

```
muted cold palette of deep blue-grey steel and cold grey
```

〔卡图〕暖缀条件句——**仅当单位自带暖源时**写入对应载体词；无自然暖源则整句省略（空写暖缀=模型自造光源，白底上必出杂物）

```
plus one small warm amber glow from (muzzle flash / headlights / exhaust embers)
```

**hex 使用口径**：hex 未在 agnes 实测中验证过解析能力——串内一律以色名为准，hex 只作人读注释（deep blue-grey steel=#2B3A4A · cold grey=#808CA6 · ember-orange=#E69919）；批次④首跑做带/不带 hex 的 A/B 小样再定（附录一标定清单①）。

## 二、光线规则（主光源方向/对比度基调/氛围光）

### 基调（全资产通用）

- **环境主光：阴天漫射顶光**（overcast diffused light from above）——无硬直射阴影、无方向性投影；唯一的方向性光来自"叙事光源"。
- **叙事光源：一图恰好一个**——炉火 / 车灯 / 黑门晕 / 屏幕辉光，自带体积光晕（场景串内词，见下），它就是那一笔暖橙或紫晕的来源。
- 对比度中低：明暗层次投资在"主体 vs 灰蓝环境"，不做伦勃朗 chiaroscuro；**暗部近黑但不糊，保留 10%~15% 亮度细节**。
- 大气透视（仅场景）：远景沉入灰蓝雾（串词见下）。

### rim-light 缝合规则（D 规则收编为 B 的卡图细则，逐条可判定）

```
若 资产 = 卡图立绘（透明底精灵）：
    rim 恒定开——背光侧轮廓一道极窄冷 rim。
    这道 rim 是内容层与 UI 层的缝合线，不因单位时代而省略。

    单位族三档判定（自上而下，命中即停）：
    ① 外观写实度——外观为历史写实装备/载具者，无论前缀，一律归历史写实系。
       口径与候选文档 D 节对齐：vis 前缀中的写实系（写实坦克/步兵/载具，
       约 125 张 ×2 阵营）归历史写实系，不因 vis 前缀划入科幻系——
       写实坦克挂霓虹青 rim 与禁则 11 自怼。
       → rim 用冰天青 #99D9FF 档：极窄、无辉光，读作"阴天天光"而非能量。
    ② 前缀族——ww1/ww2/cold/mod 归历史写实系（同①档）；fe/fut/drop 及
       科幻外观单位（能量武器 / 装甲管线 / 舰体）归科幻系。
       → 科幻系 rim 用霓虹青 #00F0FF 档：允许轻微辉光，读作"相位辉光"，
         与 UI 青同语言；辉光只落在能量要素上，不做整圈 halo。
    ③ 发光要素——单位本体带黑门 / 生灵 / 相位异常语义（vis_xeno 异形系）。
       → rim 用黑门紫 #8C59F5 档：读作"黑门侵蚀"。
    兜底：三条都无法判定时，默认历史写实系冰天青档，并把该单位登记进
    人工复核清单——宁可 rim 保守，不可档位错挂。

    附则：rim 只勾背光侧一道，不整圈描光；装甲本体不发光——
    单位发光只出现在能量/相位/信息要素上（炮口、能量管线、屏幕），
    全发光 = 全一样 = 识别度归零。

    批次④动笔前，先按此优先级跑单位族全量标注/分档脚本，产出三档名单
    + 人工复核清单，名单定稿后才开始生图/调色（流程见附录一）。

若 资产 = 场景图（战场背景/雪原演出/基地房间/漫画格）：
    rim 不开——冷由阴天漫射与灰蓝雾表达，暖由唯一叙事光源表达；
    场景里画青 rim 会把实景变成"贴在 UI 上的一张图"。

若 资产 = 相位仪徽章：
    无光效 rim——青色以矢量勾线形式出现（现状纹章风全量保留，新徽章照此）。
```

（历史写实系分支即现状 ww1 步兵青蓝轮廓光的"雏形收编"；三档 rim 色见第一章点缀色表。）

### 光线章 prompt 片段

〔卡图〕主光句（全族通用）

```
overcast diffused lighting
```

〔卡图〕rim 句——按单位族三档换词（判定见上方条件树）：

```
历史写实系：one narrow cool sky-blue rim light along the back edge
科幻系：    one narrow cyan rim light along the back edge, faint glow
            limited to emissive parts
xeno 系：   one narrow faint violet rim light along the back edge
```

〔场景〕

```
single warm ember light source in a cold blue-grey world, volumetric glow
around the light source, aerial perspective, distant objects fade into
blue-grey haze
```

（`volumetric glow` 为**场景专用**——白底卡图上的软辉光会糊掉剪影边缘，与禁则 6 同理自怼。）

## 三、笔触与媒介（写实度/颗粒感/描边规则）

### 写实度标尺（1~5，目标档 = 4）

| 档 | 描述 | 判定 |
|----|------|------|
| 1 | 卡通平涂 / 矢量 | 禁 |
| 2 | 半写实 + 勾边（现状 ww1 步兵、fut_swarm 球舰） | 禁——重生对象 |
| 3 | 半写实厚涂无勾边 | 合格下限 |
| **4** | **厚重数字厚涂 + 全图颗粒**（thick painterly digital illustration + film grain） | **本宪法目标档** |
| 5 | 照片级写实 | 禁用于新生成（存量处置见附录一） |

### 颗粒感（具体到可执行）

- 场景：生图串内写 `film grain texture`——密度近似 ISO 800 胶片、粗细一档、覆盖全部画面内容。
- 卡图：**grain 词不进卡图串**——一律后处理叠加（flood_white_to_alpha 裁出主体后加噪，透明区不存噪点）；白底上生成颗粒会先污染泛洪边缘。泛洪容差 × 颗粒密度在批次④首跑标定（附录一标定清单②）。
- 颗粒家族三成员：胶片噪点（卡图后处理 / 场景串词）、版画排线刻线（漫画格；现状 vis_player_001 坦克的"刻线+点状肌理"同族可留）、硬边金属刮擦（机械表面）。

### 软硬对撞

烟雾 = 柔边喷枪（`soft airbrush smoke`，**场景串专用**——白底上喷烟雾=毛边+阻断泛洪），金属 = 硬边刮擦（`hard-edge scuffed steel`，措辞批次④首跑小样验证）——软硬笔触对撞是"工业温度感"的来源，只在有背景的场景里成立，卡图串不带烟雾词。

### 描边规则（透明底立绘）

- **无轮廓描边**：剪影由色块明度差 + rim 光定义，不由线条定义。
- 剪影边缘必须干净利落——透明底管线（flood_white_to_alpha 泛洪 + 脚锚连通域扫描）依赖干净边缘，毛边 / 雾边都不行。
- 本条只以规范条文存在：**`no outlines / no cel shading` 是概念否定词，严禁进 prompt 串**（反激活效应，见禁则 2）——串内用正面表述"以明度对比与 rim 光定义剪影"（见下方卡图串）。

### 媒介分资产

- 卡图：厚涂 + 后处理颗粒，无描边。
- 场景 / 漫画：厚涂 + 版画排线 + 颗粒（序章漫画 11 格已合规，零换血样板）。
- 相位仪徽章：扁平矢量纹章风（深灰蓝底 + 青勾线 + 放射底纹）——**不套厚涂**，徽章是纹章语言不是插画语言。
- 基地房间：厚涂 + 颗粒（三图管线 v3 prompt 骨架不变，换本章场景串风格词重跑）。

### 措辞红线

写 `oil-stained steel` 可以；写 `dusty / grimy / gritty / battle-worn` 会被 agnes 激活成垃圾满地（机制见第五章第 5 条）——质感词要落在"材质"上，不落在"破败"上。

### 笔触章 prompt 片段

〔卡图〕

```
thick painterly illustration, clean painterly silhouettes defined by value
contrast and a narrow rim light, smooth blended brushwork, hard-edge steel
surfaces
```

〔场景〕

```
thick painterly illustration, film grain texture, soft airbrush smoke against
hard-edge scuffed steel, clean painterly silhouettes defined by value contrast
```

（`scuffed` 首跑小样验证——若带出垃圾满地，降级为 `brushed steel / matte steel`，见附录一标定清单③。）

## 四、构图规则（卡图视平线/主体占比/背景虚化层级）

### 卡图立绘（356 张主战场；白底生成 → flood_white_to_alpha → 镜像配对 → 脚锚 → grain 后处理）

- **视平线**：卡图无画面内视平线——无地面无天空（`clean pure white background with NO ground`，结构性白名单词），视角取**平视全身侧面**（eye-level full body side view）；`perspective view` 是结构性排除词。超大型单位（巨舰 / 球舰）允许微仰视——串内写 `slight low angle`，幅度以不触发 perspective view 排除为限（微仰是机位倾斜，不是透视变形）。
- **朝向**：生图串一律写 `facing right`，**生成即朝右**；enemy 侧由 FLIP_LEFT_RIGHT 镜像产出，player 侧直出——同 ID 配对 player 朝右 / enemy 朝左。构图必须**翻转安全**（画面内禁文字 / 字母 / 带字旗帜徽标 / 单侧不对称符号）。
- **主体占比**：约 65%~80%；四周留 8%~15% 白边安全距（泛洪 + 裁切适配需要）；脚部完整落在画面内不裁切（白色椭圆脚锚是 `generate_card_foot_anchors.py` 后处理产物，不进生图）。
- **生成尺寸**：agnes 实测 1152x768（≈3:2）可用；卡图管线终态 512×512 透明底——1152x768 出图 → 裁切适配 → flood_white_to_alpha → 脚部锚 → grain 后处理叠加。
- **构图自由度**（透明底约束下投在哪）：全部投资在**姿态与装备细节**——待发 / 缓行静姿为主、装备完整可见；战斗动感由游戏内 VFX 承担，卡图是识别层不是动作帧。
- **背景虚化层级**：不存在——无背景即无层级，空间感由主体自身的明度阶梯（第一章辅色层）表达。

### 卡图构图片段——按单位族三档变体（era 词插槽置于句首，例 `WWII` / `near-future`）

〔卡图·历史写实系〕

```
WWII single military unit or vehicle, full body, eye-level side view, facing
right, historically accurate equipment detail, unit fills about three
quarters of the frame with even white margins, clean pure white background
with NO ground
```

〔卡图·科幻系〕

```
single hard-surface sci-fi unit or vehicle, full body, eye-level side view,
facing right, sleek angular panel lines, unit fills about three quarters of
the frame with even white margins, clean pure white background with NO ground
```

〔卡图·xeno 系〕

```
single alien creature, full body, eye-level side view, facing right, unit
fills about three quarters of the frame with even white margins, clean pure
white background with NO ground
```

（三档变体拼装时，rim 句按第二章条件树取对应档词。）

### 场景图（战场背景 / 雪原演出 / 基地房间 / 漫画格）

- **空旷公式**：荒芜与史诗感 = 空旷构图 + 比例差 + 单一暖光源，三者缺一不可；画面有机械 / 建筑时至少安排一处"小人物 vs 巨构"对比（视觉尺寸比 ≥1:10）。
- **视平线**：地平线压低（下 1/3 附近），天空占 40%~60%，天空必须是平坦阴天（禁戏剧云）。
- **背景虚化层级**：景深用**大气雾三段**表达——前景实（主体 / 结构）、中景灰蓝雾、远景沉入雾中；禁摄影镜头虚化（painterly 语言里没有 bokeh）。
- **漫画格**：一格一个视觉焦点（b6"火光焦点"即样板）。
- **徽章**：1024×1024 对称纹章构图、中心放射底纹。

〔场景〕构图串

```
vast empty composition, low horizon, flat overcast sky, monumental lone
industrial structure, one tiny human silhouette against huge machinery
```

〔场景·雪原专用〕锁意象（正面意象锁死，不写 no trash）

```
wind-carved snow fields, flat overcast sky, distant colossal black monolith
with faint violet halo
```

## 五、禁则（与挑定方向冲突的常见 AI 生图癖好清单）

封闭清单，共 12 条；每条附一句"为什么"。前 3 条为全 prompt 串共用的管线铁律（源自风格方向候选 §0）。

**共用管线三铁律**

1. 卡图串 backdrop 只写 `clean pure white background with NO ground`；黑底 / 深底 / studio backdrop 字样不进立绘串——管线是白底生成 + flood_white_to_alpha 转透明，深底字样让泛洪失效、抠图报废。
2. 负面词栏只写结构性排除 `text / perspective view / frame / ground / ceiling`——agnes 实测负面概念词反激活（"不要大象"效应），写"不要 X"反而把 X 画进画面；铁律 1 的 `NO ground` 与室内图的 `ceiling` 同属结构性白名单，其余概念词（含 `no outlines` 这类风格否定）一律不得入负面栏。
3. enemy 侧由 FLIP_LEFT_RIGHT 镜像产出（生成一律朝右）——画面内禁一切文字 / 字母 / 带字旗帜徽标 / 单侧不对称符号，因为翻转即穿帮（`text` 结构性排除同时服务于此）。

**风格词陷阱（agnes 三轮实测）**

4. 禁 `wasteland / desolate / bleak / ruined / post-apocalyptic` 废墟字面词——风格词自带场景暗示，会把瓦砾垃圾画进画面；荒芜改由空旷构图 + 比例差 + 单一暖光源表达（第四章公式）。
5. 禁 `gritty / dusty / grimy / somber / battle-worn` 破败质感词（含 `dusty olive` 这类色板词前缀）——同上，连色板词里的 dusty 都有垃圾暗示；要质感写 `oil-stained steel`、`stylized, muted palette of dark grey-brown and olive green`。
6. 卡图立绘禁 `heavy atmospheric haze / volumetric fog / mist`——体积雾毁透明底剪影边缘（泛洪 + 脚锚扫描都依赖干净边缘）；氛围雾只进场景串。

**画面内容**

7. 卡图禁地面 / 投影 / 场景元素进入生图——脚锚是后处理产物，生图画了地面就毁抠图。
8. 竖起的屏幕 / 挂画内容必须显式限定：`screens showing ONLY simple abstract glowing patterns, plain color readouts and flat graphic symbols (never detailed pictures or scenes)`——不限定时模型会在屏幕里画乱七八糟的具象画。
9. 卡图禁赛璐璐勾边 / 卡通粗描边 / 矢量平涂——三档质感漂移正是拼凑感主源（现状 ww1 步兵、fut_swarm 即重生对象）；此判定只写在规范与分档脚本里，不写进串。
10. 禁每图多于一个叙事光源——"一图一冷暖对撞"是 B 方向的构图公式本体，多光源 = 情绪稀释 + 拼凑感回潮。
11. 历史写实系单位（ww1/ww2/cold/mod 及 vis 写实系，判定见第二章优先级①）禁内容科幻化改型（加能量管线 / 发光装甲 / 全息 HUD）——时代识别度是卡牌系统的核心信息量，统一感不能以抹平时代差为代价；历史写实系的"相位感"只允许来自冰天青 rim 档。
12. 卡图主体内禁贴剪影边缘的大片纯白色块——泛洪从边缘起抠，贴边白块有被误抠成透明的风险（白只做高光点，不做面）。

---

## 附录一、存量适配与批次④复核流程

- **总量口径**（抽样外推，批次④前以分档脚本全量复核）：卡图 356 张——调色归队约 55%~60%（压冷 LUT + rim 后处理补齐 + grain 后处理叠加），重生成约 40%~45%（勾边 / 卡通 / 构图姿态不合格，含现状 ww1 步兵、fut_swarm）。
- **流程顺序**：①先按第二章判定优先级跑单位族全量标注/分档脚本（rim 三档 × 写实度档 × 朝向/翻转合规扫描），产出三档名单 + 人工复核清单；②名单定稿后才动生图/调色——禁止边判边画。
- **调色归队卡的 rim 口径（写死，无豁免）**：一律后处理补齐/改色——脚本批量 LUT 压冷 + 边缘检测按单位族档位叠对应 rim（冰天青 / 霓虹青 / 黑门紫）。理由：rim 是内容层与 UI 层的缝合线，新生图有 rim 而调色归队图没有 = 缝合线断一半，拼凑感回潮。
- **写实度档 3 存量**：已达合格下限，调色归队即可，不强制升档 4。
- **写实度档 5 存量（照片感）**：仅战场背景类存在——压冷 + 加雾调色保留，不再新增；卡图中发现照片感存量一律重生成。
- **批次④首跑标定清单**（小样先行，标定后才放量）：
  1. hex 带 / 不带 A/B 小样——agnes 无 hex 解析实测证据（第一章 hex 口径）。
  2. 泛洪容差 × 颗粒密度标定——grain 后处理叠加参数（第三章颗粒感）。
  3. `scuffed` 类做旧措辞小样——若带出垃圾满地，降级 `brushed steel / matte steel`（第三章场景串注）。

## 附录二、端到端拼装示例（批次④第一张卡照此拼，免现场发明）

〔例〕二战我方坦克卡——单位族 = 历史写实系（外观写实命中优先级①）→ 冰天青 rim 档

正面串：

```
WWII single military vehicle, full body, eye-level side view, facing right,
historically accurate equipment detail, unit fills about three quarters of
the frame with even white margins, overcast diffused lighting, one narrow
cool sky-blue rim light along the back edge, muted cold palette of deep
blue-grey steel and cold grey, thick painterly illustration, clean painterly
silhouettes defined by value contrast and a narrow rim light, smooth blended
brushwork, hard-edge steel surfaces, plus one small warm amber glow from the
headlights, clean pure white background with NO ground
```

负面栏（结构性排除白名单）：

```
text, perspective view, frame, ground, ceiling
```

拼装决策记录：era 插槽 = WWII（句首）｜单位族 = 历史写实系 → rim 句取冰天青档（第二章条件树①）｜暖缀 = headlights（坦克待发姿态自带车灯暖源，成立写入；若单位无自然暖源——如纯步枪步兵——暖缀句整句删除）｜朝向 = facing right（player 直出，enemy 由 FLIP 产出）｜出图 1152x768 → 裁切 512×512 → flood_white_to_alpha → 脚部锚 → grain 后处理叠加。

---

*本文档为批次④资产重生成的强制依据与后续一切生图 prompt 的拼装基础；与 `docs/统一化/风格方向候选.md`（已归档留查）冲突时，以本文档为准。*
