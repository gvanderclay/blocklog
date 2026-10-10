"""Goblet squat: top and bottom poses, form numbers, review renders, optional baked loop.
Usage: squat.py -- key=value ...   (shin, femur, lean, chest, stance, toe, tilt, out, frames)"""
import sys, json
sys.path.insert(0, "/tmp/blspike/s2")
from s2lib import *
import s2lib
import hands

A = dict(shin=34.0, femur=6.0, lean=-1.0, chest=-8.0, stance=0.20, toe=20.0, tilt=0.5, gap=0.035,
         out="/tmp/blspike/s2/sq", frames=0, views="front,side,tq", headf=0.5, kout=0.0, neckf=0.5, headpitch=0.0, poses="0,1", res=540, closeup=0)
for kv in sys.argv[sys.argv.index("--") + 1:]:
    k, v = kv.split("=")
    A[k] = type(A[k])(v) if not isinstance(A[k], str) else v
os.makedirs(A["out"], exist_ok=True)

rig, rest = open_fig(); P = rig.pose.bones; B = body(rig)
sc, cam = scene_setup(res=A["res"])
db = dumbbell(rails=-1)
HOLD = json.load(open("/tmp/blspike/s2/hold_f0.json"))
ML = Matrix(HOLD["ML"]); GPOSE = HOLD["pose"]
W, Dd, L, G = DB["stack_w"], DB["stack_d"], DB["stack_len"], DB["gap"]
pts0 = mesh_points([o for o in rig.children if o.type == 'MESH'])
chest_y = min(p.y for p in pts0 if abs(p.x) < 0.05 and 1.18 < p.z < 1.30)
D_REST = Matrix.Translation((0, chest_y - A["gap"] - Dd / 2, 1.40 - (G / 2 + L)))
C_REST = rest["chest"].copy()
LT = (rest["ORG-thigh.L"].translation - rest["ORG-shin.L"].translation).length
LS = (rest["ORG-shin.L"].translation - rest["ORG-foot.L"].translation).length
HIP0 = rest["ORG-thigh.L"].translation.copy()
ANK0 = rest["foot_ik.L"].translation.copy()
rig.pose.bones["torso"]["head_follow"] = A["headf"]
rig.pose.bones["torso"]["neck_follow"] = A["neckf"]

toe = math.radians(A["toe"])
FDIR = Vector((math.sin(toe), -math.cos(toe), 0))         # left foot's horizontal direction
ANK = Vector((A["stance"], ANK0.y, ANK0.z))


def bottom_targets():
    th = math.radians(A["shin"])
    K = ANK + LS * (math.sin(th) * FDIR + Vector((0, 0, math.cos(th))))
    dz = -LT * math.sin(math.radians(A["femur"]))
    dx = HIP0.x - K.x
    dy = math.sqrt(max(LT ** 2 - dx ** 2 - dz ** 2, 0))
    return K, Vector((HIP0.x, K.y + dy, K.z + dz))


KB, HB = bottom_targets()
LEAN_B = A["lean"] if A["lean"] >= 0 else A["shin"] - 2.0   # trunk line already leans ~2 deg at rest
HT = Vector((HIP0.x, HIP0.y, HIP0.z - 0.012))                # top: knees just off lock


def pose(s):
    """s = 0 standing, 1 bottom."""
    reset(rig)
    for side, sx in (("L", 1), ("R", -1)):
        M = rest["foot_ik." + side].copy()
        R = Matrix.Rotation(sx * toe, 4, 'Z')
        a = Vector((sx * A["stance"], ANK0.y, ANK0.z))
        P["foot_ik." + side].matrix = Matrix.Translation(a) @ R @ Matrix.Translation(-M.translation) @ M
    # hips travel back and the trunk leans early in the descent, as in a real squat; depth is linear
    sy, sl = s ** 0.6, s ** 0.7
    hip = Vector((HT.x, HT.y + (HB.y - HT.y) * sy, HT.z + (HB.z - HT.z) * s))
    lean = LEAN_B * sl
    # rotate torso about its head, then move it so the left hip joint lands on target
    Mt = rest["torso"]; piv = Mt.translation
    R = Matrix.Rotation(math.radians(lean), 4, 'X')
    hip_rot = piv + (R.to_3x3() @ (HIP0 - piv))
    d = hip - hip_rot
    P["torso"].matrix = Matrix.Translation(d) @ Matrix.Translation(piv) @ R @ Matrix.Translation(-piv) @ Mt
    upd()
    place(rig, rest, "chest", rot=(0, 0, 0))
    Cm = P["chest"].matrix.copy()
    P["chest"].matrix = Matrix.Translation(Cm.translation) @ Matrix.Rotation(math.radians(A["chest"] * s), 4, 'X') @ Matrix.Translation(-Cm.translation) @ Cm
    upd()
    P["head"].rotation_quaternion = Quaternion(Vector((1, 0, 0)), math.radians(A["headpitch"] * s))
    # knees: pole in front of the desired knee along the toes
    for side, sx in (("L", 1), ("R", -1)):
        K = HT.lerp(KB, 1) if False else None
        ank = Vector((sx * A["stance"], ANK0.y, ANK0.z))
        fd = Vector((sx * FDIR.x, FDIR.y, 0))
        pole = ank + fd * 0.9 + Vector((sx * A['kout'], 0, 0.45))
        M = rest["thigh_ik_target." + side].copy(); M.translation = pole; P["thigh_ik_target." + side].matrix = M
    # dumbbell follows the chest, tilting by part of its lean
    F = P["chest"].matrix @ C_REST.inverted()
    ang = F.to_euler().x
    pos = F @ D_REST.translation
    D = Matrix.Translation(pos) @ Matrix.Rotation(ang * A["tilt"], 4, 'X')
    db.matrix_world = D
    P["hand_ik.L"].matrix = D @ ML
    P["hand_ik.R"].matrix = D @ mirror(ML)
    hands.apply(rig, "L", GPOSE); hands.apply(rig, "R", GPOSE)
    for side, sx in (("L", 1), ("R", -1)):
        pr = F @ Vector((sx * 0.30, 0.05, 0.75))
        M = rest["upper_arm_ik_target." + side].copy(); M.translation = pr; P["upper_arm_ik_target." + side].matrix = M
    upd()
    return D


SEG = [("ORG-spine.006", .081)] + [(n, .497 * w) for n, w in (("ORG-spine", .22), ("ORG-spine.001", .1), ("ORG-spine.002", .12), ("ORG-spine.003", .25), ("ORG-spine.004", .31))]
for s_ in "LR":
    SEG += [("ORG-upper_arm." + s_, .028), ("ORG-forearm." + s_, .016), ("ORG-hand." + s_, .006), ("ORG-thigh." + s_, .1), ("ORG-shin." + s_, .0465), ("ORG-foot." + s_, .0145)]


def report(tag, D):
    hd = lambda n: P[n].head.copy()
    hipc = (hd("ORG-thigh.L") + hd("ORG-thigh.R")) / 2
    neck = hd("ORG-spine.005")
    trunk = math.degrees((neck - hipc).angle(Vector((0, 0, 1))))
    knee, ank, hip = hd("ORG-shin.L"), hd("ORG-foot.L"), hd("ORG-thigh.L")
    shin = math.degrees((knee - ank).angle(Vector((0, 0, 1))))
    kflex = 180 - math.degrees((hip - knee).angle(ank - knee))
    femur = math.degrees(math.asin((hip.z - knee.z) / (hip - knee).length))
    rel = (knee - ank); rel.z = 0
    fd = Vector((FDIR.x, FDIR.y, 0))
    lateral = rel.dot(Vector((-fd.y, fd.x, 0)))   # + = outside the foot line (left foot: toward -x... sign checked below)
    off_line = (rel - fd * rel.dot(fd)).length * (1 if (rel - fd * rel.dot(fd)).x >= 0 else -1)
    elb = hd("ORG-forearm.L")
    mass = sum(m for _, m in SEG) + 0.2
    com = sum(((P[n].head + P[n].tail) / 2 * m for n, m in SEG), Vector()) + D.translation * 0.2
    com /= mass
    heel_y = ANK0.y + 0.07
    ball = ank + Vector((FDIR.x, FDIR.y, 0)) * 0.12
    pts = mesh_points([o for o in rig.children if o.type == 'MESH'])
    minz = min(p.z for p in pts)
    print(f"FORM {tag}: trunk {trunk:.1f} shin {shin:.1f} knee_flex {kflex:.1f} femur_vs_horiz {femur:+.1f} (neg = hip below knee) "
          f"hip_z {hip.z:.3f} knee_z {knee.z:.3f} hip_y {hip.y:+.3f} ankle_y {ank.y:+.3f} knee_off_foot_line {off_line*100:+.1f}cm "
          f"elbow_x {elb.x:.3f} knee_x {knee.x:.3f} elbow_z {elb.z:.3f} COM_y {com.y:+.3f} (heel {heel_y:+.3f} ball {ball.y:+.3f}) minz {minz*1000:.1f}mm")
    # grip and prop clearance
    bvh = bvh_of(db); co = eval_coords(B)
    partsL = hand_parts(B, "L"); partsR = hand_parts(B, "R")
    for side, parts in (("L", partsL), ("R", partsR)):
        m = part_metrics(co, parts, bvh)
        fing = {f: (min(m[f + n][0] for n in ("01", "02", "03")), sum(m[f + n][1] for n in ("01", "02", "03"))) for f in ("thumb", "index", "middle", "ring", "pinky")}
        reach = (P["DEF-hand." + side].head - P["hand_ik." + side].head).length * 1000
        print(f"GRIP {tag} {side}: reach_err {reach:.2f}mm heel {m['heel']} palm {[m[k] for k in ('palm01', 'palm02', 'palm03', 'palm04')]} {fing}")
    handset = set(i for ps in (partsL, partsR) for k in ps for i in ps[k])
    fore = set(group_vertices(B, ("DEF-forearm.",), 0.3))
    bodyd = min(signed_dist(bvh, co[i]) for i in s2lib.REAL if i not in handset and i not in fore)
    cloth = [o for o in rig.children if o.type == 'MESH' and o.name != "Human"][0]
    clothd = min(signed_dist(bvh, p) for p in eval_coords(cloth))
    print(f"PROP {tag}: body_min_dist {bodyd*1000:.1f}mm shirt_min_dist {clothd*1000:.1f}mm")


floor = floor_line()
states = {}
for s in [float(x) for x in A["poses"].split(",")]:
    D = pose(s)
    report(f"s={s}", D)
    states[s] = D

if A["views"]:
    # one camera framing for all poses: union of the visible points
    allpts = []
    for s in states:
        pose(s); allpts += mesh_points([o for o in rig.children if o.type == 'MESH'] + [db])
    for v in A["views"].split(","):
        az, el = dict(front=(0, 0), side=(90, 0), tq=(-35, 8))[v]
        aim(cam, Vector((0, 0, 0.85)), az, el)
        frame_to(cam, allpts, fill=0.8)
        for s in states:
            pose(s)
            floor.hide_render = (v == "tq")
            render(f"{A['out']}/{v}_s{s:.1f}.png")

if A["closeup"]:   # the goblet hold at the squat bottom, for the hand close-up sheet
    D = pose(1.0); floor.hide_render = True
    c = D @ Vector((0, 0, G / 2 + L / 2 - 0.01))
    for nm, az, el in (("front", -25, 12), ("above", 40, 45)):
        aim(cam, c, az, el); cam.data.ortho_scale = 0.42
        render(f"{A['out']}/hold_{nm}.png")

if A["frames"]:
    floor.hide_render = True
    N = A["frames"]
    def s_of(f):   # 1-based frame -> squat depth, lower 1.2 s, pause, rise 0.8 s, pause (at 30 fps for 72 frames)
        x = (f - 1) / N
        if x < 0.5: u = x / 0.5; return 0.5 - 0.5 * math.cos(math.pi * u)
        if x < 0.583: return 1.0
        if x < 0.917: u = (x - 0.583) / 0.334; return 0.5 + 0.5 * math.cos(math.pi * u)
        return 0.0
    allpts = []
    for s in (0.0, 1.0):
        pose(s); allpts += mesh_points([o for o in rig.children if o.type == 'MESH'] + [db])
    aim(cam, Vector((0, 0, 0.85)), -35, 8); frame_to(cam, allpts, fill=0.8)
    os.makedirs(A["out"] + "/frames", exist_ok=True)
    t0 = time.time()
    for f in range(1, N + 1):
        pose(s_of(f))
        render(f"{A['out']}/frames/{f:04d}.png")
    print("LOOP_SECONDS", round(time.time() - t0, 1))
