"""Grasp closure on the Rigify finger controls: each finger flexes until it touches the target, never penetrating.

Stage 1 closes knuckle, middle and end joints together in the ratio of a natural curl.
Stage 2 keeps the knuckle and closes the middle and end joints.
Stage 3 closes the end joint alone (capped). Each stage only checks the segments it moves.
"""
from s2lib import *
import hands


def _bisect(fingers, set_fn, check_fn, iters=9):
    lo = {f: 0.0 for f in fingers}
    hi = {f: 1.0 for f in fingers}
    for _ in range(iters):
        t = {f: (lo[f] + hi[f]) / 2 for f in fingers}
        set_fn(t)
        ok = check_fn()
        for f in fingers:
            if ok[f]:
                lo[f] = t[f]
            else:
                hi[f] = t[f]
    set_fn(lo)
    return lo


def close_hand(apply_all, pose, coords_fn, parts, bvh, tol=-0.8, fingers=hands.FINGERS,
               stage1=(70, 55, 35), stage2_max=(100, 60), dip_cap=60, meta=True):
    META = dict(index="palm01", middle="palm02", ring="palm03", pinky="palm04")

    def dmin(f, segs, co):
        ids = [i for n in segs for i in (parts[META[f]] if n == "meta" else parts[f + n])]
        return min(signed_dist(bvh, co[i]) for i in ids) * 1000

    base = {f: dict(pose[f]) for f in fingers}

    def set1(t):
        for f in fingers:
            pose[f]["mcp"] = base[f]["mcp"] + t[f] * stage1[0]
            pose[f]["curl"] = base[f]["curl"] + t[f] * stage1[1]
            pose[f]["dip"] = base[f]["dip"] + t[f] * stage1[2]
        apply_all(pose)

    def chk(segs):
        def c():
            co = coords_fn()
            return {f: dmin(f, segs, co) >= tol for f in fingers}
        return c

    _bisect(fingers, set1, chk(("meta", "01", "02", "03") if meta else ("01", "02", "03")))
    b2 = {f: dict(pose[f]) for f in fingers}

    def set2(t):
        for f in fingers:
            pose[f]["curl"] = b2[f]["curl"] + t[f] * (stage2_max[0] - b2[f]["curl"])
            pose[f]["dip"] = b2[f]["dip"] + t[f] * max(0.0, stage2_max[1] - b2[f]["dip"])
        apply_all(pose)

    _bisect(fingers, set2, chk(("02", "03")))
    b3 = {f: dict(pose[f]) for f in fingers}

    def set3(t):
        for f in fingers:
            pose[f]["dip"] = b3[f]["dip"] + t[f] * max(0.0, dip_cap - b3[f]["dip"])
        apply_all(pose)

    _bisect(fingers, set3, chk(("03",)))
    return pose


def close_thumb(apply_all, pose, coords_fn, parts, bvh, joints=(("rz", -40, 60), ("curl", 0, 70)), tol=-0.8):
    for joint, lo0, hi0 in joints:
        lo, hi = lo0, hi0
        for _ in range(9):
            pose["thumb"][joint] = (lo + hi) / 2
            apply_all(pose)
            co = coords_fn()
            d = min(signed_dist(bvh, co[i]) for n in ("01", "02", "03") for i in parts["thumb" + n]) * 1000
            if d < tol:
                hi = pose["thumb"][joint]
            else:
                lo = pose["thumb"][joint]
        pose["thumb"][joint] = lo
        apply_all(pose)
    return pose
