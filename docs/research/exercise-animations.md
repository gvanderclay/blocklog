# Exercise demonstrations for Blocklog

## Question and short answer

How should Blocklog deliver Hevy-style exercise and stretch demonstrations that terminal-based AI coding agents can build and check, without sacrificing movement accuracy, accessibility, or the app's calm visual language?

**Recommendation:** Try a small licensed, pre-rendered demonstration library first, played with Apple's AVFoundation, **only after the vendor explicitly clears the agent-assisted workflow and offline app distribution**. Gymvisual has the three trial movements and app-use rights, but its AI restriction is a real gating issue, not a footnote. If that permission or the visual fit fails, use an original, script-authored 3D character rendered headlessly to video; do not settle for stick figures solely because they are easy to code. This is a judgment based on the trade-offs below, not a claim that Hevy uses Gymvisual. [G1–G5, B1, A1]

Research only: no assets bought, packages installed, code changed, or trial performed.

## Date, versions, and evidence limits

Checked **2026-10-09**. Local repository commit: `c653f1d9852834788ed3b42a0e5109795539172e`. Apple's live documentation was checked for the iOS 27 project; APIs below mostly predate iOS 27. Blender manual: **4.5 LTS** (older version deliberately pinned); Lottie format: **1.0**, still a work-in-progress specification; Lottie iOS release: **4.6.1**, tag object `f4db77d7feacba0c2360b84a40c38a6ce8ff399d`; Rive iOS source: `ff3f6fd473c60223902263fbac97a9d7de9614df`, live Apple integration docs show dependency `6.24.0`. These are versions checked, not proposed deployment pins. [B1, V1–V6]

App Store listings checked: Hevy **3.1.16**, Strong **6.5.1**, Fitbod **8.35.1**. Dynamic vendor pages and prices are retrieval-date snapshots, not immutable versions. Most sources are undated or older than one month; age is given where available. MuscleWiki terms explicitly updated **2026-10-08**; Google's Gemini terms effective **2026-03-23**; the Veo 3.1 Lite card is **April 2026**; Apple motion guidance last lists a change on **2025-09-09**; HEVC-alpha session is **2019**; squat experiment is **2024**. No newer movement-specific validation was established. [C1–C3, M1, I1–I4, A1, A4, P1]

Sources were located with `ketch search` and read with `ketch scrape <url> --max-chars <limit>`; source code licences were read through GitHub's API at the pins above. The web-search tool failed twice, so no model-generated web summary is evidence. Hevy's Help Centre and Fitbod's exercise website returned 403 to direct scraping; search snippets from them are discovery leads only. Their developer-written App Store descriptions supply the verified comparison below. **Unknown** means not verified, not proof that something does not exist.

## Local constraints

- The catalog contains **66 exercises**, verified with `python3 -c 'import json; print(len(json.load(open("App/Resources/starter-exercises.json"))))'` → `66`. Dumbbell Bench Press is at `App/Resources/starter-exercises.json:3`, Dumbbell Goblet Squat at `:267`; Hip Flexor Stretch was not found by `rg -n 'Goblet|Bench Press|Hip Flexor' App/Resources/starter-exercises.json`. Stretches are incoming, so coverage and size calculations must add them separately. [L1]
- No Swift package may be added without user approval. Drawing and playback rules belong in logic, not inline view policy; interactive controls need accessibility identifiers. [L2]
- Native system controls, semantic colors, amber for actions, Dynamic Type, and no new sound or haptics apply. Existing motion rules prohibit loops and custom timing curves and limit interface animations to about half a second. A six-second demo is instructional media, but **ticket 28 must explicitly distinguish it from interface animation and approve any replay/loop exception**; this report does not silently override those rules. Prefer a still poster and tap-to-play once initially, with Replay rather than automatic repeated motion. [L3, A1]
- `command -v blender` produced no output: Blender is **not found on PATH**, not proven absent elsewhere. `command -v ketch` → `/opt/homebrew/bin/ketch`. Existing notes/history contained no settled exercise-animation approach (`rg` in `docs/research` and tickets 27–29; `git log -5 --oneline -- docs/research`). [L1]

## What other apps actually document

| Product | Verified demonstration medium | Origin and exact rendering method | Formats and size |
|---|---|---|---|
| Hevy | Developer says “hundreds of exercises with free high-quality videos”; its own goblet-squat web guide also uses photographic JPEG illustrations. Its Trainer page search result mentions animations, but that page was not used to establish the app's internal renderer. [C1, C4] | **Unknown** whether app clips are rendered 3D, filmed, or mixed, and whether produced in-house or licensed. **Unknown** whether Gymvisual supplies them. Visual resemblance is not licence evidence. | App asset container, codec, resolution, duration, per-file bytes, and offline/download policy **unknown**. Listing size **303.3 MB** is the whole app, not a demonstration budget. [C1] |
| Strong | Developer explicitly advertises “detailed exercise instructions with a growing library of animated videos.” [C2] | Animation is verified; 3D versus 2D and supplier/in-house origin **unknown**. | Per-demo formats/bytes **unknown**. Whole listing **135.4 MB**, not proof of media payload. [C2] |
| Fitbod | Developer advertises hi-resolution, multi-angle videos and detailed instructions across 1,000+ exercises. [C3] | Exact production method, filmed versus rendered, and supplier **unknown** in the successfully read primary text. Website snippets describing demonstration videos do not resolve provenance. | Codec, per-demo bytes, and offline behavior **unknown**; whole listing **204.9 MB**. [C3] |
| ExRx, as a comparable instructional library rather than an app | Dumbbell Bench Press instructions link Vimeo mount/dismount demonstration videos and describe the weight path. [P4] | Ownership/licensing for reuse in Blocklog **unknown**; viewing a public instructional reference does not grant reuse rights. | Playback links verified, distributable master formats/bytes **unknown**. |
| MuscleWiki, as an app-content supplier | Offers API video demonstrations and streams media within client applications. [M1–M3] | Master production provenance **unknown** here; licensed access is explicitly documented. | Standard terms prohibit offline storage or bundling; stream-only avoids media bundle bytes but creates network/service dependence. Per-video size **unknown**. [M1] |

**Decision implication:** Public first-party material supports video/animated demonstrations as the product pattern, not a specific common pipeline or shared vendor. Do not rip competitors' clips, equate whole-app size with clip size, or claim that “Hevy uses Gymvisual” without first-party confirmation. [C1–C4, G1]

## Approach trade-offs

The effort and quality comparisons here are **engineering judgments** for this app's terminal-only workflow. API, format, and licence facts have sources; no approach was benchmarked or medically validated in this research.

### 1. Code-drawn 2D: SwiftUI Canvas or Shape with keyframed joints

**Capabilities:** Canvas supplies immediate-mode paths, drawing, transforms, blending, and filters. Apple explicitly warns that individual canvas elements have no accessibility or interactivity. Draw the figure as media and put text descriptions and real controls outside it. No third-party Swift package is required. [A2]

**Look and accuracy:** A carefully authored silhouette with depth ordering, visible hands and equipment, and anatomical proportions can look intentional; an articulated stick figure cannot demonstrate grip, shoulder rotation, or out-of-plane elbow paths adequately. Side-on squats/stretches are easier than bench presses. Segment lengths, contact points, joint rotations, and easing all need authoring; a spring-driven bent limb is not biomechanics. This is a representational limitation and engineering judgment, not an Apple guarantee. [A2, P1–P4]

**Authoring and checking:** Excellent terminal fit: plain pose data and deterministic geometry can yield testable endpoints, sampled frames, bounding boxes, contact constraints, and a contact sheet. Render intermediate poses too: valid endpoints do not ensure valid interpolation. Semantic foregrounds can adapt directly to appearance and Increase Contrast. Estimated asset size should be measured from actual pose data; “a few kilobytes” is **unknown** until authored. Code, runtime drawing, and tests also contribute to the app. [A2, A3]

**Accessibility/licensing:** Original geometry avoids an external media licence, but reference photos/illustrations still retain their rights. Freeze to approved instructional poses for Reduce Motion; supply an equivalent movement description, not an accessibility tree of body segments. [A2, A3, A5]

**Verdict:** Good low-dependency fallback or schematic, not the default for a user asking for polished Hevy-like demonstrations.

### 2. Vector runtimes: Lottie and Rive

**Lottie:** Airbnb documents After Effects → Bodymovin → JSON → native rendering. The 1.0 format specification documents JSON and a machine-readable schema, so an agent can author a constrained JSON subset directly without After Effects, then validate and sample it in the iOS renderer. That is a custom authoring workflow, not evidence that every After Effects feature works everywhere. It still requires the same drawing/pose work as Canvas. [V1, V2]

**Package approval:** `https://github.com/airbnb/lottie-ios`, product `Lottie`, is an added dependency requiring approval. Release 4.6.1's runtime is Apache-2.0: retain required licence/notices and mark distributed modifications as applicable. Runtime licence does not license downloaded animations or After Effects. Exact runtime and demonstration bytes **unknown**. [V3, L2]

**Rive is now genuinely terminal-authorable:** Current first-party CLI docs explicitly support Rive Markup Language (RML) scene creation, `.riv` builds, `.rev` editor files, headless screenshots at chosen times/sizes, inspection, compilation verification, Luau tests, and benchmarking. It is **incorrect to reject current Rive as GUI-only**. `rive myproject --screenshot=out.png --advance=1s`, `--verify --format=json`, and `--test --format=json` are documented checks. Publishing requires browser sign-in; headless screenshot/testing does not. It was not installed or run here, so local availability and CLI version remain **unknown**. [V4, V5]

**Authoring/licensing:** Traditional Rive authoring is in its editor; scripting and data binding allow procedural figures. Current pricing says the CLI/editor are on Free with splash-screen exports, and Cadet is displayed at **$9/seat/month** to remove the splash screen. The export tutorial still says paid plans are required; **sources disagree**. Reconfirm actual export behavior and billing cadence before choosing it. Do not treat a splash-screen-bearing free asset as a good fit for Blocklog. [V6–V8]

**Package approval:** `https://github.com/rive-app/rive-ios`, product `RiveRuntime`, requires approval. Inspected runtime licence is MIT; retain its notice. Current integration docs support SwiftUI and pause/resume. Feature support varies by renderer/runtime; a CLI PNG is not proof that the exported scene works identically on iOS. [V6, V9]

**Shared trade-offs:** Polished vectors, stable proportions, compact shared art and reusable poses are plausible, but no runtime fixes unsafe geometry. Color binding/theme variants must be authored, not assumed. Pause at an instructional key pose and pair with static steps for Reduce Motion. JSON/`.riv` plus runtime bytes versus Canvas or compressed video are **unknown** until the same three movements are built. Bitmap-rich vectors need not be small. [V1–V9, A3, A5]

**Verdict:** Rive is the stronger terminal-first vector option now; Lottie is useful when a licensed designer-authored library already exists, not as an excuse to build an extra custom exporter.

### 3. Original 3D, live or pre-rendered

**Shared production work:** Obtain or create a humanoid mesh, rig, materials, props, and exercise-specific movement. Mocap is only a starting point: retargeting must preserve hand contact with dumbbells, bench support, foot/knee contact, and the chosen movement variant. Neither a realistic renderer nor an imported recording is a form certificate. [P1–P4, D1–D3]

**Headless pre-rendering:** Blender 4.5 LTS documents `--background`, `--python`, frame/animation rendering, output paths, CPU/Metal rendering options, and Python-error exit codes. An agent can script an original low-detail but well-proportioned character and PowerBlock-like rectangular props, keyframe or solve contact constraints, then render transparent PNG masters and contact sheets. Authoring a convincing rig and deformation is materially more work than playing licensed clips; exact effort **unknown** until the trial. No GUI authoring is technically required. [B1]

**Delivery:** Encode reviewed frames to H.264/HEVC video for native playback; for transparent output use **Apple HEVC with alpha**, preferably a `.mov` master/delivery workflow verified on the phone. Apple's 2019 session documents AVAssetWriter/VideoToolbox encoding, AVPlayer/AVPlayerLayer playback, and AVAssetImageGenerator still extraction. HEVC alpha is a particular multilayer encoding, not something guaranteed by an arbitrary “HEVC” export; do not assume stock FFmpeg/libx265 retains it. Apple's encoder is a terminal-scriptable route. No Swift package is required for AVFoundation/VideoToolbox. [A4]

**Appearance:** Transparency allows system backgrounds; the character's baked colors do not automatically become semantic colors. Design neutral materials that remain legible in both appearances or render light/dark variants, approximately doubling relevant delivery bytes. A white opaque rectangle is a visible mismatch in Dark Mode; chroma-keying cannot recover occluded anatomy and is not a substitute for a real alpha master. Avoid amber anatomy highlights: the app reserves amber for actions. [A3, A4, L3]

**Size/performance:** Video trades fixed camera angles and per-clip bytes for a simple native player; bake only needed views, not arbitrary rotations. Target delivery bitrate/quality must be measured; alpha quality contributes extra bytes beyond the base-layer bitrate. Playback energy and device decoding behavior are **unknown** until tested. [A4]

**Live 3D:** RealityKit supports skeletal poses, IK, and retargeting APIs; Apple's USD feature table documents USD/USDA/USDC/USDZ and skeleton animation support. Reusable geometry plus compact movement tracks may amortize catalog size and allow alternate camera angles; shaders, lighting, mesh import, deformation and device runtime performance add failure modes. Not every USD feature imports; Blender export → iOS rendering requires an actual round-trip check. Appearance/material changes and freezing poses are possible app work, not automatic accessibility. Native RealityKit requires no added Swift package. [A6, A7]

**SceneKit:** Apple explicitly deprecates SceneKit in favor of RealityKit (iOS 26 deprecation). Do not start the iOS 27 feature on it merely because older tutorials are plentiful. [A8]

**Motion sources:**

- **Mixamo:** Adobe says it is free with an Adobe ID, royalty-free for personal/commercial/nonprofit projects including films and games, and limited to bipedal humanoids. Its documented service uses uploaded characters and rigging; a supported unattended CLI/API and exact trial-exercise coverage are **unknown**. Do not base a terminal-only plan on browser auto-rigging automation. Original rigs or user-supplied downloaded characters avoid that dependency. Preserve the source's terms rather than redistribute a raw asset pack. [D1]
- **CMU mocap:** First-party homepage permits data in commercially sold products but not direct resale, even converted; FAQ permits copying/modifying/redistributing and disclaims quality. Native formats include ASF/AMC joint angles and C3D markers; converted BVH links are external sources with their own provenance to check. No exact three-exercise coverage or dumbbell/bench-prop capture was verified. This is promising reusable motion input, not a finished workout pack. [D2, D3]
- **AMASS:** Its actual licence is restricted to noncommercial research/education/art, prohibits commercial artefacts and distribution without permission, and offers commercial licensing by inquiry. Even a personal app is not automatically the permitted scientific/artistic use. Do not bundle or render it into app assets without appropriate permission; “open dataset” is not a commercial licence. [D4]

**Verdict:** Original headless 3D pre-rendering is the best owned-asset fallback; live RealityKit is justified only if changing viewpoints becomes an approved product need.

### 4. Licensed animation packs

**Gymvisual:** The vendor explicitly offers workout animation videos, GIFs, and illustrations for apps. Its licence grants perpetual worldwide one-time-fee use of purchased, nonwatermarked media to enhance Android/iOS apps. Copyright stays with the vendor; public previews/thumbnails are not licensed by a purchase of unrelated content. It prohibits resale/redistribution for reuse, stock distribution and assigning rights. Ordinary app embedding is expressly permitted, but publishing raw masters in a public source repository is not safe to assume permitted. Keep masters/delivery assets out of public distribution as a standalone library and ask about repository storage. [G1, G2]

**Critical AI limitation:** The licence prohibits processing/modifying media using AI systems and using it as the basis for AI-generated visuals, while allowing text/analytical AI features. **Unknown** whether vendor considers an agent issuing deterministic transcode commands or inspecting frames an allowed analytical operation. Obtain written permission covering agent-commanded encoding, poster extraction, visual checking, background handling, bundled/offline iOS distribution and repository storage **before handing the files to an agent**. Never feed these clips to an image/video generator or trace them into AI-authored replacement animations without explicit additional rights. [G1]

**Prices:** Published quantity rules: videos **$10 each for 1–4, $6 each for 5+**; GIFs **$3.60 each for 1–9, $0.90 each for 10+**; illustrations **$3 each for 1–9, $0.75 each for 10+**. Product pages also show **40% off for 3+ different items**, conflicting with the video rules' threshold. Three videos therefore have a rules-page budget of **$30**, possibly **$18** at the advertised cart discount; checkout price/taxes and applicable currency must be confirmed. A hypothetical one-video-per-catalog purchase is **66 × $6 = $396**, not a quote or a verified coverage match. Stretches, angle variants and missing movements are additional. [G2–G5]

**Verified trial listings and documented master formats:**

| Movement | Documented format and dimensions | Duration, rate | Computed byte estimate, not a downloaded measurement |
|---|---|---|---|
| Dumbbell Goblet Squat | MP4, 1920 × 1080; codec **unknown** | 6 s, 29.97 fps, 98.26 Mbps | `98.26 × 6 / 8` ≈ **73.70 MB** decimal. [G3] |
| Dumbbell Bench Press | MOV, 1920 × 1080, **Motion JPEG** | 6.061 s, 29.97 fps, 98.26 Mbps | ≈ **74.44 MB** decimal. [G4] |
| Kneeling Hip Flexor Stretch | MP4, 1920 × 1080; codec **unknown** | 6 s, 29.97 fps, 98.26 Mbps | ≈ **73.70 MB** decimal. [G5] |

These listings have “Basic grey” styling; squat/bench also expose “Full color” in search/product metadata. Transparency, alternate angles, exact downloaded byte counts, current visual quality, and PowerBlock-specific hand placement are **unknown**. The three master estimates total roughly **222 MB**; shipping masters unchanged is not a reasonable starting point. For illustration only, 66 six-second clips at the listed rate would be **4.86 GB** decimal. At a proposed **1–2 Mbps**, six-second opaque delivery clips would be **0.75–1.5 MB** each, **49.5–99 MB** for 66, before posters/container overhead/extra views; this is bitrate arithmetic, **not a measured achievable quality claim**, and alpha adds further bytes. Obtain compression rights and inspect hands/joints after encoding. [G1, G3–G5, A4]

**MuscleWiki alternative:** Its current API terms require stream playback, prohibit downloading/exporting/permanent media storage, require legal attribution and preservation of branding, and prohibit AI training without permission. Pricing starts at **$10/month for 1,000 direct API calls**; Free is Playground-only. This is not an offline animation pack under its standard terms. A custom offline licence price is **unknown**. A REST integration requires no Swift SDK package, but creates recurring cost, connectivity, quotas and key-management work inappropriate for a small personal offline-first logger unless explicitly chosen. [M1–M3]

**Verdict:** Small licensed pack is the least authoring work toward a polished result, conditional on rights, complete coverage and the user's visual approval. No library's marketing assertion of proper form replaces movement review.

### 5. AI image/video generation

**A verified terminal route exists:** Google's current video docs describe Gemini Omni Flash as their default video model and Veo 3.1 for specific capabilities; Veo docs give REST/Python generation, first/last-frame control and up to three reference images, with downloadable MP4. These are production-tool possibilities, not a verified exercise pipeline. API calls from a build script need no iOS Swift package. Specific model access, pricing and success rate for this catalog are **unknown**. [I1, I2]

**Consistency and correctness:** Veo 3's published model card admits that maintaining complete consistency through complex scenes/motion remains challenging; the 3.1 Lite card refers to that limitation. Character/equipment consistency across 66 demonstrations, exact joint trajectories, credible grips and seamless loops have not been established by that benchmark. Image generation can propose style or stills but provides no temporal/biomechanical guarantee; independent regeneration of key frames risks changed proportions and equipment. Do not turn visually plausible output into authoritative exercise instruction. [I3, I4, P1–P4]

**Licensing:** Gemini API additional terms say Google does not claim ownership of generated content, may produce similar outputs, and make the user responsible for lawful use/attribution where required. They prohibit clinical practice/medical advice use. Paid and unpaid services handle uploaded content differently; unpaid inputs may be used for product improvement/human review. Output-ownership language is not proof of copyright protection, exclusivity, reference-image rights or an indemnity. Gymvisual references cannot be uploaded for generation under its standard licence. Terms for any other image/video service or local model weights must be checked separately; no blanket “AI is royalty-free” claim is justified. [I5, G1]

**Appearance/size/accessibility:** Generated videos inherit the same delivery, baked-background and Reduce Motion issues as other video. Reliable alpha, a stable monochrome/semantic palette, and post-compression correctness are **unknown**. Generated stills can be described and shown as fallbacks only after the same human form review. [A3–A5, I1–I4]

**Verdict:** Use AI to write deterministic geometry/rig scripts, not to generate final instructional anatomy. Keep generative images/video to optional style exploration with owned inputs, not the trial's canonical demos.

## Correctness and accessibility checks an agent can prepare

This is a proposed verification protocol, **not validation already performed**. Automated checks catch production defects; the phone review and movement expert review establish whether a human can learn the intended movement. User aesthetic approval alone does not establish biomechanical safety.

### Choose a variant and reference before drawing

1. **Dumbbell Goblet Squat:** ACE describes shoulder-width feet, vertical dumbbell at chest, close elbows, straight back, and hips below knees. Hevy's own guide instead says comfortable depth, ideally thighs parallel. These are different depth prescriptions, not interchangeable numerical targets: ticket 28 must choose a comfortable illustrative variant and say that depth varies. Show visible feet, a controlled coordinated hip/knee/ankle bend, and secure close-to-chest grip; do not impose “knees must never pass toes.” [P2, C4]
2. **Dumbbell Bench Press:** ExRx's own exercise instructions specify dumbbells at the sides of the chest, bent arms under them, press to extension, and a slight arcing path inward over the shoulders at the top. It is a specialist instructional reference, **not original experimental biomechanics research**. Show feet/bench support, forearm/load alignment, both arms, and a controlled lower/press cycle; choose a three-quarter view that exposes shoulder/elbow and weight paths. A side view alone can hide a wrongly flared elbow. Exact universal shoulder-abduction angles are **unknown** from this source; do not invent a 45°/90° “safe range” test. [P4]
3. **Hip Flexor Stretch:** Use ACE's kneeling variant, not a lunge repetition. ACE specifies front knee over ankle, initial front hip at 90°, tall spine, braced core, stable level pelvis without anterior rotation, a gentle forward shift with rear glute contraction, and an actual hold. Show setup → ease into hold → hold; avoid rhythmic bouncing or implying that a six-second loop is the recommended stretch duration. ACE's guidance says 30–45 seconds per hold, but the app's stretch timer remains its own planned rule. [P3]

**Numerical sanity reference:** Kasahara et al.'s **2024 original experiment** recorded 26 healthy young adults performing parallel, arms-crossed squats. Reported movement ranges: trunk **34.7° ± 11.5°**, hip **82.7° ± 6.1°**, knee **107.2° ± 11.1°**, ankle dorsiflexion **32.8° ± 5.6°**. It found coordinated knee/hip/ankle contributions, with ankle peak occurring earlier than the other joint peaks. These are study-specific motion ranges, **not absolute pose angles, goblet-squat mandates or clinical safety limits**. Define each joint's zero/axis convention before comparison; a 2D image angle cannot be substituted for a 3D Cardan joint angle. [P1]

### Reproducible visual and geometry review

- Save the reference URLs, chosen variant, coordinate/joint conventions, key times, authoring tool/version and rights beside each asset. Compare independently against published reference poses; do not train on or trace restricted media. Prefer an original user-owned form-reference recording if the user supplies one and consents to agent inspection. [G1, P1–P4]
- Sample setup, quarter, bottom/end-range, midpoint return, end and **every intermediate frame** for geometry assertions: fixed segment lengths, planted feet/knees, hand/prop contact, no bench/body intersections, no reversed joints, no mesh flips, no cropping. Angles computed from joint points can be checked with a dot-product/arccos calculation, but allowable ranges must cite the chosen reference and coordinate convention. Arbitrary tolerances are engineering thresholds, not medical guarantees. [P1, B1, V5]
- Export front/side/three-quarter contact sheets where needed; check wrists, pelvis and props at readable phone size, not only zoomed-out desktop size. Projection/occlusion make a single screenshot insufficient. For proprietary clips, only do AI frame inspection after rights clarification; otherwise have the user/expert review them. [P1–P4, G1]
- Check decoded, compressed delivery frames, not just masters; verify poster/keyframe alignment and endpoint behavior. For HEVC alpha test compositing on actual light/dark grouped backgrounds, halos/premultiplication and alpha-channel presence. Do not infer decoder correctness from `ffprobe` or a simulator screenshot alone. [A4]
- Have a qualified trainer or physiotherapist review the chosen form cues and rendered movements before claiming correctness; expertise/availability/cost are **unknown**. Show clear wording that demos illustrate a movement rather than diagnose or prescribe an individual's range. [P1–P4]

### Accessibility and calm playback

Apple's HIG says motion should be purposeful, optional and cancellable, never the sole communication channel. It also asks for meaningful VoiceOver descriptions, larger text, contrast in both appearances, system colors and alternatives to complex gestures. SwiftUI exposes `accessibilityReduceMotion`; Apple says to avoid large, especially simulated-3D, animation when true. It additionally exposes `accessibilityPlayAnimatedImages` for automatic animated-image playback. These are app decisions for custom instructional media; do not assume AVPlayer, Canvas or a third-party renderer automatically honors them. [A1, A3, A5]

**Proposed behavior:** Still poster until Play is requested; immediate Pause/Replay, no autoplay in catalog rows, no camera orbit/pan or pulsing highlights. Stop when offscreen/backgrounded. Under Reduce Motion, show static setup/end-range poses with manual Next/Previous and text, not a slowed rotating character. Turning the setting on during playback stops movement. If ticket 28 later approves explicit playback with Reduce Motion enabled, it must preserve an equally informative motion-free option. [A1, A5, L3]

**VoiceOver:** Expose the title, setup, movement, return/hold and key cautions as real Dynamic Type text. For example: “Hip Flexor Stretch. Kneel on one knee with the other foot in front. Keep your torso tall and pelvis level. Gently move forward and squeeze the glute on the kneeling side. Hold without arching your lower back.” Hide redundant decorative figure internals from accessibility; label Play/Pause/Replay and step controls naturally, with state values. Avoid live announcements on every animation frame. Minimum **44 × 44 point** targets and identifiers follow the stricter local rule, even though Apple's current HIG lists a smaller minimum alongside the 44-point default. No new audio/haptics are needed. [P3, A2, A3, L2, L3]

## Remaining unknowns and purchase gates

- Competitors' exact asset suppliers, in-house/licensed provenance, 2D/3D production method, asset bytes/codecs, and offline policies remain **unknown**; no disassembled app bundles or user-phone checks were performed. [C1–C3]
- Full 66-exercise plus upcoming-stretch coverage is **unknown**. Matching by broad exercise name alone is insufficient; grips, incline, stance and stretch side/variant need manual confirmation. [L1, G3–G5]
- Gymvisual's permission for agent-assisted inspection/transcoding/poster extraction, transparent output, public/private repository storage and current cart price are **unknown**. These can change the top recommendation. [G1–G5]
- Actual alpha availability, delivered appearance, compression quality, device energy use, decoder start latency, runtime package bytes, exported-vector sizes and original 3D authoring effort are **unknown** until measured. [A4, V1–V9, B1]
- Rive's CLI works headlessly according to current docs, but was not installed/run. Pricing/export docs disagree; current billing/export entitlements and exact CLI release are **unknown**. [V4–V8]
- No comprehensive universal “safe joint angles” source or automatic medical certification method was established; illustrations should not encode population averages as personal requirements. [P1–P4]

## Source register

Every live web source below was checked on 2026-10-09 unless explicitly described as a discovery-only result. Pinning a source-code licence does not pin dynamic editor pricing or hosted documentation.

### Local

- **L1:** Repository `c653f1d9852834788ed3b42a0e5109795539172e`; `App/Resources/starter-exercises.json:3,267`; command/output observations in Local constraints. Ticket scope: `.scratch/blocklog/issues/27-exercise-animations-research.md:14–28` (untracked ticket, no commit attribution).
- **L2:** `AGENTS.md:46–61` at the repository commit above, especially package rule at `:51` and identifiers at `:58–59`.
- **L3:** `docs/design.md:7–35,39–59,99–107` at that commit: native presentation/colors/type/motion, no unsolicited sound/haptics, accessibility. Future behavior in this report is a proposal, not an existing contract.

### Competitors

- **C1:** [Hevy developer App Store listing, version 3.1.16](https://apps.apple.com/us/app/hevy-workout-tracker-gym-log/id1458862350).
- **C2:** [Strong developer App Store listing, version 6.5.1](https://apps.apple.com/us/app/strong-workout-tracker-gym-log/id464254577).
- **C3:** [Fitbod developer App Store listing, version 8.35.1](https://apps.apple.com/us/app/fitbod-workout-fitness-plans/id1041517543).
- **C4:** [Hevy Goblet Squat guide, undated live page](https://www.hevyapp.com/exercises/how-to-goblet-squat/); [Hevy dumbbell leg workout guide](https://www.hevyapp.com/dumbbell-leg-workouts/). Photographic illustrations are the web-guide medium, not proof of the app's rendering pipeline.

### Apple

- **A1:** [HIG Motion, last listed change 2025-09-09](https://developer.apple.com/design/human-interface-guidelines/motion).
- **A2:** [SwiftUI Canvas, introduced iOS 15](https://developer.apple.com/documentation/swiftui/canvas).
- **A3:** [HIG Accessibility, live/undated](https://developer.apple.com/design/human-interface-guidelines/accessibility).
- **A4:** [WWDC19 session 506: HEVC Video with Alpha, 2019 transcript](https://developer.apple.com/videos/play/wwdc19/506/); [current associated AVFoundation sample overview](https://developer.apple.com/documentation/avfoundation/using-hevc-video-with-alpha); [interoperability profile v0.9, 2019-05-30](https://developer.apple.com/av-foundation/HEVC-Video-with-Alpha-Interoperability-Profile.pdf) (profile located, detailed interoperability claims here rely on the read session, not an independent PDF audit).
- **A5:** [SwiftUI accessibilityReduceMotion, iOS 13+](https://developer.apple.com/documentation/swiftui/environmentvalues/accessibilityreducemotion), including its link/description of `accessibilityPlayAnimatedImages`.
- **A6:** [RealityKit character control, skeletons and inverse kinematics, live docs](https://developer.apple.com/documentation/realitykit/game-development-character-skeletons).
- **A7:** [Validating feature support for USD files, live Apple feature table](https://developer.apple.com/documentation/usd/validating-usd-files).
- **A8:** [SceneKit documentation, deprecated iOS 26](https://developer.apple.com/documentation/scenekit).

### Vector and authoring tools

- **B1:** [Blender 4.5 LTS command-line arguments](https://docs.blender.org/manual/en/4.5/advanced/command_line/arguments.html).
- **V1:** [Airbnb Lottie docs, established After Effects/Bodymovin workflow, undated](https://airbnb.io/lottie/). Do not apply its generic GIF-size marketing ratios as measured exercise results.
- **V2:** [Lottie Animation Format 1.0](https://lottie.github.io/lottie-spec/1.0/).
- **V3:** [lottie-ios LICENSE at 4.6.1](https://github.com/airbnb/lottie-ios/blob/4.6.1/LICENSE); `gh api repos/airbnb/lottie-ios/releases/latest --jq '.tag_name'` → `4.6.1`; `gh api repos/airbnb/lottie-ios/git/ref/tags/4.6.1 --jq '.object.sha'` → `f4db77d7feacba0c2360b84a40c38a6ce8ff399d`.
- **V4:** [Rive CLI overview, live/undated](https://rive.app/docs/cli/overview).
- **V5:** [Rive CLI examples: headless screenshots, verify, tests and performance, live/undated](https://rive.app/docs/cli/examples).
- **V6:** [Rive Apple runtime integration docs, currently shows 6.24.0](https://rive.app/docs/runtimes/apple/apple).
- **V7:** [Rive scripting getting started, live/undated](https://rive.app/docs/scripting/getting-started); [exporting for runtime](https://rive.app/docs/editor/exporting).
- **V8:** [Rive pricing, live snapshot](https://rive.app/pricing); export entitlement conflict with V7 noted above; displayed Cadet $9 billing cadence requires checkout confirmation.
- **V9:** [rive-ios MIT licence at ff3f6fd473c60223902263fbac97a9d7de9614df](https://github.com/rive-app/rive-ios/blob/ff3f6fd473c60223902263fbac97a9d7de9614df/LICENSE); `gh api repos/rive-app/rive-ios/commits/HEAD --jq '.sha'` returned that commit.

### Asset/motion licences

- **G1:** [Gymvisual Non-Exclusive Commercial Royalty-Free License, live/undated](https://gymvisual.com/content/9-license).
- **G2:** [Gymvisual price rules, live/undated](https://gymvisual.com/content/6-price-rules); [vendor overview of media/app uses](https://gymvisual.com/).
- **G3:** [Gymvisual Dumbbell Goblet Squat video listing 9294](https://gymvisual.com/videos/9294-dumbbell-goblet-squat.html).
- **G4:** [Gymvisual Dumbbell Bench Press video listing 1355](https://gymvisual.com/videos/1355-dumbbell-bench-press.html).
- **G5:** [Gymvisual Kneeling Hip Flexor Stretch video listing 11198](https://gymvisual.com/videos/11198-kneeling-hip-flexor-stretch.html).
- **M1:** [MuscleWiki API Terms, updated 2026-10-08](https://api.musclewiki.com/api-terms).
- **M2:** [MuscleWiki first-party pricing Markdown mirror, live snapshot](https://api.musclewiki.com/pricing.md).
- **M3:** [MuscleWiki API FAQ, live snapshot](https://api.musclewiki.com/faq).
- **D1:** [Adobe Mixamo FAQ, older established service docs](https://helpx.adobe.com/creative-cloud/faq/mixamo-faq.html) (search metadata dates English documentation 2021-09-14; scraped text does not repeat that timestamp).
- **D2:** [CMU motion capture homepage, older/undated](https://mocap.cs.cmu.edu/).
- **D3:** [CMU motion capture FAQ, older/undated](https://mocap.cs.cmu.edu/faqs.php).
- **D4:** [AMASS first-party dataset licence, associated 2019 dataset, live terms](https://amass.is.tue.mpg.de/license.html).

### Generative media

- **I1:** [Google video-generation model selection docs, live snapshot](https://ai.google.dev/gemini-api/docs/video).
- **I2:** [Veo 3.1 API generation docs, live snapshot](https://ai.google.dev/gemini-api/docs/veo).
- **I3:** [Veo 3 model card, older model version explicitly used for limitations](https://storage.googleapis.com/deepmind-media/Model-Cards/Veo-3-Model-Card.pdf), Known Limitations section.
- **I4:** [Veo 3.1 Lite model card, published 2026-04-08, refers limitations to I3](https://deepmind.google/models/model-cards/veo-3-1-lite/).
- **I5:** [Gemini API Additional Terms, effective 2026-03-23](https://ai.google.dev/gemini-api/terms), Use Restrictions / Generated Content / data-use sections.

### Movement references

- **P1:** [Kasahara et al., Relationship among the COM Motion, the Lower Extremity and the Trunk during the Squat, 2024](https://pmc.ncbi.nlm.nih.gov/articles/PMC11307177/), [DOI 10.5114/jhk/183066](https://doi.org/10.5114/jhk/183066), Methods / Results / Figure 1. Original experiment, not a personalized exercise prescription.
- **P2:** [ACE Goblet Squat, undated first-party instructional guide](https://www.acefitness.org/resources/everyone/exercise-library/362/goblet-squat/).
- **P3:** [ACE Kneeling Hip-flexor Stretch, undated first-party instructional guide](https://www.acefitness.org/resources/everyone/exercise-library/142/kneeling-hip-flexor-stretch/).
- **P4:** [ExRx Dumbbell Bench Press, undated first-party instructional guide](https://exrx.net/WeightExercises/PectoralSternal/DBBenchPress). Specialist guidance, not a new experimental study; no universal numerical safety claim is derived from it.

## Ranked recommendation

This ranking is a recommendation for **polish plus terminal maintainability**, conditional on the unresolved rights and visual trial, rather than a benchmark result.

1. **Licensed pre-rendered clips with native AVFoundation playback:** Closest low-authoring-effort route to a polished demonstration library, but proceed only with written clearance for agent-assisted processing/checking and satisfactory appearance/coverage. [G1–G5, A4]
2. **Original scripted 3D pre-rendered to video/HEVC alpha:** Best owned, reproducible terminal-authored fallback with convincing depth and equipment, at the cost of rigging/pose-review effort. [B1, A4, P1–P4]
3. **Rive authored with its CLI/RML:** Strong current terminal/headless vector workflow and reusable figure assets, but requires package approval, export-entitlement confirmation, and proving the bench-press view is instructive. [V4–V9, L2]
4. **Native Canvas/Shape silhouettes:** Smallest dependency-free programmable option and easiest semantic-color integration, but weakest representation of grip/rotation/depth unless substantial bespoke drawing is done. [A2, A3, P1–P4]
5. **Live RealityKit:** Technically capable and native, but changing camera viewpoints is not yet a requirement worth the extra rendering/import/runtime work. [A6, A7]
6. **Lottie:** Suitable if already-made, correctly licensed vector demos are found; otherwise it repeats Canvas's authoring work while adding a package and exporter/format maintenance. [V1–V3, L2]
7. **Generative image/video models as final demos:** Easy to call from a terminal, but consistency and biomechanics remain unproven, with additional input/output-rights and review burdens. [I1–I5, G1]

## What ticket 29 should build

**Build one three-movement instructional demo surface on the phone, not the full catalog or a live-3D engine.** First clear Gymvisual rights and get the user to approve the approximate $30 trial spend (actual cart price unresolved); choose its Dumbbell Goblet Squat, Dumbbell Bench Press, and Kneeling Hip Flexor Stretch assets after confirming the variants and look. If permissions or appearance fail, author those same three with one original headless Blender rig and props; do not silently change to lower-quality stick figures. Rive is a viable alternate trial only if the user deliberately chooses the vector look and approves its package. [G1–G5, B1, V4–V9]

Deliver three offline clips plus setup/end-range stills and written movement steps, with Play/Pause/Replay, motion-free manual steps for Reduce Motion, VoiceOver text, Dynamic Type, native controls and no sound. Use one calm view with a fixed camera; squat and stretch must show contact/pelvis, bench must show both forearm and weight paths. The stretch must demonstrate an entry and hold, not repeated lunging. For original transparent masters, verify Apple HEVC-alpha playback on the phone; for opaque vendor assets, require user approval of their light/dark presentation rather than pretending transparency exists. No third-party Swift playback package is needed. [A1–A5, P2–P4, L2, L3]

The trial must produce reproducible contact sheets/reference checks, a human form review, measured delivery bytes and catalog-size projection, and real-phone checks in light/dark, Reduce Motion toggled while playing, largest text, VoiceOver, offline mode and repeated open/close/background. Proposed initial size gate: **at most 2 MB per six-second delivery clip** plus measured posters, subject to readable hands/joints; report rather than hide a failure. Record player start latency and whether offscreen work stops; no universal battery/latency promise is made. The user judges polish and clarity against the Hevy-like expectation **before** ticket 30 expands the catalog. [A1, A3–A5, G3–G5, L2, L3]
