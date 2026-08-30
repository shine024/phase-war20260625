# -*- coding: utf-8 -*-
"""fix6: 包腔白底泄漏清洗（2026-08-30 全量审查沉淀）。

缺陷: 抠图 v6c 保留"封闭小白袋"防误抠, 但视频里轮间/炮架/骑手胯下等大面积
封闭白底(阴影使其 mn<240 逃过纯白长条种子)被整体当主体保留 → 成片上
车轮之间/枪架之间是一块不透明白。

处理: 对白名单单位的 f*.png, 清除「不透明近白封闭连通块」(面积>=MIN_AREA)。
白名单=逐套目视确认红标块全是背景泄漏的单位(见 docs/UNIT_ANIM_ISSUES.md);
白色本体单位(侦察无人机/再生骨架/P-18)禁止入名单。

用法: python tools/_fix6_pocket_scrub.py [--dry]
跑完自动重拼受影响 sheet。
"""
import glob
import os
import sys

import numpy as np
import cv2
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BASE = os.path.join(ROOT, '资料', '单位分帧动画')

# 目视确认的包腔泄漏单位 -> (处理的动画, 亮度阈)  anims=None=both
#   mn218: 深色车体内的封闭白底(带阴影, 240 纯白阈接不住)
#   mn235: 白边描边残留类(贴剪影的近纯白轮廓圈), 阈值收紧防误伤浅灰装甲
TARGETS = {
    '048_ww2_arty_m81_81mm迫击炮': (None, 218),        # 炮架白三角 ~8000px
    '025_mod_technical_武装皮卡': (None, 218),          # 车斗/车窗间隙 ~4000px
    '042_ww1_inf_cavalry_骑兵斥候': (None, 218),        # 骑手胯下间隙
    '084_ww1_sup_vickers_维克斯 .303 机枪阵地': (None, 218),  # 三脚架间隙
    '027_mod_mlrs_MLRS火箭炮': (None, 218),             # 发射箱架间隙
    '005_ww1_rifle_步兵班步枪': (None, 218),            # 持枪臂与身体间隙
    '068_fut_inf_storm_rider_暴风骑士': (None, 218),    # 摩托车轮辋间隙
    '045_ww2_arm_sherman_M4谢尔曼': (None, 218),        # 负重轮之间
    '024_mod_marine_海军陆战队班': (None, 218),         # 背包带/腿间
    '029_mod_abrams_艾布拉姆斯坦克': (None, 218),       # 车体腹下白带(attack 重建后复洗)
    '020_cold_m113_M113运兵车': (None, 218),            # 负重轮之间
    '092_cold_arty_bmd1_BMD-1 空降战车': (None, 218),   # 负重轮之间
    '054_cold_sup_zsu23_ZSU-23-4自行高炮': (None, 218), # 轮间小块
    '083_ww1_arm_rolls_mk2_劳斯莱斯 Mk.II 装甲车': (None, 218),  # 轮间小块
    '055_mod_inf_technical_武装皮卡': (None, 218),      # 同 025 (小面积)
    '012_ww2_mg42_MG42机枪组': (None, 218),             # 枪架间隙
    # ---- 2026-08-30 下午 用户重生成/重建轮追加 ----
    '013_ww2_pschreck_铁拳反坦克兵': (('attack',), 218),   # 蹲姿臂下间隙
    '064_fut_arm_heavy_mech_重装机甲': (None, 218),     # 机甲胯下大三角 ~5400px
    '067_fut_arm_titan_mk2_泰坦Mk.II': (None, 218),     # 腿间/臂间
    '057_mod_sup_m6_自行高炮M6': (None, 218),           # 炮塔后间隙
    '018_cold_m60_M60机枪班': (('attack',), 218),       # 三脚架间隙
    '101_mod_sup_growler_EA-18G 电子战小组': (None, 235),  # 整圈白描边+起落架白条
    '106_fut_inf_x9_X-9 猎杀者渗透组': (None, 235),     # 整圈白描边(迷彩斗篷高饱和受保护)
    '035_fut_hovertank_悬浮坦克': (None, 228, True),    # fix7 matte_edge 重建后贴边白描边(fringe档)
    # ---- 2026-08-30 傍晚 全面复扫 v3(目标视分诊 88 套命中→38 套真泄漏) ----
    # 轮系/炮架泄漏
    '041_ww1_arty_77mm_77mm野战炮': (None, 218),
    '056_mod_arm_m1a1_M1A1坦克': (None, 218),
    '060_mod_arm_m1a2sep_M1A2 SEP': (None, 218),
    '063_fut_arm_prism_光棱坦克': (None, 218),
    '052_cold_inf_bmp1_BMP-1步战车': (None, 218),
    '093_cold_sup_bmp1_x_BMP-1 步兵战车·改': (None, 218),
    '088_ww2_arty_hummel_黄蜂 Hummel 自行火炮': (None, 218),
    '089_ww2_arty_pak40_PaK 40 反坦克炮组': (None, 218),
    '058_mod_arty_m270_M270火箭炮': (None, 218),
    '099_mod_arm_himars_HIMARS 火箭炮组': (None, 218),
    '026_mod_stryker_斯特瑞克装甲车': (None, 218),
    '001_ww2_tiger_虎式坦克': (None, 218),
    '051_cold_arm_t55_T-55坦克': (None, 218),
    '040_ww1_arm_ft17_FT-17轻型坦克': (None, 218),
    '095_cold_arm_p18_P-18 雷达警戒车': (None, 218),   # 仅天线架间隙, 白色车身未被标记
    # 步兵/枪械间隙小漏
    '007_ww1_mortar_迫击炮组': (None, 218),
    '094_cold_inf_metis_9K111 法特导弹组': (None, 218),
    '047_ww2_inf_panzerschrek_铁拳反坦克组': (None, 218),
    '097_mod_sup_m4_carbine_M4 卡宾特遣班': (None, 218),
    '087_ww2_arm_garand_para_M1 加兰德伞兵班': (None, 218),
    '010_ww2_thompson_汤普森冲锋枪班': (None, 218),
    '091_ww2_inf_kar98k_毛瑟 Kar98k 狙击组': (None, 218),
    '014_ww2_para_伞兵精英': (None, 218),
    '028_mod_delta_三角洲精英': (None, 218),
    '004_ww1_mp18_步兵班MP18': (None, 218),
    '002_ww1_storm_暴风突击队': (('attack',), 218),    # 枪口淡烟
    '033_fut_cyborg_半机械人': (None, 218),
    '061_fut_inf_scout_mech_侦察机甲': (None, 218),
    '031_mod_command_指挥官': (None, 218),
    # 建筑/机械表面白痕
    '075_ww2_fort_flak_88mm防空塔': (None, 218),
    '078_mod_fort_citadel_要塞核心': (None, 218),
    '074_ww2_fort_bunker_混凝土碉堡': (None, 218),
    '073_ww1_fort_artillery_要塞炮台': (None, 218),
    '003_mod_apache_阿帕奇直升机': (None, 218),
    '030_mod_apache_e_阿帕奇精英': (None, 218),
    '034_fut_mech_机甲精英': (None, 218),
    # 银白机身用严阈
    '023_cold_mig_MiG战机': (None, 228),               # 腹下白带(机身银白, 228 防误伤)
    '038_fut_nexus_连接体': (None, 218),               # 深色机体上的白色泪痕(青色能量高饱和受保护)
}

# 明确跳过(白色/发光本体, 清洗会吃掉设计): 070 再生骨架(骨白甲) / 059 侦察无人机(白机身)
#   / 077 雷达站(白天线面) / 081 护盾(能量宝石) / 080 离子炮台+069 重装母舰(发光核心)
#   / 079 近防炮(白色雷达罩)
MN = 218        # 近白亮度阈(泄漏块带阴影, 240 纯白阈接不住)
SAT = 36
MIN_AREA = 250  # 512² 画布上 >=250px 的封闭白块才清


def scrub_frame(path, mn=218, dry=False, fringe=False):
    rgba = np.asarray(Image.open(path).convert('RGBA')).copy()
    op = rgba[:, :, 3] > 128
    rgb = rgba[:, :, :3].astype(np.int16)
    mnc = rgb.min(axis=2)
    sat = rgb.max(axis=2) - rgb.min(axis=2)
    nw = ((mnc >= mn) & (sat <= SAT) & op).astype(np.uint8)
    n, lab, st, _ = cv2.connectedComponentsWithStats(nw)
    kill = np.zeros(op.shape, bool)
    for i in range(1, n):
        if st[i, cv2.CC_STAT_AREA] >= MIN_AREA:
            kill |= (lab == i)
    if fringe:
        # 贴边白描边: 1-2px 细碎组件过不了面积阈, 改按"近白 且 邻接透明区"杀
        tr = (rgba[:, :, 3] <= 64).astype(np.uint8)
        ring = cv2.dilate(tr, np.ones((5, 5), np.uint8)) > 0
        kill |= ring & op & (mnc >= mn) & (sat <= 45)
    if not kill.any():
        return 0
    if not dry:
        rgba[:, :, 3][kill] = 0
        Image.fromarray(rgba, 'RGBA').save(path)
    return int(kill.sum())


def repack(adir):
    fs = [p for p in sorted(glob.glob(os.path.join(adir, 'f*.png'))) if 'bak' not in p]
    if not fs:
        return
    ims = [Image.open(p).convert('RGBA') for p in fs]
    w, h = ims[0].size
    sheet = Image.new('RGBA', (w * len(ims), h), (0, 0, 0, 0))
    for i, im in enumerate(ims):
        sheet.paste(im, (i * w, 0))
    anim = os.path.basename(adir.rstrip('\\/'))
    sheet.save(os.path.join(adir, 'sheet_%s.png' % anim))


def main():
    dry = '--dry' in sys.argv
    total = 0
    for d, spec in TARGETS.items():
        anims, mn = spec[0], spec[1]
        fringe = bool(spec[2]) if len(spec) > 2 else False
        anim_list = anims or ('idle', 'attack')
        dd = os.path.join(BASE, d)
        if not os.path.isdir(dd):
            print('!! 目录不存在:', d)
            continue
        for anim in anim_list:
            adir = os.path.join(dd, anim)
            n_px = n_f = 0
            for p in sorted(glob.glob(os.path.join(adir, 'f*.png'))):
                if 'bak' in p:
                    continue
                k = scrub_frame(p, mn=mn, dry=dry, fringe=fringe)
                if k:
                    n_f += 1
                    n_px += k
            if n_f:
                print('%-46s %s: 清洗 %d 帧 / %d px' % (d, anim, n_f, n_px))
                total += n_px
                if not dry:
                    repack(adir)
    print('DONE  total_px=%d%s' % (total, ' (dry run)' if dry else ''))


# ---- fine 档: 全量小块纯白残渣精洗(2026-08-30 晚, 用户复审"很多小块纯白") ----
SKIP_UNITS = {
    '070_fut_air_regen_frame_再生骨架', '059_mod_inf_scout_drone_侦察无人机',
    '077_cold_fort_radar_雷达站', '081_fut_fort_shield_能量护盾发生器',
    '080_fut_fort_ion_离子炮台', '069_fut_air_heavy_carrier_重装母舰',
    '079_mod_fort_phalanx_近防炮系统',
}
FINE_MN = 235    # 近纯白; 白车身着色面(190-225)安全
FINE_AREA = 45   # 40px 以上的碎渣全收


def fine_pass(dry=False):
    total = 0
    for dd in sorted(glob.glob(os.path.join(BASE, '0*_*'))):
        if not os.path.isdir(dd):
            continue
        rel = os.path.relpath(dd, BASE)
        if rel in SKIP_UNITS:
            continue
        for anim in ('idle', 'attack'):
            adir = os.path.join(dd, anim)
            n_px = n_f = 0
            for p in sorted(glob.glob(os.path.join(adir, 'f*.png'))):
                if 'bak' in p:
                    continue
                rgba = np.asarray(Image.open(p).convert('RGBA')).copy()
                op = rgba[:, :, 3] > 128
                rgb = rgba[:, :, :3].astype(np.int16)
                mnc = rgb.min(axis=2)
                sat = rgb.max(axis=2) - rgb.min(axis=2)
                nw = ((mnc >= FINE_MN) & (sat <= 32) & op).astype(np.uint8)
                n, lab, st, _ = cv2.connectedComponentsWithStats(nw)
                border = set(np.unique(np.concatenate(
                    [lab[0, :], lab[-1, :], lab[:, 0], lab[:, -1]])).tolist())
                kill = np.zeros(op.shape, bool)
                for i in range(1, n):
                    if i in border:
                        continue
                    if st[i, cv2.CC_STAT_AREA] >= FINE_AREA:
                        kill |= (lab == i)
                if kill.any():
                    n_px += int(kill.sum())
                    n_f += 1
                    if not dry:
                        rgba[:, :, 3][kill] = 0
                        Image.fromarray(rgba, 'RGBA').save(p)
            if n_f:
                print('%-46s %s: 精洗 %d 帧 / %d px' % (rel, anim, n_f, n_px))
                total += n_px
                if not dry:
                    repack(adir)
    print('FINE DONE  total_px=%d%s' % (total, ' (dry run)' if dry else ''))


if __name__ == '__main__':
    if '--fine' in sys.argv:
        fine_pass('--dry' in sys.argv)
    else:
        main()
