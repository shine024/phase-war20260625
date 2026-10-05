# -*- coding: utf-8 -*-
"""MK12 攻击动画整体重做批（2026-10-05）：用户裁定 86 标记项的攻击条
「攻击姿势不对、火位置不对」——全部走生图重生成，逐格动作脚本按目验重设计。

流程（每单位）:
  anchor  现役 idle f0 贴品红底 → img25_staging/<key>_anchor_raw.png（身份=现役待机）
  gen     img25_attack_gen.py --rolls 2 --cells-json（逐格脚本+火位硬条款）
  audit   idle f0 + 两掷 832 缩样对比图 → .godot/unit_review/mk12_out/<key>.png（目验选优）
  deploy  选优掷次经 _mk8_deploy.deploy_sheet（256 横条+烘描边+counts）覆写现役

用法: python tools/_mk12_attack_redo.py anchor|gen|audit|deploy [key...]
  gen 不带 key = 全队列（日志 mk12_gen.log）；deploy 需带 key+掷次 key:R
"""
import io
import json
import os
import subprocess
import sys
import types

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
UA = os.path.join(ROOT, "assets", "effects", "unit_anims")
OUT = os.path.join(ROOT, ".godot", "unit_review", "img25_staging")
AUD = os.path.join(ROOT, ".godot", "unit_review", "mk12_out")
os.makedirs(OUT, exist_ok=True)
os.makedirs(AUD, exist_ok=True)


def load(name, path):
    src = open(path, encoding="utf-8").read()
    lines = [ln for ln in src.splitlines()
             if not ln.strip().startswith("sys.stdout = io.TextIOWrapper")]
    mod = types.ModuleType(name)
    mod.__file__ = path
    exec(compile("\n".join(lines), path, "exec"), mod.__dict__)
    return mod


# ── 重设计配置（2026-10-05 全 65 案目验后裁定；9 案火位/大小合格不入批）──
# fire=格3 开火描述；muzzle=火光只允许出现的位置；smoke=格5；prep=格2；
# extra=追加硬条款；small=人型小动作条款；cells=整组覆盖（特殊动作）
C = {}
V_FX = "火光和烟只贴在{mz}，完整位于本格内部，绝不触碰格子边缘，绝不画在车体/炮架其他部位，绝不在主体上方空中漂浮。"


def veh(key, name, subject, fire, mz, smoke="炮口涌出灰白硝烟向左缓缓飘散",
        prep="炮身微微后缩蓄力；", extra=None):
    C[key] = dict(name=name, subject=subject,
                  cells={2: prep, 3: fire, 4: "火光衰减成一小簇火舌；", 5: smoke,
                         6: "回到与格1完全一致的中性待机，烟散尽（首尾闭合）。"},
                  fx=V_FX.format(mz=mz), extra=extra)


def inf(key, name, subject, fire, mz, extra=None):
    C[key] = dict(name=name, subject=subject, small=True,
                  cells={2: "武器微微贴肩蓄力，站姿不变；", 3: fire,
                         4: "火光消散，枪口冒出细烟；", 5: "一枚小弹壳向右后方弹出；",
                         6: "回到与格1完全一致的瞄准待机（首尾闭合）。"},
                  fx=V_FX.format(mz=mz), extra=extra)


# ── 冷战 ──
veh("cold_arm_btr_e", "BTR-60", "冷战苏联BTR-60八轮装甲运兵车，绿漆车体，车顶中央有一座小型炮塔，炮塔正面伸出一挺细机枪，面朝画面左侧",
    "机枪口爆出短促橙黄色火光，车身微微一颤", "车顶炮塔的机枪口（车体顶部中央）",
    smoke="枪口冒出细烟向左飘，一枚黄豆大小的小弹壳向右上方弹出",
    extra="弹壳必须极小（黄豆大小），绝不画成黑色圆球；硝烟只从机枪口出现，绝不出现在车体后上方。")
veh("cold_arm_t55", "T-55", "冷战苏联T-55中型坦克，圆形炮塔，细长主炮管从炮塔向画面左侧伸出，炮口在画面左端",
    "炮口爆发橙白色大炮口焰，明亮但不遮掩车身", "炮管末端的炮口")
veh("cold_arty_brem1", "BREM-1", "冷战苏联BREM-1装甲抢修车：绿漆履带车体、车首（画面左侧）装铲刀式推土铲、车体上架着一根细长的起重臂指向画面左上方（与锚定帧完全一致的角度和位置）",
    "起重臂前端爆出短促橙黄色火光", "起重臂的前端（画面左上方）",
    smoke="前端冒细烟",
    extra="六格车体完全一致且与锚定帧同款；车上绝不出现任何士兵、乘员或人物；全车唯一的火光是起重臂前端的很小橙黄色火光，火光必须贴着起重臂前端，绝不悬在空中，车体和铲刀上绝不出现火光。")
C["cold_arty_brem1"]["small"] = True   # MK12 round3：车体姿态锁死（生图两轮都把起重机抬成炮管）
veh("cold_bradley", "M113", "越战样式美军M113履带装甲输送车，橄榄绿迷彩低矮车体，车顶前部支架上架着一挺重机枪，面朝画面左侧",
    "车顶重机枪口爆出短促橙黄色火光", "车顶前部重机枪的枪口（贴着枪管）", smoke="枪口冒细烟",
    extra="枪口必须贴在车顶机枪架上，绝不变成悬浮在车顶上方的空中火球。")
veh("cold_inf_btr60", "BTR-60", "冷战苏联BTR-60八轮装甲车，橄榄绿车体，车顶中央小型炮塔正面伸出一挺机枪，面朝画面左侧",
    "机枪口爆出短促橙黄色火光", "车顶炮塔机枪口", smoke="枪口细烟，弹壳向右上方弹出")
inf("cold_spetsnaz", "特种部队", "身穿深灰色作战服、戴战斗盔的冷战特种兵，双手端突击步枪指向画面左侧，站立瞄准姿态",
    "枪口爆出短促橙黄色枪口焰", "步枪枪口")
veh("cold_sup_bmp1_x", "BMP-1", "冷战苏联BMP-1步兵战车，低矮楔形车体，车顶中央小炮塔伸出一根细长的73mm炮管指向画面左侧",
    "炮口爆发橙白色中等的炮口焰", "细长炮管最左端的炮口开口",
    extra="火光紧贴在画面最左端的炮口开口上；六格车体形状、绿色涂装和亮度完全一致。")
veh("cold_t72", "T-72", "冷战苏联T-72主战坦克，低矮圆炮塔，长主炮指向画面左侧，履带车体",
    "炮口爆发橙白色大炮口焰，明亮但不遮掩车身", "主炮末端的炮口")
# ── 掉落/家族能量系 ──
C["drop_phase_lance"] = dict(
    name="刺刀突击班", small=True, subject="穿黄褐色军大衣、戴钢盔的士兵，双手端一把细长的反装甲能量长枪指向画面左侧",
    cells={2: "长枪口出现聚集的白色光点；", 3: "枪口爆出一团拳头大小的明亮白色能量爆发，贴在枪口",
           4: "能量爆发消散，枪口残留细小电弧；", 5: "白色细烟向左飘散；",
           6: "回到与格1完全一致的瞄准待机（首尾闭合）。"},
    fx="只有枪口的白色能量爆发；绝不出现灰色圆环或烟圈悬浮在枪身上方。")
C["drop_thunder_field"] = dict(
    name="雷霆突击班", small=True, subject="穿深蓝色动力装甲的士兵，双手端一把电弧步枪，枪身缠绕青色能量导管，指向画面左侧",
    cells={2: "枪口青色电弧开始聚集变亮；", 3: "枪口爆出一团明亮的青白色电击爆发，细小电弧向左炸开",
           4: "电爆发衰减成跳动的电弧；", 5: "电弧熄灭，枪口冒出淡青色烟；",
           6: "回到与格1完全一致的瞄准待机（首尾闭合）。"},
    fx="只有枪口的电击爆发与电弧；火光只贴在步枪枪口。")
veh("fe_aether_hover_cavalry", "以太骑兵", "白色装甲带青色能量光的以太悬浮骑兵机甲——低伏的机甲战骑造型，头部前方伸出一根能量骑枪指向画面左侧",
    "骑枪尖端爆出一团拳头大小的青白色能量爆发", "能量骑枪的尖端（头部前方下缘）",
    smoke="细小青色能量残渣向左飘散",
    extra="骑枪是一根细长的青白色能量矛，与锚定帧同款、贴着头部下缘，绝不变成粗大的灰色圆柱或圆筒；机甲姿态与配色六格完全不变，绝不变暗变黑；火光只有青白色，绝不出现橙黄色或金黄色。")
veh("fe_aether_swarm_queen", "蜂群母机", "巨大的以太蜂群母舰：扁平修长的深灰色战舰舰体、布满青色能量光带与小炮塔，面朝画面左侧，舰首下缘有一门主炮——它是一艘船，绝不是机甲或螃蟹",
    "舰首下缘主炮的炮口爆出一团拳头大小的青白色能量爆发", "舰首下缘主炮的炮口（画面最左端的舰体下缘）",
    smoke="细小能量残渣向左飘散",
    extra="能量爆发只有拳头大小、贴在舰首炮口，颜色只有青白色，绝不出现橙色、红色或黄色火光；画面中绝不出现蜜蜂、黄蜂、昆虫或任何带翅膀的生物；绝不变成包住整艘舰的大光球；舰体姿态六格完全不变，绝不变成坦克或其他载具。")
veh("fe_frontier_mixed_company", "混编突击队", "军绿色轮式装甲卡车，车顶前部架着一挺重机枪，车身侧面有几个小观察窗，面朝画面左侧",
    "车顶重机枪口爆出短促橙黄色火光", "车顶前部机枪口", smoke="枪口细烟",
    extra="车身侧面小观察窗保持原样，绝不新增火光。")
inf("fe_frontier_veteran", "边境老兵", "戴深色钢盔、穿卡其色作战服、背行军背包的边境老兵，双手端着步枪指向画面左侧，站立瞄准姿态——六格全部戴同一个钢盔，绝不脱盔",
    "枪口爆出短促橙黄色枪口焰", "步枪枪口")
inf("fe_iron_wall_juggernaut", "重装先驱", "穿重型蓝黑色动力装甲的战士，双手端一把粗大的重型步枪指向画面左侧",
    "枪口爆出一团拳头大小的橙白色炮口焰，明亮但不遮掩枪身", "重型步枪的枪口",
    extra="炮口焰是拳头大小的紧凑火团，只出现在重型步枪的枪口（画面左侧），绝不画在盾牌、胸口或手上——绝不出现盾牌；六格都是同一个蓝黑色动力装甲战士，绝不变成载具或机甲；六格全部保持同一种单膝跪地端枪姿势，跪姿全程一致，首尾闭合；绝不画成巨大的球形爆炸云，绝不遮掩枪身和身体。")
veh("fe_quantum_mobile_base", "移动堡垒基地", "军绿色履带式移动基地车，车体上布满绿色发光能量水晶簇、货箱和天线，车体外甲覆盖紫色符文涂鸦纹路（与锚定帧完全一致的杂乱模块化外观），车体前部顶部有一座小型防御炮塔，炮塔的枪管细小指向画面左侧——除了炮塔的小枪管外车体没有任何长炮管",
    "防御炮塔的小枪管口爆出短促橙黄色火光", "车体前部顶部炮塔的小枪管口", smoke="枪口细烟",
    extra="六格车体都保持锚定帧里的杂乱模块化外观：绿色发光水晶簇、货箱、天线和紫色符文涂鸦纹路全部保留在车体上；防御炮塔保持锚定帧里的极小尺寸，绝不放大成大炮塔；除了炮塔的小枪管外车体没有任何长炮管，绝不新增任何炮管或武器。")
inf("fe_void_dimensional_soldier", "次元行者", "穿黑色紧身作战服的次元行者，双手端一把黑色步枪指向画面左侧，站立瞄准姿态",
    "枪口爆出短促橙黄色枪口焰", "步枪枪口",
    extra="六格全程保持同一种站立端枪瞄准姿势，双脚位置完全不变，绝不出现跪姿或换姿势；六格都是同一个黑色短发士兵，黑色短发和整张脸完全露出来，发型与锚定帧一模一样，头上没有任何兜帽或布料覆盖；身上覆盖着与锚定帧相同的深蓝黑色紧身作战服微光。")
# ── 未来 ──
veh("fut_air_drone", "无人机群", "未来派深蓝色三角翼武装无人机，尖锐机头指向画面左侧",
    "机头下方炮口爆出一团拳头大小的青白色能量爆发", "机头下方的能量炮口", smoke="细小青色能量残渣向左飘散",
    extra="火光只有青白色，绝不出现橙色或黄色火光；机身保持深蓝灰色与蓝色灯光，绝不整体变成紫红色或紫色，绝不出现紫色线条、星座连线或粒子杂纹。")
C["fut_air_stealth_bomber"] = dict(
    name="B-21 突袭者", subject="未来派深灰色飞翼隐身轰炸机，扁平三角飞翼造型，面朝画面左侧",
    cells={2: "机腹弹舱出现一条细的深色缝隙（微微张开）；", 3: "一枚深色小炸弹从机腹脱离，出现在机腹下方偏左位置",
           4: "炸弹坠出画面下缘，机腹残留一缕淡淡白烟；", 5: "淡淡白烟消散，机腹闭合；",
           6: "回到与格1完全一致的平飞姿态（首尾闭合）。"},
    fx="没有机炮火光、没有爆炸、没有橙色火焰——只有弹舱细缝、小炸弹下落与淡淡白烟；机身飞行姿态六格保持不变，机腹绝不出现大黑洞。")
veh("fut_arm_hovertank", "悬浮坦克", "未来派悬浮主战坦克，棕灰色楔形车体、无履带悬浮在空中，车体前端有两个能量发射鳍，面朝画面左侧",
    "两个能量鳍前方爆出一团明亮的紫色能量爆发", "车体前端两个能量鳍之间", smoke="紫色残光向左飘散",
    extra="能量爆发是一团拳头大小、饱满圆润的紫蓝色光团，颜色与车体前端能量鳍的光色一致，紧贴在车体前端（画面左侧）两个能量鳍之间的空中；六格车体形状、棕灰涂装与亮度完全一致，悬浮高度不变。")
inf("fut_inf_x9", "虚空潜行者", "披着彩色数码迷彩斗篷、戴全覆式头盔的未来突击兵，双手端一把能量步枪指向画面左侧，站立瞄准姿态",
    "枪口爆出短促的青蓝色能量弹爆发", "能量步枪的枪口")
C["fut_nano_drone"] = dict(
    name="纳米修复机", subject="白色球形纳米修复无人机，圆滚滚的单眼机身，机身左侧伸出一支细小的修理激光笔",
    cells={2: "左侧激光笔尖亮起微光；", 3: "激光笔向画面左侧射出一段极细的青色细线光束脉冲（比铅笔芯还细，笔直一条线）",
           4: "光束熄灭，笔尖残留微光；", 5: "微光熄灭，笔尖冒出极细的白色雾气；",
           6: "回到与格1完全一致的悬停姿态（首尾闭合）。"},
    fx="只有左侧激光笔发出的极细青色直线光束；绝不出现大型晶体、光刃、长条形能量块或菱形光团；绝不出现橙红色火焰，绝不画在机身右侧；机身六格保持同款球形，绝不变成其他形状。")
veh("fut_space_fighter", "空天战斗机", "未来派深蓝灰色空天战斗机，尖锐机头指向画面左侧，机翼后掠",
    "机头机炮爆出蓝白色机炮火光", "机头炮口", smoke="细小能量残渣向左飘散",
    extra="机身保持深蓝灰色，绝不出现紫色裂纹、紫色纹路或紫色底块；机炮火光只有蓝白色，绝不出现橙黄色。")
veh("guardian_ww1_ironclad", "铁壁守护者", "一战英国铁壁守护者坦克，深色铆接菱形车体覆着淡蓝色能量光纹，车顶炮塔伸出一根主炮管指向画面左侧",
    "主炮口爆发橙白色大炮口焰", "主炮管末端的炮口", smoke="灰白硝烟从炮口向左飘散",
    extra="火光只出现在主炮管末端炮口（画面最左端），车体中段、炮塔和车体上方绝不出现任何火光；炮口焰是圆润的橙白色火团，绝不出现黑色星形、尖刺状或日冕形爆炸图案；硝烟只从炮口向左飘散，绝不从车体顶部或尾部冒出；炮管长度六格完全一致；车体上的蓝色光纹保持原有亮度不变，绝不新增蓝色火光。")
# ── 现代 ──
veh("mod_ah64", "阿帕奇", "美军AH-64阿帕奇武装直升机，深绿色机身、串列座舱、两侧短翼挂火箭巢，机鼻下方有一座机炮，面朝画面左侧",
    "机鼻机炮口爆出短促橙黄色机炮火光", "机鼻下方的机炮口", smoke="枪口细烟，一枚弹壳向下弹出",
    extra="火光只出现在机鼻机炮口，绝不画在短翼、旋翼或尾梁；六格都是同一架完整的深绿色阿帕奇直升机，绝不允许空白格，绝不变成其他机型。")
C["mod_air_multirole"] = dict(
    name="F-15E", subject="美军F-15E喷气式战斗轰炸机，深灰色机身、双垂尾，面朝画面左侧，一侧机翼下方挂着导弹",
    cells={2: "翼下导弹挂架出现点火微光；", 3: "一枚导弹从翼下挂架点火脱离向画面左下方飞去，挂架处爆出白色发射焰",
           4: "发射焰衰减，挂架冒出淡淡尾烟；", 5: "尾烟消散；",
           6: "回到与格1完全一致的平飞姿态（首尾闭合）。"},
    fx="只有翼下挂架的发射焰与离架导弹；绝不画在机头、机尾或发动机喷口；机身姿态六格保持不变。")
veh("mod_arm_himars", "HIMARS", "美军HIMARS高机动火箭炮车，军绿色六轮卡车底盘，车尾上架着一箱倾斜指向画面左上方的火箭弹发射箱",
    "发射箱口连续窜出数枚拖着明亮尾焰的火箭，向画面左上方飞去", "车尾上方发射箱的箱口",
    smoke="白色发射烟从箱口涌出向左上方飘散",
    extra="火箭尾焰细长贴着火箭尾部；绝不画成一团悬浮在卡车上方的大火球，绝不遮挡车轮和驾驶室。")
veh("mod_arm_m1a2sep", "M1A2 SEP", "美军M1A2主战坦克，沙黄色涂装、扁平炮塔、长主炮指向画面左侧",
    "炮口爆发橙白色中等大小的炮口焰，明亮但不遮掩车体", "主炮末端的炮口",
    extra="绝不出现白色圆球或白色圆环；炮口焰是圆润的橙白色火团贴在炮口，绝不画成黑色星形或尖刺状爆炸图案，绝不画成盖住前装甲的大团火球；硝烟只从炮口向左飘散，绝不从车体尾部、发动机甲板或炮塔顶部冒出。")
veh("mod_arty_m270", "M270火箭炮", "美军M270火箭炮，灰蓝色履带底盘，车体上方装着一具长方形火箭发射箱",
    "发射箱左端箱口向画面左上方喷出两三枚小火箭，每枚火箭是一根细小的深色箭体拖着一道细长的明亮橙黄色尾焰",
    "发射箱左端的箱口",
    smoke="白色发射烟贴着箱口向左上方涌出",
    extra="六格车体的灰蓝色涂装与形状完全一致；火箭尾焰从发射箱左端箱口连续地指向左上方。")
veh("mod_stryker", "斯特赖克", "美军斯特赖克八轮装甲车，沙漠迷彩，车顶前部有一座遥控武器站，架上架着一挺机枪，面朝画面左侧",
    "车顶机枪口爆出短促橙黄色火光", "车顶遥控武器站的机枪口", smoke="枪口细烟",
    extra="六格主体轮廓完全一致，只有火光烟变化；车体就是沙漠迷彩八轮斯特赖克，绝不长出钻头、长矛、撞角或任何突出物，绝不变成履带车。")
veh("mod_stryker_m2", "斯特赖克M2", "美军斯特赖克八轮装甲车，深蓝色灰涂装，车顶前部有一座武器站架着一挺重机枪，面朝画面左侧",
    "车顶重机枪口爆出短促橙黄色火光", "车顶武器站的机枪口", smoke="枪口细烟",
    extra="绝不在车体前方或前轮附近出现任何火光。")
inf("mod_sup_m4_carbine", "M4 卡宾特遣班", "穿沙漠迷彩作战服、戴战术背心的士兵，双手端M4卡宾枪指向画面左侧，站立瞄准姿态",
    "枪口爆出短促橙黄色枪口焰", "卡宾枪的枪口",
    extra="六格都是同一套沙漠迷彩作战服，色调绝不变成紫色或粉紫色；六格同一种端枪姿势（站姿或跪姿其一），绝不混排。")
veh("mod_sup_m6", "自行高炮M6", "美军自行高炮，军绿色履带底盘，车顶两门细长高射炮管并排指向画面左上方",
    "两门炮口同时爆出橙黄色炮口焰", "两根炮管末端的炮口", smoke="弹壳向右下方弹出，炮口冒细烟")
C["vis_xeno_adept"] = dict(
    name="虚空法师", small=True, subject="身穿深蓝紫色长袍、身形修长的异界虚空法师，左手向画面左侧抬起施法，指尖萦绕青色能量",
    cells={2: "抬起的指尖青色能量聚集变亮；", 3: "指尖前方爆出一团明亮的青白色能量爆发",
           4: "爆发衰减成细小电弧；", 5: "能量残渣消散；",
           6: "回到与格1完全一致的施法姿态（首尾闭合）。"},
    extra="六格保持同一种站立施法姿势（绝不下跪、不混排站姿跪姿）；能量颜色只有青白色，绝不出现橙黄色。",
    fx="只有抬手指尖前方的能量爆发；绝不画在脚下或裙摆，脚边绝不出现白色碎块。")
# ── 一战 ──
veh("ww1_105mm", "105mm榴弹炮", "一战德国105mm榴弹炮，钢蓝色细长炮管指向画面左上方，大木辐条车轮与开脚式炮架",
    "炮口爆发橙白色大炮口焰", "炮管末端的炮口", smoke="浓白硝烟从炮口涌出向左飘散",
    extra="火光颜色是橙白色，绝不是蓝色。")
veh("ww1_a7v", "A7V", "一战德国A7V突击坦克，高大的灰蓝色铆接方盒车体，车体前部下方伸出一门短炮管指向画面左侧",
    "前炮口爆发橙白色炮口焰", "车体前部下方的炮口", smoke="炮口硝烟向左飘散",
    extra="绝不画在车顶上方空中。")
veh("ww1_arm_rolls", "劳斯装甲车", "一战英国劳斯莱斯轮式装甲车，浅蓝灰绿色车身、木辐条车轮，车体后部球形旋转炮塔伸出一挺细机枪管指向画面左侧",
    "炮塔机枪口爆出拳头大小、清晰可见的短促橙黄色火光", "炮塔前部伸出的机枪管末端枪口", smoke="枪口细烟，弹壳向右上方弹出",
    extra="球形炮塔是封闭的金属圆顶，舱盖合拢、表面完整，只有一挺细机枪管从炮塔前部伸出；火光是拳头大小的橙黄色火焰，紧贴在机枪管末端枪口上；画面中只有这一辆车本身，车体钢板表面完全封闭；六格车体的浅蓝灰绿涂装、木辐条车轮与形状完全一致。")
veh("ww1_arty_77mm", "77mm野战炮", "一战德国77mm野战炮，细长炮管指向画面左上方，弧形炮盾、大木辐条车轮、向画面右后方张开的驻锄",
    "炮口爆发橙白色大炮口焰", "炮管末端的炮口", smoke="白烟贴着炮口向画面左侧缓缓飘散",
    extra="绝不出现悬浮在炮身右上方的独立烟团；硝烟必须从炮口连着向左飘。")
veh("ww1_arty_m81", "81mm迫击炮", "一战重型攻城迫击炮，粗短炮身以大仰角指向画面左上方，钢制开脚炮架",
    "炮口爆出紧贴炮口的橙黄色大炮口焰", "粗短炮身的炮口", smoke="深灰色硝烟向上方飘散，一枚弹壳向右弹出",
    extra="炮口焰紧贴炮口，绝不悬浮在炮口上方。")
veh("ww1_av7", "AV7", "一战德国AV7重型坦克，灰绿色铆接车体、菱形轮廓，车体正面伸出一门短炮管指向画面左侧",
    "正面炮口爆发橙白色炮口焰", "车体正面的炮口", smoke="炮口硝烟向左飘散",
    extra="绝不画成悬浮在车体左侧空中的黄色圆环，绝不画在车体顶部或后部。")
veh("ww1_boss_av7", "圣沙蒙", "一战法国圣沙蒙式巨型突击坦克（Boss），深灰色长方形高大车体，车体正面下缘伸出一门主炮指向画面左侧",
    "正面主炮口爆发橙白色大炮口焰", "车体正面下缘的主炮口", smoke="炮口硝烟向左飘散",
    extra="绝不画在车顶。")
veh("ww1_fort_artillery", "要塞炮台", "要塞重炮工事——灰色混凝土基座上安放一门长炮管要塞炮，炮管指向画面左侧",
    "炮口爆发橙白色大炮口焰，明亮但不吞没炮架", "要塞炮的炮口", smoke="硝烟从炮口向左飘散",
    extra="六格里至少四格有可见的火光或烟，绝不只亮一帧。")
veh("ww1_fort_pillbox", "机枪碉堡", "一战混凝土机枪碉堡，矮胖的梯形钢筋混凝土堡垒，正面（画面左侧）有狭窄的机枪射孔",
    "正面机枪射孔喷出短促橙黄色枪口焰", "正面（画面左侧）的机枪射孔", smoke="细烟从射孔飘出",
    extra="火光只从正面射孔喷出，绝不画在碉堡顶部或屋顶边缘。")
inf("ww1_inf_cavalry", "骑兵斥候", "一战骑兵——戴钢盔的士兵骑在深棕色战马上，双手端骑枪指向画面左侧",
    "枪口爆出拳头大小的紧凑橙黄色枪口焰", "骑枪的枪口",
    extra="深棕色战马与骑手姿态六格完全一致，毛色与第一格相同，只有枪口火光变化；火光是紧凑的拳头大小橙黄色火焰，紧贴骑枪枪口。")
inf("ww1_inf_mp18_x", "MP18 突击队", "一战德国风暴突击队员，穿灰绿色军大衣、戴钢盔，双手端MP18冲锋枪指向画面左侧，站立瞄准姿态",
    "枪口爆出短促橙黄色枪口焰", "冲锋枪的枪口")
veh("ww1_lanchest", "兰彻斯特", "一战英国兰彻斯特装甲车，深灰色车身、圆顶炮塔，炮塔正面伸出一挺机枪，面朝画面左侧",
    "炮塔机枪口爆出短促橙黄色火光", "炮塔正面的机枪口", smoke="枪口细烟",
    extra="绝不漂浮在车顶上方。")
veh("ww1_mark4", "马克IV", "一战英国马克IV雄性坦克，菱形艇身车体环绕履带，侧面战斗舱伸出一门短炮管指向画面左侧",
    "侧舷炮口爆发橙白色炮口焰", "侧面战斗舱炮管的炮口（车体侧面中部高度）", smoke="炮口硝烟向左飘散",
    extra="绝不画在车顶。")
inf("ww1_storm", "风暴突击兵", "一战德国风暴突击兵，穿深绿色作战服、背突击背包，双手端步枪指向画面左侧，站立瞄准姿态",
    "枪口爆出短促橙黄色枪口焰", "步枪枪口",
    extra="身体颜色和亮度六格完全不变，绝不全身发亮。")
# ── 二战 ──
C["ww2_air_dive_bomber"] = dict(
    name="Ju 87 斯图卡", subject="二战德国Ju87斯图卡俯冲轰炸机，倒海鸥翼、固定式起落架整流罩、绿棕迷彩，一架孤立完整的飞机占满画面，面朝画面左侧水平平飞",
    cells={2: "机腹弹舱门缓缓打开；", 3: "一枚深色炸弹从机腹脱离，向画面下方坠落",
           4: "炸弹坠出画面下缘，弹舱口冒出淡淡白烟；", 5: "弹舱门缓缓闭合；",
           6: "回到与格1完全一致的平飞姿态（首尾闭合）。"},
    fx="画面中是一架孤立完整的飞机；动作只有弹舱开合与炸弹下落；机身姿态六格保持不变。")
inf("ww2_arm_garand_para", "M1 加兰德伞兵班", "二战美军伞兵，穿卡其色作战服、戴M1钢盔，双手端M1加兰德步枪指向画面左侧，站立瞄准姿态",
    "枪口爆出短促橙黄色枪口焰，清晰可见", "步枪枪口",
    extra="格3至格5的枪口必须有清晰可见的枪口焰；绝不全身发亮而无枪口焰。")
veh("ww2_arty_m81", "81mm迫击炮", "二战美军81mm迫击炮，绿色粗短炮身以大仰角指向画面左上方，方形基座",
    "炮口爆出紧贴炮口的橙黄色炮口焰", "炮身的炮口", smoke="深灰色硝烟向上飘散",
    extra="炮口焰紧贴炮口，绝不画成竖起的橙色旗帜形状，绝不悬浮在炮管上方。")
veh("ww2_fort_bunker", "混凝土碉堡", "二战大型混凝土碉堡，灰色多层堡垒，正面（画面左侧）下层有狭窄机枪射孔，顶部有观察塔",
    "正面机枪射孔喷出橙黄色枪口焰", "正面（画面左侧）的机枪射孔", smoke="细烟从射孔飘出",
    extra="顶部观察塔保持原样，绝不新增顶部火光。")
veh("ww2_inf_bazooka", "装甲车", "一战样式沙黄色轮式装甲车，铆接车体、车顶中央圆顶炮塔，炮塔正面伸出一挺机枪，面朝画面左侧",
    "炮塔机枪口爆出短促橙黄色火光", "车顶炮塔的机枪口", smoke="枪口细烟",
    extra="绝不在车体前方或车轮附近出现任何火光。")
veh("ww2_inf_hellcat", "M18地狱猫", "二战美军M18地狱猫坦克歼击车，橄榄色低矮炮塔、细长炮管指向画面左侧，六对负重轮",
    "炮口爆发清晰可见的橙白色炮口焰", "细长炮管末端的炮口", smoke="炮口硝烟向左飘散",
    extra="火光必须清晰可见，绝不离体漂浮。")
inf("ww2_inf_kar98k", "雷霆狙击手", "二战德国狙击手，身披树叶伪装网，双手端Kar98k步枪指向画面左侧，站立瞄准姿态",
    "枪口爆出短促橙黄色枪口焰，清晰可见", "Kar98k的枪口",
    extra="身体伪装色和亮度六格完全不变，绝不全身发亮。")
C["ww2_sup_gmc_truck"] = dict(
    name="GMC 补给卡车", subject="二战美军GMC 2.5吨军用卡车，军绿色驾驶室与帆布货厢，面朝画面左侧",
    cells={2: "车辆微微前倾停稳；", 3: "货厢后挡板缓缓放下",
           4: "一个木色补给箱从货厢滑落到地面；", 5: "补给箱稳稳落地，后挡板垂下；",
           6: "回到与格1完全一致的静止姿态（首尾闭合）。"},
    fx="没有火光没有烟没有爆炸——只是卸货动作；驾驶室和车轮六格保持不变。")

QUEUE = list(C)


def phase_anchor(keys):
    import numpy as np
    from PIL import Image
    for k in keys:
        p = os.path.join(UA, k, "sheet_idle.png")
        meta = json.load(open(os.path.join(UA, k, "anim.json"), encoding="utf-8"))
        fs = int(meta.get("frame_size", 256))
        im = Image.open(p).convert("RGBA")
        f0 = im.crop((0, 0, fs, im.height))
        bg = Image.new("RGBA", (fs, fs), (255, 0, 255, 255))
        bg.paste(f0, (0, 0), f0)
        bg.convert("RGB").save(os.path.join(OUT, "%s_anchor_raw.png" % k))
        print("  [anchor] %s fs=%d" % (k, fs), flush=True)


def phase_gen(keys):
    for k in keys:
        spec = C[k]
        cj = os.path.join(OUT, "_mk12_cells_%s.json" % k)
        with open(cj, "w", encoding="utf-8") as f:
            json.dump(spec["cells"], f, ensure_ascii=False)
        args = [sys.executable, os.path.join(ROOT, "tools", "img25_attack_gen.py"), k,
                "--subject", spec["subject"], "--rolls", "2", "--cells-json", cj]
        if spec.get("small"):
            args.append("--small-motion")
        rc = subprocess.call(args, cwd=ROOT)
        print("  [gen] %s rc=%d" % (k, rc), flush=True)


def roll_sheet(key):
    for suf in ("_R1", "_R2", ""):
        p = os.path.join(OUT, "%s%s_attack_sheet_832.png" % (key, suf))
        if os.path.exists(p):
            yield suf, p


def phase_audit(keys):
    from PIL import Image, ImageDraw
    for k in keys:
        rows = []
        idle = Image.open(os.path.join(UA, k, "sheet_idle.png")).convert("RGBA")
        fs = idle.height
        f0 = idle.crop((0, 0, fs, fs)).resize((120, 120), Image.LANCZOS)
        for suf, p in roll_sheet(k):
            im = Image.open(p).convert("RGBA")
            cell = im.width // 3
            frames = [im.crop((c * cell, r * cell, (c + 1) * cell, (r + 1) * cell))
                      for r in range(2) for c in range(3)]
            strip = Image.new("RGBA", (len(frames) * 120, 120), (0, 0, 0, 0))
            for i, fr in enumerate(frames):
                strip.paste(fr.resize((120, 120), Image.LANCZOS), (i * 120, 0), fr.resize((120, 120), Image.LANCZOS))
            rows.append((suf, strip))
        W = max((s.width for _, s in rows), default=720) + 140
        H = 150 + len(rows) * 132
        page = Image.new("RGB", (W, H), (16, 16, 20))
        dr = ImageDraw.Draw(page)
        dr.text((4, 2), "%s  %s  idle f0 ->" % (k, C[k]["name"]), fill=(255, 220, 120))
        bg = Image.new("RGBA", (120, 120), (60, 60, 72, 255))
        bg.paste(f0, (0, 0), f0)
        page.paste(bg.convert("RGB"), (0, 24))
        y = 150
        for suf, s in rows:
            dr.text((4, y - 12), "掷次 %s" % suf, fill=(160, 200, 255))
            tile = Image.new("RGBA", s.size, (40, 40, 50, 255))
            tile.paste(s, (0, 0), s)
            page.paste(tile.convert("RGB"), (130, y))
            y += 132
        page.save(os.path.join(AUD, "%s.png" % k))
        print("  [audit] %s (%d 掷)" % (k, len(rows)), flush=True)


def _rescue_cell(cell, ag):
    """残留底修复（色簇直杀）：不透明像素量化色簇里找「残留底簇」——
    ①中性浅灰板：min≥140、通道差≤22、亮度std<7（平板）、≥5%；
    ②品紫残晕：r-g>20 且 b-g>20 且 g<110、≥8%（键控边缘暗品红）。
    命中→按色距直杀（平板全覆盖，无 BFS）；主体着色/带阴影簇不满足平板性不误杀。"""
    import numpy as np
    from PIL import Image
    ca = np.asarray(cell)
    op = ca[:, :, 3] > 8
    if op.sum() < 500:
        return None
    rgb = ca[:, :, :3].astype(int)
    q = (rgb[op] // 16)
    keys = q[:, 0] * 256 + q[:, 1] * 16 + q[:, 2]
    vals, counts = np.unique(keys, return_counts=True)
    mask = np.zeros(op.shape, dtype=bool)
    hit = False
    for i in np.where(counts >= max(500, op.sum() * 0.05))[0]:
        sel = rgb[op][keys == vals[i]]
        bg = sel.mean(axis=0)
        flat = sel.mean(axis=1).std() < 7
        grayish = bg.min() >= 140 and bg.max() - bg.min() <= 22 and flat
        purplish = (bg[0] - bg[1] > 20 and bg[2] - bg[1] > 20
                    and bg[1] < 110 and counts[i] >= op.sum() * 0.08)
        if not (grayish or purplish):
            continue
        dist = np.sqrt(((rgb - bg) ** 2).sum(axis=2))
        mask |= (dist < 30) & op
        hit = True
    if not hit or mask.mean() < 0.04:
        return None
    out = cell.copy()
    al = np.asarray(out)[:, :, 3].copy()
    al[mask] = 0
    out.putalpha(Image.fromarray(al))
    out = ag.keep_main_bodies(out)
    out = ag.strip_rail_cols(out)
    return out


def _scrub_cell(cell):
    """透明邻域品紫残晕擦除：距透明像素 2px 内的紫红调不透明像素 → 杀。
    (r-g>18 且 b-g>12)：暗品红晕(54,10,72)/亮品红(255,0,255)命中；
    军绿/皮肤/蓝色装甲不命中（皮肤 b-g<0）。"""
    import numpy as np
    from PIL import Image, ImageFilter
    ca = np.asarray(cell)
    if ca[:, :, 3].max() == 0:
        return cell, False
    al = ca[:, :, 3]
    t = (al > 8).astype("uint8") * 255
    spread = Image.fromarray(255 - t).filter(ImageFilter.MaxFilter(5))
    kill_zone = (np.asarray(spread) > 0) & (al > 8)
    rgb = ca[:, :, :3].astype(int)
    purple = (rgb[:, :, 0] - rgb[:, :, 1] > 18) & (rgb[:, :, 2] - rgb[:, :, 1] > 12)
    mask = kill_zone & purple
    if mask.sum() < 30:
        return cell, False
    out = cell.copy()
    a2 = al.copy()
    a2[mask] = 0
    out.putalpha(Image.fromarray(a2))
    return out, True


def phase_fixbg(keys):
    """对两掷 832 卷逐格查浅底残留，命中格重键控后原位写回。"""
    ag = load("mk12_agk", os.path.join(ROOT, "tools", "img25_attack_gen.py"))
    from PIL import Image
    import numpy as np
    for k in keys:
        for suf, p in list(roll_sheet(k)):
            im = Image.open(p).convert("RGBA")
            cw = im.width // 3
            fixed = 0
            for idx in range(6):
                r, c = divmod(idx, 3)
                cell = im.crop((c * cw, r * cw, (c + 1) * cw, (r + 1) * cw))
                ca = np.asarray(cell)
                if ca[:, :, 3].max() == 0:
                    continue
                rec = _rescue_cell(cell, ag)
                if rec is not None:
                    cell = rec
                    fixed += 1
                cell, scrubbed = _scrub_cell(cell)
                if scrubbed:
                    fixed += 1
                if rec is not None or scrubbed:
                    im.paste(cell, (c * cw, r * cw))
            if fixed:
                im.save(p)
                print("  [fixbg] %s%s 重键控 %d 格" % (k, suf, fixed), flush=True)


def phase_deploy(keys):
    mk8 = load("mk12_mk8", os.path.join(ROOT, "tools", "_mk8_deploy.py"))
    for kv in keys:
        k, _, suf = kv.partition(":")
        suf = suf or "_R1"
        src = os.path.join(OUT, "%s%s_attack_sheet_832.png" % (k, suf))
        if not os.path.exists(src):
            print("  [skip] %s 缺 %s" % (k, src), flush=True)
            continue
        mk8.deploy_sheet(src, k, "attack", flip=False, bake=True)


def main():
    ph = sys.argv[1] if len(sys.argv) > 1 else "audit"
    keys = [a for a in sys.argv[2:] if not a.startswith("-")]
    if not keys:
        keys = QUEUE
    bad = [k for k in keys if k.partition(":")[0] not in C]  # 12-05 deploy 支持 key:_Rn 后缀（原校验切分前整串比对必拒）
    if bad:
        sys.exit("未知单位: %s" % bad)
    globals()["phase_" + ph](keys)
    print("MK12 %s 完成: %d 案" % (ph, len(keys)))


if __name__ == "__main__":
    main()
