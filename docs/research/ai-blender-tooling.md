# AI tooling for scripted Blender exercise animations

## Question and short answer

How do AI agents build Blender models and animations well, and which tools can Blocklog adopt for a headless, scripted pipeline whose output the user owns outright and that runs on this Mac?

**Short answer.** Adopt nothing exotic. The best pipeline is plain `blender --background --python` driven by the agent, with pose tables in data, agent-written validation scripts, and a render-then-look loop on contact sheets. A Blender MCP server adds little for an agent that can already run shell commands. Every text-to-motion and video-to-motion tool found either needs a CUDA GPU with 17–26 GB of memory (this Mac is an M1 with 8 GB) or carries a licence or training-data restriction that makes "owned outright" doubtful. The only permissively licensed base assets found are the MPFB human (CC0) and CMU mocap (free to modify and redistribute). Ranked list at the end.

## Date, versions, evidence limits

- Checked **2026-10-09** on this Mac: `sysctl hw.model` → `MacBookPro17,1`, Apple M1, `hw.memsize` 8589934592 (8 GB).
- Blender installed here: `blender --background --version` → `Blender 5.2.2 LTS (hash d13f752e3b9c built 2026-09-15)`; latest tag from GitHub API `v5.2.2`.
- Licences were read from the repositories' own LICENSE/README files through the GitHub API and raw files at the default branch on the check date (not pinned to commits; re-check before depending on one). Dates are `pushed_at` from the GitHub API.
- The web-search tool failed with server errors, so no model-generated summaries are used. Items I could not verify are marked `unknown`.
- I am not a lawyer. "Owned outright" legal questions (copyright in AI-assisted output) were not researched: `unknown`.

## 1. Blender MCP servers and agent integrations

**MCP for Blender** (formerly `blender-mcp`), `ahujasid/mcp-for-blender`: MIT licence (GitHub API `license.spdx_id` = MIT), 30,319 stars, last push 2026-10-06. The README says it is a third-party plugin, not made by the Blender Foundation. [https://github.com/ahujasid/mcp-for-blender]
- Architecture: a Blender add-on (`addon.py`) opens a socket server inside a running Blender; an MCP server (`uvx mcp-for-blender`) talks to it (README line 200). It controls "your live Blender" (`execute_blender_code` row: "Run Python in your live Blender", README ~line 636). So it is GUI-session-based, not headless. The README mentions headless only for injecting API-key environment variables ("For headless setups or CI, credentials can also be injected by environment variables", ~line 758), not for running Blender without a window. Whether the add-on works under `--background`: `unknown`.
- Tools: scene inspection, viewport screenshot, `execute_blender_code`, Poly Haven (CC0), Sketchfab, Poly Pizza downloads, and `generate_3d` via Tripo, Hyper3D Rodin and Hunyuan3D (paid or key-based cloud APIs).
- Security: the README warns that `execute_blender_code` runs arbitrary Python in Blender ("ALWAYS save your work", ~line 792). Telemetry is opt-in (~line 799).
- Does it help an agent that already runs `blender --background --python`? Marginally. Its useful parts (viewport screenshot, scene query) are replaceable by a script that renders a still and dumps scene data to JSON. Its cost: a GUI Blender session, a socket, state that persists between calls (hurts reproducibility), and cloud 3D generators with their own terms. It is useful for exploratory modelling of a one-off prop, not for a repeatable pipeline.

**Other integrations seen** (GitHub search `blender mcp`, sorted by stars, 2026-10-09; maturity only, I did not audit them):
- `arjun988/blender-skills` (MIT, 279 stars, pushed 2026-07-10): "94 specialist Blender skills" for Claude Code, Codex and others, MCP-powered. Prompt packs, quality `unknown`.
- `scenario-labs/skills` (MIT, 940 stars): skills that call the Scenario MCP (a paid hosted service) and "teams that drive Blender".
- `squall01337/mixamo-llm-mocap` (MIT, 350 stars, pushed 2026-09-26): video → GVHMR → Mixamo-rig FK animation, "operated end-to-end by an AI agent". Needs CUDA (~8 GB VRAM badge) and Blender 5.1+; it inherits GVHMR's non-commercial licence (section 3). Useful only as a design reference for an agent-run mocap pipeline, including its fidelity eval script (limb angles, foot slide, jitter).
- `FreedomIntelligence/BlenderLLM` (Apache-2.0, last push 2024-12-23): a model that writes CAD-style bpy scripts; stale and aimed at CAD, not character animation.
- `lewdineer/Kimodo_Blender_Bridge`, `atticus-lv/kimodo_motion` (GPL-3.0): Blender add-ons around NVIDIA Kimodo (section 3).
- `KhronosGroup/glTF-Blender-IO` (Apache-2.0): official glTF exporter, not AI, relevant only if a model is ever shipped instead of video.

**Not found:** any Blender-Foundation-official MCP or agent integration in these searches. `unknown` whether one exists.

## 2. Practices for LLM-written `bpy`

These come from the primary Blender docs where marked; the rest is my engineering judgement and is labelled so.

1. **Pin the Blender version and read its release notes for the Python API.** Blender's own 5.0 notes say: "The legacy Action API has been removed… This covered the properties `action.fcurves`, `action.groups`, and `action.id_root`. Instead… access those properties on the channelbag", with `bpy_extras.anim_utils.action_ensure_channelbag_for_slot(action, slot)` and `channelbag.fcurves.ensure()` as the replacements. [https://developer.blender.org/docs/release_notes/5.0/python_api/] A model trained mostly on pre-4.4 code will write `action.fcurves.new(...)` and fail on the installed 5.2.2. Practical rule: tell the agent the exact version, make it call `bpy.context.object.keyframe_insert(...)` for keys (works across versions) and read fcurves only through a small shared helper that is tested once.
2. **Render and look.** Agent loop (my judgement, matches the existing research's contact-sheet idea in `docs/research/exercise-animations.md`): script renders N frames from front and side cameras at low resolution with a flat EEVEE or Workbench engine, tiles them into one image, and the agent views the image. Fewer, larger tiles beat many small ones. Add frame numbers and joint-angle text to the tiles so the agent can reason numerically as well as visually. `unknown`: published measurements of how well vision models judge exercise form from such sheets; treat the agent as a first-pass checker and the user as the form reviewer.
3. **Declarative pose tables.** Keep exercise data as JSON/Python dicts (keyframe time, per-bone rotation or IK-target position, hold/ease) and one generic script that builds the rig, applies the table and renders. The agent edits data, not API calls, so a bad edit cannot break scene construction, and diffs are reviewable. The mixamo-llm-mocap repo uses a similar "spec-driven retarget" with an automatic fidelity eval step. [https://github.com/squall01337/mixamo-llm-mocap]
4. **Validation scripts the agent runs before rendering** (my judgement; all are pure math on `bpy` data and run headless): loop seam (pose at first frame equals pose at last frame + 1, velocity continuity); foot/hand sliding (world-space speed of IK targets that should be planted is below a threshold); floor penetration (lowest vertex or bone tail z ≥ 0); joint limits (per-bone Euler angle ranges, such as elbow 0–150°, knee 0–150°); dumbbell grip (hand-to-handle distance constant while held); hand/arm vs torso interpenetration (bounding-sphere or `mathutils.bvhtree` overlap tests). Each prints pass/fail and frame numbers so the agent can fix a table row.
5. **Run headless, one process per render, exit non-zero on failure**, so a justfile recipe and CI can rely on it; avoid operators that need a UI context (`bpy.ops` calls fail in background mode more often than the data API). Prefer `bpy.data` and `mathutils` over `bpy.ops`.
6. **Determinism:** fixed seeds, fixed frame range, set `scene.render` fields explicitly in the script, never rely on defaults from the user's startup file; start with `--factory-startup`.

## 3. Motion sources

Question for each: can the output be owned outright for a commercial-style app, can it run on this M1 (8 GB), and is it worth it versus hand-authored pose tables?

| Source | Code licence | Weights / data licence | Apple silicon | Verdict |
|---|---|---|---|---|
| **CMU Mocap Database** | n/a | "The motion capture data may be copied, modified, or redistributed without permission." (FAQ, "How can I use this data?") [http://mocap.cs.cmu.edu/faqs.php] | Plain BVH/AMC files, no model | Safe source and reference. Coverage of dumbbell exercises: `unknown`, likely thin. |
| **Mixamo** (Adobe) | n/a | Adobe FAQ: "You can use both characters and animations royalty free for personal, commercial, and non-profit projects including… create films. Create video games." [https://helpx.adobe.com/creative-cloud/faq/mixamo-faq.html] Terms on AI processing/redistribution of raw files: `unknown` (not found in that FAQ). Not "owned outright". Needs an Adobe login (web only). | No model | Avoid as the core of the pipeline: licensed, not owned, and the user already rejected a licence-bound pack. |
| **SMPL / SMPL-X body model** | n/a | Max Planck licence: "for the sole purpose of performing non-commercial scientific research, non-commercial education, or non-commercial artistic projects… any use for commercial purposes, is prohibited… production of other artefacts for commercial purposes"; also prohibits using the software to train methods for commercial use; commercial licence via Meshcapade. [https://smpl.is.tue.mpg.de/modellicense.html] | n/a | Anything that needs SMPL to run is a commercial-use risk. |
| **AMASS dataset** | n/a | Same non-commercial wording, "incorporation in a commercial product… production of other artefacts for commercial purposes" prohibited; training for commercial use prohibited. [https://amass.is.tue.mpg.de/license.html] | n/a | Avoid. |
| **HumanML3D** (training data of MDM, MoMask, T2M-GPT) | n/a | Built from AMASS and HumanAct12; its README says it cannot redistribute AMASS data and provides scripts to rebuild it from AMASS, so the AMASS licence applies. [https://github.com/EricGuo5513/HumanML3D] | n/a | Models trained on it inherit doubt: `unknown` legal status of their outputs. |
| **MDM** (`GuyTevet/motion-diffusion-model`) | MIT | Weights trained on HumanML3D/KIT; needs the SMPL files (`prepare/download_smpl_files.sh`) for mesh rendering; README: "CUDA capable GPU (one is enough)" | CUDA required per README | Avoid. |
| **MoMask** (`EricGuo5513/momask-codes`) | MIT | README: "our code depends on other libraries, including SMPL, SMPL-X, PyTorch3D, and uses datasets which each have their own respective licenses that must also be followed." | Not documented for MPS: `unknown` | Avoid. |
| **T2M-GPT** (`Mael-zys/T2M-GPT`) | Apache-2.0 | HumanML3D-trained (inferred from the paper family; repository README not read) | `unknown` | Avoid. |
| **WHAM** (`yohanshin/WHAM`) | MIT | Needs SMPL downloaded after registering on the SMPL and SMPLify sites; training uses AMASS (README lines 24, 75). | CUDA assumed; `unknown` for MPS | Avoid for shipped output (SMPL). |
| **4D-Humans / HMR2.0** (`shubham-goel/4D-Humans`) | MIT | Needs the SMPL neutral model; trained on 8 A100 GPUs, CUDA 11.6, Linux (README line 66) | Inference on MPS: `unknown` | Avoid for shipped output (SMPL). |
| **GVHMR** (`zju3dv/GVHMR`) | Custom, GitHub API says `NOASSERTION`: "educational, research and non-profit purposes only. Any modification based on this work must be open-source and prohibited for commercial use." [https://raw.githubusercontent.com/zju3dv/GVHMR/main/LICENSE] | SMPL-X dependent | CUDA per the downstream repo's badge | Avoid. Used by `mixamo-llm-mocap`, so that pipeline is non-commercial too. |
| **MediaPipe Pose** (`google-ai-edge/mediapipe`) | Apache-2.0 | BlazePose GHUM models; 33 3D landmarks from RGB (pose.md line 42). Model-card licence terms: `unknown` (not read) | Runs on Apple silicon CPU/GPU (Google ships macOS wheels; not verified here) | Fine as a measuring tool to compare the pose of a rendered frame against a reference. Output is landmarks, not rig rotations; poor for quality hand-off. Needs filmed reference video, which the plan excludes. |
| **Kimodo** (`nv-tlabs/kimodo`) | Apache-2.0 (repo LICENSE) | Text-to-motion diffusion, trained on "700 hours" of "commercially-friendly" mocap (README). SOMA models: NVIDIA Open Model License; the SMPL-X variant: NVIDIA R&D (research) licence, so avoid that one. NVIDIA's licence page says "NVIDIA does not claim ownership to any outputs" and "Models are commercially usable", but also makes you responsible for outputs and indemnifying NVIDIA. [https://www.nvidia.com/en-us/agreements/enterprise-software/nvidia-open-model-license/] The BONES-SEED dataset licence is restricted to academics or startups under $1M revenue and defines "Results" as "rendered animations" derived from the dataset; it applies to users of the dataset (we would not download it), but whether it reaches outputs of a model trained on it: `unknown`. | README: ~17 GB VRAM on GPU, "most extensively tested on GeForce RTX 3090, 4090 and A100", "developed on Linux, though Windows should work". With `TEXT_ENCODER_DEVICE=cpu`, <3 GB VRAM. macOS/MPS support: not claimed, `unknown`. | Best-licensed text-to-motion found, but not demonstrated on this Mac. Could run on a rented CUDA GPU. Output is SOMA 77-joint motion needing retargeting. |
| **HY-Motion 1.0** (`Tencent-Hunyuan/HY-Motion-1.0`) | GitHub `NOASSERTION`; custom Tencent licence (`License.txt` at HEAD) | The licence excludes "the territory of the European Union, United Kingdom and South Korea" (line 17), requires a separate licence above 1 million monthly active users (line 30), and forbids using "any Output or results… to improve any other AI model" (line 37). README thanks SMPL/SMPLH; the model uses SMPL-family skeletons: whether SMPL's licence reaches the outputs: `unknown`. | README line 88: "supports macOS, Windows, and Linux", but model zoo lists min VRAM 26 GB (1.0B) and 24 GB (Lite 0.46B) | Does not fit an 8 GB M1; licence is restrictive. Avoid. |

Reading: the two models whose text I could not clear (MDM/MoMask/T2M-GPT/WHAM/4D-Humans) are research-grade and tied to SMPL/AMASS, which forbid commercial artefacts. Text-to-motion models in general were also trained on whole-body daily and sports motions, and nothing found shows they can hold an accurate dumbbell curl or a 90° elbow with a fixed bar. For ~30–60 simple, repetitive, symmetrical exercise loops, a 4–8 row pose table plus IK is likely faster to get right than generating and retargeting motion. This last sentence is my judgement, not a measured result.

## 4. Text-to-3D and image-to-3D (figure or props)

- **TRELLIS** (`microsoft/TRELLIS`): MIT code; the HF model card `microsoft/TRELLIS-image-large` lists `mit`. README: "An NVIDIA GPU with at least 16GB of memory is necessary… tested only on Linux" with CUDA 11.8/12.2. Not runnable on this Mac.
- **TripoSR** (`VAST-AI-Research/TripoSR`): MIT for "source code, pretrained models, and an interactive online demo" (README line 27). Installable without CUDA ("torchmcubes was not compiled with CUDA support, use CPU version instead" troubleshooting note), so CPU or maybe MPS; speed on M1 8 GB `unknown`. Produces a static, unrigged mesh from a single image.
- **Stable Fast 3D** (`stabilityai/stable-fast-3d`): HF card license `other`, gated: community licence terms not read; `unknown`.
- **Hunyuan3D-2**: Tencent licence "does not apply in the European Union, United Kingdom and South Korea" and the grant is limited to the Territory (LICENSE lines 1–3, 2). Avoid.
- **SAM 3D Objects** (`facebookresearch/sam-3d-objects`): GitHub `NOASSERTION`; licence not read: `unknown`.
- Cloud APIs reachable through MCP for Blender (Tripo, Hyper3D Rodin, Hunyuan3D): per-service terms not read; `unknown`.
- Why these are low value here: the figure must be rigged and share a topology with the animation, and image-to-3D meshes come unrigged, with messy topology and no guaranteed originality (they can echo training images). The **MPFB** add-on solves the figure better: GPLv3 code, but "assets… released under CC0 1.0 Universal" including base mesh, rigs and poses, and "no output from MPFB contains any trace of program logic… Exports to files (FBX, OBJ…), Graphical data generated via scripting… Renderings… Screenshots… Saved model files… We regard these things as your data". [https://github.com/makehumancommunity/mpfb2/blob/master/LICENSE.md] Last push 2026-10-04. Dumbbells and blocks are boxes and cylinders in `bpy` and need no generator.

## 5. Apple-silicon summary

| Tool | Runs on this M1 (8 GB)? |
|---|---|
| Blender 5.2.2 headless | Yes: `blender --background --version` works (this session). |
| MCP for Blender | Yes, but needs a GUI Blender session. |
| CMU BVH, MPFB | Yes (data and a Blender add-on). |
| MediaPipe | Likely (CPU); not tested here. |
| Kimodo | Not claimed; CUDA, 17 GB (3 GB with CPU text encoder). `unknown` on MPS. |
| HY-Motion 1.0 | README says macOS supported, but 24–26 GB minimum VRAM: no, with 8 GB. |
| MDM, TRELLIS, WHAM, 4D-Humans, GVHMR | CUDA-oriented (README statements above): no. |
| TripoSR | CPU path exists; speed unknown. |

## 6. Ranked recommendation

Adopt, in order:
1. **Headless Blender 5.2.2 driven directly by the agent**, with the pitfalls list in section 2: version-pinned API helper (slotted actions), `--factory-startup`, exit-code validation. Zero licence risk.
2. **A render-and-look script** (contact sheet, front and side, frame and angle labels) that the agent views after every change; plus **validation scripts** for loop seam, foot/hand slide, floor penetration, joint limits, grip.
3. **Pose tables as data** (JSON or Python dicts) with one generic builder and IK targets; the agent edits rows only.
4. **MPFB human** (CC0 assets, outputs explicitly yours) as the base figure, or an original hand-modelled figure; check the rig it exports works with the pose builder before committing.
5. **CMU mocap BVH** as an optional reference or starter for generic motions (stand-to-squat, walk) where a table is awkward; verify the exercise is in the database first (`unknown`).
6. **MediaPipe Pose** only as an optional second opinion on rendered frames or on a user-made reference clip. Optional, low priority.

Optional, not recommended now: **MCP for Blender** (MIT) for interactive one-off exploration if the user wants to watch a live viewport; it does not improve a headless pipeline.

Avoid:
- **Anything built on SMPL, SMPL-X, AMASS or HumanML3D** (MDM, MoMask, T2M-GPT, WHAM, 4D-Humans, GVHMR, `mixamo-llm-mocap`): the licences prohibit commercial artefacts or have unclear output ownership. [SMPL and AMASS licence pages above]
- **HY-Motion 1.0**: EU/UK/South Korea carve-out, 1M MAU clause, output-use limits, and 24–26 GB VRAM.
- **Kimodo for now**: best licence of the text-to-motion set, but no Mac support shown and the training-data licence question reaches rendered output only through unresolved reading. Revisit if a rented CUDA GPU is acceptable and the user wants generated base motion; it would still need retargeting from the SOMA skeleton and form checks.
- **Mixamo** as the animation source (licensed, not owned, terms on AI use not found).
- **Image-to-3D and text-to-3D** for the figure: unrigged output, uncertain originality, CUDA for the best models.
- **Cloud 3D generators through MCP** (Tripo, Rodin, Hunyuan): per-service terms unread.

## Unknowns to resolve if the plan leans on them

- Copyright status of AI-assisted pose tables and renders in the US and where the user sells: not researched.
- Whether Kimodo or any generator runs on Apple silicon (MPS): untested.
- Whether CMU mocap has dumbbell-exercise clips: not checked.
- Whether MCP for Blender's add-on can run under `--background`: not checked.
- Quality of vision-model form judgement from contact sheets: no source found.
