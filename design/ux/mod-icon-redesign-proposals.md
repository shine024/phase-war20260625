# 改造图标重设计方案（v37.2 候选 · 数据定稿后执行）

> 2026-09-17 调研。背景：用户重做改造分类与数据中；数据定稿前**不重生成图**，本稿先定方向。
> 前置现状：v37.1 已给所有显示点加了稀有度发光底座（ModIconTile，复用 tile_rarity_style 六色语言）——
> 本轮解决的是**图标本体**的风格问题。agnes 行为约束见 `tools/_agnes_image_api.md`（负面词反激活/
> 正面意象锁死/风格词自带场景暗示/屏幕内容必须显式限定），徽章域先例见 `STYLE_BIBLE.md` 6.4。

## 零、所有方案共守的四条铁律

1. **稀有度不进图**。稀有度一律由 v37.1 底座（边框+辉光六色）承载，图标本体保持稀有度中立——
   这是 WoW 以来的成熟惯例（稀有度染在框/底，不染物品本身），更是**工程寿命**：稀有度数值轮动、
   模块升档降档都只改数据，98+ 张图一张不用重生成。反例：把稀有度色烘进图 = 图数 ×6 且与底座语言打架。
2. **单一主体 + 70% 居中安全区**。最终最小显示位 18px（卡情报 ModsBlock）、主口径 26px——
   业界 32px 可读测试线之下，剪影存活率 > 细节数量。生成 1024²，内容实寸 PIL 标定，26px 下采样目检。
3. **族编码用"形状锚 +（可选）族色"双层**。10 模块族各定一个剪影锚（步兵=头盔 / 装甲=履带盾 /
   炮兵=曲射弹道 / 防空=雷达波弧 / 空军=机翼 / 工兵=扳手 / 工事=沙包垒 / 侦察=镜片 /
   通用=六角 / 强化=菱形晶体），族内变体靠主体差异（弹药族：穿甲弹头 vs 集束 vs 化学）。
4. **批量管线照徽章族旧例**：出图到 `docs/待生成徽章_改造图标_<批次>/` → 用户裁决 → 复制
   `assets/ui/icons/mod_icons/` → `--headless --editor --quit` 导入（`--import` 直跑崩）→
   `scripts/tools/update_mod_icons.py` 跑映射。先试点 2 族 8-10 张样张，批了再铺全量。

---

## 方案 A「军械剪影·类别色码」—— Tarkov / 坦克世界系

**语言**：单一军械主体高对比剪影（微厚涂，近白高光 + 深灰蓝暗部），无框无底，透明底贴图；
类别信息用**色码**表达（Tarkov 7.x 附件图标按类别整体染蓝的做法；WoT Equipment 2.0 的
火力/生存/机动四类白标也是同路数——白/单色主体 + 类别色点缀）。

**参考**：Escape from Tarkov 附件图标（类别色码）、World of Tanks Equipment 2.0（军事 stencil 语汇、
四类设备图标）、game-icons.net 军械类的剪影构图。

- agnes 策略：正面意象锁死——"single rifle optical sight, centered front view, clean flat
  shading in near-white and deep blue-grey, plain dark background, square emblem composition,
  no text"；屏幕/纹理限定句必带；负面词只留结构性。
- 优点：军事题材契合度最高；剪影在 18-26px 存活好；风格耐看不过时。
- 缺点：同族模块区分靠主体差异，prompt 逐条定制量大；"眼前一亮"上限中等（靠底座补光）。
- 适合：想要"硬核军武感"、接受逐张审核节奏。

## 方案 B「霓虹纹章·族徽」—— 项目 6.4 徽章族同源 ★推荐

**语言**：直接复用**相位仪徽章族 94 张已验证**的生成语言（STYLE_BIBLE 6.4 锚段原文）：
深空黑→深灰蓝径向渐变不透明底 + 霓虹发光勾线 + 能量光晕 + 对称纹章居中单一主体。
**族 = 勾线主色**（十族十色，从 DT 色板派生，与稀有度六色错开明度带），**功能 = 中心主体意象**；
高稀有度可加同心刻度环档位（aegis 表盘先例元素）。

**参考**：Warframe 模组卡（信息分层模板：边框=稀有度 / 角标=极性 / 数字=槽耗——我们对应
底座=稀有度 / 图形=族 / 名字行=功能，同一套"每层只说一件事"逻辑）、项目内 pi_* 徽章族（同引擎
同 prompt 同审核流，零新增管线风险）。

- agnes 策略：6.4 锚段照抄 + 族变体句换勾线色（umbra 族先例同法）——**prompt 模板现成、
  批量稳定性已被 94 张验证**，这是四案里管线风险最低的。
- 优点：与 v37.1 发光底座、相位仪徽章、全局霓虹 UI 语言无缝；发光内建，"亮眼"上限高；
  深底自带衬托，图标不再"暗贴图浮空"。
- 缺点：不透明深底方块与现状透明底混用需统一批切换；全员发光靠底座主次压噪（common 无光已就位）。
- 适合：想要"一眼惊艳"且接受整套切深底徽章风。

## 方案 C「极简功能标·双色扁平」—— game-icons / Destiny 系（性价比之王）

**语言**：浅灰白单色几何剪影 glyph，无底无光（光和色全交给 v37.1 底座），家族=SVG 源程序化染色。

**参考**：Destiny 2 护甲模组（纯几何 glyph + 极简，justrealmilk/destiny-icons 全集可作构图研究）、
game-icons.net（**4000+ 张 CC BY 3.0**，Lorc/Delapouite，军事/strategy 主题极全，署名即可商用——
common/uncommon 长尾可直接取材混编，立即见效）、Factorio 物品标的"小尺寸永远清晰"哲学。

- 来源两条腿：①game-icons.net 直接取材+署名（零生成成本）；②agnes 批量文生图扁平 glyph
  （"minimal flat pictogram, single symbol, two-tone"），SVG 化后按族色程序染色出全量。
- 优点：**对"数据未定稿"容错最强**——分类再改只重跑染色脚本秒级重出；18px 存活率四案最高；
  成本最低。
- 缺点：本体"惊艳"上限最低（发光感全靠底座）；与卡面厚涂风有风格距离——但 UI 图标本就该比
  场景资产抽象一档（32px 原则：剪影>细节）。
- 适合：想先快速见效、后续再升级；或与 B 混搭（低稀有度 C、高稀有度 B）。

## 方案 D「军械特写·厚涂」—— 卡面同源 / Monster Hunter 系（英雄化限定）

**语言**：与 356 张卡图立绘同族厚涂，军械局部特写 45° 斜置 + 单一冷暖对撞光源 + rim 三档。
**参考**：项目卡图家族本身、Monster Hunter 装饰品/技能珠（小图标承载厚涂质感的成功先例）。

- 优点：与卡面世界观统一度最高、质感上限最高。
- 缺点：agnes 成本与逐张审核量最大；18-26px 下厚涂细节糊成色块，可读性四案最差。
- **不建议全量**；建议只作为 mythic/legendary 少数"招牌改造"的英雄图标二期选项
  （10-20 张量级），与 B/C 底盘混搭。

---

## 建议（可拍板项）

| 档位 | 方案 |
|---|---|
| 全量底盘 | **B 霓虹纹章**（亮眼优先）或 **C 双色扁平**（成本/容错优先） |
| 混搭 | C 做全量 + B 只给 legendary/mythic（约 30-40 张）做发光徽章 |
| 二期可选 | D 英雄图标 10-20 张（mythic 招牌件） |

**流程承诺**：等你分类/数据定稿 → 我按最终分类出"族×意象词表"prompt 清单 → 试点 2 族样张
→ 你裁决 → 铺全量 + update_mod_icons.py 重映射 + 26px 缩放目检。

## 调研来源

- Warframe：[Logan Carr 模组系统设计分析](https://www.logancarrdesign.com/warframe-mods)、
  [Warframe Wiki: Mods/Polarity](https://wiki.warframe.com/w/Mod)、
  [Warframe Mod Maker（卡模板拆解）](https://warframemaker.com/)
- 图标库：[game-icons.net（CC BY 3.0，4000+）](https://game-icons.net/)
- 军武系：[WoT Equipment 2.0](https://worldoftanks.eu/en/news/general-news/1-10-equipment-2-0/)、
  [WoT UI Art 合集](https://www.pinterest.com/pin/world-of-tanks-ui-art-vol-3--747738344418032442/)、
  [Tarkov 附件类别色码讨论](https://www.reddit.com/r/EscapefromTarkov/comments/1uhwsjp/new_player_what_are_the_blue_icons_on_the_bottom/)
- 几何 glyph 系：[Destiny 2 mod 图标全集（GitHub）](https://github.com/justrealmilk/destiny-icons)、
  [light.gg Armor Mods](https://www.light.gg/db/armor-mods/)
- 规范：[32px 图标可读性](https://h-idris.com/blog/game-ui-icon-design)、
  [背包 UI 图标制作指南](https://morphic.com/resources/how-to/make-game-icons-for-inventory-ui)、
  [Cyberpunk 2077 稀有度色讨论](https://www.reddit.com/r/cyberpunkgame/comments/179qawk/ui_and_item_rarity_colors/)
