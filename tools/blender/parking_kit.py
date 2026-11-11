"""주차장 모듈 부품 생성 (Blender 백그라운드에서 실행).

사용법:
  blender --background --python tools/blender/parking_kit.py -- <출력 폴더>

부품마다 .glb 파일 하나를 만든다. 축 약속:
  Blender X → Godot X,  Blender Z(위) → Godot Y(위),  Blender -Y → Godot +Z
재질 이름은 Godot 쪽(parking_builder.gd)에서 셰이더 재질로 바꿔 끼우는 열쇠로 쓴다.
콘크리트 계열은 UV 없이 월드 좌표로 텍스처를 입히므로(삼면 투영) UV를 신경 쓰지 않는다.
"""
import math
import os
import sys

import bpy

OUT = os.path.abspath(sys.argv[sys.argv.index("--") + 1])
os.makedirs(OUT, exist_ok=True)


def lin(hexstr):
    """sRGB 16진수 → 선형 색 (Blender와 glTF는 선형 색을 쓴다)."""
    out = []
    for i in (0, 2, 4):
        c = int(hexstr[i:i + 2], 16) / 255.0
        out.append(c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4)
    return (*out, 1.0)


def material(name, color="808080", rough=0.8, metal=0.0, emit=None, emit_strength=0.0):
    m = bpy.data.materials.get(name)
    if m:
        return m
    m = bpy.data.materials.new(name)
    try:
        m.use_nodes = True
    except Exception:
        pass
    nt = m.node_tree
    bsdf = next((nd for nd in nt.nodes if nd.type == "BSDF_PRINCIPLED"), None)
    if bsdf is None:
        nt.nodes.clear()
        bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
        out = nt.nodes.new("ShaderNodeOutputMaterial")
        nt.links.new(bsdf.outputs[0], out.inputs[0])
    bsdf.inputs["Base Color"].default_value = lin(color)
    bsdf.inputs["Roughness"].default_value = rough
    bsdf.inputs["Metallic"].default_value = metal
    if emit:
        bsdf.inputs["Emission Color"].default_value = lin(emit)
        bsdf.inputs["Emission Strength"].default_value = emit_strength
    return m


def clear():
    for o in list(bpy.data.objects):
        bpy.data.objects.remove(o, do_unlink=True)
    for me in list(bpy.data.meshes):
        bpy.data.meshes.remove(me)


def active():
    return bpy.context.view_layer.objects.active


def cube(name, size, loc=(0, 0, 0), mat=None):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc)
    o = active()
    o.name = name
    o.scale = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if mat:
        o.data.materials.append(mat)
    return o


def cyl(name, r, depth, loc=(0, 0, 0), rot=(0, 0, 0), verts=24, mat=None):
    bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=r, depth=depth, location=loc, rotation=rot)
    o = active()
    o.name = name
    if mat:
        o.data.materials.append(mat)
    smooth(o)
    return o


def cone(name, r1, r2, depth, loc=(0, 0, 0), verts=32, mat=None):
    bpy.ops.mesh.primitive_cone_add(vertices=verts, radius1=r1, radius2=r2, depth=depth, location=loc)
    o = active()
    o.name = name
    if mat:
        o.data.materials.append(mat)
    smooth(o)
    return o


def smooth(o):
    for p in o.data.polygons:
        p.use_smooth = True


def bevel(o, width, segments=2):
    """모서리를 살짝 깎는다. 빛을 받아 얇게 반짝이는 모서리가 실사 느낌의 핵심."""
    mod = o.modifiers.new("Bevel", "BEVEL")
    mod.width = width
    mod.segments = segments
    mod.limit_method = "ANGLE"
    mod.harden_normals = True
    smooth(o)
    return o


def shear_z_by_x(o, slope):
    """월드 X 위치에 비례해 위로 올린다 (오브젝트 원점이 아니라 월드 기준)."""
    ox = o.location.x
    for v in o.data.vertices:
        v.co.z += (v.co.x + ox) * slope


def join(objs, name):
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    # 조인하기 전에 모디파이어를 적용해 둔다
    for o in objs:
        bpy.context.view_layer.objects.active = o
        for mod in list(o.modifiers):
            bpy.ops.object.modifier_apply(modifier=mod.name)
    bpy.context.view_layer.objects.active = objs[0]
    for o in objs:
        o.select_set(True)
    bpy.ops.object.join()
    o = active()
    o.name = name
    return o


def export(name):
    bpy.ops.object.select_all(action="SELECT")
    path = os.path.join(OUT, name + ".glb")
    bpy.ops.export_scene.gltf(
        filepath=path,
        export_format="GLB",
        use_selection=True,
        export_apply=True,
        export_yup=True,
    )
    print("exported", path)
    clear()


# ---------------------------------------------------------------- 재질 (이름이 Godot 쪽 열쇠)

M_PAINT = material("concrete_paint", "E4E3DC")        # 칠한 벽·기둥 → Godot에서 셰이더로 교체
M_CEIL = material("concrete_ceiling", "9C9E9A")       # 천장·보 → 셰이더로 교체
M_RAMP = material("ramp_floor", "8A8D88")             # 경사로 바닥 → 셰이더로 교체
M_PAINT_WHITE = material("paint_white", "E8E8E2")     # 바닥 화살표 → 셰이더로 교체
M_WHEELSTOP = material("wheelstop_yellow", "D9B12E", 0.7)
M_RUBBER = material("rubber_black", "1A1A1A", 0.9)
M_FIX_METAL = material("fixture_metal", "D8D8D2", 0.45, 0.2)
M_TUBE = material("tube", "F2F7F0", 0.3, 0.0, "DCEBD8", 4.0)   # 형광관 → 켜짐/꺼짐을 Godot에서 교체
M_PIPE_GRAY = material("pipe_gray", "7C807E", 0.55, 0.3)
M_PIPE_RED = material("pipe_red", "A3302A", 0.5, 0.1)
M_BRASS = material("sprinkler_brass", "B08A45", 0.35, 0.9)
M_CAB_RED = material("cabinet_red", "B22E28", 0.45, 0.2)
M_GLASS = material("glass_dark", "1E2422", 0.08, 0.0)
M_DOOR = material("door_gray", "8E938F", 0.55, 0.4)
M_DOOR_FRAME = material("door_frame", "5F6461", 0.5, 0.5)
M_HANDLE = material("handle_steel", "C8C8C8", 0.25, 1.0)
M_EXIT = material("exit_green", "2FB46A", 0.4, 0.0, "3BD07A", 3.0)
M_EXIT_BOX = material("exit_box", "E8E8E2", 0.5)
M_CONE = material("cone_orange", "E0561E", 0.55)
M_REFLECT = material("reflect_white", "EDEDED", 0.4)
M_CUP = material("cup_paper", "EDE9E0", 0.75)
M_SLEEVE = material("cup_sleeve", "8A6440", 0.85)
M_LID = material("cup_lid", "232323", 0.4)
M_SIGN = material("sign_green", "1F6B47", 0.5, 0.0, "1F6B47", 0.6)
M_SHUTTER = material("shutter_metal", "A7ABA6", 0.45, 0.6)
M_SHUTTER_DARK = material("shutter_dark", "4E524F", 0.5, 0.6)
M_HAZARD = material("hazard_yellow", "D9B12E", 0.6)
M_HWALL = material("helix_wall", "E4E3DC")      # 나선 벽 위쪽 (띠 없음) → 셰이더로 교체
M_HBAND = material("helix_band", "4E7A5B")      # 나선 벽 아래 초록 띠 → 셰이더로 교체
M_HLINE = material("helix_line", "E3C23B")      # 띠 위 노란 선 → 셰이더로 교체


# ---------------------------------------------------------------- 부품

def pillar():
    """기둥 0.6 x 0.6 x 2.7 m. 원점은 바닥 가운데."""
    o = cube("pillar", (0.6, 0.6, 2.7), (0, 0, 1.35), M_PAINT)
    bevel(o, 0.025, 3)
    # 바닥 쪽 고무 모서리 보호대 4개
    guards = []
    for sx in (-1, 1):
        for sy in (-1, 1):
            g = cube("guard", (0.09, 0.09, 1.0), (sx * 0.27, sy * 0.27, 0.5), M_RUBBER)
            bevel(g, 0.02, 2)
            guards.append(g)
    join([o] + guards, "pillar")
    export("pillar")


def beam():
    """보 8 x 0.4 x 0.45 m. 원점은 윗면 가운데 (천장에 붙인다)."""
    o = cube("beam", (8.0, 0.4, 0.45), (0, 0, -0.225), M_CEIL)
    bevel(o, 0.02, 2)
    export("beam")


def wheel_stop():
    """주차 턱 1.6 x 0.15 x 0.11 m. 원점은 바닥 가운데."""
    o = cube("wheel_stop", (1.6, 0.15, 0.11), (0, 0, 0.055), M_WHEELSTOP)
    bevel(o, 0.035, 3)
    export("wheel_stop")


def fixture():
    """형광등 기구. 원점은 윗면(천장에 매다는 곳), 아래로 매달림. 길이 방향은 X."""
    house = cube("housing", (1.26, 0.17, 0.06), (0, 0, -0.03), M_FIX_METAL)
    bevel(house, 0.012, 2)
    rods = [cyl("rod", 0.006, 0.08, (sx * 0.5, 0, 0.0), verts=8, mat=M_FIX_METAL) for sx in (-1, 1)]
    tubes = []
    for sy in (-0.042, 0.042):
        tubes.append(cyl("tube", 0.014, 1.2, (0, sy, -0.075), rot=(0, math.pi / 2, 0), verts=16, mat=M_TUBE))
    join([house] + rods + tubes, "fixture")
    export("fixture")


def pipe_gray():
    """굵은 배관 8 m, 양 끝에 이음 링. 원점은 가운데."""
    p = cyl("pipe", 0.075, 8.0, rot=(0, math.pi / 2, 0), verts=24, mat=M_PIPE_GRAY)
    rings = [cyl("ring", 0.095, 0.05, (sx * 3.9, 0, 0), rot=(0, math.pi / 2, 0), verts=24, mat=M_PIPE_GRAY) for sx in (-1, 1)]
    hangers = [cube("hanger", (0.03, 0.03, 0.5), (sx * 2.0, 0, 0.3), M_PIPE_GRAY) for sx in (-1, 1)]
    join([p] + rings + hangers, "pipe_gray")
    export("pipe_gray")


def pipe_sprinkler():
    """빨간 스프링클러 배관 8 m, 2 m마다 스프링클러 헤드. 원점은 가운데."""
    p = cyl("pipe", 0.035, 8.0, rot=(0, math.pi / 2, 0), verts=16, mat=M_PIPE_RED)
    parts = [p]
    for x in (-3.0, -1.0, 1.0, 3.0):
        parts.append(cyl("drop", 0.012, 0.12, (x, 0, -0.06), verts=10, mat=M_PIPE_RED))
        parts.append(cyl("head", 0.012, 0.035, (x, 0, -0.135), verts=10, mat=M_BRASS))
        parts.append(cyl("deflector", 0.028, 0.004, (x, 0, -0.155), verts=16, mat=M_BRASS))
    join(parts, "pipe_sprinkler")
    export("pipe_sprinkler")


def ramp_tunnel():
    """위로 올라가는 경사로 터널. 길이 24 m(X), 안쪽 폭 6 m, 높이 차 3 m.
    원점은 아래쪽 끝 바닥 가운데. 양 끝이 열려 있어서 위아래 층을 잇는다
    (한 층의 동쪽 터널 = 위층의 서쪽 입구). 막아야 하면 Godot에서 막는다."""
    slope = 3.0 / 24.0
    floor_ = cube("floor", (24.0, 6.6, 0.3), (12.0, 0, -0.15), M_RAMP)
    ceil = cube("ceil", (24.0, 6.6, 0.3), (12.0, 0, 2.85), M_CEIL)
    wl = cube("wall_l", (24.0, 0.3, 2.7), (12.0, 3.15, 1.35), M_PAINT)
    wr = cube("wall_r", (24.0, 0.3, 2.7), (12.0, -3.15, 1.35), M_PAINT)
    for o in (floor_, ceil, wl, wr):
        shear_z_by_x(o, slope)
    # 바닥 가장자리 연석
    curbs = []
    for sy in (-1, 1):
        c = cube("curb", (24.0, 0.25, 0.15), (12.0, sy * 2.875, 0.075), M_WHEELSTOP)
        shear_z_by_x(c, slope)
        curbs.append(c)
    join([floor_, ceil, wl, wr] + curbs, "ramp_tunnel")
    export("ramp_tunnel")


# ---------------------------------------------------------------- 나선 경사로
# 값은 levels/ch1_parking/helix_geo.gd와 같아야 한다.
HX_R = 9.0          # 차로 중심선 반지름 (안쪽 벽 6 m, 바깥 벽 12 m)
HX_TURN = 1.5 * math.pi   # 270도
HX_RISE = 3.0
HX_STUB = 13.0      # 아래 진입로 길이
HX_HALF = 3.0       # 차로 반폭


def _arc(cx, cz, r, a0, a1, y0, y1, n):
    """원호 중심선. 각도 a에서 점 = (cx + r sin a, cz - r cos a), 진행 방향 (cos a, sin a), 바깥쪽 (sin a, -cos a)."""
    pts = []
    for i in range(n + 1):
        t = i / n
        a = a0 + (a1 - a0) * t
        pts.append((cx + r * math.sin(a), y0 + (y1 - y0) * t, cz - r * math.cos(a), math.sin(a), -math.cos(a)))
    return pts


def _arc_right(cx, cz, r, t0, t1, y, n, out_sign):
    """출구용 원호 (오른쪽으로 꺾임). 점 = (cx - r cos t, cz - r sin t). out_sign: 바깥쪽 법선 방향."""
    pts = []
    for i in range(n + 1):
        t = t0 + (t1 - t0) * i / n
        nx, nz = -math.cos(t) * out_sign, -math.sin(t) * out_sign
        pts.append((cx - r * math.cos(t), y, cz - r * math.sin(t), nx, nz))
    return pts


def helix_path(variant):
    """나선 경사로 중심선 (Godot 좌표, 조각 원점 기준).
    공통: 아래 진입로 (0,0,0)→(13,0,0), 나선 0→270도 (중심 (13, *, 9)), 끝점 (4, 3, 9), 진행 방향 -Z.
    east: 끝에서 -Z로 13 m 곧게 → (4, 3, -4). 아래층 바로 위에 겹쳐 놓은 위층(B3, 90도 돌림) 입구에 닿는다.
    west: 끝에서 -Z로 17 m → 오른쪽으로 90도 꺾어 (반지름 6) +X 방향으로 (10, 3, -14). B2 서쪽 입구에 닿는다.
    """
    path = [(0.0, 0.0, 0.0, 0.0, -1.0)]
    path += _arc(HX_STUB, HX_R, HX_R, 0.0, HX_TURN, 0.0, HX_RISE, 72)
    ex, ez = HX_STUB - HX_R, HX_R            # (4, 9)
    if variant == "east":
        path.append((ex, HX_RISE, ez - 13.0, -1.0, 0.0))
    else:
        path.append((ex, HX_RISE, ez - 17.0, -1.0, 0.0))   # (4, 3, -8)
        # 중심 (10, -8), 반지름 6: t=0 → (4, -8) 진행 -Z, t=90도 → (10, -14) 진행 +X. 바깥쪽은 원의 바깥 = (-cos t, -sin t)
        path += _arc_right(ex + 6.0, ez - 17.0, 6.0, 0.0, math.pi / 2, HX_RISE, 16, 1.0)[1:]
    return path


def helix_mesh(name, variant):
    """나선 경사로 조각. 가운데(135도)에서는 휘어진 벽 때문에 양 끝이 보이지 않는다 → 반복 관문을 여기에 둔다.
    east와 west는 나선 부분이 완전히 같고 출구만 다르다. 순간이동은 회전 없이 평행 이동만 한다."""
    import bmesh

    path = helix_path(variant)
    n_helix_end = 1 + 72   # 나선 마지막 점의 인덱스
    h = HX_HALF
    # 단면: (안쪽 d0, 바깥쪽 d1, 높이 h0, h1, 재질, 출구에서는 바닥을 얇게)
    sections = [
        (-h, h, -0.3, 0.0, M_RAMP),
        (-h, h, 2.7, 3.0, M_CEIL),
        (h, h + 0.3, -0.3, 1.0, M_HBAND), (h, h + 0.3, 1.0, 1.05, M_HLINE), (h, h + 0.3, 1.05, 3.0, M_HWALL),
        (-h - 0.3, -h, -0.3, 1.0, M_HBAND), (-h - 0.3, -h, 1.0, 1.05, M_HLINE), (-h - 0.3, -h, 1.05, 3.0, M_HWALL),
        (-h, -h + 0.25, 0.0, 0.15, M_WHEELSTOP), (h - 0.25, h, 0.0, 0.15, M_WHEELSTOP),
    ]
    mats = []
    for s in sections:
        if s[4] not in mats:
            mats.append(s[4])

    me = bpy.data.meshes.new(name)
    bm = bmesh.new()
    for d0, d1, h0, h1, mat in sections:
        rings = []
        for idx, (cx, cy, cz, nx, nz) in enumerate(path):
            lo = h0
            # 출구 구간은 아래 진입로 천장 위를 지나므로, 바닥 판을 얇게 해 겹치는 면이 보이지 않게 한다
            if idx > n_helix_end and h0 < -0.2 and h1 <= 0.0:
                lo = -0.12
            elif idx > n_helix_end and h0 < -0.2:
                lo = -0.12
            ring = []
            for (d, hh) in ((d0, lo), (d1, lo), (d1, h1), (d0, h1)):
                gx, gy, gz = cx + nx * d, cy + hh, cz + nz * d
                ring.append(bm.verts.new((gx, -gz, gy)))
            rings.append(ring)
        new_faces = []
        for a, b in zip(rings[:-1], rings[1:]):
            for j in range(4):
                k = (j + 1) % 4
                f = bm.faces.new((a[j], a[k], b[k], b[j]))
                f.material_index = mats.index(mat)
                new_faces.append(f)
        bmesh.ops.recalc_face_normals(bm, faces=new_faces)
    bm.to_mesh(me)
    bm.free()
    for m in mats:
        me.materials.append(m)
    o = bpy.data.objects.new(name, me)
    bpy.context.collection.objects.link(o)
    bpy.context.view_layer.objects.active = o
    o.select_set(True)
    try:
        bpy.ops.object.shade_smooth_by_angle(angle=math.radians(35))
    except Exception:
        pass
    export(name)


def helix_east():
    helix_mesh("helix_east", "east")


def helix_west():
    helix_mesh("helix_west", "west")


def fire_shutter():
    """방화셔터: 폭 6 m, 높이 2.7 m. 원점은 바닥 가운데. 판 방향은 Godot Z, 두께는 X."""
    parts = []
    slat_h = 0.075
    n = int(2.62 / slat_h)
    for i in range(n):
        s = cube("slat", (0.05, 6.0, slat_h - 0.006), (0, 0, 0.04 + slat_h * (i + 0.5)), M_SHUTTER)
        bevel(s, 0.012, 2)
        parts.append(s)
    bottom = cube("bottom_bar", (0.08, 6.0, 0.05), (0, 0, 0.025), M_SHUTTER_DARK)
    bevel(bottom, 0.01, 2)
    guides = [cube("guide", (0.12, 0.1, 2.7), (0, sy * 3.0, 1.35), M_SHUTTER_DARK) for sy in (-1, 1)]
    stripe = cube("stripe", (0.056, 5.98, 0.12), (0, 0, 1.2), M_HAZARD)
    join(parts + [bottom, stripe] + guides, "fire_shutter")
    export("fire_shutter")


def arrow():
    """바닥에 칠한 화살표. 길이 방향 +X, 두께 없음(평면)."""
    verts = [(-1.0, -0.13, 0), (0.35, -0.13, 0), (0.35, -0.38, 0), (1.0, 0, 0),
             (0.35, 0.38, 0), (0.35, 0.13, 0), (-1.0, 0.13, 0)]
    me = bpy.data.meshes.new("arrow")
    me.from_pydata(verts, [], [list(range(len(verts)))])
    me.update()
    o = bpy.data.objects.new("arrow", me)
    bpy.context.collection.objects.link(o)
    o.data.materials.append(M_PAINT_WHITE)
    bpy.context.view_layer.objects.active = o
    export("arrow")


def fire_cabinet():
    """소화전함 0.75 x 0.2 x 0.95 m. 원점은 뒷면 아래 가운데, 앞쪽이 Godot +Z."""
    box = cube("box", (0.75, 0.2, 0.95), (0, -0.1, 0.475), M_CAB_RED)
    bevel(box, 0.015, 2)
    glass = cube("glass", (0.32, 0.01, 0.45), (-0.16, -0.203, 0.6), M_GLASS)
    handle = cube("handle", (0.03, 0.03, 0.12), (0.26, -0.215, 0.5), M_HANDLE)
    bevel(handle, 0.008, 2)
    join([box, glass, handle], "fire_cabinet")
    export("fire_cabinet")


def steel_door():
    """철제 방화문과 문틀. 폭 1.0 m(X), 높이 2.1 m. 원점은 벽면 아래 가운데, 앞쪽이 Godot +Z."""
    frame_parts = [
        cube("jamb_l", (0.08, 0.1, 2.18), (-0.54, -0.05, 1.09), M_DOOR_FRAME),
        cube("jamb_r", (0.08, 0.1, 2.18), (0.54, -0.05, 1.09), M_DOOR_FRAME),
        cube("head", (1.16, 0.1, 0.08), (0, -0.05, 2.14), M_DOOR_FRAME),
    ]
    for f in frame_parts:
        bevel(f, 0.01, 2)
    slab = cube("slab", (1.0, 0.05, 2.1), (0, -0.03, 1.05), M_DOOR)
    bevel(slab, 0.006, 2)
    bar = cube("bar", (0.7, 0.05, 0.06), (0, -0.09, 1.0), M_HANDLE)
    bevel(bar, 0.015, 2)
    window = cube("window", (0.22, 0.01, 0.5), (0, -0.056, 1.55), M_GLASS)
    join(frame_parts + [slab, bar, window], "steel_door")
    export("steel_door")


def exit_sign():
    """비상구 표시등 0.42 x 0.08 x 0.16 m. 원점은 뒷면 가운데, 앞쪽이 Godot +Z."""
    box = cube("box", (0.42, 0.08, 0.16), (0, -0.04, 0), M_EXIT_BOX)
    bevel(box, 0.01, 2)
    face = cube("face", (0.38, 0.005, 0.12), (0, -0.0825, 0), M_EXIT)
    join([box, face], "exit_sign")
    export("exit_sign")


def traffic_cone():
    base = cube("base", (0.38, 0.38, 0.03), (0, 0, 0.015), M_CONE)
    bevel(base, 0.02, 2)
    body = cone("body", 0.14, 0.025, 0.68, (0, 0, 0.37), mat=M_CONE)
    band = cone("band", 0.104, 0.078, 0.16, (0, 0, 0.45), mat=M_REFLECT)
    band.scale = (1.02, 1.02, 1.0)
    bpy.ops.object.transform_apply(scale=True)
    join([base, body, band], "traffic_cone")
    export("traffic_cone")


def coffee_cup():
    """앵커 오브젝트: 쓰러진 커피컵 (세운 상태로 만들고 Godot에서 눕힌다). 원점은 바닥 가운데."""
    cup = cone("cup", 0.032, 0.045, 0.11, (0, 0, 0.055), mat=M_CUP)
    sleeve = cone("sleeve", 0.0385, 0.0445, 0.05, (0, 0, 0.06), mat=M_SLEEVE)
    sleeve.scale = (1.03, 1.03, 1.0)
    bpy.ops.object.transform_apply(scale=True)
    lid = cyl("lid", 0.047, 0.012, (0, 0, 0.114), verts=32, mat=M_LID)
    join([cup, sleeve, lid], "coffee_cup")
    export("coffee_cup")


def hanging_sign():
    """천장에 매다는 안내판 판재 1.8 x 0.05 x 0.4 m. 원점은 윗면 가운데, 글씨는 Godot에서 붙인다."""
    plate = cube("plate", (1.8, 0.05, 0.4), (0, 0, -0.32), M_SIGN)
    bevel(plate, 0.01, 2)
    rods = [cyl("rod", 0.008, 0.12, (sx * 0.7, 0, -0.06), verts=8, mat=M_FIX_METAL) for sx in (-1, 1)]
    join([plate] + rods, "hanging_sign")
    export("hanging_sign")


clear()
for build in (pillar, beam, wheel_stop, fixture, pipe_gray, pipe_sprinkler, ramp_tunnel,
              arrow, fire_cabinet, steel_door, exit_sign, traffic_cone, coffee_cup, hanging_sign,
              fire_shutter, helix_east, helix_west):
    build()
print("KIT DONE")
