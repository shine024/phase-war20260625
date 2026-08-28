# -*- coding: utf-8 -*-
"""对 _flagged.txt 里全部图跑视觉分诊（复用 vision_triage 逻辑），输出 PASS/FAIL 汇总。"""
import subprocess, sys, os
sys.stdout.reconfigure(encoding="utf-8", errors="replace")

flagged = [l.strip() for l in open("tools/bg_rework/_flagged.txt", encoding="utf-8") if l.strip()]
checked = {"bg_level_31.png", "bg_level_32.png", "bg_level_63.png", "bg_level_98.png",
           "bg_level_24.png", "bg_level_67.png"}  # 已人工核过（含重跑后）
todo = [f for f in flagged if f not in checked]
print("to triage: %d" % len(todo), flush=True)

BATCH = 6
all_out = []
for i in range(0, len(todo), BATCH):
    chunk = todo[i:i + BATCH]
    print("---- batch %d: %s" % (i // BATCH + 1, ", ".join(chunk)), flush=True)
    r = subprocess.run([sys.executable, "tools/bg_rework/vision_triage.py"] + chunk,
                       capture_output=True, text=True, encoding="utf-8", errors="replace")
    out = r.stdout or ""
    all_out.append(out)
    print(out.encode("gbk", "replace").decode("gbk"), flush=True)
    if r.returncode != 0:
        print("STDERR:", (r.stderr or "")[-500:].encode("gbk", "replace").decode("gbk"), flush=True)

# 汇总（从各批 stdout 累积；跳过已核过且通过的图）
import re
fails = re.findall(r"=== (\S+\.png) ===\s*\n(?:VERDICT \| )?(FAIL[^\n]*)", "\n".join(all_out))
print("\n==== FAIL SUMMARY ====")
for name, detail in fails:
    print("%s  %s" % (name, detail[:120]))
if not fails:
    print("(none)")
