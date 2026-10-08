# -*- coding: utf-8 -*-
"""fam44 视觉反推提示词（2026-10-07）：把 R14 原卷喂给对话视觉模型（agnes-2.5-pro，cn 域
/v1/chat/completions，OpenAI 兼容），两轮：
  ① 盲反推——不给提示词，让模型从图反推「生成这张图用了什么提示词」；
  ② 对诊断——亮出我们真实用的提示词 + 身份锚定帧，问三件事：
     模型实际执行的 vs 我们写的偏差在哪 / 正侧视(正交零透视)为什么守不住 / 改进版提示词。
用法: python tools/_fam44_reverse_prompt.py [--sheet <png>] [--anchor <png>] [--model agnes-2.5-pro]
产出: .godot/unit_review/img25_staging/_reverse_prompt.txt
"""
import argparse
import base64
import io
import json
import subprocess
import sys

from PIL import Image

KEYS = [l.strip() for l in open("tools/_api_key.txt", encoding="utf-8") if l.strip()]
API = "https://apihub.agnes-ai.cn/v1/chat/completions"
STG = ".godot/unit_review/img25_staging/"

# 我们真实用的提示词骨架（img25_attack_gen.build_prompt 的 mark4 实例化，逐格脚本=默认机炮六拍）
REAL_PROMPT = """第二张图是成品布局示例：它展示的就是最终要交付的雪碧图版式——同一主体在 2 行 3 列共六个格子里各出现一次，格与格之间是很宽的纯白间隔带。成品必须完全照搬这个版式：六格的位置、间隔带宽度、主体的大小和底缘位置都与示例一致。
第一张图是主体的身份锚定帧。六格画的都是同一个主体：与锚定帧完全同身份、同体型、同比例、同配色、同武器、同朝向（面朝画面正左方），以及与示例一致的纯色背景底色。
任务：保持版式与主体大小不变，把六个格子画成第一次世界大战英国Mark IV菱形坦克（菱形车体环绕履带，侧面艏炮炮管伸出，土黄迷彩涂装）面朝正左方的机炮开火动作序列，每格一个独立完整姿态，绝不把相邻几格画成连在一起的漫画分镜。
格 1：中性待机，与锚定帧完全一致，无任何特效；
格 2：预备，机身微微下沉蓄力，炮口出现很小的橙色火点；
格 3：开火！炮口焰在炮口位置爆发，明亮但不遮掩机身；
格 4：火光衰减，炮口只剩一小簇短火舌；
格 5：后坐，机身微微后缩，炮口挂着少量余烟；
格 6：回到与格 1 完全一致的中性待机，余烟散尽（首尾闭合）。
【硬性·大小】六格主体大小完全相同，如同同一张图复制粘贴 6 次，每格主体完整不出本格；每格内容整体收缩在本格内部，上下左右四边各留出至少本格尺寸 6% 的空白边距，主体与火光都压不到格子边缘。
【硬性·站位】每格主体位于格子内偏右的位置（主体中心约在本格横向右侧 40% 处），格子左侧留出空间给火光。
【硬性·视角＝正左侧视图】六格与第一张图（身份锚定帧）完全相同的相机：同一正左侧视角、同一拍摄距离、同一高度、同一大小——相当于把第一张图的主体原样复制进每个格子，再只改动作部位。镜头架在主体正左方与主体同高、沿横轴水平拍摄：主体头尾长轴与画面横轴完全平行，高度方向与画面纵轴完全平行；画面即主体的左侧面立面（机械制图左视图、正交投影、透视深度为零），炮口指向横轴最左端。
【硬性·分格】六格必须是六个相互独立、完整的姿态，任何炮管、火光、烟都不得伸进隔壁格子。
【硬性·特效】没有弹道、没有弹丸、没有飞行物、没有光束——只有炮口火光和烟；火光和烟只贴在炮口位置且完整位于本格内部，绝不触碰格子边缘，绝不画在机尾或其他部位；除炮口焰与烟外无任何特效。
【硬性·无场景】画面是悬在均匀纯色背景前的主体本体：没有地面、没有地平线、没有影子；炮口焰绝不在下方产生任何反光、光斑或倒影；除主体和它的火光烟外，画面里没有任何别的东西。
不要数字、序号、文字、格子编号、边框线、地面、阴影、水印。"""

TURN1 = (
    "这张图是 AI 图像模型生成的 3×2 武器开火动画雪碧图（六格应为同一辆坦克的连续动作）。"
    "请【反推提示词】：假设你只看到这张成品图，写出最能生成出这张图的完整提示词——"
    "按实际画面内容写，包括：版式描述、主体描述、逐格动作、视角/相机描述、特效描述、禁令清单。"
    "特别注意：你是从画面证据反推，画面里凡出现地面、透视、非正侧视角的地方，都要如实写进你反推的提示词里。"
)

TURN2 = (
    "第二张图（单辆坦克）是我们的身份锚定帧——真正的严格正左侧视、正交零透视、无地面。"
    "第一张图（六格雪碧图）是我们实际提示词的产出。我们的真实提示词如下：\n\n"
    "===== 真实提示词 =====\n" + REAL_PROMPT + "\n===== 提示词结束 =====\n\n"
    "请回答三个问题：\n"
    "问题①：对比你的盲反推和我们的真实提示词——产出图里有哪些内容是我们提示词里【没写】却被模型加进来的"
    "（如地面/接触阴影/轮辐间泥土/透视），有哪些是我们【写了】但模型没执行的？逐条列。\n"
    "问题②：正侧视守不住的机理——我们的【硬性·视角＝正左侧视图】段写了两百多字，"
    "为什么模型还是画出 3/4 视角、透视深度、轮子椭圆？从提示词工程角度指出具体失效原因"
    "（哪些措辞反而诱发透视？哪些词太抽象模型无法执行？锚定帧参考与文字指令冲突时模型听谁的？）。\n"
    "问题③：给出改进后的完整提示词（中文，可以在我们版式上只改需要改的段落），"
    "目标：六格全部严格正侧视、零透视、无地面无影子，同时保住身份一致与开火动作。"
    "改进之处请用【改动】标注并一句话说明理由。"
)


def b64_url(path, max_w=1600):
    im = Image.open(path).convert("RGB")
    if im.width > max_w:
        im = im.resize((max_w, int(im.height * max_w / im.width)), Image.LANCZOS)
    buf = io.BytesIO()
    im.save(buf, "PNG")
    return "data:image/png;base64," + base64.b64encode(buf.getvalue()).decode()


def chat(messages, model):
    payload = json.dumps({"model": model, "messages": messages,
                          "temperature": 0.2, "max_tokens": 4096})
    open(STG + "_reverse_payload.json", "w", encoding="utf-8").write(payload)
    for i in range(3):
        r = subprocess.run(
            ["curl", "--http1.1", "-s", "--ssl-no-revoke", "-X", "POST", API,
             "-H", "Authorization: Bearer " + KEYS[i % len(KEYS)],
             "-H", "Content-Type: application/json",
             "--data-binary", "@" + STG + "_reverse_payload.json", "--max-time", "300"],
            capture_output=True, text=True, timeout=320, encoding="utf-8", errors="replace")
        try:
            d = json.loads(r.stdout)
        except Exception:
            print("  非 JSON:", (r.stdout or r.stderr)[:150], flush=True)
            continue
        if d.get("error"):
            print("  API 报错:", json.dumps(d["error"], ensure_ascii=False)[:200], flush=True)
            continue
        return d["choices"][0]["message"]["content"]
    return None


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--sheet", default=STG + "ww1_mark4_R14_attack_sheet_832.png")
    ap.add_argument("--anchor", default=STG + "ww1_mark4_anchor_raw.png")
    ap.add_argument("--model", default="agnes-2.5-pro")
    args = ap.parse_args()

    img_sheet = b64_url(args.sheet)
    img_anchor = b64_url(args.anchor)

    m1 = [{"role": "system", "content": "你是资深 AI 绘图提示词工程师与视觉诊断专家。用中文回答。"},
          {"role": "user", "content": [
              {"type": "image_url", "image_url": {"url": img_sheet}},
              {"type": "text", "text": TURN1}]}]
    print("== 第①轮：盲反推 ==", flush=True)
    a1 = chat(m1, args.model)
    if not a1:
        sys.exit("第①轮失败")
    print(a1[:2000], flush=True)

    m2 = m1 + [{"role": "assistant", "content": a1},
               {"role": "user", "content": [
                   {"type": "image_url", "image_url": {"url": img_anchor}},
                   {"type": "text", "text": TURN2}]}]
    print("\n== 第②轮：对诊断 ==", flush=True)
    a2 = chat(m2, args.model)
    if not a2:
        sys.exit("第②轮失败")

    out = (f"# 反推提示词报告（{args.model}，2026-10-07）\n\n## ① 盲反推\n\n{a1}\n\n"
           f"## ② 对诊断（真实提示词 vs 反推 + 锚定帧对照）\n\n{a2}\n")
    open(STG + "_reverse_prompt.txt", "w", encoding="utf-8").write(out)
    print(a2, flush=True)
    print("\nOK", STG + "_reverse_prompt.txt", flush=True)


if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8")
    main()
