"""Shared code for the exercise animations: the figure, the props, the house style, the hand library and applying a
pose file. Runs inside Blender 5.2 (bpy); render.py is the entry point.

Coordinates are the figure's armature space, which is the world: metres, Z up, the figure stands at the origin
facing -Y, its left side at +X. Angles in pose files are degrees.
"""
import json
import math
import os

import bmesh
import bpy
from mathutils import Euler, Matrix, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
BUILD = os.path.join(ROOT, "build", "animations")
FIGURE = os.path.join(BUILD, "figure.blend")
EXERCISES = os.path.join(HERE, "exercises")
FPS = 30

# Mirrors an armature-space matrix across X = 0 (left <-> right).
S4 = Matrix.Diagonal((-1.0, 1.0, 1.0, 1.0))


def mirror(m):
    return S4 @ m @ S4


def rotation(deg):
    return Euler([math.radians(a) for a in deg]).to_matrix().to_4x4()


def update():
    bpy.context.view_layer.update()


# ---------------------------------------------------------------- figure


class Figure:
    """MPFB's figure from build/animations/figure.blend, restyled, with IK stretch off so an unreachable target
    leaves a gap the checks catch."""

    def __init__(self):
        bpy.ops.wm.open_mainfile(filepath=FIGURE)
        self.rig = bpy.data.objects["Human.rigify"]
        update()
        self.rest = {pb.name: pb.matrix.copy() for pb in self.rig.pose.bones}
        self.bones = self.rig.pose.bones
        for side in "LR":
            for limb in ("upper_arm_parent.", "thigh_parent."):
                pb = self.bones[limb + side]
                pb["IK_Stretch"] = 0.0
                pb["pole_vector"] = True  # knees and elbows aim at their *_ik_target poles
        self.body = next(o for o in self.rig.children if o.name == "Human")
        self.cloth = next(o for o in self.rig.children if o.type == 'MESH' and o.name != "Human")
        for m in self.body.modifiers:
            if m.type == 'MASK':
                m.show_viewport = False  # measurements see every vertex at its own index; renders keep the masks
        helper = {g.index for g in self.body.vertex_groups
                  if g.name in ("HelperGeometry", "JointCubes") or g.name.startswith("helper-")}
        # The visible body: MPFB's base mesh also holds hidden helper geometry.
        self.real = [v.index for v in self.body.data.vertices
                     if not any(g.group in helper and g.weight > 0.5 for g in v.groups)]
        self.hand_vertices = {s: self._hand_vertices(s) for s in "LR"}
        clay = material("clay", (0.50, 0.50, 0.52))
        cloth = material("cloth", (0.17, 0.17, 0.19))
        for o in (self.body, self.cloth):
            o.data.materials.clear()
            o.data.materials.append(clay if o is self.body else cloth)
            for p in o.data.polygons:
                p.material_index = 0

    def _hand_vertices(self, side):
        """Visible vertices weighted mostly to that side's hand and finger bones."""
        prefixes = ("DEF-hand.", "DEF-palm.", "DEF-thumb.", "DEF-f_")
        idx = {g.index for g in self.body.vertex_groups if g.name.startswith(prefixes) and g.name.endswith("." + side)}
        real = set(self.real)
        return [v.index for v in self.body.data.vertices
                if v.index in real and sum(g.weight for g in v.groups if g.group in idx) > 0.5]

    def reset(self):
        for pb in self.bones:
            pb.location = (0, 0, 0)
            pb.rotation_quaternion = (1, 0, 0, 0)
            pb.rotation_euler = (0, 0, 0)
            pb.scale = (1, 1, 1)


# ---------------------------------------------------------------- materials and props


def material(name, rgb, rough=0.8, metal=0.0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (*rgb, 1)
    b.inputs["Roughness"].default_value = rough
    b.inputs["Metallic"].default_value = metal
    return m


def _box(bm, size, loc, mat_index):
    geom = bmesh.ops.create_cube(bm, size=1.0)
    for v in geom["verts"]:
        v.co = Vector((v.co.x * size[0], v.co.y * size[1], v.co.z * size[2])) + Vector(loc)
    for f in {f for v in geom["verts"] for f in v.link_faces}:
        f.material_index = mat_index


def _object(name, bm, mats, bevel=0.0):
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    for m in mats:
        me.materials.append(m)
    o = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(o)
    if bevel:
        bv = o.modifiers.new("bevel", 'BEVEL')
        bv.width = bevel
        bv.segments = 3
        bv.limit_method = 'ANGLE'
    return o


# PowerBlock-like proportions (Elite EXP): two square end stacks, the handle in the hand opening, and two rails
# along the opening. Local axes: the handle along Z, X across the stacks, the rails at +Y; they sit either side of
# the wrist in a grip.
DUMBBELL = dict(stack_w=0.150, stack_d=0.145, stack_len=0.095, gap=0.115, handle_r=0.0165, rail=0.020, rail_x=0.058)


def dumbbell(name):
    d = DUMBBELL
    mats = [material("charcoal", (0.10, 0.10, 0.11), 0.55), material("rail", (0.36, 0.36, 0.38), 0.45),
            material("handle", (0.55, 0.55, 0.57), 0.35, 0.3)]
    bm = bmesh.new()
    zc = d["gap"] / 2 + d["stack_len"] / 2
    for z in (zc, -zc):
        _box(bm, (d["stack_w"], d["stack_d"], d["stack_len"]), (0, 0, z), 0)
    r = d["rail"]
    for sx in (-1, 1):
        _box(bm, (r, r, d["gap"] + 0.004), (sx * d["rail_x"], d["stack_d"] / 2 - r / 2 - 0.004, 0), 1)
    geom = bmesh.ops.create_cone(bm, cap_ends=True, segments=32, radius1=d["handle_r"], radius2=d["handle_r"],
                                 depth=d["gap"] + 0.004)
    for f in {f for v in geom["verts"] for f in v.link_faces}:
        f.material_index = 2
    return _object(name, bm, mats, bevel=0.005)


# A flat bench: pad top at BENCH["top"], centred on the origin along Y.
BENCH = dict(top=0.44, length=1.20, width=0.28, pad=0.07)


def bench(name="bench"):
    b = BENCH
    mats = [material("pad", (0.13, 0.13, 0.14), 0.7), material("frame", (0.30, 0.30, 0.32), 0.4, 0.4)]
    bm = bmesh.new()
    _box(bm, (b["width"], b["length"], b["pad"]), (0, 0, b["top"] - b["pad"] / 2), 0)
    rail_top = b["top"] - b["pad"]
    _box(bm, (0.06, b["length"] - 0.2, 0.05), (0, 0, rail_top - 0.025), 1)
    for y in (-(b["length"] / 2 - 0.15), b["length"] / 2 - 0.15):
        _box(bm, (0.06, 0.06, rail_top), (0, y, rail_top / 2), 1)
        _box(bm, (0.40, 0.06, 0.04), (0, y, 0.02), 1)
    return _object(name, bm, mats, bevel=0.008)


def floor_line():
    """A 3 mm slab just under z = 0, seen as a thin line from the side; only the contact sheets show it."""
    bm = bmesh.new()
    _box(bm, (4.0, 4.0, 0.003), (0, 0, -0.0015), 0)
    return _object("floor", bm, [material("floor", (0.62, 0.62, 0.64), 0.9)])


# ---------------------------------------------------------------- hand library


FINGERS = ("index", "middle", "ring", "pinky")
HANDS = json.load(open(os.path.join(HERE, "hands.json")))


def hand_shape(name):
    return HANDS["shapes"][name]


def blend_shapes(a, b, t):
    out = {k: {p: a[k][p] + (b[k][p] - a[k][p]) * t for p in a[k]} for k in FINGERS + ("thumb",)}
    out["palm"] = [a["palm"][i] + (b["palm"][i] - a["palm"][i]) * t for i in range(2)]
    return out


def apply_hand(fig, side, shape):
    """Poses one hand's finger controls (see hands.json for the parameters); the right hand mirrors the left."""
    P = fig.bones
    s = 1 if side == "L" else -1
    r = math.radians
    for f in FINGERS:
        p = shape[f]
        m = P[f"f_{f}.01_master.{side}"]
        m.rotation_mode = 'XYZ'
        m.rotation_euler = (r(p["mcp"]), 0, s * r(p["spread"]))
        m.scale = (1, 1 - p["curl"] / 180.0, 1)
        P[f"f_{f}.03.{side}"].rotation_euler = (r(p["dip"] - p["curl"]), 0, 0)
    t = shape["thumb"]
    m = P[f"thumb.01_master.{side}"]
    m.rotation_mode = 'XYZ'
    m.rotation_euler = (r(t["rx"]), s * r(t["ry"]), s * r(t["rz"]))
    m.scale = (1, 1 - t["curl"] / 180.0, 1)
    px, pz = shape["palm"]
    P[f"palm.{side}"].rotation_quaternion = (Euler((r(px), 0, 0)).to_quaternion()
                                             @ Euler((0, 0, s * r(pz))).to_quaternion())


# ---------------------------------------------------------------- pose files


class PoseFileError(Exception):
    pass


def slug_of(exercise):
    out = "".join(c if c.isalpha() else "-" for c in exercise.lower())
    while "--" in out:
        out = out.replace("--", "-")
    return out.strip("-")


def load_pose_file(slug_or_path):
    """A pose file by slug, or by path (a scratch copy, for trying a change)."""
    path = slug_or_path if slug_or_path.endswith(".json") else os.path.join(EXERCISES, slug_or_path + ".json")
    slug = os.path.basename(path)[:-5]
    spec = json.load(open(path))
    for field in ("exercise", "description", "variant", "references", "view", "props", "frames", "still", "poses",
                  "keys", "planted"):
        if field not in spec:
            raise PoseFileError(f"{slug}: missing field {field}")
    if slug_of(spec["exercise"]) != slug:
        raise PoseFileError(f"{slug}: the file name should be {slug_of(spec['exercise'])}.json")
    if not spec["references"]:
        raise PoseFileError(f"{slug}: no references")
    keys = spec["keys"]
    if keys[0]["frame"] != 1 or keys[-1]["frame"] != spec["frames"] + 1:
        raise PoseFileError(f"{slug}: keys must start at frame 1 and end at frame frames + 1")
    if any(b["frame"] <= a["frame"] for a, b in zip(keys, keys[1:])):
        raise PoseFileError(f"{slug}: key frames must increase")
    for k in keys:
        if k["pose"] not in spec["poses"]:
            raise PoseFileError(f"{slug}: key at frame {k['frame']} names unknown pose {k['pose']}")
    if not 1 <= spec["still"] <= spec["frames"]:
        raise PoseFileError(f"{slug}: still frame outside 1…frames")
    spec["slug"] = slug
    spec["poses"] = {name: with_mirrored_sides(p) for name, p in spec["poses"].items()}
    return spec


def _mirror_entry(entry):
    if isinstance(entry, str):
        return entry
    out = dict(entry)
    if "at" in out:
        out["at"] = [-out["at"][0], out["at"][1], out["at"][2]]
    if "turn" in out:
        out["turn"] = [out["turn"][0], -out["turn"][1], -out["turn"][2]]
    for field in ("palm", "fingers"):
        if field in out:
            out[field] = [-out[field][0], out[field][1], out[field][2]]
    if "pivot" in out:
        out["pivot"] = [-out["pivot"][0], out["pivot"][1], out["pivot"][2]]
    for field in ("on", "in"):
        if field in out:
            out[field] = out[field].replace(".L", ".R")
    return out


def with_mirrored_sides(pose):
    """A pose gives the left side; the right side mirrors it unless the pose gives it too."""
    out = dict(pose)
    for name, entry in pose.items():
        if name.endswith(".L") and name[:-2] + ".R" not in pose:
            out[name[:-2] + ".R"] = _mirror_entry(entry)
    return out


def _hermite(times, values, tangents, t):
    for i in range(len(times) - 1):
        t0, t1 = times[i], times[i + 1]
        if t0 <= t <= t1:
            h = t1 - t0
            u = (t - t0) / h
            h00, h10 = 2 * u ** 3 - 3 * u ** 2 + 1, u ** 3 - 2 * u ** 2 + u
            h01, h11 = -2 * u ** 3 + 3 * u ** 2, u ** 3 - u ** 2
            return h00 * values[i] + h10 * h * tangents[i] + h01 * values[i + 1] + h11 * h * tangents[i + 1]
    raise ValueError(t)


VECTORS = ("at", "turn", "palm", "fingers")  # the interpolated fields of an entry


def pose_at(spec, frame):
    """The pose at a frame: every entry interpolated between the keys. Each key eases in and out; a key with
    "via": true passes through without stopping (Catmull-Rom tangent). Hand shapes blend linearly."""
    keys = spec["keys"]
    times = [k["frame"] for k in keys]
    poses = [spec["poses"][k["pose"]] for k in keys]
    names = poses[0].keys()
    for p in poses:
        if p.keys() != names:
            raise PoseFileError(f"{spec['slug']}: every pose must give the same entries")
    out = {}
    for name in names:
        entries = [p[name] for p in poses]
        if isinstance(entries[0], str):
            out[name] = _blend_shape_names(times, entries, frame)
            continue
        fixed = {k: v for k, v in entries[0].items() if k not in VECTORS}
        if any({k: v for k, v in e.items() if k not in VECTORS} != fixed or e.keys() != entries[0].keys()
               for e in entries):
            raise PoseFileError(f"{spec['slug']}: {name} must keep its fields, parent and hold in every pose")
        entry = dict(fixed)
        for field in VECTORS:
            if field not in entries[0]:
                continue
            entry[field] = []
            for c in range(3):
                vs = [e[field][c] for e in entries]
                tangents = [0.0] * len(vs)
                for i, k in enumerate(keys):
                    if k.get("via") and 0 < i < len(keys) - 1:
                        tangents[i] = (vs[i + 1] - vs[i - 1]) / (times[i + 1] - times[i - 1])
                entry[field].append(_hermite(times, vs, tangents, frame))
        out[name] = entry
    return out


def _blend_shape_names(times, names, frame):
    for i in range(len(times) - 1):
        if times[i] <= frame <= times[i + 1]:
            u = (frame - times[i]) / (times[i + 1] - times[i])
            u = u * u * (3 - 2 * u)
            return blend_shapes(hand_shape(names[i]), hand_shape(names[i + 1]), u)
    raise ValueError(frame)


# Entries are applied parents first. Bones in a pose file are the Rigify controls; props are named in Props.
ORDER = ("torso", "hips", "chest", "neck", "head", "foot_ik", "toe_ik", "thigh_ik_target", "upper_arm_ik_target")


class Props:
    """The pose file's props: "dumbbells" (0, 1 named dumbbell, or 2 named dumbbell.L and dumbbell.R) and
    "bench" (null or "flat")."""

    def __init__(self, spec):
        p = spec["props"]
        n = p.get("dumbbells", 0)
        names = {0: [], 1: ["dumbbell"], 2: ["dumbbell.L", "dumbbell.R"]}[n]
        self.moving = {name: dumbbell(name) for name in names}
        self.fixed = {}
        if p.get("bench"):
            self.fixed["bench"] = bench()

    def all(self):
        return {**self.moving, **self.fixed}


def _place(fig, bone, entry):
    """Places a control. With "at": absolute, the bone's rest matrix turned by "turn" about "pivot" (default: its
    rest head), then moved so the pivot lands on "at". A hand control can instead aim its "palm" (the palm's
    outward normal) and "fingers" (wrist to knuckles) with its head at "at". Without "at": turned by "turn" (world
    axes) about its current head, on top of what its parents give it."""
    pb = fig.bones[bone]
    rot = rotation(entry.get("turn", (0, 0, 0)))
    if "palm" in entry:
        # Rigify's hand bones: X is the left palm's normal and points out of the back of the right hand.
        x = Vector(entry["palm"]).normalized() * (1 if bone.endswith(".L") else -1)
        y = Vector(entry["fingers"])
        y = (y - x * y.dot(x)).normalized()
        m = Matrix((x, y, x.cross(y))).transposed().to_4x4()
        m.translation = Vector(entry["at"])
        pb.matrix = m
    elif "at" in entry:
        rest = fig.rest[bone]
        pivot = Vector(entry.get("pivot", rest.translation))
        pb.matrix = Matrix.Translation(Vector(entry["at"])) @ rot @ Matrix.Translation(-pivot) @ rest
    else:
        m = pb.matrix.copy()
        h = m.translation.copy()
        pb.matrix = Matrix.Translation(h) @ rot @ Matrix.Translation(-h) @ m


def apply_pose(fig, props, pose):
    """Poses the figure and the moving props for one frame."""
    fig.reset()
    if "rig" in pose:
        raise PoseFileError("rig settings belong at the top level")
    known = set()
    for prefix in ORDER:
        for name, entry in pose.items():
            if name == prefix or name.startswith(prefix + "."):
                _place(fig, name, entry)
                known.add(name)
        update()
    for name, entry in pose.items():
        if name in props.moving and "in" not in entry:
            parent = entry.get("parent")
            frame = Matrix.Identity(4)
            if parent:
                frame = fig.bones[parent].matrix @ fig.rest[parent].inverted()
            props.moving[name].matrix_world = (frame @ Matrix.Translation(Vector(entry["at"]))
                                               @ rotation(entry.get("turn", (0, 0, 0))))
            known.add(name)
    update()
    for side in "LR":
        name = "hand_ik." + side
        entry = pose.get(name)
        if entry is not None and "on" in entry:
            hold = HANDS["holds"][entry["hold"]]
            held = props.moving[entry["on"]].matrix_world
            m = Matrix(hold["hand"])
            fig.bones[name].matrix = held @ (m if side == "L" else mirror(m))
            apply_hand(fig, side, hand_shape(hold["shape"]))
        elif entry is not None:
            _place(fig, name, entry)
            if "hold" in entry:
                apply_hand(fig, side, hand_shape(HANDS["holds"][entry["hold"]]["shape"]))
        shape = pose.get("fingers." + side)
        if shape is not None:  # a shape name, blended into numbers by pose_at
            apply_hand(fig, side, shape if isinstance(shape, dict) else hand_shape(shape))
        known |= {name, "fingers." + side}
    update()
    for name, entry in pose.items():
        if name in props.moving and "in" in entry:  # a prop held in a placed hand follows the hand
            side = entry["in"][-1]
            hold = props_hold(pose, side)
            props.moving[name].matrix_world = (fig.bones["DEF-hand." + side].matrix
                                               @ (hold if side == "L" else mirror(hold)).inverted())
            known.add(name)
    unknown = set(pose) - known
    if unknown:
        raise PoseFileError(f"unknown pose entries: {sorted(unknown)}")
    update()


def props_hold(pose, side):
    return Matrix(HANDS["holds"][pose["hand_ik." + side]["hold"]]["hand"])


def held_hands(pose):
    """Hand side -> the prop it holds, in this pose."""
    return {name[-1]: e.get("on") for name, e in pose.items() if name.startswith("hand_ik.") and "hold" in e}


def setup_rig(fig, spec):
    for key, value in spec.get("rig", {}).items():
        bone, prop = key.split(".", 1)
        fig.bones[bone][prop] = value


# ---------------------------------------------------------------- house style, camera and rendering


def scene_setup(res=540, samples=16):
    sc = bpy.context.scene
    sc.render.engine = 'BLENDER_EEVEE'
    sc.eevee.taa_render_samples = samples
    sc.render.film_transparent = True
    sc.render.resolution_x = sc.render.resolution_y = res
    sc.render.resolution_percentage = 100
    sc.render.fps = FPS
    sc.render.image_settings.file_format = 'PNG'
    sc.render.image_settings.color_mode = 'RGBA'
    sc.view_settings.view_transform = 'Standard'
    w = bpy.data.worlds.new("world")
    w.use_nodes = True
    w.node_tree.nodes["Background"].inputs[0].default_value = (0.8, 0.8, 0.82, 1)
    w.node_tree.nodes["Background"].inputs[1].default_value = 0.6
    sc.world = w
    cam = bpy.data.objects.new("camera", bpy.data.cameras.new("camera"))
    sc.collection.objects.link(cam)
    cam.data.type = 'ORTHO'
    cam.data.clip_start = 0.01
    cam.data.clip_end = 100
    sc.camera = cam
    for name, energy, rot in (("key", 3.0, (50, 0, -40)), ("fill", 1.0, (70, 0, 60))):
        light = bpy.data.objects.new(name, bpy.data.lights.new(name, 'SUN'))
        light.data.energy = energy
        light.rotation_euler = [math.radians(a) for a in rot]
        sc.collection.objects.link(light)
    return sc, cam


def aim(cam, azimuth, elevation, center=(0, 0, 0.8), dist=8.0):
    """Azimuth 0 puts the camera in front of the figure (on -Y); 90 on its left (+X); -90 on its right."""
    a, e = math.radians(azimuth), math.radians(elevation)
    c = Vector(center)
    cam.location = c + Vector((dist * math.sin(a) * math.cos(e), -dist * math.cos(a) * math.cos(e),
                               dist * math.sin(e)))
    cam.rotation_euler = (c - cam.location).to_track_quat('-Z', 'Y').to_euler()
    update()


def project(cam, pts):
    """Points in the camera's view as (x, y), 0…1 across the frame when inside."""
    r = cam.matrix_world.to_3x3()
    rx, ry = r.col[0], r.col[1]
    c = cam.location
    s = cam.data.ortho_scale
    return [(0.5 + (p - c).dot(rx) / s, 0.5 + (p - c).dot(ry) / s) for p in pts]


def frame_to(cam, pts, fill):
    """Centres the orthographic camera on the points; the larger side of their box fills `fill` of the frame."""
    r = cam.matrix_world.to_3x3()
    rx, ry, fwd = r.col[0], r.col[1], -r.col[2]
    xs = [p.dot(rx) for p in pts]
    ys = [p.dot(ry) for p in pts]
    cam.location = (rx * (max(xs) + min(xs)) / 2 + ry * (max(ys) + min(ys)) / 2 + fwd * cam.location.dot(fwd))
    cam.data.ortho_scale = max(max(xs) - min(xs), max(ys) - min(ys)) / fill
    update()


def render(path):
    bpy.context.scene.render.filepath = path
    bpy.ops.render.render(write_still=True)
