# -*- coding: utf-8 -*-
"""
按场景要素批量生成关卡背景(text2img,纯正向自然景观)
=====================================================
用户要求:图片中不要有棋盘、不要有人/兵/武器/军事道具。

核心教训(来自 背景图_工作流说明.md v07→v12 踩坑):
  扩散模型对负向词("NO crates")和机制词都不可靠,反而会把被列举的物件"召唤"进画面。
  → 正向描述目标形态("open natural ground with sparse grass")才稳。

本脚本据此设计:
  1. 完全不读 提示词.txt 的 ```text 块(那是 3x3 自走棋版,满是 autochess board +
     军事道具 + 负向列举,直接用必然画出棋盘/武器)
  2. 只从每关的"场景说明"行提取要素(天气/地形/时间/能量场/势力)
  3. 用纯正向自然景观模板组装 prompt(开阔地面+稀草+碎石+远处小树)
  4. 不传中文 narrative(阵地/攻防战/轰炸/血战等军事中文词会触发模型)
  5. 结尾只保留最小 no-x(No text, no UI, no watermark)
  6. size 用 1K(游戏 1280x720 足够,文件小)

用法:
  python 生成关卡背景_提示词.py             # 默认跑 提示词.txt 里全部关(5-20)
  python 生成关卡背景_提示词.py 5           # 单关
  python 生成关卡背景_提示词.py 6 7 8       # 指定关号

输入: ./提示词.txt(只读关卡要素,不读 text 块)
输出: ./N.png(如 5.png ~ 20.png)
"""
import json, urllib.request, urllib.error, ssl, os, re, sys, time

# SSL 绕过(apihub 证书过期,沿用既有脚本做法)
ctx = ssl.create_default_context()
ctx.check_hostname = False
ctx.verify_mode = ssl.CERT_NONE

# 密钥(主;见 docs/生图API.txt,与既有反推改图脚本同源)
KEY = "sk-2mxCpSC8Nf0nm2TAf9fYHuRxNj7aeoIttPuuu9ivodbU3zXN"
IMG = "https://apihub.agnes-ai.com/v1/images/generations"

HERE = os.path.dirname(os.path.abspath(__file__))
PROMPT_FILE = os.path.join(HERE, "提示词.txt")

# === 场景要素 → 正向描述片段库(完全去战场化,宁静自然风光) ===
# 教训: 一战战场氛围词(rainy/stormy/foggy/battlefield/plains+mud)会让扩散模型
#       训练分布偏置画出围栏/箱/栅栏/网格地面。必须用柔和自然词替代,且强锚定
#       "宁静/田园/无人迹荒野"才能稳定避开战场元素。

# 天气+时间 → 天空描述(全部柔和化,去战场感)
SKY = {
    ("雨天", "白昼"): "a soft overcast daytime sky in gentle cool gray-blue tones, with light cloud layers and a calm serene mood",
    ("风暴", "黄昏"): "a warm gentle golden-hour sky with soft amber light, long calm shadows, and quiet layered clouds at sunset",
    ("浓雾", "夜晚"): "a tranquil misty night sky with soft cool moonlight glowing gently through thin veil of mist, peaceful and quiet",
    ("晴朗", "黎明"): "a serene clear dawn sky with a gentle warm-cool gradient, soft first morning light, and delicate quiet clouds",
}

# 能量场 → 地平线点缀(极克制科幻氛围,不画线/不画结构)
ENERGY = {
    "强能量场": "A faint soft cyan tint in the distant air adds a quiet subtle ethereal atmosphere.",
    "虚空裂隙": "A subtle soft purple-violet wash in the upper sky adds a quiet dreamlike atmosphere.",
    "纳米雾场": "A soft silvery shimmer floating gently above the distant land adds a quiet ethereal mist.",
    "常规能量场": "The distant air has a calm natural soft atmospheric depth.",
}

# 地形 → 远景轮廓(去"城市工业烟囱"等战场触发词,城市改宁静远方屋顶)
TERRAIN_DISTANT = {
    "平原": "Gentle open meadows stretch peacefully to the far horizon, with soft low rolling hills fading into the distance.",
    "山地": "Layered soft mountain ranges fade gently into calm atmospheric distance, peaks silhouetted quietly.",
    "城市": "A faraway quiet old town of soft gentle rooftops fades into the distant haze, peaceful and still.",
    "森林": "A soft dense woodland of gentle treetops forms a quiet dark green band along the far horizon.",
    "沙漠": "Soft gentle dune curves roll peacefully toward the far horizon, calm and quiet.",
}

# 地形 → 地面材质(去 muddy/wet/weathered 等战场泥泞词,改自然泥土)
TERRAIN_GROUND = {
    "平原": "flat natural earth meadow ground with soft gentle grass-covered soil",
    "山地": "flat natural rocky earth ground at a gentle mountain base, with soft mossy patches",
    "城市": "flat quiet earthen ground with soft overgrown grass reclaiming old stone paving",
    "森林": "flat soft forest floor covered in gentle fallen leaves and quiet undergrowth",
    "沙漠": "flat smooth sandy desert ground with gentle soft wind-rippled texture",
}

# 地形 → 地面自然装饰(纯自然,无人造物)
TERRAIN_DETAIL = {
    "平原": "soft tufts of green meadow grass, small wildflowers, and a few smooth natural stones scattered gently",
    "山地": "patches of soft mountain grass, gentle mossy rocks, and a few small wild mountain flowers",
    "城市": "soft green weeds and wild grass growing gently over old stone, with tiny wildflowers reclaiming the quiet ground",
    "森林": "soft fallen leaves, patches of green moss, small mushrooms, and gentle ferns growing quietly",
    "沙漠": "soft ripples in the sand, a few small smooth desert pebbles, and a single tiny dry desert bush",
}


def parse_scenes(text):
    """从 提示词.txt 解析每关 {关号: (weather, terrain, time, energy, faction, narrative)}。

    每关格式:
      ## 第 N 关
      **关卡介绍：** <narrative>
      **场景说明：** <weather>、<terrain>、<time>、<energy>；<faction>
    只读这两行元数据,不读 ```text 块(text 块是 3x3 自走棋版,军事/棋盘词密集,弃用)。
    """
    scenes = {}
    for m in re.finditer(r"## 第 (\d+) 关(.*?)(?=## 第 \d+ 关|\Z)", text, re.S):
        lv = int(m.group(1))
        body = m.group(2)
        narrative_m = re.search(r"\*\*关卡介绍[：:]\*\*\s*(.+)", body)
        scene_m = re.search(r"\*\*场景说明[：:]\*\*\s*(.+)", body)
        if not scene_m:
            print("L%02d 跳过:未找到场景说明" % lv)
            continue
        narrative = narrative_m.group(1).strip() if narrative_m else ""
        scene_raw = scene_m.group(1).strip()
        # 解析 "天气、地形、时间、能量场；势力（xxx）"
        parts = re.split(r"[；;]", scene_raw)
        left = parts[0]  # 天气、地形、时间、能量场
        faction = parts[1].strip() if len(parts) > 1 else ""
        fields = [f.strip() for f in re.split(r"[、,，]", left)]
        if len(fields) < 4:
            print("L%02d 跳过:场景说明字段不足 %r" % (lv, scene_raw))
            continue
        weather, terrain, tod, energy = fields[0], fields[1], fields[2], fields[3]
        scenes[lv] = (weather, terrain, tod, energy, faction, narrative)
    return scenes


def build_prompt(scene):
    """纯正向自然景观 prompt(无军事/棋盘词,最小 no-x)。scene = (weather,terrain,tod,energy,faction,narrative)。"""
    weather, terrain, tod, energy, faction, _narrative = scene
    sky = SKY.get((weather, tod))
    if sky is None:
        # 兜底:未知天气/时间组合,用通用天空
        sky = "a soft natural sky with gentle cloud layers"
        print("  WARN: 未知天气/时间组合 (%s/%s),用通用天空" % (weather, tod))
    energy_s = ENERGY.get(energy, ENERGY["常规能量场"])
    distant = TERRAIN_DISTANT.get(terrain, TERRAIN_DISTANT["平原"])
    ground_mat = TERRAIN_GROUND.get(terrain, TERRAIN_GROUND["平原"])
    detail = TERRAIN_DETAIL.get(terrain, TERRAIN_DETAIL["平原"])

    # 纯正向 + 强锚定宁静田园。绝不出现任何战场/军事/棋盘词,也不传中文 narrative。
    # 核心:用 peaceful/pastoral/serene/untouched 等强词把模型锁定在自然风光分布,
    #       避开 WWI/battlefield 训练偏置画出围栏/箱/栅栏。
    return (
        "16:9 horizontal 2D side-scrolling mobile game landscape background, "
        "bright clean polished peaceful hand-painted nature art style, high detail, "
        "serene pastoral scenery, a calm untouched natural wilderness.\n\n"
        "A wide peaceful pastoral landscape, viewed from a low gentle side-view perspective. "
        "The mood is serene, tranquil and quiet — an empty uninhabited natural wilderness. "
        "The upper third of the frame is " + sky + ". "
        + distant + " "
        + energy_s + " "
        "The sky is a soft atmospheric backdrop only.\n\n"
        "Below the distant horizon, the entire lower two-thirds of the frame is one continuous "
        "open peaceful meadow expanse spanning the full frame width — a "
        + ground_mat + ". "
        "The ground is a single soft uninterrupted natural surface covered gently with "
        + detail + ". "
        "The same soft natural meadow extends continuously all the way to the far distance, "
        "near and far blending as one calm continuous field. "
        "A few soft small bushes sit quietly far away in the same color family as the ground. "
        "The lower ground area is gently larger than the upper sky area.\n\n"
        "This is a calm peaceful empty nature painting — a quiet serene open meadow, "
        "soft gentle ambient daylight, no harsh shadows, no artificial light. "
        "Low gentle side-view perspective, level smooth ground. "
        "Smooth soft brushwork, no hard edges, no lines or borders anywhere.\n\n"
        "Style: clean painted 2D side-scroller background, readable calm pastoral composition, "
        "pure scenery artwork only."
    )


def post(url, body, timeout=300):
    """带 3 次重试的 POST(SSL 绕过,沿用既有脚本)。"""
    last_err = None
    for a in range(1, 4):
        try:
            req = urllib.request.Request(
                url,
                data=json.dumps(body).encode(),
                headers={"Authorization": "Bearer " + KEY, "Content-Type": "application/json"},
            )
            r = urllib.request.urlopen(req, timeout=timeout, context=ctx)
            return json.loads(r.read().decode())
        except urllib.error.HTTPError as e:
            err = e.read().decode()
            print("  HTTP %d %s" % (e.code, err[:200]))
            last_err = "HTTP %d" % e.code
            if e.code in (400, 401, 403, 404):
                raise
            if a < 3:
                time.sleep(3)
                continue
            raise
        except Exception as e:
            print("  net err %r" % e)
            last_err = repr(e)
            if a < 3:
                time.sleep(3)
                continue
            raise
    raise RuntimeError("post failed after retries: %s" % last_err)


def gen(level, prompt):
    """text2img → 存 N.png。返回输出路径。"""
    body = {
        "model": "agnes-image-2.1-flash",
        "prompt": prompt,
        "size": "1K",  # 游戏分辨率 1280x720,1K 档(16:9 ≈1024x576)足够且文件小
        "ratio": "16:9",
        "extra_body": {"response_format": "url"},
    }
    d = post(IMG, body, timeout=300)
    img_url = d["data"][0]["url"]
    out = os.path.join(HERE, "%d.png" % level)
    urllib.request.urlretrieve(img_url, out)
    return out


def main():
    if not os.path.exists(PROMPT_FILE):
        print("找不到 %s" % PROMPT_FILE)
        sys.exit(1)
    text = open(PROMPT_FILE, encoding="utf-8").read()
    scenes = parse_scenes(text)
    if not scenes:
        print("提示词.txt 未解析出任何关卡")
        sys.exit(1)

    want = [int(x) for x in sys.argv[1:]] if len(sys.argv) > 1 else sorted(scenes)
    todo = [lv for lv in want if lv in scenes]
    missing = [lv for lv in want if lv not in scenes]
    if missing:
        print("提示词.txt 无这些关,跳过: %s" % missing)

    print("待生成 %d 关: %s" % (len(todo), todo))
    print("=" * 60)

    ok, failed = [], []
    for lv in todo:
        out = os.path.join(HERE, "%d.png" % lv)
        if os.path.exists(out):
            print("L%02d 已存在,跳过(删 %s 可重跑)" % (lv, os.path.basename(out)))
            ok.append(lv)
            continue
        sc = scenes[lv]
        prompt = build_prompt(sc)
        print("L%02d 生成中... [%s/%s/%s/%s] prompt 长度 %d"
              % (lv, sc[0], sc[1], sc[2], sc[3], len(prompt)))
        try:
            path = gen(lv, prompt)
            print("L%02d OK -> %s" % (lv, os.path.basename(path)))
            ok.append(lv)
        except Exception as e:
            print("L%02d FAIL %r" % (lv, e))
            failed.append(lv)
        time.sleep(2)

    print("=" * 60)
    print("成功 %d: %s" % (len(ok), ok))
    if failed:
        print("失败 %d: %s" % (len(failed), failed))
        print("重跑: python \"%s\" %s" % (sys.argv[0], " ".join(str(x) for x in failed)))
    else:
        print("全部完成,无失败")
    print("DONE")


if __name__ == "__main__":
    main()
