# -*- coding: utf-8 -*-
"""开火四拍 v2（2026-10-15）：24 缺帧卡补攻击卷。
基线 = _tmp_api_firegrid_20261014.py 单拍线（每拍单图 i2i 参考卡图本体，出完拼 2048²）。
v2 三改动（用户 2026-10-15 拍板）：
  1. 无弹道——11 张 cfg 修订（026/032/059/064/068/070/087/093/095/116/128），
     beam/bolt/missile streaking 全改炮口聚能/出膛瞬间，弹丸交游戏内投射物系统。
  2. margin 约束——prompt 强制主体占格 ~80%，焰烟紧凑贴武器，不触图缘（防空光溢格）。
  3. 6 key 双 host 轮换——apihub 组→apihub.agnes-ai.com，api 组→api.agnes-ai.cn，
     key 与域名绑定（见 docs/生图API.txt），401 自动剔组。
修订 cfg 的卡其旧 poses 一律不复用（旧拍是弹道句产物）。
用法: python tools/_tmp_api_firegrid_v2_20261015.py 073,110,070,059   # 缺省=全 24
"""
import base64
import importlib
import io
import json
import os
import ssl
import sys
import time
import urllib.error
import urllib.request

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from _tmp_api_card_regen_20261014 import UNITS, RAW  # noqa: E402
import _tmp_api_firegrid_20261014 as V1  # noqa: E402

CTX = ssl.create_default_context()
CTX.check_hostname = False
CTX.verify_mode = ssl.CERT_NONE
MODEL = "agnes-image-2.5-flash"

# ── 6 key 双 host（2026-10-15 全量实测，见 docs/生图API.txt）──
HOSTS = {
    "api": "https://api.agnes-ai.cn/v1/images/generations",
    "apihub": "https://apihub.agnes-ai.com/v1/images/generations",
}
KEY_POOL = [
    ("api", "sk-E6ayvrmsxJ49DHqkMfhe7d8T8Ze0aN4Uw1tLW71SzDYW5NiR"),
    ("apihub", "sk-thpXTkWon9RiLMdnsZgqlQUH7XI6SdlhLYsx7eQToj7GtIPv"),
    ("api", "sk-LhCskZbAvDmDLwRJI97ngbxxKD4BFCvwygrKxR7yD0KSW4D3"),
    ("apihub", "sk-2mxCpSC8Nf0nm2TAf9fYHuRxNj7aeoIttPuuu9ivodbU3zXN"),
    ("api", "sk-ltQwjD1SVEHvhGgr7gzqDuIaFcZm5XWyXWDX25tfk1Q75lYQ"),
    ("apihub", "sk-Pzu3QigNdQlVhFC7cVDVsTDwfvt3T6nIDq23HeJgaKMnRo6K"),
]

# ── 去弹道修订（只列改动条目，其余沿用 v1 cfg）──
FIX_CFG = {
    "026": dict(
        poses=[
            "ready: the one prism tower dark and idle, the cyan conduits dim, the hover hull level",
            "firing: the prism tip charging into a blinding cyan glow-core with a compact burst of cyan energy petals blooming right at the crystal tip, the conduits flaring bright, the hull level and unchanged",
            "recoil: the one prism tower cooling with a faint afterglow, conduits dimming, the hull level and unchanged",
            "settling: the tower back to dark idle, conduits dim, hull level",
        ],
        flash="The cyan glow-core and energy-petal burst stay compact and attached at the crystal tip, ONLY in the top-right panel. NO beam leaves the prism, NO bolt crosses the frame. The other three panels have NO glow, NO flare, NO smoke."),
    "032": dict(
        poses=[
            "cruise: the carrier gliding level, all weapons cold and idle, the launch bay doors closed, drones parked and inert on the deck",
            "main-battery fire: the carrier's forward main gun emitters each flashing with one compact round white-cyan starburst pressed flat against the emitter face, like a camera flash going off, the emitter tips glowing white-hot, the whole hull braced, launch bay still closed",
            "bay launch: a row of small drones lifting straight up off the flight deck in a staggered line just above the deck, the carrier otherwise unchanged and level, the main gun emitters cooling",
            "recover: the carrier easing back to level cruise, bay doors closed again, drones stowed on deck, gun emitters dimming to idle",
        ],
        flash="Each firing burst is a single round flat starburst of light pressed against the emitter face, ONLY in the top-right panel. The bursts stay compact and attached to the hull, no rays and no beams extend from them. NO projectiles leave the hull. Drone-launch panels show drones hovering just above the deck but NO gun glow. The top-left and bottom-right panels have NO flash, NO glow, NO smoke."),
    "059": dict(
        poses=[
            "ready: the rocket pod angled up-left, all tube mouths closed and cold, the carrier parked on its tracks",
            "salvo: two front tube mouths bursting with bright launch flames and dense smoke clouds right at the pod face, the pod and carrier rocked slightly by the launch, tube interiors glowing",
            "reload: the pod vents thin smoke from the open tube mouths, the carrier settled on its tracks",
            "settling: the pod back to closed cold tubes angled up-left, the carrier at rest, shown in exact flat side profile view facing left like the reference image",
        ],
        flash="The launch flames and dense smoke stay compact and attached at the tube mouths on the pod face, ONLY in the top-right panel. NO rockets leave the pod, NO streaks cross the frame. The other three panels have NO flames, only the thin vent smoke in the bottom-left panel."),
    "064": dict(
        poses=[
            "ready: the four drones cruising level in their staggered formation heading left, sensor eyes dim",
            "firing: the two lead drones' emitter tips each flashing with one compact round cyan starburst pressed flat against the tip, like a camera flash going off, the sensor eyes flaring, formation unchanged, still exactly four drones",
            "cooling: the drones' emitters glowing faint afterglow, formation unchanged",
            "settling: all four drones cruising level again, sensor eyes dim",
        ],
        flash="Each firing burst is a single round flat starburst of cyan light pressed against the emitter tip, ONLY in the top-right panel. The bursts stay compact and attached to the drones, no rays and no beams extend from them. Exactly four drones appear, no more. The other three panels have NO flash, NO flare, NO smoke."),
    "068": dict(
        poses=[
            "ready: the operative standing braced facing left with both feet planted, the one energy submachine gun raised and aimed level left, seams dim",
            "firing: the energy gun discharging with one compact round cyan-white starburst floating just at the front opening of the barrel, like a camera flash going off, not smeared along the gun and not on the suit, the operative standing braced with both feet planted, minimal motion, stance unchanged, seams glowing faintly",
            "recoil: the operative frozen mid-frame like a paused photograph in exactly the ready stance, the energy submachine gun still raised and aimed level left, both boots flat on the ground, his cloak hanging straight down motionless, the suit seams flaring faintly brighter for an instant, nothing else in motion, no flash",
            "settling: the gun raised and aimed level left exactly as in the ready pose, seams back to dim, the operative standing braced in place with feet planted, his cloak hanging straight down motionless, no stride",
        ],
        flash="The cyan-white burst is one round flat starburst floating just at the muzzle opening, ONLY in the top-right panel. It stays compact and attached to the muzzle opening, NOT smeared along the gun and NOT on the suit. NO bolt leaves the gun, NO streak crosses the frame. The other three panels have NO flash, NO flare, NO smoke."),
    "070": dict(
        desc="a futuristic mobile shrine carrier: one dark obsidian tracked chassis with riveted armor plates, carrying one tall grey crystal obelisk spire on its back, the crystal faces traced with faint blue static veins, small vents and cables at the spire base",
        poses=[
            "ready: the crystal spire humming with dim blue static veins on the crystal faces, the tracked chassis stationary on the ground, its small hull turrets dark and unlit, no light anywhere on the chassis",
            "firing: one compact round blue-white energy sphere bursting right at the spire tip, like a camera flash going off, its glow fading within a short distance of the tip and hugging the crystal, the crystal faces flaring faintly, this sphere is the ONLY light source in the image, the tracked vehicle below sits completely still and dark like a parked machine with its engine off, nothing else glows anywhere in the image",
            "recoil: the sphere gone, faint residual sparks thinning around the spire tip, the crystal dimming back, the chassis frozen exactly as in the ready pose, its small hull turrets dark and unlit, each barrel a cold dark metal tube with zero glow, no flash",
            "settling: the spire back to dim blue static veins exactly as in the ready pose, the tracked chassis at rest in the exact same position, size and orientation as the ready pose, identical to the reference, its small hull turrets dark and unlit, no flash",
        ],
        flash="The firing light is one compact round energy sphere pressed at the spire tip, ONLY in the top-right panel. It is the ONLY light source in that panel: everything below the crystal stays dark and unlit. Its glow stays close to the crystal and fades quickly, NO bolts, NO beams, NO lightning arcs reaching away from the spire, nothing crosses the frame. The other three panels have NO sphere, NO arcs, NO smoke."),
    "087": dict(
        poses=[
            "ready: the one launcher box angled up-left at about forty-five degrees exactly as in the reference, all four tube mouths closed, the trailer parked level on its wheels, the deep magenta background identical to the reference",
            "launch: ONE tube mouth on the upper edge flashing with one small compact launch flame right at that tube opening, a thin wisp of smoke, ALL other tube mouths stay cold and dark, the trailer holding steady on its wheels, nothing leaves the tube",
            "recoil: the flame gone, that one tube mouth venting a thin wisp of smoke, all other tubes cold and dark, the launcher angle unchanged, the trailer parked level, no flash",
            "settling: all tube mouths closed again, the launcher angled up-left at about forty-five degrees exactly as in the ready pose, the trailer at rest, the background flat deep magenta everywhere, evenly saturated with no pale areas, no flash",
        ],
        flash="The launch flame is one small compact burst pressed at ONE tube mouth, ONLY in the top-right panel. It stays small and attached at that tube opening, NO missile is visible, NOTHING leaves the tube, NO streaks cross the frame, the smoke stays a thin wisp and never becomes a cloud. The other three panels have NO flame, only the thin vent smoke in the bottom-left panel."),
    "093": dict(
        poses=[
            "ready: the one emitter cannon pointing level left, lens core dim, cooling fins still, carriage parked",
            "firing: the emitter lens flashing with one blinding white-blue round starburst pressed flat against the lens face, like a giant camera flash going off, the barrel shrouds glowing hot, vents glowing, carriage braced, the whole carriage and emitter keeping the exact same orientation and left-facing profile as the reference, nothing rotated",
            "cooling: the lens core glowing blue afterglow, heat shimmer rising off the barrel, no burst",
            "settling: the lens core back to dim, the emitter level left, carriage at rest",
        ],
        flash="The firing light is a single round flat starburst pressed against the lens face, ONLY in the top-right panel. It stays compact and attached to the lens, no rays and no beams extend from it, nothing crosses the frame. The other three panels have NO burst, only the afterglow and heat shimmer in the bottom-left panel."),
    "095": dict(
        poses=[
            "ready: the hunter standing braced facing left with both feet planted, the one energy carbine raised and shouldered exactly as in the reference, aiming level left, seams dim",
            "firing: the energy carbine discharging with one compact round violet starburst floating just at the front opening of the barrel, a single frozen instant of light like a photo of a camera flash, the burst stays at the muzzle opening and not on the carbine body, the seams glowing faintly, the hunter standing braced, minimal motion",
            "cooling: the carbine glowing violet afterglow, seams dimming, the hunter standing braced facing left with both feet planted in exact left-facing profile view identical to the ready pose, no flash",
            "settling: the carbine back to aimed-ready level left, seams dim",
        ],
        flash="The violet burst is a single round flat starburst floating just at the muzzle opening, ONLY in the top-right panel. It stays compact and attached to the muzzle opening, NOT on the carbine body, no lightning arcs and no rays extend from it, nothing crosses the frame. The other three panels have NO flash, NO flare, NO smoke."),
    "116": dict(
        desc="a domed armored fortress bunker: layered angled armor plates, one large hexagonal cyan energy window glowing on the front face, antennas on the roof, a completely smooth dome with no openings except that one window",
        poses=[
            "ready: the one hexagonal window dim, the dome silent and identical to the reference, sensor masts still",
            "peak: the hexagonal window face lighting up with one compact round cyan burst of light pressed flat on the window itself, like a camera flash going off inside the bunker, the dome steady and identical to the reference with nothing new attached, masts still",
            "cooling: the window glowing faint cyan afterglow, the dome settled and identical to the reference, masts unchanged",
            "settling: the window back to dim exactly as in the reference, the dome at rest, masts still",
        ],
        flash="The cyan burst is one round flat glow pressed on the window face, ONLY in the top-right panel. Nothing leaves the window, no rays and no beams extend from it, nothing crosses the frame. The other three panels have NO burst, NO flare, NO smoke."),
    "128": dict(
        desc="an alien war tripod creature: three long spike-tipped insect legs, a dark carapace body with one smooth curved armored head shell at the front, glowing green stripe markings along the body, hanging tentacle cables",
        poses=[
            "ready: the tripod standing still on its three spike legs, the head shell lowered exactly as in the reference, green stripes dim, tentacles hanging still, the flat magenta background perfectly clean with no clouds and no smudges",
            "peak: the head shell flaring with one compact round green burst of light pressed flat against the shell itself, like a camera flash going off inside the shell, this burst is the ONLY light source with the carapace body and legs staying unlit, no smoke and no mist anywhere, the tripod braced on its three spike legs, the creature identical to the reference with nothing held and nothing attached, tentacles still",
            "cooling: the head shell glowing green afterglow, the stripes fading, tentacles settling, no burst",
            "settling: the stripes back to dim exactly as in the reference, the tripod standing at rest, legs planted",
        ],
        flash="The burst is one round flat green glow pressed flat on the head shell itself, ONLY in the top-right panel. Nothing leaves the shell, no rays and no beams extend from it, nothing crosses the frame. The other three panels have NO burst, NO flare, NO smoke."),
    "039": dict(
        poses=[
            "ready: the trooper standing braced facing left with both feet planted, the service rifle shouldered exactly as in the reference, aiming level left",
            "firing: the rifle discharging with one small compact orange muzzle flash, a small round burst floating just at the front opening of the barrel, not smeared along the barrel and not on the weapon body, the trooper standing braced with both feet planted, minimal motion, stance unchanged",
            "recoil: the trooper frozen mid-frame like a paused photograph in exactly the ready stance, standing braced with both feet planted, the service rifle still shouldered exactly as in the ready pose, aiming level left, only his torso leaning back just a hair, both boots flat on the ground, no flash",
            "settling: the rifle back to shouldered-ready level left, the trooper standing still, feet planted",
        ],
        flash="The muzzle flash is one small round burst floating right at the front opening of the barrel, ONLY in the top-right panel. It stays small and compact, NOT smeared along the barrel, NOT on the weapon body and NOT on the trooper. No rays and no streaks extend from it, nothing crosses the frame. The other three panels have NO flash, NO spark, NO smoke."),
    "056": dict(
        poses=[
            "ready: the marine standing braced facing left with both feet planted, the one M16A4 raised and shouldered exactly as in the reference, aiming level left",
            "firing: the M16A4 discharging with one small compact orange muzzle flash, a small round burst floating just at the front opening of the barrel, not smeared along the barrel and not on the weapon body, like a camera flash going off, the marine standing braced with both feet planted, minimal motion, stance unchanged",
            "recoil: the marine frozen mid-frame like a paused photograph in exactly the ready stance, standing braced with both feet planted, the M16A4 still raised and shouldered with the stock at his shoulder, aiming level left in exact left-facing profile view, only his torso leaning back just a hair, both boots flat on the ground, no flash",
            "settling: the M16A4 raised and shouldered again exactly as in the ready pose, aiming level left, the marine standing braced with both feet planted, a thin wisp of white smoke rising from the muzzle, no flash",
        ],
        flash="The muzzle flash is one small round burst floating right at the front opening of the barrel, ONLY in the top-right panel. It stays small and compact, NOT smeared along the barrel, NOT on the weapon body and NOT on the marine. No rays and no streaks extend from it, nothing crosses the frame. The other three panels have NO flash, NO spark, NO smoke."),
    "069": dict(
        poses=[
            "ready: the colossal mech standing braced facing left, the one arm-mounted rotary gatling cannon pointing level left exactly as in the reference, the left arm a plain armored fist with no weapon, no shoulder cannon, the chest core glow steady, all legs planted",
            "firing: the gatling cannon discharging with one compact round orange-white starburst pressed flat against its muzzle, like a camera flash going off, the mech standing firm on its planted legs, torso unchanged, the left fist unchanged",
            "recoil: the gatling barrel assembly eased back a very short distance into its arm mount, the mech otherwise frozen exactly as in the ready pose, legs planted, torso unchanged, core glow steady, no flash",
            "settling: the gatling back to level left exactly as in the ready pose, the mech standing at full height with torso upright, both legs straight and planted, no crouch, no lean, a thin wisp of white smoke rising from the muzzle, no flash",
        ],
        flash="The firing light is one compact round starburst pressed flat against the gatling muzzle, ONLY in the top-right panel. It stays attached to the muzzle, no rays and no beams extend from it, nothing crosses the frame. The other three panels have NO flash, NO spark, NO smoke."),
    "075": dict(
        poses=[
            "ready: the stormtrooper standing braced facing left with both feet planted, the one MP18 raised and shouldered exactly as in the reference, aiming level left",
            "firing: the MP18 discharging with one small compact orange muzzle flash, a small round burst floating just at the front opening of the barrel, not smeared along the barrel and not on the weapon body, like a camera flash going off, the stormtrooper standing braced with both feet planted, minimal motion, stance unchanged",
            "recoil: the stormtrooper frozen in exactly the same stance as the ready pose, both boots flat on the ground, only the MP18 shifting back a very short distance in his grip, no body movement, no step, no leg raised, no flash",
            "settling: the MP18 back to shouldered-ready level left, the stormtrooper standing still, feet planted",
        ],
        flash="The muzzle flash is one small round burst attached right at the barrel tip, ONLY in the top-right panel. No rays and no streaks extend from it, nothing crosses the frame. The other three panels have NO flash, NO spark, NO smoke."),
    "078": dict(
        poses=[
            "ready: the one long barrel pointing level left, the trail legs spread and planted, the gun shield unchanged, the carriage parked exactly as in the reference",
            "firing: the long barrel discharging with one compact round orange-white starburst pressed flat against the muzzle, like a camera flash going off, the burst stays at the muzzle opening and not along the barrel, the carriage holding steady on its trails, wheels grounded",
            "recoil: the barrel eased back a very short distance into the cradle, the carriage otherwise frozen exactly as in the ready pose, trail legs and gun shield unchanged, no dust, no flash",
            "settling: the barrel back to level left exactly as in the ready pose, the carriage at rest, a thin wisp of white smoke rising from the muzzle, no flash",
        ],
        flash="The firing light is one compact round starburst pressed flat against the muzzle, ONLY in the top-right panel. It stays attached to the muzzle, NOT smeared along the barrel, no rays and no beams extend from it, nothing crosses the frame. The other three panels have NO flash, NO spark, NO smoke, NO dust."),
    "146": dict(
        poses=[
            "ready: the one 75mm front gun pointing level left, the hull resting on its tracks, cupola unchanged",
            "firing: the 75mm gun discharging with one compact round orange-white starburst pressed flat against the muzzle on the front plate, like a camera flash going off, the hull steady on its tracks",
            "recoil: the gun eased back into the glacis, the hull settled, no flash",
            "settling: the gun back to level left, the hull at rest",
        ],
        flash="The firing light is one compact round starburst pressed flat against the gun muzzle, ONLY in the top-right panel. It stays attached to the muzzle, no rays and no beams extend from it, nothing crosses the frame. The other three panels have NO flash, NO spark, NO smoke."),
    "149": dict(
        poses=[
            "ready: the unmanned automatic machine gun emplacement pointing level left exactly as in the reference, the tripod planted, the ammunition drum box unchanged, the muzzle completely dark and cold with no flash and no smoke, absolutely no people anywhere",
            "firing: the MG42 discharging with one small compact orange muzzle flash, a small round burst floating just at the front opening of the barrel sleeve, not smeared along the barrel and not on the mount, like a camera flash going off, the emplacement frozen exactly as in the ready pose, absolutely no people anywhere",
            "recoil: the gun body cycled back a very short distance on its tripod mount, the emplacement otherwise frozen exactly as in the ready pose, tripod and drum box unchanged, absolutely no people anywhere, no flash",
            "settling: the gun back to level left exactly as in the ready pose, barrel dark, a thin wisp of white smoke drifting from the barrel sleeve, the tripod at rest, absolutely no people anywhere, no flash",
        ],
        flash="The muzzle flash is one small round burst floating right at the front opening of the barrel, ONLY in the top-right panel. It stays small and compact, NOT smeared along the barrel, NOT on the mount. No rays and no streaks extend from it, nothing crosses the frame. NO crew figure, NO person appears in any panel. The other three panels have NO flash, NO spark, NO smoke."),
    # ── 二轮重掷修订(2026-10-15 目验后):057 射手混入+BR 爆闪 / 113 TR 沙地+炮架变形 / 086 053 步态漂移 / 017 仰角漂移+ready 烟 ──
    "110": dict(
        desc="a low hexagonal weathered concrete hut: grey concrete walls with rain stains and moss patches, one dark empty rectangular window opening facing the left edge with its interior in deep shadow, sandbags piled at the base, a dented shallow dome roof, a plain hut with no fixtures and no attachments",
        poses=[
            "ready: the one dark window opening completely empty with nothing inside it, the hut identical to the reference with nothing added, nothing attached and nothing held, sandbags unchanged",
            "peak: one compact round warm-yellow burst of light pressed flat right on the dark window opening, like a camera flash going off inside, the opening glowing from within, the hut otherwise identical to the reference with nothing new attached, sandbags and dome roof unchanged",
            "cooling: the window opening glowing faint warm afterglow from within, the hut settled and identical to the reference, sandbags unchanged, no flash",
            "settling: the dark window opening back to dark exactly as in the ready pose, still empty with nothing inside it, the hut at rest, identical to the reference, no flash",
        ],
        flash="The light is one round flat glow pressed right on the dark window opening, ONLY in the top-right panel. The hut stays bare: nothing is mounted on it, nothing protrudes from any wall, the window is its only opening and stays empty. Nothing leaves the opening, no rays and no beams extend from it, nothing crosses the frame. The other three panels have NO burst, NO flare, NO smoke."),
    "057": dict(
        poses=[
            "ready: the ring-mounted heavy machine gun pointing level left, the cab and cargo bed empty, nobody anywhere, the pickup parked level on its four wheels",
            "firing: the ring-mounted heavy machine gun discharging with one compact orange muzzle flash, a small round burst floating just at the front opening of the barrel, not smeared along the barrel and not on the weapon body, nothing streaks out of the muzzle and the magenta air around stays clean and empty, the gun still mounted on its ring exactly as in the reference, the cargo bed side rails and both spare tyres identical to the reference, the cab and bed empty, nobody anywhere, wheels grounded",
            "recoil: the gun cycled slightly back on its ring mount, the bed and cab unchanged and empty, nobody anywhere, no flash",
            "settling: the gun back to level left on its ring mount exactly where it sits in the ready pose, barrel dark, the pickup at rest, the cargo bed keeps its ribbed side rails and BOTH spare tyres (one behind the cab, one at the tailgate) exactly as in the ready pose, nothing is removed, the bed empty, nobody anywhere",
        ],
        flash="The muzzle flash is one small round burst floating right at the front opening of the gun barrel, ONLY in the top-right panel. It stays small and compact, NOT smeared along the barrel and NOT on the pickup. The magenta air between the muzzle and the frame edge stays completely clean and empty, no rays and no streaks extend from the burst, nothing crosses the frame. NO crew figure, NO gunner, NO person appears in any panel. The other three panels have NO flash, NO spark, NO smoke."),
    "113": dict(
        poses=[
            "ready: the one long barrel elevated toward the upper left at the same angle as the reference, the muzzle completely dark with no glow and no smoke, the cross-shaped platform and splinter shield identical to the reference, planted on the bare flat magenta floor",
            "firing: the long barrel discharging with one compact round orange-white starburst pressed flat against the muzzle, like a camera flash going off, the barrel keeping exactly the same elevation as the reference, only a small smoke puff at the muzzle with NO smoke band and no trail extending toward any frame edge, the cross-shaped platform and splinter shield identical to the reference, the floor around stays bare flat magenta with no dust and no ground",
            "recoil: the barrel eased slightly back in its cradle at the same elevation, the platform and shield identical to the reference, bare magenta floor, no flash",
            "settling: the barrel back elevated toward the upper left, just one small thin wisp of white smoke rising from the muzzle and fading within a short distance, no long smoke trail and no smoke band anywhere, the platform at rest on the bare magenta floor, identical to the reference",
        ],
        flash="The firing light is one compact round starburst pressed flat against the muzzle, ONLY in the top-right panel. It stays attached to the muzzle, no rays and no beams extend from it, nothing crosses the frame. NO dust, NO ground patch, NO sand appears in any panel. The other three panels have NO flash, NO spark, NO smoke."),
    "086": dict(
        poses=[
            "ready: the rifleman standing braced with both feet planted, the one M4 aimed level left, foregrip locked",
            "firing: the M4 discharging with one compact round orange muzzle flash right at the barrel tip, like a camera flash going off, the rifleman standing braced with both feet planted, stance unchanged, no straps and no ribbons flying off the gear",
            "recoil: the rifleman frozen in exactly the same stance as the ready pose, both boots flat on the ground, only the carbine shifting back slightly in his grip, no body movement, no step, no leg raised, no flash",
            "settling: the carbine back to aimed-ready, level left, the rifleman standing still, feet planted",
        ],
        flash="The muzzle flash is one small round burst attached right at the barrel tip, ONLY in the top-right panel. No rays and no streaks extend from it, nothing crosses the frame. The other three panels have NO flash, NO spark, NO smoke."),
    "017": dict(
        poses=[
            "ready: the quad autocannon cluster angled up-left at the same elevation as the reference, barrels cold and clean with no smoke, the one radar dish raised high on its mast behind the cab, clearly visible in profile as in the reference, the same color palette and lighting as the reference, all five road wheels grounded",
            "firing: the quad cluster discharging with one compact star-shaped flash pressed flat at the cluster muzzle, the cluster keeping the same up-left elevation as the reference, the one radar dish raised high on its mast, clearly visible in profile as in the reference, the same color palette as the reference, all five wheels grounded, hull braced",
            "recoil: the quad cluster eased slightly back on its trunnion at the same elevation, the one radar dish raised high on its mast, clearly visible in profile as in the reference, the same color palette as the reference, all five wheels grounded, no smoke",
            "settling: the quad cluster back angled up-left at the reference elevation, the one radar dish raised high on its mast, clearly visible in profile as in the reference, the same color palette as the reference, all five wheels grounded, barrels cold, calm stance",
        ],
        flash="The star-shaped muzzle flash is one small round compact burst centered on the four-barrel cluster tip, ONLY in the top-right panel, orange-yellow with a white core, its glow fading out within a short distance of the muzzle. NO long spikes, NO tracer streaks, NO rays extend from the burst toward any edge, nothing crosses the frame. The other three panels have NO flash, NO spark, NO smoke."),
    "053": dict(
        poses=[
            "ready: the operator standing braced with both feet planted, the one AK-105 shouldered and aimed level left, stock welded to the shoulder",
            "firing: the AK-105 discharging with one compact round orange muzzle flash right at the barrel tip, like a camera flash going off, the operator standing braced with both feet planted, stance unchanged",
            "recoil: the operator frozen mid-frame like a paused photograph in exactly the ready stance, standing braced with both feet planted, the AK-105 still raised and shouldered with the stock welded at his shoulder, aiming level left, only his torso leaning back just a hair, both boots flat on the ground, no flash",
            "settling: the carbine back to the aimed-ready position, level left, the operator standing still, feet planted",
        ],
        flash="The muzzle flash is one small round burst attached right at the barrel tip, ONLY in the top-right panel. No rays and no streaks extend from it, nothing crosses the frame. The other three panels have NO flash, NO spark, NO smoke."),
    # ── 三轮:人形批(2026-10-15 用户令「先做人形的」,卡图已重生成=站定上肩瞄准;炮管/枪后缩幅度小)──
    # ── 四轮:用户反馈「火光要在炮口不在炮管/主体上,人形动作别夸张」(2026-10-15):039/059 重写,057 补强 ──
    "059": dict(
        poses=[
            "ready: the rocket pod angled up-left, all tube mouths closed and cold and dark, the carrier parked on its tracks",
            "firing: one single launch flash at ONE tube mouth on the upper edge of the pod, a small compact ball of white-orange fire floating just at that one tube opening with a thin wisp of smoke, ALL other tube mouths stay cold and dark, the launcher rack, the cab and its headlights stay completely dark, no rocket leaves the frame",
            "recoil: the flash gone, that one tube mouth venting a thin wisp of smoke, all other tubes cold and dark, the pod angle unchanged, the carrier parked level on its tracks",
            "settling: all tube mouths closed, cold and dark, the pod angled up-left exactly as in the reference, the carrier at rest in the exact left-facing profile view identical to the reference, the cab stays the plain welded armored box exactly as in the ready pose, no extra windows, no glass panels, only its narrow vision slit unchanged, no headlights on",
        ],
        flash="The launch flash is ONE small round fireball pressed at ONE tube mouth on the upper edge of the pod, ONLY in the top-right panel. It stays small and attached at that tube opening, NOT smeared along the tubes, NOT on the launcher rack, NOT on the hull, the cab and headlights stay dark. NO streaks, NO rockets fly out, nothing crosses the frame. The other three panels have NO flash, NO flame, NO smoke."),
    "066": dict(
        poses=[
            "ready: the exoskeleton trooper standing braced facing left with both feet planted, the one bullpup rifle raised and shouldered exactly as in the reference, aiming level left, servos settled",
            "firing: the bullpup rifle discharging with one small compact orange muzzle flash, a small round burst floating just at the front opening of the barrel, not smeared along the barrel and not on the weapon body, like a camera flash going off, the trooper standing braced with both feet planted, minimal motion, stance unchanged, servos locked",
            "recoil: the trooper frozen in exactly the same stance as the ready pose, the bullpup rifle still raised and shouldered with the stock welded at his cheek, aiming level left, only his torso leaning back just a hair, both boots flat on the ground, no body movement, no step, no leg raised, no crouch, no flash",
            "settling: the bullpup rifle raised and shouldered again exactly as in the ready pose, stock at his cheek, aiming level left, the trooper standing braced with both feet planted, a thin wisp of white smoke rising from the muzzle, no flash, servos settled",
        ],
        flash="The muzzle flash is one small round burst attached right at the rifle barrel tip, ONLY in the top-right panel. No rays and no streaks extend from it, nothing crosses the frame. The other three panels have NO flash, NO spark, NO smoke."),
}

# cfg 修订过的卡：首轮旧弹道拍作废不复用；首轮跑完后清空，靠文件存在复用
FIXED_NOS = set()  # 2026-10-15 首轮已完成，改按需删拍重掷

# ── margin 约束（Q3：主体缩、留焰烟空间、不触图缘）──
MARGIN = ("The subject occupies about 80% of the frame, centered, with empty flat magenta margin "
          "on all four sides - leave room around the weapon for its compact muzzle effects. "
          "All flashes, smoke and glow stay compact and attached to the weapon, "
          "NEVER touching or bleeding off the frame edges. ")

# 无武器卡专用（116/128）：清洗 weapon/muzzle/barrels 字眼，防模型自造枪管
NO_WEAPON_MARGIN = ("The subject occupies about 80% of the frame, centered, with empty flat magenta margin "
                    "on all four sides. All light effects stay compact and attached to the subject, "
                    "NEVER touching or bleeding off the frame edges. ")
NO_WEAPON_INV = ("facing LEFT in profile, the subject NEVER mirrored, "
                 "IDENTICAL structure, identical part count and identical proportions as the reference image "
                 "in every panel: the subject looks exactly like the reference with nothing added, "
                 "nothing attached and nothing held, ")

ALL_CFG = {**V1.UNITS_CFG, **V1.UNITS_CFG2}

# 无武器卡：走 NO_WEAPON_MARGIN/INV 通道
NO_WEAPON_NOS = {'116', '128'}


def merged_cfg(no):
    return {**ALL_CFG[no], **FIX_CFG.get(no, {})}


def call_i2i(refs, prompt, out_path, tries=24):
    """6 key 双 host 轮换。401 剔单 key；403 熔断；503 长退避。"""
    bodies = {}
    for grp, url in HOSTS.items():
        bodies[grp] = {"model": MODEL, "prompt": prompt, "image_size": "1024x1024",
                       "extra_body": {"image": ["data:image/png;base64," + b for b in refs],
                                      "response_format": "url"}}
    dead = set()  # 401 剔除的 key 下标
    for att in range(tries):
        live = [i for i in range(len(KEY_POOL)) if i not in dead]
        if not live:
            print("    all keys dead (401) - abort", flush=True)
            raise SystemExit(3)
        grp, key = KEY_POOL[live[att % len(live)]]
        try:
            req = urllib.request.Request(HOSTS[grp], data=json.dumps(bodies[grp]).encode(),
                                         headers={"Authorization": "Bearer " + key,
                                                  "Content-Type": "application/json"})
            d = json.loads(urllib.request.urlopen(req, timeout=300, context=CTX).read().decode())
            url = (d.get("data") or [{}])[0].get("url", "")
            if url and "/i2i/" in url:
                png = urllib.request.urlopen(urllib.request.Request(url), timeout=180,
                                             context=CTX).read()
                open(out_path, "wb").write(png)
                return True, url
            if url:
                # 新站 i2i URL 旗标未确证：/t2i/ 也保存但明示警告，人工核对
                print("    ⚠ i2i 旗标缺失(%s), 存疑保存" % url.split("/images/")[-1][:40],
                      flush=True)
                png = urllib.request.urlopen(urllib.request.Request(url), timeout=180,
                                             context=CTX).read()
                open(out_path, "wb").write(png)
                return True, url
            raise RuntimeError("no url: %s" % json.dumps(d)[:160])
        except urllib.error.HTTPError as e:
            print("    HTTP %d %s" % (e.code, e.read().decode()[:120]), flush=True)
            if e.code == 403:
                raise SystemExit(3)
            if e.code == 401:
                dead.add(KEY_POOL.index((grp, key)))
                time.sleep(6)
                continue
            if e.code == 503:
                time.sleep(45 + min(att, 24) * 6)
                continue
        except Exception as e:
            print("    err %r" % e, flush=True)
        time.sleep(6)
    return False, None


def b64(im):
    buf = io.BytesIO()
    im.save(buf, "PNG")
    return base64.b64encode(buf.getvalue()).decode()


def gen_unit(no):
    import _tmp_api_card_regen_batch2 as B2
    all_units = {u["no"]: u for u in UNITS}
    for u in B2.UNITS2:
        all_units.setdefault(u["no"], u)
    if no not in all_units or no not in ALL_CFG:
        print("[%s] 无单位或无配置, skip" % no, flush=True)
        return
    u = all_units[no]
    cfg = merged_cfg(no)
    card = os.path.join(RAW, "%s·%s.png" % (u["no"], u["name"]))
    if not os.path.exists(card):
        print("[%s·%s] 卡图缺失, skip" % (u["no"], u["name"]), flush=True)
        return
    card_im = Image.open(card).convert("RGB")
    pose_dir = os.path.join(RAW, "poses")
    os.makedirs(pose_dir, exist_ok=True)
    panels = []
    for beat, pose in zip(["TL", "TR", "BL", "BR"], cfg["poses"]):
        out = os.path.join(pose_dir, "%s·%s_%s.png" % (u["no"], u["name"], beat))
        if os.path.exists(out) and no not in FIXED_NOS:
            panels.append(Image.open(out).convert("RGB"))
            print("  [%s %s] 已有, 复用" % (no, beat), flush=True)
            continue
        if no in NO_WEAPON_NOS:
            prompt = (V1.SKELETON.replace("{DESC}", cfg["desc"])
                      + "Now show THE SAME subject in this exact action beat: %s. " % pose
                      + NO_WEAPON_MARGIN + NO_WEAPON_INV + " Identical scale and colors as the reference image.")
        else:
            prompt = (V1.SKELETON.replace("{DESC}", cfg["desc"])
                      + "Now show THE SAME subject in this exact action beat: %s. " % pose
                      + MARGIN + V1.INV + " Identical scale and colors as the reference image.")
        if beat == "TR" and cfg.get("flash"):
            prompt = prompt + " " + cfg["flash"]
        t0 = time.time()
        ok, _ = call_i2i([b64(card_im)], prompt, out)
        print("  [%s·%s %s] %s %.0fs" % (u["no"], u["name"], beat,
              "OK" if ok else "FAIL", time.time() - t0), flush=True)
        if not ok:
            return
        panels.append(Image.open(out).convert("RGB"))
        time.sleep(2)
    grid = Image.new("RGB", (2048, 2048), (255, 0, 255))
    for p, (cx, cy) in zip(panels, ((0, 0), (1, 0), (0, 1), (1, 1))):
        grid.paste(p.resize((1024, 1024), Image.LANCZOS), (cx * 1024, cy * 1024))
    out = os.path.join(RAW, "%s·%s_开火4格.png" % (u["no"], u["name"]))
    grid.save(out)
    print("[%s·%s] 拼合 -> %s" % (u["no"], u["name"], os.path.basename(out)), flush=True)


def main(nos):
    for no in nos:
        gen_unit(no)
        time.sleep(3)


if __name__ == "__main__":
    targets = sys.argv[1].split(",") if len(sys.argv) > 1 else sorted(ALL_CFG)
    # 只跑缺开火4格的卡
    todo = []
    for no in targets:
        import _tmp_api_card_regen_batch2 as B2
        all_units = {u["no"]: u for u in UNITS}
        for u in B2.UNITS2:
            all_units.setdefault(u["no"], u)
        u = all_units.get(no)
        if u and not os.path.exists(os.path.join(RAW, "%s·%s_开火4格.png" % (no, u["name"]))):
            todo.append(no)
    print("待生成 %d 张: %s" % (len(todo), ",".join(todo)), flush=True)
    main(todo)
