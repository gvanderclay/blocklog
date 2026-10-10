# Exercise animations: the plan

Ticket 28's plan for the animations track (`.scratch/blocklog/spec.md`, User Stories 105–108; v2-Q3, v2-Q24, v2-Q38). Tickets 29–31 carry it out. It builds on four research reports: `docs/research/exercise-animations.md`, `blender-scripted-animation.md`, `ai-blender-tooling.md` and `free-animation-assets.md`. Values marked *(spike)* are filled in by the spike in section 10, before the user approves the plan.

## Goal and scope

Every starter exercise (66 today) and every phase 6 stretch (20, from `docs/research/stretch-routines.md`) gets a short looping 3D clip. Each clip has a still frame for Reduce Motion and a one-sentence description for VoiceOver. The clips appear only on a new exercise info screen, opened from the exercise picker and from a workout's exercise row. Clips are rendered by our own scripts in headless Blender, and the user owns them outright.

Out of scope: animations in the guided players or set rows, voice narration, filmed video (v2-Q38), more than one camera view per exercise, clips for custom exercises, a visible written description, and any change to `App/Model` or the backup.

## 1. Pipeline at a glance

1. **Pose file.** `scripts/animations/exercises/<slug>.json` holds the data an author edits (section 4).
2. **Scene build.** `just animate <slug>` runs Blender 5.2 headless. It opens the figure, adds the props and the house style, and poses every frame from the pose file's key poses.
3. **Checks.** The pose checks run on every frame (section 8). Any failure stops the run before the clip renders.
4. **Contact sheets.** Sheets from the clip's camera and from the side, for the render-and-look loop. They are written even when a check fails, to show the failure.
5. **Frames.** EEVEE renders transparent PNG frames 1…N into `build/animations/<slug>/` (gitignored).
6. **Encode.** ffmpeg's `hevc_videotoolbox` writes `App/Resources/Animations/<slug>.mov` (HEVC with alpha), and the still frame is copied to `<slug>.png`.
7. **Manifest.** `scripts/animations/manifest.py` regenerates `App/Resources/exercise-animations.json` from every pose file.

As with the chime and the icon, the committed clips, stills and manifest are generated files. Change the pose files and scripts, never the outputs.

## 2. Character and props

**Figure: MPFB 2.0.17** (MakeHuman for Blender), core CC0 assets only.

- **Shape.** One neutral, average-build adult. The body is one matte grey "clay" material, mid-tone so it reads on both the white and the `#1C1C1E` cell background. Shorts and a fitted top come from MPFB's core CC0 assets, in a darker grey. No hair, and the face is plain.
- **Colour.** No amber anywhere: amber marks actions (`docs/design.md`).
- **Rig.** MPFB's generated Rigify rig with its IK limbs (`hand_ik.*`, `foot_ik.*`) and MPFB's weights.
- **Build.** `scripts/animations/figure.py` builds the figure once into `build/animations/figure.blend`, which is gitignored and rebuilt when missing. Only this step needs MPFB; rendering opens the `.blend` under `--factory-startup`.
- **Licence.** MPFB's assets are CC0 and its output belongs to the user (MPFB `LICENSE.md` sections C–D). Blender's output is the user's own (blender.org licence). The add-on's GPL code never ships in the app.
- **Fallback, if the spike fails MPFB** (no headless install, or bad deformation at deep squat or arms overhead): an original mannequin built in `bpy` from rounded primitives. Each part is parented rigidly to a bone of a Rigify rig generated from the human metarig, so there are no weights to fix. Same material and style.
- **Never used:** community MakeHuman packs, paid add-ons such as Human Generator, Quaternius raw files (their redistribution limit), and Mixamo characters.

**Props:** all original, modelled from primitives in `scripts/animations/scene.py`.

- **PowerBlock-like dumbbell.** Two bevelled rectangular stacks joined by a handle enclosed in the block. Charcoal with lighter rail edges, no logo, no amber. One size for every exercise: a clip doesn't show a weight. Proportions approximate the Elite EXP block; exact dimensions aren't critical.
- **Adjustable bench:** flat, incline (30° and 45°) and decline.
- **Pull-up bar:** a bar on two posts.
- **A wall** for Wall Sit, and **a doorway** for Doorway Chest Stretch.
- **No visible floor plane.** If the spike shows an EEVEE shadow catcher keeps a soft contact shadow in the alpha channel, use it; otherwise there is no shadow.

No free source has dumbbell motion, so every clip is keyframed by us. CMU mocap could seed 3–5 bodyweight moves, but retargeting and cleanup cost about as much as keying, so it is not planned.

## 3. Scripts and `just` recipes

| File | Job |
|---|---|
| `scripts/animations/figure.py` | Builds `build/animations/figure.blend` with MPFB. The recipes run it when the file is missing or older than the script. |
| `scripts/animations/assets/male_casualsuit04/` | The one CC0 clothing asset the figure wears, committed from MakeHuman's system asset pack (its texture lines removed, since the clothes are recoloured flat). |
| `scripts/animations/scene.py` | Shared code: the figure, props, house style (an orthographic camera aimed by the pose file's view, one key and one fill light, materials, render settings), the hand library's code, and applying a pose file: every frame is interpolated from the key poses in Python and set on the Rigify controls. |
| `scripts/animations/hands.json` | The hand library: finger shapes on the Rigify finger controls (relaxed, and the fitted goblet, grip and flat) and holds, each a shape plus the hand control's matrix in the held prop's space. |
| `scripts/animations/checks.py` | The pose checks in section 8 and the form metrics, as pure functions on sampled frames. Each failure prints the check, the worst frame and the value. |
| `scripts/animations/render.py` | Entry point, run as `blender --background --factory-startup --python-exit-code 1 --python scripts/animations/render.py -- [--sheets-only] <slug or path>…`. |
| `scripts/animations/manifest.py` | System `python3`: reads every pose file and writes the manifest. |
| `scripts/animations/exercises/<slug>.json` | One pose file per exercise. |

Recipes, added to `justfile` and to the Commands list in `AGENTS.md`:

- `just animate *slugs`: checks, contact sheets, render, encode, still, manifest, and a decoded check image (section 8). With no slug it re-renders everything. Do that only for a house-style change, because each re-render adds every clip to git history again.
- `just animation-sheets *slugs`: the checks and contact sheets only, about 25 s. This is the authoring loop. A path to a scratch copy of a pose file works in place of a slug.

Both recipes:

- fail unless `blender --version` reports 5.2 (the pinned LTS);
- pass `--python-exit-code 1`, so a Python error fails the run;
- use `--factory-startup` and fixed seeds, and never rely on the user's startup file.

Gotchas from the research:

- The EEVEE engine id is `BLENDER_EEVEE`, not `BLENDER_EEVEE_NEXT`.
- `Action.fcurves` no longer exists. Use the channelbag.
- Enable add-ons with `default_set=True`.
- Keying actions turned out unnecessary: the scripts pose each frame directly, so `Action.fcurves` and F-curve modifiers aren't used. Set controls parents first and call `view_layer.update()` between levels, or a child set through `pose_bone.matrix` lands relative to its parent's stale pose.
- Prefer the data API to `bpy.ops`.
- Call `view_layer.update()` before reading matrices.

## 4. Pose files

One JSON file per exercise. The author, usually an agent, edits data, not scene code. Coordinates are the world: metres, Z up, the figure standing at the origin facing −Y with its left side at +X. Angles are degrees. Abridged from `exercises/dumbbell-goblet-squat.json`:

    {
      "exercise": "Dumbbell Goblet Squat",
      "description": "Hold one dumbbell upright against your chest, sit your hips down until your thighs are about level with the floor, then stand back up.",
      "variant": "ACE goblet squat to about parallel: …",
      "references": ["https://www.acefitness.org/resources/everyone/exercise-library/362/goblet-squat/", "…"],
      "view": {"azimuth": -35, "elevation": 8},
      "props": {"dumbbells": 1},
      "frames": 72,
      "still": 1,
      "rig": {"torso.head_follow": 0.0, "torso.neck_follow": 1.0},
      "poses": {
        "bottom": {
          "torso": {"at": [0.0, 0.1241, 0.3756], "turn": [32.0, 0.0, 0.0]},
          "chest": {"turn": [-8.0, 0, 0]},
          "head": {"turn": [-20.0, 0, 0]},
          "foot_ik.L": {"at": [0.2, -0.0224, 0.0692], "turn": [0.0, 0.0, 20.0]},
          "thigh_ik_target.L": {"at": [0.6278, -0.8682, 0.5192]},
          "upper_arm_ik_target.L": {"at": [0.3, 0.1915, 0.2741]},
          "dumbbell": {"parent": "chest", "at": [0.0, -0.2338, 1.2475], "turn": [12.0, 0.0, 180.0]},
          "hand_ik.L": {"hold": "goblet", "on": "dumbbell"}
        },
        "mid": { }, "stand": { }
      },
      "keys": [ {"frame": 1, "pose": "bottom"}, {"frame": 7, "pose": "bottom"}, {"frame": 19, "pose": "mid", "via": true},
                {"frame": 31, "pose": "stand"}, {"frame": 37, "pose": "stand"}, {"frame": 55, "pose": "mid", "via": true},
                {"frame": 73, "pose": "bottom"} ],
      "planted": ["foot.L", "foot.R"],
      "allowedContacts": {},
      "jointRanges": {"kneeFlex.L": [0, 135], "hipFlex.L": [0, 125]},
      "form": {"bottom": {"hipOverKnee.L": [-8, 0], "trunkMinusShin": [-15, 0], "kneeOverFoot.L": [-3, 3], "elbowInsideKnee.L": [0, 30]}}
    }

Each field's job:

- **`exercise`** keys the clip to its exercise. The file name is its slug: lowercase, with runs of non-letters replaced by `-`; the run checks it.
- **`description`** is the VoiceOver sentence.
- **`variant` and `references`** record what the pose was checked against.
- **`view`** is the clip's one camera: azimuth 0 in front of the figure, 90 on its left, −90 on its right, and the elevation above the horizon. The camera fits every frame so the figure's larger side fills 92% of the frame.
- **`props`**: `dumbbells` is 0, 1 (named `dumbbell`) or 2 (`dumbbell.L` and `dumbbell.R`); `bench` is `"flat"` or absent. The bench's pad top is 0.44 m, centred on the origin along Y.
- **`frames`** is the loop length at 30 fps; the last key is frame N+1 and must repeat frame 1.
- **`still`** is the frame used for Reduce Motion.
- **`rig`** sets Rigify properties, such as `torso.head_follow`.
- **`poses`** are named key poses. Each entry names a Rigify control (`torso`, `hips`, `chest`, `neck`, `head`, `foot_ik.L`, `toe_ik.L`, `thigh_ik_target.L` for the knee's direction, `upper_arm_ik_target.L` for the elbow's, `hand_ik.L`), a prop, or `fingers.L` (a hand shape name). A `.L` entry without its `.R` twin is mirrored to the right side. Every pose gives the same entries.
  - `{"at", "turn", "pivot"}`: the control's rest pose turned by `turn` (XYZ, world axes) about `pivot` (its rest head by default), then moved so the pivot lands on `at`. A planted foot that rolls uses the ball of the foot as its pivot, so the ball stays put.
  - `{"turn"}` alone: turned about its current head, on top of what its parents give it (the chest, the head, the toes).
  - A hand: `{"at", "palm", "fingers"}` aims the palm's outward normal and the wrist-to-knuckles direction with the wrist at `at`. With `"hold": "handle"` the hand takes the hold's shape and a prop `{"in": "hand.L"}` follows it. Or `{"hold": "goblet", "on": "dumbbell"}` puts the hand on a prop placed by `{"parent", "at", "turn"}` (`at` is where it sits with the figure at rest; it then moves with the parent bone).
- **`keys`** time the poses. Each key eases in and out; a key with `"via": true` is passed through without stopping.
- **`planted`, `allowedContacts`, `jointRanges` and `form`** feed the checks (section 8). `planted` names `foot`, `ball`, `forearm` or `hand` with a side. `allowedContacts` gives a prop a deeper allowed contact in metres, such as `{"bench": 0.02}` for the back on the pad. `form` checks metrics at the frames keyed with that pose; `checks.py` documents each metric and its axes.

Motion rules:

- **Rep exercises:** one rep per loop, 2–3 s: lower about 1.2 s, a brief pause, rise about 1 s, a brief pause. Ease in and out; nothing jerks at the seam. The still is the end-range position, and the loop starts there (frame 1), so the still matches the clip's first frame: the still never jumps to the first frame when the clip starts, under Reduce Motion or while the first frame loads.
- **Holds** (Plank, Side Plank, Wall Sit, Dead Hang and every stretch): from the setup, ease into the hold (about 1 s), hold (2–3 s), then ease out (about 1 s). The clip shows how to get into position, never a bouncing stretch. The still is the hold, and the loop starts in the hold, for the same reason.
- **Per-side and one-arm exercises** show one side. Their description says "then switch sides".
- **Alternating exercises** show both sides in one loop.
- **Views:** front three-quarter by default, side where depth or back angle is the point (hinges, rows), and three-quarter from above the feet for bench work, so both forearms and dumbbell paths show.

## 5. Delivery format

- **Container:** HEVC with alpha in `.mov` (`hvc1`), with no audio track.
- **Size and rate:** square 540 × 540 px *(the spike chose 540 over 720, section 10)*, 30 fps, 2–5 s per loop.
- **Encode:**

      ffmpeg -y -framerate 30 -i build/animations/<slug>/frames/%04d.png -pix_fmt bgra \
        -c:v hevc_videotoolbox -q:v 70 -alpha_quality 0.9 -allow_sw 0 -tag:v hvc1 -an \
        -movflags +faststart -fflags +bitexact App/Resources/Animations/<slug>.mov

  The spike set `-q:v` to 70. `alpha_quality` defaults to 0, which is unsafe for edges.
- **Still:** the `still` frame as a PNG with alpha, same size, `App/Resources/Animations/<slug>.png`.
- **Playback:** `AVQueuePlayer` with `AVPlayerLooper`, muted, in an `AVPlayerLayer`. This is AVFoundation, so no Swift package.
- **Bundling:** XcodeGen bundles the files from `App/Resources` as it already does for the chime and the JSON. Files land flat in the bundle, which the unique slugs allow.
- **Fallback, if ticket 29's first on-device check shows alpha failing** (black box, halos, or no playback): opaque HEVC rendered onto the list cell colours, as `<slug>-light.mov` and `<slug>-dark.mov`, chosen by `colorScheme`. That doubles the clip bytes, and the budget in section 9 is re-set with the user.

Measured *(spike, one test render: goblet squat, real figure and dumbbell)*:

| What | Value |
|---|---|
| EEVEE seconds per frame, warm, 720 px | 0.26 s (0.23 s at 540 px); 16 samples, M1, 72 frames in about 25 s including startup. The first frame costs about 1 s. |
| Clip bytes at two quality settings, 720 and 540 px | 720 px: 324,325 at `-q:v 50`, 375,633 at 70, 433,112 at 80, 671,776 at 90. 540 px: 275,963 at 50, 314,037 at 70, 355,523 at 80, 514,500 at 90. Chosen: 540 px, `-q:v 70`. |
| Still bytes | 118,272 at 540 px (201,006 at 720 px), PNG with alpha. |
| AVFoundation `ContainsAlphaChannel` | 1 (codec `hvc1`, 72 frames decoded through `AVAssetReader`). Decoded frames composited on white and `#1C1C1E` show clean edges, no halo, at `-q:v 50` to 80. |
| Two encodes byte-identical | No: the two files differ in 2 of 314,037 bytes (offsets 1343 and 5242). The renders are pixel-identical between runs. |
| EEVEE shadow catcher keeps alpha | No. `Object.is_shadow_catcher` gives an opaque lit floor (alpha 255). A ShaderToRGB floor material gives noisy partial alpha and a visible floor edge. Decision: no shadow. |

Measured at the trial *(ticket 29, 540 px, `-q:v 70`)*:

| Exercise | Frames | Clip bytes | Still bytes |
|---|---|---|---|
| Dumbbell Goblet Squat | 72 | 286,935 | 126,342 |
| Dumbbell Bench Press | 72 | 283,522 | 171,966 |
| Plank | 150 | 281,836 | 110,107 |

The three average 420,236 bytes per exercise, which × 86 is 36.1 MB. `just animate` of one slug takes about 1 to 1.5 minutes. Re-rendering a slug gives pixel-identical frames, the same still and the same decoded frames; the `.mov` still differs in 4 bytes between encodes, with `-fflags +bitexact`.

Budget check: (314,037 + 118,272) bytes × 86 = 37.2 MB, under the 40 MB soft target. At 720 px and `-q:v 70` it would be (375,633 + 201,006) × 86 = 49.6 MB.

## 6. Keying a clip to its exercise

- **Manifest.** `App/Resources/exercise-animations.json` is generated from the pose files: `[{ "exercise": "Dumbbell Goblet Squat", "file": "dumbbell-goblet-squat", "description": "…" }]`. The description lives beside the clip, and the app never computes a slug.
- **Logic type.** `App/Logic/ExerciseAnimation.swift` holds `@MainActor struct ExerciseAnimation`, with `clip: URL`, `still: URL` and `description: String`. It has `static let bundled`, loaded like `StarterRoutine.bundled`, and a lookup that takes an `Exercise` and returns its animation or nil.
- **Matching** is by name, ignoring case, through `ExerciseCatalog.normalized(_:).key`, the same matching starter routines use. A custom exercise gets none, since `ExerciseCatalog.nameProblem` stops it taking a starter's name. There is no stored field and no model change.
- **Tests** in `Tests/ExerciseAnimationTests.swift` go through the public type and a seeded in-memory store:
  - Every manifest entry names a starter exercise. Renaming one in `starter-exercises.json` fails here until the pose file's `exercise` is renamed and `manifest.py` re-run.
  - Every entry's clip and still are in the bundle, and its description is one non-empty sentence. A missing file fails here.
  - Every bundled `.mov` belongs to an entry, so a renamed leftover can't waste space.
  - The lookup finds Dumbbell Goblet Squat by name and gives a custom exercise nothing.
  - Ticket 30 adds: every starter exercise has an animation, and the total clip and still bytes stay within the budget in section 9.

## 7. The info screen

- **View.** `App/Views/ExerciseInfoScreen.swift`. It shows the exercise name, wrapping at every text size. Below it, when the exercise has an animation, comes a section with the clip, square and full cell width, transparent on the cell background. Then two `LabeledContent` rows, Muscle Group and Equipment, using the existing `title`s. With no animation it shows the details and no placeholder.
- **From the exercise picker.** A trailing `info.circle` button on each row (`exercisePicker.row.<exercise name>.info`), with a borderless style so tapping the row still adds the exercise, and a 44 × 44 point target. It pushes the screen inside the picker's `NavigationStack`. I rejected a context menu (hidden) and tapping the row (that already adds the exercise).
- **From a workout.** "Exercise Info" (`info.circle`) becomes the first item of the exercise actions menu (`workout.exercise.<e>.info`). It opens a sheet with its own `NavigationStack` and Done (`.confirmationAction`, `exerciseInfo.done`). I rejected making the header name tappable: it is less discoverable, and the header already has a menu.
- **Playback.** The clip (`exerciseInfo.animation`) starts on appear and loops gaplessly. A tap toggles pause and play, which satisfies WCAG 2.2.2 (pause for moving content). It pauses when the screen disappears or the app goes to the background. The still shows until the first frame is ready. No sound, no haptics.
- **`docs/design.md` changes (ticket 29):**
  - Motion gains one exception: exercise animations on the info screen are instructional media and may loop, muted, with tap to pause and the Reduce Motion rule below. Nothing else loops.
  - The SF Symbols table gains "Exercise info: `info.circle`".
  - The feel-check list gains the animations lines.

## 8. Reduce Motion, VoiceOver and checking a pose

**Reduce Motion.** When `accessibilityReduceMotion` is on, the screen shows the still and nothing plays until the user taps it. A tap then loops it, and another tap pauses it. Turning Reduce Motion on while a clip plays pauses it and returns to the still.

**VoiceOver.**

- The clip is one button element. Its label is the description, its value is "Playing" or "Paused", and the still shares the label.
- The description is one plain sentence covering setup, movement and return (or hold), with "then switch sides" for per-side work. It is not shown as visible text (decision D6).
- No live announcements.

**Automated pose checks** (`checks.py`, every run, any failure stops the render):

- **Loop seam:** keyed channels at frame N+1 equal frame 1, and the step from frame N to frame 1 is close to its neighbours.
- **Foot slide:** each planted joint (the ankle and ball for `foot`, the elbow and wrist for `forearm`) moves at most 1 cm in world space.
- **Grip:** each held hand ends within 1 cm of its hold (the IK reach error, since IK stretch is off).
- **Floor:** no evaluated body or clothes vertex is below −0.5 cm.
- **Interpenetration:** no body or clothes vertex is more than 2 mm inside a prop (3 mm for a hand, the fitted grips' contact), or deeper than the prop's `allowedContacts` depth, by a `BVHTree` nearest-surface test.
- **Joint ranges:** the per-frame angle stays inside the pose file's `jointRanges`, which cite its reference. Axis conventions are fixed in `checks.py`.
- **Framing:** the figure's bounding box stays inside the camera with a margin, so nothing crops.

The tolerances are engineering thresholds, not medical limits.

**Render-and-look loop** (the author):

1. Choose the variant and reference and write them in the pose file. Use ACE, ExRx, or free-exercise-db photos as references. Those photos are downloaded only into `build/` for viewing, never committed or bundled, because their provenance is unverified.
2. `just animation-sheets <slug>` writes `build/animations/<slug>/sheet-clip.png` (the clip's camera) and `sheet-side.png` (from the figure's left, with a floor line): 12 even frames, EEVEE at half size, frame numbers stamped. The checks print the form metrics per key frame, the deepest contact with each prop and the lowest vertex.
3. View the sheets at phone scale beside the reference; fix pose rows; repeat.
4. `just animate <slug>`, then view `build/animations/<slug>/decoded.png`: six frames decoded from the delivered `.mov`, composited on white and `#1C1C1E`. Check edges for halos, hands on the handle, and the dumbbell's path.
5. The user judges the clips on the phone: the trial in ticket 29, all of them in ticket 31. An agent's visual judgement is a first pass. The user is the form reviewer, and no trainer review is planned (D6).

Trial variants:

- **Goblet squat:** ACE, about parallel, dumbbell upright at the chest, elbows close, and a note that depth varies.
- **Dumbbell bench press:** ExRx. Dumbbells at the sides of the chest, pressed with a slight inward arc, bench and feet visible.
- **Plank:** ACE front plank on the forearms, elbows under the shoulders, a straight line from head to heels. The setup is the same position with the knees down.

Trial results *(ticket 29)*. All checks pass for the three.

- **Goblet squat:** the spike's approved poses, keyed with the hips travelling back early through a `via` mid pose. Bottom: hip 3.0 cm below the knee, trunk lean 27.7° against shin lean 32.9°, knee 0.5 cm inside the foot line, elbow 9.4 cm inside the knee.
- **Dumbbell bench press:** elbows flexed 98° at the bottom with the forearm within 3.4 cm of vertical, 19° at the top. The grip hold puts the block about 26° off the forearm, because the wrist sits between the rails and the handle in the palm; the hands are extended 22° at the wrist so the block stands upright from the side. The camera is at azimuth −40, elevation 25: the plan's "from above the feet" view hid the near arm behind the head and foreshortened the press.
- **Plank:** hips 1.2 cm above the shoulder–ankle line, head top 1.6 cm below it, elbows 2.5 cm from under the shoulders. Knees down, the knee joints are 7.7 cm off the floor, where the trousers just reach it (the clothes sit outside the skin).
- **Hip Flexor Stretch** (ticket 30): ACE kneeling variant, entry then hold, no bouncing.

## 9. App size

The catalogue is 86 clips: 66 starter exercises and 20 stretches.

- **Arithmetic** (not measured): an average 3 s clip at 1 Mbps is about 375 KB, and at 2 Mbps about 750 KB. That gives 32–64 MB for 86 clips, plus 4–9 MB of stills at 50–100 KB each. A flat clay figure on alpha should compress better; the spike measures it.
- **Budget:** 40 MB for all clips and stills, about 465 KB per exercise. A unit test enforces it from ticket 30. If the spike's clip × 86 exceeds it, first step down to 540 px or a lower quality, then ask the user before raising it.
- **Git:** clips are committed plainly, without Git LFS. Repo growth comes mostly from re-renders, so re-render only the slugs whose pose changed, and only after their sheets pass.

## 10. The spike

Run under ticket 28, after the user approves the MPFB install (D3), and before plan approval. It runs outside the repo (`/tmp/blspike`) and changes no app code; its only repo change fills the table in section 5.

1. Install MPFB 2.0.17 headless (`blender --command extension install-file …`) and record the exact command. Generate the figure with its Rigify rig in `--background --factory-startup` and record the time. Render one sheet of four poses (standing, deep squat, arms overhead, lying on a bench) to judge deformation. **Fallback:** the mannequin in section 2.
2. Key a rough goblet squat (72 frames) with one block dumbbell, rendered with EEVEE at 720 px with a transparent film. Record warm seconds per frame. **Fallback, above about 4 s per frame:** 540 px and simpler lighting.
3. Encode at two quality settings, at 720 and 540 px. Record the bytes. Check the alpha flag through AVFoundation, and composite decoded frames on white and `#1C1C1E`. **Fallback, if too big:** lower quality or 540 px.
4. Encode twice and `cmp` the files. If they differ, the rule "re-render only changed slugs" in section 9 matters more.
5. Try an EEVEE shadow catcher with alpha. If it doesn't work, use no shadow.

The on-device check (alpha on the phone, halos, gapless loop, music keeps playing) is ticket 29's first step, because it needs the info screen.

**Spike results** (run 2026-10-09, M1 8 GB, Blender 5.2.2, work in `/tmp/blspike`):

- **MPFB install.** The GitHub release has no assets; MPFB 2.0.17 comes from extensions.blender.org (sha256 `4f0a879d…a239a87`, 45,031,536 bytes, verified). Command, 2 s: `blender --background --factory-startup --command extension install-file -r user_default --enable mpfb.zip`. `--factory-startup` does not load the user extension, so each script runs `addon_utils.enable("bl_ext.user_default.mpfb", default_set=True, persistent=False)` and `addon_utils.enable("rigify", default_set=True, persistent=False)` first. It lands in `~/Library/Application Support/Blender/5.2/extensions/user_default/mpfb` (82 MB). To uninstall: `blender --command extension remove mpfb`.
- **System assets.** The extension holds only the base mesh, rigs and targets; shorts, tops and skins are in the separate CC0 pack `makehuman_system_assets_cc0.zip` (280,737,770 bytes from `files.makehumancommunity.org/asset_packs/makehuman_system_assets/`). The spike read it from `/tmp/blspike/assets`, not from the Blender config. Ticket 29 must fetch it too, or commit the one clothing asset used.
- **Figure build, 2.3 s headless.** `HumanService.create_human()`, `add_builtin_rig(…, "rigify.human_toes")`, `add_mhclo_asset(…)`, `RigService.generate_rigify_rig(meta, meta_rig_action="delete")`. The rig has the expected controls (`hand_ik.L/R`, `foot_ik.L/R`, `torso`, `chest`, `hips`). The figure is 1.66 m tall, `figure.blend` is 2.6 MB, and `create_human` needs its default scale 0.1 to give metres.
- **Fallbacks taken.** (1) No shorts exist in the core CC0 pack, so the figure wears `male_casualsuit04` (T-shirt and long trousers), recoloured dark grey. (2) The plan's mannequin fallback was not needed. (3) 540 px chosen over 720 px for the size budget. (4) No shadow, since the EEVEE shadow catcher gave no alpha. (5) The contact sheets are EEVEE frames, not Workbench.
- **Goblet squat.** Keyed per frame (72 baked frames, `torso` plus both `hand_ik` controls), the dumbbell on a Child Of constraint to `chest`. Feet stay on the floor (IK controls unkeyed). The hands hover around the dumbbell and do not grip it yet. The figure fills only about 45% of the frame height, so ticket 29 should tighten the framing.
- **Deformation.** Standing, deep squat, arms overhead and lying on a bench all deform without collapse. The T-shirt shows a small gap at the shoulder with the arms overhead, and the lying pose arches the back because the pose was not tuned.
- **Files.** Four-pose sheet: `/tmp/blspike/review/four-pose-sheet-white.png` and `…-dark.png`. Squat contact sheet (12 frames): `/tmp/blspike/review/squat-contact-sheet-white.png`. Scripts (`figure.py`, `lib.py`, `goblet.py`, `sheet.py`, `dec.swift`) are in the same folder.

**Spike 2 results** (2026-10-09; the user judged spike 1's hands and squat unacceptable, and approved these):

- **Form by numbers.** `squat.py` and `plank.py` pose against ACE and NASM references and print checks: goblet bottom with the hip 3 cm below the knee, trunk lean 27.7° ≤ shin lean 32.9°, heels flat, knees over toes, elbows inside knees; plank with hips 1.5 cm off the head–heel line and elbows under shoulders. Ticket 29 keeps these checks in shared code, so each exercise is a data file of key poses checked automatically, plus the user's review.
- **Hands are a fixed library, fitted once.** `hands.py` holds the poses (grip, block hold, flat; add fist and relaxed). `closefit.py` closes fingers to contact; the fitted grip is stored in the hand bone's space (`grip_hand.json`) and reused, never refitted per exercise. Hand bone axes: X palm normal, Y wrist→knuckles, Z thumb side; the knuckle line is 14.7° oblique, so lay handles along it.
- **Goblet hold with a PowerBlock (user):** the palms go under the top block with the fingers up its sides onto the top, one hand per side; hands never go around the handle. The heels hold the bottom edges, since palms can't reach under a 15 cm block; the palms still hover 6–11 mm off its sides.
- **Dumbbell.** Rails at ±0.058 m so they sit either side of the wrist in the grip; the hand barely fits the 115 mm gap.
- **Framing** is still loose (the squat camera frames standing and bottom together); ticket 29 tightens it.
- **Files.** The spike scripts are kept in `scripts/animations/spike/` as the starting point for ticket 29's pipeline; they still use `/tmp/blspike` paths and the figure from `figure.py`. Review images: `/tmp/blspike/review2/` (lost on reboot).

**Plan approved by the user, 2026-10-09.**

## 11. Approvals and decisions

AGENTS.md rule 6: no Swift package is needed, since AVFoundation plays the clips. Rule 15: no model change. The user decides:

- **D1, the trial's stretch.** Hip Flexor Stretch exists only after ticket 32a (phase 6). *Recommend:* swap in Plank, a hold that proves the hold pattern now, and move Hip Flexor Stretch to ticket 30's stretch batch. Waiting would stall the track for two phases.
- **D2, a loop exception to `docs/design.md`** ("No looping…"). *Recommend:* allow it on the info screen only, muted, tap to pause, with a still under Reduce Motion. User Story 105 asks for a looping clip. The alternative, a still with tap-to-play once, is weaker for checking form.
- **D3, install the MPFB 2.0.17 add-on** into the user's Blender 5.2 config. This is a machine change; nothing new ships. *Recommend:* yes. It removes the modelling and rigging work, and its assets are CC0. If declined, the mannequin fallback applies.
- **D4, the figure's look.** *Recommend:* a neutral average adult in grey clay with darker shorts and top, no hair, plain face. The user confirms or asks for changes on the spike's sheet, and again at the trial.
- **D5, size and storage.** *Recommend:* a 40 MB budget for clips and stills, committed plainly without Git LFS. LFS would add a hook and CI setup for a single-user repository.
- **D6, defaults** (I take these unless the user objects):
  - one camera view per exercise;
  - the description read by VoiceOver only, not shown;
  - the user is the form reviewer, with no paid trainer;
  - no CMU, Mixamo, AI motion generators or Blender MCP.

**Answers (user, 2026-10-09):** D1 yes (Plank in the trial), D2 yes, D3 yes (install MPFB), D4 yes, D6 agreed. D5: aim for small files, but treat 40 MB as a soft target, not a hard limit; no Git LFS.

## 12. Rejected alternatives

- **Gymvisual pack:** its licence restricts AI processing (v2-Q3).
- **2D Canvas figures and Rive:** the user chose 3D (v2-Q3), and Rive needs a package.
- **Live RealityKit:** no product need for camera control.
- **Blender MCP:** needs a GUI session and adds nothing to a headless pipeline.
- **Text-to-motion or video-to-motion** (Kimodo, MDM, GVHMR and others): CUDA with 17–26 GB of GPU memory, or SMPL/AMASS non-commercial terms.
- **Mixamo:** an AI/ML clause, and it is browser-only.
- **wger, Everkinetic and Commons:** ShareAlike or mixed licences.
- **Opaque H.264:** would need a light and a dark copy. It stays only as the fallback.
- **Extracting the still at runtime** by seeking the player: a blank frame while loading, and alpha behaviour is unverified.
- **A stored animation field on `Exercise`:** a migration for data the bundle already knows.

## 13. Risks

- **Form quality is the real cost.** The tooling is proven; correct movement isn't. The trial exists to catch a poor result before 63 more clips.
- **Alpha on the device is unverified.** If the layer shows black, the first lever to try is the player layer's `pixelBufferAttributes` set to 32-bit BGRA (to verify). Then the opaque fallback.
- **Playing a video may interrupt the user's music.** Clips carry no audio track and the player is muted. If music still stops, set the `.ambient` category before playing, as `RestChime` does.
- **Rigify control names and the Blender API drift between versions.** The recipe pins 5.2 and fails on anything else.
- **Rendering 86 clips takes hours on the M1 with 8 GB.** Run renders in the background, not alongside an Xcode build.
- **The hardware encoder may not be deterministic,** which bloats git on re-renders. Re-render only changed slugs.
- **Ticket 30's coverage test must not block phase 6.** It skips the Stretching group until the stretch batch lands (ticket 30).

## 14. Order of work

1. Ticket 28: the spike (section 10), then the user approves this plan.
2. Ticket 29: on-device check, pipeline, trial of three, info screen. The user says go or change course.
3. Ticket 30: batches A–D (starter exercises), then batch S (stretches) once 32a ships.
4. Ticket 31: checkpoint on the phone and the `animations` tag.
