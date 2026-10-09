# Scripted Blender figures and exercise animations, headless on a Mac

## Question and short answer

How do we make good Blender models and animations by script (`bpy`), headless on Apple silicon, for short looping exercise clips on an iOS info screen, with output the user owns outright?

**Short answer:** It is feasible end to end with no GUI. On the installed Blender 5.2.2 LTS, a script can add a Rigify rig, auto-weight a mesh, key poses, loop them with a Cycles modifier, render transparent frames with EEVEE (about 1 s per 540 px frame, warm), and encode HEVC with alpha through the ffmpeg already installed. Blender's licence leaves all output with the user; MPFB (MakeHuman's Blender add-on) adds CC0 assets, so a figure made with it is also unencumbered, subject to the caveats below. The hard part is not tooling but authoring movements with correct form and a good-looking figure; that is judgment work no source here settles (see Unknowns).

Research only; no repo code changed. Experiments ran in `/tmp/bl`, outside the repo.

## Date and versions checked

Checked **2026-10-09** (machine date). Local tools (commands run, outputs below):

- `blender --version` → `Blender 5.2.2 LTS`, build date 2026-09-15, hash `d13f752e3b9c` (`/opt/homebrew/bin/blender`, app at `/Applications/Blender.app`). The earlier note `docs/research/exercise-animations.md` recorded Blender as not on PATH; it is now installed.
- `ffmpeg -version` → `ffmpeg version 9.0.2`; encoders present: `libx264`, `h264_videotoolbox`, `libx265`, `hevc_videotoolbox`, `prores_videotoolbox`, `prores_ks`.
- macOS 27.0.1, `Apple M1` (`sw_vers`, `sysctl`).
- MPFB2: master commit `d0a32e57a7f915cb2f2b95410e2117648c7bbb7e` (2026-10-04), latest release `v2.0.17` (2026-07-22), requires Blender ≥ 4.2 [M1–M3].
- Manual pages are the `latest` docs; they were read on this date and are not pinned.

## 1. The figure: from scratch vs a base mesh

### Licence of Blender's own output

"What you create with Blender is your sole property. All your artwork – images or movie files – including the .blend files and other data files Blender can write, is free for you to use as you like." [B1] This covers renders, videos and `.blend` files the script produces. It does not by itself clear third-party meshes, textures or add-on assets you bring in; each of those carries its own licence.

### Options

| Option | Licence of what you ship | Verdict |
|---|---|---|
| Model from scratch with `bpy` primitives (capsules, spheres, bevelled boxes) | Yours; nothing external. | Safest. A stylised mannequin (rounded limbs, simple hands) is also the easiest to make look consistent. Effort is mostly proportions and hands; unknown until tried. |
| **MPFB2** (MakeHuman Community add-on) | Source code GPLv3; bundled assets (base mesh, proxies, targets, textures, clothes, rigs, poses) **CC0 1.0**; the team states exports (FBX, OBJ, DAE…), scripted output, renderings and saved models are "your data" with no claim [M4]. | Best base mesh if a realistic or semi-realistic body is wanted. Output is clear to ship. Caveat below. |
| Blender's bundled Rigify metarig | Rigify is a bundled add-on (`scripts/addons_core/rigify`), part of Blender; the Blender output statement applies [B1]. It is a rig, not a body mesh. | Use for the rig either way (section 2). |
| Human Generator and other paid add-ons | **Unknown**: I did not read its licence (the vendor page was unreachable from this machine). Do not use until the exact licence text has been read. | Skip; MPFB covers the need with a CC0 grant. |
| Community-made MakeHuman clothes/skins downloaded separately | Not covered by the MPFB statement; each pack has its own licence. **Unknown** per pack. | Use only MPFB's bundled assets, or check each pack's licence file. |

MPFB's own wording for the assets (verbatim essentials): the assets "have been released under CC0 1.0 Universal" and the team's "opinion" is that no output contains program logic, so "there is no limitation on what you can do with this combined output" [M4]. That is the vendor's stated opinion, not a court ruling. CC0 plus the Blender statement is the strongest grant available short of modelling everything yourself. GPLv3 on the add-on's code does not attach to the rendered video or an exported mesh on the team's reading [M4].

Scripting concern: MPFB must be installed as an add-on or extension in the Blender that runs the script. Installation method and headless operation of its Python API were **not tested** here (`unknown`). Because the build script is run headless, either install it once into the user's Blender config, or build the body once, save the `.blend`, and have the animation scripts only open that file.

## 2. Rigging and skinning

### Rigify vs a hand-built armature

Rigify is a bundled add-on [B2]. I verified in 5.2.2 that it works headless:

- `addon_utils.enable("rigify", default_set=True, persistent=False)` returns the module. With `default_set=False` it raised `KeyError: 'bpy_prop_collection[key]: key "rigify" not found'` inside Rigify's `register()` and returned `None`; the error is about the add-on preferences entry, so pass `default_set=True` in a factory-settings headless run.
- `bpy.ops.object.armature_human_metarig_add()` creates a 159-bone human metarig; `bpy.ops.pose.rigify_generate()` then produced an object named `rig` with 706 bones in 2.66 s.
- The generated rig has the controls an exercise script needs: IK/FK limbs (custom properties `IK_FK`, `IK_Stretch`, `pole_vector`, `IK_parent`, `pole_parent` on limb bones such as `thigh_parent.L`), and bones named `hand_ik.L`, `foot_ik.L` among others (command output; script `/tmp/bl/r.py` and `/tmp/bl/w.py`).

| | Rigify | Hand-built armature (`edit_bones`) |
|---|---|---|
| Setup by script | Add metarig, scale/move its bones to the mesh, generate. Metarig edits require edit mode; 2.7 s generate. | About 20 bones created in edit mode, then IK constraints added per limb. |
| Posing for exercises | Ready-made IK/FK switch, pole targets, foot roll, spine/neck chains. Controls have many bones (706), which makes scripted posing names long and rig-version dependent. | Only what you build; names and behaviour are yours and stable. |
| Risk | Rigify's bone names and properties may change between Blender versions (`unknown` across versions); pin Blender. | You write IK, limits and foot control yourself. |

Recommendation (judgment): use **Rigify** for a human-proportioned mesh (MPFB or hand-modelled), pinning the Blender version; hand-build only if the figure is a deliberately simple mannequin with rigid parts.

### Skinning

- Rigid mannequin: parent each part to a bone (`obj.parent = rig; obj.parent_type='BONE'; obj.parent_bone=name`). No weights, no deformation artifacts, fully scriptable. (Technique not run here; standard parenting API [B6].)
- Deforming single mesh: verified headless — with a mesh and the generated rig selected and the rig active, `bpy.ops.object.parent_set(type='ARMATURE_AUTO')` ran in `--background` and produced 160 vertex groups on a test cylinder (`/tmp/bl/w.py`). Automatic weights quality on a real body, elbows, shoulders and hips is **unknown** and needs a visual check on contact sheets (section 8). MPFB's meshes also come with rig-compatible weights through its own rig tooling (`unknown`, not tested).
- Operators that rely on context (`parent_set`, `mode_set`, `rigify_generate`) worked here because the objects were selected and active. In a larger script use `with bpy.context.temp_override(...)` (see pitfalls).

## 3. Animating with correct form by script

### Keying poses

- Pose bones: set `pb.rotation_mode`, assign `pb.rotation_euler`/`location`, then `pb.keyframe_insert("rotation_euler", frame=f)`. With Rigify, key the IK control bones and spine bones rather than every deform bone.
- **Layered actions (API change).** In 5.2.2, `bpy.types.Action` no longer has an `fcurves` attribute: `hasattr(action, "fcurves")` → `False`, `hasattr(action, "layers")` → `True` (`/tmp/bl/a.py`). F-curves live under `action.layers[i].strips[j].channelbag(slot).fcurves`; the API lists `ActionChannelbag`, `ActionChannelbagFCurves`, `ActionLayer`, `ActionSlot`, `ActionStrip` [B3]. Code from older tutorials that loops `action.fcurves` will fail. The slot came from `obj.animation_data.action_slot`; my test got 3 f-curves back from the channelbag.
- Timing: key at 24 fps (or 30) with a short half-cycle; use Bezier or constant-ish ease for strength movements, linear only where velocity should be steady. Pose "holds" (isometric stretch) are held keys, not a loop of motion; the prior report already warns that a stretch hold is not a rhythmic motion [see `docs/research/exercise-animations.md`, section "Correctness and accessibility checks"].

### Planted feet, hands on dumbbells

- **IK** [B4]: an IK constraint on a chain with a target bone keeps a foot or hand at a world position while the pelvis moves; a pole target sets the knee/elbow direction. The manual lists Target, Pole Target, Iterations and Chain Length; the tip bone can also be moved without a target. Rigify's limb IK already provides this. Plant a foot by leaving its IK control bone **un-keyed or keyed to a constant value** across the whole cycle; foot sliding is then impossible unless the parent changes. Verify with the check in section 8.
- **Dumbbell attachment** [B5]: constrain the prop to the hand with a Child Of constraint targeting `hand_ik.L` (a bone name in the Rigify rig) and set `inverse_matrix` yourself in a script: I used `c.inverse_matrix = (rig.matrix_world @ rig.pose.bones["hand_ik.L"].matrix).inverted()` after a `view_layer.update()`, and the constraint accepted it without an operator call (`/tmp/bl/w.py`). That avoids the `set inverse` operator, which depends on UI context. Alternative: parent the prop directly to the bone (`parent_type='BONE'`), which needs no inverse. For a bench press both dumbbells follow IK hand controls; for the goblet squat a single prop follows both hands, so drive its position from one hand bone and keep the second hand IK-targeted to the dumbbell's handle empty (design choice, not run).
- Limits: a Limit Rotation constraint on bones [B7] documents allowed angles; Rigify exposes limits on its deform bones too (`unknown` per bone). Use it as a second line of defence, not as the checker.

### Seamless loops

- Key the cycle from frame 1 to frame N+1 where the pose at N+1 equals frame 1 exactly (copy values, not re-posed by eye), then add an F-curve **Cycles** modifier on every channel [B8]: `fc.modifiers.new('CYCLES')`. This worked on the channelbag f-curves in 5.2.2 without error (`/tmp/bl/a.py`).
- Render frames 1…N only; frame N+1 duplicates frame 1 and would cause a stutter. (Standard looping practice, not a cited claim.)
- Cycles-modifier extrapolation beyond the keyed range is not needed if the scene range is exactly one period; the modifier keeps the curve stable if the range is later extended.
- Beware Bezier handles at the loop seam: if frame 1 and N+1 are both extremes, the tangents must be flat or matching, or the speed jumps. Use auto-clamped handles (default) and check velocity on the contact sheet or by sampling joint positions at frames 1, 2, N, N+1.
- For a stretch, the loop is better built as "ease into position, hold, ease out", with the hold as flat keys. Whether to loop at all, versus play once, is the app's motion-rule decision (ticket 28), not tooling.

## 4. Props, lighting, camera, background, house style

All of these are plain `bpy.data` creation calls and were not individually benchmarked except the camera/light/film settings in the timing test (`/tmp/bl/t.py`): sun light, camera at `(0,-6,0)` rotated 90° about X, `film_transparent=True`, PNG RGBA output.

- **Props.** PowerBlock-like dumbbells are two or three primitives: a rounded rectangular block (cube with bevel modifier) on each end of a cylinder handle, built from one function and reused. The repo notes PowerBlock geometry in `App/PowerBlock`; take dimensions from there rather than inventing them (not read in this task).
- **Style.** Pick one: flat toon look (Freestyle outlines [B9], or a Toon/Emission shader) or soft clay (Principled BSDF with roughness ~0.6, one key plus one fill light). A flat style renders fastest and survives compression best (judgment). Use one function that builds the lighting and camera, and call it for every clip, so the house style is code, not per-clip tweaking.
- **Camera.** Orthographic camera gives stable proportions and simple framing for a small phone screen; the front, side and three-quarter views can be the same rig with three camera positions. Set the framing from the figure's bounding box with margin so limbs never crop.
- **Background/alpha.** Set `scene.render.film_transparent = True` and a PNG RGBA output (as in the timing test) [B10]. Materials should be legible on both light and dark backgrounds; avoid pure black or pure white clothing. Avoid soft ground shadows unless baked into a shadow-catcher with alpha, which needs testing.
- **Colour management.** 5.x changed some colour pipeline details; check the output PNG against the app's backgrounds on a real device (`unknown`).

## 5. Rendering headless on macOS

Commands per the manual: `blender -b file.blend -a` renders the animation; `-o` sets output path, `-F` format, `-E` engine, and `--python-exit-code <n>` makes a Python exception exit non-zero; Cycles options go after `--`, e.g. `-- --cycles-device METAL` [B11]. The audio device is off in background mode by default [B11]; I still passed `-noaudio`.

### Measured on this machine (M1, 8-core GPU) — 540 × 540 transparent PNG of a UV sphere, one sun light

| Run | Result |
|---|---|
| EEVEE, first render in a fresh process | 5.23 s |
| EEVEE, second process | 0.94 s |
| Cycles Metal, 32 samples, first ever render | **73.2 s** (one-time Metal kernel compilation; the shaders are cached afterwards) |
| Cycles Metal, 32 samples, after cache | 2.68 s |

These are a trivial scene, so they measure startup and fixed cost only, not a real figure. Treat them as `a lower bound`. A real scene with a rigged mesh and soft shadows will cost more; measure it with a representative clip before committing to a frame budget.

Facts:

- EEVEE ran in `--background` with no display, on Metal, with transparent film (`film_transparent`) [B10] — verified by the run above.
- The EEVEE engine identifier is `BLENDER_EEVEE` in 5.x; it was `BLENDER_EEVEE_NEXT` in 4.2–4.5 [B12]. Scripts written for 4.x fail on `scene.render.engine = 'BLENDER_EEVEE_NEXT'`.
- Cycles on macOS needs Apple silicon and macOS 13+ for Metal [B13]. In a script, set `prefs.compute_device_type='METAL'`, call `prefs.get_devices()`, enable the devices, then `scene.cycles.device='GPU'` (as in `t.py`; this printed `('Apple M1 (GPU - 8 cores)', 'METAL', True)` and the CPU device as not used). Cycles is an add-on enum, so `bpy.types.RenderSettings...engine` listed only `BLENDER_EEVEE` before the add-on was touched (command output); set `scene.render.engine = 'CYCLES'` anyway, it worked.
- Path guiding is not supported on any GPU [B13] (irrelevant for a simple scene).
- **Recommendation:** EEVEE for these clips. Flat or clay looks need no path tracing, and the per-frame cost is far lower; use Cycles only if soft contact shadows or a specific look needs it, and then warm the Metal cache once before timing.

### Known headless pitfalls

- First Cycles Metal render pays the shader compile (73 s above); a CI that starts with a cold cache pays it every time.
- Don't rely on the GPU in a sandboxed, SSH or "no session" macOS process; Metal availability there is `unknown` (my runs came from a normal shell).
- A failing Python script exits 0 unless `--python-exit-code 1` is set [B11]; always pass it.
- Parallelism: Blender uses all cores by default (`-t 0`); running several Blender processes at once on an M1 contends for the one GPU (`unknown` scaling).

## 6. Export for iOS

### Pipeline (verified pieces marked)

1. Render PNG RGBA frames with Blender (straight alpha). Blender can write movies via its FFMPEG format [B14], but I did not use it, because **HEVC-with-alpha is not an option there** (`unknown` for 5.2; not in the manual page checked). Use the PNG sequence and encode with ffmpeg.
2. Encode with the macOS VideoToolbox encoder. Verified command and result:

```
ffmpeg -framerate 30 -i f_%03d.png -c:v hevc_videotoolbox -alpha_quality 0.75 \
       -allow_sw 0 -tag:v hvc1 -pix_fmt bgra a.mov
```

   Result: the file reads back through AVFoundation with `ContainsAlphaChannel = 1` and the track characteristic `public.contains-alpha-channel`; the `libx264` MP4 of the same frames had neither (`/tmp/bl/c.swift`, run on `a.mov` and `b.mp4`). `ffprobe` showed only `pix_fmt=yuv420p` for both, so ffprobe does not show the alpha; AVFoundation does. The 10-frame 540 px test was 6.6 kB (alpha) vs 3.7 kB (H.264) but a sphere is not representative of real size.
3. Alternative with Apple's own tool: `avconvert -p PresetHEVC1920x1080WithAlpha -s in.mov -o out.mov --replace` (presets `PresetHEVC1920x1080WithAlpha`, `PresetHEVC3840x2160WithAlpha`, `PresetHEVCHighestQualityWithAlpha` are listed by `avconvert --help`). I ran it on the encoded file and the output kept the alpha flag; it needs an alpha-bearing source.
4. ProRes 4444 (`prores_ks -profile:v 4444 -pix_fmt yuva444p10le`) is a lossless-ish master with alpha; it is too large to ship (not measured). Keep PNG frames or ProRes as the master and HEVC as the delivery file.

### Formats

| Format | Alpha | Verdict |
|---|---|---|
| HEVC with alpha (`.mov`, `hvc1`) | Yes, verified container flag | Use if transparent clips are wanted. Apple documents playing, writing and exporting HEVC with alpha in a sample tied to WWDC 2019 session 506 [A1]. On-device playback and look were **not tested** here. |
| H.264 MP4 | No | Smallest and most compatible; needs an opaque background baked in, so one file per appearance (light/dark) or a neutral background that works in both. |
| ProRes 4444 | Yes | Master only. |

- **Looping playback:** `AVPlayerLooper` "loops media content using a queue player" and is available since iOS 10 [A2]. Use it with an `AVQueuePlayer`, muted; whether the loop is gapless on a device for these files is `unknown` until tested. Note that `AVAssetWriterInputPixelBufferAdaptor` is marked deprecated in iOS 27 in favour of `AVAssetWriter.inputPixelBufferReceiver(for:pixelBufferAttributes:)` [A3]; irrelevant if ffmpeg encodes, relevant only if a Swift tool writes the video.
- **Resolution and length:** the screen shows a small view; 540–720 px square (retina) is enough on a phone (judgment; check on a device). 1–2 s per cycle is typical for a rep, 2–4 s for a stretch loop. Frame rate 30 fps; 24 fps is enough for slow stretches.
- **Bitrate:** not measured on real content. The earlier note computed 1–2 Mbps as a target for 6-second clips [`docs/research/exercise-animations.md`]. Encode a real clip at several `-b:v` values and inspect hands and the dumbbell at phone size; a flat-shaded figure compresses far better than a photographic one.
- For `hevc_videotoolbox`, `-alpha_quality` is a 0–1 compression quality for the alpha channel with default 0 (`ffmpeg -h encoder=hevc_videotoolbox`). The default of 0 is not a safe default for edges; I used 0.75. Halos at the figure's edge when composited on dark and light backgrounds must be checked on-screen (premultiplication is the usual cause, `unknown` for this exact chain).

## 7. Consistent exercise authoring

To keep 66+ clips consistent, structure the project so each exercise is data and the figure, camera, lighting, render and encode are shared code (design suggestion):

- `figure.py`: build or import the figure and rig once; save `figure.blend`.
- `house.py`: lighting, camera, materials, output settings.
- `exercises/<name>.py` or a JSON table: key poses per frame as named-control values, the prop, the planted contacts, the variant and its reference.
- `render.py`: open `figure.blend`, apply an exercise, loop, render PNGs, make contact sheets, run checks, encode.

## 8. Quality checks

These are checks to build; none has been run on a real exercise.

- **Contact sheets.** Render frames at 8–12 even intervals from front and side (and three-quarter for bench press) and tile them with ffmpeg: for example `ffmpeg -i f_%03d.png -vf "select='not(mod(n,3))',tile=6x2" sheet.png`. Review at actual phone size, not zoomed out.
- **Foot sliding.** For each frame read the world position of the foot IK control or the evaluated foot bone: `rig.matrix_world @ rig.pose.bones["foot_ik.L"].matrix.translation` after `scene.frame_set(f)` (a world position was read this way in `w.py`: `(0.098, 0.016, 0.085)`). Assert the maximum displacement in planted frames is under a tolerance (choose per exercise; a tolerance is an engineering threshold, not an authority).
- **Hand-to-dumbbell contact.** Assert distance between each grip point (an empty on the prop's handle) and the hand bone is below a tolerance on every frame.
- **Loop seam.** Assert pose at frame 1 equals frame N+1 for every keyed channel; sample positions at frames N and 1 and check the step is close to the neighbouring steps (no jump).
- **Interpenetration.** `mathutils.bvhtree.BVHTree.FromObject` on the evaluated body, bench, floor and dumbbells; `overlap()` between pairs per frame. Expect some body-limb contact at the pelvis or hands, so whitelist known contacts and flag the rest.
- **Joint limits.** Compute the angle between parent and child bone vectors per frame and compare against a documented range for the chosen variant. The prior report warns that a study's range is not a safety limit and that axis conventions must be set first [see `docs/research/exercise-animations.md`, section "Numerical sanity reference"].
- **Decoded video.** Decode the delivered file, not only the PNGs: check dimensions, frame count, alpha via AVFoundation (the `c.swift` check above), and composite on light and dark backgrounds.
- **Human review.** Automated checks catch production defects; they do not show that the movement is correct. A trainer or physiotherapist review is `unknown` in availability and cost (prior report).

## 9. Pitfalls specific to scripting Blender

- **Version drift.** Pin one Blender version for the project. Verified drift in this range: EEVEE engine id `BLENDER_EEVEE_NEXT` → `BLENDER_EEVEE` in 5.0 [B12]; `Action.fcurves` gone in favour of layered actions with slots (checked on 5.2.2; API [B3]). The 5.0 release notes also remove operators and properties around the dope sheet and pose library [B12]. Read each release's Python API page before upgrading.
- **Add-on enable.** Rigify failed to register with `default_set=False` in factory-settings mode; use `default_set=True` (verified).
- **`bpy.ops` and context.** Operators check context (active object, mode, area); in `--background` there is no window or area, so UI-bound operators (for example, anything that needs a 3D viewport) fail or poll false. Prefer data API (`bpy.data`, `edit_bones`, `constraints.new`) and use `bpy.context.temp_override(...)` for operators you must call. Mode switches need the object to be the active one (my `a.py` set `view_layer.objects.active` first).
- **Edit mode data.** Edit bones are valid only while the armature is in edit mode; leave the mode before reading pose data.
- **Depsgraph.** After changing transforms, `bpy.context.view_layer.update()` before reading `matrix_world`; after `scene.frame_set(f)` before reading evaluated pose bone positions. In my Child Of test, `d.matrix_world.translation` printed `(0,0,0)` immediately after setting the inverse, before the depsgraph updated the new object; check evaluated values after an update.
- **Exit codes.** Always `--python-exit-code 1`; a script error otherwise returns 0 and a pipeline reports success on a missing render.
- **First-run cost.** Cycles Metal shader compile (73 s above); EEVEE shader compile on first render (5 s above).
- **Determinism.** Use `random.seed` for any randomised placement; sampling noise in Cycles needs a fixed seed (`scene.cycles.seed`) so frames do not flicker.
- **Interpreters.** Blender's bundled Python runs the scripts; the system Python's packages are not available unless `--python-use-system-env` is passed [B11].

## Unknowns

- Whether MPFB can be installed and driven headless in this setup (not tested); whether its default body suits a calm stylised house look.
- Human Generator's licence terms; any community MakeHuman packs' licences.
- Automatic-weight quality on a full body; the effort to hand-model a mannequin from scratch.
- Real per-frame render time and file size of an actual exercise clip, at the target resolution and bitrate.
- On-device behaviour of HEVC-alpha `.mov` playback (including edge halos, gapless looping, battery) and whether Dark Mode compositing looks right. Only the container's alpha flag was verified, on macOS.
- Metal availability in a no-GUI session (CI, SSH).
- Whether Rigify's control names stay stable across Blender versions.
- Correct form for each exercise; the movement references and variant choices belong to ticket 28 and the prior report.

## Recommended approach

1. **Pin Blender 5.2.2 LTS** (installed), and write every script against it; fail the pipeline on any Python error (`--python-exit-code 1`).
2. **Figure:** start from a from-scratch stylised mannequin built in `bpy` (no licence question at all), or MPFB's CC0 base mesh if realism is wanted after a visual trial. Do not use paid add-ons or community packs unless their licence is read first.
3. **Rig:** Rigify generated from the human metarig, with `parent_set(type='ARMATURE_AUTO')` for skinning, or rigid parts parented to bones for the mannequin. Review the weights on contact sheets before animating.
4. **Animate:** key IK control bones (feet planted by not keying them), spine and pelvis; attach dumbbells with a Child Of constraint or bone parenting; put a Cycles modifier on every channel through the layered-action channelbag; render frames 1…N.
5. **Render:** EEVEE, transparent film, orthographic camera, one shared `house.py` for light, camera and materials; 540–720 px, 30 fps.
6. **Encode:** `ffmpeg … hevc_videotoolbox -alpha_quality 0.75 -tag:v hvc1` to a `.mov`, check the alpha flag with an AVFoundation read, and play with `AVPlayerLooper`. Test one clip on the phone in Light and Dark before building the rest.
7. **Checks per clip:** front and side contact sheets, foot and hand assertions, loop-seam assertion, BVH overlap, decoded-file check. Trial three clips (goblet squat, dumbbell bench press, kneeling hip flexor stretch) before committing to the whole catalog.

## Sources

Official or first-party; all read 2026-10-09.

- [B1] Blender licence, "Your Artwork": https://www.blender.org/about/license/
- [B2] Rigify manual (add-on pages exist under `addons/rigify/…`, e.g. introduction, metarigs, rig_types; the search index lists them): https://docs.blender.org/manual/en/latest/addons/rigify/introduction.html
- [B3] Blender Python API, `bpy.types` list with `ActionChannelbag`, `ActionLayer`, `ActionSlot`, `ActionStrip`: https://docs.blender.org/api/current/bpy.types.Action.html
- [B4] Inverse Kinematics constraint: https://docs.blender.org/manual/en/latest/animation/constraints/tracking/ik_solver.html
- [B5] Child Of constraint: https://docs.blender.org/manual/en/latest/animation/constraints/relationship/child_of.html
- [B6] (technique, not read) bone parenting via the API is part of `bpy.types.Object.parent_type`.
- [B7] Limit Rotation constraint: https://docs.blender.org/manual/en/latest/animation/constraints/transform/limit_rotation.html
- [B8] F-curve modifiers (Cycles): https://docs.blender.org/manual/en/latest/editors/graph_editor/fcurves/modifiers.html (page exists, HTTP 200; I did not extract its text, so the modifier type name `CYCLES` rests on the API run in `a.py`)
- [B9] Freestyle introduction: https://docs.blender.org/manual/en/latest/render/freestyle/introduction.html (page exists; contents not read in detail)
- [B10] EEVEE film settings (transparent): https://docs.blender.org/manual/en/latest/render/eevee/render_settings/film.html (page exists; behaviour verified by the run)
- [B11] Command-line arguments: https://docs.blender.org/manual/en/latest/advanced/command_line/arguments.html
- [B12] Release notes, Python API 5.0 (EEVEE id rename; operator/property removals): https://developer.blender.org/docs/release_notes/5.0/python_api/
- [B13] Cycles GPU rendering (Metal, limitations): https://docs.blender.org/manual/en/latest/render/cycles/gpu_rendering.html
- [B14] Video formats: https://docs.blender.org/manual/en/latest/files/media/video_formats.html (page exists; HEVC-alpha absence not confirmed from its text)
- [M1] MPFB2 repository: https://github.com/makehumancommunity/mpfb2 (API call returned name `mpfb2`)
- [M2] MPFB2 master commit: https://api.github.com/repos/makehumancommunity/mpfb2/commits/master → `d0a32e57a7f915cb2f2b95410e2117648c7bbb7e`, 2026-10-04
- [M3] MPFB2 latest release `v2.0.17`, 2026-07-22 (https://api.github.com/repos/makehumancommunity/mpfb2/releases/latest); README: "requires a Blender version of at least 4.2"
- [M4] MPFB2 licence file (sections A–D): https://raw.githubusercontent.com/makehumancommunity/mpfb2/master/LICENSE.md
- [A1] Apple sample, "Using HEVC video with alpha" (WWDC19 session 506): https://developer.apple.com/documentation/avfoundation/using-hevc-video-with-alpha
- [A2] `AVPlayerLooper`, iOS 10.0+: https://developer.apple.com/documentation/avfoundation/avplayerlooper (read through `https://developer.apple.com/tutorials/data/documentation/avfoundation/avplayerlooper.json`)
- [A3] `AVAssetWriterInputPixelBufferAdaptor`, deprecated at 27.0: https://developer.apple.com/documentation/avfoundation/avassetwriterinputpixelbufferadaptor (same JSON route)

Local experiments (all under `/tmp/bl`, outside the repo; not committed): `t.py` (EEVEE vs Cycles timing), `a.py` (layered action, Cycles modifier, Rigify enable failure), `r.py` (Rigify generate), `w.py` (auto weights, Child Of, foot position), `c.swift` (AVFoundation alpha check).
