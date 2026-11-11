"""Blender 모델링 공통 도우미. 다른 스크립트에서 `from bkit import *`로 쓴다.

축 약속: Blender X → Godot X, Blender Z(위) → Godot Y(위), Blender -Y → Godot +Z (앞쪽).
"""
import math
import os
import sys

import bpy

OUT = os.path.abspath(sys.argv[sys.argv.index("--") + 1]) if "--" in sys.argv else os.getcwd()
os.makedirs(OUT, exist_ok=True)


def lin(hexstr):
    out = []
    for i in (0, 2, 4):
        c = int(hexstr[i:i + 2], 16) / 255.0
        out.append(c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4)
    return (*out, 1.0)


def material(name, color="808080", rough=0.8, metal=0.0, emit=None, emit_strength=0.0, alpha=1.0):
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
    if alpha < 1.0:
        bsdf.inputs["Alpha"].default_value = alpha
        try:
            m.surface_render_method = "BLENDED"
        except Exception:
            pass
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


def smooth(o):
    for p in o.data.polygons:
        p.use_smooth = True


def cube(name, size, loc=(0, 0, 0), mat=None, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc, rotation=rot)
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


def cone(name, r1, r2, depth, loc=(0, 0, 0), rot=(0, 0, 0), verts=32, mat=None):
    bpy.ops.mesh.primitive_cone_add(vertices=verts, radius1=r1, radius2=r2, depth=depth, location=loc, rotation=rot)
    o = active()
    o.name = name
    if mat:
        o.data.materials.append(mat)
    smooth(o)
    return o


def torus(name, r_major, r_minor, loc=(0, 0, 0), rot=(0, 0, 0), mat=None, seg=32):
    bpy.ops.mesh.primitive_torus_add(major_radius=r_major, minor_radius=r_minor, location=loc, rotation=rot,
                                     major_segments=seg, minor_segments=8)
    o = active()
    o.name = name
    if mat:
        o.data.materials.append(mat)
    smooth(o)
    return o


def bevel(o, width, segments=2):
    mod = o.modifiers.new("Bevel", "BEVEL")
    mod.width = width
    mod.segments = segments
    mod.limit_method = "ANGLE"
    mod.harden_normals = True
    smooth(o)
    return o


def tube(name, points, r, mat=None, verts=10):
    """점들을 잇는 굽은 관 (원기둥 여러 개)."""
    parts = []
    for a, b in zip(points[:-1], points[1:]):
        dx, dy, dz = b[0] - a[0], b[1] - a[1], b[2] - a[2]
        ln = math.sqrt(dx * dx + dy * dy + dz * dz)
        mid = ((a[0] + b[0]) / 2, (a[1] + b[1]) / 2, (a[2] + b[2]) / 2)
        o = cyl(name, r, ln * 1.02, mid, verts=verts, mat=mat)
        # z축을 (dx, dy, dz) 방향으로
        rot_axis = (-dy, dx, 0.0)
        ang = math.acos(max(-1.0, min(1.0, dz / ln)))
        if abs(ang) > 1e-6:
            import mathutils
            o.rotation_mode = "AXIS_ANGLE"
            al = math.sqrt(rot_axis[0] ** 2 + rot_axis[1] ** 2) or 1.0
            o.rotation_axis_angle = (ang, rot_axis[0] / al, rot_axis[1] / al, 0.0)
            bpy.ops.object.transform_apply(location=False, rotation=True, scale=False)
        parts.append(o)
    return parts


def join(objs, name):
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        bpy.context.view_layer.objects.active = o
        o.select_set(True)
        for mod in list(o.modifiers):
            bpy.ops.object.modifier_apply(modifier=mod.name)
        o.select_set(False)
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.join()
    o = active()
    o.name = name
    return o


def export(name):
    bpy.ops.object.select_all(action="SELECT")
    path = os.path.join(OUT, name + ".glb")
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True,
                              export_apply=True, export_yup=True)
    print("exported", path)
    clear()
