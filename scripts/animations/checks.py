"""The pose checks (docs/exercise-animations.md section 8), as pure functions on sampled frames. render.py samples
every frame 1…N+1 into a Sample, and any failure stops the run before rendering. The tolerances are engineering
thresholds, not medical limits.

Form metrics, named in a pose file's "jointRanges" (every frame) and "form" (the frames keyed with that pose).
A ".L" or ".R" suffix picks the side. Angles in degrees, distances in centimetres:
  kneeFlex, hipFlex, elbowFlex   0 = straight; hipFlex is the thigh against the trunk line
  armToTrunk                     upper arm against the trunk's downward line: 0 at the sides, 90 forward or out
  trunkLean, shinLean            from vertical; trunkMinusShin = trunkLean - shinLean.L (<= 0: trunk no more
                                 inclined than the shins, as in a squat with the chest up)
  hipOverKnee                    hip joint height over the knee joint; negative = below (squat depth)
  kneeOverFoot                   the knee's sideways offset from its foot's line, + = outward
  elbowInsideKnee                |knee x| - |elbow x|, + = elbow inside the knee
  bodyLine, headLine             hip centre and head top off the shoulder-ankle line, + = above (pike), - = sag
  elbowUnderShoulder             horizontal distance from elbow to shoulder
  wristOverElbow                 horizontal distance from wrist to elbow (a vertical forearm reads 0)
  neckToTrunk                    the head bone against the trunk line
"""
import math

from mathutils import Vector

UP = Vector((0, 0, 1))

# The joints a Sample records, from Rigify's ORG bones: name -> (bone, end).
JOINTS = {"neck": ("ORG-spine.005", "head"), "skull": ("ORG-spine.006", "head"), "headTop": ("ORG-spine.006", "tail")}
for _s in "LR":
    JOINTS.update({
        "hip." + _s: ("ORG-thigh." + _s, "head"), "knee." + _s: ("ORG-shin." + _s, "head"),
        "ankle." + _s: ("ORG-foot." + _s, "head"), "ball." + _s: ("ORG-toe." + _s, "head"),
        "shoulder." + _s: ("ORG-upper_arm." + _s, "head"), "elbow." + _s: ("ORG-forearm." + _s, "head"),
        "wrist." + _s: ("ORG-hand." + _s, "head")})

# A planted name -> the joints that must stay put.
PLANTED = {"foot": ("ankle", "ball"), "ball": ("ball",), "forearm": ("elbow", "wrist"), "hand": ("wrist",)}

SLIDE = 0.01        # a planted joint moves at most 1 cm
REACH = 0.01        # a held hand ends at most 1 cm from its target on the prop
FLOOR = -0.005      # no vertex below -0.5 cm
DEPTH = 0.002       # body into a prop, unless allowedContacts says more
HAND_DEPTH = 0.003  # a holding hand into its prop
SEAM_JOINT = 0.001  # frame N+1 repeats frame 1
MARGIN = 0.02       # the figure stays this far inside the frame


class Sample:
    """One evaluated frame: joints (name -> Vector), hand reach error per held side (m), the lowest vertex (m),
    the deepest penetration per prop as (metres, where), and the figure's box in the clip camera (0…1)."""

    def __init__(self, frame, joints, reach, floor, depth, box):
        self.frame, self.joints, self.reach, self.floor, self.depth, self.box = frame, joints, reach, floor, depth, box


def _angle(a, b):
    return math.degrees(a.angle(b)) if a.length > 1e-9 and b.length > 1e-9 else 0.0


def _flat(v):
    return Vector((v.x, v.y, 0))


def metric(name, j):
    base, _, side = name.partition(".")
    s = lambda n: j[n + "." + side]
    hip_c = (j["hip.L"] + j["hip.R"]) / 2
    trunk = j["neck"] - hip_c
    if base == "kneeFlex":
        return 180 - _angle(s("hip") - s("knee"), s("ankle") - s("knee"))
    if base == "hipFlex":
        return 180 - _angle(trunk, s("knee") - s("hip"))
    if base == "elbowFlex":
        return 180 - _angle(s("shoulder") - s("elbow"), s("wrist") - s("elbow"))
    if base == "armToTrunk":
        return _angle(s("elbow") - s("shoulder"), -trunk)
    if base == "trunkLean":
        return _angle(trunk, UP)
    if base == "shinLean":
        return _angle(s("knee") - s("ankle"), UP)
    if base == "trunkMinusShin":
        return _angle(trunk, UP) - _angle(j["knee.L"] - j["ankle.L"], UP)
    if base == "hipOverKnee":
        return (s("hip").z - s("knee").z) * 100
    if base == "kneeOverFoot":
        foot = _flat(s("ball") - s("ankle")).normalized()
        rel = _flat(s("knee") - s("ankle"))
        off = rel - foot * rel.dot(foot)
        outward = 1 if (off.x >= 0) == (side == "L") else -1
        return outward * off.length * 100
    if base == "elbowInsideKnee":
        return (abs(s("knee").x) - abs(s("elbow").x)) * 100
    if base in ("bodyLine", "headLine"):
        sh = (j["shoulder.L"] + j["shoulder.R"]) / 2
        line = ((j["ankle.L"] + j["ankle.R"]) / 2 - sh).normalized()
        v = (hip_c if base == "bodyLine" else j["headTop"]) - sh
        perp = v - line * v.dot(line)
        return math.copysign(perp.length, perp.z) * 100
    if base == "elbowUnderShoulder":
        return _flat(s("elbow") - s("shoulder")).length * 100
    if base == "wristOverElbow":
        return _flat(s("wrist") - s("elbow")).length * 100
    if base == "neckToTrunk":
        return _angle(j["headTop"] - j["skull"], trunk)
    raise KeyError(f"unknown metric {name}")


def run(spec, samples):
    """Every check's failures, as lines naming the check, the frame and the value. Empty when all pass."""
    fails = []
    by = {s.frame: s for s in samples}
    n = spec["frames"]
    first, last = by[1], by[n + 1]

    # Loop seam: frame N+1 repeats frame 1, and the step into it is like its neighbours' steps.
    def step(a, b):
        return max((by[b].joints[k] - by[a].joints[k]).length for k in by[a].joints)
    gap = max((last.joints[k] - first.joints[k]).length for k in first.joints)
    if gap > SEAM_JOINT:
        fails.append(f"loop seam: frame {n + 1} differs from frame 1 by {gap * 100:.1f} cm")
    seam, around = step(n, n + 1), max(step(n - 1, n), step(1, 2))
    if seam > 1.5 * around + 0.002:
        fails.append(f"loop seam: the step from frame {n} to 1 is {seam * 100:.1f} cm, its neighbours "
                     f"{around * 100:.1f} cm")

    # Planted joints stay put.
    for planted in spec["planted"]:
        kind, _, side = planted.partition(".")
        for joint in PLANTED[kind]:
            name = joint + "." + side
            worst = max(samples, key=lambda s: (s.joints[name] - first.joints[name]).length)
            d = (worst.joints[name] - first.joints[name]).length
            if d > SLIDE:
                fails.append(f"foot slide: {planted} ({name}) moves {d * 100:.1f} cm by frame {worst.frame}")

    # Per-frame checks report their worst frame only.
    allowed = spec.get("allowedContacts", {})
    worst = {}

    def note(key, amount, line):
        if amount > worst.get(key, (0, ""))[0]:
            worst[key] = (amount, line)
    for s in samples:
        for side, err in s.reach.items():
            if err > REACH:
                note("grip" + side, err, f"grip: hand.{side} is {err * 100:.1f} cm off its hold at frame {s.frame}")
        if s.floor < FLOOR:
            note("floor", -s.floor, f"floor: a vertex is {-s.floor * 100:.1f} cm below the floor at frame {s.frame}")
        for prop, (depth, where) in s.depth.items():
            limit = HAND_DEPTH if where.startswith("hand") else DEPTH
            limit = max(limit, allowed.get(prop, 0))
            if depth > limit:
                note(prop, depth, f"interpenetration: {where} is {depth * 1000:.1f} mm into {prop} at frame {s.frame}")
        x0, y0, x1, y1 = s.box
        out = max(MARGIN - min(x0, y0), max(x1, y1) - 1 + MARGIN)
        if out > 0:
            note("framing", out, f"framing: the figure leaves the frame's margin at frame {s.frame}")
    fails += [line for _, line in worst.values()]

    for name, (lo, hi) in spec.get("jointRanges", {}).items():
        for s in samples:
            v = metric(name, s.joints)
            if not lo <= v <= hi:
                fails.append(f"joint range: {name} {v:.1f} outside [{lo}, {hi}] at frame {s.frame}")
                break

    keyed = {}
    for k in spec["keys"]:
        keyed.setdefault(k["pose"], []).append(k["frame"])
    for pose, rules in spec.get("form", {}).items():
        for frame in keyed.get(pose, []):
            for name, (lo, hi) in rules.items():
                v = metric(name, by[frame].joints)
                if not lo <= v <= hi:
                    fails.append(f"form: {pose} {name} {v:.1f} outside [{lo}, {hi}] at frame {frame}")
    return fails


def report(spec, samples):
    """Every form and range metric at each key frame, for the author."""
    names = sorted(set(spec.get("jointRanges", {})) | {n for r in spec.get("form", {}).values() for n in r})
    by = {s.frame: s for s in samples}
    lines = []
    for k in spec["keys"]:
        s = by[k["frame"]]
        values = " ".join(f"{n} {metric(n, s.joints):.1f}" for n in names)
        lines.append(f"frame {k['frame']:3d} {k['pose']}: {values}")
    for prop in samples[0].depth:
        worst = max(samples, key=lambda s: s.depth[prop][0])
        depth, where = worst.depth[prop]
        lines.append(f"deepest into {prop}: {where or 'nothing'} {depth * 1000:.1f} mm at frame {worst.frame}")
    lines.append(f"lowest vertex: {min(s.floor for s in samples) * 1000:.1f} mm")
    return lines
