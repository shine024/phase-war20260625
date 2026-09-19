# -*- coding: utf-8 -*-
"""_tmp_gen_modicon_mapping.py —— 249 改造 → 图标意象映射表自动草稿（只读数据，不改数据）

全量跑的前置测试：从 data/modification_modules/*.gd 解析全部模块（id/name/rarity/slot_type），
按关键词词典自动产出"名字→主体意象"映射草稿，统计自动覆盖率；未命中关键词的进
need_manual 清单（生产时由人工补意象词——正是"贴合"的把关层）。

输出：docs/待生成徽章_改造图标样张_20260917/mapping_draft.json
用法：python tools/_tmp_gen_modicon_mapping.py
"""
import glob
import json
import os
import re

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC_GLOB = os.path.join(ROOT, "data", "modification_modules", "*_mods.gd")
OUT = os.path.join(ROOT, "docs", "待生成徽章_改造图标样张_20260917", "mapping_draft.json")

# 族 → 勾线色/色相（试点验证过的 8 族 + 工兵/通用补齐）
FAMILY = {
    "infantry": ("橄榄绿色", 80), "armor": ("钢青色", 187), "artillery": ("琥珀金色", 38),
    "anti_air": ("钴蓝色", 220), "air": ("冰青色", 195), "engineer": ("工程橙色", 25),
    "fort": ("珊瑚橙色", 15), "recon": ("紫罗兰色", 275), "universal": ("银白色", 210),
    "enhancement": ("品红色", 310),
}

# 关键词 → 主体意象（贴合层；命中即自动出意象句，未命中进 need_manual）
KEYWORDS = [
    (r"突击步枪|assault", "一支突击步枪的侧面剪影徽记"),
    (r"冲锋枪|submachine", "一支冲锋枪的侧面剪影徽记"),
    (r"小口径|caliber", "一枚细口径弹头与三道速度线组成的徽记"),
    (r"无托|bullpup", "一支无托结构步枪的紧凑侧影徽记"),
    (r"狙击|sniper", "一具高精度狙击枪管与两脚架剪影徽记"),
    (r"机枪|machine.?gun", "一挺弹链供弹机枪的侧面剪影徽记"),
    (r"滑膛炮|smoothbore", "一门坦克滑膛炮管与炮塔正面剪影徽记"),
    (r"膛线|rifling", "一段炮膛剖面与螺旋膛线纹样组成的徽记"),
    (r"增程|extended.?range", "一枚带尾部助推焰的增程炮弹与抛物弹道弧线组成的徽记"),
    (r"制导|guided", "一枚带折叠翼的制导炮弹与锁定框组成的徽记"),
    (r"子母|cluster", "一枚母弹开仓释放多枚子弹药的徽记"),
    (r"倾斜装甲|sloped", "一块倾斜放置的轧制钢板剖面徽记"),
    (r"复合|composite", "多层复合装甲板叠层剖面的徽记"),
    (r"爆反|reactive", "六边形爆炸反应装甲砖块阵列为主体、其中一块迸发小火光的徽记"),
    (r"主动防护|\bAPS", "一座车载相控阵天线拦截来袭弹的徽记"),
    (r"雷达", "一面旋转抛物面雷达天线与电波弧组成的徽记"),
    (r"敌我识别|IFF", "一副天线环与问号化双箭头组成的徽记"),
    (r"导弹", "一枚带十字翼的导弹侧影徽记"),
    (r"挂架|rail|rack", "一枚翼下挂架上的导弹侧影徽记"),
    (r"近炸引信|fuze", "一枚引信头部与扩散感应波环组成的徽记"),
    (r"激光", "一座近防炮塔射出弧形激光束的徽记"),
    (r"涡扇|turbofan", "一台涡扇发动机进气道正面徽记"),
    (r"矢量|vector", "一个偏转喷口与两道偏流焰组成的徽记"),
    (r"隐身|stealth", "一架菱形隐身飞行器剪影与波纹消散线的徽记"),
    (r"相控阵|AESA", "一块嵌阵元平板雷达的正面徽记"),
    (r"头盔|helmet", "一顶飞行头盔与护目镜正面徽记"),
    (r"超视距|BVR", "一枚远程空空导弹与雷达锁定环组成的徽记"),
    (r"混凝土|concrete", "钢筋混凝土块垒砌截面的徽记"),
    (r"坑道|tunnel", "一段地下坑道拱形入口的徽记"),
    (r"炮塔|turret", "一座双管自动炮塔的正面徽记"),
    (r"过滤|filtration", "一台通风过滤装置与气流线组成的徽记"),
    (r"弹药库|ammo.?dump", "叠放的弹药箱与警告条纹组成的徽记"),
    (r"伪装|camouflage", "一张伪装网与树叶剪影组成的徽记"),
    (r"红外|IR|thermal", "一个热源轮廓被波纹抑制的徽记"),
    (r"消音|suppressor", "一支消音器剖面与消音隔板的徽记"),
    (r"瞄准镜|scope", "一枚高倍率圆形瞄准镜镜片与测距刻线组成的徽记"),
    (r"无人机|UAV", "一架侦察无人机俯视剪影徽记"),
    (r"电台|radio", "一台战术电台与信号波弧组成的徽记"),
    (r"通讯|comms", "一对通讯天线与电波弧组成的徽记"),
    (r"数字化|digital", "一个士兵剪影与数据流线组成的徽记"),
    (r"背心|vest", "一件战术背心正面徽记"),
    (r"盾牌|shield", "一面防弹盾牌正面徽记"),
    (r"激光指示|designator", "一台激光指示器与光束标记点组成的徽记"),
    (r"体质|HP", "一枚菱形能量晶体与上升双箭头组成的徽记"),
    (r"火力|dmg", "一枚菱形能量晶体与交叉双炮管剪影组成的徽记"),
    (r"防护|防御|def", "一枚菱形能量晶体与盾形轮廓组成的徽记"),
    (r"机动|速度|speed", "一枚菱形能量晶体与三道疾速线组成的徽记"),
    (r"索敌|射程|range", "一枚菱形能量晶体与瞄准环组成的徽记"),
    # ── 全量扩充（2026-09-17，覆盖 need_manual 130 条）──
    (r"双联|四联|quad|twin", "一座多联装高炮座的正面徽记"),
    (r"发电|generator", "一台野战发电机与电流弧组成的徽记"),
    (r"烟幕|smoke", "一具烟幕弹发射器与烟云弧组成的徽记"),
    (r"火控|fire.?control", "一台火控计算机与弹道解算线组成的徽记"),
    (r"电磁|emp", "一枚电磁弹头与环形电弧组成的徽记"),
    (r"酸液|acid", "一枚滴蚀酸液的弹头与腐蚀斑组成的徽记"),
    (r"探照灯|searchlight", "一具探照灯与光锥组成的徽记"),
    (r"定时引信|time.?fuze", "一枚防空弹与定时刻度环组成的徽记"),
    (r"备弹|ammo.?cache|弹药库", "一排堆叠弹药架与储备箱组成的徽记"),
    (r"测高|altimeter", "一台测高仪与高度刻度线组成的徽记"),
    (r"弹幕|barrage", "一台弹幕计算机与多道弹道弧组成的徽记"),
    (r"脱壳穿甲|apfsds|ap_ammo|穿甲弹", "一枚长杆尾翼稳定穿甲弹的飞行体徽记"),
    (r"自动装弹|autoloader|装填|loader", "一台自动装弹机机械臂与弹链组成的徽记"),
    (r"燃气轮机|turbine", "一台燃气轮机叶轮与气流线组成的徽记"),
    (r"柴油|增压|引擎|diesel", "一台涡轮增压柴油机与排气线组成的徽记"),
    (r"扫雷|mine.?plow|sweeper", "一块车前扫雷滚与翻土线组成的徽记"),
    (r"数据链|datalink|data.?link", "一台数据链终端与三条链路弧组成的徽记"),
    (r"狂热|frenzy|兴奋剂|stimulant", "一枚燃烧徽记与升腾火纹组成的徽记"),
    (r"附加钢板|spacer|附加", "一组螺栓固定的附加钢板徽记"),
    (r"炮盾|mantlet", "一块厚重炮盾的正面徽记"),
    (r"周视|commander", "一座车长周视镜镜塔的徽记"),
    (r"反击|counter", "一圈受击反弹脉冲与反弹箭头组成的徽记"),
    (r"运输车|supply|补给|运输", "一辆弹药补给卡车的侧影徽记"),
    (r"导航|nav", "一台导航仪与规划航线组成的徽记"),
    (r"温压|thermobaric", "一枚温压弹与扩散爆燃云组成的徽记"),
    (r"掩体|fortification", "一段火炮掩体弧墙与炮位的徽记"),
    (r"反击炮击|counter.?battery", "一门反向扬起的炮口与反击弹道弧组成的徽记"),
    (r"助燃|incendiary", "一罐助燃剂与腾起的火苗组成的徽记"),
    (r"白磷|phosphorus", "一枚白磷弹头与迸散白烟点组成的徽记"),
    (r"石墨|graphite", "一枚弹头与石墨纤维丝束组成的徽记"),
    (r"纳米放大|nano.?amp", "一台纳米晶体放大器与增益波组成的徽记"),
    (r"纳米播种|seeder", "一台播撒纳米晶种的装置与散落晶粒组成的徽记"),
    (r"身管|barrel.?maint|枪管", "一段炮管与维护扳手工具组成的徽记"),
    (r"气象|met", "一只气象气球与数据链弧组成的徽记"),
    (r"濒死|last.?stand", "一枚濒死爆发火光与坚守壁垒组成的徽记"),
    (r"爆破|explosive|breaching|破门", "一具破门锤与爆破装药组成的徽记"),
    (r"焊接|welding", "一把焊枪与飞溅焊花组成的徽记"),
    (r"架桥|bridge", "一段桥梁架设的工程剪影徽记"),
    (r"铲|shovel|entrenching", "一把工兵铲与镐组成的套装徽记"),
    (r"急救|medical|medkit|医疗|ifak|敷料|止血", "一只急救包与医疗十字组成的徽记"),
    (r"光纤|optical.?fiber", "一束光纤线缆与流光点组成的徽记"),
    (r"化学喷洒|sprayer|化学", "一具化学喷嘴与雾滴组成的徽记"),
    (r"起重机|crane|抢修", "一台抢修起重机的剪影徽记"),
    (r"反应训练|atkspd", "一枚菱形能量晶体与闪电组成的徽记"),
    (r"弱点|weak.?point|crit|洞察|精准", "一枚菱形能量晶体与靶环准星组成的徽记"),
    (r"回收|lifesteal", "一枚菱形能量晶体与回收钩爪组成的徽记"),
    (r"爆破战技|splash", "一枚菱形能量晶体与迸裂爆芒组成的徽记"),
    (r"破甲|penetration", "一枚菱形能量晶体与破甲锥组成的徽记"),
    (r"连锁|chain", "一枚菱形能量晶体与连锁环组成的徽记"),
    (r"闪避|回避|dodge", "一枚菱形能量晶体与残影弧线组成的徽记"),
    (r"休整|regen", "一枚菱形能量晶体与休整帐篷组成的徽记"),
    (r"反坦克壕|trench", "一段反坦克壕沟的剖面徽记"),
    (r"雷场|minefield", "一片布设地雷阵与警示旗组成的徽记"),
    (r"指挥|command", "一座指挥塔的剪影徽记"),
    (r"地堡|bunker", "一座指挥地堡的剪影徽记"),
    (r"防空洞|bomb.?shelter", "一扇加固防空洞门的徽记"),
    (r"沙袋|sandbag", "一层沙袋垒砌工事的徽记"),
    (r"排水|drainage", "一台排水泵与水流线组成的徽记"),
    (r"永备|hardened", "一座永备碉堡的正面徽记"),
    (r"殉爆|demolition", "两座隔离防爆墙与弹药箱组成的徽记"),
    (r"双弹匣|dual.?mag", "一副并联双弹匣的徽记"),
    (r"插板|insert|body.?armor", "一块防弹插板与纤维纹组成的徽记"),
    (r"护膝|knee", "一副护膝护肘的徽记"),
    (r"外骨骼|exoskeleton", "一具外骨骼腿部支架的徽记"),
    (r"夜视|nvg|night", "一副夜视仪与绿色夜光视野组成的徽记"),
    (r"凝固汽油|napalm", "一枚凝固汽油弹与胶状火团组成的徽记"),
    (r"战斗靴|boots", "一双战斗靴的正面徽记"),
    (r"弹链|ammo.?belt", "一条弯曲弹链与枪身组成的徽记"),
    (r"野战医院|hospital", "一顶野战医院帐篷与十字组成的徽记"),
    (r"gps|定位", "一颗定位卫星与地面定位环组成的徽记"),
    (r"假目标|decoy", "一个角反射器诱饵与虚影组成的徽记"),
    (r"摩托|atv", "一辆越野摩托的侧影徽记"),
    (r"双筒|binoculars", "一副野战双筒望远镜的正面徽记"),
    (r"静音靴|silent", "一双静音靴与消声波纹组成的徽记"),
    (r"多光谱|multiband|传感", "一枚多光谱传感器镜头与波段环组成的徽记"),
    (r"数据库|database", "一枚目标数据芯片与列表线组成的徽记"),
    (r"防雷|mine.?resistant", "一张防雷座椅的侧影徽记"),
    (r"三防|nbc", "一副三防面具的正面徽记"),
    (r"相位共鸣|resonance", "一圈相位共鸣波环与谐振纹组成的徽记"),
    (r"相位过载|overdrive", "一圈过载相位波环与闪电组成的徽记"),
    (r"电子劫持|hijack", "一道劫持电波与断裂锁链组成的徽记"),
    (r"燃烧催化|combustion", "一簇催化火焰与剂罐组成的徽记"),
    (r"过载电容|capacitor", "一台过载电容与迸发电弧组成的徽记"),
    (r"纳米催化|catalyst", "一枚纳米催化晶体与反应泡组成的徽记"),
    (r"光束分裂|splitter", "一束光分成三束的分光光路徽记"),
    (r"反射|reflector", "一组反射镜阵列与折返光路组成的徽记"),
    (r"分析|analyzer", "一台弱点扫描仪与锁定框组成的徽记"),
    (r"污染|pollution", "一只污染蓄能罐与荧光液组成的徽记"),
    (r"弹道重赋|converted", "一道被重定的弹道弧与转折点组成的徽记"),
    (r"扩容|expansion", "一个扩容弹舱与并列弹药组成的徽记"),
    (r"中继|relay", "一座中继天线塔与电波弧组成的徽记"),
    (r"统一装药|unified", "一组统一装药块与同心爆环组成的徽记"),
    (r"痛苦传导|pain", "一条传导锁链与能量流组成的徽记"),
    (r"波次|wave|动员", "一面动员旗帜与三道波纹组成的徽记"),
    (r"平板|tablet", "一块班组战术平板与态势图组成的徽记"),
    (r"神盾|aegis", "一面六边形神盾与能量护环组成的徽记"),
    (r"奇点|singularity", "一枚奇点核心与吸聚漩涡组成的徽记"),
    (r"凝固|稳定|翼", "一枚带尾翼的稳定弹体飞行徽记"),
]

# 家族兜底意象（词典未命中时用——保证全量 100% 有主体）
FAMILY_FALLBACK = {
    "enhancement": "一枚菱形能量晶体徽记",
    "universal": "一枚六边形科技核心徽记",
    "engineer": "一套工具与齿轮的工程徽记",
    "infantry": "一顶军用钢盔与步枪剪影组成的徽记",
    "armor": "一块装甲钢板与履带纹组成的徽记",
    "artillery": "一枚炮弹与炮管剪影组成的徽记",
    "anti_air": "一面防空雷达与电波弧组成的徽记",
    "air": "一架喷气机翼型剪影徽记",
    "fort": "一座混凝土碉堡剪影徽记",
    "recon": "一副双筒望远镜与镜片反光组成的徽记",
}


def parse_file(path):
    src = open(path, "r", encoding="utf-8").read()
    family = os.path.basename(path).replace("_mods.gd", "")
    mods = []
    # 条目以 '"<小写id>" = {' 开头；name/rarity 在条目头部 600 字符内（含同行 AA/AIR 排版）
    starts = list(re.finditer(r'"([a-z0-9_]+)"\s*=\s*\{', src))
    for i, m in enumerate(starts):
        window = src[m.end(): starts[i + 1].start() if i + 1 < len(starts) else m.end() + 800][:600]
        nam = re.search(r'name\s*=\s*"([^"]+)"', window)
        rar = re.search(r'rarity\s*=\s*"(\w+)"', window)
        if not nam:
            continue
        mods.append({"id": m.group(1), "name": nam.group(1),
                     "rarity": rar.group(1) if rar else "common",
                     "family": family})
    return mods


def main():
    all_mods = []
    for f in sorted(glob.glob(SRC_GLOB)):
        all_mods.extend(parse_file(f))
    mapped, need_manual = [], []
    for mod in all_mods:
        hay = mod["name"] + " " + mod["id"]
        hit = None
        for pat, subject in KEYWORDS:
            if re.search(pat, hay, re.I):
                hit = subject
                break
        line, hue = FAMILY.get(mod["family"], ("银白色", 210))
        entry = dict(mod, line=line, hue=hue,
                     subject=hit or FAMILY_FALLBACK.get(mod["family"], "一枚科技核心徽记"),
                     subject_source="keyword" if hit else "family_fallback")
        (mapped if hit else need_manual).append(entry)
    out = {"total": len(all_mods), "auto_mapped": len(mapped),
           "need_manual": len(need_manual), "entries": mapped,
           "need_manual_ids": [m["id"] + " " + m["name"] for m in need_manual]}
    with open(OUT, "w", encoding="utf-8") as f:
        json.dump(out, f, ensure_ascii=False, indent=1)
    print("total=%d auto=%d need_manual=%d -> %s" %
          (len(all_mods), len(mapped), len(need_manual), OUT))


if __name__ == "__main__":
    main()
