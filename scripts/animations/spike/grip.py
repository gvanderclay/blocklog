"""Power grip around the PowerBlock handle, hammer-curl hold (palm medial, thumb up).
The handle lies along the knuckle line against the open palm; each finger then closes until it touches
(knuckle first, then the middle and end joints), and the thumb wraps over last.
Usage: blender -b -P grip.py -- uo=-0.01,0,0.01 [render=1] [probe=1] [thumb=rx,rz,ry]"""
import sys, json, copy
sys.path.insert(0, "/tmp/blspike/s2")
from s2lib import *
import s2lib, hands
from closefit import close_hand, close_thumb
A = dict(kv.split("=") for kv in sys.argv[sys.argv.index("--") + 1:]) if "--" in sys.argv else {}
UOS = [float(x) for x in A.get("uo", "-0.010,-0.005,0,0.005").split(",")]
TH = [float(x) for x in A.get("thumb", "20,40,0").split(",")]
S1 = tuple(float(x) for x in A.get("s1", "70,55,35").split(","))
out = "/tmp/blspike/s2/gr"; os.makedirs(out, exist_ok=True)
rig, rest = open_fig(); P = rig.pose.bones; B = body(rig)
sc, cam = scene_setup(res=540)
db = dumbbell(rails=1)
parts = hand_parts(B, "L")
WRIST = Vector((0.20, -0.27, 1.07))
n0 = Vector((-1, 0, 0)); u0 = Vector((0, -1, 0))
HM = Matrix((n0, u0, n0.cross(u0))).transposed().to_4x4(); HM.translation = WRIST


def apply_all(pose):
    P["hand_ik.L"].matrix = HM; P["hand_ik.R"].matrix = mirror(HM)
    for s_, sx in (("L", 1), ("R", -1)):
        M = rest["upper_arm_ik_target." + s_].copy(); M.translation = Vector((sx * 0.25, 0.25, 0.75)); P["upper_arm_ik_target." + s_].matrix = M
    hands.apply(rig, "L", pose); hands.apply(rig, "R", hands.POSES["relaxed"])
    upd()


coords = lambda: eval_coords(B)
OPEN = copy.deepcopy(hands.OPEN); OPEN["thumb"].update(rx=TH[0], rz=TH[1], ry=TH[2])
apply_all(OPEN)
# the hand's actual axes after IK: X palm normal (out of the palm), Y wrist -> knuckles
HW = P["DEF-hand.L"].matrix.to_3x3()
n, u = HW.col[0].normalized(), HW.col[1].normalized()
KI, KP = P["f_index.01_master.L"].head.copy(), P["f_pinky.01_master.L"].head.copy()
AX = (KI - KP).normalized()
WJ = P["DEF-hand.L"].head.copy()   # wrist joint: the rails straddle it, so the forearm passes between them
HANDK = [k for k in parts if k != "heel"] + ["heel"]
co0 = eval_coords(B)
pr = [(co0[i] - (KI + KP) / 2).dot(AX) for k in HANDK for i in parts[k]]
SHIFT = (max(pr) + min(pr)) / 2     # centre the hand's width between the end stacks
print("HANDSPAN mm", round(min(pr) * 1000, 1), round(max(pr) * 1000, 1), "gap", DB["gap"] * 1000)
PALM = [i for k in ("heel", "palm01", "palm02", "palm03", "palm04") for i in parts[k]]
BASE = PALM + parts["thumb01"] + [i for f in hands.FINGERS for i in parts[f + "01"]]


def place(uo, off):
    c = (KI + KP) / 2 + u * uo + n * off + AX * SHIFT
    Yl = (WJ - c) - AX * (WJ - c).dot(AX); Yl.normalize()
    db.matrix_world = Matrix.Translation(c) @ Matrix((Yl.cross(AX), Yl, AX)).transposed().to_4x4()
    upd()


def place_palm(uo, target=-0.5):
    """Slide the handle along the palm normal until the palm (or finger bases) just touch it."""
    lo, hi = 0.0, 0.07
    for _ in range(14):
        mid = (lo + hi) / 2; place(uo, mid)
        co, bv = coords(), bvh_of(db)
        d = min(signed_dist(bv, co[i]) for i in BASE) * 1000
        if d < target: lo = mid
        else: hi = mid
    place(uo, hi)
    return hi


def summary(bv):
    m = part_metrics(coords(), parts, bv, touch=0.0025)
    s = {"palm": (min(m[k][0] for k in ("heel", "palm01", "palm02", "palm03", "palm04")), sum(m[k][1] for k in ("heel", "palm01", "palm02", "palm03", "palm04")))}
    for f in ("thumb",) + hands.FINGERS:
        s[f] = tuple((m[f + i][0], m[f + i][1]) for i in ("01", "02", "03"))
    return s


def thumb_side(co):
    """Angle (deg) of the thumb tip around the handle axis, 0 = toward the palm, 180 = opposite the palm."""
    c = db.matrix_world.translation
    tip = co[max(parts["thumb03"], key=lambda i: (co[i] - KI).length)]
    v = tip - c; v -= AX * v.dot(AX)
    return round(math.degrees(v.angle(-n)), 1) if v.length > 1e-6 else 0.0


if A.get("probe") == "1":
    place_palm(UOS[0]); bv = bvh_of(db)
    for rx in (0, 20, 40, 60):
        for rz in (-20, 0, 20, 40, 60):
            p = copy.deepcopy(OPEN); p["thumb"].update(rx=rx, rz=rz); apply_all(p)
            co = coords()
            print("PROBE rx", rx, "rz", rz, "dmin", {k: round(min(signed_dist(bv, co[i]) for i in parts[k]) * 1000, 1) for k in ("thumb01", "thumb02", "thumb03")}, "side", thumb_side(co))
    sys.exit()

def segmin(co, f, bv):
    return [min(signed_dist(bv, co[i]) for i in parts[f + k]) * 1000 for k in ("01", "02", "03")]


def fit_fingers(pose, bv, mcps, tol=-0.8, CURL=110, DIP=70, DIPMAX=85):
    """Per finger: for each knuckle angle, close the middle and end joints together until the finger touches,
    then the end joint alone; keep the knuckle angle whose worst segment gap is smallest."""
    F = hands.FINGERS
    best = {f: None for f in F}

    def bis(setf, ok):
        lo = {f: 0.0 for f in F}; hi = {f: 1.0 for f in F}
        for _ in range(9):
            for f in F: setf(f, (lo[f] + hi[f]) / 2)
            apply_all(pose); co = coords()
            for f in F:
                if ok(co, f): lo[f] = (lo[f] + hi[f]) / 2
                else: hi[f] = (lo[f] + hi[f]) / 2
        for f in F: setf(f, lo[f])
        return lo
    for m in mcps:
        for f in F: pose[f].update(mcp=m, curl=0, dip=0)
        apply_all(pose); co = coords()
        valid = {f: min(segmin(co, f, bv)) >= tol for f in F}
        c = bis(lambda f, t: pose[f].update(curl=CURL * t, dip=DIP * t), lambda co, f: min(segmin(co, f, bv)) >= tol)
        d0 = {f: pose[f]["dip"] for f in F}
        bis(lambda f, t: pose[f].update(dip=d0[f] + (DIPMAX - d0[f]) * t), lambda co, f: segmin(co, f, bv)[2] >= tol)
        apply_all(pose); co = coords()
        for f in F:
            g = segmin(co, f, bv)
            if valid[f] and (best[f] is None or max(g) < best[f][0]):
                best[f] = (max(g), dict(pose[f]))
    for f in F:
        if best[f]: pose[f].update(best[f][1])
    apply_all(pose)
    return pose


results = []
for uo in UOS:
    pose = copy.deepcopy(OPEN); apply_all(pose)
    off = place_palm(uo); bv = bvh_of(db)
    if A.get("mode", "fit") == "fit":
        pose = fit_fingers(pose, bv, mcps=[20 + 2.5 * i for i in range(29)])
    else:
        pose = close_hand(apply_all, pose, coords, parts, bv, meta=False, stage1=S1, stage2_max=(110, 70), dip_cap=70)
    # the thumb wraps last and stops at the handle or at the fingers it crosses, whichever it meets first
    co = coords()
    fid = set(i for f in ("index", "middle") for k in ("02", "03") for i in parts[f + k])
    bvf = BVHTree.FromPolygons(co, [tuple(p.vertices) for p in B.data.polygons if all(v in fid for v in p.vertices)])

    def thumb_ok(tol=-0.8):
        co = coords()
        dh = min(signed_dist(bv, co[i]) for k in ("thumb01", "thumb02", "thumb03") for i in parts[k]) * 1000
        df = min([d for d in (signed_dist(bvf, co[i]) for i in parts["thumb03"]) if abs(d) < 0.008] or [9]) * 1000
        return dh >= tol and df >= tol
    for joint, lo, hi in (("curl", 0.0, 80.0), ("rx", TH[0], TH[0] + 40.0)):
        for _ in range(9):
            pose["thumb"][joint] = (lo + hi) / 2; apply_all(pose)
            if thumb_ok(): lo = pose["thumb"][joint]
            else: hi = pose["thumb"][joint]
        pose["thumb"][joint] = lo; apply_all(pose)
    s = summary(bv)
    co = coords()
    fid = set(i for f in ("index", "middle") for k in ("02", "03") for i in parts[f + k])
    bvf = BVHTree.FromPolygons(co, [tuple(p.vertices) for p in B.data.polygons if all(v in fid for v in p.vertices)])
    hand = set(i for k in parts for i in parts[k])
    rest_ids = [i for i in s2lib.REAL if i not in hand]
    print("CHECK thumb_into_fingers_mm", round(min([d for d in (signed_dist(bvf, co[i]) for i in parts["thumb03"]) if abs(d) < 0.008] or [9]) * 1000, 1),
          "body_to_dumbbell_mm", round(min(signed_dist(bv, co[i]) for i in rest_ids) * 1000, 1),
          "clothes_to_dumbbell_mm", round(min(signed_dist(bv, p) for p in mesh_points([o for o in rig.children if o.type == 'MESH' and o.name != "Human"])) * 1000, 1))
    print("FIT uo", uo, "off", round(off, 4), "palm", s["palm"], "thumb side", thumb_side(coords()), "rx/rz/curl", [round(pose["thumb"][k]) for k in ("rx", "rz", "curl")], "d", [x[0] for x in s["thumb"]])
    for f in hands.FINGERS:
        print("   ", f, "mcp/curl/dip", [round(pose[f][k]) for k in ("mcp", "curl", "dip")], "d", [x[0] for x in s[f]], "n", [x[1] for x in s[f]])
    results.append((uo, off, pose))
if A.get("render") == "1":
    uo, off, pose = results[-1]
    apply_all(pose); place(uo, off)
    tag = A.get("tag", "grip")
    # the dumbbell in the hand bone's space: any exercise places it as DEF-hand.L matrix @ DH and applies the pose
    DH = P["DEF-hand.L"].matrix.inverted() @ db.matrix_world
    json.dump({"pose": pose, "uo": uo, "off": off, "thumb0": TH, "DH": [list(r) for r in DH]}, open(f"{out}/{tag}_hand.json", "w"))
    c = db.matrix_world.translation.copy()
    views = [("out", Vector((1, 0, 0.15))), ("front", Vector((0.35, -1, 0.2))), ("in", Vector((-1, -0.6, 0.3))), ("below", Vector((-0.5, -1, -0.45))), ("in0", Vector((-1, -0.5, -0.15)))]
    views = [v for v in views if v[0] in A.get("views", "out,front,in,below,in0").split(",")]
    sc.eevee.taa_render_samples = int(A.get("samples", 16))
    if A.get("diag") == "1":   # handle only, so the axial view shows the wrap in section
        db.hide_render = True
        bpy.ops.mesh.primitive_cylinder_add(radius=DB["handle_r"], depth=DB["gap"], vertices=48)
        hc = bpy.context.active_object; hc.matrix_world = db.matrix_world.copy(); hc.data.materials.append(mat("h", (0.55, 0.55, 0.57), 0.35))
        views = [("axis", AX.copy()), ("front", Vector((0.35, -1, 0.2))), ("in", Vector((-1, -0.6, 0.3)))]
    for nm, d in views:
        aim_dir(cam, c + n * 0.012 - u * 0.01, d); cam.data.ortho_scale = float(A.get("scale", 0.17))
        render(f"{out}/{tag}_{nm}.png")
