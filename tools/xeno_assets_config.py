# -*- coding: utf-8 -*-
"""v27 星冥族 20 单位专属美术资产配置（卡图 + idle/attack 动画 prompt 单一真身）。

设计语言：星冥族 = 生物机械 + 灵能晶体 + 深紫/暗青/星辉白配色 + 生物荧光，
与借用期的人类地球军械卡图（铁灰/橄榄绿/锈蚀金属）形成明显差别。

消费方：
  generate_xeno_card_icons.py  -- 卡图生成（agnes-image-2.1-flash，白底）
  deploy_xeno_card_icons.py    -- 卡图部署（白转透 512 + enemy/ + player/ 翻转 + _ref 白底参考图）
  sync_xeno_extra_anims.py     -- 把 ANIMS 合并进 tools/unit_animations_extra.json
                                  （generate_unit_animations.py create/poll/build +
                                   deploy_unit_anims.py 消费 extra json）
"""

# 卡图 prompt 骨架：正面意象锁死 + 结构性负面排除（勿加概念负面词，见 tools/_agnes_image_api.md）
STRICT_PREFIX = (
    "STRICTLY a pure 2D side profile silhouette view, absolutely NO front view, "
    "NO three-quarter view, NO perspective depth, flat orthographic game sprite, "
    "single subject only centered, the unit FACES TOWARD THE LEFT side of the frame, "
    "clean pure white background with NO ground, "
    "NO shadow, NO floor, NO reflection, NO watermark, NO signature, NO text, "
    "NO extra sketches, NO environment, "
    "studio isolated product shot style. "
)
XENO_STYLE = (
    "星冥族异族文明单位设定，生物机械与灵能晶体构造，深紫罗兰与暗青主色，"
    "青色灵能晶体发光，星辉白纹路点缀，生物荧光光晕，"
)
NEGATIVE = (
    "不要：三分之四视角、斜侧视、透视 perspective、广角、仰视、俯视、等距 isometric、"
    "鸟瞰 top-down、看到顶部、背景场景、地面、投影底板、文字、水印、logo、人类士兵、现代军车。"
)

# key 与 data/xeno_units.gd 的 visual_fallback 一一对应（vis_xeno_<short>）
UNITS = [
    # ── A 段 · 基础战线（8）──
    {
        "key": "vis_xeno_swarmling", "display": "蚀群幼体", "air": False,
        "subject": (
            "星冥族小型蚀群幼体虫，四足低伏虫形生物，半透明几丁质甲壳下流动青色能量脉络，"
            "一对镰刀状骨刃前肢收拢在胸前，头部三只发光复眼，尾部锥刺，整体娇小敏捷"
        ),
    },
    {
        "key": "vis_xeno_probe", "display": "晶工探测器", "air": False,
        "subject": (
            "星冥族晶工探测器，三足支架上的旋转晶体构造体，中央悬浮切割水晶棱柱，"
            "棱柱尖端聚焦一道横向青色光束，支架为暗紫生物金属，晶体间有能量弧光连接"
        ),
    },
    {
        "key": "vis_xeno_zealot", "display": "渡暮狂战士", "air": False,
        "subject": (
            "星冥族渡暮狂战士，高大类人异族武士的纯侧面剪影，只能看到单侧肩膀与手臂，"
            "一臂向前平伸挥出一道青蓝色等离子光刃指向画面左侧，另一臂收于身后半掩，"
            "胸甲与战裙为紫水晶质感生物甲片层叠，头部后掠冠羽发光，独侧眼睛亮青色，前倾冲刺姿态"
        ),
    },
    {
        "key": "vis_xeno_stalker", "display": "影跃猎者", "air": False,
        "subject": (
            "星冥族影跃猎者，四足机械猎兽，纤长暗紫色装甲腿低伏，"
            "背部镶嵌三面折射棱镜晶体，头部菱形独眼发光，轮廓流线敏捷"
        ),
    },
    {
        "key": "vis_xeno_adept", "display": "灵裔侍从", "air": False,
        "subject": (
            "星冥族灵裔侍从，纤瘦类人异族施法者，额前镶嵌发光灵能水晶，"
            "身前悬浮一颗旋转的水晶法器，长袍状生物甲片层叠，周身环绕细小灵能光点"
        ),
    },
    {
        "key": "vis_xeno_sentinel", "display": "哨兵浮棱", "air": False,
        "subject": (
            "星冥族哨兵浮棱，悬浮感的三棱柱晶体哨戒构造体，中央大棱晶横向发出棱光束，"
            "三个环形晶体碎片环绕主体，底部一束青色反重力光锥收于地面支点"
        ),
    },
    {
        "key": "vis_xeno_dragoon", "display": "龙骑残躯", "air": False,
        "subject": (
            "星冥族龙骑残躯，四足机械化生物载具，侧面搭载一门长管相位炮指向画面左侧，"
            "装甲为暗紫生物金属板，腿部液压晶体关节发光，背部残留褶皱生物组织"
        ),
    },
    {
        "key": "vis_xeno_plasma_bug", "display": "等离囊虫", "air": False,
        "subject": (
            "星冥族等离囊虫，肥胖昆虫状活体炮台，背部隆起巨大半透明等离子囊，"
            "囊内橙紫色等离子体翻滚发光，腹部六条短足撑地，头部小而尖朝向画面左侧"
        ),
    },
    # ── B 段 · 精英战线（6）──
    {
        "key": "vis_xeno_tripod", "display": "三足行者", "air": False,
        "subject": (
            "星冥族三足行者，巨型三足步行战斗构筑体，三条细长装甲腿支撑圆顶主体，"
            "顶部热射线棱镜炮塔指向画面左侧，圆顶镶满发光晶体窗，悬垂触须状传感器"
        ),
    },
    {
        "key": "vis_xeno_hunter", "display": "隐面猎手", "air": False,
        "subject": (
            "星冥族隐面猎手，无面人形猎手，面部为光滑镜面无五官并反射星光，"
            "肩部搭载小型粒子炮指向画面左侧，暗色棱纹甲与半透明短斗篷，身形瘦削"
        ),
    },
    {
        "key": "vis_xeno_mimic", "display": "拟时者", "air": False,
        "subject": (
            "星冥族拟时者，细长人形异族，周身漂浮数枚钟表水晶碎片状时棘，"
            "身体轮廓带淡淡残影拖尾，半透明时序光带缠绕四肢，头部狭长无面"
        ),
    },
    {
        "key": "vis_xeno_biomorph", "display": "异变体", "air": False,
        "subject": (
            "星冥族异变体，兽性双足变异生物，四肢覆骨刺利爪，暴露的肌肉与甲壳交错，"
            "背脊一排酸绿色发光囊泡，前倾低伏撕咬姿态朝向画面左侧"
        ),
    },
    {
        "key": "vis_xeno_dark_templar", "display": "暗影执刃", "air": False,
        "subject": (
            "星冥族暗影执刃，披纱斗篷的暗影武士，兜帽阴影下无面只有两点幽蓝眼光，"
            "单手握一柄虚空弯刀指向画面左侧，刀身深紫近黑边缘泛星辉，斗篷碎边漂浮"
        ),
    },
    {
        "key": "vis_xeno_reaver", "display": "蚀甲虫", "air": False,
        "subject": (
            "星冥族蚀甲虫，巨型甲虫状活体攻城炮台，厚重层叠的生物装甲背甲，"
            "背甲开孔处探出蠕虫状发射管朝向画面左侧，甲壳缝隙透出青色能量光，六条粗足"
        ),
    },
    # ── C 段 · 王牌（3，combat_kind=3 空中）──
    {
        "key": "vis_xeno_interceptor", "display": "拦截机群", "air": True,
        "subject": (
            "星冥族拦截机群，三架小型碟形晶体无人拦截器组成楔形编队，"
            "每架为菱形晶体核心加环形翼，尾部拖星辉轨迹，整体朝向画面左侧"
        ),
    },
    {
        "key": "vis_xeno_carrier", "display": "蚀空母舰", "air": True,
        "subject": (
            "星冥族蚀空母舰，巨大浮空棱晶母舰，鲸形生物金属舰体朝向画面左侧，"
            "腹部机库开口透出格状微光，舰脊一排水晶突塔，底部反重力光晕"
        ),
    },
    {
        "key": "vis_xeno_saucer", "display": "猎能碟", "air": True,
        "subject": (
            "星冥族猎能碟，经典倒扣碟形飞行器，碟缘一道环形晶体碎片旋转环，"
            "底部中央巨大的聚能主炮晶体充能发光，碟面星辉纹路流动，整体朝向画面左侧"
        ),
    },
    # ── D 段 · 首领（3）──
    {
        "key": "vis_xeno_templar", "display": "渡师·风暴", "air": False,
        "subject": (
            "星冥族渡师·风暴，庄严的高阶异族施法者，浮空坐台式层叠长袍构装下缘收于地面支点，"
            "华丽多层晶体头冠，双手之间一团灵能风暴漩涡电弧缠绕，长袍垂边碎成光粒"
        ),
    },
    {
        "key": "vis_xeno_thing", "display": "拟形之惧", "air": False,
        "subject": (
            "星冥族拟形之惧，不稳定的变形恐惧生物，多个镜面甲壳板块浮空拼合成庞然巨躯，"
            "伸出数条拟形触手与刃状肢体朝向画面左侧，板块缝隙涌动星光"
        ),
    },
    {
        "key": "vis_xeno_mothership", "display": "蚀冕方舟", "air": True,
        "subject": (
            "星冥族蚀冕方舟，巨型王冠状浮空方舟母舰，多层晶体环冠缓慢旋转，"
            "中央舰体如倒悬尖塔，底部湮灭光炮巨大晶体充能发光，周身星辉环绕，史诗感"
        ),
    },
]

assert len(UNITS) == 20


def card_prompt(unit: dict) -> str:
    return STRICT_PREFIX + (
        unit["subject"]
        + "，严格2D正侧视，正交投影，游戏单位立绘/精灵图姿态，"
        + XENO_STYLE
        + "完整单位居中入镜，主体占比约八成，轮廓清晰剪影可读，"
        + "干净棚拍纯白背景，无地面无场景无杂物，高清。" + NEGATIVE
    )


# ---------------------------------------------------------------- 动画 prompt
# 骨架固化为：首帧一致性 + 朝向锁定 + 精灵风格 + 动作 + 镜头锁定 + 白底 + 循环
_IDLE_TAIL = (
    "镜头完全锁定，无运镜，无变焦，无平移，单位始终完整在画面内不被裁切。"
    "纯白色无缝背景，无地面，无阴影，无文字，无水印。"
    "动作结尾精确回到起始姿态，首尾帧一致，动作平滑无缝循环。"
)
_ATTACK_TAIL = (
    "镜头完全锁定，无运镜，无变焦，单位始终完整在画面内。"
    "纯白色无缝背景，无地面，无阴影，无文字，无水印。"
)


def _idle(keep: str, motion: str) -> dict:
    return {"seconds": "4", "prompt": (
        "严格保持首帧图像中该单位的外观、比例、甲壳纹理、晶体与发光细节完全一致，不改变设计。"
        + keep
        + "严格2D游戏精灵风格，平面正交正侧视。单位原地静止待机：" + motion + "。" + _IDLE_TAIL
    )}


def _attack(keep: str, motion: str) -> dict:
    return {"seconds": "5", "prompt": (
        "严格保持首帧图像中该单位的外观、比例、甲壳纹理、晶体与发光细节完全一致，不改变设计。"
        + keep
        + "严格2D游戏精灵风格，平面正交正侧视。单位原地不动，向画面左侧方向：" + motion + "。" + _ATTACK_TAIL
    )}


_KEEP_FACING = "该单位始终保持首帧的朝向，武器与头部指向画面左侧，绝不掉头，绝不转向，绝不转头，不看向镜头。"

ANIMS = {
    "vis_xeno_swarmling": {
        "idle": _idle(_KEEP_FACING, "四足轻颤，甲壳下的青色能量脉络缓慢流动明灭，三只复眼轮流闪烁，尾部锥刺轻微摆动后回位"),
        "attack": _attack(_KEEP_FACING, "快速挥出一对镰刀状前肢双连斩，青色刃光弧线闪现，身体随挥砍小幅前倾后复位"),
    },
    "vis_xeno_probe": {
        "idle": _idle("该单位始终保持首帧的朝向，晶体棱柱指向画面左侧，绝不掉头，绝不转向。", "三足支架纹丝不动，中央水晶棱柱缓慢自转，晶体间能量弧光轮流明灭"),
        "attack": _attack("该单位始终保持首帧的朝向，晶体棱柱指向画面左侧，绝不掉头，绝不转向。", "水晶棱柱聚焦充能后向左发射一道青色切割光束，光束短暂过曝后棱柱复位，支架轻微震颤"),
    },
    "vis_xeno_zealot": {
        "idle": _idle(_KEEP_FACING, "双臂等离子光刃保持指向左侧，光刃长度如呼吸般轻微涨落，胸甲晶体微微脉动，冠羽轻摆"),
        "attack": _attack(_KEEP_FACING, "双臂光刃向左交叉挥砍两次，青蓝刃光划出弧线残影，肩膀随挥砍转动后回到初始姿态"),
    },
    "vis_xeno_stalker": {
        "idle": _idle(_KEEP_FACING, "四足低伏蓄势微颤，背部三面棱镜折射出流动光斑，菱形独眼缓慢闪烁"),
        "attack": _attack(_KEEP_FACING, "背部棱镜聚焦向左射出一道折射光束，光斑汇聚成束后散开，身体随发射轻微后坐"),
    },
    "vis_xeno_adept": {
        "idle": _idle(_KEEP_FACING, "悬浮的水晶法器缓慢自转，周身灵能光点绕体环流，额前水晶呼吸发光"),
        "attack": _attack(_KEEP_FACING, "水晶法器向左释放一圈扩张的灵能冲击波光环，法器短暂过曝，长袍随能量涌动轻摆后复位"),
    },
    "vis_xeno_sentinel": {
        "idle": _idle("该单位始终保持首帧的朝向与悬浮高度，棱晶指向画面左侧，绝不掉头，绝不转向。", "整体轻微上下浮动，三个环形晶体碎片缓慢公转，底部光锥稳定"),
        "attack": _attack("该单位始终保持首帧的朝向，棱晶指向画面左侧，绝不掉头，绝不转向。", "中央棱晶向左持续照射一道棱光束，光束轻微抖动闪烁，环形碎片加速旋转后复位"),
    },
    "vis_xeno_dragoon": {
        "idle": _idle(_KEEP_FACING, "四足站立静止，腿部关节晶体呼吸发光，相位炮管轻微下沉回位，背部生物组织微微蠕动"),
        "attack": _attack(_KEEP_FACING, "相位炮向左开炮一次，炮口青色闪光炸现，炮管明显后坐退缩再复位，躯体随之后震"),
    },
    "vis_xeno_plasma_bug": {
        "idle": _idle(_KEEP_FACING, "背部等离子囊内橙紫色等离子体缓慢翻滚明灭，腹部随呼吸起伏，六短足纹丝不动"),
        "attack": _attack(_KEEP_FACING, "背囊猛然收缩，向左前方抛射一团橙紫色等离子体团划出弧线，囊体排空后重新充盈复位"),
    },
    "vis_xeno_tripod": {
        "idle": _idle(_KEEP_FACING, "三条长腿站立静止，圆顶晶体窗轮流明灭，悬垂触须传感器轻摆，炮塔微微转动后回位"),
        "attack": _attack(_KEEP_FACING, "顶部棱镜炮塔向左持续照射热射线光束，光束灼热抖动，圆顶随能量输出震颤，炮塔复位"),
    },
    "vis_xeno_hunter": {
        "idle": _idle(_KEEP_FACING, "静立不动，镜面无面脸反射星光流动，半透明斗篷轻摆，肩部粒子炮微微升降"),
        "attack": _attack(_KEEP_FACING, "肩部粒子炮向左连续脉冲射击，炮口星光连续闪烁，肩膀随后坐轻微抖动"),
    },
    "vis_xeno_mimic": {
        "idle": _idle(_KEEP_FACING, "周身钟表水晶碎片缓慢公转，身体残影时隐时现，时序光带沿四肢流动"),
        "attack": _attack(_KEEP_FACING, "抬手向左掷出一枚时棘水晶碎片，碎片拖出时间残像轨迹飞出，手臂与碎片残影重叠后复位"),
    },
    "vis_xeno_biomorph": {
        "idle": _idle(_KEEP_FACING, "背脊酸绿色囊泡明灭呼吸，利爪轻叩地面，低伏身躯随呼吸起伏"),
        "attack": _attack(_KEEP_FACING, "向左猛然扑击挥爪两次，酸绿色爪光残影闪现，身体前冲后拉回初始低伏姿态"),
    },
    "vis_xeno_dark_templar": {
        "idle": _idle(_KEEP_FACING, "斗篷碎边漂浮，虚空弯刀刀身星辉缓慢流转，身影半透明化轻微闪烁"),
        "attack": _attack(_KEEP_FACING, "身形瞬间虚影化向左突进斩击一刀，虚空刀光划出深紫色弧线，随后回到初始站位显形"),
    },
    "vis_xeno_reaver": {
        "idle": _idle(_KEEP_FACING, "厚重甲壳随呼吸缓慢起伏，甲壳缝隙青色能量光流动，蠕虫状发射管轻微蠕动"),
        "attack": _attack(_KEEP_FACING, "背甲发射管向左射出一条扭动的蠕虫状弹药，发射管收缩回弹，甲壳随发射震颤"),
    },
    "vis_xeno_interceptor": {
        "idle": _idle("编队始终保持首帧的楔形阵形与朝向，机头指向画面左侧，绝不掉头。", "三机整体轻微悬浮浮动，环形翼旋转，尾部星辉轨迹微微流动"),
        "attack": _attack("编队始终保持首帧的楔形阵形与朝向，机头指向画面左侧，绝不掉头。", "三机同时向左齐射脉冲光弹，机首晶体炮口连续闪烁，机身轻微后坐"),
    },
    "vis_xeno_carrier": {
        "idle": _idle("舰体始终保持首帧的朝向，舰首指向画面左侧，绝不掉头，绝不转向。", "巨大舰体缓慢悬浮漂浮，腹部机库格状微光明灭，舰脊水晶突塔轮流闪烁"),
        "attack": _attack("舰体始终保持首帧的朝向，舰首指向画面左侧，绝不掉头，绝不转向。", "腹部机库开口开启，向左释放三架小型拦截机飞出画面，机库灯光闪动后关闭复位"),
    },
    "vis_xeno_saucer": {
        "idle": _idle("该单位始终保持首帧的朝向，绝不掉头，绝不转向。", "碟体悬浮并轻微升降，碟缘环形晶体缓慢公转，碟面星辉纹路流动"),
        "attack": _attack("该单位始终保持首帧的朝向，绝不掉头，绝不转向。", "底部聚能主炮晶体充能过曝后向左发射一道粗壮的聚能光柱，光柱衰减，碟体随发射轻微下沉后复位"),
    },
    "vis_xeno_templar": {
        "idle": _idle("该单位始终保持首帧的朝向与浮空高度，双手风暴漩涡位于胸前，绝不掉头，绝不转向。", "浮空坐台轻微升降，双手间灵能风暴漩涡缓慢旋转，电弧跳动，长袍光粒垂边漂浮"),
        "attack": _attack("该单位始终保持首帧的朝向，绝不掉头，绝不转向。", "双手向左推出灵能风暴，紫色电弧漩涡向左侧扩大炸开，随后漩涡收回胸前复位"),
    },
    "vis_xeno_thing": {
        "idle": _idle(_KEEP_FACING, "镜面甲壳板块缓慢错动重组，触手蠕动，板块缝隙星光涌动明灭"),
        "attack": _attack(_KEEP_FACING, "躯干前倾，向左猛然伸出多条刃状触手连续刺击，镜面板块翻开又合拢，回到初始构型"),
    },
    "vis_xeno_mothership": {
        "idle": _idle("该单位始终保持首帧的朝向，绝不掉头，绝不转向。", "多层晶体环冠缓慢旋转，周身星辉明灭，底部湮灭光炮晶体呼吸发光"),
        "attack": _attack("该单位始终保持首帧的朝向，绝不掉头，绝不转向。", "底部湮灭光炮晶体充能过曝后向左发射巨大光柱，光柱持续后衰减熄灭，环冠加速旋转后复位"),
    },
}

assert set(ANIMS.keys()) == {u["key"] for u in UNITS}
