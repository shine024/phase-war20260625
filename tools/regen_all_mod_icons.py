#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
全部 85 张改造模块图标一次性重生成（v10.4 终结方案）。
背景：三轮打地鼠（白底批/实心底批/雾状底批）证明历史批次来源混杂，
阈值修补永远追不全。全部走统一管线：纯白底生成 → 白转透明 → 84% 留白 512。
用法：python tools/regen_all_mod_icons.py            # 全量
      python tools/regen_all_mod_icons.py mod_shield  # 单张重试
"""
import json
import os
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
API_KEY = open(os.path.join(ROOT, "tools", "_api_key.txt"), encoding="utf-8").read().strip()
BASE_URL = "https://apihub.agnes-ai.com/v1"
MODEL = "agnes-image-2.1-flash"
D = os.path.join(ROOT, "assets", "ui", "icons", "mod_icons")
RAW = os.path.join(D, "_allregen_raw")
os.makedirs(RAW, exist_ok=True)

P = "单个军事科技部件图标，扁平矢量插画，粗轮廓剪影，深色调主体配霓虹青蓝高光与少量橙色点缀，居中占画面60%，纯白背景，无文字无水印，"
N = "不要文字，不要边框，不要多对象，不要透视，不要照片写实，不要背景色块，背景必须是纯白色。"

SUBJECT = {
    "mod_acid": "酸液腐蚀弹药剂罐与滴液", "mod_active": "主动防御拦截弹发射器", "mod_aerodynamics": "流线型气动套件与导流翼",
    "mod_ammo_apfsds": "尾翼稳定脱壳穿甲弹与弹托", "mod_ammo_chem": "化学能战斗部弹头", "mod_ammo_cluster": "子母弹开放舱与子弹药",
    "mod_ammo_extended": "加长身管炮管", "mod_ammo_graphite": "石墨粉尘弹头", "mod_ammo_incendiary": "燃烧弹弹头与火焰",
    "mod_ammo_phosphorus": "白磷弹丸与烟雾", "mod_ammo_thermobaric": "温压弹战斗部", "mod_ammunition": "弹药箱与码放的炮弹",
    "mod_antiradiation": "防辐射衬层板材", "mod_armor": "多层复合装甲板块", "mod_armor_special": "特种装甲模块与支架",
    "mod_autoloader": "自动装弹机输弹机构", "mod_automation": "工业自动化机械臂", "mod_barrel": "重机枪枪管与散热套",
    "mod_beam_splitter": "光束分束器与棱镜组", "mod_bridge": "架桥坦克桥臂", "mod_chem_sprayer": "化学喷射器与药罐",
    "mod_combustion_catalyst": "燃烧催化剂注入阀", "mod_command": "指挥通讯天线与终端", "mod_comms": "通讯电台与天线",
    "mod_countermeasure": "干扰弹发射阵列", "mod_deception": "伪装网与假目标骨架", "mod_demolition": "爆破装药与雷管",
    "mod_designator": "激光目标指示器三脚架", "mod_digging": "军用推土铲与臂架", "mod_drone": "四旋翼侦察无人机",
    "mod_ecm": "电子对抗吊舱与散热格栅", "mod_electronics": "电子机柜与电路板", "mod_emp_warhead": "电磁脉冲弹头与线圈",
    "mod_engine": "燃气轮机与排气管", "mod_engineering": "工程工具组与线缆盘", "mod_enhancement": "性能强化芯片组",
    "mod_environment": "环境过滤罐与散热鳍", "mod_ergonomics": "人机工程操控面板", "mod_exoskeleton": "动力外骨骼肢体",
    "mod_fire_control": "火控计算机与瞄准环", "mod_fortification": "装配式掩体板与沙袋", "mod_fuze": "可编程电子引信",
    "mod_guidance": "制导导引头陀螺仪", "mod_gun": "速射炮与弹链", "mod_helmet": "综合头盔与目镜",
    "mod_laser": "激光发射器与透镜阵列", "mod_logistics": "后勤补给集装箱", "mod_medical": "医疗箱与十字标志",
    "mod_minefield": "地雷布设器与雷体", "mod_missile": "导弹弹体与尾翼", "mod_mobility": "强化履带与负重轮",
    "mod_mount": "武器挂架与枢轴", "mod_nano_amp": "纳米放大器谐振腔", "mod_nano_catalyst": "纳米催化剂反应瓶",
    "mod_nano_seeder": "纳米播种器喷口阵列", "mod_navigation": "导航罗盘与卫星信号", "mod_network": "网络节点与数据流",
    "mod_obstacle": "反坦克拒桩与铁丝网", "mod_optical_fiber": "光纤线缆盘与接口", "mod_optics": "光学瞄准镜物镜组",
    "mod_overdrive": "过载增压阀与电弧", "mod_overload": "超载变压器线圈", "mod_pollution": "污染滤芯与警示条纹",
    "mod_power": "动力电池组与电缆", "mod_protection": "球形防护力场发生器", "mod_radar": "相控阵雷达天线阵面",
    "mod_recon": "侦察潜望镜与镜头", "mod_recovery": "回收机械爪与绞盘", "mod_reflector": "反射镜面阵列",
    "mod_repair": "维修扳手与焊枪", "mod_resonance": "共振发生器与波形环", "mod_shield": "六边形能量护盾与光弧",
    "mod_shield_reactive": "爆炸反应装甲块", "mod_special": "特种作战模块箱", "mod_stealth": "隐形吸波涂层板",
    "mod_survival": "生存应急包与净水器", "mod_system": "系统核心主板", "mod_targeting_drone": "瞄准无人机与光点",
    "mod_targeting_laser": "瞄准激光器与十字光轴", "mod_thermolite": "热成像仪与热流", "mod_thrust": "推进器喷口与焰流",
    "mod_weakpoint": "弱点标记瞄准框", "mod_weapon": "突击步枪侧视", "mod_weapon_air": "航空机炮吊舱",
    "mod_weapons": "并列武器组与枪架",
}


def generate(prompt, output_path):
    payload = json.dumps({"model": MODEL, "prompt": prompt, "size": "1024x1024", "n": 1})
    tmp = output_path + ".payload.json"
    open(tmp, "w", encoding="utf-8").write(payload)
    cmd = ["curl", "--http1.1", "-s", "-X", "POST", BASE_URL + "/images/generations",
           "-H", "Authorization: Bearer " + API_KEY, "-H", "Content-Type: application/json",
           "--data-binary", "@" + tmp, "-o", output_path + ".resp.json", "--max-time", "180"]
    r = subprocess.run(cmd, capture_output=True, text=True, timeout=200)
    try:
        os.unlink(tmp)
    except OSError:
        pass
    if r.returncode != 0:
        return False, "curl exit " + str(r.returncode)
    try:
        content = open(output_path + ".resp.json", encoding="utf-8").read()
    except OSError:
        return False, "no resp"
    finally:
        try:
            os.unlink(output_path + ".resp.json")
        except OSError:
            pass
    try:
        data = json.loads(content)
    except Exception:
        return False, "bad json: " + content[:120]
    url = (data.get("data") or [{}])[0].get("url", "")
    if not url:
        return False, "no url"
    subprocess.run(["curl", "--http1.1", "-s", "-L", "-o", output_path, url, "--max-time", "180"],
                   capture_output=True, timeout=200)
    return os.path.exists(output_path) and os.path.getsize(output_path) > 1000, "ok"


def deploy(raw_path, out_path):
    from PIL import Image
    import numpy as np
    arr = np.array(Image.open(raw_path).convert("RGB"), dtype=np.int16)
    brightness = arr.sum(axis=2) / 3.0
    alpha = np.clip((240 - brightness) * 6.375, 0, 255).astype(np.uint8)
    img = Image.fromarray(np.dstack([arr[:, :, 0].astype(np.uint8), arr[:, :, 1].astype(np.uint8),
                                     arr[:, :, 2].astype(np.uint8), alpha]), "RGBA")
    bbox = img.getbbox()
    if bbox:
        img = img.crop(bbox)
    w, h = img.size
    scale = min(512 / w, 512 / h) * 0.84
    nw, nh = max(1, int(w * scale)), max(1, int(h * scale))
    img = img.resize((nw, nh), Image.Resampling.LANCZOS)
    canvas = Image.new("RGBA", (512, 512), (0, 0, 0, 0))
    canvas.paste(img, ((512 - nw) // 2, (512 - nh) // 2), img)
    canvas.save(out_path)


def main():
    only = sys.argv[1] if len(sys.argv) > 1 else None
    ok = fail = 0
    failed = []
    for f, subj in sorted(SUBJECT.items()):
        if only and f != only:
            continue
        raw = os.path.join(RAW, f + ".png")
        out = os.path.join(D, f + ".png")
        if not (os.path.exists(raw) and os.path.getsize(raw) > 1000):
            good, msg = generate(P + subj + N, raw)
            if not good:
                print("gen FAIL:", f, msg)
                fail += 1
                failed.append(f)
                continue
        try:
            deploy(raw, out)
            print("deploy:", f)
            ok += 1
        except Exception as e:
            print("deploy FAIL:", f, e)
            fail += 1
            failed.append(f)
    print(f"\nDone: {ok} ok, {fail} fail")
    if failed:
        print("FAILED:", " ".join(failed))


if __name__ == "__main__":
    main()
