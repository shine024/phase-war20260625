#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""批次② Task 7 改造描述落地（202 条，v2 名不动版）——重写辅助。

铁律：只改 description 字符串内容；name/name_en/prototype 及其余一切键零动。
基调：军语克制体（样例 4/5/6 基调锚）——句号分句、去「+」罗列、去游戏黑话、
      数字排版「8 点」「+30%」、禁感叹号；描述域不新增「改装」。
数值内核：旧→新数值子串多重集断言（符号与 × 归一后比较），不等即失败。

用法：python tools/_tmp_b2_d7_rewrite.py           # dry-run（只打印对照）
      python tools/_tmp_b2_d7_rewrite.py --write   # 落盘
"""

from __future__ import annotations

import re
import sys
from collections import Counter
from pathlib import Path

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8")

ROOT = Path(__file__).resolve().parents[1]
DIR = ROOT / "data" / "modification_modules"

# 期望条目数（文件名去掉 _mods.gd 后缀）
EXPECTED = {
    "infantry": 27, "universal": 31, "air": 25, "artillery": 23, "armor": 18,
    "anti_air": 17, "engineer": 16, "enhancement": 16, "recon": 15, "fort": 14,
}

# 已合规保留（军语基调已达标，逐字不动）的条目
KEEPS = {
    "infantry": ["inf_23_combat_stimulant"],
    "universal": [],
    "air": ["air_15_afterburner", "air_17_bombsight", "air_18_heavy_rack",
            "air_20_standoff_missile", "air_21_terrain_radar", "air_22_countermeasure"],
    "artillery": [],
    "armor": ["arm_18_gun_mantlet"],
    "anti_air": ["aa_13_radar_lock", "aa_14_searchlight", "aa_15_flak_burst"],
    "engineer": [],
    "enhancement": ["enh_dmg_up", "enh_def_flat", "enh_speed_up", "enh_range_up",
                    "enh_crit", "enh_lifesteal", "enh_penetration", "enh_dodge"],
    "recon": ["rec_13_target_designator"],
    "fort": [],
}

REWRITES: dict[str, dict[str, str]] = {
    "infantry": {
        "inf_01_submachine_gun": "缩短枪管，换大容量弹鼓。近战压制火力提升。",
        "inf_02_assault_rifle": "中间威力弹药革命。火力与机动自此平衡。",
        "inf_03_small_caliber": "小口径弹药，携弹量翻倍。持续作战能力提升。",
        "inf_04_bullpup": "枪机后置，全枪缩短。机动性提升。",
        "inf_05_ap_ammo": "钨芯穿甲弹头。步兵由此获得反装甲火力。",
        "inf_06_hp_ammo": "弹头扩张变形。对软组织目标停止作用强。",
        "inf_07_optical_scope": "光学瞄准镜。中距离命中率与有效射程提升。",
        "inf_08_holographic": "全息视窗快速瞄准。近战反应提升。",
        "inf_09_dual_mag": "弹匣并联。换弹时间减半，火力压制不中断。",
        "inf_10_saw": "弹链供弹。压制火力持续输出。",
        "inf_11_armor_insert": "硬质插板抵御步枪弹直射。防护力显著提升。",
        "inf_12_body_armor": "前后插板，加挂侧甲。全方位防护。",
        "inf_13_helmet_upgrade": "复合材料盔体，附件接口标准化。防护与兼容性提升。",
        "inf_14_knee_pads": "护具内衬减负。部署加速 10%。",
        "inf_15_riot_shield": "随行移动掩体。防护力大幅提升。",
        "inf_16_exoskeleton": "液压外骨骼。负重翻倍，机动与部署速度提升。",
        "inf_17_tourniquet": "四肢止血带。控制大出血，战斗内缓慢回复。",
        "inf_18_ifak": "止血与气道管理。濒死时回复 15% 生命值（每战 1 次）。",
        "inf_19_radio": "单兵战术电台。自身攻速 +5%，周围友军攻击力 +3%。",
        "inf_20_night_vision": "微光夜视瞄准。暴击率 +15%。",
        "inf_21_thermal": "热成像瞄准。暴击率 +23%。",
        "inf_22_breaching": "破门装备。部署加速 20%，对轻装伤害 -5%。",
        "inf_24_urban_warfare": "城市巷战训练。受到装甲与空军单位攻击时伤害减免 50%。",
        "inf_25_medic_sacrifice": "阵亡时治疗周围 200 像素内友军，恢复量为自身 20% 最大生命值。",
        "inf_26_chemical_warhead": "攻击 35% 概率施加化学毒剂：每秒造成 8 点伤害，持续 6 秒（绿色毒雾）。",
        "inf_27_napalm": "攻击 30% 概率引燃目标：每层每秒 6 点伤害，可叠至 5 层，持续 5 秒（橙色火苗）。",
    },
    "universal": {
        "gen_01_comms": "班组基础通讯。射速与暴击小幅提升。",
        "gen_02_digital": "数字化单兵系统。三维防御提升 7.5%。",
        "gen_03_camouflage": "多地形伪装迷彩。闪避 +20%。",
        "gen_04_vest": "模块化战术背心。基础防护提升。",
        "gen_05_shield": "随行防护盾。防护大幅提升，速度略降。",
        "gen_06_laser_designator": "激光指示目标。对装甲伤害 +10%。",
        "gen_07_mine_resistant": "强化底盘与防雷座椅。三维防御大幅提升。",
        "gen_08_nbc_protection": "核生化三防。减伤 +30%。",
        "gen_09_ir_jammer": "红外干扰机压制制导。导弹闪避提升。",
        "gen_10_ammo_rack": "外挂弹药架。持续作战能力提升。",
        "gen_11_phase_resonance": "独占改造。三维攻击全面提升，相位能量强化火力。",
        "gen_12_phase_shielding": "独占改造。减伤 +20%，生命 +30%，相位能量构造防护层。",
        "gen_13_phase_overdrive": "独占改造。攻速 +30%，暴击 +15%，相位能量过载驱动。",
        "gen_14_phase_shield_gen": "生成独立相位护盾池（2000 点）。伤害优先扣相位池，每秒回复 50 点。",
        "gen_15_laser_marker": "攻击时 100% 概率标记目标。被标记目标受到 +20% 额外伤害，持续 5 秒，炮兵优先打击。",
        "gen_16_emp_pulse": "攻击 35% 概率释放电磁脉冲：目标攻速 -30%、暴击 -20%、闪避 -15%，持续 4 秒，并造成 10 点真实伤害（蓝色电弧）。",
        "gen_17_electronic_hijack": "周期性劫持半径 200 内敌方增益光环（指挥、堡垒庇护）。被劫持光环失效，增益转由本单位享有，持续 4 秒，冷却 18 秒。",
        "gen_combustion_catalyst": "所有燃烧持续伤害 ×1.3。助燃燃烧链全局增益。",
        "gen_overload_capacitor": "电磁脉冲真实伤害提升。目标石墨电子损坏 ≥5 时触发电磁脉冲反射，连锁 3 个相邻敌方。电磁脉冲链触发器。",
        "gen_nano_catalyst": "纳米病毒概率提升。浓度 ≥50 时 30% 概率感染扩散至相邻敌人。纳米浓度场触发器。",
        "gen_beam_splitter": "光束武器命中激光谐振 ≥3 的目标时追加 2 道次级光束，每道 40% 伤害。光束谐振链触发器。",
        "gen_reflector_array": "光束武器命中带激光谐振的目标时 30% 概率反射至相邻敌方，衰减 60%。光束谐振链触发器。",
        "gen_weakpoint_analyzer": "命中同时带有无人机标记与雷达锁定的目标时触发弱点暴露，下次命中 +50% 暴击伤害。侦察链式触发器。",
        "gen_pollution_accumulator": "化学持续伤害 ×1.2。每次化学命中额外累积战场污染度。化学污染场触发器。",
        "gen_converted_munitions": "攻击维度转换：对轻轴攻击整体转按对甲轴结算（武器、攻值、目标防御三维都走对甲），对甲与对空轴不变。适合对甲火力远强于对轻的载具与火炮。",
        "gen_expansion_chamber": "同时攻击目标数 +1。每次开火额外向射程内另一敌人射击，全额伤害独立结算。",
        "gen_overflow_shield": "溢流转化：治疗超出生命上限的部分按 60% 转化为护盾。护盾上限不变，仍为双倍生命值。",
        "gen_truestrike_pinpoint": "按比例无视目标 50% 闪避率。高闪避侦察与飞行单位的天敌。",
        "gen_relay_antenna": "改造光环（ally_* 类）影响范围扩至全场。需同时装备带光环的改造方有收益。",
        "gen_unified_splash": "统一溅射公式：自身溅射比例 60%，曲射与命中路径共用一轴，所有命中附带 60% 溅射伤害。",
        "gen_stealth_coating": "机体与车体表面吸波涂层，降低雷达与火控锁定。闪避与对空防御提升。",
    },
    "air": {
        "air_01_turbofan": "大推力涡扇换装。部署加速 60%。",
        "air_02_vector_thrust": "推力矢量喷管。机动性大幅提升。",
        "air_03_stealth_coating": "雷达吸波隐身涂层。闪避 +40%。",
        "air_04_aesa": "多目标锁定。大范围溅射与射程提升。",
        "air_05_helmet_sight": "头盔瞄准具离轴发射。射速提升。",
        "air_06_bvr_missile": "超视距空空导弹。射程与暴击伤害提升。",
        "air_07_dogfight_missile": "红外格斗导弹。暴击伤害提升。",
        "air_08_ecm": "电子对抗干扰。导弹闪避提升。",
        "air_09_air_refuel": "空中加油补给。攻速 +50%。",
        "air_10_drop_tank": "外挂副油箱增加燃料。暴击率提升。",
        "air_11_weapon_rack": "复合挂架外挂武器。攻速 +50%。",
        "air_12_data_link": "数据链编队协同：自身三维攻击 +7.5%，周围友军三维攻击 +7.5%。",
        "air_13_ejection_seat": "钛合金装甲包裹座舱。抗弹能力大幅提升。",
        "air_14_swing_wing": "可变后掠翼。部署加速 40%，闪避 +10%。",
        "air_16_phase_shift": "受到暴击时相位偏移引擎储能。下次攻击必定暴击，敌方暴击优势转化为我方反击。",
        "air_19_cluster_dispenser": "一次投弹覆盖大片地面目标。溅射比例与溅射范围提升，轰炸机核心配置。",
        "air_thermolite_bomb": "命中 30% 概率挂燃烧。层数 ≥8 时触发化学爆发，半径 80 内感染 3 个相邻敌人。助燃燃烧链触发器。",
        "air_antiradiation_missile": "电磁伤害提升。目标石墨电子损坏层数越高伤害越高，每层 +15%。电磁脉冲链触发器。",
        "air_targeting_laser": "命中 60% 概率挂激光谐振层数，累积 ≥3 触发多重攻击。光束谐振链触发器。",
    },
    "artillery": {
        "art_01_rifling": "加长炮管，优化膛线。射程和精度提升。",
        "art_02_extended_range": "火箭增程弹。射程大幅提升，威力略降。",
        "art_03_guided_shell": "GPS 制导炮弹。暴击率与暴击伤害大幅提升。",
        "art_04_cluster_munition": "子弹药撒布。范围伤害增加，单目标伤害略降。",
        "art_05_counter_battery_radar": "反炮兵雷达定位敌炮阵地。反击精确，暴击伤害提升。",
        "art_06_fire_computer": "弹道自动解算。射速大幅提升。",
        "art_07_ammo_supply": "随行弹药补给车。持续射击时间大幅延长。",
        "art_08_uav": "无人机校射。暴击伤害与炮兵攻速提升。",
        "art_09_rapid_fire": "优化装填流程。射速提升。",
        "art_10_auto_nav": "自动导航定位。部署速度提升。",
        "art_11_thermobaric": "温压战斗部。对堡垒伤害大幅提升。",
        "art_12_fortification": "构筑防御阵地。防护提升，部署略慢。",
        "art_13_apfsds_sabot": "每次命中撕裂目标装甲：降低 8% 防御，最多叠加 5 层（累计 -40% 防御）。",
        "art_14_counter_battery": "被攻击时自动标记攻击者（5 秒）。炮兵优先反击被标记目标，另获 2 次优先反击机会。",
        "art_15_emp_round": "攻击 40% 概率触发电磁脉冲：目标攻速 -30%、暴击 -20%、闪避 -15%，持续 4 秒，并造成 12 点真实伤害（蓝色电弧）。",
        "art_16_nano_virus": "攻击 25% 概率注入纳米病毒：目标每秒损失 2% 最大生命值，持续 8 秒（紫色粒子）。",
        "art_incendiary_mix": "命中 40% 概率挂助燃剂标记，层数累积。与白磷弹、温压弹组成助燃燃烧链。",
        "art_white_phosphorus": "35% 概率挂燃烧，助燃剂层数越高燃烧概率越大。链路激活时燃烧层数上限 5→10。",
        "art_graphite_fiber": "命中 50% 概率累积石墨电子损坏层数。与电磁战斗部、反辐射导弹组成电磁脉冲链。",
        "art_nano_amp": "纳米病毒概率与伤害提升。与纳米播种机、纳米催化剂组成纳米浓度场。",
        "art_chem_cluster": "50% 概率挂化学毒，每次命中累积战场化学污染度。与酸液战斗部、化学喷洒器组成化学污染场。",
        "sup_nano_seeder": "每次攻击累积战场纳米浓度，浓度越高纳米病毒伤害越高。纳米浓度场触发器。",
        "sup_targeting_drone": "增强无人机标记范围与易伤值。与相控阵雷达叠加，触发集火链式弱点暴露。侦察链式触发器。",
    },
    "armor": {
        "arm_01_sloped_armor": "倾斜装甲增加等效厚度。固定防护与百分比防护双通道。",
        "arm_02_composite_armor": "多层复合装甲。对装甲防御 +30%，减伤 +50%。",
        "arm_03_reactive_armor": "爆炸反应装甲。受击时反弹 30% 伤害给攻击者，可触发 3 次。",
        "arm_04_aps": "主动拦截来袭导弹。30% 概率完全免伤，可触发 3 次。",
        "arm_05_smoothbore": "换装滑膛炮：对装甲攻击替换为确定值。弱炮收益最大，等效火力不重复换装。",
        "arm_06_apfsds": "高动能尾翼稳定穿甲弹。对装甲伤害最大化。",
        "arm_07_gun_missile": "炮射导弹。获得对空交战能力。",
        "arm_08_autoloader": "自动装弹机。射速大幅提升。",
        "arm_09_turbine": "燃气轮机换装。部署加速 40%。",
        "arm_10_diesel_turbo": "增压柴油机。部署加速 20%，生命 +10%。",
        "arm_11_fire_control": "猎歼式火控。精准度大幅提升。",
        "arm_12_thermal_sight": "热成像瞄准。暴击率 +15%。",
        "arm_13_deep_wading": "弹道计算机实时解算。开火节奏加快。",
        "arm_14_mine_plow": "附加装甲使三维防御提升 30%，轻微减速。",
        "arm_15_data_link": "战术数据链协同：自身暴击 +5%，周围友军暴击 +10%。",
        "arm_16_battle_frenzy": "承受攻击积累战意。受击 8 次后激活战斗狂热，5 秒内攻击力 +35%。",
        "arm_17_spacer_armor": "焊接附加钢板，留空气层间隙。固定防护与百分比防护双通道。",
    },
    "anti_air": {
        "aa_01_radar": "炮瞄雷达自动跟踪。暴击伤害和射速提升。",
        "aa_02_iff": "敌我识别器辅助索敌。对轻装伤害提升。",
        "aa_03_missile_rail": "挂装防空导弹。对空火力大幅提升。",
        "aa_04_quad_mount": "多管并联。射速提升。",
        "aa_05_proximity_fuze": "近炸引信空爆。暴击伤害与溅射提升。",
        "aa_06_laser": "激光近防拦截来袭弹药。30% 概率拦截，弹药无限，无次数限制。",
        "aa_07_aesa": "相控阵多目标锁定。大范围溅射与射程提升。",
        "aa_08_power_gen": "车载发电持续供能。攻速 +100%。",
        "aa_09_smoke_launcher": "烟幕遮蔽。导弹闪避提升 30%。",
        "aa_10_camouflage": "红外伪装网隐蔽。闪避 +30%。",
        "aa_11_auto_fc": "全自动火控。射速与暴击伤害提升。",
        "aa_12_fire_on_move": "行进间射击。攻速 +10%，暴击率 -20%。",
        "aa_emp_warhead": "40% 概率释放电磁脉冲，降低攻速、暴击与闪避并造成真实伤害。目标石墨电子损坏层数越高伤害越高。电磁脉冲链触发器。",
        "aa_acid_warhead": "45% 概率挂化学毒。目标化学层数 ≥5 时额外护甲穿透 +20%。化学污染场触发器。",
    },
    "engineer": {
        "eng_01_mine_sweeper": "破甲弹命中时爆炸反制。伤害大幅减免。",
        "eng_02_explosives": "定向爆破装药。对堡垒伤害大幅提升。",
        "eng_03_welding": "战场焊接抢修。持续回复生命值。",
        "eng_04_bridge": "坦克架桥车随行。部署加速 5%。",
        "eng_05_shovel": "推土铲构筑工事。防御提升，轻微减速。",
        "eng_06_crane": "外挂间隙装甲板，提前引爆来袭弹丸。",
        "eng_07_generator": "野战发电。三维防御 +12.5%。",
        "eng_08_medical": "机动医疗单元。每秒回复 0.15% 生命值。",
        "eng_09_supply": "弹药补给分发：自身攻速 +15%，周围友军攻速 +30%。",
        "eng_10_camouflage": "大型伪装网隐蔽。闪避 +15%。",
        "eng_11_breaching_charge": "定向爆破对堡垒与装甲目标造成额外真实伤害：每次命中无视防御，扣除目标当前生命值的 5%。",
        "eng_12_reactive_engineering": "工程车加挂爆反装甲。受击时反弹 25% 伤害，可触发 2 次。",
        "eng_13_supply_cache": "阵亡时遗落补给，治疗周围 180 像素内友军，恢复量为自身 15% 最大生命值。",
        "eng_optical_fiber": "光束类武器伤害 +20%。光束谐振链全局增益。",
        "eng_chem_sprayer": "攻击 50% 概率范围挂化学毒，累积战场污染度。化学污染场触发器。",
        "eng_14_salvage_drone": "击毁敌方单位时回收其残余纳米材料修复自身，回复目标最大生命 8%。",
    },
    "enhancement": {
        "enh_hp_up": "生命值上限提升。",
        "enh_def_up": "伤害减免提升。",
        "enh_atkspd_up": "攻速提升，射击间隔缩短。",
        "enh_splash": "溅射伤害提升。",
        "enh_regen": "每秒回复生命值。",
        "enh_chain": "连锁概率提升。",
        "enh_shield_kill": "击杀敌人后生成护盾，掩护连续接战。",
        "enh_crit_dmg": "暴击伤害加成提升。",
    },
    "recon": {
        "rec_01_optical_camouflage": "光学迷彩隐蔽接敌。暴击 +50%。",
        "rec_02_ir_suppression": "热信号遮蔽处理。减伤提升。",
        "rec_03_suppressor": "枪口抑制器压制声光。闪避 +50%。",
        "rec_04_high_power_scope": "高倍观测瞄准。射程与暴击提升。",
        "rec_05_uav": "无人侦察机校射。暴击率提升。",
        "rec_06_tactical_radio": "战术电台通讯协调。暴击率 +30%。",
        "rec_07_gps": "GPS 定位引导。部署加速 20%。",
        "rec_08_nvg": "微光夜视瞄准。暴击率 +15%。",
        "rec_09_breaching": "破门器材随行。城市战部署更快。",
        "rec_10_medkit": "急救包随行。濒死时回复 15% 生命值。",
        "rec_11_decoy": "充气假目标误导敌方。暴击率 +20%。",
        "rec_12_atv": "越野摩托机动。部署加速 60%。",
        "rec_14_crit_designator": "攻击命中 30% 概率挂暴击标注。被标注目标受攻击时暴击率 +50%，持续 5 秒，全队远程优先集火。",
        "rec_phased_radar": "周期扫描锁定敌方高威胁单位，雷达锁定易伤 +15%。与无人机标记叠加触发集火链式。侦察链式触发器。",
    },
    "fort": {
        "for_01_concrete": "钢筋混凝土碉堡装甲。防护大幅提升。",
        "for_02_tunnel": "地下坑道工事，全方位防御。对轻装、对空、对装甲伤害减免。",
        "for_03_auto_turret": "遥控武器站自动射击。射速提升。",
        "for_04_filtration": "三防通风过滤系统。减伤提升。",
        "for_05_ammo_dump": "地下弹药储备。攻击力提升。",
        "for_06_radar": "远程预警雷达索敌。暴击率提升。",
        "for_07_camouflage": "工事伪装覆盖。闪避 +50%。",
        "for_08_trench": "反坦克壕阻滞装甲推进。对装甲伤害 +50%。",
        "for_09_minefield": "雷场封锁通路。对轻装伤害 +10%。",
        "for_10_command": "指挥协同：自身暴击 +7.5%，周围友军暴击 +15%。",
        "for_11_advanced_minefield": "堡垒外围部署智能雷场。对接近的敌人造成 150 点一次性爆炸伤害。",
        "for_12_anti_tank_trench": "挖掘反坦克壕。200 像素范围内敌方移速降低 40%。",
        "for_13_command_bunker": "强化指挥塔。250 像素范围内友军暴击 +15%。",
        "for_14_bomb_shelter": "顶层防爆隔层与地下掩体。减伤与耐久提升，轰炸反制。",
    },
}

# 新文案禁式（甲/乙类代表词＋标点＋「改装」不新增于 description 域）
BANNED_NEW = re.compile(
    "进化|合成|法则|蓝图|副本|拆解|星级|升星|科研点|研究点|能量卡|爬塔"
    "|玩家|用户|指挥官|氪金|充值|付费|月卡|通行证|战令|签到|福利|奖励|领取"
    "|活动|新手|老玩家|删档|开服|服务器|联网|掉线|版本更新|维护公告"
    "|抽卡|卡池|十连|保底|体力|疲劳值|限时|特价|折扣|促销|NPC|道具"
    "|金币|钻石|点券|改装|！|～"
)

ENTRY_KEY = re.compile(r'(?m)^\t*"([a-z0-9_]+)"\s*=\s*\{')
DESC = re.compile(r'description\s*=\s*"([^"]*)"')


def numeric_multiset(s: str) -> Counter:
    toks = re.findall(r"[+\-]?[×]?\d+(?:\.\d+)?%?", s)
    return Counter(t.lstrip("+-×") for t in toks)


def main(write: bool) -> int:
    total_changes = total_keeps = 0
    for stem, expect in EXPECTED.items():
        path = DIR / f"{stem}_mods.gd"
        text = path.read_text(encoding="utf-8")
        keys = [m.group(1) for m in ENTRY_KEY.finditer(text)]
        if len(keys) != expect:
            print(f"[FATAL] {path.name}: 条目数 {len(keys)} != 期望 {expect}")
            return 1
        rw = REWRITES[stem]
        kp = KEEPS[stem]
        unknown = [k for k in keys if k not in rw and k not in kp]
        missing = [k for k in list(rw) + list(kp) if k not in keys]
        if unknown or missing or set(rw) & set(kp):
            print(f"[FATAL] {path.name}: unknown={unknown} missing={missing}")
            return 1

        spans = [(m.start(), m.group(1)) for m in ENTRY_KEY.finditer(text)]
        out, changed = [], 0
        out.append(text[:spans[0][0]])
        print(f"== {path.name}（{expect} 条，改 {len(rw)} 保 {len(kp)}）==")
        for i, (pos, key) in enumerate(spans):
            end = spans[i + 1][0] if i + 1 < len(spans) else len(text)
            block = text[pos:end]
            if key in kp:
                out.append(block)
                continue
            found = DESC.findall(block)
            if len(found) != 1:
                print(f"[FATAL] {key}: description 命中 {len(found)} 次（应为 1）")
                return 1
            old = found[0]
            new = rw[key]
            if BANNED_NEW.search(new):
                print(f"[FATAL] {key}: 新文案含禁式 → {BANNED_NEW.search(new).group(0)}")
                return 1
            if numeric_multiset(old) != numeric_multiset(new):
                print(f"[FATAL] {key}: 数值多重集不一致\n  旧: {old}\n  新: {new}")
                print(f"  旧 tokens: {sorted(numeric_multiset(old).elements())}"
                      f"\n  新 tokens: {sorted(numeric_multiset(new).elements())}")
                return 1
            if old == new:
                print(f"[WARN] {key}: 新旧相同（应归入 KEEPS 或改写）")
            block = block.replace(f'description = "{old}"', f'description = "{new}"', 1)
            out.append(block)
            changed += 1
            print(f"  [{key}]\n    旧: {old}\n    新: {new}")
        new_text = "".join(out)
        # 骨架零动断言：屏蔽 description 串内容后与原文一致
        mask = lambda t: re.sub(r'(description\s*=\s*)"[^"]*"', r'\1""', t)
        if mask(new_text) != mask(text):
            print(f"[FATAL] {path.name}: 屏蔽 description 后骨架不一致（不应发生）")
            return 1
        if write and changed:
            path.write_text(new_text, encoding="utf-8", newline="")
        total_changes += changed
        total_keeps += len(kp)
    print(f"\n[DONE] {'已落盘' if write else 'DRY-RUN（未写盘）'}"
          f"：变更 {total_changes} 条 / 保留 {total_keeps} 条 / 合计 {total_changes + total_keeps}")
    return 0


if __name__ == "__main__":
    sys.exit(main(write="--write" in sys.argv))
