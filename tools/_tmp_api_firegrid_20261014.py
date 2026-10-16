# -*- coding: utf-8 -*-
"""4 格开火视图生成批（2026-10-14）：以 raw/ 选定卡图为锚，i2i 出 2x2 开火四拍。

先例 = tools/api_sprite_pipeline/grid2x2_vehicle.py（参考=[2x2 底稿, 原卡图]，
四拍 ready→firing(唯一带焰)→recoil→settling，焰只在右上格）。
本批用户口径：**只生图**——不键控、不切格、不拼卷；产物直接落
docs/卡图API重生成_20261014/raw/<编号·名称>_开火4格.png。

用法：python tools/_tmp_api_firegrid_20261014.py [编号,编号,...]   # 缺省全 10
"""
import base64
import io
import json
import os
import ssl
import sys
import time
import urllib.error
import urllib.request

from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from _tmp_api_card_regen_20261014 import UNITS, KEYS, RAW, LEDGER  # noqa: E402

IMG = "https://api.agnes-ai.cn/v1/images/generations"
CTX = ssl.create_default_context()
CTX.check_hostname = False
CTX.verify_mode = ssl.CERT_NONE
MODEL = "agnes-image-2.5-flash"

# ── 每单位专属四拍姿态（顺序=左上/右上/左下/右下）+ 焰句——部件复述=结构锁（2026-10-14
# 用户口径：几种不同单位提示词必须差异化，且先批有变形——每拍复述该单位关键部件清单防增删部件。──
UNITS_CFG = {
    "011": dict(
        desc="an unmanned automatic 81mm mortar weapon: a wide olive-green base plate, one ammunition drum and one mechanical auto-loader arm beside an angled mortar tube, rust-brown steel details",
        poses=[
            "ready: the mortar stable on its wide base plate, the tube angled up-left, the ammunition drum full and the auto-loader arm parked beside the tube",
            "firing: a compact flash and small smoke puff at the upward muzzle, the auto-loader arm locked at the tube mouth, the drum, the base plate and the tube all unchanged in shape",
            "recoil: the tube pressed slightly down into the base plate, the auto-loader arm swinging back, the drum and base plate unchanged in shape",
            "settling: back to the ready stance, tube angled up-left, drum full, arm parked, base plate unchanged",
        ],
        flash="The muzzle flash and smoke puff appear in ONLY the top-right panel, small and attached directly at the upward muzzle mouth. The other three panels have NO flash, NO spark, NO smoke."),
    "012": dict(
        desc="an unmanned automatic trench mortar: one riveted steel mount, one chain-fed ammunition belt draped into the breech, brass gears on the side, field-grey and rust-brown steel",
        poses=[
            "ready: the mortar stable on its riveted steel mount, the chain-fed belt draped into the breech, all brass gears engaged",
            "firing: a compact flash at the upward muzzle, the chain belt advanced by exactly one link, the brass gears turned one notch, the riveted mount and the tube unchanged in shape",
            "recoil: the tube pressed down slightly, the chain belt settled, the gears at rest, the riveted mount unchanged in shape",
            "settling: back to ready, chain belt draped, gears engaged, riveted mount unchanged",
        ],
        flash="The muzzle flash appears in ONLY the top-right panel, small and attached directly at the upward muzzle mouth. The other three panels have NO flash, NO spark, NO smoke."),
    "017": dict(
        desc="a Soviet ZSU-23-4 Shilka: one quad 23mm autocannon cluster on a boxy turret with one raised radar dish, tracked chassis with five road wheels per side, dark olive green",
        poses=[
            "ready: the quad autocannon cluster pointing up-left, the one radar dish raised, all five road wheels on the ground, hull at rest",
            "firing: the quad cluster discharging with one compact star-shaped flash at the cluster muzzle, the radar dish raised, all five wheels grounded, hull braced",
            "recoil: the quad cluster eased slightly back on its trunnion, the radar dish raised, all five wheels grounded",
            "settling: the quad cluster back to pointing up-left, radar dish raised, all five wheels grounded, calm stance",
        ],
        flash="The star-shaped muzzle flash appears in ONLY the top-right panel, one flash at the four-barrel cluster tip, orange-yellow with a white core. The other three panels have NO flash, NO spark, NO smoke."),
    "019": dict(
        desc="an M1A1 Abrams main battle tank: one low angular turret, one long 120mm gun barrel, side skirts over seven road wheels per side, NATO green",
        poses=[
            "ready: the one 120mm gun barrel pointing level left from the low angular turret, all seven road wheels and side skirts unchanged, hull at rest",
            "firing: the 120mm gun discharging with one compact star-shaped flash at the barrel tip, the turret seated, all seven wheels and side skirts unchanged",
            "recoil: the one barrel eased a little back into the mantlet, turret unchanged, all seven wheels and side skirts unchanged",
            "settling: the barrel back to pointing level left, turret at rest, all seven wheels and side skirts unchanged",
        ],
        flash="The star-shaped muzzle flash appears in ONLY the top-right panel, small, orange-yellow with a white core, attached directly at the barrel tip. The other three panels have NO flash, NO spark, NO smoke."),
    "026": dict(
        desc="a futuristic prism tank: one white ceramic hull, one tall crystalline prism tower with refractor nodes, cyan-blue energy conduits along the hull",
        poses=[
            "ready: the one prism tower dark and idle, the cyan conduits dim, the hover hull level",
            "firing: the one prism tower emitting a single bright cyan beam wedge toward the upper-left from its crystal tip, the conduits flaring bright, the hull level and unchanged",
            "recoil: the one prism tower cooling with a faint afterglow, conduits dimming, the hull level and unchanged",
            "settling: the tower back to dark idle, conduits dim, hull level",
        ],
        flash="The bright cyan beam and conduit flare appear in ONLY the top-right panel. The other three panels have NO beam, NO glow, NO flash, NO smoke."),
    "030": dict(
        desc="a colossal titan walker: one central armored hull, two long-barreled rail cannons side by side, four articulated legs, gunmetal blue-grey with amber stripes",
        poses=[
            "ready: both twin rail cannons pointing level left from the one central hull, all four articulated legs planted, amber stripes unchanged",
            "firing: both rail cannons discharging together, one compact flash at each of the two muzzles, all four legs planted and braced, hull unchanged",
            "recoil: both cannons eased slightly back into the one central hull, all four legs planted, amber stripes unchanged",
            "settling: both cannons back to pointing level left, all four legs planted, calm stance",
        ],
        flash="The two muzzle flashes appear in ONLY the top-right panel, compact, one at each rail cannon tip. The other three panels have NO flash, NO spark, NO smoke."),
    "032": dict(
        desc="a massive futuristic airborne carrier in side view: one broad flying-wing hull, rows of engine pods, one open launch bay deck with small drones parked in rows, dark blue-grey with cyan trim",
        poses=[
            "cruise: the carrier gliding level, all weapons cold and idle, the launch bay doors closed, drones parked and inert on the deck",
            "main-battery fire: the carrier's forward main guns discharging in a broad salvo toward the left edge, bright cyan-white energy bolts streaming left from each gun, the whole hull braced against the firing, launch bay still closed",
            "bay launch: the open launch bay doors swinging open from above, the row of small drones releasing and lifting up-and-out of the deck in a staggered line, the main guns re-cooling between salvos",
            "recover: the carrier easing back to level cruise, bay doors closed again, drones stowed on deck, gun emitters dimming to idle",
        ],
        flash="The main-battery energy bolts and gun glow appear ONLY in the top-right panel. The drone-launch panels may show small drones leaving the bay but NO gun bolts or gun glow. The top-left and bottom-right panels have NO flash, NO bolts, NO glow, NO smoke."),
    "037": dict(
        desc="an unmanned automatic machine gun nest: one curved wall of stacked sandbags, one water-cooled heavy machine gun with barrel and jacket, one ammunition belt and box, one clockwork traverse mechanism, tan and olive",
        poses=[
            "ready: the one water-cooled barrel pointing level left from its mechanical mount, the ammunition belt resting in the feed, the clockwork mechanism still, the sandbag wall unchanged",
            "firing: one compact flash at the barrel tip, the belt advanced by one link, the clockwork turned one notch, the sandbag wall and the gun unchanged in shape",
            "recoil: the barrel jacket cycled slightly back on its mount, the belt settled, the clockwork at rest, the sandbag wall unchanged",
            "settling: back to ready, the barrel level left, belt resting, clockwork still, sandbag wall unchanged",
        ],
        flash="The muzzle flash appears in ONLY the top-right panel, small and attached directly at the barrel tip. The other three panels have NO flash, NO spark, NO smoke."),
    "038": dict(
        desc="an unmanned compact light automatic trench mortar: one tripod base, one angled mortar tube, one drum magazine auto-feeder, blued steel",
        poses=[
            "ready: the mortar stable on its one tripod, the tube angled up-left, the one drum magazine seated full",
            "firing: a compact flash at the upward muzzle, the one drum magazine, the tripod and the tube all unchanged in shape",
            "recoil: the tube pressed slightly down onto the one tripod, the drum magazine unchanged",
            "settling: back to ready, the tube angled up-left, the drum seated, the tripod unchanged",
        ],
        flash="The muzzle flash appears in ONLY the top-right panel, small and attached directly at the upward muzzle mouth. The other three panels have NO flash, NO spark, NO smoke."),
    "039": dict(
        desc="a single elite assault trooper: grey-green combat fatigues, one smooth rounded combat helmet, one chest rig with pouches, one service rifle with a visible muzzle",
        poses=[
            "windup: the trooper advancing toward the left edge in a low ready gait, the service rifle cocked up at the shoulder, muzzle pointing ahead-left, about to fire",
            "firing: the trooper surging forward and firing, one compact orange-yellow muzzle flash with a white core directly at the rifle muzzle, body braced forward in a charging stance, rifle held firm",
            "recoil: the trooper still driving left, the service rifle kicked back a little against his shoulder from the shot, muzzle ahead-left, no flash",
            "recover: the trooper re-cocking the rifle and resuming the forward advance, muzzle ahead-left, settling into the ready gait",
        ],
        flash="The muzzle flash appears in ONLY the top-right panel, compact and attached directly at the rifle muzzle. The top-left, bottom-left and bottom-right panels have NO flash, NO spark, NO smoke."),
}

INV = ("facing LEFT in profile, the weapon pointing to the left where applicable, "
       "the subject NEVER mirrored, "
       "IDENTICAL structure, identical part count and identical proportions as the reference image in every panel: "
       "the same number of wheels, legs, barrels, gears, drums, sandbags and pouches in every panel, "
       "never adding, removing or reshaping any part, the same colors and details in every panel")

# ── 批2（编号 041~149）26 单位攻击图配置：各卡专属动作，射击为主 ──
UNITS_CFG2 = {
    "041": dict(
        desc="a World War I French Saint-Chamond heavy tank: one long overhanging hull with sloped front glacis, one short 75mm gun in the front plate, a small top cupola, exposed coil-spring suspension and tracks, riveted grey-blue steel",
        poses=[
            "ready: the one 75mm front gun pointing level left, the hull resting on its tracks, cupola unchanged",
            "firing: the 75mm gun discharging with one compact star-shaped flash at the muzzle, the hull rocking slightly on its springs, cupola and tracks unchanged",
            "recoil: the one gun eased back into the front glacis, the hull settled back onto its tracks, no flash",
            "settling: the gun back to level left, the hull at rest, cupola unchanged",
        ],
        flash="The star-shaped muzzle flash appears in ONLY the top-right panel, orange-yellow with a white core, attached at the 75mm muzzle. The other three panels have NO flash, NO spark, NO smoke."),
    "053": dict(
        desc="a modern special forces operator in dark digital-camo fatigues and black webbing, aiming one AK-105 carbine with both hands",
        poses=[
            "ready: the operator in a braced stance, the one AK-105 shouldered and aimed level left, stock welded to the shoulder",
            "firing: the AK-105 discharging with one compact orange muzzle flash at the barrel tip, the operator braced against the shot, stance unchanged",
            "recoil: the carbine kicked back slightly into the shoulder, the operator absorbing it, no flash",
            "settling: the carbine back to the aimed-ready position, level left, calm stance",
        ],
        flash="The muzzle flash appears in ONLY the top-right panel, small, attached at the barrel tip. The other three panels have NO flash, NO spark, NO smoke."),
    "056": dict(
        desc="a modern marine in woodland digital camo and one combat helmet, holding one M16A4 rifle at the ready",
        poses=[
            "ready: the marine in a bladed stance, the one M16A4 shouldered and aimed level left",
            "firing: the M16A4 discharging with one compact orange muzzle flash at the barrel tip, the marine braced, stance unchanged",
            "recoil: the rifle kicked back slightly into the shoulder, the marine absorbing it, no flash",
            "settling: the rifle back to the aimed-ready position, level left",
        ],
        flash="The muzzle flash appears in ONLY the top-right panel, small, attached at the barrel tip. The other three panels have NO flash, NO spark, NO smoke."),
    "057": dict(
        desc="an armed technical pickup truck: one olive-green single-cab pickup with one heavy machine gun ring-mounted in the open cargo bed, spare tyres in the bed",
        poses=[
            "ready: the ring-mounted heavy machine gun pointing level left, the pickup parked level on its four wheels",
            "firing: the machine gun discharging with one compact flash at the barrel tip and a spent-case arc, the gunner shield and cab unchanged, wheels grounded",
            "recoil: the gun cycled slightly back on its ring mount, the bed and cab unchanged, no flash",
            "settling: the gun back to level left, the pickup at rest",
        ],
        flash="The muzzle flash appears in ONLY the top-right panel, small, attached at the gun barrel tip. The other three panels have NO flash, NO spark, NO smoke."),
    "059": dict(
        desc="a tracked self-propelled multiple rocket launcher: one boxy tracked carrier with cab at the front, one raised pod cluster of rocket tubes on the rear bed angled up-left",
        poses=[
            "ready: the rocket pod angled up-left, all tube mouths closed and cold, the carrier parked on its tracks",
            "salvo: two rockets leaving the top-right tube mouths with bright launch flames and smoke, streaking toward the upper-left edge, the pod and carrier unchanged",
            "reload: the pod vents thin smoke, the carrier settled on its tracks, tube mouths empty and open",
            "settling: the pod back to closed cold tubes angled up-left, the carrier at rest",
        ],
        flash="The rocket launch flames and smoke appear in ONLY the top-right panel, two rockets streaking up-left. The other three panels have NO rockets, NO flames, NO smoke except the thin vent smoke in the bottom-left panel."),
    "060": dict(
        desc="a Delta Force operator in tan combat gear and black balaclava, aiming one M4 carbine with an optic",
        poses=[
            "ready: the operator bladed behind the one M4, aimed level left, stock welded",
            "firing: the M4 discharging with one compact orange muzzle flash at the barrel tip, the operator braced, stance unchanged",
            "recoil: the carbine kicked into the shoulder, the operator absorbing it, no flash",
            "settling: the carbine back to aimed-ready, level left",
        ],
        flash="The muzzle flash appears in ONLY the top-right panel, small, attached at the barrel tip. The other three panels have NO flash, NO spark, NO smoke."),
    "064": dict(
        desc="a swarm of four small futuristic combat drones in loose staggered formation: sleek dark-grey delta stealth shapes with glowing cyan sensor eyes",
        poses=[
            "ready: the four drones cruising level in their staggered formation heading left, sensor eyes dim",
            "firing: the two lead drones discharging small bright cyan energy bolts toward the left edge, sensor eyes flaring, formation unchanged",
            "cooling: the drones' emitters glowing faint afterglow, bolts gone, formation unchanged",
            "settling: all four drones cruising level again, sensor eyes dim",
        ],
        flash="The cyan energy bolts and sensor flare appear in ONLY the top-right panel. The other three panels have NO bolts, NO flare, NO smoke."),
    "066": dict(
        desc="a future mech infantry trooper in one light powered exoskeleton: pale blue-white armor plates, dark servo joints, cyan accent lights, carrying one bullpup rifle",
        poses=[
            "ready: the trooper striding left in the exoskeleton, the one bullpup rifle shouldered and aimed level left, servos settled",
            "firing: the bullpup rifle discharging with one compact orange muzzle flash at the barrel tip, the trooper braced mid-stride, servos locked",
            "recoil: the rifle kicked into the shoulder, the trooper's stride absorbing it, no flash",
            "settling: the rifle back to aimed-ready level left, the trooper resuming the stride",
        ],
        flash="The muzzle flash appears in ONLY the top-right panel, small, attached at the rifle barrel tip. The other three panels have NO flash, NO spark, NO smoke."),
    "068": dict(
        desc="a futuristic stealth operative in one dark teal nano-weave suit with glowing seams and a half-face visor, holding one compact energy submachine gun",
        poses=[
            "ready: the operative gliding left, the one energy submachine gun raised and aimed level left, seams dim",
            "firing: the energy gun discharging one bright cyan-white bolt toward the left edge, the suit seams flaring, the operative braced",
            "cooling: the emitter glowing faint afterglow, the bolt gone, seams dimming, no bolt",
            "settling: the gun back to aimed-ready level left, seams dim",
        ],
        flash="The energy bolt and seam flare appear in ONLY the top-right panel. The other three panels have NO bolt, NO flare, NO smoke."),
    "069": dict(
        desc="a towering futuristic colossus mech: heavy pale-green armor, one shoulder-mounted cannon, one arm gatling gun, thick digitigrade legs, glowing cyan core",
        poses=[
            "ready: the one shoulder cannon pointing level left, the arm gatling lowered, all digitigrade legs planted, core glow steady",
            "firing: the shoulder cannon discharging with one large star-shaped flash at its muzzle, the whole mech rocked back on its legs, the gatling unchanged",
            "recoil: the cannon eased back into its mount, the mech settled onto its legs, the core glow steady, no flash",
            "settling: the cannon back to level left, the mech at rest, legs planted",
        ],
        flash="The star-shaped flash appears in ONLY the top-right panel, large, at the shoulder cannon muzzle. The other three panels have NO flash, NO spark, NO smoke."),
    "070": dict(
        desc="a futuristic storm-core battle tower: one obsidian tracked chassis with one vertical spire of glowing blue lightning coils, vents and cables",
        poses=[
            "ready: the coil spire humming with dim blue arcs, the tower stationary on its tracks",
            "firing: the spire discharging one thick branching blue lightning bolt toward the left edge, every coil flaring bright, the chassis unchanged",
            "cooling: the coils crackling with faint residual arcs, the bolt gone, arcs thinning",
            "settling: the coils back to dim blue idle arcs, the tower at rest",
        ],
        flash="The lightning bolt and coil flare appear in ONLY the top-right panel. The other three panels have NO bolt, only the dim idle arcs described."),
    "073": dict(
        desc="a World War I Vickers machine gun emplacement: one water-cooled Vickers gun on a tripod behind a low curved sandbag screen, ammunition boxes beside",
        poses=[
            "ready: the one water-cooled barrel pointing level left, the ammunition belt resting in the feed, the sandbag screen unchanged",
            "firing: the Vickers discharging with one compact flash at the barrel tip, the belt advanced one link, the water jacket steaming faintly, sandbags unchanged",
            "recoil: the gun cycled slightly back on the tripod, the belt settled, no flash",
            "settling: the gun back to level left, belt resting, sandbags unchanged, the barrel tip completely cold and dark with no flash and no lingering glow",
        ],
        flash="The muzzle flash appears in ONLY the top-right panel, small, attached at the barrel tip. The other three panels have NO flash, NO spark, NO smoke."),
    "074": dict(
        desc="a World War I Ford Model T field ambulance: one canvas-topped light truck with red-cross side markings, thin front radiator, spoked wheels",
        poses=[
            "cruise: the ambulance rolling level toward the left at a steady pace, wheels mid-turn, canvas unchanged",
            "sprint: the ambulance accelerating hard toward the left edge, wheels blurred with speed, a small dust plume kicking up behind the rear wheels, canvas fluttering",
            "weave: the ambulance swaying through a turn, body leaning slightly, dust trailing, still heading left",
            "settle: the ambulance easing back to a steady pace, dust settling behind, wheels steady",
        ],
        flash="This unit carries no weapon: NO muzzle flash anywhere. The only accents are wheel-speed blur and dust plumes behind the rear wheels in the middle two panels."),
    "075": dict(
        desc="a World War I German stormtrooper in field-grey uniform and stahlhelm, charging with one MP18 submachine gun",
        poses=[
            "ready: the trooper charging left, the one MP18 raised at the hip aimed ahead-left",
            "firing: the MP18 discharging on the move with one compact orange muzzle flash at the barrel tip, the trooper mid-stride, coat tails flying",
            "recoil: the MP18 kicked in the grip, the trooper's stride absorbing it, no flash",
            "settling: the MP18 back to the raised-hip carry, the trooper resuming the charge",
        ],
        flash="The muzzle flash appears in ONLY the top-right panel, small, attached at the barrel tip. The other three panels have NO flash, NO spark, NO smoke."),
    "078": dict(
        desc="a World War II German PaK 40 anti-tank gun: one long-barreled gun on a two-wheel split-trail carriage with a gun shield, dark yellow",
        poses=[
            "ready: the one long barrel pointing level left, the trail legs spread and planted, the gun shield unchanged",
            "firing: the PaK 40 discharging with one large star-shaped flash at the muzzle and dust kicked up around the trails, the carriage rocking back",
            "recoil: the barrel eased back into the cradle, the carriage settled onto its trails, no flash",
            "settling: the barrel back to level left, the carriage at rest",
        ],
        flash="The star-shaped flash appears in ONLY the top-right panel, large, at the muzzle. The other three panels have NO flash, NO spark, NO smoke."),
    "086": dict(
        desc="a modern task-force rifleman in tan multicam and one fast helmet, aiming one M4 carbine with optic and foregrip",
        poses=[
            "ready: the rifleman bladed behind the one M4, aimed level left, foregrip locked",
            "firing: the M4 discharging with one compact orange muzzle flash at the barrel tip, the rifleman braced, stance unchanged",
            "recoil: the carbine kicked into the shoulder, the rifleman absorbing it, no flash",
            "settling: the carbine back to aimed-ready, level left",
        ],
        flash="The muzzle flash appears in ONLY the top-right panel, small, attached at the barrel tip. The other three panels have NO flash, NO spark, NO smoke."),
    "087": dict(
        desc="a Patriot PAC-3 surface-to-air launcher: one rectangular trailer-mounted launcher with four missile tubes angled up-left, a support mast at the rear, tan",
        poses=[
            "ready: the one launcher box angled up-left, all four tube mouths closed, the trailer parked level on its wheels",
            "launch: one missile bursting out of the top tube with bright launch flame and a thick smoke cloud, climbing toward the upper-left edge, the launcher box unchanged",
            "vent: the spent tube mouth open and venting thin smoke, the trailer settled, no missile",
            "settling: the tube mouths closed again, the launcher at rest angled up-left",
        ],
        flash="The missile launch flame and smoke cloud appear in ONLY the top-right panel, one missile climbing up-left. The other three panels have NO missile, NO flame, and only the thin vent smoke in the bottom-left panel."),
    "093": dict(
        desc="a futuristic HEL-30 laser cannon array: one large multi-lens emitter cannon on an autonomous tracked carriage, dark gunmetal with amber stripes and a glowing blue lens core",
        poses=[
            "ready: the one emitter cannon pointing level left, lens core dim, cooling fins still, carriage parked",
            "firing: the HEL-30 discharging one thick bright blue-white laser beam toward the left edge, the lens core flaring white, vents glowing, carriage braced",
            "cooling: the lens core glowing blue afterglow, the beam gone, heat shimmer rising off the barrel, no beam",
            "settling: the lens core back to dim, the emitter level left, carriage at rest",
        ],
        flash="The laser beam and lens flare appear in ONLY the top-right panel. The other three panels have NO beam, NO flare, only the afterglow and heat shimmer described in the bottom-left panel."),
    "094": dict(
        desc="a futuristic nano-repair engineering vehicle: one blue-grey six-wheel chassis with one multi-joint robotic service arm folded at the rear and one glowing translucent nano-fluid tank",
        poses=[
            "ready: the service arm folded at the rear, the nano-tank glowing steady, the truck parked level",
            "deploy: the service arm unfolding and extending toward the left edge, a spray of glowing cyan nano-mist jetting from its tool head, the nano-tank brightening as it pumps",
            "cycle: the arm mid-arc sweeping its nano-mist spray, the tank glow pulsing, wheels grounded",
            "stow: the arm folding back to its rear cradle, the mist gone, the nano-tank glow steady again",
        ],
        flash="This unit carries no weapon: the cyan nano-mist spray from the tool head appears ONLY in the top-right and bottom-left panels. NO muzzle flash, NO sparks anywhere."),
    "095": dict(
        desc="a futuristic X-9 infiltration hunter in matte-black stealth exosuit plating with violet seam glows and a full-face visor, carrying one compact rail carbine",
        poses=[
            "ready: the hunter gliding left in the exosuit, the one rail carbine aimed level left, seams dim",
            "firing: the rail carbine discharging one bright violet bolt toward the left edge with a compact crack-flash at the muzzle, seams flaring, the hunter braced",
            "cooling: the carbine rails glowing violet afterglow, the bolt gone, seams dimming, no bolt",
            "settling: the carbine back to aimed-ready level left, seams dim",
        ],
        flash="The violet bolt and muzzle crack-flash appear in ONLY the top-right panel. The other three panels have NO bolt, NO flash, NO smoke."),
    "110": dict(
        desc="a low hexagonal concrete machine-gun pillbox bunker: one dark embrasure slit, sandbags at the base, a shallow dented dome roof, weathered grey concrete",
        poses=[
            "ready: the one machine gun barrel barely visible inside the embrasure slit pointing left, the bunker silent, sandbags unchanged",
            "firing: one compact orange muzzle flash bursting out of the embrasure slit toward the left edge, the slit lip scorched, the bunker unchanged",
            "recoil: the barrel withdrawn into the slit, thin gunsmoke drifting from the embrasure, no flash",
            "settling: the barrel back at the slit pointing left, the bunker silent, sandbags unchanged",
        ],
        flash="The muzzle flash out of the embrasure appears in ONLY the top-right panel. The other three panels have NO flash, and only thin gunsmoke drifts from the slit in the bottom-left panel."),
    "113": dict(
        desc="a World War II 88mm anti-aircraft gun emplacement: one long-barreled 88 on a cross-shaped platform mount with a splinter shield, barrel elevated toward the upper left, dark grey",
        poses=[
            "ready: the one long barrel elevated toward the upper left, the platform planted, the splinter shield unchanged",
            "firing: the 88 discharging with one large star-shaped flash at the muzzle high up-left, the whole mount rocking on its cross legs, dust kicked at the base",
            "recoil: the barrel slid back in its cradle, the mount settled, no flash",
            "settling: the barrel back elevated toward the upper left, the mount at rest",
        ],
        flash="The star-shaped flash appears in ONLY the top-right panel, large, at the elevated muzzle. The other three panels have NO flash, NO spark, NO smoke."),
    "116": dict(
        desc="a futuristic fortress core: one squat armored dome with layered angled plates and one glowing hexagonal energy gate on the front face, sensor masts on top, gunmetal with cyan glow",
        poses=[
            "ready: the one hexagonal gate dim, the dome silent, sensor masts still",
            "firing: the hexagonal gate flaring open and discharging one bright cyan energy pulse toward the left edge, the whole dome vibrating, masts unchanged",
            "cooling: the gate glowing cyan afterglow, the pulse gone, the dome settled, masts unchanged",
            "settling: the gate back to dim, the dome at rest, masts still",
        ],
        flash="The energy pulse and gate flare appear in ONLY the top-right panel. The other three panels have NO pulse, NO flare, NO smoke."),
    "128": dict(
        desc="an alien war tripod: three tall articulated insect legs, one bulbous hood-shaped body with hanging tentacle cables and a single glowing green heat-ray emitter eye",
        poses=[
            "ready: the tripod striding left on its three legs, the one emitter eye glowing dim green, tentacles swaying",
            "firing: the emitter eye discharging one searing green heat-ray beam toward the left edge, the eye flaring white-green, the hood body flaring with vein light, legs braced",
            "cooling: the eye glowing green afterglow, the beam gone, tentacles recoiling, no beam",
            "settling: the eye back to dim green, the tripod resuming its stride, legs moving",
        ],
        flash="The heat-ray beam and eye flare appear in ONLY the top-right panel. The other three panels have NO beam, NO flare, NO smoke."),
    "146": dict(
        desc="a World War I French Saint-Chamond tank: one long overhanging hull with sloped front glacis, a 75mm gun in the front plate, exposed suspension and a low driver cupola, riveted grey steel",
        poses=[
            "ready: the one 75mm front gun pointing level left, the hull resting on its tracks, cupola unchanged",
            "firing: the 75mm gun discharging with one compact star-shaped flash at the muzzle, the hull rocking on its coil springs, tracks unchanged",
            "recoil: the gun eased back into the glacis, the hull settled, no flash",
            "settling: the gun back to level left, the hull at rest",
        ],
        flash="The star-shaped muzzle flash appears in ONLY the top-right panel, orange-yellow with a white core. The other three panels have NO flash, NO spark, NO smoke."),
    "149": dict(
        desc="a World War II German MG42 machine gun team: one kneeling gunner firing one MG42 toward the left and one loader beside him, both in stahlhelm helmets, feldgrau uniforms",
        poses=[
            "ready: the gunner kneeling behind the one MG42 aimed level left, the loader crouched beside holding one ammunition belt, both helmets unchanged",
            "firing: the MG42 discharging with one compact orange muzzle flash at the barrel tip, the belt feeding, the gunner braced, the loader feeding the belt",
            "recoil: the MG42 bucking slightly into the gunner's shoulder, the belt settled, no flash",
            "settling: the MG42 back to level left, the gunner re-braced, the loader holding the next belt",
        ],
        flash="The muzzle flash appears in ONLY the top-right panel, small, attached at the barrel tip. The other three panels have NO flash, NO spark, NO smoke."),
}

SKELETON = ("STRICTLY a pure 2D SIDE VIEW side-on game sprite (never a front view, never a "
            "three-quarter view), flat orthographic game sprite, single subject only, centered in each panel,\n"
            "{DESC},\n"
            "matte painting style, detailed weathering, "
            "every panel is FULLY COLORED with exactly the same colors as the reference image, "
            "NEVER a black silhouette, NEVER a flat dark shadow shape, "
            "FLAT EVEN MATTE LIGHTING with uniform brightness, the lighting is identical in every panel,\n"
            "the entire background is one perfectly flat uniform bright pure magenta #FF00FF color fill "
            "covering the canvas edge to edge: NO ground, NO floor line, NO shadow under the subject in any panel, "
            "nothing but the subject on flat magenta in every panel,\n"
            "the complete subject in each panel, generous empty margin, "
            "NO text, NO watermark, NO scene background\n")


def prompt2x2(cfg):
    parts = ["%s: the same subject %s, %s;" % (p, pose, INV)
             for p, pose in zip(["top-left", "top-right", "bottom-left", "bottom-right"], cfg["poses"])]
    return SKELETON.replace("{DESC}", cfg["desc"]) + (
        "shown in a regular grid of exactly 4 flat panels, 2 columns and 2 rows, "
        "all 4 panels showing THE SAME subject, identical scale, identical colors and identical rendering in every panel. "
        + " ".join(parts) + " " + cfg["flash"] +
        "Keep the exact 4-panel grid layout, panel positions and spacing of the reference image unchanged, "
        "changing only the subject pose in each panel as listed. "
        "One complete subject centered in each panel, generous empty magenta spacing between panels, "
        "no panel borders, no grid lines, no labels, no numbers.")


def b64(im):
    buf = io.BytesIO()
    im.save(buf, "PNG")
    return base64.b64encode(buf.getvalue()).decode()


def build_template(card_path):
    """2x2 版式底稿：原卡图（品红底）等比缩入 4 格，1024x1024。"""
    card = Image.open(card_path).convert("RGB")
    tpl = Image.new("RGB", (1024, 1024), (255, 0, 255))
    im = card.copy()
    im.thumbnail((440, 440), Image.LANCZOS)
    for cx, cy in ((0, 0), (1, 0), (0, 1), (1, 1)):
        tpl.paste(im, (cx * 512 + (512 - im.width) // 2, cy * 512 + (512 - im.height) // 2))
    return tpl


def call_i2i(refs, prompt, out_path, tries=24):
    body = {"model": MODEL, "prompt": prompt, "image_size": "1024x1024",
            "extra_body": {"image": ["data:image/png;base64," + b for b in refs],
                           "response_format": "url"}}
    auth_fail = set()  # 401 = key 无效：全部 key 都 401 时熔断（防无效 key hammering）
    for att in range(tries):
        key = KEYS[att % len(KEYS)]
        try:
            req = urllib.request.Request(IMG, data=json.dumps(body).encode(),
                                         headers={"Authorization": "Bearer " + key,
                                                  "Content-Type": "application/json"})
            d = json.loads(urllib.request.urlopen(req, timeout=300, context=CTX).read().decode())
            url = (d.get("data") or [{}])[0].get("url", "")
            if url and "/i2i/" in url:
                png = urllib.request.urlopen(
                    urllib.request.Request(url), timeout=180, context=CTX).read()
                open(out_path, "wb").write(png)
                return True, url
            if url:  # t2i 逃逸：当失败重试
                print("    i2i 标志缺失, retry", flush=True)
                time.sleep(5)
                continue
            raise RuntimeError("no url: %s" % json.dumps(d)[:160])
        except urllib.error.HTTPError as e:
            msg = e.read().decode()[:120]
            print("    HTTP %d %s" % (e.code, msg), flush=True)
            if e.code == 403:  # 账号风控限制：立即熔断，绝不重试 hammering
                raise SystemExit(3)
            if e.code == 401:
                auth_fail.add(key)
                if len(auth_fail) >= len(set(KEYS)):
                    print("    all keys invalid (401) - abort", flush=True)
                    raise SystemExit(3)
                time.sleep(6)
                continue
            if e.code == 503:  # 队列满：长退避骑穿队满窗口（45s 起步、封顶 ~3.3 分钟）
                time.sleep(45 + min(att, 24) * 6)
                continue
        except Exception as e:
            print("    err %r" % e, flush=True)
        time.sleep(6)
    return False, None


def gen_single_pose(no):
    """单姿态单图 i2i：每拍一张（参考=卡图本体），出完拼 2×2。
    背景：2.5 模型多格差异化遵循差（039 两轮同姿态、032 束漏 3 格）——
    单图单姿态无跨格混淆，击发焰写进该拍姿态句本身，其余拍天然无焰。"""
    import importlib
    b2 = importlib.import_module("_tmp_api_card_regen_batch2")
    all_units = {u["no"]: u for u in UNITS}
    for u in b2.UNITS2:
        all_units.setdefault(u["no"], u)
    all_cfg = {**UNITS_CFG, **UNITS_CFG2}
    u = all_units[no]
    cfg = all_cfg[no]
    card = os.path.join(RAW, "%s·%s.png" % (u["no"], u["name"]))
    out = os.path.join(RAW, "%s·%s_开火4格.png" % (u["no"], u["name"]))
    if not os.path.exists(card):
        print("[%s·%s] 卡图缺失, skip" % (u["no"], u["name"]), flush=True)
        return
    if os.path.exists(out):  # 用户保留的卷不重做（删掉该文件即重做）
        print("[%s·%s] 开火4格已存在, skip（删除该文件可重做）" % (u["no"], u["name"]),
              flush=True)
        return
    card_im = Image.open(card).convert("RGB")
    pose_dir = os.path.join(RAW, "poses")
    os.makedirs(pose_dir, exist_ok=True)
    beats = ["TL", "TR", "BL", "BR"]
    panels = []
    for i, (beat, pose) in enumerate(zip(beats, cfg["poses"])):
        out = os.path.join(pose_dir, "%s·%s_%s.png" % (u["no"], u["name"], beat))
        if os.path.exists(out):
            panels.append(Image.open(out).convert("RGB"))
            print("  [%s %s] 已有, 复用" % (no, beat), flush=True)
            continue
        prompt = (SKELETON.replace("{DESC}", cfg["desc"])
                  + "Now show THE SAME subject in this exact action beat: %s. " % pose
                  + INV + " Identical scale and colors as the reference image.")
        ok, _ = call_i2i([b64(card_im)], prompt, out)
        print("  [%s·%s %s] %s" % (u["no"], u["name"], beat,
              "OK" if ok else "FAIL"), flush=True)
        if not ok:
            return
        panels.append(Image.open(out).convert("RGB"))
        time.sleep(2)
    grid = Image.new("RGB", (2048, 2048), (255, 0, 255))
    for p, (cx, cy) in zip(panels, ((0, 0), (1, 0), (0, 1), (1, 1))):
        grid.paste(p.resize((1024, 1024), Image.LANCZOS),
                   (cx * 1024, cy * 1024))
    out = os.path.join(RAW, "%s·%s_开火4格.png" % (u["no"], u["name"]))
    grid.save(out)
    print("[%s·%s] 拼合 -> %s" % (u["no"], u["name"], os.path.basename(out)),
          flush=True)


def main(nos=None, single=False):
    import importlib
    b2 = importlib.import_module("_tmp_api_card_regen_batch2")
    all_units = {u["no"]: u for u in UNITS}
    for u in b2.UNITS2:
        all_units.setdefault(u["no"], u)
    all_cfg = {**UNITS_CFG, **UNITS_CFG2}
    targets = sorted(all_units) if nos is None else list(nos)
    if single:
        for no in targets:
            gen_single_pose(no)
        return
    for no in targets:
        if no not in all_units or no not in all_cfg:
            print("[%s] 编号无单位或无配置, skip" % no, flush=True)
            continue
        u = all_units[no]
        cfg = all_cfg[no]
        card = os.path.join(RAW, "%s·%s.png" % (u["no"], u["name"]))
        out = os.path.join(RAW, "%s·%s_开火4格.png" % (u["no"], u["name"]))
        if not os.path.exists(card):
            print("[%s·%s] 卡图缺失, skip" % (u["no"], u["name"]), flush=True)
            continue
        tpl = build_template(card)
        t0 = time.time()
        ok, url = call_i2i([b64(tpl), b64(Image.open(card).convert("RGB"))],
                           prompt2x2(cfg), out)
        print("[%s·%s] %s %.0fs" % (u["no"], u["name"],
              "OK -> " + os.path.basename(out) if ok else "FAIL", time.time() - t0),
              flush=True)
        time.sleep(3)


if __name__ == "__main__":
    nos = set(sys.argv[1].split(",")) if len(sys.argv) > 1 and not sys.argv[1].startswith("-") else None
    single = "--single" in sys.argv
    main(nos, single)
