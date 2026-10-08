# -*- coding: utf-8 -*-
"""批A 视频任务驱动：poll 失败(过期404等)→重建任务→poll→build。

用法: python tools/_batchA_video_driver.py <unit>   (anim 恒 attack)
"""
import io
import sys

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")
sys.path.insert(0, "tools")
import generate_unit_animations as g  # noqa: E402

unit = sys.argv[1]
try:
    g.step_poll(unit, "attack")
except Exception as e:
    print("[poll fail → recreate]", str(e)[:160], flush=True)
    g.step_create(unit, "attack")
    g.step_poll(unit, "attack")
g.step_build(unit, "attack")
print("[done] %s/attack f帧=%d" % (unit, len(g.glob(g.os.path.join(
    g.anim_dir(unit, "attack"), "f*.png")))), flush=True)
