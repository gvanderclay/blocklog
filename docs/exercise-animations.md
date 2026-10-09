# Exercise animations: the plan

Ticket 28's plan for the animations track (`.scratch/blocklog/spec.md`, User Stories 105–108; v2-Q3, v2-Q24, v2-Q38). Tickets 29–31 carry it out. It builds on four research reports: `docs/research/exercise-animations.md`, `blender-scripted-animation.md`, `ai-blender-tooling.md` and `free-animation-assets.md`. Values marked *(spike)* are filled in by the spike in section 10, before the user approves the plan.

## Goal and scope

Every starter exercise (66 today) and every phase 6 stretch (20, from `docs/research/stretch-routines.md`) gets a short looping 3D clip. Each clip has a still frame for Reduce Motion and a one-sentence description for VoiceOver. The clips appear only on a new exercise info screen, opened from the exercise picker and from a workout's exercise row. Clips are rendered by our own scripts in headless Blender, and the user owns them outright.

Out of scope: animations in the guided players or set rows, voice narration, filmed video (v2-Q38), more than one camera view per exercise, clips for custom exercises, a visible written description, and any change to `App/Model` or the backup.

## 1. Pipeline at a glance

1. **Pose file.** `scripts/animations/exercises/<slug>.json` holds the data an author edits (section 4).
2. **Scene build.** `just animate <slug>` runs Blender 5.2 headless. It opens the figure, adds the props and the house style, keys the poses and loops them.
3. **Checks.** The pose checks run (section 8). Any failure stops the run before rendering.
4. **Contact sheets.** Front and side sheets, for the render-and-look loop.
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
| `scripts/animations/figure.py` | Builds `build/animations/figure.blend` with MPFB, or the fallback mannequin. |
| `scripts/animations/scene.py` | Shared code: props, house style (orthographic camera per named view, one key and one fill light, materials, render settings), and applying a pose file (keys on IK controls, spine and pelvis; a Cycles F-curve modifier on every channel through the 5.x layered-action channelbag helper). |
| `scripts/animations/checks.py` | The pose checks in section 8, as pure functions on evaluated pose data. Each failure prints the check, frame and value. |
| `scripts/animations/render.py` | Entry point, run as `blender --background --factory-startup --python-exit-code 1 --python scripts/animations/render.py -- [--sheets-only] <slug>…`. |
| `scripts/animations/manifest.py` | System `python3`: reads every pose file and writes the manifest. |
| `scripts/animations/exercises/<slug>.json` | One pose file per exercise. |

Recipes, added to `justfile` and to the Commands list in `AGENTS.md`:

- `just animate *slugs`: checks, contact sheets, render, encode, still, manifest, and a decoded check image (section 8). With no slug it re-renders everything. Do that only for a house-style change, because each re-render adds every clip to git history again.
- `just animation-sheets *slugs`: the checks and contact sheets only, which is fast. This is the authoring loop.

Both recipes:

- fail unless `blender --version` reports 5.2 (the pinned LTS);
- pass `--python-exit-code 1`, so a Python error fails the run;
- use `--factory-startup` and fixed seeds, and never rely on the user's startup file.

Gotchas from the research:

- The EEVEE engine id is `BLENDER_EEVEE`, not `BLENDER_EEVEE_NEXT`.
- `Action.fcurves` no longer exists. Use the channelbag.
- Enable add-ons with `default_set=True`.
- Prefer the data API to `bpy.ops`.
- Call `view_layer.update()` before reading matrices.

## 4. Pose files

One JSON file per exercise. The author, usually an agent, edits data, not scene code. Ticket 29 fixes the exact control names after the spike and updates this example.

    {
      "exercise": "Dumbbell Goblet Squat",
      "description": "Hold one dumbbell upright against your chest, sit your hips down until your thighs are about level with the floor, then stand back up.",
      "variant": "Goblet squat to about parallel, feet shoulder-width, elbows close to the body.",
      "references": ["https://www.acefitness.org/resources/everyone/exercise-library/362/goblet-squat/"],
      "view": "frontThreeQuarter",
      "props": { "dumbbells": "goblet", "bench": null },
      "frames": 72,
      "still": 36,
      "poses": { "stand": { "torso": [0, 0, 0], "foot_ik.L": [0.12, 0, 0] }, "bottom": { } },
      "keys": [ { "frame": 1, "pose": "stand" }, { "frame": 36, "pose": "bottom" }, { "frame": 73, "pose": "stand" } ],
      "planted": ["foot_ik.L", "foot_ik.R"],
      "grips": { "hand_ik.L": "dumbbell.handle", "hand_ik.R": "dumbbell.handle" },
      "allowedContacts": [["forearm.L", "dumbbell"]],
      "jointRanges": { "knee": [0, 125], "hip": [0, 110] }
    }

Each field's job:

- **`exercise`** keys the clip to its exercise.
- **`description`** is the VoiceOver sentence.
- **`variant` and `references`** record what the pose was checked against.
- **`view`** is one camera per exercise.
- **`frames`** is the loop length at 30 fps; key frame N+1 equals frame 1.
- **`still`** is the frame used for Reduce Motion.
- **`planted`, `grips`, `allowedContacts` and `jointRanges`** feed the checks.
- The slug is the file name: lowercase, with non-letters replaced by `-`.

Motion rules:

- **Rep exercises:** one rep per loop, 2–3 s: lower about 1.2 s, a brief pause, rise about 1 s, a brief pause. Ease in and out; nothing jerks at the seam. The still is the end-range position.
- **Holds** (Plank, Side Plank, Wall Sit, Dead Hang and every stretch): from the setup, ease into the hold (about 1 s), hold (2–3 s), then ease out (about 1 s). The clip shows how to get into position, never a bouncing stretch. The still is the hold.
- **Per-side and one-arm exercises** show one side. Their description says "then switch sides".
- **Alternating exercises** show both sides in one loop.
- **Views:** front three-quarter by default, side where depth or back angle is the point (hinges, rows), and three-quarter from above the feet for bench work, so both forearms and dumbbell paths show.

## 5. Delivery format

- **Container:** HEVC with alpha in `.mov` (`hvc1`), with no audio track.
- **Size and rate:** square 720 × 720 px *(spike may choose 540)*, 30 fps, 2–5 s per loop.
- **Encode:**

      ffmpeg -y -framerate 30 -i build/animations/<slug>/frames/%04d.png -pix_fmt bgra \
        -c:v hevc_videotoolbox -q:v <Q> -alpha_quality 0.9 -allow_sw 0 -tag:v hvc1 -an \
        -movflags +faststart App/Resources/Animations/<slug>.mov

  `<Q>` is set by the spike. `alpha_quality` defaults to 0, which is unsafe for edges.
- **Still:** the `still` frame as a PNG with alpha, same size, `App/Resources/Animations/<slug>.png`.
- **Playback:** `AVQueuePlayer` with `AVPlayerLooper`, muted, in an `AVPlayerLayer`. This is AVFoundation, so no Swift package.
- **Bundling:** XcodeGen bundles the files from `App/Resources` as it already does for the chime and the JSON. Files land flat in the bundle, which the unique slugs allow.
- **Fallback, if ticket 29's first on-device check shows alpha failing** (black box, halos, or no playback): opaque HEVC rendered onto the list cell colours, as `<slug>-light.mov` and `<slug>-dark.mov`, chosen by `colorScheme`. That doubles the clip bytes, and the budget in section 9 is re-set with the user.

Measured *(spike, one test render: goblet squat, real figure and dumbbell)*:

| What | Value |
|---|---|
| EEVEE seconds per frame, warm, 720 px | (spike) |
| Clip bytes at two quality settings, 720 and 540 px | (spike) |
| Still bytes | (spike) |
| AVFoundation `ContainsAlphaChannel` | (spike) |
| Two encodes byte-identical | (spike) |
| EEVEE shadow catcher keeps alpha | (spike) |

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
- **Foot slide:** a planted IK control moves at most 1 cm in world space.
- **Grip:** each held hand stays within 1 cm of its handle.
- **Floor:** no evaluated vertex is below −0.5 cm.
- **Interpenetration:** a `BVHTree` overlap test of the body against the props, except `allowedContacts`.
- **Joint ranges:** the per-frame angle stays inside the pose file's `jointRanges`, which cite its reference. Axis conventions are fixed in `checks.py`.
- **Framing:** the figure's bounding box stays inside the camera with a margin, so nothing crops.

The tolerances are engineering thresholds, not medical limits.

**Render-and-look loop** (the author):

1. Choose the variant and reference and write them in the pose file. Use ACE, ExRx, or free-exercise-db photos as references. Those photos are downloaded only into `build/` for viewing, never committed or bundled, because their provenance is unverified.
2. `just animation-sheets <slug>` writes `build/animations/<slug>/sheet-front.png` and `sheet-side.png`: 12 even frames, Workbench engine, frame numbers stamped. The checks print joint angles per key frame.
3. View the sheets at phone scale beside the reference; fix pose rows; repeat.
4. `just animate <slug>`, then view `build/animations/<slug>/decoded.png`: six frames decoded from the delivered `.mov`, composited on white and `#1C1C1E`. Check edges for halos, hands on the handle, and the dumbbell's path.
5. The user judges the clips on the phone: the trial in ticket 29, all of them in ticket 31. An agent's visual judgement is a first pass. The user is the form reviewer, and no trainer review is planned (D6).

Trial variants:

- **Goblet squat:** ACE, about parallel, dumbbell upright at the chest, elbows close, and a note that depth varies.
- **Dumbbell bench press:** ExRx. Dumbbells at the sides of the chest, pressed with a slight inward arc, bench and feet visible.
- **Plank:** forearm plank, elbows under the shoulders, a straight line from head to heels. Reference chosen and recorded in ticket 29.
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
