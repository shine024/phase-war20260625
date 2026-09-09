#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""批次②禁用词扫描器——语言宪法第五章脚本化。

计划出处：docs/统一化/plans/2026-09-08-批次2-文案收编计划.md §2.3 / Task 1。
词表出处：docs/统一化/LANGUAGE_BIBLE.md 第五章（甲类 15 词条·绝对禁用／乙类 15 词条·
运营腔／丙类 24 词条·视语境速查索引——丙类变体的语境豁免细则以宪法第二章对应词条为准）。

扫描域（§2.3）：data/ scenes/ managers/ scripts/ 递归 *.gd ＋ data/json/*.json。

命中分级与计数口径：
  甲·必修     —— 甲类词条命中于字符串区（非注释、非名域、非豁免）→ 计入违规，退出码 1；
  乙·运营腔   —— 乙类词条命中于字符串区 → 计入违规；
  丙·视语境   —— 丙类变体命中于字符串区 → 计入违规（语境豁免除外，见下）；
  语境-机制豁免 —— 丙#7「敌人」命中行含机制标记（击杀/伤害/部署等，语气规则 3 双轨制：
                 战斗机制语境「敌人」合法，如「击杀 50 名敌人」）→ 不计数；
  名域-合法存量 —— 命中在条目名字段（UCT display_name/short_name/weapon_label/w_*、
                 改造 name/prototype、敌装备 name——宪法 v2.4 终局裁决「条目名全不动」，
                 卡名 231／short_name 76／改造名 202／敌装备名为合法存量）→ 不计数；
  白名单豁免   —— 宪法附录 C 豁免清单＋计划书 §2.3 所列（行号随工作树核实 2026-09-08）；
  INFO·注释    —— 命中在 .gd 注释区（非玩家可见文案）→ 不计数，单列备查。

用法：
  python tools/b2_scan_banned_words.py                      # 扫描＋stdout 报告
  python tools/b2_scan_banned_words.py --baseline docs/统一化/b2_baseline_scan.json
                                                            # 扫描＋基线存档 JSON
  python tools/b2_scan_banned_words.py --compare docs/统一化/b2_baseline_scan.json
                                                            # 对照基线出净差（新增/清除）
  python tools/b2_scan_banned_words.py --report docs/统一化/批次2-禁用词扫描报告.md
                                                            # 另存 markdown 报告

工程约束：Python 标准库 only；Windows 控制台强制 UTF-8 输出；解析套路沿用
tools/gen_term_mapping_draft.py / 已删 b2_propose_term_names.py（git 2c17aa0）的已验证正则。
"""

from __future__ import annotations

import argparse
import datetime as _dt
import json
import re
import subprocess
import sys
from pathlib import Path

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8")
if hasattr(sys.stderr, "reconfigure"):
    sys.stderr.reconfigure(encoding="utf-8")

ROOT = Path(__file__).resolve().parents[1]

# ─────────────────────────────────────────────────────────────────────────────
# 词表（逐词条自 LANGUAGE_BIBLE.md 第五章抄录；regex 前缀 r 表示带断言的变体式）
# 字段：cls(甲/乙/丙) idx(宪法表内序号) title words(pattern 列表) replace(建议替代)
#       note(语境/豁免/不可机扫注记) sample(仅计数不逐条列报——合法语境占绝对多数的词)
# ─────────────────────────────────────────────────────────────────────────────

WORD_ENTRIES: list[dict] = [
    # ── 甲类·已退役系统词（禁复活）——出处：宪法第五章甲类表 ──
    dict(cls="甲", idx=1, title="进化（系统整体退役）",
         words=["进化"],
         replace="新卡获取「制造」；节点语义「制造授权」；谱系「来源」",
         note="覆盖变体：形态进化/低进化/完整进化/谱系进化链/进化图纸（甲#2 门词另列，长词优先归并）"),
    dict(cls="甲", idx=2, title="进化战力门/进化情报基础门",
         words=["进化战力门", "进化情报基础门"],
         replace="门槛语义「制造条件」",
         note="与甲#1「进化」重叠——扫描按最长匹配归并到本词条"),
    dict(cls="甲", idx=3, title="手动强化/强化等级",
         words=["手动强化", "强化等级"],
         replace="「战斗卡等级」（card_level 1-30）",
         note="豁免：「全局强化」为活词（背包 Tab＋enhancement 改造族），本式不命中该词"),
    dict(cls="甲", idx=4, title="升星/星级强化/星级（玩家侧）",
         words=["升星", "星级强化", "星级"],
         replace="「等级／经验」",
         note="星级仅为等级派生视觉（card_level÷3），玩家侧文案不写；敌方内部轴 enhance_level 见甲#3"),
    dict(cls="甲", idx=5, title="合成/合成配方",
         words=["合成"],
         replace="「制造」", note="合成系统整体删除（2026-08-23 P2-7）"),
    dict(cls="甲", idx=6, title="科研点/研究点",
         words=["科研点", "研究点"],
         replace="技术解锁语境「情报」；泛指研究可作普通动词",
         note="research_points 退役"),
    dict(cls="甲", idx=7, title="法则（相位法则系统删除）",
         words=["法则"],
         replace="相位仪装配语义「符文」；「知识值」为现行活概念",
         note="覆盖变体：相位法则/法则卡/主动法则/红蓝槽法则；存量：default_cards.gd:226"),
    dict(cls="甲", idx=8, title="法则碎片/LawShard",
         words=["法则碎片", r"LawShard"],
         replace="「知识值」", note="LawShard 常量仅作兼容来源"),
    dict(cls="甲", idx=9, title="卡牌蓝图/副本/拆解",
         words=["蓝图", "副本", "拆解"],
         replace="蓝图语义「图纸」；副本「关卡」；拆解文案删除",
         note="卡牌蓝图体系整体删除（2026-08-22）"),
    dict(cls="甲", idx=10, title="敌源MOD/EOM",
         words=["敌源MOD", r"\bEOM\b"],
         replace="敌方增益揭示「情报」（stat_visibility）", note="EOM 按词边界匹配"),
    dict(cls="甲", idx=11, title="产能点/账号改造解锁集/相位师首杀解锁",
         words=["产能点", "账号改造解锁集", "相位师首杀解锁"],
         replace="无对应现行机制，文案一律不提", note="改造安装门槛＝「图纸＋纳米材料」"),
    dict(cls="甲", idx=12, title="能量卡/yellow 槽",
         words=["能量卡"],
         replace="相位仪槽位文案以现行 phase_instruments.gd 为准", note="能量卡系统移除"),
    dict(cls="甲", idx=13, title="爬塔",
         words=["爬塔"],
         replace="无尽征战语境「黑门 · 无限模式」（面板标题形）",
         note="宪法原文含单字「塔」——噪声不可机械判定，不作扫描式；爬塔模式移除（v6.0）"),
    dict(cls="甲", idx=14, title="相位师名册",
         words=["相位师名册"],
         replace="排行语境用现行 Tab 名「敌方相位师」", note="phase_master_roster 零引用死系统"),
    dict(cls="甲", idx=15, title="我方时代加成/时代缩放",
         words=["时代加成", "时代缩放"],
         replace="难度语义统一归「敌方难度链」", note="我方时代缩放停用（v6.8）"),

    # ── 乙类·出戏词（游戏运营腔，禁入叙事文案）——出处：宪法第五章乙类表 ──
    dict(cls="乙", idx=1, title="玩家/用户/指挥官",
         words=["玩家", "用户", "指挥官"],
         replace="「你」（叙述人称节立法；丙#1 勇士/旅行者同源另列）",
         note="存量：achievements_special.gd:42/:106（附录 C#7，批次② Task 10 修）"),
    dict(cls="乙", idx=2, title="氪金/充值/付费/首充/月卡/基金/通行证/战令",
         words=["氪金", "充值", "付费", "首充", "月卡", "基金", "通行证", "战令"],
         replace="本项目无内购，相关词汇一律不出现", note=""),
    dict(cls="乙", idx=3, title="签到", words=["签到"],
         replace="「每日勤务」", note="任务面板日常 Tab 语义"),
    dict(cls="乙", idx=4, title="福利/奖励/领取",
         words=["福利", "奖励", "领取"],
         replace="公司下发「补给」；战斗所得「缴获/战利品」；「领取」→「接收/下发」",
         note=""),
    dict(cls="乙", idx=5, title="活动", words=["活动"],
         replace="「委托」（公司语境）／「战时勤务」",
         note="常见词——命中逐条人工判语境（机械/日程语境误报可能）"),
    dict(cls="乙", idx=6, title="新手/老玩家", words=["新手", "老玩家"],
         replace="不作群体称呼，一律以「你」直述", note=""),
    dict(cls="乙", idx=7, title="删档", words=["删档"],
         replace="「清空档案」", note=""),
    dict(cls="乙", idx=8, title="开服/服务器/联网/掉线",
         words=["开服", "服务器", "联网", "掉线"],
         replace="禁入一切文案——世界观为深航车队单车回溯，无线上语境", note=""),
    dict(cls="乙", idx=9, title="版本更新/维护公告",
         words=["版本更新", "维护公告"],
         replace="系统层「更新日志」；叙事文案禁入", note=""),
    dict(cls="乙", idx=10, title="抽卡/卡池/十连/保底",
         words=["抽卡", "卡池", "十连", "保底"],
         replace="「制造」——新卡获取唯一通道（与甲#1 同源）", note=""),
    dict(cls="乙", idx=11, title="体力/疲劳值", words=["体力", "疲劳值"],
         replace="禁入（无对应系统）", note=""),
    dict(cls="乙", idx=12, title="限时/特价/折扣/促销",
         words=["限时", "特价", "折扣", "促销"],
         replace="「战时窗口」「军需价」；促销腔禁入", note=""),
    dict(cls="乙", idx=13, title="NPC", words=[r"\bNPC\b"],
         replace="具名角色直称（「公司联络人」「驻守相位师」等）", note="按词边界匹配"),
    dict(cls="乙", idx=14, title="道具", words=["道具"],
         replace="「物资／补给」", note=""),
    dict(cls="乙", idx=15, title="金币/钻石/点券",
         words=["金币", "钻石", "点券"],
         replace="资源全集见第二章五资源词条，不自造货币名", note=""),

    # ── 丙类·权威词汇表禁用变体速查索引（24 词条）——出处：宪法第五章丙类表；
    #     语境豁免与判定细则以第二章对应词条为准 ──
    dict(cls="丙", idx=1, title="叙述人称变体",
         words=["勇士", "旅行者"],
         replace="「你」", note="玩家/用户/指挥官已在乙#1（宪法丙表同列，归并去重）"),
    dict(cls="丙", idx=2, title="生灵变体",
         words=["精灵", "宠物", "召唤兽", "随从", "单位"],
         replace="「生灵」（第二章生灵条）",
         note="「单位」战斗机制语境合法（丙表自注）——合法语境占绝对多数，本扫描器仅计数不逐条列报；"
              "「伙伴（人称）」与丙#6 同列，归并至丙#6 扫描"),
    dict(cls="丙", idx=3, title="黑门变体",
         words=["黑暗之门", "魔门", "鬼门", "传送门"],
         replace="「黑门」（指本体时）", note="以裂隙/裂缝代称亦禁——裂缝/裂口见丙#15"),
    dict(cls="丙", idx=4, title="深航计划变体",
         words=["深渊计划", "远航计划", "深潜计划", "时光机计划", r"深航(?!计划)"],
         replace="「深航计划」", note="「深航」单用禁——负向断言排除全称"),
    dict(cls="丙", idx=5, title="相位师变体",
         words=["术士", "超能力者", "召唤师", "位相师", r"(?<!虚空)法师"],
         replace="「相位师」",
         note="「虚空法师」敌方专名豁免（附录 C#12 待裁决——负向断言排除）"),
    dict(cls="丙", idx=6, title="同伴变体",
         words=["队友", "好友", "朋友", r"伙伴(?!加油)"],
         replace="「同伴」",
         note="「伙伴加油」航空术语豁免（air_mods.gd:118 buddy refueling——负向断言排除）；"
              "存量违规：hero_archive_texts.gd:189/:65、quest_definitions.gd:574「新星伙伴」（附录 C#9/#10）"),
    dict(cls="丙", idx=7, title="迷失者变体",
         words=["叛徒", "疯子", "堕落者", "失忆者", "敌人"],
         replace="叙事语境「迷失者／迷失的同伴」",
         note="「敌人」战斗机制语境（击杀/伤害/计数）合法（语气规则 3 双轨制）——"
              "命中行含机制标记者自动标「语境-机制豁免」不计数"),
    dict(cls="丙", idx=8, title="相位仪变体",
         words=["相位器", "相位表", "手表", "终端", "法器", "宝具"],
         replace="「相位仪」", note="「终端」语境判定：机械/代码语境误报可能"),
    dict(cls="丙", idx=9, title="卡牌变体",
         words=["塔罗牌", "符卡"],
         replace="「卡牌／卡片／战斗卡」三分工（第二章卡牌条）",
         note="「卡」单字裸用禁——单字噪声不可机械判定，不作扫描式"),
    dict(cls="丙", idx=10, title="基地车变体",
         words=["余烬要塞", "房车", "大卡车", "营地", "要塞", "堡垒"],
         replace="「基地车／移动基地（装甲卡车驻地）」",
         note="「要塞/堡垒/营地」指基地车才禁——「堡垒」为合法兵种类名（combat_kind=4，"
              "计划书 Task 8 自注），语境逐条判；「余烬要塞」为确定性违规（附录 C#5，长词优先归并）"),
    dict(cls="丙", idx=11, title="时代变体",
         words=["纪元", "时期", "星球", r"世界(?!观)"],
         replace="「时代」（含回响）",
         note="「构装纪元/新纪元黎明」关卡 flavor 豁免（level_information.gd:299-303，白名单）；"
              "「世界观」术语排除；存量：lore_manager.gd:17「一战时期」（附录 C#13）"),
    dict(cls="丙", idx=12, title="时空乱流变体",
         words=["时间风暴", "时空风暴", "湍流", r"(?<!时空)乱流"],
         replace="「时空乱流」", note="「乱流」裸用禁——负向断言排除全称"),
    dict(cls="丙", idx=13, title="暗能量变体",
         words=["黑暗能量", "负能量", "邪能", "虚空能量"],
         replace="「暗能量」", note=""),
    dict(cls="丙", idx=14, title="星冥族变体",
         words=["外星人", "异形", "魔族", "星冥一族", r"(?<!星)冥族"],
         replace="「星冥族」", note="负向断言排除合法全称「星冥族」内的子串"),
    dict(cls="丙", idx=15, title="裂隙变体",
         words=["裂缝", "裂口", "虫洞"],
         replace="「裂隙」（三段式，第二章裂隙条）",
         note="存量：hero_archive_texts.gd:193/:69（附录 C#11）；「位面裂缝」另见丙#24（长词优先归并）"),
    dict(cls="丙", idx=16, title="黑日战线变体（新造地图名）",
         words=["百灯群岛", "沙漏双界"],
         replace="「黑日战线」（MAP_SCHEME=11 定稿）",
         note="「等一切新造地图名」不可穷举机扫，以现知两名为式；"
              "world_map.gd:347/:351 死路径行白名单单列 INFO"),
    dict(cls="丙", idx=17, title="公司变体",
         words=["军团", "商会", "国家", "政府", r"阵营(?!色)"],
         replace="「公司」（七公司全名逐字固定）",
         note="「阵营色」美术术语豁免（company_definitions.gd 注释语境——负向断言＋注释区双保险）"),
    dict(cls="丙", idx=18, title="兵种类名变体",
         words=["坦克兵", "医生", "狙击手", r"类型\s*\d", r"类型%d"],
         replace="兵种类名以第二章类名表为准",
         note="world_map.gd:2135「类型%d」程序容错兜底白名单豁免（非正式文案）；"
              "「医生」等职业词语境逐条判"),
    dict(cls="丙", idx=19, title="纳米材料变体",
         words=[r"纳米(?!材料)", "纳米物质", "基础材料"],
         replace="「纳米材料」（第二章资源词条）",
         note="「纳米」单用禁——负向断言排除全称；存量：faction_quest_generator.gd「声望+纳米」、"
              "bunker_room_defs.gd「纳米×200」；「材料」单用需语义判定（噪声不可机扫，不作扫描式）"),
    dict(cls="丙", idx=20, title="合金变体",
         words=["钢材", "钛合金", "钨合金", "金属"],
         replace="「合金」（资源专名）", note="「金属」泛指语境多——逐条判（钛合金/钨合金长词优先归并）"),
    dict(cls="丙", idx=21, title="晶体变体",
         words=["水晶", "宝石", "石英", "晶石"],
         replace="「晶体」", note="「能量水晶」另见丙#22（长词优先归并）"),
    dict(cls="丙", idx=22, title="能量块变体",
         words=["能量核心", "电池", "能量水晶", "能源块"],
         replace="「能量块」", note="甲#12「能量卡」另列"),
    dict(cls="丙", idx=23, title="星髓变体",
         words=["星核", "星尘", "髓晶", "星之髓"],
         replace="「星髓」", note=""),
    dict(cls="丙", idx=24, title="现实界/相位界/相位缝（方案 8 概念词）",
         words=["表界", "里界", "阳面", "阴面", "上位面", "下位面", "位面裂缝",
                "现实界", "相位界", "相位缝"],
         replace="三词本身不得作活概念（附录 B#4 正史待主会话裁决）",
         note="存量：achievement_definitions.gd:324、truck_base.gd:144——裁决前记违规、新文案禁引入"),
]

# 丙#7「敌人」机制语境标记（语气规则 3：战斗机制语境合法——击杀/伤害/计数等）
MECHANIC_MARKERS = (
    "击杀", "伤害", "部署", "射程", "攻击", "防御", "生命", "目标", "计数",
    "消灭", "敌方", "交战", "火力", "命中", "格挡", "拦截", "波次",
)

# 白名单豁免（宪法附录 C 豁免清单＋计划书 §2.3；行号 2026-09-08 对当前工作树核实；
# content_key 为行内容校验锚——行号漂移时内容不符则不豁免，宁误报不漏报）
WHITELIST: list[dict] = [
    dict(file="data/modification_modules/air_mods.gd", lines=range(116, 121),
         content="伙伴加油", reason="航空术语 buddy refueling 豁免（宪法附录 C；模式级负向断言双保险）"),
    dict(file="data/level_information.gd", lines=range(297, 305),
         content="纪元", reason="关卡 flavor「构装纪元/新纪元黎明」豁免（宪法附录 C）"),
    dict(file="scenes/world_map.gd", lines=range(2133, 2138),
         content="类型", reason="「类型 N」程序容错兜底显示，非正式文案（宪法附录 C）"),
    dict(file="scenes/world_map.gd", lines=[347],
         content="沙漏双界", reason="MAP_SCHEME=8 死路径（附录 B#4 定稿 11）——INFO 单列不计违规（计划书 §2.3）"),
    dict(file="scenes/world_map.gd", lines=[351],
         content="百灯群岛", reason="MAP_SCHEME 兜底死路径——INFO 单列不计违规（计划书 §2.3）"),

    # ── 批次③ Task 4 增补（2026-09-09）——名域/退役机制/开发件/迁移日志 ──
    dict(file="data/faction_skill_tree.gd", lines=[221],
         content="法则共鸣", reason="技能节点条目名（v2.4 名不动裁决；裁决 B 仅描述层生效）"),
    dict(file="data/phase_instruments.gd", lines=[26],
         content="法则共鸣", reason="相位仪条目名 pi_r_law_boost（v2.4 名不动裁决）"),
    dict(file="data/phase_instruments.gd", lines=[94],
         content="法则共鸣：所有法则效果", reason="desc 回显条目名+退役法则机制效果（pi_r_law_boost 随法则系统退役）"),
    dict(file="data/level_information.gd", lines=[75],
         content="法则家族限制", reason="构建函数头注（开发文档，非玩家文案）"),
    dict(file="data/level_information.gd", lines=[127],
         content="法则家族限制", reason="_add_ww1 系 docstring 设计备注（开发文档）"),
    dict(file="data/level_information.gd", lines=[178],
         content="法则家族限制", reason="_add_ww2 系 docstring 设计备注（开发文档）"),
    dict(file="data/level_information.gd", lines=[229],
         content="法则家族限制", reason="_add_cold 系 docstring 设计备注（开发文档）"),
    dict(file="data/level_information.gd", lines=[278],
         content="法则家族限制", reason="_add_modern 系 docstring 设计备注（开发文档）"),
    dict(file="data/level_information.gd", lines=[296],
         content="物理法则", reason="科学用语「物理法则」合法（宪法 §5.4；计划书 Task 4 Step 3）"),
    dict(file="data/level_information.gd", lines=[471],
         content="法则家族", reason="API docstring（开发文档；法则家族 gate 已随 P2-7 退役）"),
    dict(file="data/level_information.gd", lines=[477],
         content="法则家族", reason="API docstring（开发文档；法则家族 gate 已随 P2-7 退役）"),
    dict(file="data/intel_manual_items.gd", lines=[382],
         content="无效蓝图ID", reason="push_warning 开发日志（非玩家文案）"),
    dict(file="data/intel_manual_items.gd", lines=[406],
         content="进化蓝图解析失败", reason="push_warning 开发日志（非玩家文案）"),
    dict(file="data/intel_manual_items.gd", lines=[417],
         content="未知的蓝图类型", reason="push_warning 开发日志（非玩家文案）"),
    dict(file="managers/battle/battle_manager.gd", lines=[333],
         content="相位师排名星级", reason="push_warning 开发日志（非玩家文案）"),
    dict(file="managers/daily_task_manager.gd", lines=[366],
         content="USE_PHASE_LAWS", reason="退役枚举残留实例标签（load_state 已过滤，死路径）"),
    dict(file="managers/evolution/card_evolution_manager.gd", lines=[254],
         content="E2进化目标", reason="push_warning 开发日志（非玩家文案）"),
    dict(file="managers/intel_item_bag.gd", lines=[64],
         content="无效蓝图类型", reason="push_warning 开发日志（非玩家文案）"),
    dict(file="managers/intel_item_bag.gd", lines=[75],
         content="无效蓝图类型", reason="push_warning 开发日志（非玩家文案）"),
    dict(file="data/evolution_paths/__init__.gd", lines=[72],
         content="无进化路径", reason="退役存根 fail-closed 文案（v26.8 进化退役，零 UI 消费）"),
    dict(file="data/evolution_paths/__init__.gd", lines=[85],
         content="强化等级不足", reason="退役存根 fail-closed 文案（强化① v20.12 退役，零 UI 消费）"),
    dict(file="data/evolution_paths/__init__.gd", lines=[87],
         content="未找到目标进化节点", reason="退役存根 fail-closed 文案（零 UI 消费）"),
    dict(file="scripts/systems/save_migration.gd", lines=[193],
         content="数量为负", reason="迁移校验错误日志（开发诊断，非玩家文案）"),
    dict(file="scripts/systems/save_migration_v4.gd", lines=[129],
         content="强化等级变化", reason="v3→v4 迁移日志（退役轴的历史迁移，开发诊断）"),
    dict(file="scripts/systems/save_migration_v9.gd", lines=[15],
         content="产能点", reason="v9 no-op 迁移体日志（v25.3 退役说明，开发诊断）"),
    dict(file="scenes/tools/card_ui_preview.gd", lines=[150],
         content="单卡蓝图", reason="开发预览工具非玩家可达（计划书 Task 4：不动）"),
    dict(file="scenes/tools/card_ui_preview.gd", lines=[224],
         content="合成", reason="开发预览工具非玩家可达"),
    dict(file="scenes/tools/card_ui_preview.gd", lines=[226],
         content="法则", reason="开发预览工具非玩家可达"),
    dict(file="scenes/tools/card_ui_preview.gd", lines=[234],
         content="星级显示", reason="开发预览工具非玩家可达"),
    dict(file="scenes/tools/card_ui_preview.gd", lines=[453],
         content="单卡真实蓝图", reason="开发预览工具非玩家可达"),
    dict(file="scenes/tools/card_ui_preview.gd", lines=[652],
         content="合成", reason="开发预览工具非玩家可达"),
    dict(file="scenes/tools/card_ui_preview.gd", lines=[654],
         content="法则", reason="开发预览工具非玩家可达"),
]

# 名域字段行判定（宪法 v2.4 终局裁决：条目名全不动——命中标注「名域-合法存量」不计数）
RE_NAME_FIELD_UCT = re.compile(
    r'"(?:display_name|short_name|weapon_label|w_light|w_armor|w_air)"\s*:')
RE_NAME_FIELD_MODS = re.compile(r'^\s*(?:name|prototype)\s*=')          # name_en 由 \s*= 排除
RE_NAME_FIELD_JSONISH = re.compile(r'"name"\s*:')                        # 敌装备等 JSON 式字典条目名

NAME_DOMAIN_FILES = {
    "data/unified_card_table.gd": RE_NAME_FIELD_UCT,
    "data/modification_modules/air_mods.gd": RE_NAME_FIELD_MODS,
    "data/modification_modules/armor_mods.gd": RE_NAME_FIELD_MODS,
    "data/modification_modules/artillery_mods.gd": RE_NAME_FIELD_MODS,
    "data/modification_modules/anti_air_mods.gd": RE_NAME_FIELD_MODS,
    "data/modification_modules/engineer_mods.gd": RE_NAME_FIELD_MODS,
    "data/modification_modules/enhancement_mods.gd": RE_NAME_FIELD_MODS,
    "data/modification_modules/fort_mods.gd": RE_NAME_FIELD_MODS,
    "data/modification_modules/recon_mods.gd": RE_NAME_FIELD_MODS,
    "data/modification_modules/universal_mods.gd": RE_NAME_FIELD_MODS,
    "data/enemy_equipment_armor_modules.gd": RE_NAME_FIELD_JSONISH,
}

# 扫描域（§2.3）
SCAN_DIRS = ("data", "scenes", "managers", "scripts")
JSON_GLOB = "data/json/*.json"

TOOL_VERSION = "1.0.0"


def _read(path: Path) -> str:
    try:
        return path.read_text(encoding="utf-8")
    except UnicodeDecodeError:
        return path.read_text(encoding="utf-8-sig")


def _rel(path: Path) -> str:
    return path.relative_to(ROOT).as_posix()


def collect_files() -> list[Path]:
    files: list[Path] = []
    for d in SCAN_DIRS:
        base = ROOT / d
        if not base.is_dir():
            continue
        files.extend(sorted(base.rglob("*.gd")))
    files.extend(sorted(ROOT.glob(JSON_GLOB)))
    return files


def _comment_start(line: str) -> int:
    """返回行内第一个位于字符串外的 '#' 下标（无则 -1）——.gd 注释区判定。"""
    quote = None
    i = 0
    while i < len(line):
        ch = line[i]
        if quote:
            if ch == "\\":
                i += 2
                continue
            if ch == quote:
                quote = None
        elif ch in ('"', "'"):
            quote = ch
        elif ch == "#":
            return i
        i += 1
    return -1


def _compile_entries() -> list[dict]:
    out = []
    for e in WORD_ENTRIES:
        pats = [re.compile(w) for w in e["words"]]
        out.append({**e, "patterns": pats})
    return out


# sample 词标记（宪法丙表自注：合法语境占绝对多数，报告仅计数不逐条列报）
for _e in WORD_ENTRIES:
    if _e["cls"] == "丙" and _e["idx"] == 2:
        _e["sample"] = True  # 「单位」

_ENTRIES = _compile_entries()


def scan_line(line: str) -> list[dict]:
    """单行扫描：全词条候选 → 最长匹配归并（跨词条重叠子串归长词）→ 返回命中。"""
    cands = []
    for e in _ENTRIES:
        for pat in e["patterns"]:
            for m in pat.finditer(line):
                cands.append((m.start(), m.end(), e, m.group(0)))
    cands.sort(key=lambda c: (c[0], -(c[1] - c[0])))
    kept, spans = [], []
    for c in cands:
        if any(c[0] < s[1] and c[1] > s[0] for s in spans):
            continue  # 子串重叠——已被更长词归并
        spans.append((c[0], c[1]))
        kept.append(dict(start=c[0], end=c[1], entry=c[2], word=c[3]))
    return kept


def _whitelist_reason(rel: str, lineno: int, line: str) -> str | None:
    for w in WHITELIST:
        if w["file"] == rel and lineno in w["lines"] and w["content"] in line:
            return w["reason"]
    return None


def _name_domain(rel: str, line: str) -> bool:
    rx = NAME_DOMAIN_FILES.get(rel)
    return bool(rx and rx.search(line))


def scan_file(path: Path) -> list[dict]:
    rel = _rel(path)
    is_json = path.suffix == ".json"
    hits = []
    for lineno, line in enumerate(_read(path).splitlines(), start=1):
        cstart = -1 if is_json else _comment_start(line)
        for h in scan_line(line):
            e, word = h["entry"], h["word"]
            if cstart >= 0 and h["start"] > cstart:
                status = "INFO-注释"
            elif _name_domain(rel, line):
                status = "名域-合法存量"
            else:
                wl = _whitelist_reason(rel, lineno, line)
                if wl:
                    status = "INFO-死路径" if "死路径" in wl else "白名单豁免"
                    h["reason"] = wl
                elif e["cls"] == "丙" and e["idx"] == 7 and word == "敌人" \
                        and any(mk in line for mk in MECHANIC_MARKERS):
                    status = "语境-机制豁免"
                else:
                    status = {"甲": "甲·必修", "乙": "乙·运营腔", "丙": "丙·视语境"}[e["cls"]]
            hits.append(dict(
                file=rel, line=lineno, cls=e["cls"], entry=f'{e["cls"]}#{e["idx"]} {e["title"]}',
                word=word, status=status, context=line.strip()[:78]))
    return hits


def run_scan() -> tuple[list[dict], int]:
    files = collect_files()
    hits: list[dict] = []
    for p in files:
        try:
            hits.extend(scan_file(p))
        except (OSError, UnicodeDecodeError) as exc:  # 单文件失败不中断全扫
            print(f"[WARN] 跳过 {p}: {exc}", file=sys.stderr)
    return hits, len(files)


def summarize(hits: list[dict]) -> dict:
    def n(status):
        return sum(1 for h in hits if h["status"] == status)
    by_cls = {c: sum(1 for h in hits if h["cls"] == c and h["status"].startswith(c))
              for c in ("甲", "乙", "丙")}
    return {
        "jia_must_fix": n("甲·必修"),
        "yi_ops_tone": n("乙·运营腔"),
        "bing_contextual": n("丙·视语境"),
        "mechanic_exempt": n("语境-机制豁免"),
        "name_domain_legal": n("名域-合法存量"),
        "whitelist_exempt": n("白名单豁免"),
        "dead_path_info": n("INFO-死路径"),
        "comment_info": n("INFO-注释"),
        "by_class_counted": {"甲": by_cls["甲"], "乙": by_cls["乙"], "丙": by_cls["丙"]},
    }


def print_report(hits: list[dict], n_files: int, max_per_entry: int = 6) -> None:
    s = summarize(hits)
    print("== 批次② 禁用词扫描报告（b2_scan_banned_words.py）==")
    print(f"词表：甲 15 ／ 乙 15 ／ 丙 24（出处 docs/统一化/LANGUAGE_BIBLE.md 第五章）")
    print(f"扫描域：data/ scenes/ managers/ scripts/ *.gd ＋ data/json/*.json —— {n_files} 文件")
    print("—— 汇总 ——")
    print(f"  甲·绝对禁用（必修）  ：{s['jia_must_fix']}")
    print(f"  乙·运营腔            ：{s['yi_ops_tone']}")
    print(f"  丙·视语境            ：{s['bing_contextual']}（另有语境-机制豁免 {s['mechanic_exempt']} 不计数）")
    print(f"  名域-合法存量        ：{s['name_domain_legal']}（条目名字段，v2.4 终局裁决不改——不计数）")
    print(f"  白名单豁免           ：{s['whitelist_exempt']}｜INFO-死路径：{s['dead_path_info']}｜INFO-注释：{s['comment_info']}")
    for cls in ("甲", "乙", "丙"):
        entries = [e for e in WORD_ENTRIES if e["cls"] == cls]
        print(f"—— {cls}类明细（每词条至多列 {max_per_entry} 条；sample 词仅计数）——")
        for e in entries:
            # 以 entry 全名精确匹配（防 甲#1 / 甲#10 前缀撞车）；注释 INFO 保留在计数外、展示时跳过
            tag = f"{cls}#{e['idx']}"
            eh = [h for h in hits if h["entry"] == f"{tag} {e['title']}"]
            if not eh:
                continue
            counted = [h for h in eh if h["status"].startswith(cls)]
            skipped = len(eh) - len(counted)
            print(f"[{tag} {e['title']}] 命中 {len(eh)}"
                  f"（计违规 {len(counted)}｜名域/豁免/机制 {skipped}）替代→ {e['replace']}")
            if e.get("sample"):
                print("    （sample 词：仅计数，合法语境占绝对多数——明细见基线 JSON）")
                continue
            shown = 0
            for h in eh:
                if h["status"].startswith("INFO-注释"):
                    continue
                if shown >= max_per_entry:
                    print(f"    ……另有 {len(eh) - shown} 处（含注释 INFO），见基线 JSON")
                    break
                print(f"    {h['file']}:{h['line']} 『{h['word']}』 {h['status']} ｜ {h['context']}")
                shown += 1
    print("—— 退出码 ——")
    print(f"  {'1（存在甲类必修级违规）' if s['jia_must_fix'] else '0（无甲类必修级违规）'}")


def _git_head() -> str:
    try:
        return subprocess.run(["git", "rev-parse", "HEAD"], cwd=ROOT,
                              capture_output=True, text=True, timeout=10,
                              encoding="utf-8").stdout.strip()
    except Exception:
        return ""


def write_baseline(hits: list[dict], n_files: int, path: Path) -> None:
    s = summarize(hits)
    doc = {
        "meta": {
            "tool": "tools/b2_scan_banned_words.py", "tool_version": TOOL_VERSION,
            "generated_at": _dt.datetime.now().isoformat(timespec="seconds"),
            "git_head": _git_head(),
            "files_scanned": n_files,
            "word_source": "docs/统一化/LANGUAGE_BIBLE.md 第五章（甲15/乙15/丙24）",
            "note": "批次②净收益对照基线（计划书 Task 1 Step 1）；--compare 按本档出净差",
        },
        "summary": s,
        "hits": hits,
    }
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(doc, ensure_ascii=False, indent=1), encoding="utf-8")
    print(f"\n[OK] 基线已存档：{path.as_posix()}（{len(hits)} 条命中记录）")


def _hit_key(h: dict) -> tuple:
    # 以 (file, word, context) 为身份键——行号随编辑漂移，内容键更稳
    return (h["file"], h["word"], h["context"])


def compare_baseline(hits: list[dict], path: Path) -> None:
    if not path.is_file():
        raise SystemExit(f"[FATAL] 基线文件不存在：{path.as_posix()}")
    old = json.loads(path.read_text(encoding="utf-8"))
    old_keys = {_hit_key(h) for h in old.get("hits", [])}
    new_keys = {_hit_key(h) for h in hits}
    added = [h for h in hits if _hit_key(h) not in old_keys]
    removed = [h for h in old.get("hits", []) if _hit_key(h) not in new_keys]
    os_, ns = old.get("summary", {}), summarize(hits)
    print(f"== 对照基线净差（基线 {path.as_posix()}，{old.get('meta', {}).get('generated_at', '?')}）==")
    for k, label in (("jia_must_fix", "甲·必修"), ("yi_ops_tone", "乙·运营腔"),
                     ("bing_contextual", "丙·视语境"), ("name_domain_legal", "名域-合法存量")):
        print(f"  {label}：{os_.get(k, 0)} → {ns[k]}（净差 {ns[k] - os_.get(k, 0):+d}）")
    print(f"  新增命中 {len(added)} 条／清除命中 {len(removed)} 条")
    for tag, lst in (("新增", added), ("清除", removed)):
        for h in lst[:50]:
            print(f"  [{tag}] {h['file']}:{h['line']} 『{h['word']}』 {h['status']} ｜ {h['context']}")
        if len(lst) > 50:
            print(f"  [{tag}] ……另有 {len(lst) - 50} 条")


def write_md_report(hits: list[dict], n_files: int, path: Path) -> None:
    s = summarize(hits)
    lines = [
        "# 批次2 禁用词扫描报告", "",
        f"- 生成：{_dt.datetime.now().isoformat(timespec='seconds')}｜工具 `tools/b2_scan_banned_words.py` v{TOOL_VERSION}",
        f"- 词表出处：`docs/统一化/LANGUAGE_BIBLE.md` 第五章（甲 15／乙 15／丙 24）",
        f"- 扫描域：data/ scenes/ managers/ scripts/ *.gd ＋ data/json/*.json（{n_files} 文件）", "",
        "## 汇总", "",
        "| 分级 | 计数 | 口径 |", "|---|---|---|",
        f"| 甲·绝对禁用（必修） | {s['jia_must_fix']} | 计入违规，退出码 1 |",
        f"| 乙·运营腔 | {s['yi_ops_tone']} | 计入违规 |",
        f"| 丙·视语境 | {s['bing_contextual']} | 计入违规（语境-机制豁免 {s['mechanic_exempt']} 另计不数） |",
        f"| 名域-合法存量 | {s['name_domain_legal']} | 条目名字段（v2.4 不改）不计数 |",
        f"| 白名单豁免/INFO-死路径/INFO-注释 | {s['whitelist_exempt']}/{s['dead_path_info']}/{s['comment_info']} | 不计数 |", "",
    ]
    for cls in ("甲", "乙", "丙"):
        lines.append(f"## {cls}类明细")
        lines.append("")
        for e in [e for e in WORD_ENTRIES if e["cls"] == cls]:
            eh = [h for h in hits if h["entry"] == f"{cls}#{e['idx']} {e['title']}"]
            if not eh:
                continue
            counted = sum(1 for h in eh if h["status"].startswith(cls))
            lines.append(f"### {cls}#{e['idx']} {e['title']}——命中 {len(eh)}（计违规 {counted}）")
            lines.append(f"- 替代写法：{e['replace']}")
            if e["note"]:
                lines.append(f"- 注记：{e['note']}")
            lines.append("")
            if e.get("sample"):
                lines.append("- （sample 词：仅计数，明细见基线 JSON）")
                lines.append("")
                continue
            lines.append("| 文件 | 行 | 词 | 分级 | 上下文 |")
            lines.append("|---|---|---|---|---|")
            for h in eh:
                ctx = h["context"].replace("|", "\\|")
                lines.append(f"| {h['file']} | {h['line']} | {h['word']} | {h['status']} | {ctx} |")
            lines.append("")
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("\n".join(lines), encoding="utf-8")
    print(f"\n[OK] markdown 报告已写出：{path.as_posix()}")


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description="批次②禁用词扫描器（宪法第五章脚本化）")
    ap.add_argument("--baseline", metavar="PATH", type=Path,
                    help="扫描并存档基线 JSON（批次②净收益对照）")
    ap.add_argument("--compare", metavar="PATH", type=Path,
                    help="对照既有基线 JSON 出净差（新增/清除）")
    ap.add_argument("--report", metavar="PATH", type=Path,
                    help="另存 markdown 报告（默认 docs/统一化/批次2-禁用词扫描报告.md）")
    ap.add_argument("--max-per-entry", type=int, default=6,
                    help="stdout 明细每词条至多列 N 条（默认 6；基线 JSON 存全量）")
    args = ap.parse_args(argv)

    hits, n_files = run_scan()
    print_report(hits, n_files, max_per_entry=args.max_per_entry)

    if args.report:
        write_md_report(hits, n_files, args.report)
    if args.baseline:
        write_baseline(hits, n_files, args.baseline)
    if args.compare:
        compare_baseline(hits, args.compare)

    return 1 if summarize(hits)["jia_must_fix"] else 0


if __name__ == "__main__":
    sys.exit(main())
