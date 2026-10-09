# Starter dumbbell routines

## Question and short answer

Which established, evidence-backed dumbbell routine templates should Blocklog ship, using only its starter exercise names, double progression, and sessions of about 45–60 minutes; and which classic standalone workouts can be offered as one-offs?

**Ship six session templates: Full Body, Upper Body, Lower Body, Push, Pull, and Legs.** They form three alternative programmes: repeat Full Body three nonconsecutive days per week; alternate Upper Body/Lower Body four days per week; or repeat Push/Pull/Legs six days per week. Recommend Full Body as the default, Upper/Lower for people who prefer four days, and Push/Pull/Legs only for experienced users who actually want six days. These are conservative **Blocklog adaptations of established programme structures**, not six independently trial-validated programmes or verbatim copies of a published plan. ACSM supports consistent, high-effort training of all major muscle groups at least twice weekly, and published dumbbell programmes demonstrate all three structures. [A][F][U][P]

**Ship only Golden Six — Dumbbell Adaptation as a trial one-off.** Retain Cindy and Humane Burpee below as future candidates for a separate **new workout types** phase supporting AMRAP and descending ladders; they are deliberately excluded from the final JSON. Golden Six supplies a classic full-body strength session, while the other two require workout structures the present schema cannot faithfully express. [user decision, 2026-10-09; G][C][H]

Six is the number of bundleable **sessions**, not six complete weekly programmes; the JSON schema represents sessions rather than a calendar. Upper and Lower belong together, as do Push, Pull and Legs. Do not present Push alone as a complete programme. [L2; product recommendation]

## Date, versions, and evidence boundaries

- Researched **2026-10-09** against repository commit `c653f1d9852834788ed3b42a0e5109795539172e`.
- Exercise catalogue: `App/Resources/starter-exercises.json`, 66 entries at that commit. Exercise spelling and kind were checked against the actual JSON, not inferred from a programme's exercise labels. [L1]
- Current guidance checked: ACSM's **April 2026** position stand, published online March 5, 2026; its literature search ends October 2024. This source is older than one month, but is the current official position stand checked here. [A]
- Additional literature: Schoenfeld and colleagues' **2017** volume and loading meta-analyses and **2019** frequency meta-analysis; Pelland and colleagues' paper published online **December 2025**. These are older sources. Author-written abstracts were retrieved from Europe PMC's bibliographic API; the full papers were not examined except the ACSM stand. [V][R][Q][D]
- Programme examples: live Muscle & Strength full-body, upper/lower, and push/pull/legs pages accessed October 9, 2026. Their original publication dates are **unknown** from the scraped programme text. These are first-party sources for what their programmes prescribe, **not scientific evidence that those exact workouts are superior**. [F][U][P]
- Local research notes and git history were checked first. `git log --all --oneline --grep='starter\|template'` returned `a33eddb Reject a backup with no exercises` and `f29dd51 Tracer: log a freeform dumbbell workout`; neither provides a template prescription. No previously researched starter programme was identified in the checked `docs/research/` files. This is a bounded search, not proof that none exists elsewhere. [local command, 2026-10-09]

## Evidence translated into defaults

| Decision | Evidence and limitation |
|---|---|
| Use three familiar programme structures, not an exotic branded method. | Muscle & Strength publishes a three-day dumbbell full-body programme, four-day dumbbell upper/lower programme, and six-day dumbbell push/pull/legs programme. Their advertised session lengths are 45, 45–60, and 45–70 minutes respectively. Their exercises and volumes are adapted below, rather than copied. [F][U][P] |
| Most movements get 2–3 working sets; the upper session's principal press gets 4. | ACSM finds multiple sets beneficial, advises at least two sets per exercise, and distinguishes meaningful gains from maximising gains. Its hypertrophy optimisation recommendation is higher weekly volume, approximately 10 or more sets per muscle. This is not a minimum below which training is ineffective. The 2017 volume meta-analysis finds a graded relationship; the newer dose-response analysis finds diminishing returns. [A][V][D] |
| Use 8–12 for most compound lifts, 10–15 or 12–20 for accessories, and 15–25 for small shoulder isolation movements. | The older ACSM stand gives 8–12 RM as a novice starting range. The 2017 load meta-analysis finds similar hypertrophy across loading ranges, but its included protocols trained to failure; do not claim it directly proves these non-failure prescriptions. Current ACSM does not require momentary failure. The exact higher isolation ranges are a **practical design choice** for coarse dumbbell increments, not a experimentally established best range. [B][R][A] |
| Prioritise the main squat, press, pull, and hinge before small-muscle accessories. | ACSM finds strength gains are greatest for exercises performed earlier in a session; the older stand explicitly sequences large/multijoint exercises first. Order does not establish a hypertrophy advantage for every exercise. [A][B] |
| Every bundled set is `normal`; do not prescribe drop or failure sets by default. | ACSM finds no consistent outcome advantage for training to momentary failure or elaborate set structures. Its discussion proposes roughly 2–3 repetitions in reserve while acknowledging that exact optimal reserve targets remain uncertain. [A] |
| Let frequency reflect adherence, not a claim that six days is better. | The 2019 frequency meta-analysis finds no meaningful hypertrophy difference when volume is equated. The 2025 dose-response analysis also permits negligible independent frequency effects on hypertrophy, while finding a positive, diminishing-return relationship for strength. [Q][D] |

### Operating instructions for the six programme sessions

These instructions accompany the templates; the supplied JSON has no fields for schedule, rest, technique, or effort. [requested schema; L2]

- **Choose one programme, not all six sessions in the same week.** Full Body: Monday/Wednesday/Friday. Upper/Lower: Upper Monday, Lower Tuesday, Upper Thursday, Lower Friday. Push/Pull/Legs: Push Monday, Pull Tuesday, Legs Wednesday, repeat Thursday–Saturday, rest Sunday. These are practical schedules adapted from the published structures; no claim of unique optimality is intended. [F][U][P; adaptation]
- **Warm up before working sets.** Allow approximately 5–8 minutes for easy movement and progressively heavier, non-fatiguing preparation sets on the first major lifts; add `warmUp` sets as needed. The exact preparation count depends on the person and working load, so it is not fixed in the JSON. This is a coaching recommendation, not a tested universal dose. Warm-ups are not the listed working-set counts. [B; adaptation]
- **Rest about 2 minutes after compound working sets and 60–90 seconds after accessories or core work; extend rest if technique or repetitions deteriorate.** These are practical defaults, not an evidence-mandated optimum. They deliberately replace the published programmes' shorter 30–60/45–60-second prescriptions. ACSM 2009 used 1–2 minutes for hypertrophy; ACSM 2026 leaves the hypertrophy effect of rest intervals unresolved. [B][A][U][P; adaptation]
- **Select a weight that permits the lower bound with controlled technique and about 2–3 good repetitions still possible.** Work upward within the range, then use the app's next-setting suggestion when every working set reaches the upper bound. Do not convert this into mandatory failure training. [A; L3]
- **Treat a weight increase as a suggestion, not a requirement to lift a weight you cannot control.** A 5 lb jump from 10 lb is 50%; 2.5 lb from 10 lb is 25%. Both exceed the older ACSM 2–10% progression guideline. Wider ranges provide more room to build repetitions, but **do not guarantee** that the next PowerBlock setting is manageable. If the new load puts sets below the lower bound or compromises technique, return to the previous setting and reassess the range or exercise. This is an arithmetic observation and practical recommendation, not a validated workaround for every jump. [B; arithmetic; L3]
- **For unilateral work, repetitions are per side; do both sides before treating the prescribed set as complete.** Use the same load and let the weaker side govern progression. For One-Arm Dumbbell Row, one listed set includes both arms; for Bulgarian split squats, both legs. These are template conventions; the JSON cannot store per-side instructions. [requested schema; coaching recommendation]
- **For Plank, 45 seconds is a starting target, not a timed progression algorithm.** Shorten it if alignment cannot be maintained. The app does not auto-progress duration exercises. For unweighted Pull-up, hitting the range generates an add-weight suggestion, not an automatic jump. The safe method of adding weight is outside this template. [L3]

### Session-length estimate

The sessions contain 15–18 working sets and 5–7 exercises. Budget roughly 10–18 minutes of active sets (longer for unilateral movements), 18–26 minutes of recovery, and 10–15 minutes for warm-up, weight changes, and transitions: approximately **40–60 minutes**, aiming at the requested 45–60-minute slot. This is planning arithmetic, **not a measured completion time**; unilateral lower-body work, pull-up recovery, or equipment setup can push a session over an hour. Do not shorten needed recovery just to match a duration label. [counts derived from JSON; coaching estimate]

## Recommended sessions

All counts below are working sets; all set types are `normal`. The table order is the JSON exercise order. Every numeric prescription is this report's adaptation informed by the cited programme and scientific guidance, not a number directly validated for Blocklog users. [A][B][F][U][P]

### 1. Full Body — the default three-day programme

**Rationale:** one repeatable session covers squat, hinge, horizontal push/pull, overhead press, calves, and trunk without requiring a pull-up bar. Repeat three nonconsecutive days weekly. Based on the movement coverage and 3-set compounds/2-set accessories of the published three-day full-body plan; replace its stiff-leg deadlift with Romanian deadlift, its squat with goblet squat, and its arm isolation with overhead press, calf work and plank. Unlike the source's three different workouts, this intentionally repeats one session. [F; adaptation]

| Order | Exact exercise name | Sets | Repetitions / duration |
|---|---|---|---|
| 1 | Dumbbell Goblet Squat | 3 | 8–12 |
| 2 | Dumbbell Bench Press | 3 | 8–12 |
| 3 | One-Arm Dumbbell Row | 3 | 8–12 per side |
| 4 | Dumbbell Romanian Deadlift | 3 | 8–12 |
| 5 | Standing Dumbbell Shoulder Press | 2 | 8–12 |
| 6 | Dumbbell Calf Raise | 2 | 12–20 |
| 7 | Plank | 2 | 45 seconds |

**Volume:** 18 sets/session, 54/week; 9 primary sets/week each for squat, hinge, horizontal pressing and rowing, 6 each for overhead pressing and calves. Arms receive indirect work but no dedicated isolation. This is a general-purpose starter, not a maximal-volume bodybuilding routine. [JSON arithmetic; A][D]

### 2. Upper Body — pair with Lower Body, four days weekly

**Rationale:** horizontal and vertical pressing/pulling plus small doses of shoulders and arms give balanced upper-body coverage in a repeatable upper/lower split. Adapt the published upper days by retaining bench press, supported rows, shoulder press, curl and triceps work, replacing pullover/shrug with Pull-up, and limiting accessory volume. Bench press gets four sets to avoid an especially low chest dose at twice weekly. [U; adaptation]

| Order | Exact exercise name | Sets | Repetitions |
|---|---|---|---|
| 1 | Dumbbell Bench Press | 4 | 8–12 |
| 2 | Chest-Supported Dumbbell Row | 3 | 8–12 |
| 3 | Seated Dumbbell Shoulder Press | 2 | 8–12 |
| 4 | Pull-up | 2 | 5–10 |
| 5 | Dumbbell Lateral Raise | 2 | 15–25 |
| 6 | Dumbbell Curl | 2 | 10–15 |
| 7 | Overhead Dumbbell Triceps Extension | 2 | 12–20 |

**Volume:** 17 sets/session, 34 upper-body sets/week; 8 primary chest sets and 10 combined row/pull-up sets weekly, with 4 direct sets each for curls and triceps plus indirect compound work. Do not count every press as a full additional triceps set; direct and indirect exposure differ. [JSON arithmetic; D]

### 3. Lower Body — pair with Upper Body, four days weekly

**Rationale:** squat, hinge, unilateral leg work, hip extension, calf work, and trunk training preserve the established upper/lower pattern without the source programme's unavailable dumbbell hamstring curl. Romanian deadlift replaces stiff-leg deadlift; Bulgarian split squat and glute bridge replace the extra squat/hamstring-curl slots. [U; adaptation]

| Order | Exact exercise name | Sets | Repetitions / duration |
|---|---|---|---|
| 1 | Dumbbell Goblet Squat | 3 | 8–12 |
| 2 | Dumbbell Romanian Deadlift | 3 | 8–12 |
| 3 | Dumbbell Bulgarian Split Squat | 3 | 8–12 per side |
| 4 | Dumbbell Glute Bridge | 2 | 10–15 |
| 5 | Dumbbell Calf Raise | 3 | 12–20 |
| 6 | Plank | 2 | 45 seconds |

**Volume:** 16 sets/session, 32 lower-body sets/week; 12 squat/split-squat sets for quads, 6 primary hinge sets for hamstrings, 6 calf sets and 4 trunk sets weekly. Glute exposure overlaps squats, split squats, hinges and bridges. There is **no knee-flexion hamstring exercise** here: none of the catalogue's 66 names supplies one, so do not silently invent a dumbbell leg curl. This is a catalogue-limited starting plan, not a claim of complete hamstring-function coverage. [L1; JSON arithmetic]

### 4. Push — part of six-day Push/Pull/Legs

**Rationale:** an established chest/shoulder/triceps session, trimmed from the published high-volume PPL plan to fit a home session. Retain flat/incline pressing, seated shoulder press, lateral raise and triceps extension; omit redundant decline/floor/Arnold pressing. [P; adaptation]

| Order | Exact exercise name | Sets | Repetitions |
|---|---|---|---|
| 1 | Dumbbell Bench Press | 3 | 8–12 |
| 2 | Incline Dumbbell Bench Press | 3 | 8–12 |
| 3 | Seated Dumbbell Shoulder Press | 3 | 8–12 |
| 4 | Dumbbell Lateral Raise | 3 | 15–25 |
| 5 | Overhead Dumbbell Triceps Extension | 3 | 12–20 |

**Volume:** 15 sets/session; repeated twice, 12 primary chest sets, 6 overhead press sets, 6 lateral raise sets, and 6 direct triceps sets/week, plus indirect pressing exposure. [JSON arithmetic; D]

### 5. Pull — part of six-day Push/Pull/Legs

**Rationale:** vertical and horizontal pulling, rear shoulders, traps, and elbow flexors avoid a programme made entirely of row variations. Retain supported row, rear delt fly and curls from the published PPL programme; add Pull-up and shrug, replace its unavailable Zottman curl with Hammer Curl, and reduce total sets. This template requires the assumed pull-up bar. [P; adaptation; L1]

| Order | Exact exercise name | Sets | Repetitions |
|---|---|---|---|
| 1 | Pull-up | 3 | 5–10 |
| 2 | Chest-Supported Dumbbell Row | 3 | 8–12 |
| 3 | Dumbbell Rear Delt Fly | 3 | 15–25 |
| 4 | Dumbbell Shrug | 2 | 10–15 |
| 5 | Dumbbell Curl | 2 | 10–15 |
| 6 | Hammer Curl | 2 | 10–15 |

**Volume:** 15 sets/session; repeated twice, 12 combined pull-up/row sets, 6 rear delt sets, 4 shrug sets, and 8 direct elbow-flexor sets/week. This counts movement exposures, not a guarantee of equal stimulus to every back muscle. [JSON arithmetic; D]

### 6. Legs — part of six-day Push/Pull/Legs

**Rationale:** the published PPL lower-body structure, with unilateral squatting to keep useful leg loading within a home dumbbell ceiling and core added to its otherwise core-free plan. Keep goblet squat, hip thrust and calf raise; use Romanian deadlift and Bulgarian split squat rather than duplicate bilateral squat/deadlift variants. [P; adaptation]

| Order | Exact exercise name | Sets | Repetitions |
|---|---|---|---|
| 1 | Dumbbell Goblet Squat | 3 | 8–12 |
| 2 | Dumbbell Romanian Deadlift | 3 | 8–12 |
| 3 | Dumbbell Bulgarian Split Squat | 2 | 8–12 per side |
| 4 | Dumbbell Hip Thrust | 2 | 10–15 |
| 5 | Dumbbell Calf Raise | 3 | 12–20 |
| 6 | Hanging Knee Raise | 2 | 8–15 |

**Volume:** 15 sets/session; repeated twice, 10 squat/split-squat sets, 6 primary hinge sets, 6 calf sets and 4 trunk sets/week. As with Lower Body, hamstring work is hip-extension dominant; do not promise maximal hypertrophy for every muscle. At six days, the full PPL programme totals 90 working sets/week, so it is not the beginner default. [JSON arithmetic; A][P]

## One-off workouts

A one-off here means **usable on its own without completing the other days of a split**, not a claim that the original author prescribed doing it only once. Golden Six historically was a repeatable three-day full-body programme. Cindy and Humane Burpee are genuinely named standalone sessions. None is evidence that one isolated workout produces the adaptations measured in multiweek resistance-training studies. [G][C][H][A]

**Decision:** trial Golden Six as the only shipped one-off. Cindy and Humane Burpee remain research candidates for a separate new workout types phase and are not bundled. The flat exercise/set schema does not capture rounds, a workout clock, or per-set repetition ladders; it cannot reproduce an official Cindy score or the original Humane Burpee. Preserve those originals when AMRAP/ladders are supported rather than shipping the fixed-set sketches below now. [user decision, 2026-10-09; requested schema]

### Shipped trial one-off: Golden Six — Dumbbell Adaptation

**Rationale:** a recognisable golden-era full-body strength session, with catalogue-safe substitutions and moderate working volume. Approximately 45–60 minutes under the programme-session rest guidance; actual completion time remains unknown. [G; adaptation; planning estimate]

**Publication provenance:** Ironman Magazine's May 1, 2001 first-party article, *Train To Gain: Star Talk*, quotes Arnold naming the six movements, recommending three to four sets each, and three alternate-day sessions per week for at least three months. It attributes the text to **Arnold Schwarzenegger, IRONMAN's Ultimate Bodybuilding Encyclopedia**. This is not evidence that it appears in Arnold's *New Encyclopedia of Modern Bodybuilding*; edition/page and first-ever publication remain **unknown**. [G]

**Original sets × reps:** the detailed historical prescription below is preserved in a 2011 transcription of Arnold's section of *Three Golden Era Greats on Gaining Mass*, and a 2024 transcription identifying Gene Mozee's *Gain 50 Pounds of Muscle*, *IronMan*, October 1992. These are **secondary-hosted transcriptions, not independently verified original page scans**. The publisher's shorter 2001 excerpt verifies the programme and book attribution but does not give the exact reps. Accordingly, the exact per-exercise historical numbers carry a lower confidence level than the first-party attribution. [G][GS]

| Original prescription (transcribed) | Blocklog exercise | Bundled working prescription | Substitution/change |
|---|---|---|---|
| Barbell squat, 4 × 10 | Dumbbell Goblet Squat | 3 × 8–12 | Dumbbell squat variant; one fewer set; range replaces fixed 10. |
| Wide-grip barbell bench press, 3 × 10 | Dumbbell Bench Press | 3 × 8–12 | Dumbbells replace barbell; no claimed equivalence to its specific grip width. |
| Chins (or lat pulldowns), 3 × maximum reps | Chin-up | 3 × 5–10 | Catalogue chin-up; bounded range replaces maximum reps; original wide-grip description is not preserved. |
| Overhead press, often seated behind neck, 4 × 10 | Seated Dumbbell Shoulder Press | 3 × 8–12 | Normal dumbbell press replaces behind-neck barbell version; one fewer set. |
| Barbell curl, 3 × 10 | Dumbbell Curl | 2 × 10–15 | Dumbbells; one fewer set; wider range. |
| Bent-knee sit-up, 3–4 × 20 or as many as possible | Crunch | 2 × 12–20 | Crunch is a different trunk-flexion movement; lower volume, no maximum-rep demand. |

**Order and count:** table order; 16 working sets; every set `normal`. Use the double-progression instructions above for weighted movements, but do not force added weight on chin-ups or crunches. This session does not add a hinge or row because doing so would cease to be a six-movement adaptation; it is not our most balanced default ongoing programme. The full-body starter above remains the recommendation for regular training. [JSON arithmetic; G][A; adaptation]

### Future candidate: Cindy (AMRAP workout type)

**Rationale:** an iconic minimal-equipment bodyweight session using three catalogue movements with no exercise substitution. [C][L1]

**Original:** CrossFit's official Cindy is **as many rounds and reps as possible in 20 minutes** of **5 pull-ups, 10 push-ups, 15 air squats**. CrossFit identifies its first posting as December 29, 2004; score is completed rounds/reps. Its beginner variant is a 12-minute AMRAP using ring rows and assisted push-ups, neither of which is a separate catalogue exercise. [C][L1]

**Unbundled adaptation sketch:** perform **five fixed rounds**, each in this order: Pull-up 5, Push-up 10, Squat 15. A fixed-set sketch would log each round as one `normal` set of each exercise with equal low/high rep bounds; this sketch is not included in the JSON. Complete all three movements in a round before starting the next round. Rest as needed to preserve controlled technique; this is not a race and not a mandatory 20-minute test. Prefer strict pull-ups for this home adaptation, rather than importing the official page's kipping warm-up. It is **not Rx Cindy**, and its fixed-round completion time is **unknown**, plausibly around 10–25 minutes plus preparation depending on capacity. [C; adaptation and estimate]

| Order within each round | Exact catalogue name | Logged sets | Repetitions per set |
|---|---|---|---|
| 1 | Pull-up | 5 normal | 5 |
| 2 | Push-up | 5 normal | 10 |
| 3 | Squat | 5 normal | 15 |

Air squat → `Squat` is a catalogue-name mapping; the other names already match. The movement selection is preserved, while the AMRAP clock and scoring are deliberately removed. Do **not** accept automatic add-weight suggestions merely because fixed targets were met: the purpose here is repeatable bodyweight rounds. If five pull-ups are not available, the previously listed row alternative is an explicitly modified version, not an official Cindy score. [C][L1][L3; recommendation]

### Future candidate: Humane Burpee (descending-ladder workout type)

**Rationale:** a well-known short push/squat/hinge sequence adapted away from the unavailable kettlebell swing. Dan John's author-written article credits its creator as **Dan Martin**; do not incorrectly credit John with invention. [H]

**Original:** in Dan John's October 28, 2015 *Men's Health* article, perform 15 kettlebell swings, 5 goblet squats, 5 push-ups; then 15/4/4; then 15/3/3; 15/2/2; 15/1/1. The five rounds total **75 swings, 15 squats and 15 push-ups**, with a goal of four minutes or less and rest only as needed. This is a descending ladder, not five equal working sets. [H]

**Unbundled adaptation sketch:** five fixed, unhurried rounds of **15 Dumbbell Romanian Deadlift, 5 Dumbbell Goblet Squat, 5 Push-up** in that order. This retains the broad hinge/squat/push sequence, **not** the ballistic swing or the ladder. A Romanian deadlift is not a swing and should not be rushed to imitate one. Fixed repetitions would replace the ladder because the requested schema provides one shared rep range per exercise, not a target for each planned set; this sketch is not included in the JSON. The adapted totals are 75 hinges, 25 squats and 25 push-ups; do not cite the original four-minute target or its conditioning effects as validated for this version. Allow approximately 15–30 minutes including setup and rest as a planning estimate; measured time is **unknown**. [H][L1; adaptation, arithmetic and estimate]

| Order within each round | Exact catalogue name | Logged sets | Repetitions per set |
|---|---|---|---|
| 1 | Dumbbell Romanian Deadlift | 5 normal | 15 |
| 2 | Dumbbell Goblet Squat | 5 normal | 5 |
| 3 | Push-up | 5 normal | 5 |

Kettlebell swing → Romanian deadlift is a substantial movement and intent change. Kettlebell goblet squat → dumbbell goblet squat changes equipment. Push-up is unchanged. Use an intentionally manageable hinge load and normal recovery; do not apply the strength templates' automatic weight-step rule just because these fixed counts were completed. This is the **lowest-fidelity** adaptation of the three, and is not bundled; a future ladder implementation should preserve the original structure instead. [H][L3; recommendation]

## Limits, substitutions, and unknowns

- **Equipment availability is unknown.** Bench and pull-up bar are inferred from catalogue entries, not confirmed owned. Upper and Pull use Pull-up; Legs uses Hanging Knee Raise. Supported rows and incline presses require an adjustable bench. If equipment is absent, offer an explicit catalogue-valid substitution rather than failing midway: Pull-up → Bent-Over Dumbbell Row (same sets, 8–12), Chest-Supported Dumbbell Row → One-Arm Dumbbell Row (same sets, 8–12 per side), Incline Dumbbell Bench Press → Dumbbell Floor Press (same prescription), Hanging Knee Raise → Crunch (same sets, 12–20), Dumbbell Bench Press → Dumbbell Floor Press, Seated Dumbbell Shoulder Press → Standing Dumbbell Shoulder Press. These are pragmatic alternatives, **not biomechanically identical replacements**. [L1; coaching recommendation]
- **Ability to perform five strict pull-ups is unknown.** The catalogue has no assisted pull-up. Beginners below the range should use the row alternative; do not label unrecorded assistance as a bundled exercise. [L1; coaching recommendation]
- **PowerBlock grip and placement comfort are unknown** for goblet squats, bridges, hip thrusts and overhead extensions. Do not require gripping removable plates/adders or securing a dumbbell between the feet. Check manufacturer-approved handling and individual setup before use. If a goblet hold is awkward, Dumbbell Front Squat is a catalogue-valid alternative (same sets/range); if loaded bridges/thrusts cannot be set up securely, use Glute Bridge (same sets, 12–20). These substitutions are coaching proposals, not verified handling instructions. [L1; unknown]
- **The optimal split for this specific user is unknown.** No cited trial evaluates this exact PowerBlock-limited six-template bundle. Health conditions, training history, pain, recovery and priorities require individualisation; the ACSM evidence applies to healthy adults. [A]
- **No exact isolation rep range is proven to solve 2.5–5 lb jumps.** These ranges are pragmatic, and the app currently proposes the next setting rather than confirming that the user can lift it. At the 90 lb ceiling it does not propose a heavier setting. [L3; unknown]
- **Volume is deliberately conservative**, especially direct hamstring, calf and arm volume in some plans. ACSM's approximately 10-set hypertrophy target informs optimisation, not a universal threshold; it would be misleading to call these maximum-growth plans for every muscle. Adjust volume after observing adherence and recovery rather than silently adding sets to the bundle. [A][V][D; recommendation]
- **Safety and discomfort were not hardware-tested.** No new exercise, package, model change, or code is proposed. These templates are starting points, not rehabilitation, sport-specific, or maximal-strength prescriptions. [research scope]

## Sources

Scientific sources below are primary author/organisation publications. Europe PMC is used only to retrieve the original author abstracts; it is not a substitute for full-paper review.

- **[A] Currier et al., ACSM Position Stand (2026).** *Resistance Training Prescription for Muscle Function, Hypertrophy, and Physical Performance in Healthy Adults: An Overview of Reviews.* *Medicine & Science in Sports & Exercise* 58(4):851–872. DOI: [10.1249/MSS.0000000000003897](https://doi.org/10.1249/MSS.0000000000003897). [Full text](https://pmc.ncbi.nlm.nih.gov/articles/PMC12965823/), especially abstract, Table 4, and Discussion (high effort, twice weekly, multiple sets, individualisation, RIR uncertainty). Official [ACSM explanation dated March 17, 2026](https://www.acsm.org/resistance-training-guidelines-update-2026/). Full text and explanation read using `ketch scrape` on 2026-10-09. **Older than one month.**
- **[B] ACSM Position Stand (2009).** *Progression models in resistance training for healthy adults.* DOI: [10.1249/MSS.0b013e3181915670](https://doi.org/10.1249/MSS.0b013e3181915670), [PMID 19204579](https://pubmed.ncbi.nlm.nih.gov/19204579/). Abstract retrieved through [Europe PMC API](https://www.ebi.ac.uk/europepmc/webservices/rest/search?query=EXT_ID:19204579%20AND%20SRC:MED&format=json&resultType=core): novice 8–12 RM, large/multijoint movements first, 2–10% load increases, hypertrophy rest 1–2 minutes. **Historical guidance superseded overall by [A]; used as a practical starting point, not the current blanket standard.**
- **[V] Schoenfeld, Ogborn & Krieger (2017; online July 2016).** *Dose-response relationship between weekly resistance training volume and increases in muscle mass: A systematic review and meta-analysis.* DOI: [10.1080/02640414.2016.1210197](https://doi.org/10.1080/02640414.2016.1210197), [PMID 27433992](https://pubmed.ncbi.nlm.nih.gov/27433992/). [Author abstract via Europe PMC API](https://www.ebi.ac.uk/europepmc/webservices/rest/search?query=EXT_ID:27433992%20AND%20SRC:MED&format=json&resultType=core). Fifteen studies; graded weekly-volume relationship; three-category comparison showed a trend, not a conclusive universal 10-set cutoff. **Older source; abstract only.**
- **[R] Schoenfeld, Grgic, Ogborn & Krieger (2017).** *Strength and Hypertrophy Adaptations Between Low- vs. High-Load Resistance Training: A Systematic Review and Meta-analysis.* DOI: [10.1519/JSC.0000000000002200](https://doi.org/10.1519/JSC.0000000000002200), [PMID 28834797](https://pubmed.ncbi.nlm.nih.gov/28834797/). [Author abstract via Europe PMC API](https://www.ebi.ac.uk/europepmc/webservices/rest/search?query=EXT_ID:28834797%20AND%20SRC:MED&format=json&resultType=core). Twenty-one studies; similar hypertrophy across loads, heavier loads better for 1RM strength; failure-training inclusion criterion. **Older source; abstract only.**
- **[Q] Schoenfeld, Grgic & Krieger (2019; online December 2018).** *How many times per week should a muscle be trained to maximize muscle hypertrophy?* DOI: [10.1080/02640414.2018.1555906](https://doi.org/10.1080/02640414.2018.1555906), [PMID 30558493](https://pubmed.ncbi.nlm.nih.gov/30558493/). [Author abstract via Europe PMC API](https://www.ebi.ac.uk/europepmc/webservices/rest/search?query=EXT_ID:30558493%20AND%20SRC:MED&format=json&resultType=core). Twenty-five studies; no significant or meaningful frequency effect with volume equated. **Older source; abstract only.**
- **[D] Pelland et al. (online December 4, 2025).** *The Resistance Training Dose Response: Meta-Regressions Exploring the Effects of Weekly Volume and Frequency on Muscle Hypertrophy and Strength Gains.* DOI: [10.1007/s40279-025-02344-w](https://doi.org/10.1007/s40279-025-02344-w), [PMID 41343037](https://pubmed.ncbi.nlm.nih.gov/41343037/). [Author abstract via Europe PMC API](https://www.ebi.ac.uk/europepmc/webservices/rest/search?query=EXT_ID:41343037%20AND%20SRC:MED&format=json&resultType=core). Sixty-seven studies; direct/indirect sets distinguished; fractional counting fit best; increasing volume with diminishing returns. **Older than one month; abstract only.**
- **[F] Muscle & Strength, [Dumbbell Only Workout: 3 Day Full Body Dumbbell Workout](https://www.muscleandstrength.com/workouts/3-day-full-body-dumbbell-workout).** Live programme text checked 2026-10-09. First-party programme prescription, not a scientific trial. Day 1 has four 3-set compounds and three 2-set accessories; source rotates three sessions. **Original publication date unknown.**
- **[U] Muscle & Strength, [4 Day Dumbbell Only Upper/Lower Workout Routine](https://www.muscleandstrength.com/workouts/dumbbell-only-upper-lower-workout-routine).** Live programme text checked 2026-10-09. First-party programme prescription, not a scientific trial. Four different sessions, 45–60-minute label, 48–72 hours between matching body-region workouts. **Original publication date unknown.**
- **[P] Muscle & Strength, [Dumbbell Only Workout: 6 Day Dumbbell Workout Split](https://www.muscleandstrength.com/workouts/6-day-dumbbell-only-workout).** Live programme text checked 2026-10-09. First-party intermediate PPL programme prescription, not a scientific trial. Twice-weekly muscle-group training, two variants per region, 45–70-minute label; reduced-volume adaptation here. **Original publication date unknown.**
- **[G] Ironman Magazine, [Train To Gain: Star Talk](https://www.ironmanmagazine.com/train-to-gain-star-talk/), May 1, 2001.** First-party publisher excerpt quoting Arnold and explicitly attributing the Golden Six text to *IRONMAN's Ultimate Bodybuilding Encyclopedia*. Read with `ketch scrape` on 2026-10-09. Verifies six names, 3–4 sets, and three-day schedule; exact per-exercise reps not given. **Historical source.**
- **[GS] Secondary transcriptions of Golden Six:** [*Three Ways to Gain — Arnold Schwarzenegger, Larry Scott, and Bill Pearl*](https://ditillo2.blogspot.com/2011/04/three-ways-to-gain-arnold.html), April 6, 2011; and C. S. Sloan's [*Classic Bodybuilding: How to Gain 50 pounds of Muscle!*](https://cssloanstrength.blogspot.com/2024/05/classic-bodybuilding-how-to-gain-50.html), May 17, 2024, identifying Gene Mozee's article in *IronMan*, October 1992. Read with `ketch scrape` on 2026-10-09. **Secondary-hosted quotations only; original issue/pages not verified.** These support the detailed historical set/rep table, not a claim of scientifically measured gains.
- **[C] CrossFit, [The Cindy Workout](https://www.crossfit.com/cindy).** Official benchmark owner, live page checked 2026-10-09 with `ketch scrape`; identifies first posting December 29, 2004. Specifies 20-minute AMRAP and 5/10/15 movement counts, scaling and scoring. **Historical workout; live explanatory page publication date unknown.**
- **[H] Dan John, [Try the 'Humane Burpee' for a Ridiculously Good Workout](https://www.menshealth.com/fitness/a19547957/humane-burpee/), October 28, 2015.** First-person coach-authored primary account at *Men's Health*, credits Dan Martin as creator; specifies five-round descending ladder and four-minute goal. Read with `ketch scrape` on 2026-10-09. **Historical source; promotional benefit claims not used as scientific evidence.**
- **[L1] Local catalogue:** `App/Resources/starter-exercises.json:1–398` at commit `c653f1d9852834788ed3b42a0e5109795539172e`; names and kinds read directly and validated by the command below.
- **[L2] Local routine semantics:** `CONTEXT.md:22–24` at that commit: a routine is one named session structure with ordered exercises, set types, rep ranges or duration, not a multiweek programme or scheduler.
- **[L3] Local progression:** `App/Logic/Progression.swift:26–54` at that commit: duration is excluded, every previous working set must reach the upper bound, unweighted bodyweight exercises only receive a suggestion, the next PowerBlock setting resets repetitions to the lower bound, and no next setting means no suggestion.

## Validation

Validated the final JSON block against the actual catalogue with Python's standard library; no code or other file was changed. Command (from repository root):

```bash
python3 - <<'PY'
import json, re
from pathlib import Path
catalog = json.loads(Path('App/Resources/starter-exercises.json').read_text())
kinds = {e['name']: e['kind'] for e in catalog}
text = Path('docs/research/starter-routines.md').read_text()
blocks = re.findall(r'```json\n(.*?)\n```', text, re.S)
assert len(blocks) == 1
routines = json.loads(blocks[0])
assert len(catalog) == 66 and len(kinds) == 66
assert 4 <= sum(r['kind'] == 'routine' for r in routines) <= 6
assert sum(r['kind'] == 'oneOff' for r in routines) == 1
assert next(r['name'] for r in routines if r['kind'] == 'oneOff') == 'Golden Six — Dumbbell Adaptation'
assert len({r['name'] for r in routines}) == len(routines)
entries = 0
for r in routines:
    assert set(r) == {'name', 'kind', 'exercises'}
    assert r['kind'] in {'routine', 'oneOff'}
    assert (5 <= len(r['exercises']) <= 7) if r['kind'] == 'routine' else (3 <= len(r['exercises']) <= 7)
    for e in r['exercises']:
        assert e['exercise'] in kinds, e['exercise']
        assert e['sets'] and all(s in {'normal','warmUp','drop','failure'} for s in e['sets'])
        kind = kinds[e['exercise']]
        if kind == 'duration':
            assert set(e) == {'exercise','sets','targetDurationSeconds'}
            assert type(e['targetDurationSeconds']) is int and e['targetDurationSeconds'] > 0
        else:
            assert kind in {'weightReps','bodyweightReps'}
            assert set(e) == {'exercise','sets','repRange'}
            assert len(e['repRange']) == 2
            lo, hi = e['repRange']
            assert type(lo) is int and type(hi) is int and 0 < lo <= hi
        entries += 1
print(f'PASS: {len(routines)} routines; {entries} exercise entries; all exact names and kind-specific targets valid against {len(catalog)} starter exercises.')
print('Working sets per routine:', ', '.join(r['name'] + '=' + str(sum(len(e['sets']) for e in r['exercises'])) for r in routines))
PY
```

Output:

```text
PASS: 7 routines; 43 exercise entries; all exact names and kind-specific targets valid against 66 starter exercises.
Working sets per routine: Full Body=18, Upper Body=17, Lower Body=16, Push=15, Pull=15, Legs=15, Golden Six — Dumbbell Adaptation=16
```

## Machine-ready bundle

Every entry includes the additionally requested `kind`: `routine` for the six programme sessions, or `oneOff` for the Golden Six trial one-off. Otherwise, the array contains only the requested fields. Schedule, equipment requirements, per-side conventions, warm-up guidance, and rationale must accompany it separately; they cannot be encoded in this schema. No starting weight is prescribed. [requested schema; L2]

```json
[
  {
    "name": "Full Body",
    "kind": "routine",
    "exercises": [
      {"exercise": "Dumbbell Goblet Squat", "sets": ["normal", "normal", "normal"], "repRange": [8, 12]},
      {"exercise": "Dumbbell Bench Press", "sets": ["normal", "normal", "normal"], "repRange": [8, 12]},
      {"exercise": "One-Arm Dumbbell Row", "sets": ["normal", "normal", "normal"], "repRange": [8, 12]},
      {"exercise": "Dumbbell Romanian Deadlift", "sets": ["normal", "normal", "normal"], "repRange": [8, 12]},
      {"exercise": "Standing Dumbbell Shoulder Press", "sets": ["normal", "normal"], "repRange": [8, 12]},
      {"exercise": "Dumbbell Calf Raise", "sets": ["normal", "normal"], "repRange": [12, 20]},
      {"exercise": "Plank", "sets": ["normal", "normal"], "targetDurationSeconds": 45}
    ]
  },
  {
    "name": "Upper Body",
    "kind": "routine",
    "exercises": [
      {"exercise": "Dumbbell Bench Press", "sets": ["normal", "normal", "normal", "normal"], "repRange": [8, 12]},
      {"exercise": "Chest-Supported Dumbbell Row", "sets": ["normal", "normal", "normal"], "repRange": [8, 12]},
      {"exercise": "Seated Dumbbell Shoulder Press", "sets": ["normal", "normal"], "repRange": [8, 12]},
      {"exercise": "Pull-up", "sets": ["normal", "normal"], "repRange": [5, 10]},
      {"exercise": "Dumbbell Lateral Raise", "sets": ["normal", "normal"], "repRange": [15, 25]},
      {"exercise": "Dumbbell Curl", "sets": ["normal", "normal"], "repRange": [10, 15]},
      {"exercise": "Overhead Dumbbell Triceps Extension", "sets": ["normal", "normal"], "repRange": [12, 20]}
    ]
  },
  {
    "name": "Lower Body",
    "kind": "routine",
    "exercises": [
      {"exercise": "Dumbbell Goblet Squat", "sets": ["normal", "normal", "normal"], "repRange": [8, 12]},
      {"exercise": "Dumbbell Romanian Deadlift", "sets": ["normal", "normal", "normal"], "repRange": [8, 12]},
      {"exercise": "Dumbbell Bulgarian Split Squat", "sets": ["normal", "normal", "normal"], "repRange": [8, 12]},
      {"exercise": "Dumbbell Glute Bridge", "sets": ["normal", "normal"], "repRange": [10, 15]},
      {"exercise": "Dumbbell Calf Raise", "sets": ["normal", "normal", "normal"], "repRange": [12, 20]},
      {"exercise": "Plank", "sets": ["normal", "normal"], "targetDurationSeconds": 45}
    ]
  },
  {
    "name": "Push",
    "kind": "routine",
    "exercises": [
      {"exercise": "Dumbbell Bench Press", "sets": ["normal", "normal", "normal"], "repRange": [8, 12]},
      {"exercise": "Incline Dumbbell Bench Press", "sets": ["normal", "normal", "normal"], "repRange": [8, 12]},
      {"exercise": "Seated Dumbbell Shoulder Press", "sets": ["normal", "normal", "normal"], "repRange": [8, 12]},
      {"exercise": "Dumbbell Lateral Raise", "sets": ["normal", "normal", "normal"], "repRange": [15, 25]},
      {"exercise": "Overhead Dumbbell Triceps Extension", "sets": ["normal", "normal", "normal"], "repRange": [12, 20]}
    ]
  },
  {
    "name": "Pull",
    "kind": "routine",
    "exercises": [
      {"exercise": "Pull-up", "sets": ["normal", "normal", "normal"], "repRange": [5, 10]},
      {"exercise": "Chest-Supported Dumbbell Row", "sets": ["normal", "normal", "normal"], "repRange": [8, 12]},
      {"exercise": "Dumbbell Rear Delt Fly", "sets": ["normal", "normal", "normal"], "repRange": [15, 25]},
      {"exercise": "Dumbbell Shrug", "sets": ["normal", "normal"], "repRange": [10, 15]},
      {"exercise": "Dumbbell Curl", "sets": ["normal", "normal"], "repRange": [10, 15]},
      {"exercise": "Hammer Curl", "sets": ["normal", "normal"], "repRange": [10, 15]}
    ]
  },
  {
    "name": "Legs",
    "kind": "routine",
    "exercises": [
      {"exercise": "Dumbbell Goblet Squat", "sets": ["normal", "normal", "normal"], "repRange": [8, 12]},
      {"exercise": "Dumbbell Romanian Deadlift", "sets": ["normal", "normal", "normal"], "repRange": [8, 12]},
      {"exercise": "Dumbbell Bulgarian Split Squat", "sets": ["normal", "normal"], "repRange": [8, 12]},
      {"exercise": "Dumbbell Hip Thrust", "sets": ["normal", "normal"], "repRange": [10, 15]},
      {"exercise": "Dumbbell Calf Raise", "sets": ["normal", "normal", "normal"], "repRange": [12, 20]},
      {"exercise": "Hanging Knee Raise", "sets": ["normal", "normal"], "repRange": [8, 15]}
    ]
  },
  {
    "name": "Golden Six — Dumbbell Adaptation",
    "kind": "oneOff",
    "exercises": [
      {"exercise": "Dumbbell Goblet Squat", "sets": ["normal", "normal", "normal"], "repRange": [8, 12]},
      {"exercise": "Dumbbell Bench Press", "sets": ["normal", "normal", "normal"], "repRange": [8, 12]},
      {"exercise": "Chin-up", "sets": ["normal", "normal", "normal"], "repRange": [5, 10]},
      {"exercise": "Seated Dumbbell Shoulder Press", "sets": ["normal", "normal", "normal"], "repRange": [8, 12]},
      {"exercise": "Dumbbell Curl", "sets": ["normal", "normal"], "repRange": [10, 15]},
      {"exercise": "Crunch", "sets": ["normal", "normal"], "repRange": [12, 20]}
    ]
  }
]
```
