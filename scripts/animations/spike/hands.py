"""Reusable hand poses on the Rigify finger controls (MPFB's generated rig).

Per finger (index, middle, ring, pinky), in degrees:
  mcp    knuckle flexion, the master control's X rotation (+ = toward the palm)
  curl   middle and end joint flexion, through the master's Y scale: sy = 1 - curl/180
  dip    end joint flexion in total; the difference from curl goes on f_<finger>.03
  spread master Z rotation (+ = toward the thumb side)
Thumb: rx (master X, across the palm), rz (master Z, out of the palm plane), ry (twist),
       curl (its two outer joints, through the master's Y scale).
palm: (x, z) rotation of the palm control, which cups the palm.
The right hand mirrors the left: X angles kept, Y and Z negated.
"""
import math
from mathutils import Quaternion, Vector

FINGERS = ("index", "middle", "ring", "pinky")


def finger(mcp=0, curl=0, dip=None, spread=0):
    return dict(mcp=mcp, curl=curl, dip=curl if dip is None else dip, spread=spread)


POSES = {
    # loose, natural rest: slight flexion that increases toward the little finger, fingers together
    "relaxed": dict(index=finger(12, 18, 10, 2), middle=finger(15, 22, 12, 0), ring=finger(18, 26, 14, -2),
                    pinky=finger(22, 30, 16, -5), thumb=dict(rx=10, rz=12, ry=0, curl=12), palm=(0, 4)),
    # palm down on the floor: nearly straight fingers, together, thumb alongside
    "flat": dict(index=finger(4, 6, 4, 1), middle=finger(4, 6, 4, 0), ring=finger(5, 8, 5, -1),
                 pinky=finger(6, 10, 6, -3), thumb=dict(rx=8, rz=4, ry=0, curl=6), palm=(0, 0)),
    # power grip around a ~33 mm handle: fingers wrapped, thumb opposed across the fingers
    "grip": dict(index=finger(55, 85, 50, 2), middle=finger(60, 88, 52, 0), ring=finger(64, 90, 55, -2),
                 pinky=finger(68, 92, 58, -4), thumb=dict(rx=40, rz=30, ry=10, curl=40), palm=(0, 10)),
}

# closure targets for the automatic fit: the pose at t=1; t=0 is open
OPEN = dict(index=finger(0, 0, 0, 2), middle=finger(0, 0, 0, 0), ring=finger(0, 0, 0, -2),
            pinky=finger(0, 0, 0, -4), thumb=dict(rx=0, rz=0, ry=0, curl=0), palm=(0, 0))


def lerp_pose(a, b, t):
    """Blend two poses; t may be a dict of per-part factors (finger name or 'thumb')."""
    out = {}
    for k in FINGERS + ("thumb",):
        tk = t[k] if isinstance(t, dict) else t
        out[k] = {p: a[k][p] + (b[k][p] - a[k][p]) * tk for p in a[k]}
    tp = t.get("palm", 1.0) if isinstance(t, dict) else t
    out["palm"] = tuple(a["palm"][i] + (b["palm"][i] - a["palm"][i]) * tp for i in range(2))
    return out


def apply(rig, side, pose):
    P = rig.pose.bones
    s = 1 if side == "L" else -1
    r = math.radians
    for f in FINGERS:
        p = pose[f]
        m = P[f"f_{f}.01_master.{side}"]
        m.rotation_mode = 'XYZ'
        m.rotation_euler = (r(p["mcp"]), 0, s * r(p["spread"]))
        m.scale = (1, 1 - p["curl"] / 180.0, 1)
        d = P[f"f_{f}.03.{side}"]
        d.rotation_euler = (r(p["dip"] - p["curl"]), 0, 0)
    t = pose["thumb"]
    m = P[f"thumb.01_master.{side}"]
    m.rotation_mode = 'XYZ'
    m.rotation_euler = (r(t["rx"]), s * r(t["ry"]), s * r(t["rz"]))
    m.scale = (1, 1 - t["curl"] / 180.0, 1)
    px, pz = pose["palm"]
    q = Quaternion(Vector((1, 0, 0)), r(px)) @ Quaternion(Vector((0, 0, 1)), s * r(pz))
    P[f"palm.{side}"].rotation_quaternion = q


def keyable(side):
    """Every control a hand pose writes, for keying."""
    out = [f"f_{f}.01_master.{side}" for f in FINGERS] + [f"f_{f}.03.{side}" for f in FINGERS]
    return out + [f"thumb.01_master.{side}", f"palm.{side}"]
