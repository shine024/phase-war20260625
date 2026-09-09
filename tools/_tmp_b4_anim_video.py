# -*- coding: utf-8 -*-
"""批次④批 2 配套：agnes-video 逐帧动画重生成驱动（fut_inf_c96 / ww2_arm_garand_para × idle/attack）。"""
import sys, time, traceback, ssl
ssl._create_default_https_context = ssl._create_unverified_context  # 本机证书链过期，API 调用跳过校验

sys.stdout.reconfigure(encoding="utf-8", errors="replace")
sys.path.insert(0, r"F:\godot fair duet\create\phase-war\tools")

import importlib.util
spec = importlib.util.spec_from_file_location(
    "gua", r"F:\godot fair duet\create\phase-war\tools\generate_unit_animations.py")
gua = importlib.util.module_from_spec(spec)
try:
    spec.loader.exec_module(gua)
except SystemExit:
    pass

UNITS_ANIMS = [("fut_inf_c96", "idle"), ("fut_inf_c96", "attack"),
               ("ww2_arm_garand_para", "idle"), ("ww2_arm_garand_para", "attack")]

for unit, anim in UNITS_ANIMS:
    try:
        print("=== %s/%s create ===" % (unit, anim), flush=True)
        gua.step_create(unit, anim)
        print("=== %s/%s poll ===" % (unit, anim), flush=True)
        gua.step_poll(unit, anim, max_wait=900)
        print("=== %s/%s build ===" % (unit, anim), flush=True)
        gua.step_build(unit, anim)
        print("=== %s/%s DONE ===" % (unit, anim), flush=True)
    except Exception as e:
        print("!!! %s/%s FAILED: %s" % (unit, anim, e), flush=True)
        traceback.print_exc()
print("[VIDEO PIPELINE COMPLETE]")
