"""Checks, contact sheets and (unless --sheets-only) renders and encodes exercise animations. Run through
`just animate <slug>…` or `just animation-sheets <slug>…`, which call

    blender --background --factory-startup --python-exit-code 1 --python scripts/animations/render.py -- \
        [--sheets-only] <slug>…

For each slug: sample every frame 1…N+1 of its pose file, run the checks (checks.py), write the contact sheets
build/animations/<slug>/sheet-clip.png (the clip's camera) and sheet-side.png (from the figure's left), and stop
with exit status 1 if any check failed. Then render the frames, encode App/Resources/Animations/<slug>.mov, copy
the still to <slug>.png, and write build/animations/<slug>/decoded.png: six frames decoded from the .mov,
composited on white and #1C1C1E.
"""
import os
import shutil
import subprocess
import sys

import bpy
import numpy as np
from mathutils.bvhtree import BVHTree

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import checks  # noqa: E402
import scene  # noqa: E402

RES = 540
SHEET_CELL = 270
SHEET_FRAMES = 12
FILL = 0.92  # the figure's larger side across all frames fills this much of the clip
RESOURCES = os.path.join(scene.ROOT, "App", "Resources", "Animations")
DARK = (0x1C / 255, 0x1C / 255, 0x1E / 255)


def coords(obj):
    """World vertex positions of an evaluated object, as an (n, 3) array."""
    dg = bpy.context.evaluated_depsgraph_get()
    e = obj.evaluated_get(dg)
    me = e.to_mesh()
    co = np.empty(len(me.vertices) * 3)
    me.vertices.foreach_get("co", co)
    co = co.reshape(-1, 3)
    mw = np.array(e.matrix_world)
    co = co @ mw[:3, :3].T + mw[:3, 3]
    polys = [tuple(p.vertices) for p in me.polygons]
    e.to_mesh_clear()
    return co, polys


def penetration(prop, points, labels):
    """The deepest point inside the prop, as (metres, label), or (0, "")."""
    co, polys = coords(prop)
    lo, hi = co.min(axis=0) - 0.01, co.max(axis=0) + 0.01
    near = np.nonzero(np.all((points > lo) & (points < hi), axis=1))[0]
    if not len(near):
        return 0.0, ""
    bvh = BVHTree.FromPolygons([tuple(p) for p in co], polys)
    worst = (0.0, "")
    for i in near:
        p = scene.Vector(points[i])
        loc, nor, _, d = bvh.find_nearest(p)
        if loc is not None and (p - loc).dot(nor) < 0 and d > worst[0]:
            worst = (d, labels[i])
    return worst


def sample_frames(fig, props, spec):
    """Poses every frame 1…N+1 and records what the checks need, plus a thinned point cloud per frame for the
    camera."""
    body_ids = np.array(fig.real)
    hand_of = {}
    for side, ids in fig.hand_vertices.items():
        for i in ids:
            hand_of[i] = "hand." + side
    samples, clouds = [], []
    for f in range(1, spec["frames"] + 2):
        pose = scene.pose_at(spec, f)
        scene.apply_pose(fig, props, pose)
        joints = {n: getattr(fig.bones[b], end).copy() for n, (b, end) in checks.JOINTS.items()}
        reach = {s: (fig.bones["DEF-hand." + s].head - fig.bones["hand_ik." + s].head).length
                 for s in scene.held_hands(pose)}
        body, _ = coords(fig.body)
        cloth, _ = coords(fig.cloth)
        body = body[body_ids]
        points = np.vstack([body, cloth])
        labels = [hand_of.get(int(i), "body") for i in body_ids] + ["clothes"] * len(cloth)
        depth = {name: penetration(obj, points, labels) for name, obj in props.all().items()}
        prop_pts = [coords(o)[0] for o in props.all().values()]
        cloud = np.vstack([points[::5]] + prop_pts)
        samples.append(checks.Sample(f, joints, reach, float(points[:, 2].min()), depth, None))
        clouds.append(cloud)
    return samples, clouds


def fit_camera(cam, azimuth, elevation, clouds, fill):
    scene.aim(cam, azimuth, elevation)
    every = np.vstack(clouds)
    scene.frame_to(cam, [scene.Vector(p) for p in every[::3]], fill)


def boxes(cam, clouds):
    out = []
    for cloud in clouds:
        xy = scene.project(cam, [scene.Vector(p) for p in cloud])
        xs, ys = [p[0] for p in xy], [p[1] for p in xy]
        out.append((min(xs), min(ys), max(xs), max(ys)))
    return out


def read_png(path):
    img = bpy.data.images.load(path)
    w, h = img.size
    px = np.empty(w * h * 4, dtype=np.float32)
    img.pixels.foreach_get(px)
    bpy.data.images.remove(img)
    return px.reshape(h, w, 4)  # bottom row first


def on(rgba, rgb):
    a = rgba[..., 3:4]
    return np.concatenate([rgba[..., :3] * a + np.array(rgb) * (1 - a), np.ones_like(a)], axis=-1)


def write_png(path, rows):
    """Writes a grid of equal-size RGBA tiles, given top row first."""
    grid = np.concatenate([np.concatenate(r, axis=1) for r in rows][::-1], axis=0)
    h, w = grid.shape[:2]
    img = bpy.data.images.new(os.path.basename(path), w, h, alpha=True)
    img.pixels.foreach_set(grid.astype(np.float32).ravel())
    img.filepath_raw = path
    img.file_format = 'PNG'
    img.save()
    bpy.data.images.remove(img)


def contact_sheet(sc, cam, fig, props, spec, out, path):
    """12 even frames at half size, frame numbers stamped, on white."""
    n = spec["frames"]
    frames = [1 + round(i * n / SHEET_FRAMES) for i in range(SHEET_FRAMES)]
    sc.render.resolution_x = sc.render.resolution_y = SHEET_CELL
    sc.render.use_stamp = True
    for attr in dir(sc.render):
        if attr.startswith("use_stamp_") and isinstance(getattr(sc.render, attr), bool):
            setattr(sc.render, attr, attr == "use_stamp_frame")
    sc.render.stamp_font_size = 14
    tiles = []
    for f in frames:
        sc.frame_current = f
        scene.apply_pose(fig, props, scene.pose_at(spec, f))
        tmp = os.path.join(out, "sheet-tmp.png")
        scene.render(tmp)
        tiles.append(on(read_png(tmp), (1, 1, 1)))
    os.remove(tmp)
    write_png(path, [tiles[i:i + 4] for i in range(0, len(tiles), 4)])
    sc.render.use_stamp = False
    sc.render.resolution_x = sc.render.resolution_y = RES


def run(arg, sheets_only):
    spec = scene.load_pose_file(arg)
    slug = spec["slug"]
    out = os.path.join(scene.BUILD, slug)
    os.makedirs(out, exist_ok=True)
    fig = scene.Figure()
    scene.setup_rig(fig, spec)
    sc, cam = scene.scene_setup(res=RES)
    props = scene.Props(spec)
    floor = scene.floor_line()

    samples, clouds = sample_frames(fig, props, spec)
    view = spec["view"]
    fit_camera(cam, view["azimuth"], view["elevation"], clouds, FILL)
    for s, box in zip(samples, boxes(cam, clouds)):
        s.box = box
    fails = checks.run(spec, samples)
    for line in checks.report(spec, samples):
        print(f"FORM {slug} {line}")
    clip_camera = (cam.location.copy(), cam.rotation_euler.copy(), cam.data.ortho_scale)

    floor.hide_render = True
    contact_sheet(sc, cam, fig, props, spec, out, os.path.join(out, "sheet-clip.png"))
    fit_camera(cam, 90, 0, clouds, 0.9)
    floor.hide_render = False
    contact_sheet(sc, cam, fig, props, spec, out, os.path.join(out, "sheet-side.png"))
    floor.hide_render = True
    print(f"SHEETS {slug} {out}/sheet-clip.png {out}/sheet-side.png")
    if fails:
        for line in fails:
            print(f"CHECK FAILED {slug}: {line}")
        return False
    print(f"CHECKS PASSED {slug}")
    if sheets_only:
        return True

    cam.location, cam.rotation_euler, cam.data.ortho_scale = clip_camera
    frames = os.path.join(out, "frames")
    shutil.rmtree(frames, ignore_errors=True)
    os.makedirs(frames)
    for f in range(1, spec["frames"] + 1):
        scene.apply_pose(fig, props, scene.pose_at(spec, f))
        scene.render(os.path.join(frames, f"{f:04d}.png"))
    os.makedirs(RESOURCES, exist_ok=True)
    clip = os.path.join(RESOURCES, slug + ".mov")
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-framerate", str(scene.FPS), "-i",
                    os.path.join(frames, "%04d.png"), "-pix_fmt", "bgra", "-c:v", "hevc_videotoolbox", "-q:v", "70",
                    "-alpha_quality", "0.9", "-allow_sw", "0", "-tag:v", "hvc1", "-an", "-movflags", "+faststart", "-fflags", "+bitexact",
                    clip], check=True)
    shutil.copyfile(os.path.join(frames, f"{spec['still']:04d}.png"), os.path.join(RESOURCES, slug + ".png"))

    # Six frames decoded from the delivered clip, on white and on the dark cell colour.
    picks = [1 + round(i * spec["frames"] / 6) for i in range(6)]
    tiles = []
    for f in picks:
        path = os.path.join(out, "decoded-tmp.png")
        subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", clip, "-vf", f"select=eq(n\\,{f - 1})", "-frames:v",
                        "1", "-pix_fmt", "rgba", path], check=True)
        tiles.append(read_png(path))
        os.remove(path)
    write_png(os.path.join(out, "decoded.png"), [[on(t, (1, 1, 1)) for t in tiles], [on(t, DARK) for t in tiles]])
    print(f"RENDERED {slug} {clip} {os.path.getsize(clip)} bytes, still {os.path.getsize(clip[:-4] + '.png')} bytes,"
          f" {out}/decoded.png")
    return True


def main():
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    sheets_only = "--sheets-only" in args
    slugs = [a for a in args if not a.startswith("--")]
    if not slugs:
        slugs = sorted(f[:-5] for f in os.listdir(scene.EXERCISES) if f.endswith(".json"))
    ok = True
    for arg in slugs:  # a slug, or the path of a scratch copy of a pose file
        ok = run(arg, sheets_only) and ok
    if not ok:
        sys.exit(1)


main()
