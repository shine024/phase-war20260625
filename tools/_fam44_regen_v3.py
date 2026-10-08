# -*- coding: utf-8 -*-
"""fam44 两案第三轮重生成（10-06 深夜）。

视觉裁定：
  void_soldier v2 整体朝左+横抱枪 → 换方向锚定措辞（枪托抵左肩/枪口最右/禁横抱）。
  juggernaut  v2 枪口已水平朝右 ✓ 但滑成 3/4 视 → 保留枪姿措辞+加「单侧肩甲」约束。
v2 留档 _raw_v2.png（juggernaut v2 为可用回退）。
用法: python tools/_fam44_regen_v3.py
"""
import os
import shutil
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import fam44_cards_redo as R  # noqa: E402  (其模块头已做 stdout utf-8 wrap，勿再包)

POSE = {
    "fe_void_dimensional_soldier": (
        "端枪行进姿态：双手将能量步枪向右水平端平——枪托抵在左肩窝，整条枪管水平向右伸出，"
        "枪口位于全身最右端且与肩同高；左腿在前右腿在后成行进步态。"
        "绝不横抱枪、绝无枪口朝左、绝不转身朝向画面左侧。"),
    "fe_iron_wall_juggernaut": (
        "抬枪据枪姿态：加特林机枪整体抬至肩侧架起，但枪管保持水平，枪口指向画面正右方"
        "且是全身最右端，枪口绝不朝上；身体保持纯正侧面——观众只能看见靠观众一侧的单块肩甲，"
        "另一侧肩甲完全被躯干遮挡不可见，躯干与头颈无任何向镜头扭转，无透视深度。"),
}


def main():
    for k, pose in POSE.items():
        R.UNITS[k]["pose"] = pose
        raw = os.path.join(R.STAGE, "%s_raw.png" % k)
        keep = os.path.join(R.STAGE, "%s_raw_v2.png" % k)
        if os.path.isfile(raw):
            if os.path.isfile(keep):
                os.remove(keep)
            shutil.move(raw, keep)
            print("留档 %s" % os.path.basename(keep), flush=True)
        R.run_case(k)
    print("done", flush=True)


if __name__ == "__main__":
    main()
