# -*- coding: utf-8 -*-
"""batch_flow_regenerate.py —— 5 张新分格图批量重生成（FLOW 网页 UI）
风格锚点：原始 7 张 FLOW 分格（取最早出的 b1_insomnia）；内容按新文案重写。
输出：assets/intro/comic/_raw/ 下新 flow-gen 图；部署时手动 cp 到最终路径。
用法: python tools/batch_flow_regenerate.py [--skip N]
"""
import argparse, os, subprocess, sys, time
from pathlib import Path

if sys.stdout and hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    sys.stderr.reconfigure(encoding="utf-8", errors="replace")

ROOT = Path(__file__).parent.parent
TOOLS = ROOT / "tools"
RAW   = ROOT / "assets/intro/comic/_raw"
TOOL  = ROOT / "docs" / "基地重设计" / "flow_edit_tool.py"
PYTHON = r"C:\Python314\python.exe"
PROJECT = "5bffb93f-5026-4009-872c-cb70d0304f45"
STYLE_REF = str(ROOT / "assets/intro/comic/b1_insomnia.png")  # 最暗阴郁风格的原 FLOW 图

# id → (输出png名, 文件名, 风格参考, 提示词)
# 每图提示词都含 "Hand-painted storybook illustration, muted palette of charcoal black and dark olive-brown"
# 以复刻 v24.4 FLOW 图的色板。
JOBS = [
    ("b6_black_gates", "b6_black_gates.png", STYLE_REF,
     "Night sky over a dark continent seen from a high hilltop: dozens of colossal black rectangular gates hang in the low storm clouds, each gate a towering monolith slab of pure black with a thin edge of violet glow, narrow beams of violet light pour down from the gates onto distant cities below, one distant city burns with a faint amber glow on the horizon, a tiny column of fleeing silhouettes walks along a road in the lower foreground. Hand-painted storybook illustration, muted palette of charcoal black and dark olive-brown, cinematic wide shot."),
    ("b7_deep_voyage", "b7_deep_voyage.png", STYLE_REF,
     "Interior of a vast modern international assembly hall like a united nations summit at night: hundreds of delegates in dark business suits seated in wide curved tiered rows facing a brightly lit stage, one speaker stands at a podium on the stage gesturing toward a massive wall-sized digital screen behind them showing a glowing holographic globe surrounded by icons of small black rectangular gates, professional conference lighting with cool blue wash over the audience, warm spotlights on the stage. Hand-painted storybook illustration, muted palette of charcoal black and dark olive-brown."),
    ("b8_departure",   "b8_sacrifice.png", STYLE_REF,
     "A colossal perfectly round portal of violet and golden swirling energy hangs low over a dark flat plain at night like a giant luminous ring hovering just above ground, a long convoy of olive military trucks with canvas covers drives straight toward the portal seen from behind so only red taillights are visible in a receding line, the front trucks already half inside the glowing ring, golden sparks and embers rain down from the portal rim, small silhouettes of soldiers stand watching along both sides of the road, cinematic wide shot. Hand-painted storybook illustration, muted palette of charcoal black and dark olive-brown."),
    ("b10_rift_stream","b10_rift_stream.png", STYLE_REF,
     "A long river of a thousand tiny walking silhouettes drifts through a tunnel of fractured space at night, the tunnel is lined with cracked glass-like shards, each shard reflecting a different starfield, ribbons of violet energy tear silently between the travelers, some silhouettes glow faintly golden and hold together while others crumble into drifting motes of light, the river of people stretches into the far distance. Hand-painted storybook illustration, muted palette of charcoal black and dark olive-brown."),
    ("wakeup_snowfield","wakeup_snowfield.png", STYLE_REF,
     "An endless snowfield at first light under a pale grey sky: a long eight-wheeled armored command vehicle sits in deep snow in the middle ground, its body a fully enclosed box-shaped crew module with a row of small dark windows along the side, olive green and dark brown armor plating with faint cyan glow strips, rolled canvas on the roof, one headlight glows warm amber, a trail of fresh footprints leads from the foreground snow to the vehicle side door, on the far horizon one colossal black rectangular monolith slab of pure black towers straight up into the low clouds, its top lost in the sky, faint violet glow along its edges, soft snowfall, long cold blue shadows. Hand-painted storybook illustration, muted palette of charcoal black and dark olive-brown."),
]


def run_one(job_id, out_png, ref, prompt):
    out_dir = RAW
    os.makedirs(out_dir, exist_ok=True)
    print(f"[{job_id}] 开始...", flush=True)
    t0 = time.time()
    # dry-run first to catch auth/network issues early
    dr = subprocess.run(
        [PYTHON, str(TOOL), "--ref", ref, "--prompt", prompt,
         "--prefix", f"flow-{job_id}", "--project", PROJECT,
         "--outdir", str(out_dir), "--count", "1", "--dry-run"],
        capture_output=True, text=True, encoding="utf-8", errors="replace",
        timeout=120, cwd=str(ROOT),
    )
    if "✅" not in dr.stdout:
        print(f"  dry-run FAIL: {dr.stderr[-400:] or dr.stdout[-400:]}", flush=True)
        return False
    print(f"  dry-run OK ({time.time()-t0:.1f}s)", flush=True)
    # real run
    t1 = time.time()
    r = subprocess.run(
        [PYTHON, str(TOOL), "--ref", ref, "--prompt", prompt,
         "--prefix", f"flow-{job_id}", "--project", PROJECT,
         "--outdir", str(out_dir), "--count", "1"],
        capture_output=True, text=True, encoding="utf-8", errors="replace",
        timeout=600, cwd=str(ROOT),
    )
    dur = time.time() - t1
    print(f"  output: {r.stdout[-300:].replace('✅','[OK]').replace('❌','[X]')}", flush=True)
    print(f"  stderr tail: {r.stderr[-200:] or '(empty)'}", flush=True)
    print(f"  [{job_id}] done in {dur:.1f}s", flush=True)
    # find newest flow-gen jpeg in _raw
    new = sorted(out_dir.glob("flow-gen-*.jpeg"), key=lambda p: p.stat().st_mtime, reverse=True)
    if new and len(new) > 0:
        src = new[0]
        dst = out_dir / out_png
        if src != dst:
            src.rename(dst)
        print(f"  saved -> {dst} ({dst.stat().st_size//1024}KB)", flush=True)
        return True
    return False


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--skip", type=int, default=0, help="跳过前 N 个 job")
    args = ap.parse_args()
    ok = 0
    for i, (jid, out, ref, prompt) in enumerate(JOBS):
        if i < args.skip:
            print(f"[{jid}] 跳过（--skip={args.skip}）", flush=True)
            continue
        if run_one(jid, out, ref, prompt):
            ok += 1
        else:
            print(f"[{jid}] FAIL", flush=True)
        # flow 生成一张约 1-3 分钟；间歇 5 秒避免连压
        if i < len(JOBS) - 1:
            time.sleep(5)
    print(f"完成 {ok}/{len(JOBS)} 张", flush=True)
    return 0 if ok == len(JOBS) else 1


if __name__ == "__main__":
    sys.exit(main())
