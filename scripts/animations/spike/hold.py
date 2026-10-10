"""Fit the goblet hold. Usage: hold.py -- "beta,py,pz;..." tag"""
import sys; sys.path.insert(0, "/tmp/blspike/s2")
from s2lib import *
import hands, copy
from closefit import close_hand, close_thumb
a = sys.argv[sys.argv.index("--") + 1:]
CONFIGS = [tuple(float(x) for x in c.split(",")) for c in a[0].split(";")]; TAG = a[1] if len(a) > 1 else "t"
rig, rest = open_fig(); P = rig.pose.bones; B = body(rig)
sc, cam = scene_setup(res=540)
db = dumbbell(rails=-1)
pts = mesh_points([o for o in rig.children if o.type == 'MESH'])
chest_y = min(p.y for p in pts if abs(p.x) < 0.05 and 1.18 < p.z < 1.30)
W, Dd, L, G = DB["stack_w"], DB["stack_d"], DB["stack_len"], DB["gap"]
zb = G / 2
D = Matrix.Translation((0, chest_y - 0.035 - Dd / 2, 1.40 - (G / 2 + L))); db.matrix_world = D
bvh_db = bvh_of(db)
parts = hand_parts(B, "L")
FING = {"index": "index", "middle": "middle", "ring": "ring", "pinky": "pinky"}

def hand_local(beta, off, py, pz):
    b = math.radians(beta)
    n = Vector((-math.cos(b), 0, math.sin(b))); u = Vector((math.sin(b), 0, math.cos(b))); r = n.cross(u)
    M = Matrix((n, u, r)).transposed().to_4x4()
    M.translation = Vector((W / 2 + 0.012, py, zb + pz)) + n * off
    return M

state = {}
def apply_all(pose):
    P["hand_ik.L"].matrix = D @ state["ML"]; P["hand_ik.R"].matrix = D @ mirror(state["ML"])
    hands.apply(rig, "L", pose); hands.apply(rig, "R", pose)
    for s_, sx in (("L", 1), ("R", -1)):
        M = rest["upper_arm_ik_target." + s_].copy(); M.translation = Vector((sx * 0.30, 0.05, 0.75)); P["upper_arm_ik_target." + s_].matrix = M
    upd()
coords = lambda: eval_coords(B)
def summary(co):
    m = part_metrics(co, parts, bvh_db)
    out = {"heel": m["heel"], "palm": (min(m[k][0] for k in ("palm01", "palm02", "palm03", "palm04")), sum(m[k][1] for k in ("palm01", "palm02", "palm03", "palm04")))}
    for f in ("thumb", "index", "middle", "ring", "pinky"):
        out[f] = (min(m[f + n][0] for n in ("01", "02", "03")), sum(m[f + n][1] for n in ("01", "02", "03")))
    return out

PALM = [i for k in ("heel", "palm01", "palm02", "palm03", "palm04") for i in parts[k]]
PLACE = PALM + parts["thumb01"]
def place_palm(beta, py, pz, pose, ids, target=-0.5):
    lo, hi = -0.04, 0.04
    for _ in range(14):
        mid = (lo + hi) / 2; state["ML"] = hand_local(beta, mid, py, pz); apply_all(pose)
        co = coords(); d = min(signed_dist(bvh_db, co[i]) for i in ids) * 1000
        if d < target: hi = mid
        else: lo = mid
    state["ML"] = hand_local(beta, lo, py, pz); apply_all(pose)
    return lo

for ci, (BETA, PY, PZ, TRX) in enumerate(CONFIGS):
    pose = copy.deepcopy(hands.OPEN); pose["palm"] = (0, 8); pose["thumb"]["rx"] = TRX; pose["thumb"]["rz"] = -40
    off = place_palm(BETA, PY, PZ, pose, PLACE)
    print("CONFIG", ci, BETA, PY, PZ, TRX, "OFF", round(off, 4), "OPEN", summary(coords()))
    pose = close_hand(apply_all, pose, coords, parts, bvh_db)
    pose = close_thumb(apply_all, pose, coords, parts, bvh_db)
    print("FINAL", ci, summary(coords()))
    print("POSE", ci, {k: ({p: round(x, 1) for p, x in v.items()} if isinstance(v, dict) else v) for k, v in pose.items()})
    print("ML", ci, [list(map(lambda x: round(x, 5), row)) for row in state["ML"]])
    ctr = D @ Vector((0, 0, G / 2 + L / 2 - 0.02))
    for nm, az, el_ in (("front", 0, 0), ("side", 90, 0), ("tq", -35, 15), ("back", 160, 20)):
        aim(cam, ctr, az, el_); cam.data.ortho_scale = 0.36
        render(f"/tmp/blspike/s2/hold_{TAG}{ci}_{nm}.png")
    import json
    json.dump({"ML": [list(r) for r in state["ML"]], "pose": pose, "config": [BETA, PY, PZ, TRX]}, open(f"/tmp/blspike/s2/hold_{TAG}{ci}.json", "w"))
