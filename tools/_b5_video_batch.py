# -*- coding: utf-8 -*-
"""B5 攻击动画重出·视频关键帧路线（2026-10-04 用户令：§十生图攻击候选全废）。

复用 tools/generate_unit_animations.py 已验证管线（运行时 UNITS.update 注入 11 案，零改宿主文件）：
卡图白底化 512² ref（按目验朝向翻转朝左）→ imgbb 传图 → agnes-video-2.5-flash keyframe 模式
(16:9 720P, seconds=5) → mp4 → ffmpeg 8fps 抽帧 → v6c 白底转透明 → 12 帧 512 画布 sheet。

身份事实以 2026-10-04 逐张卡图目验为准（勿信旧 subject 文本）：
  045=沙袋工事MG42无人、039=单跪姿炮手、轰炸机=双发中型机头朝右、
  M1A2/77mm/105mm/皮卡(058) 炮口朝右→ref 预翻转朝左（MG 族翻转朝左契约）。

产物落管线工作区 资料/单位分帧动画/999_<key>_<name>/attack/，再导出 staging 命名
<key>_VID_attack_*（sheet_512 / GIF / cells_dark 网格）。绝不写 assets/（§十铁律）。

用法:
  python tools/_b5_video_batch.py create   # 建视频任务（限流 6/min，间隔 11s）
  python tools/_b5_video_batch.py poll     # 轮询+下载 mp4
  python tools/_b5_video_batch.py build    # 抽帧+后处理+导出 staging
  python tools/_b5_video_batch.py all      # 三步连跑
"""
import importlib.util
import io
import os
import shutil
import sys
import time

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))  # 让宿主能 import _netfix
OUT = os.path.join(ROOT, ".godot", "unit_review", "img25_staging")
CI = os.path.join(ROOT, "assets", "card_icons")

spec = importlib.util.spec_from_file_location(
    "ga", os.path.join(ROOT, "tools", "generate_unit_animations.py"))
ga = importlib.util.module_from_spec(spec)
spec.loader.exec_module(ga)

# ---- 网络通道（2026-10-04 实测）：urllib 对 /videos 空响应/断连，改 curl 直连（本机已验证）。
# api.agnes-ai.cn 对现有 key 一律 401 弃用；两个 apihub realm 才是真通道：
#   视频 key(_api_key.txt #1/#3) → apihub.agnes-ai.com；图像 key(_agnes_image_api.md #1/#2) → apihub.agnes-ai.cn
# 503 video_queue_full = 服务商队列满（所有可用组合同时满），只能退避重试。
import re  # noqa: E402
import subprocess  # noqa: E402

ga.BASE_URLS = ["https://apihub.agnes-ai.com/v1", "https://apihub.agnes-ai.cn/v1"]
ga.QUERY_URLS = ["https://apihub.agnes-ai.com/agnesapi", "https://apihub.agnes-ai.cn/agnesapi"]

_IMG_KEYS = re.findall(r"sk-[A-Za-z0-9]{10,}",
                       open(os.path.join(ROOT, "tools", "_agnes_image_api.md"), encoding="utf-8").read())


def merged_keys():
    vk = [l.strip() for l in open(ga.KEY_FILE, encoding="utf-8") if l.strip()]
    return vk + _IMG_KEYS[:2]  # 视频key#2 已证实失效，整表原样+图像key前两枚


ga.api_keys = merged_keys


def curl_http_json(url, payload=None, headers=None, timeout=120, method=None):
    cmd = ["curl", "-sk", "--max-time", str(timeout), "-w", "\n%{http_code}",
           "-H", "User-Agent: Mozilla/5.0"]
    if method:
        cmd += ["-X", method]
    if headers:
        for k, v in headers.items():
            cmd += ["-H", "%s: %s" % (k, v)]
    if payload is not None:
        cmd += ["-H", "Content-Type: application/json",
                "--data-binary", json.dumps(payload, ensure_ascii=False)]
    r = subprocess.run(cmd + [url], capture_output=True)
    txt = r.stdout.decode("utf-8", "replace")
    body, _, code = txt.rpartition("\n")
    status = int(code.strip() or "0")
    if status >= 400:
        raise ga.urllib.error.HTTPError(url, status, body[:200], None,
                                        io.BytesIO(body.encode("utf-8")))
    return status, json.loads(body)  # 非 JSON 2xx → JSONDecodeError → 上层换 key 重试


ga.http_json = curl_http_json

FFMPEG = shutil.which("ffmpeg")
if not FFMPEG:
    raise SystemExit("找不到 ffmpeg（shutil.which）")
ga.FFMPEG = FFMPEG  # 宿主 step_build 用的是它自己模块里的 FFMPEG（chocolatey 路径已失效）

TAIL = ("镜头完全锁定，无运镜，无变焦，单位始终完整在画面内。"
        "主体在画面中的位置与朝向全程固定如静止照片，只有武器部件运动与火光硝烟变化，绝不左右摇摆。"
        "纯白色无缝背景，无地面，无阴影，无文字，无水印。")

JOBS = [
    dict(key="ww2_sup_mg42", card="enemy/vis_enemy_045.png", name="沙袋MG42阵地",
         flip=False,
         prompt=("严格保持首帧图像中这座机枪阵地（沙袋工事上架设的MG42机枪、鼓形弹匣与弹药箱）"
                 "的外观、结构、比例与细节完全一致，不改变设计。"
                 "工事与机枪始终保持首帧的朝向，枪管指向画面左侧，绝不掉头，绝不转向。"
                 "画面中没有任何人员，绝不出现士兵。"
                 "严格2D游戏精灵风格，平面正交正侧视。机枪阵地原地固定，机枪向画面左侧方向连续扫射："
                 "枪口火光在左侧枪口处连续闪烁，弹链持续跳动，弹壳向右后方抛出，枪身高频轻微震颤。"
                 + TAIL)),
    dict(key="ww2_boss_kingtiger", card="enemy/vis_enemy_049.png", name="虎王坦克",
         flip=False,
         prompt=("严格保持首帧图像中这辆重型坦克的外观、比例、涂装与细节完全一致，不改变设计。"
                 "车体与炮塔始终保持首帧的朝向，炮管指向画面左侧，绝不掉头，绝不转向。"
                 "严格2D游戏精灵风格，平面正交正侧视。坦克原地静止，主炮向画面左侧方向开炮一次："
                 "巨大的炮口火光出现在左侧炮口处，炮管后坐退缩再复位，硝烟向左飘散，"
                 "车体随之后坐明显摇摆然后稳定。"
                 + TAIL)),
    dict(key="ww2_air_bomber", card="enemy/ww2_air_bomber.png", name="双发轰炸机",
         flip=True, air=True, matte_edge=True, nw_trim=False,
         prompt=("严格保持首帧图像中这架双发螺旋桨轰炸机的外观、比例、涂装与细节完全一致，不改变设计。"
                 "机身始终保持首帧的朝向，机头与螺旋桨指向画面左侧，绝不掉头，绝不转向，"
                 "始终保持水平平飞，绝不爬升绝不俯冲。"
                 "严格2D游戏精灵风格，平面正交正侧视。轰炸机在画面中固定位置水平平飞，"
                 "机腹弹舱门缓缓开启，一串航空炸弹脱离机腹向下坠落离开画面，随后弹舱门收拢复位，"
                 "两侧螺旋桨保持高速旋转的动态模糊。纯白色无缝背景，无地面，无云，无阴影，无文字，无水印。"
                 "镜头完全锁定，无运镜，无变焦，单位始终完整在画面内。")),
    dict(key="ww1_arty_mortar", card="enemy/vis_enemy_039.png", name="重迫击炮",
         flip=False,
         prompt=("严格保持首帧图像中这门重迫击炮与这名跪姿炮手的外观、服装、装备、姿势与细节完全一致，"
                 "不改变设计。画面中只有这一名炮手，绝不增加人数，绝不出现第二个人。"
                 "迫击炮炮管始终保持首帧的朝向，炮口斜指画面左上方，"
                 "炮手跪在炮身右侧面向画面左侧，绝不掉头，绝不转向，绝不转头。"
                 "严格2D游戏精灵风格，平面正交正侧视。迫击炮原地开炮："
                 "炮身沿支架微微下沉蓄力，炮口喷出橙红色膛口火光，一枚炮弹离开炮口飞向左上方，"
                 "膛口焰散成烟环，炮身回弹复位，炮口余烟向上飘散，"
                 "炮手随开炮轻微缩肩后回位。"
                 + TAIL)),
    dict(key="ww1_a7v", card="player/ww1_a7v.png", name="A7V突击坦克",
         flip=False,
         prompt=("严格保持首帧图像中这辆第一次世界大战德国A7V突击坦克的外观、比例、涂装与细节完全一致，"
                 "不改变设计。车体始终保持首帧的朝向，车头指向画面左侧，绝不掉头，绝不转向。"
                 "严格2D游戏精灵风格，平面正交正侧视。坦克原地静止，"
                 "车体侧面机枪射孔向画面左侧方向连续开火：射孔处火光连续闪烁，"
                 "青烟贴着车体向左散开，车体随射击轻微震颤。"
                 + TAIL)),
    dict(key="ww1_lanchest", card="player/ww1_lanchest.png", name="兰彻斯特装甲车",
         flip=False,
         prompt=("严格保持首帧图像中这辆第一次世界大战英国兰彻斯特装甲车的外观、比例、涂装与细节完全一致，"
                 "不改变设计。车体与炮塔始终保持首帧的朝向，绝不掉头，绝不转向。"
                 "严格2D游戏精灵风格，平面正交正侧视。装甲车原地静止，"
                 "炮塔机枪向画面左侧方向连续射击：枪口火光在左侧枪口处连续闪烁，"
                 "弹壳向右后方抛出，青烟一缕向左飘散，车体轻微抖动。"
                 + TAIL)),
    dict(key="ww1_mark4", card="player/ww1_mark4.png", name="MarkIV菱形坦克",
         flip=False,
         prompt=("严格保持首帧图像中这辆第一次世界大战英国Mark IV菱形坦克的外观、比例、涂装与细节完全一致，"
                 "不改变设计。车体始终保持首帧的朝向，车头指向画面左侧，绝不掉头，绝不转向。"
                 "严格2D游戏精灵风格，平面正交正侧视。坦克原地静止，"
                 "侧面炮座向画面左侧方向开炮：炮口火光出现在左侧炮口处，"
                 "炮身轻微后坐复位，硝烟向左飘散，车体随之后坐轻微摇摆然后稳定。"
                 + TAIL)),
    dict(key="mod_arm_m1a2sep", card="player/vis_player_023.png", name="M1A2SEP坦克",
         flip=True,
         prompt=("严格保持首帧图像中这辆主战坦克的外观、比例、涂装与细节完全一致，不改变设计。"
                 "车体与炮塔始终保持首帧的朝向，炮管指向画面左侧，绝不掉头，绝不转向。"
                 "严格2D游戏精灵风格，平面正交正侧视。坦克原地静止，主炮向画面左侧方向开炮一次："
                 "巨大的炮口火光出现在左侧炮口处，炮管后坐退缩再复位，硝烟向左飘散，"
                 "车体随之后坐轻微摇摆然后稳定。"
                 + TAIL)),
    dict(key="mod_air_technical_e", card="enemy/vis_enemy_058.png", name="武装皮卡",
         flip=True,
         prompt=("严格保持首帧图像中这辆武装皮卡的外观、比例、涂装、车轮数与细节完全一致，不改变设计。"
                 "车体与车载机枪始终保持首帧的朝向，车头指向画面左侧，机枪枪口指向画面左侧，"
                 "绝不掉头，绝不转向，枪口绝不指向镜头前方。"
                 "严格2D游戏精灵风格，平面正交正侧视。皮卡原地静止，"
                 "车载机枪向画面左侧方向连续开火：枪口火光在左侧枪口处连续闪烁，"
                 "弹壳向右后方抛出，车体随射击轻微抖动。"
                 + TAIL)),
    dict(key="ww1_arty_77mm", card="player/vis_player_003.png", name="77mm野战炮",
         flip=True,
         prompt=("严格保持首帧图像中这门野战炮的外观、防盾、炮架、木质辐条车轮与细节完全一致，"
                 "不改变设计。炮管始终保持首帧的朝向，炮口指向画面左侧，绝不掉头，绝不转向。"
                 "画面中没有任何人员，绝不出现士兵。"
                 "严格2D游戏精灵风格，平面正交正侧视。野战炮原地固定开炮一次："
                 "炮身沿炮架向后滑动，炮口爆出巨大的橙白色火光，随后大团硝烟向左飘散，"
                 "炮架回弹复位，炮口余烟缭绕。"
                 + TAIL)),
    dict(key="ww1_105mm", card="player/ww1_105mm.png", name="105mm榴弹炮",
         flip=True,
         prompt=("严格保持首帧图像中这门野战榴弹炮的外观、防盾、炮架、辐条车轮与细节完全一致，"
                 "不改变设计。炮管始终保持首帧的朝向，炮口指向画面左侧，绝不掉头，绝不转向。"
                 "画面中没有任何人员，绝不出现士兵。"
                 "严格2D游戏精灵风格，平面正交正侧视。野战榴弹炮原地固定开炮一次："
                 "炮身沿炮架向后滑动，炮口爆出巨大的橙白色火光，随后大团硝烟向左飘散，"
                 "炮架回弹复位，炮口余烟缭绕。"
                 + TAIL)),
]

CELL = 512  # ref 画布


def build_ref(job):
    """卡图 → alpha bbox 裁剪 →（按需翻转朝左）→ 512² 纯白 JPG（单位居中占约 66%）。"""
    from PIL import Image
    dst = os.path.join(ga.REF_DIR, job["key"] + "_white.jpg")
    card = Image.open(os.path.join(CI, job["card"])).convert("RGBA")
    import numpy as np
    a = np.asarray(card)
    ys, xs = np.where(a[..., 3] > 10)
    body = card.crop((int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1))
    if job.get("flip"):
        body = body.transpose(Image.FLIP_LEFT_RIGHT)
    w, h = body.size
    sc = min((CELL * 66) / 100 / w, (CELL * 66) / 100 / h, 4.0)
    body = body.resize((max(1, int(w * sc)), max(1, int(h * sc))), Image.LANCZOS)
    canvas = Image.new("RGB", (CELL, CELL), (255, 255, 255))
    canvas.paste(body, ((CELL - body.width) // 2, (CELL - body.height) // 2), body)
    canvas.save(dst, quality=92)
    return dst


def inject_units():
    entries = {}
    for job in JOBS:
        entries[job["key"]] = {
            "name": job["name"],
            "ref": job["key"] + "_white.jpg",
            "anims": {"attack": {"seconds": "5", "prompt": job["prompt"]}},
        }
        for opt in ("air", "matte_edge", "nw_trim", "mn_floor", "smoke_trim"):
            if opt in job:
                entries[job["key"]][opt] = job[opt]
    ga.UNITS.update(entries)


def adir_of(key):
    return ga.anim_dir(key, "attack")


def phase_create():
    inject_units()
    pending = [j for j in JOBS if not os.path.exists(ga.task_file(j["key"], "attack"))]
    for attempt in range(10):
        still = []
        for job in pending:
            key = job["key"]
            if os.path.exists(ga.task_file(key, "attack")):
                continue
            ref = build_ref(job)
            print("[%s] ref -> %s (attempt %d)" % (key, os.path.basename(ref), attempt + 1), flush=True)
            try:
                ga.step_create(key, "attack")
            except Exception as e:  # noqa: BLE001 - 队列满/断连 → 稍后整轮重试
                print("[retry later] %s: %r" % (key, e), flush=True)
                still.append(job)
            time.sleep(11)
        pending = [j for j in still if not os.path.exists(ga.task_file(j["key"], "attack"))]
        if not pending:
            print("全部任务建立完成", flush=True)
            return
        if attempt < 9:
            print("-- %d 案未建（队列满/断连），45s 后重试 --" % len(pending), flush=True)
            time.sleep(45)
    print("[FAIL] %d 案建任务失败" % len(pending), flush=True)


def phase_poll():
    inject_units()
    for job in JOBS:
        key = job["key"]
        mp4 = os.path.join(adir_of(key), "source.mp4")
        if os.path.exists(mp4):
            print("[skip poll] %s 已有 mp4" % key, flush=True)
            continue
        if not os.path.exists(ga.task_file(key, "attack")):
            print("[skip poll] %s 无 task（create 未成）" % key, flush=True)
            continue
        try:
            ga.step_poll(key, "attack", max_wait=900)
        except Exception as e:  # noqa: BLE001 - 单案超时/失败不拖垮整批
            print("[FAIL poll] %s: %r" % (key, e), flush=True)


def export_staging(key):
    from PIL import Image
    adir = adir_of(key)
    meta_p = os.path.join(adir, "meta.json")
    with open(meta_p, encoding="utf-8") as f:
        meta = json.load(f)
    # sheet 原样复制
    sheet = Image.open(os.path.join(adir, "sheet_attack.png"))
    sheet.save(os.path.join(OUT, "%s_VID_attack_sheet_512.png" % key))
    # GIF（suggested_fps → 间隔 ms）
    dur = int(round(1000.0 / meta.get("suggested_fps", 10)))
    frames = []
    for fn in meta["frame_files"]:
        im = Image.open(os.path.join(adir, fn)).convert("RGBA")
        frames.append(im.resize((256, 256), Image.LANCZOS))
    frames[0].save(os.path.join(OUT, "%s_VID_attack_anim.gif" % key),
                   save_all=True, append_images=frames[1:], duration=dur, loop=0,
                   disposal=2, transparency=0)
    # 深底 4x3 网格（212px/格）
    cell = 212
    g = Image.new("RGB", (4 * cell, 3 * cell), (40, 44, 52))
    for i, im in enumerate(frames):
        g.paste(im.resize((cell, cell), Image.LANCZOS), (i % 4 * cell, i // 4 * cell), im.resize((cell, cell), Image.LANCZOS))
    g.save(os.path.join(OUT, "%s_VID_attack_cells_dark.png" % key))
    print("[export] %s frames=%d dur=%dms" % (key, len(frames), dur), flush=True)


import json  # noqa: E402


def phase_build():
    inject_units()
    for job in JOBS:
        key = job["key"]
        print("== build %s ==" % key, flush=True)
        try:
            ga.step_build(key, "attack")
        except Exception as e:  # noqa: BLE001 - 单案失败不拖垮整批
            print("[FAIL build] %s: %r" % (key, e), flush=True)
            continue
        try:
            export_staging(key)
        except Exception as e:  # noqa: BLE001
            print("[FAIL export] %s: %r" % (key, e), flush=True)


def main():
    cmd = sys.argv[1] if len(sys.argv) > 1 else ""
    if cmd == "create":
        phase_create()
    elif cmd == "poll":
        phase_poll()
    elif cmd == "build":
        phase_build()
    elif cmd == "all":
        phase_create()
        phase_poll()
        phase_build()
    else:
        print(__doc__)


if __name__ == "__main__":
    main()
