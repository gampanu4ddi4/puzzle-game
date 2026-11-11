"""거리(지상) 소품 생성 (Blender 백그라운드에서 실행).

사용법:
  blender --background --python tools/blender/street_kit.py -- <출력 폴더>

축 약속(bkit.py): Blender X → Godot X, Blender Z → Godot Y(위), Blender -Y → Godot +Z(앞).
모든 소품은 원점이 바닥 가운데. 따로 적지 않으면 "앞"은 Godot +Z (= Blender -Y).
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from bkit import *  # noqa: E402,F401

# ---------------------------------------------------------------- 재질
M_PLINTH = material("plinth_concrete", "8E8F8A", 0.9)
M_BODY = material("booth_body", "DCDCD4", 0.45, 0.15)
M_ROOF = material("booth_roof", "3C4044", 0.5, 0.3)
M_FRAME = material("frame_alu", "9AA0A2", 0.35, 0.8)
M_DOOR = material("booth_door", "C9CAC2", 0.45, 0.2)
M_FLOOR = material("rubber_floor", "2A2C2E", 0.9)
M_COUNTER = material("counter_top", "B9A98A", 0.55)
M_CAB = material("booth_cab", "8C8C84", 0.6, 0.1)
M_STEEL = material("steel", "C8C8C8", 0.25, 1.0)
M_DARK = material("steel_dark", "3A3E3C", 0.5, 0.6)
M_CORK = material("cork", "A9875A", 0.9)
M_BINDER_R = material("binder_red", "A03A34", 0.6)
M_BINDER_B = material("binder_blue", "2F4F8A", 0.6)
M_BINDER_G = material("binder_gray", "6E7270", 0.6)
M_FABRIC = material("chair_fabric", "2E3540", 0.95)
M_PLASTIC_BLACK = material("plastic_black", "1A1A1A", 0.5)
M_BEIGE = material("beige_plastic", "CFC6AE", 0.55)
M_CRT = material("crt_screen", "15191A", 0.08, 0.0, "203038", 0.15)
M_KEYPAD = material("keypad", "3A3A3A", 0.6)
M_FAN = material("fan_blue", "8FB5C4", 0.5)
M_WHITE_PLASTIC = material("plastic_white", "E8E8E2", 0.5)
M_KIOSK = material("kiosk_red", "B22E28", 0.45, 0.2)
M_KIOSK_HEAD = material("kiosk_white", "E8E8E2", 0.45, 0.1)
M_KIOSK_SCREEN = material("kiosk_screen", "0E1A24", 0.1, 0.0, "3A7AB0", 1.2)
M_YELLOW = material("button_yellow", "E3C23B", 0.4, 0.0, "E3C23B", 0.6)
M_VEND_BODY = material("vend_body", "E6E6E0", 0.4, 0.2)
M_VEND_FRONT = material("vend_front", "FFFFFF", 0.3, 0.0, "FFFFFF", 1.0)
M_VEND_LOGO = material("vend_logo", "C8473F", 0.4, 0.0, "FF5A4A", 2.0)
M_ORANGE = material("pole_orange", "E0561E", 0.5, 0.1)
M_MIRROR = material("mirror", "D8DCDE", 0.03, 1.0)
M_BOLLARD = material("bollard_steel", "3A3E3C", 0.45, 0.6)
M_REFLECT = material("reflect_yellow", "E3C23B", 0.35)
M_POLE = material("pole_concrete", "8E8F8A", 0.85)
M_INSUL = material("insulator", "E6E6E0", 0.25)
M_TRANS = material("transformer", "7E8482", 0.5, 0.4)
M_LAMP_HEAD = material("lamp_head", "2E3230", 0.5, 0.5)
M_SODIUM = material("lamp_lens", "FFD9A0", 0.3, 0.0, "FFB05A", 6.0)
M_LIGHT_RED = material("lamp_red", "3A0A08", 0.2)
M_LIGHT_AMBER = material("lamp_amber", "3A2A08", 0.2)
M_LIGHT_GREEN = material("lamp_green", "082A12", 0.2)
M_SIGN_RED = material("sign_red", "C8302A", 0.5)
M_SIGN_BLUE = material("sign_blue", "1F4FA0", 0.5)
M_SIGN_WHITE = material("sign_white", "EDEDED", 0.5)
M_BIN_GREEN = material("bin_green", "3A7A4A", 0.55, 0.1)
M_BIN_BLUE = material("bin_blue", "2F5FA0", 0.55, 0.1)
M_HOLE = material("hole_dark", "0A0A0A", 0.9)
M_BUMP_Y = material("bump_yellow", "E3C23B", 0.6)
M_BUMP_K = material("bump_black", "1C1C1C", 0.7)
M_AC = material("ac_body", "E8E6DF", 0.5, 0.1)
M_SIGNBOX = material("sign_box", "2A2D30", 0.5, 0.3)
M_SIGNFACE = material("sign_face", "E8E8E2", 0.4)


# ---------------------------------------------------------------- 정산소 부스
def booth():
    """정산소: 1.8(x) x 2.2(깊이) x 2.5 m. 창문은 -X 쪽(차로 쪽), 문은 Godot -Z 쪽(거리 쪽).
    창문 구멍: -X 면, 높이 1.0~2.0, 폭(깊이 방향) -0.75~0.75. 유리는 Godot에서 붙인다(미닫이)."""
    p = []
    p.append(bevel(cube("plinth", (1.95, 2.35, 0.15), (0, 0, 0.075), M_PLINTH), 0.02))
    z0, z1 = 0.15, 2.45
    hh = z1 - z0
    # 뒤(+X)
    p.append(bevel(cube("back", (0.06, 2.2, hh), (0.87, 0, z0 + hh / 2), M_BODY), 0.01))
    # 옆(-Y, Godot +Z 쪽: 건물 쪽): 막힌 벽
    p.append(bevel(cube("side_a", (1.8, 0.06, hh), (0, -1.07, z0 + hh / 2), M_BODY), 0.01))
    # 옆(+Y, Godot -Z 쪽: 거리 쪽): 문
    p.append(bevel(cube("side_b1", (0.75, 0.06, hh), (-0.525, 1.07, z0 + hh / 2), M_BODY), 0.01))
    p.append(bevel(cube("side_b2", (0.25, 0.06, hh), (0.775, 1.07, z0 + hh / 2), M_BODY), 0.01))
    p.append(bevel(cube("side_b3", (0.85, 0.06, 0.3), (0.225, 1.07, z1 - 0.15), M_BODY), 0.01))
    p.append(bevel(cube("door", (0.8, 0.04, 2.0), (0.225, 1.075, z0 + 1.0), M_DOOR), 0.008))
    p.append(cube("door_glass", (0.5, 0.012, 0.6), (0.225, 1.1, z0 + 1.45), M_CRT))
    p.append(bevel(cube("door_handle", (0.12, 0.04, 0.03), (-0.08, 1.12, z0 + 1.0), M_STEEL), 0.006))
    # 앞(-X): 창문 아래·위, 창문 양옆 기둥
    p.append(bevel(cube("front_low", (0.06, 2.2, 0.85), (-0.87, 0, z0 + 0.425), M_BODY), 0.01))
    p.append(bevel(cube("front_top", (0.06, 2.2, 0.45), (-0.87, 0, z1 - 0.225), M_BODY), 0.01))
    p.append(bevel(cube("front_post_a", (0.06, 0.35, 1.0), (-0.87, -0.925, 1.5), M_BODY), 0.01))
    p.append(bevel(cube("front_post_b", (0.06, 0.35, 1.0), (-0.87, 0.925, 1.5), M_BODY), 0.01))
    # 알루미늄 창틀
    for (sx, sy, sz, loc) in ((0.07, 1.6, 0.05, (-0.9, 0, 1.0)), (0.07, 1.6, 0.05, (-0.9, 0, 2.0)),
                              (0.07, 0.05, 1.05, (-0.9, -0.775, 1.5)), (0.07, 0.05, 1.05, (-0.9, 0.775, 1.5))):
        p.append(bevel(cube("frame", (sx, sy, sz), loc, M_FRAME), 0.008))
    # 돈 주고받는 스테인리스 받침
    p.append(bevel(cube("pass_tray", (0.28, 0.42, 0.03), (-0.95, 0.2, 1.0), M_STEEL), 0.006))
    # 지붕: 처마 + 띠
    p.append(bevel(cube("roof", (2.3, 2.7, 0.1), (0, 0, z1 + 0.05), M_ROOF), 0.015))
    p.append(bevel(cube("fascia", (2.32, 2.72, 0.22), (0, 0, z1 - 0.06), M_BODY), 0.01))
    # 안: 바닥, 계산대, 선반, 게시판
    p.append(cube("floor", (1.7, 2.1, 0.02), (0, 0, z0 + 0.01), M_FLOOR))
    p.append(bevel(cube("counter", (0.5, 2.05, 0.04), (-0.6, 0, 0.98), M_COUNTER), 0.005))
    p.append(bevel(cube("cabinet", (0.04, 1.6, 0.8), (-0.37, -0.1, 0.56), M_CAB), 0.005))
    p.append(bevel(cube("shelf", (0.26, 1.3, 0.03), (0.72, -0.2, 1.75), M_CAB), 0.005))
    for i, m in enumerate((M_BINDER_R, M_BINDER_B, M_BINDER_G, M_BINDER_B, M_BINDER_R, M_BINDER_G)):
        p.append(bevel(cube("binder", (0.22, 0.06, 0.3), (0.72, -0.75 + 0.08 * i, 1.92), m), 0.004))
    p.append(cube("cork", (0.02, 0.6, 0.45), (0.83, 0.45, 1.55), M_CORK))
    # 천장 형광등 기구
    p.append(bevel(cube("ceiling_lamp", (0.6, 0.12, 0.05), (0, 0, z1 - 0.06), M_WHITE_PLASTIC), 0.01))
    join(p, "booth")
    export("booth")


def office_chair():
    p = []
    for i in range(5):
        a = i * 2 * math.pi / 5
        leg = cube("leg", (0.3, 0.05, 0.035), (0.15 * math.cos(a), 0.15 * math.sin(a), 0.07), M_PLASTIC_BLACK, (0, 0, a))
        p.append(bevel(leg, 0.01))
        p.append(cyl("caster", 0.025, 0.03, (0.29 * math.cos(a), 0.29 * math.sin(a), 0.03), (math.pi / 2, 0, a), 10, M_PLASTIC_BLACK))
    p.append(cyl("column", 0.025, 0.32, (0, 0, 0.25), mat=M_STEEL))
    p.append(bevel(cube("seat", (0.46, 0.44, 0.08), (0, 0, 0.45), M_FABRIC), 0.03, 3))
    p.append(bevel(cube("back", (0.42, 0.06, 0.48), (0, 0.24, 0.78), M_FABRIC), 0.03, 3))
    p.append(cube("back_bar", (0.05, 0.04, 0.3), (0, 0.24, 0.5), M_PLASTIC_BLACK))
    join(p, "office_chair")
    export("office_chair")


def crt_monitor():
    """14인치 CRT 모니터. 화면이 Godot +Z 쪽."""
    p = []
    p.append(bevel(cube("bezel", (0.36, 0.06, 0.33), (0, -0.15, 0.2), M_BEIGE), 0.015))
    back = cube("tube", (0.3, 0.26, 0.27), (0, 0.0, 0.19), M_BEIGE)
    for v in back.data.vertices:   # 뒤로 갈수록 좁아진다
        if v.co.y > 0:
            v.co.x *= 0.7
            v.co.z = 0.19 + (v.co.z - 0.19) * 0.75
    p.append(bevel(back, 0.012))
    p.append(cube("screen", (0.28, 0.01, 0.22), (0, -0.183, 0.21), M_CRT))
    p.append(bevel(cube("stand", (0.22, 0.2, 0.04), (0, -0.05, 0.02), M_BEIGE), 0.01))
    p.append(cube("button", (0.02, 0.01, 0.01), (0.14, -0.185, 0.06), M_KEYPAD))
    join(p, "crt_monitor")
    export("crt_monitor")


def desk_phone():
    p = []
    base = cube("base", (0.2, 0.22, 0.06), (0, 0, 0.03), M_BEIGE)
    for v in base.data.vertices:
        if v.co.y < 0 and v.co.z > 0.03:
            v.co.z -= 0.025
    p.append(bevel(base, 0.01))
    p.append(cube("keys", (0.09, 0.09, 0.005), (0.035, -0.04, 0.045), M_KEYPAD))
    p.append(bevel(cube("handset", (0.05, 0.2, 0.035), (-0.06, 0.0, 0.075), M_BEIGE), 0.012))
    join(p, "desk_phone")
    export("desk_phone")


def desk_fan():
    p = []
    p.append(cyl("base", 0.11, 0.03, (0, 0, 0.015), mat=M_FAN))
    p.append(cyl("pole", 0.015, 0.26, (0, 0, 0.16), mat=M_WHITE_PLASTIC))
    p.append(cyl("motor", 0.05, 0.1, (0, 0.03, 0.32), (math.pi / 2, 0, 0), 16, M_FAN))
    p.append(torus("cage", 0.15, 0.006, (0, -0.04, 0.32), (math.pi / 2, 0, 0), M_WHITE_PLASTIC))
    p.append(torus("cage2", 0.07, 0.005, (0, -0.06, 0.32), (math.pi / 2, 0, 0), M_WHITE_PLASTIC))
    for i in range(3):
        a = i * 2 * math.pi / 3
        blade = cube("blade", (0.05, 0.005, 0.12), (0.06 * math.sin(a), -0.03, 0.32 + 0.06 * math.cos(a)), M_FAN, (0, a, 0))
        p.append(blade)
    join(p, "desk_fan")
    export("desk_fan")


def ticket_machine():
    """주차권 발권기. 앞(버튼, 화면)이 Godot -X 쪽(차로 쪽)."""
    p = []
    p.append(bevel(cube("base", (0.5, 0.5, 0.06), (0, 0, 0.03), M_DARK), 0.01))
    p.append(bevel(cube("body", (0.42, 0.4, 1.05), (0, 0, 0.58), M_KIOSK), 0.02, 3))
    head = cube("head", (0.5, 0.46, 0.5), (0, 0, 1.33), M_KIOSK_HEAD)
    for v in head.data.vertices:   # 앞면을 비스듬히
        if v.co.x < 0 and v.co.z > 1.33:
            v.co.x += 0.1
    p.append(bevel(head, 0.02, 3))
    p.append(cube("screen", (0.01, 0.22, 0.14), (-0.215, 0, 1.45), M_KIOSK_SCREEN, (0, -0.2, 0)))
    p.append(cyl("button", 0.05, 0.03, (-0.255, 0, 1.22), (0, math.pi / 2, 0), 20, M_YELLOW))
    p.append(cube("slot", (0.02, 0.12, 0.012), (-0.255, 0, 1.12), M_HOLE))
    p.append(bevel(cube("cap", (0.56, 0.52, 0.04), (0, 0, 1.6), M_DARK), 0.01))
    join(p, "ticket_machine")
    export("ticket_machine")


def vending_machine():
    """음료 자판기 1.0 x 0.8 x 1.85 m. 앞(진열창)이 Godot +Z."""
    p = []
    p.append(bevel(cube("body", (1.0, 0.8, 1.83), (0, 0, 0.915), M_VEND_BODY), 0.02, 3))
    p.append(cube("front", (0.88, 0.01, 1.62), (0, -0.405, 0.93), M_VEND_FRONT))
    p.append(cube("logo", (0.9, 0.01, 0.12), (0, -0.406, 1.78), M_VEND_LOGO))
    p.append(bevel(cube("plinth", (0.98, 0.7, 0.06), (0, 0.04, 0.03), M_DARK), 0.01))
    join(p, "vending_machine")
    export("vending_machine")


def convex_mirror():
    """도로반사경: 주황 기둥 3 m 위에 둥근 볼록거울. 거울이 Godot +Z 쪽."""
    p = []
    p.append(cyl("pole", 0.04, 3.0, (0, 0, 1.5), mat=M_ORANGE))
    p.append(cyl("plate", 0.42, 0.04, (0, 0.03, 3.1), (math.pi / 2, 0, 0), 32, M_ORANGE))
    bpy.ops.mesh.primitive_uv_sphere_add(radius=0.4, location=(0, -0.0, 3.1), segments=32, ring_count=16)
    m = active()
    m.name = "mirror"
    m.scale = (1.0, 0.18, 1.0)
    bpy.ops.object.transform_apply(scale=True)
    m.data.materials.append(M_MIRROR)
    smooth(m)
    p.append(m)
    p.append(torus("rim", 0.41, 0.025, (0, -0.01, 3.1), (math.pi / 2, 0, 0), M_ORANGE))
    p.append(bevel(cube("visor", (0.6, 0.12, 0.03), (0, -0.05, 3.53), M_ORANGE), 0.01))
    join(p, "convex_mirror")
    export("convex_mirror")


def bollard():
    p = []
    p.append(cyl("post", 0.07, 0.82, (0, 0, 0.41), mat=M_BOLLARD))
    bpy.ops.mesh.primitive_uv_sphere_add(radius=0.07, location=(0, 0, 0.82), segments=16, ring_count=8)
    top = active()
    top.data.materials.append(M_BOLLARD)
    smooth(top)
    p.append(top)
    p.append(cyl("band", 0.073, 0.07, (0, 0, 0.68), mat=M_REFLECT))
    p.append(torus("ring", 0.075, 0.012, (0, 0, 0.6), mat=M_STEEL, seg=16))
    join(p, "bollard")
    export("bollard")


def utility_pole():
    """콘크리트 전봇대 11 m. 완목은 Godot Z 방향(도로와 직각)이 아니라 도로 방향(X)으로 전선을 받는다:
    전선 고정점 = (0, 9.85, ±1.0)과 (0, 9.25, ±0.9) (Godot 좌표)."""
    p = []
    p.append(cone("pole", 0.2, 0.13, 11.0, (0, 0, 5.5), verts=20, mat=M_POLE))
    for z, w in ((9.85, 2.2), (9.25, 1.9)):
        p.append(bevel(cube("arm", (0.1, w, 0.1), (0, 0, z), M_DARK), 0.01))
        for sy in (-1, 1):
            for k in range(2):
                y = sy * (w / 2 - 0.1 - 0.35 * k)
                p.append(cyl("insul", 0.035, 0.12, (0, y, z + 0.11), verts=10, mat=M_INSUL))
    p.append(cyl("transformer", 0.32, 1.1, (0.45, 0, 7.6), verts=20, mat=M_TRANS))
    p.append(cyl("tr_cap", 0.34, 0.06, (0.45, 0, 8.18), verts=20, mat=M_DARK))
    p.append(cube("tr_bracket", (0.3, 0.1, 0.1), (0.2, 0, 7.9), M_DARK))
    for i in range(12):
        z = 2.6 + 0.45 * i
        a = (i % 2) * math.pi
        p.append(cyl("step", 0.015, 0.3, (0.18 * math.cos(a), 0.18 * math.sin(a), z), (0, math.pi / 2, a), 6, M_DARK))
    p.append(cube("tag", (0.22, 0.01, 0.3), (0, -0.19, 2.0), M_SIGN_WHITE))
    join(p, "utility_pole")
    export("utility_pole")


def street_lamp():
    """가로등 8 m. 팔이 Godot +Z 쪽(도로 쪽)으로 굽어 나간다. 등은 (0, 8.55, 2.0) 근처."""
    p = []
    p.append(cone("pole", 0.1, 0.07, 8.0, (0, 0, 4.0), verts=16, mat=M_DARK))
    p.append(cyl("flange", 0.18, 0.06, (0, 0, 0.03), verts=16, mat=M_DARK))
    pts = [(0, 0, 7.9)]
    for i in range(1, 9):
        t = i / 8
        pts.append((0, -2.0 * t, 7.9 + 0.7 * math.sin(t * math.pi * 0.5)))
    p += tube("arm", pts, 0.045, M_DARK, 8)
    p.append(bevel(cube("head", (0.32, 0.7, 0.12), (0, -2.15, 8.6), M_LAMP_HEAD), 0.02))
    p.append(cube("lens", (0.26, 0.58, 0.02), (0, -2.15, 8.53), M_SODIUM))
    join(p, "street_lamp")
    export("street_lamp")


def traffic_light():
    """신호등: 기둥 6 m, 팔은 Godot +Z 쪽으로 3.2 m. 가로형 등 상자가 Godot -X 쪽을 본다."""
    p = []
    p.append(cyl("pole", 0.1, 6.0, (0, 0, 3.0), verts=16, mat=M_DARK))
    p.append(cyl("arm", 0.06, 3.3, (0, -1.65, 5.8), (math.pi / 2, 0, 0), 12, M_DARK))
    p.append(bevel(cube("box", (0.3, 1.05, 0.36), (0, -3.2, 5.55), M_PLASTIC_BLACK), 0.02))
    for i, m in enumerate((M_LIGHT_RED, M_LIGHT_AMBER, M_LIGHT_GREEN)):
        y = -3.2 + (i - 1) * 0.33
        p.append(cyl("lamp", 0.12, 0.02, (-0.16, y, 5.55), (0, math.pi / 2, 0), 20, m))
        p.append(cube("visor", (0.18, 0.28, 0.02), (-0.24, y, 5.7), M_PLASTIC_BLACK))
    join(p, "traffic_light")
    export("traffic_light")


def no_parking_sign():
    """주정차금지 표지판 (파란 원, 빨간 테와 X). 앞이 Godot +Z. 아래 흰 보조판에 글씨는 Godot에서."""
    p = []
    p.append(cyl("pole", 0.035, 2.7, (0, 0, 1.35), verts=12, mat=M_STEEL))
    p.append(cyl("red", 0.3, 0.02, (0, -0.04, 2.45), (math.pi / 2, 0, 0), 32, M_SIGN_RED))
    p.append(cyl("blue", 0.25, 0.02, (0, -0.05, 2.45), (math.pi / 2, 0, 0), 32, M_SIGN_BLUE))
    for a in (math.pi / 4, -math.pi / 4):
        p.append(cube("x", (0.46, 0.012, 0.06), (0, -0.062, 2.45), M_SIGN_RED, (0, a, 0)))
    p.append(cube("plate", (0.5, 0.015, 0.17), (0, -0.04, 2.02), M_SIGN_WHITE))
    join(p, "no_parking_sign")
    export("no_parking_sign")


def trash_bins():
    """일반쓰레기(초록), 재활용(파랑) 통 두 개. 앞이 Godot +Z."""
    p = []
    for x, m in ((-0.26, M_BIN_GREEN), (0.26, M_BIN_BLUE)):
        p.append(bevel(cube("bin", (0.46, 0.46, 0.9), (x, 0, 0.45), m), 0.03, 3))
        p.append(bevel(cube("lid", (0.48, 0.48, 0.05), (x, 0, 0.92), m), 0.02))
        p.append(cyl("hole", 0.1, 0.02, (x, -0.235, 0.7), (math.pi / 2, 0, 0), 20, M_HOLE))
    join(p, "trash_bins")
    export("trash_bins")


def speed_bump():
    """과속방지턱 6.6 m (X 방향). 노랑·검정 고무 조각."""
    p = []
    for i in range(12):
        x = -3.3 + 0.275 + 0.55 * i
        c = cyl("seg", 0.3, 0.54, (x, 0, 0), (0, math.pi / 2, 0), 24, M_BUMP_Y if i % 2 == 0 else M_BUMP_K)
        c.scale = (1.0, 0.6, 0.2)
        bpy.ops.object.transform_apply(scale=True)
        p.append(c)
    join(p, "speed_bump")
    export("speed_bump")


def ac_unit():
    """에어컨 실외기. 팬이 Godot +Z 쪽."""
    p = []
    p.append(bevel(cube("body", (0.8, 0.3, 0.6), (0, 0, 0.3), M_AC), 0.015))
    p.append(cyl("fan", 0.22, 0.02, (-0.1, -0.15, 0.3), (math.pi / 2, 0, 0), 24, M_HOLE))
    for r in (0.21, 0.15, 0.09):
        p.append(torus("grill", r, 0.004, (-0.1, -0.16, 0.3), (math.pi / 2, 0, 0), M_DARK, 24))
    p.append(cube("vent", (0.18, 0.01, 0.4), (0.27, -0.152, 0.3), M_DARK))
    join(p, "ac_unit")
    export("ac_unit")


def sign_box():
    """상가 간판 틀 6.2 x 0.9 m (앞판 재질 sign_face는 Godot에서 켜고 끈다). 앞이 Godot +Z."""
    p = []
    p.append(bevel(cube("box", (6.2, 0.25, 0.9), (0, 0, 0.45), M_SIGNBOX), 0.02))
    p.append(cube("face", (6.0, 0.01, 0.75), (0, -0.13, 0.45), M_SIGNFACE))
    join(p, "sign_box")
    export("sign_box")


clear()
for build in (booth, office_chair, crt_monitor, desk_phone, desk_fan, ticket_machine, vending_machine,
              convex_mirror, bollard, utility_pole, street_lamp, traffic_light, no_parking_sign,
              trash_bins, speed_bump, ac_unit, sign_box):
    build()
print("STREET KIT DONE")
