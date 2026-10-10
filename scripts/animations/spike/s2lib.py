"""Spike 2 shared code: figure, PowerBlock-like prop, camera framing, render, contact checks."""
import bpy, math, os, sys, time
from mathutils import Vector, Matrix, Euler, Quaternion
from mathutils.bvhtree import BVHTree

S4 = Matrix.Diagonal((-1.0, 1.0, 1.0, 1.0))


def mirror(M):
    """Mirror an armature-space bone matrix across the X=0 plane (left <-> right)."""
    return S4 @ M @ S4


def rad(*a):
    return [math.radians(x) for x in a]


# ---------------------------------------------------------------- figure
def open_fig(path="/tmp/blspike/figure.blend"):
    bpy.ops.wm.open_mainfile(filepath=path)
    rig = bpy.data.objects["Human.rigify"]
    bpy.context.view_layer.update()
    rest = {pb.name: pb.matrix.copy() for pb in rig.pose.bones}
    for s in "LR":
        for p in ("upper_arm_parent.", "thigh_parent."):
            pb = rig.pose.bones[p + s]
            pb["IK_Stretch"] = 0.0      # no rubber limbs: an unreachable target shows as a gap the check catches
            pb["pole_vector"] = True    # explicit knee and elbow direction from the *_ik_target poles
    restyle(rig)
    hb = body(rig)
    for m in hb.modifiers:
        if m.type == 'MASK':
            m.show_viewport = False   # measurements see every vertex at its own index; renders keep the masks
    global REAL
    helper = {g.index for g in hb.vertex_groups if g.name in ("HelperGeometry", "JointCubes") or g.name.startswith("helper-")}
    REAL = [v.index for v in hb.data.vertices if not any(g.group in helper and g.weight > 0.5 for g in v.groups)]
    return rig, rest


def mat(name, rgb, rough=0.8, metal=0.0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (*rgb, 1)
    b.inputs["Roughness"].default_value = rough
    b.inputs["Metallic"].default_value = metal
    return m


def restyle(rig):
    body = mat("clay", (0.50, 0.50, 0.52))
    cloth = mat("cloth", (0.17, 0.17, 0.19))
    for o in rig.children:
        if o.type != 'MESH':
            continue
        m = body if o.name == "Human" else cloth
        o.data.materials.clear()
        o.data.materials.append(m)
        for p in o.data.polygons:
            p.material_index = 0


def body(rig):
    return [o for o in rig.children if o.name == "Human"][0]


def reset(rig):
    for pb in rig.pose.bones:
        pb.location = (0, 0, 0)
        pb.rotation_quaternion = (1, 0, 0, 0)
        pb.rotation_euler = (0, 0, 0)
        pb.scale = (1, 1, 1)


def place(rig, rest, name, d=(0, 0, 0), rot=(0, 0, 0), pivot=None):
    """Rotate a bone (degrees, XYZ, armature axes) about a pivot, then translate it by d."""
    pb = rig.pose.bones[name]
    M = rest[name]
    piv = M.translation.copy() if pivot is None else Vector(pivot)
    R = Euler(rad(*rot)).to_matrix().to_4x4()
    pb.matrix = Matrix.Translation(Vector(d)) @ Matrix.Translation(piv) @ R @ Matrix.Translation(-piv) @ M


def upd():
    bpy.context.view_layer.update()


# ---------------------------------------------------------------- prop
def _box(name, size, loc, material, bevel=0.006):
    me = bpy.data.meshes.new(name)
    o = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(o)
    import bmesh
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    for v in bm.verts:
        v.co = Vector((v.co.x * size[0], v.co.y * size[1], v.co.z * size[2])) + Vector(loc)
    bm.to_mesh(me)
    bm.free()
    me.materials.append(material)
    if bevel:
        bv = o.modifiers.new("bevel", 'BEVEL')
        bv.width = bevel
        bv.segments = 3
    return o


# PowerBlock-like proportions (Elite EXP): two square end stacks, a hand opening with the handle,
# and two rails along the opening. Local axes: handle along Z, X = width, Y = depth (rails at +Y).
DB = dict(stack_w=0.150, stack_d=0.145, stack_len=0.095, gap=0.115, handle_r=0.0165, rail=0.020)


def dumbbell(rails=-1):
    charcoal = mat("charcoal", (0.10, 0.10, 0.11), 0.55)
    rail = mat("rail", (0.36, 0.36, 0.38), 0.45)
    handle = mat("handle", (0.55, 0.55, 0.57), 0.35, 0.3)
    w, d, L, g = DB["stack_w"], DB["stack_d"], DB["stack_len"], DB["gap"]
    zc = g / 2 + L / 2
    parts = [_box("stackTop", (w, d, L), (0, 0, zc), charcoal), _box("stackBot", (w, d, L), (0, 0, -zc), charcoal)]
    r = DB["rail"]
    for sx in (-1, 1):
        parts.append(_box("rail", (r, r, g + 0.004), (sx * 0.058, rails * (d / 2 - r / 2 - 0.004), 0), rail, 0.003))
    bpy.ops.mesh.primitive_cylinder_add(radius=DB["handle_r"], depth=g + 0.004, vertices=32, location=(0, 0, 0))
    h = bpy.context.active_object
    h.data.materials.append(handle)
    parts.append(h)
    # apply modifiers and join into one mesh so a single BVH covers the prop
    dg = bpy.context.evaluated_depsgraph_get()
    me = bpy.data.meshes.new("dumbbell")
    import bmesh
    bm = bmesh.new()
    mats = []
    for p in parts:
        e = p.evaluated_get(dg)
        m = e.to_mesh()
        mi = mats.index(p.data.materials[0]) if p.data.materials[0] in mats else (mats.append(p.data.materials[0]) or len(mats) - 1)
        for poly in m.polygons:
            poly.material_index = mi
        m.transform(p.matrix_world)
        bm.from_mesh(m)
        e.to_mesh_clear()
    bm.to_mesh(me)
    bm.free()
    for p in parts:
        bpy.data.objects.remove(p, do_unlink=True)
    o = bpy.data.objects.new("dumbbell", me)
    bpy.context.scene.collection.objects.link(o)
    for m in mats:
        me.materials.append(m)
    return o


def floor_line(width=4.0):
    """A 3 mm slab just under z=0: invisible from above, a thin line at elevation 0, for judging contact."""
    return _box("floorline", (width, width, 0.003), (0, 0, -0.0015), mat("floor", (0.62, 0.62, 0.64), 0.9), 0)


# ---------------------------------------------------------------- scene, camera, render
def scene_setup(res=540, samples=16):
    sc = bpy.context.scene
    sc.render.engine = 'BLENDER_EEVEE'
    sc.eevee.taa_render_samples = samples
    sc.render.film_transparent = True
    sc.render.resolution_x = sc.render.resolution_y = res
    sc.render.resolution_percentage = 100
    sc.render.image_settings.file_format = 'PNG'
    sc.render.image_settings.color_mode = 'RGBA'
    sc.view_settings.view_transform = 'Standard'
    w = bpy.data.worlds.new("w")
    w.use_nodes = True
    w.node_tree.nodes["Background"].inputs[0].default_value = (0.8, 0.8, 0.82, 1)
    w.node_tree.nodes["Background"].inputs[1].default_value = 0.6
    sc.world = w
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    sc.collection.objects.link(cam)
    cam.data.type = 'ORTHO'
    cam.data.clip_start = 0.01
    cam.data.clip_end = 100
    sc.camera = cam
    for nm, en, rot in (("key", 3.0, (50, 0, -40)), ("fill", 1.0, (70, 0, 60))):
        l = bpy.data.objects.new(nm, bpy.data.lights.new(nm, 'SUN'))
        l.data.energy = en
        l.rotation_euler = rad(*rot)
        sc.collection.objects.link(l)
    return sc, cam


def aim(cam, center, az, el, dist=8.0):
    """az 0 = camera on -Y looking +Y (front of the figure); az 90 = camera on +X (figure's left side)."""
    a, e = math.radians(az), math.radians(el)
    c = Vector(center)
    cam.location = c + Vector((dist * math.sin(a) * math.cos(e), -dist * math.cos(a) * math.cos(e), dist * math.sin(e)))
    cam.rotation_euler = (c - cam.location).to_track_quat('-Z', 'Y').to_euler()


def aim_dir(cam, center, direction, dist=8.0):
    c = Vector(center)
    cam.location = c + Vector(direction).normalized() * dist
    cam.rotation_euler = (c - cam.location).to_track_quat('-Z', 'Y').to_euler()


REAL = []


def mesh_points(objs):
    """World vertices of the visible geometry (the body without its helper vertices)."""
    dg = bpy.context.evaluated_depsgraph_get()
    pts = []
    for o in objs:
        e = o.evaluated_get(dg)
        me = e.to_mesh()
        mw = e.matrix_world
        vs = me.vertices
        if o.name == "Human":
            pts += [mw @ vs[i].co for i in REAL]
        else:
            pts += [mw @ v.co for v in vs]
        e.to_mesh_clear()
    return pts


def frame_to(cam, pts, fill=0.8, square=True):
    """Center the ortho camera on the points' projected box; the larger side fills `fill` of the frame."""
    upd()
    R = cam.matrix_world.to_3x3()
    rx, ry = R.col[0], R.col[1]
    xs = [p.dot(rx) for p in pts]
    ys = [p.dot(ry) for p in pts]
    w, h = max(xs) - min(xs), max(ys) - min(ys)
    cx, cy = (max(xs) + min(xs)) / 2, (max(ys) + min(ys)) / 2
    fwd = -R.col[2]
    depth = cam.location.dot(fwd)
    cam.location = rx * cx + ry * cy + fwd * depth
    cam.data.ortho_scale = max(w, h) / fill
    return w, h


def render(path):
    sc = bpy.context.scene
    sc.render.filepath = path
    t = time.time()
    bpy.ops.render.render(write_still=True)
    return time.time() - t


# ---------------------------------------------------------------- contact checks
def bvh_of(obj):
    dg = bpy.context.evaluated_depsgraph_get()
    e = obj.evaluated_get(dg)
    me = e.to_mesh()
    verts = [e.matrix_world @ v.co for v in me.vertices]
    polys = [tuple(p.vertices) for p in me.polygons]
    e.to_mesh_clear()
    return BVHTree.FromPolygons(verts, polys)


def group_vertices(obj, prefixes, thresh=0.3):
    """Vertex indices whose summed weight in groups starting with any prefix exceeds thresh."""
    idx = {g.index for g in obj.vertex_groups if g.name.startswith(tuple(prefixes))}
    out = []
    for v in obj.data.vertices:
        s = sum(g.weight for g in v.groups if g.group in idx)
        if s > thresh:
            out.append(v.index)
    return out


def eval_coords(obj):
    dg = bpy.context.evaluated_depsgraph_get()
    e = obj.evaluated_get(dg)
    me = e.to_mesh()
    co = [e.matrix_world @ v.co for v in me.vertices]
    e.to_mesh_clear()
    return co


def signed_dist(bvh, p):
    loc, nor, i, d = bvh.find_nearest(p)
    if loc is None:
        return 9.0
    return d if (p - loc).dot(nor) >= 0 else -d


# ---------------------------------------------------------------- hand parts and contact metrics
HAND_PARTS = {"heel": ("DEF-hand.",), "palm01": ("DEF-palm.01.",), "palm02": ("DEF-palm.02.",),
              "palm03": ("DEF-palm.03.",), "palm04": ("DEF-palm.04.",)}
for _f in ("thumb", "f_index", "f_middle", "f_ring", "f_pinky"):
    for _i in ("01", "02", "03"):
        HAND_PARTS[_f.replace("f_", "") + _i] = ("DEF-%s.%s." % (_f, _i),)


def hand_parts(obj, side):
    """Vertices of each hand part, assigned by their strongest deform group on that side."""
    names = {g.index: g.name for g in obj.vertex_groups}
    out = {k: [] for k in HAND_PARTS}
    real = set(REAL)
    for v in obj.data.vertices:
        if v.index not in real:
            continue
        best, bw = None, 0.25
        for g in v.groups:
            n = names[g.group]
            if g.weight > bw and n.endswith("." + side):
                for k, pre in HAND_PARTS.items():
                    if n.startswith(pre):
                        best, bw = k, g.weight
        if best:
            out[best].append(v.index)
    return out


def part_metrics(co, parts, bvh, touch=0.002):
    """Per part: (min signed distance in mm, vertices within `touch`)."""
    res = {}
    for k, ids in parts.items():
        ds = [signed_dist(bvh, co[i]) for i in ids]
        res[k] = (round(min(ds) * 1000, 1), sum(1 for d in ds if d < touch))
    return res
