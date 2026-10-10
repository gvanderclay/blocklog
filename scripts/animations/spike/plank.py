"""Forearm plank: rigid rotation of the standing body, forearms on the floor under the shoulders, toes curled under.
Usage: plank.py -- key=value ... (hs, toe, hx, feet, headpitch, out, views)"""
import sys, json, copy
sys.path.insert(0, "/tmp/blspike/s2")
from s2lib import *
import s2lib, hands
from closefit import close_hand

A = dict(hs=0.285, toe=80.0, hx=0.15, feet=0.11, headpitch=0.0, out="/tmp/blspike/s2/pk", views="front,side,tq",
         res=540, elbow_back=0.0, roll=-8.0, closeup=0)
for kv in sys.argv[sys.argv.index("--") + 1:]:
    k, v = kv.split("=")
    A[k] = type(A[k])(v) if not isinstance(A[k], str) else v
os.makedirs(A["out"], exist_ok=True)
rig, rest = open_fig(); P = rig.pose.bones; B = body(rig)
sc, cam = scene_setup(res=A["res"])
P["torso"]["head_follow"] = 1.0
P["torso"]["neck_follow"] = 1.0
floor = floor_line()
# a solid floor for contact queries (not rendered)
fq = s2lib._box("floorq", (6, 6, 0.2), (0, 0, -0.1), mat("fq", (1, 1, 1)), 0); fq.hide_render = True
bvh_floor = bvh_of(fq)

piv = rest["torso"].translation.copy()
LEG = (rest["ORG-thigh.L"].translation - rest["ORG-shin.L"].translation).length + (rest["ORG-shin.L"].translation - rest["ORG-foot.L"].translation).length
S0 = rest["ORG-upper_arm.L"].translation.copy()
BALL0 = rest["ORG-toe.L"].translation.copy()
hb = 0.016                                   # ball-of-foot joint height above the floor
dy, dz = S0.y - BALL0.y, S0.z - BALL0.z
rr, ph = math.hypot(dy, dz), math.atan2(dy, dz)
TH = ph + math.acos((A["hs"] - hb) / rr)     # body rotation that puts shoulder at hs and ball at hb
R = Matrix.Rotation(TH, 4, 'X')
def rot(p):
    return piv + (R.to_3x3() @ (Vector(p) - piv))
tz = A["hs"] - rot(S0).z
T = Matrix.Translation((0, -rot(S0).y + 0.0, tz))   # shoulder line at y=0
BODY = T @ Matrix.Translation(piv) @ R @ Matrix.Translation(-piv)
print("BODY_ROT_DEG", round(math.degrees(TH), 2), "incline", round(90 - math.degrees(TH), 2))

parts = {s: hand_parts(B, s) for s in "LR"}
state = {"pose": copy.deepcopy(hands.POSES["flat"]), "hand": {}}
for f in hands.FINGERS:   # start slightly extended so the closure settles every finger onto the floor
    state["pose"][f].update(mcp=-25.0, curl=0.0, dip=0.0)
state["pose"]["thumb"].update(rx=12.0, rz=-30.0, curl=0.0)


def pose_body():
    reset(rig)
    P["torso"].matrix = BODY @ rest["torso"]
    for s, sx in (("L", 1), ("R", -1)):
        # feet closer (hip width), then the same rigid rotation keeps the legs straight and in line
        M = rest["foot_ik." + s].copy(); M.translation.x = sx * A["feet"]
        hip = rest["ORG-thigh." + s].translation
        M.translation = hip + (M.translation - hip).normalized() * (LEG - 0.003)   # knees straight
        P["foot_ik." + s].matrix = BODY @ M
        Mp = rest["thigh_ik_target." + s].copy(); Mp.translation.x = sx * A["feet"]
        P["thigh_ik_target." + s].matrix = BODY @ Mp
    upd()
    for s in "LR":   # toes curled under: extend at the ball of the foot
        P["toe_ik." + s].rotation_euler = (math.radians(A["toe"]), 0, 0)
    P["head"].rotation_quaternion = Quaternion(Vector((1, 0, 0)), math.radians(A["headpitch"]))
    upd()


def hand_matrix(s, off):
    u = Vector((0, -1, 0)); Rr = Matrix.Rotation(math.radians(A["roll"]), 3, u)
    n = Rr @ Vector((0, 0, -1)); r = n.cross(u)                            # palm down, fingers forward, rolled level
    M = Matrix((n, u, r)).transposed().to_4x4()
    shoulder = P["ORG-upper_arm.L"].head
    M.translation = Vector((A["hx"], shoulder.y - 0.235, 0.03 + off))
    return M if s == "L" else mirror(M)


def apply_arms(pose):
    for s, sx in (("L", 1), ("R", -1)):
        P["hand_ik." + s].matrix = state["hand"][s]
        hands.apply(rig, s, pose)
        sh = P["ORG-upper_arm." + s].head
        M = rest["upper_arm_ik_target." + s].copy()
        M.translation = Vector((sx * (A["hx"] + 0.15), sh.y + 0.35 + A["elbow_back"], -0.25)); P["upper_arm_ik_target." + s].matrix = M
    upd()


pose_body()
# hands: lower onto the floor until the palm touches, then let the fingers settle onto it
for s in "LR":
    state["hand"][s] = hand_matrix(s, 0.0)
PALM = {s: [i for k in ("heel", "palm01", "palm02", "palm03", "palm04") for i in parts[s][k]] for s in "LR"}
lo, hi = -0.03, 0.05
for _ in range(14):
    mid = (lo + hi) / 2
    for s in "LR": state["hand"][s] = hand_matrix(s, mid)
    apply_arms(state["pose"])
    co = eval_coords(B)
    d = min(signed_dist(bvh_floor, co[i]) for s in "LR" for i in PALM[s]) * 1000
    if d < -0.5: lo = mid
    else: hi = mid
for s in "LR": state["hand"][s] = hand_matrix(s, hi)
apply_arms(state["pose"])
coords = lambda: eval_coords(B)
from closefit import close_thumb
pose = close_hand(lambda p: apply_arms(p), state["pose"], coords, parts["L"], bvh_floor, stage1=(45, 24, 14), stage2_max=(26, 16), dip_cap=16)
pose = close_thumb(lambda p: apply_arms(p), pose, coords, parts["L"], bvh_floor, joints=(("rz", -50, 20), ("curl", 0, 25)))
state["pose"] = pose
apply_arms(pose)

# ---- report
hd = lambda n: P[n].head.copy()
co = eval_coords(B)
cloth = [o for o in rig.children if o.type == 'MESH' and o.name != "Human"][0]
cco = eval_coords(cloth)
allz = [co[i].z for i in s2lib.REAL] + [p.z for p in cco]
fore = group_vertices(B, ("DEF-forearm.",), 0.4)
toes = group_vertices(B, ("DEF-toe",), 0.3)
shoulder, elbow, wrist = hd("ORG-upper_arm.L"), hd("ORG-forearm.L"), hd("ORG-hand.L")
hipc = (hd("ORG-thigh.L") + hd("ORG-thigh.R")) / 2
sh_c = (hd("ORG-upper_arm.L") + hd("ORG-upper_arm.R")) / 2
ank_c = (hd("ORG-foot.L") + hd("ORG-foot.R")) / 2
headtop = hd("ORG-spine.006") + P["ORG-spine.006"].matrix.col[1].to_3d() * 0.20
line = (ank_c - sh_c).normalized()
def off_line(p):   # + = above the shoulder-ankle line (pike), - = below (sag)
    v = p - sh_c; perp = v - line * v.dot(line); return perp.z / abs(perp.z) * perp.length if perp.length > 1e-6 else 0
neck_dir = (hd("ORG-spine.006") - hd("ORG-spine.005")).normalized()
trunk_dir = (sh_c - hipc).normalized()
print(f"PLANK: shoulder_z {shoulder.z:.3f} elbow {tuple(round(c,3) for c in elbow)} shoulder {tuple(round(c,3) for c in shoulder)} "
      f"elbow_under_shoulder_dy {(elbow.y - shoulder.y)*100:+.1f}cm dx {(elbow.x - shoulder.x)*100:+.1f}cm wrist_z {wrist.z:.3f}")
print(f"LINE: hip_off {off_line(hipc)*100:+.1f}cm (- sag, + pike) head_off {off_line(headtop)*100:+.1f}cm knee_off {off_line((hd('ORG-shin.L')+hd('ORG-shin.R'))/2)*100:+.1f}cm "
      f"neck_vs_trunk {math.degrees(neck_dir.angle(trunk_dir)):.1f}deg")
print(f"FLOOR: min_z {min(allz)*1000:.1f}mm forearm_min_z {min(co[i].z for i in fore)*1000:.1f}mm forearm_touch {sum(1 for i in fore if co[i].z < 0.003)} "
      f"toes_min_z {min(co[i].z for i in toes)*1000:.1f}mm toes_touch {sum(1 for i in toes if co[i].z < 0.003)}")
for s in "LR":
    m = part_metrics(co, parts[s], bvh_floor)
    fing = {f: (min(m[f + n][0] for n in ("01", "02", "03")), sum(m[f + n][1] for n in ("01", "02", "03"))) for f in ("thumb", "index", "middle", "ring", "pinky")}
    print(f"HAND {s}: reach_err {(P['DEF-hand.'+s].head - P['hand_ik.'+s].head).length*1000:.2f}mm palm {[m[k] for k in ('heel','palm01','palm02','palm03','palm04')]} {fing}")
print("POSE", {k: ({p: round(x, 1) for p, x in v.items()} if isinstance(v, dict) else v) for k, v in pose.items()})
json.dump({"pose": pose}, open(A["out"] + "/plank_hand.json", "w"))

if A["views"]:
    pts = mesh_points([o for o in rig.children if o.type == 'MESH'])
    for v in A["views"].split(","):
        az, el = dict(front=(0, 0), side=(90, 0), tq=(-55, 12))[v]
        aim(cam, Vector((0, 0, 0.2)), az, el)
        frame_to(cam, pts, fill=0.8)
        floor.hide_render = (v == "tq")
        render(f"{A['out']}/{v}.png")

if A["closeup"]:   # the left hand flat on the floor, for the hand close-up sheet
    floor.hide_render = False
    c = (P["DEF-hand.L"].head + P["DEF-hand.L"].tail) / 2 + Vector((0, 0, 0.02))
    for nm, az, el in (("front", 45, 20), ("above", 100, 55)):
        aim(cam, c, az, el); cam.data.ortho_scale = 0.26
        render(f"{A['out']}/hand_{nm}.png")
