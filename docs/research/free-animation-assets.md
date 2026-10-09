# Free prebuilt assets for Blocklog's exercise animations

## Question and short answer

Which free figures, motion capture, props and finished exercise media could Blocklog bundle (or build on) so that ticket 28's scripted-Blender pipeline has less to build, and under what exact licence terms?

**Answer.** Adopt **MPFB** (the MakeHuman Blender add-on) for the figure, with Quaternius's Universal Base Characters as a fallback figure. Everything else saves little. [M1–M4, Q1–Q3]

- **Figure and rig (adopt MPFB):** It is the one big saving. MPFB generates a rigged human inside Blender by Python script, and its assets and output are CC0.
- **Motion (do not expect a saving):** No free source has dumbbell exercises. 50 of the 66 starter exercises use dumbbells, so those animations must be keyframed by us. CMU mocap has squats, lunges and generic stretches, and could seed 3–5 exercises. Mixamo may have 6–8 bodyweight clips, but its terms carry an AI/ML clause and it works only through a browser login.
- **Props:** No free CC0 dumbbell or gym bench was found. A PowerBlock-like block is a few lines of `bpy`, so model it.
- **Finished media:** The only large free set (free-exercise-db) is 2 photographs per exercise of a real person, with unverified image provenance. Use it, if at all, as a private pose reference. wger, Everkinetic and Wikimedia are ShareAlike or mixed and are out.
- **Out for this app:** Bandai Namco (non-commercial), AMASS (non-commercial), Rokoko (no exercises, ML ban), wger and Everkinetic (CC BY-SA). Gymvisual stays out, as ticket 28 already decided.

## Date, versions, and method

Checked **2026-10-09**. Repo commit and the catalogue are as in `docs/research/exercise-animations.md` (66 exercises: 50 dumbbell, 11 bodyweight, 5 pull-up bar; `python3` count over `App/Resources/starter-exercises.json`).

Versions: MPFB **v2.0.17** (released 2026-07-22; needs Blender 4.2 or newer [M3]); free-exercise-db commit `f00c92c7dcf1216a928a52c3706c7ce8e2f71ed5` (2026-09-27); Blender Human Base Meshes **v1.4.1**; Quaternius Asset License **v1.0, last updated 2026-08-28** [Q1]; Mixamo Additional Terms **effective 2021-06-23** (old, but still the current version I could find) [X2]; CMU pages undated.

Method: pages read with `ketch scrape` (JS pages with `--force-browser`), licence texts fetched from the owner's site or the repo at a tag, and repo and API metadata read through the GitHub, wger, Wikimedia Commons, Poly Haven and Sketchfab public APIs. The web-search tool errored, so no model-written summary is evidence. `Unknown` means I did not verify it. Coverage counts are my judgement from name matching, not tested. Work-saved figures are estimates, not measurements.

Scope note on AI: the question's "AI processing" means AI coding agents scripting Blender, inspecting renders and transcoding. A licence that bans training or improving AI models is a different clause from one that bans AI processing of the asset. I say which each source has.

## Licence summary (exact terms, per source)

| Source | Commercial / App Store bundling | Modification | AI use | Attribution | Raw-asset redistribution | Safe for Blocklog? |
|---|---|---|---|---|---|---|
| MPFB add-on and output (CC0 assets) [M1–M4] | Yes | Yes | No clause found | None | Allowed for CC0 assets; add-on code is GPLv3 | **Yes** |
| Quaternius packs (pack pages say CC0; QAL v1.0 text) [Q1–Q3] | Yes | Yes | No clause | None | **Not as a standalone asset**; fine inside a finished product | **Yes**, keep raw files out of any public repo |
| Kenney (CC0) [K1] | Yes | Yes | No clause | Not required | Yes (CC0) | Yes, but nothing relevant found |
| Poly Haven (CC0) [P1] | Yes | Yes | Explicitly welcomes AI use | None | Yes | Yes, but no gym or figure models |
| Blender Human Base Meshes (CC0) [B1] | Yes | Yes | No clause | None | Yes | Yes (unrigged) |
| Blender Studio film assets (CC-BY) [B1] | Yes | Yes | No clause | **Required** | Yes with credit | Yes with credit; not needed |
| CMU Graphics Lab mocap [C1, C2] | Yes in "commercially-sold products" | Yes | No clause | Requested (acknowledgement text) | **May not be resold directly, even converted** | **Yes** for our own app |
| Mixamo (Adobe) [X1, X2] | "Royalty free" for personal, commercial, non-profit projects | Unknown | **Restriction on AI/ML** (see below) | Unknown | Unknown | **Risky**, avoid |
| Bandai Namco motion datasets [N1] | **No** (CC BY-NC 4.0) | n/a | n/a | Yes | n/a | **No** |
| AMASS | **No** (non-commercial) per `docs/research/exercise-animations.md` [D4 there] | n/a | n/a | n/a | n/a | **No** |
| Rokoko free packs and terms [R1, R2] | Free-pack licence **unknown** | Unknown | **ML/AI ban in terms 5.4** | Unknown | Unknown | **No** (no exercises anyway) |
| wger images and videos (CC-BY-SA 3 or 4) [W1] | Yes with conditions | Yes under SA | No clause | Per-image author credit | ShareAlike | **No** |
| Everkinetic images (CC-BY-SA 3, via wger) [W1] | Yes with conditions | Yes under SA | No clause | Required | ShareAlike | **No** |
| free-exercise-db (Unlicense claim) [F1] | Repo says yes | Yes | No clause | None | Yes | **Reference only** (image provenance unverified) |
| Wikimedia Commons "Dumbbell exercises" [WC1] | Mixed licences per file | Mixed | n/a | Mixed | Mixed | No (sparse and mixed) |
| Sketchfab CC-BY models [S1] | Yes | Yes | Unknown (platform terms not read) | **Required** | Yes with credit | Possible for props, not needed |

CC0 text used for all CC0 rows: Poly Haven quotes the CC0 FAQ: "Anyone can then use the work in any way and for any purpose, including commercial purposes" [P1]. For CC-BY and CC-BY-SA the deeds say respectively: "You must give appropriate credit, provide a link to the license, and indicate if changes were made" [L1] and "If you remix, transform, or build upon the material, you must distribute your contributions under the same license as the original" [L2].

## Group 1: rigged figures and base meshes

### MPFB (MakeHuman for Blender): recommended

- **What it is:** A free Blender add-on that builds a human character with sliders or Python. MPFB 2.x needs Blender 4.2 or newer; latest release v2.0.17 on 2026-07-22. [M3, M5]
- **Rigs:** Its rig service supports the MPFB default rig (with or without toes), game-engine rigs, Rigify metarigs and generated Rigify rigs, and Mixamo, CMU MotionBuilder and OpenPose skeletons. Its docs describe enabling IK. [M6, M7] That fits ticket 28: IK for foot and hand contacts, plus a CMU skeleton that can take CMU mocap.
- **Licence, exact text:** The add-on source is GPLv3. The assets (base mesh and proxies, targets and modifiers, textures, clothes, rigs, poses and expressions) "have been released under CC0 1.0 Universal". On output: "no output from MPFB contains any trace of program logic… what you get is a combination of assets and your own creative input", and "the MakeHuman team makes no claim whatsoever over output such as: Exports to files (FBX, OBJ, DAE, MHX2...), Graphical data generated via scripting or plugins, Renderings, Screenshots, Saved model files." [M2] The FAQ answers "Can I use models made with MPFB in a closed-source game?" with "Yes. All core assets… are shared under CC0." [M4]
- **Commercial use, App Store, modification, attribution:** All allowed, no credit needed, for core assets. [M2, M4]
- **AI use:** Neither the licence nor the FAQ mentions AI. Unknown beyond that.
- **Raw-asset redistribution:** CC0 assets may be redistributed. The GPLv3 add-on is not bundled in the app.
- **Caveats (unsettled):**
  - The CC0 statement about output is "the opinion of the MakeHuman team" [M2], not a court ruling.
  - Third-party assets from the MakeHuman asset packs, such as clothes, can carry other licences; the FAQ says that is the user's obligation. [M4] Use only the bundled core assets and CC0 packs.
  - The old MakeHuman 1.x licence page says its data is AGPL unless the user opts into CC0 for exports under conditions in its section C [M8]. MPFB's own LICENSE is the current, simpler statement; follow MPFB's, and use MPFB, not MakeHuman 1.x.
  - The add-on is a manual download (extension zip). A headless install path was not verified: `unknown`.
- **Fit:** The look is a realistic human body. A calm, flat-shaded "mannequin" render is possible by script; not tested.

### Quaternius Universal Base Characters: fallback

- Six game-ready characters (superhero, regular and teen proportions, male and female), about 13k triangles, humanoid rig, compatible with the Universal Animation Library (UAL). Pack page lists models 26 and formats FBX, OBJ, Blend, glTF; page says "License CC0". The "Source" tier includes the rigged `.blend` files; whether the free tier includes a `.blend` is `unknown`. [Q4]
- **Licence discrepancy:** The pack pages still say CC0 [Q2, Q4], but `quaternius.com/license.html` now publishes the Quaternius Asset License v1.0, last updated 2026-08-28, which governs assets "released… under this License… regardless of the specific site or platform". [Q1] Under it: use, copy and modify for personal, educational or commercial purposes; incorporate into a Product; distribute and sell the Product; no fee, royalty or credit ("No attribution is required"); but you may not "extract, repackage, sublicense, sell, or otherwise redistribute the Assets… as a standalone asset, asset pack, stock file, template, or similar product, whether for free or for payment". Distributing "a completed Product that merely incorporates the Assets" is allowed. The licence applies to the version in effect when you obtained the asset. [Q1]
- **App Store:** Fine. We ship rendered video, not the model.
- **Raw files:** Do not commit Quaternius `.blend` or FBX files to a public repository (it could read as standalone redistribution). A private repo is `unknown` under the text; keep raw files outside git or in a private repo.
- **AI use:** The licence has no AI clause. [Q1]
- **Fit:** Stylised figure, smaller saving than MPFB if Rigify IK is wanted (its rig is a game rig, not Rigify; IK setup is ours).

### Blender Human Base Meshes v1.4.1

- 49 MB bundle, CC0, requires Blender 4.2 LTS or newer; 17 sculpt base meshes (unrigged) by Blender Studio and contributors. [B1, B2] No rig, so less saving than MPFB or Quaternius.

### Blender Studio / Sprite Fright characters

- The blender.org demo-file page lists film files as CC-BY (some CC-BY-SA) and the Ellie Pose Library v2.0.0 as CC-BY (24 MB). [B1] CC-BY needs credit. Cartoon proportions suit poorly; the Ellie rig adds facial and cartoon complexity we do not need. Not recommended.

### Mixamo characters

- Same Adobe terms as Mixamo animations (below). Not recommended.

### Sketchfab, Kenney, Poly Haven

- Sketchfab: CC-BY rigged humans exist but I did not audit any; downloads need an account and credit is required. Skip.
- Kenney: all game assets are CC0, attribution not required (credit suggested: "Kenney"; his logo is reserved). [K1] I did not find a gym or exercise-ready human there. `Unknown`.
- Poly Haven: all assets CC0; its text names "AI researchers" among welcome users. [P1] Its 521 models (API list) include no dumbbells, gym benches or humanoid figures; the closest are a painted wooden bench and a wooden bench-like furniture items. [P2]

## Group 2: animations and motion capture

| Source | Contains | Dumbbell work? | Licence verdict |
|---|---|---|---|
| CMU Graphics Lab | Squats, lunges, generic stretches, balance (listed below) [C3] | No | Usable (see terms) |
| Mixamo | Air Squat, Push Up, Plank, Crunch, Burpee, Bicep Curl Workout, jumping jacks, hanging, stretching [X3, secondary] | No (bicep curl is "Workout", no prop) | Risky (AI/ML clause) |
| Quaternius UAL / UAL2 | Locomotion, combat, parkour, farming, zombie, emotes [Q5, Q6] | No | Fine, but not exercise content |
| Rokoko free packs | Dance, walk and run, idle, martial arts, sports [R3] | No | No (ML ban, free-pack licence unknown) |
| Bandai Namco | Daily activity, fighting, dancing [N1] | No | CC BY-NC: no |
| AMASS | Large mocap archive | Unknown | Non-commercial: no |

### CMU Graphics Lab mocap: usable, small saving

- **Terms, exact:** The home page says "This dataset of motions is free for all uses." and "You may include this data in commercially-sold products, but you may not resell this data directly, even in converted form." The FAQ: "The motion capture data may be copied, modified, or redistributed without permission." The page requests (does not require) an acknowledgement: "The data used in this project was obtained from mocap.cs.cmu.edu." [C1, C2] No AI clause on either page.
- **Bundling and raw assets:** An app containing rendered video is a commercially-sold product. Redistributing the raw data as a pack is the forbidden "resale"; do not publish converted data as a standalone download.
- **Coverage (searches run 2026-10-09 on `mocap.cs.cmu.edu/search.php`):** subject 14 trials 06 and 14 "jumping jacks, jog, squats, side twists, stretches"; subject 144 "Lunges" trials 11, 12, 17, 18; subject 42 trial 01 "stretch - rotate head, shoulders, arms, legs"; subject 88 trial 02 includes "vertical pushups" among acrobatics. [C3] Nothing with dumbbells, a bench or a pull-up bar was found; searches "squat", "push" and "bend" returned no standalone rows (so squat data is only inside subject 14's mixed trials).
- **Catalogue coverage:** at most `Squat`, `Dumbbell Lunge`-like lunges (without weights), `Push-up` (poor) and generic warm-up stretches. Roughly **3–5 of 66 starter exercises** plus a few generic stretch poses for phase 6, as raw material. Held stretches in phase 6 (such as a hip-flexor hold) are not covered.
- **Cost of use:** ASF/AMC joint angles at 120 Hz need conversion and retargeting (MPFB can use a CMU rig, which helps [M6]), foot-skate cleanup and a seamless loop. For a squat that is probably no faster than hand-keyframing it. This is a judgement, not measured.

### Mixamo: avoid

- **Free terms (FAQ):** Free with an Adobe ID; "You can use both characters and animations royalty free for personal, commercial, and non-profit projects including… Create films. Create video games." Humanoid bipeds only. [X1]
- **Exact AI clause, Additional Terms effective 2021-06-23, section 1:** "You will not, and will not instruct or allow third parties to, use the Services or Software (or any content, data, output, or other information received or derived from the Services or Software) to directly or indirectly create, train, test, or otherwise improve any machine learning algorithms or artificial intelligence systems, including, but not limited to, any architectures, models, or weights." [X2]
- **Reading:** It bans training or improving AI, not scripting. An AI coding agent that opens a Mixamo FBX in Blender is not obviously inside it, but "test" and "indirectly… improve" are broad, the clause reaches downloaded content, and agent providers differ on whether transcripts improve their models. `Unknown` whether Adobe would object. Given ticket 28 already dropped Gymvisual over an AI clause, treat this one the same: avoid.
- **Other gaps:** The FAQ is silent on App Store bundling, raw-asset redistribution and modification terms; `unknown`. Download needs a browser and an Adobe login, so an agent cannot fetch it headlessly. A previous research note also found no supported CLI. [X1; prior report D1]
- **Coverage (secondary source, a third-party list of Mixamo animation names, not Adobe's):** Air Squat Workout, Basic Push Up, Plank Position, Crunch variants, Burpee Workout, Bicep Curl Workout, jumping jacks, free-hang poses, stretching clips. [X3] That could touch `Squat`, `Push-up`, `Plank`, `Crunch`, `Burpee`, `Dead Hang`, about **6–8 of 66**, all bodyweight, none with dumbbells.

### Quaternius Universal Animation Library (1 and 2)

- UAL 1 is "a kit of 120+ animations… all the locomotion movements in different directions, combat and gun, emotes and much more"; UAL 2 adds "more than 130 animations" for melee and armed combos, parkour, farming, zombie locomotion. [Q5, Q6, Q7] No exercise clips are described; `unknown` whether any exist inside. Licence as in the Quaternius section above. No saving for the catalogue.

### Bandai Namco, AMASS, Rokoko

- Bandai Namco datasets 1 and 2: both **CC BY-NC 4.0** (scripts MIT); content is daily activity, fighting, dancing and locomotion. Non-commercial: unusable. [N1]
- AMASS: restricted to non-commercial research, education and art; already ruled out in `docs/research/exercise-animations.md` section 3.
- Rokoko: free packs are dance, walk and run, idle, martial arts and sports. [R3] I found no licence text for those downloads (`unknown`). The Rokoko Services Terms 5.4 say "You may not use any assets obtained or provided under this agreement for the purpose of developing, training, or enhancing machine learning and/or AI models or algorithms, whether for commercial or non-commercial purposes, without the explicit written consent of the Company." [R2] No exercises, so skip.

## Group 3: props (dumbbells, benches, mats)

- **No verified CC0 dumbbell, bench or mat.** Poly Haven has none [P2]; Kenney: none found; Poly Pizza's "dumbbell" search page returned Unity Asset Store listings (paid), not CC0 models. [PP1]
- **Sketchfab:** the public search API (`downloadable=true`) returns many CC-BY dumbbells, weight benches and yoga mats, for example "Dumbbell Adjustable Fitness Prop" (13k faces), "Weight Bench" (5k faces) and "Yoga Mat" (2k faces). These require credit (CC-BY), a Sketchfab login to download, and a licence check per model. Raw geometry is likely heavier than needed. [S1]
- **Recommendation:** Build them. A PowerBlock-like dumbbell (two stacked rectangular blocks and a handle) is a handful of `bpy.ops.mesh.primitive_cube_add` calls, a bench is four boxes, a mat is one box. This is original work, owned outright, matches the "PowerBlock-like blocks" in ticket 28, and takes minutes, so no download is worth its licence overhead. Estimate, not measured.

## Group 4: finished exercise animations, illustrations and videos

### free-exercise-db (Unlicense claim): reference only

- **Licence, exact:** Repo `LICENSE.md` is the Unlicense: "This is free and unencumbered software released into the public domain. Anyone is free to copy, modify, publish, use, compile, sell, or distribute this software… for any purpose, commercial or non-commercial". README: "Open Public Domain Exercise Dataset in JSON format, 800+ exercises". GitHub API reports `unlicense`. [F1]
- **Gap:** The licence is the repo author's. I found **no statement** of who made the 1,749 image files or under what licence they were first published (README names only the wrkout/exercises.json project as source of the data; no `everkinetic` or credit text in any Markdown file). The wrkout project's own README points to a paid site "which can be used in commercial projects". [F2] So image provenance is `unknown` and a public-domain claim on photographs I cannot trace is a legal risk for an App Store app.
- **Content:** 876 records in `dist/exercises.json` (123 category `stretching`), two JPEG photographs each (about 64 KB each), of a real person in a gym. Viewed `exercises/Dumbbell_Bench_Press/0.jpg`. These are not animations, and not our visual style. [F1]
- **Catalogue coverage by name, my judgement:** 11 of our 66 names match exactly (e.g. Dumbbell Bench Press, Dumbbell Floor Press, One-Arm Dumbbell Row, Plank, Chin-up). About 20 more have a close equivalent (Dumbbell Flyes, Pushups, Pullups, Arnold Dumbbell Press, Hammer Curls, Dumbbell Lunges, Dumbbell Step Ups, Romanian Deadlift, Bench Dips, Crunches and others). So roughly **30 of 66**, with stills only. No match for Goblet Squat (only a kettlebell entry), Burpee, Wall Sit, Dead Hang, Diamond Push-up, Dumbbell Thruster, Snatch (dumbbell), Bulgarian Split Squat. [F1, computed with `python3` over `dist/exercises.json`] Overlap with phase 6 stretches is `unknown`.
- **Use:** A private pose reference an author consults, not bundled, so the provenance risk does not reach the app. Comparing our render to a photo is the form check the research doc wants.

### wger: out

- The wger API's `/exerciseimage/` returns 379 images; the licence ids seen are 1 (CC-BY-SA 3, 83 images by "Everkinetic") and 2 (CC-BY-SA 4, the rest, from dozens of individual uploaders); 42 flagged `is_ai_generated`. `/video/` lists 78 videos (one inspected: HEVC 1920×1080, 34 MB; licence id 2, CC-BY-SA 4). [W1] The wger code is AGPLv3. [W2]
- ShareAlike means any adapted version must be released under the same licence, and per-uploader credits are needed. App Store terms and SA do not mix cleanly, and I did not find a clear safe reading. **Not safe** for Blocklog. Coverage is also thin (379 images).

### Wikimedia Commons

- `Category:Dumbbell exercises` has 37 files: licences are CC BY 2.0 (12), CC BY-SA 4.0 (9), public domain (8), CC BY-SA 3.0 (6), CC BY-SA 2.0 (1), CC0 (1). Mostly photos and a few ShareAlike diagrams or clips. `Category:Stretching exercises` has 1 file. [WC1] Too sparse and mixed. Not recommended.

## Risky terms, plainly

- **Mixamo (Adobe):** AI/ML clause (section 1), browser-only, silent on redistribution. Not safe under this project's stance on AI clauses. [X2]
- **Quaternius QAL:** safe for the app; the rule is no standalone redistribution of the raw assets. Do not push raw Quaternius files to a public repo. [Q1]
- **CMU:** safe; no direct resale of converted data. [C1]
- **MPFB:** safe if only core CC0 assets are used; third-party clothing and add-on packs must be checked one by one. [M2, M4]
- **ShareAlike (wger, Everkinetic, most Commons files):** not safe. [L2, W1, WC1]
- **Non-commercial (Bandai Namco, AMASS):** not usable. [N1]
- **Rokoko:** ML ban, no relevant clips. [R2]
- **free-exercise-db images:** provenance unverified, so do not bundle. [F1]

## Ranked recommendation

| Rank | Adopt | Catalogue coverage | Work saved vs scratch (estimate) |
|---|---|---|---|
| 1 | **MPFB** figure, rig and posing helpers; keep its CC0 core assets only | Figure for all 66 exercises and the phase 6 stretches | The largest single item: no character modelling, topology, weighting or rig building; Rigify IK rig is generated. Several days of authoring become a script, but the poses and loops remain ours. |
| 2 | **Quaternius Universal Base Characters** as backup figure | Same | Same savings if MPFB's look or headless install disappoints; no Rigify, so less IK help. |
| 3 | **free-exercise-db** photos, private reference only | About 30 of 66 by name, stills | Saves hunting references for those; adds nothing to the bundle. |
| 4 | **CMU mocap** to seed squat, lunge and a generic stretch | 3–5 of 66, plus a few stretches | Small; retargeting and cleanup may cost as much as keyframing. Optional. |
| — | Props | 0 from free sources | Build in Blender; cheaper than vetting a download. |
| — | Mixamo | 6–8 of 66, bodyweight only | Not recommended for the AI/ML clause and browser-only access. |
| — | wger, Everkinetic, Commons, Bandai Namco, AMASS, Rokoko | none usable | Do not use. |

**Bottom line for ticket 28:** The free landscape removes the cost of the human figure and its rig, not the cost of the animations. Plan on keyframing about 50 dumbbell exercises ourselves and only optionally seeding 3–5 from CMU. I found no free finished animation set suitable for bundling.

## Unknowns

- Whether MPFB can be installed and driven headless in Blender 4.5 on this Mac: not tested.
- Whether Quaternius's free tier includes the rigged `.blend` (only the Source tier is documented to) and whether a private git repo counts as "standalone redistribution": not settled by the licence text.
- Whether any CC0 dumbbell or bench exists on Poly Pizza, Kenney or OpenGameArt: not found, not exhaustively searched.
- Mixamo's exact exercise list: only a third-party list was read; Adobe's terms on redistribution and bundling: not found.
- Free-exercise-db's image origin and licence; its overlap with phase 6 stretches.
- Rokoko free-pack licence text.
- Sketchfab's platform terms on AI use.

## Sources

- [M1] MPFB repo licence index, `https://raw.githubusercontent.com/makehumancommunity/mpfb2/v2.0.17/LICENSE.md` (tag v2.0.17): sections A–D.
- [M2] Same file, sections C and D (assets CC0; output statement).
- [M3] `https://github.com/makehumancommunity/mpfb2/blob/master/README.md`: "MPFB 2.x requires a Blender version of at least 4.2".
- [M4] `https://static.makehumancommunity.org/mpfb/faq/use_in_closed_source.html`.
- [M5] `https://api.github.com/repos/makehumancommunity/mpfb2/releases/latest` → `v2.0.17`, 2026-07-22.
- [M6] `https://github.com/makehumancommunity/mpfb2/blob/master/docs/services/rigservice.md` (search snippet, rig types listed; page not read in full).
- [M7] `https://static.makehumancommunity.org/mpfb/docs/characters/rig.html` ("Choosing a rig type", "Enabling IK"; headings only, from search result).
- [M8] `http://www.makehumancommunity.org/content/license.html` (MakeHuman 1.x licence, AGPL with CC0 option for exports).
- [Q1] `https://quaternius.com/license.html`, Quaternius Asset License v1.0, last updated 8/28/2026.
- [Q2] `https://quaternius.com/packs/universalanimationlibrary.html` ("License CC0").
- [Q3] `https://quaternius.com/faq.html` returned only its title (JS content not rendered): no FAQ text used.
- [Q4] `https://quaternius.com/packs/universalbasecharacters.html` (August 2025, "License CC0").
- [Q5] UAL page above ("120+ animations… locomotion… combat and gun, emotes").
- [Q6] `https://quaternius.com/packs/universalanimationlibrary2.html` ("License CC0").
- [Q7] Search snippet at `https://x.com/quaternius` ("more than 130 animations", secondary).
- [K1] `https://kenney.nl/support`.
- [P1] `https://polyhaven.com/license`.
- [P2] `https://api.polyhaven.com/assets?t=models` (521 models; keyword filter for dumbbell, gym, bench, mat, mannequin, human returned none relevant).
- [PP1] `https://poly.pizza/search/dumbbell` (results are Unity Asset Store listings).
- [B1] `https://www.blender.org/download/demo-files/` (Human Base Meshes v1.4.1, 49 MB, CC0; Ellie Pose Library v2.0.0, CC-BY).
- [B2] `https://studio.blender.org/training/stylized-character-workflow/base-meshes` (search snippet, "License CC-0").
- [C1] `https://mocap.cs.cmu.edu/` home page terms.
- [C2] `https://mocap.cs.cmu.edu/faqs.php`.
- [C3] `https://mocap.cs.cmu.edu/search.php?subjectnumber=%&motion=<term>` for `stretch`, `lunge`, `pushup`, `squat`, `push`, `bend` (2026-10-09).
- [X1] `https://helpx.adobe.com/creative-cloud/faq/mixamo-faq.html`.
- [X2] `https://wwwimages2.adobe.com/content/dam/cc/en/legal/servicetou/Mixamo-Addl-Terms-en_US-20210623.pdf`.
- [X3] `https://www.cnblogs.com/jingzaixin/p/18262137` (secondary: a blog's list of Mixamo animation names).
- [N1] `https://raw.githubusercontent.com/BandaiNamcoResearchInc/Bandai-Namco-Research-Motiondataset/master/README.md`, "License" section.
- [R2] `https://www.rokoko.com/services-terms-of-use`, clause 5.4.
- [R3] `https://www.rokoko.com/resources/rokoko-mocap-12-free-sports-animations` and sibling free-resource pages (titles only; no licence text).
- [F1] `https://github.com/yuhonas/free-exercise-db` at `f00c92c7dcf1216a928a52c3706c7ce8e2f71ed5`: `LICENSE.md`, `README.md`, `dist/exercises.json`; GitHub API licence `unlicense`.
- [F2] `https://github.com/wrkout/exercises.json` README ("Commerical Projects?" section).
- [W1] `https://wger.de/api/v2/exerciseimage/?limit=400`, `/api/v2/license/`, `/api/v2/video/` (2026-10-09).
- [W2] `https://github.com/wger-project/wger` README (AGPL-3.0 or later).
- [WC1] `https://commons.wikimedia.org/w/api.php` (`Category:Dumbbell exercises` metadata, `Category:Stretching exercises`).
- [S1] `https://api.sketchfab.com/v3/search?type=models&q=dumbbell|weight bench|yoga mat&downloadable=true` (licence label "CC Attribution").
- [L1] `https://creativecommons.org/licenses/by/4.0/`.
- [L2] `https://creativecommons.org/licenses/by-sa/4.0/`.
- Blender output ownership: `https://www.blender.org/about/license/` ("What you create with Blender is your sole property").
- Local: `docs/research/exercise-animations.md`; `App/Resources/starter-exercises.json`; `.scratch/blocklog/spec.md` (phase 6 stretches, user stories 79–91).
