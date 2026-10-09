# Guided Stretching Routines for Blocklog

## Question and Short Answer

What stretching dose and timing should a dumbbell-training app recommend, and which short, guided routines can it bundle?

Use 30-second static holds as an approachable default, with optional repeats, after lifting or in a separate warmed-up session; use continuous, controlled movements before lifting. Bundle **Full-Body Quick Stretch**, **Dynamic Lifting Warm-Up**, **Hips and Lower Back**, and **Upper Body Reset**. Two 30-second rounds reach ACSM's 60-second-per-exercise session target; three rounds are an optional flexibility-focused dose, not a proven requirement. Stretching improves range of motion, but the app should not promise soreness prevention, injury prevention, posture correction, or treatment of sciatica. [E1–E5]

The routine prescriptions and easier/harder variations below are editorial proposals informed by the cited techniques, not clinically validated packages. The JSON at the end supplies every requested field, including cues shorter than 120 characters.

## Date, Versions, and Research Boundaries

- Checked **2026-10-09** against repository commit `c653f1d9852834788ed3b42a0e5109795539172e`. Local search: `rg -n -i 'stretch|flexibility' docs .scratch/blocklog` and `git log -5 --oneline --all --grep='stretch'` returned no relevant local findings.
- Video checked: YouTube ID `eQHmKJh20_c`, English caption transcript through approximately 10:25, fetched successfully with `node /Users/gvanderclay/pi/skills/youtube-transcript/transcript.js eQHmKJh20_c`. Captions can misrecognize words; the video was not visually reviewed. Exact original publication date: **unknown**. [V]
- Evidence versions: ACSM's **2011** position stand; Behm et al. **2016** systematic review; Afonso et al. **2021** recovery meta-analysis; Ingram et al., online **2024**, journal issue **2025**, dosage meta-analysis; Warneke et al. **2025** Delphi consensus; a **July 2026** lower-limb flexibility meta-analysis. These are older than the last month, explicitly retained because they address the question directly. No qualifying last-month source was established in this search. [E1–E6]
- Technique pages were read on the checked date; their known review/publication dates are recorded in the source register. They are first-party technique guidance, not evidence that the proposed complete routines improve lifting outcomes.
- Publisher/health-system pages were read with `ketch scrape <URL> --max-chars <limit>`. PubMed abstracts were additionally read through its first-party API: `curl -L -s 'https://eutils.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi?db=pubmed&id=39614059,26642915,21694556&rettype=abstract&retmode=text'`; output confirmed the titles, DOIs, and findings quoted below. Mayo pages repeatedly returned HTTP 403, so unverified Mayo search snippets are not used as technique evidence. The ACSM publisher returned HTTP 403; detailed recommendations were checked in the reproduced position-stand tables on Medscape, with provenance disclosed below. [E1]

## Evidence and Recommended Defaults

### Hold Duration and Frequency

ACSM recommends holding static stretches **10–30 seconds for most adults**, with **30–60 seconds potentially more beneficial for older adults**; repeating each flexibility exercise **2–4 times**, targeting **60 seconds total per exercise**, and exercising **at least 2–3 days/week**. Its table grades hold-duration evidence **C** (nonrandomized/observational), and volume/frequency evidence **B** (limited randomized evidence). This is a reasonable baseline prescription, not proof that exactly 30 seconds is optimal for every muscle or person. Warming the muscles first is also recommended. [E1, Table 2]

**Product recommendation:** default to one convenient round of 30-second static holds, but describe that as a quick session, not as satisfying every flexibility recommendation. Suggest two rounds, 2–3 days/week, for the conventional ACSM dose; allow three rounds when the user wants more flexibility work and remains comfortable. The 15-second neck hold is a deliberately gentle editorial choice, within ACSM's general range; the five-second active twist follows the video's actual demonstration rather than pretending it is a 30-second static stretch. [E1; V 9:31–9:51]

### Total Weekly Time per Muscle

There are two different questions: a practical baseline dose and the dose that maximizes improvements in pooled studies.

- **Baseline:** ACSM's 60 seconds per exercise on 2–3 days/week yields **2–3 minutes/week for a target receiving one exercise**. For unilateral exercises, apply that calculation to each side separately: 30 seconds left plus 30 seconds right is not 60 seconds for each side. These weekly figures are arithmetic from the ACSM prescription, not an independently established minimum-effective threshold. [E1]
- **Dose-response estimate:** Ingram et al. included **189 studies and 6,654 adults**, finding moderate acute and large chronic flexibility effects. Their exploratory meta-regression estimated the greatest gains at approximately **4 minutes/session for acute changes** and **10 minutes/week for chronic changes**, with no observed additional benefit beyond those volumes in the model. Neither frequency nor intensity significantly moderated the pooled effects. These are estimated plateaus, not mandatory minimums, safety ceilings, or proof that every individual has the same response. [E2]
- **Per-muscle caution:** Do not interpret “10 minutes/week” as ten minutes of any mixed whole-body routine covering every muscle. For app planning, track actual targeted exposure per muscle/side, not elapsed routine time, pauses, or lead-ins. The accessible Ingram abstract does not fully describe normalization across multi-muscle protocols; its exact per-muscle dose coding is **unknown** here because full methods were not accessible. Consequently, “10 minutes per muscle per week” should not be presented as a verified universal prescription from this report. [E2, access limitation]
- **Competing guidance:** The 2025 Delphi panel recommends **2–3 daily sets of 30–120 seconds per muscle/soft tissue** when maximizing chronic flexibility, favoring static or PNF over dynamic stretching. This expert-consensus recommendation is more aggressive than the Ingram plateau estimate and ACSM's general-fitness baseline. The disagreement should remain visible; there is no single settled optimum. [E5, §3.2.2]
- **Illustration:** three rounds of a 30-second unilateral static stretch on three days yields **4.5 minutes/week per side**; on seven days, **10.5 minutes/week per side**. Two rounds on three days yields **3 minutes/week per side**. These are arithmetic, not promises of flexibility gains. Do not count Elephant Walks or Cat-Cow movement windows as equivalent static-hold time, or add overlapping stretches as if each isolates one muscle. [E1–E2; editorial accounting recommendation]

A July 2026 review of **79 randomized studies / 3,287 participants** again found improved lower-limb flexibility, but substantial heterogeneity (**I² = 66.1%**) and potential small-study effects. It found no significant baseline-flexibility moderator, whereas Ingram found larger improvements in people with poorer baseline flexibility. Different samples and eligibility criteria limit direct comparison; personalize by comfort and adherence rather than claiming a certain group will gain more. [E2, E6]

### Before versus After Resistance Training

**Before lifting:** prefer a general warm-up and controlled dynamic movements, followed by light practice sets of the actual lifts. The practice-set recommendation is an editorial application to dumbbell training; the cited stretching studies do not validate this exact warm-up sequence. Behm et al. found immediate performance changes averaging **−4.6% after ≥60 seconds static stretching per muscle group** versus **−1.1% after <60 seconds**, and **+1.3% after dynamic stretching**. These are study averages across performance tasks, not predicted changes for an individual dumbbell workout. Most studies tested soon afterward without a full subsequent dynamic warm-up; where dynamic activity followed stretching, no clear performance effect was observed. [E3]

The 2025 consensus similarly advises against prolonged **>60-second static stretching per muscle** before maximal/explosive contractions, while accepting brief static stretching within a dynamic warm-up. Thus “never stretch before lifting” overstates the evidence. Reserve the long static routines and repeated rounds for afterward or another session, but a brief comfortable stretch for a needed range of motion is not categorically forbidden. [E5, §3.2.3]

**After lifting / separate session:** static routines are convenient flexibility work once warm, not proven recovery treatments. Afonso et al. found no significant advantage over passive recovery for strength recovery or soreness at 24–72 hours; confidence in the evidence was **very low**, with only **229 participants** in the meta-analysis and high risk of bias in about 70% of studies. Say “flexibility session,” not “prevents tomorrow's soreness.” Evidence that immediately post-lifting is superior to a separate warmed-up session for long-term flexibility is **unknown** in the sources checked. [E1, E4]

**Rounds:** two 30-second rounds provide 60 seconds of exposure; three provide 90 seconds. The video explicitly recommends repeating the entire routine three times as a more tolerable way to accumulate 90–120 seconds than holding a single stretch for two minutes. This is presenter advice, not trial evidence that three circuits outperform the same total dose delivered differently. Whether circuits versus consecutive sets give superior flexibility outcomes for these exact routines is **unknown**. [V 9:59–10:18; E1–E2]

### Safety and Claims to Avoid

Use a mild stretch sensation, breathe normally, avoid bouncing or forcing end range, and choose the easier variation when needed. Stop if pain or feeling unwell occurs; seek individualized advice for an injury, health condition, recent surgery, pregnancy, or uncertainty about suitability. These are general fitness routines, not rehabilitation prescriptions. A five-second lead-in is setup time, **not** a physiological warm-up. [T1, T2, T3]

Do not carry over the video's “sciatica … must” claim for Figure-Four Stretch, its suggestions that everyone's hips/lats are tight, or its “best stretch” ranking for Pancake Stretch as established medical facts. They are presenter statements only. Label Elephant Walks as a hamstring mobility movement; the presenter's “nerve floss” description does not establish safety or efficacy as neural rehabilitation. If tingling, numbness, or radiating symptoms occur, do not push further; obtain appropriate clinical advice. [V 2:15–2:50, 4:24–4:37, 5:15–5:26; conservative product safety recommendation]

Stretching should not be marketed as an all-purpose injury-prevention strategy, posture correction, or a substitute for progressive resistance training; the 2025 consensus does not endorse those claims. Some technique pages make broad soreness/posture/injury claims; this report uses those pages for technique only, deferring outcome claims to the reviews and consensus. [E3–E5; T3, T6, T7]

## Timer Contract and Duration Accounting

These are proposed content semantics, not assertions about existing Blocklog implementation:

- `holdSeconds` is **per side** when `perSide` is true, and the entire movement window when false. An alternating movement that already uses both legs in one window has `perSide: false`.
- Give each timed side/window a five-second lead-in. Between sides, pause the active clock for “Switch Sides” and resume on user confirmation with the next lead-in. This prevents setup consuming hold time; pause time is not included in the durations below.
- Movement entries explicitly say to repeat/move in their cue. The timer is a **movement window**, not an instruction to remain still. The requested schema has no per-item static/dynamic discriminator; **unknown** whether the future player can communicate this without more than a cue. Shipping the dynamic routine requires a clear “keep moving” presentation, not a generic “hold this pose” instruction.
- Preserve the requested `kind: "stretch"` value for all four routines, including the warm-up, because no alternative enum was specified. Do not silently invent a new bundled format.
- All bundled routines default to `rounds: 1`; the UI can select 1–3. One round of each new routine falls within 5–10 minutes with the proposed lead-ins. Repeating a routine multiplies time and can exceed ten minutes; this is not an error or a ten-minute maximum.
- Formula: `timedSeconds = rounds × sum(holdSeconds × (perSide ? 2 : 1))`; proposed lead-in time is `rounds × 5 × sum(perSide ? 2 : 1)`. Add actual switch/transition pauses separately. Do not promise a fixed completion time while pauses are user-controlled.

| Routine | Timed Work, 1 Round | Timed Windows | With 5-Second Lead-Ins | Placement |
| --- | ---: | ---: | ---: | --- |
| Full-Body Quick Stretch | 4:40 | 11 | 5:35 + pauses | After lifting or separate warmed-up session |
| Dynamic Lifting Warm-Up | 6:00 | 5 | 6:25 + pauses | Before lifting; follow with light practice sets |
| Hips and Lower Back | 6:00 | 10 | 6:50 + pauses | After lifting or separate warmed-up session |
| Upper Body Reset | 5:00 | 10 | 5:50 + pauses | After lifting or a warmed-up movement break |

Times are arithmetic from the JSON, not measured usability results. If the player gives only one lead-in per stretch rather than per side, recalculate estimates accordingly.

## Routine Design and Technique Provenance

The final JSON is the canonical content specification for names, side flags, seconds, cues, and one-sentence easier/harder variations. Variations not explicitly shown in a cited source are conservative editorial adaptations: reduce range/support the position for easier, increase only comfortable range for harder. “Harder” never means force, pain, added weight, or needing to progress.

### Full-Body Quick Stretch

Adapt the video's sequence, including its easy/hard options, but regularize the main work to 30-second windows. Its actual demonstration often lasts longer than 30 seconds: for example Pancake begins about 3:16 and ends about 4:40, and Lat Stretch runs about 6:44–7:58. Consequently the app's compact version is **not a frame-for-frame ten-minute reproduction**. The final standing twist is genuinely brief—about five seconds per side—so keep it brief instead of converting it into a long forced spinal hold. [V]

| Order | Stretch | Per Side | Seconds | Technique Source and Adaptation |
| --- | --- | --- | ---: | --- |
| 1 | Hip Flexor Stretch | Yes | 30 | Video 0:26–2:12; half-kneeling technique and knee padding also supported by South Tees. Optional back-foot grasp is the video's harder option and adds a front-thigh stretch; do not force the knee. [V, T2] |
| 2 | Elephant Walks | No | 30 | Video 2:15–3:11: alternate straightening knees while folded forward. Hands higher is easier; lower support is harder. Use a continuous movement window, without claiming neural treatment. [V] |
| 3 | Pancake Stretch | No | 30 | Video 3:16–4:40: wide seated straddle, reach forward; upright against a wall is easier. The name and variants come from the video, not a clinical technique page independently checked here. [V] |
| 4 | Figure-Four Stretch | Yes | 30 | Video 4:44–6:34: supine ankle over opposite knee; no pull is easier, gently draw the supporting thigh closer for harder while keeping the pelvis comfortable. [V] |
| 5 | Lat Stretch | No | 30 | Video 6:44–7:58: hands forward, thumbs up, lower chest; clasped hands overhead is the harder variant. UHD documents a related kneeling lat stretch, but not this exact thumb-up/clasped-hand variant. [V, T4] |
| 6 | Seated Side Bend | Yes | 30 | Video 8:01–9:27: overhead reach, both sit bones down; smaller reach is easier, longer arc without lifting a hip is harder. [V] |
| 7 | Standing Active Twist | Yes | 5 | Video 9:31–9:51: actively turn and briefly hold each side; no hand-assisted wrenching. Smaller/larger comfortable turns are editorial variations. [V] |

**Dose:** one round provides 30 seconds per side for most unilateral static stretches; two rounds provide 60, three provide 90. Three rounds take about **16:45 plus pauses** under the proposed lead-in contract, not ten minutes. Elephant Walks and the short active twist do not receive 90 seconds of static hold per muscle from three rounds. [JSON arithmetic; E1]

### Dynamic Lifting Warm-Up

A simple, entirely standing, unloaded warm-up adapted from NHS technique instructions: Marching in Place (180 seconds), Heel Digs (60), Knee Lifts (30), Shoulder Rolls (45), and Knee Bends (45). The first three durations follow the NHS example; the latter two are editorial time windows for smooth repetitions rather than copying its repetition count. All entries alternate or move continuously, so none triggers a switch-sides pause. This is a **general dynamic warm-up**, not five static stretches and not a validated dumbbell-specific protocol. [T1]

For the shoulder rolls, perform five forward then five backward and repeat gently. For knee bends, start shallow, as the NHS describes (no more than roughly 10 cm of lowering), and use a slightly larger pain-free range only as an optional adaptation. The longer/harder option for any movement is range or comfortable pace, never ballistic movement. Follow this routine with light sets of the exercises about to be trained; that final practice step is not encoded in this stretch-only schema. [T1; editorial application]

### Hips and Lower Back

Six familiar entries, with no loaded stretching: Hip Flexor Stretch, Figure-Four Stretch, Supine Hamstring Stretch, Knee-to-Chest Stretch, Cat-Cow, and Knee Rolls. The first four are 30 seconds per side; Cat-Cow and Knee Rolls are 60-second continuous movement windows. Reusing Hip Flexor Stretch and Figure-Four Stretch preserves identical names and content rather than creating duplicate aliases. This supports hip mobility around squats, lunges, and hinges as an editorial training complement; it is not a claim to cure back pain. [T2–T3, T5; V]

| Stretch | Technique Provenance |
| --- | --- |
| Hip Flexor Stretch | South Tees' half-kneeling lunge, with cushion/pillow if needed; video for the optional back-foot grasp. [T2, V] |
| Figure-Four Stretch | Video's supine position and no-pull modification; no independent clinical-page confirmation of this exact version was obtained. [V] |
| Supine Hamstring Stretch | AAOS: lie with knees bent, hold behind the thigh, gently straighten the lifted leg; towel around the thigh if needed, not pressure at the knee joint. [T3, §4] |
| Knee-to-Chest Stretch | Guy's and St Thomas': lie with knees bent and feet down, hug behind one knee; AAOS also supplies a 30-second knee-to-chest prescription. Keep the supporting leg bent for this version. [T5; T3, §3] |
| Cat-Cow | South Tees: hands under shoulders, hips/knees at 90 degrees, round and gently reverse in a slow controlled manner. Use a movement window, not a one-minute end-range spinal hold. [T6] |
| Knee Rolls | Guy's and St Thomas': supine, knees bent, gently roll side to side and return. Use comfortable range and keep the shoulders supported; do not force a rotation. [T5] |

### Upper Body Reset

Doorway Chest Stretch (60 seconds, bilateral), Cross-Body Shoulder Stretch (30 per side), Overhead Triceps Stretch (30 per side), Lat Stretch (30, bilateral), Seated Side Bend (30 per side), and Neck Side Bend (15 per side). These complement pressing/rowing and a desk-work movement break as an editorial choice; they are not a tested posture-correction package. [T4, T7–T9; V; E5]

| Stretch | Technique Provenance |
| --- | --- |
| Doorway Chest Stretch | UMass Memorial: arms on a doorway, elbows bent, step forward upright rather than leaning. Lower elbows can reduce discomfort. Its example uses 15-second repeats; the 60-second comfortable window here is an editorial accumulated-time adaptation, not its exact prescription. [T7] |
| Cross-Body Shoulder Stretch | British Heart Foundation: arm across chest, support above elbow, gently draw closer without pressing the elbow joint; 30-second hold. [T8, §6] |
| Overhead Triceps Stretch | BHF's overhead bent-elbow technique, 30 seconds; MedlinePlus independently documents the same alternative technique with 10–20-second holds. The 30-second duration follows BHF, not MedlinePlus. [T8, §5; T9] |
| Lat Stretch | Reuse the full-body content exactly; video for the specific thumb-up/clasped-hands version, UHD for a related kneeling lat stretch. [V, T4] |
| Seated Side Bend | Reuse the video's both-hips-down overhead side bend, with smaller/larger comfortable reaches. [V] |
| Neck Side Bend | NHS neck stretch: sit tall, keep the opposite shoulder down and tilt gently. Use no hand pulling on the head; 15 seconds is an editorial duration within ACSM's general range, not the NHS page's five-second prescription. The harder version adds only a little comfortable tilt. [T10, E1] |

## Source Register

**Evidence sources**

- **[E1] ACSM / Garber et al., 2011.** *Quantity and Quality of Exercise for Developing and Maintaining Cardiorespiratory, Musculoskeletal, and Neuromotor Fitness in Apparently Healthy Adults: Guidance for Prescribing Exercise.* DOI: <https://doi.org/10.1249/MSS.0b013e318213fefb>. Author-affiliated institutional abstract: <https://digitalcommons.uri.edu/kinesiology_facpubs/137/>; PubMed: <https://pubmed.ncbi.nlm.nih.gov/21694556/>. Detailed Table 2 read through the reproduced article at <https://www.medscape.com/viewarticle/745450_11>. **Older source.** The table text is the position stand's recommendations, accessed through a secondary host; publisher full text was unavailable here, so reproduction fidelity beyond the checked abstract is not independently confirmed.
- **[E2] Ingram et al., 2025 (online 2024-11-30).** *Optimising the Dose of Static Stretching to Improve Flexibility: A Systematic Review, Meta-analysis and Multivariate Meta-regression.* *Sports Medicine* 55:597–617. DOI/publisher abstract: <https://link.springer.com/article/10.1007/s40279-024-02143-9>; <https://pubmed.ncbi.nlm.nih.gov/39614059/>. Search through June 2024. **Older source; abstract/preview read, full methods unavailable.**
- **[E3] Behm, Blazevich, Kay, and McHugh, 2016.** *Acute Effects of Muscle Stretching on Physical Performance, Range of Motion, and Injury Incidence in Healthy Active Individuals: A Systematic Review.* *Applied Physiology, Nutrition, and Metabolism* 41:1–11. DOI: <https://doi.org/10.1139/apnm-2015-0235>; abstract read via first-party PubMed API, <https://pubmed.ncbi.nlm.nih.gov/26642915/>. **Older source; abstract read.**
- **[E4] Afonso et al., 2021-05-05.** *The Effectiveness of Post-exercise Stretching in Short-Term and Delayed Recovery of Strength, Range of Motion and Delayed Onset Muscle Soreness: A Systematic Review and Meta-Analysis of Randomized Controlled Trials.* *Frontiers in Physiology* 12:677581. <https://www.frontiersin.org/journals/physiology/articles/10.3389/fphys.2021.677581/full>. Abstract and methods read; reported GRADE confidence very low. **Older source.**
- **[E5] Warneke et al., 2025-06-11 online.** *Practical Recommendations on Stretching Exercise: A Delphi Consensus Statement of International Research Experts.* *Journal of Sport and Health Science* 14:101067. DOI: <https://doi.org/10.1016/j.jshs.2025.101067>. Author-institution PDF: <https://pure.northampton.ac.uk/ws/files/85616373/Warneke_et_al_2025_Practical_recommendations_on_stretching_exercise_a_Delphi_consensus_statement_of_international_research_experts.pdf>. Abstract and §§3.2.1–3.2.4 read. Twenty experts, at least 80% agreement threshold; **expert consensus, not a new intervention trial; older source**.
- **[E6] 2026-07-11.** *Moderating Effects of Individual Characteristics and the Target Lower Limb Muscle Group on Flexibility Adaptations to Chronic Static Stretching in Healthy Individuals: A Systematic Review and Meta-Analysis of Randomized Controlled Trials.* DOI: <https://link.springer.com/article/10.1186/s40798-026-01066-1>. Abstract and introduction read; studies published before June 2025. **Older than the last month.**

**Technique sources**

- **[V] Video:** <https://www.youtube.com/watch?v=eQHmKJh20_c>. English transcript read directly through the named wrapper; source for the model routine and timestamped presenter advice, not a clinical effectiveness study. Publication date and whether the English track was manually edited: **unknown**.
- **[T1] NHS, “How to Warm Up Before Exercising.”** <https://www.nhs.uk/live-well/exercise/how-to-warm-up-before-exercising/>. Page last reviewed **2026-06-24**, video last reviewed 2023-12-08; **older than the last month**. All five warm-up techniques read.
- **[T2] South Tees Hospitals NHS Foundation Trust, “Hip Stretch in Half Kneeling.”** <https://www.southtees.nhs.uk/resources/hip-stretch-in-half-kneeling/>. Technique text and knee-padding modification read; page review date **unknown**.
- **[T3] American Academy of Orthopaedic Surgeons / OrthoInfo, “Hip Conditioning Program.”** <https://orthoinfo.aaos.org/en/recovery/hip-conditioning-program/>. Knee-to-chest and supine hamstring instructions read; current page review date **unknown**. This is clinician-supervised rehabilitation guidance; the app borrows techniques, not its complete rehabilitation dosage or broad soreness-prevention claim.
- **[T4] University Hospitals Dorset / Poole Hospital NHS Foundation Trust, “Upper Limb Stretching Programme.”** <https://www.uhd.nhs.uk/uploads/about/docs/our_publications/patient_information_leaflets/Childrens_therapy/Childrens_physiotherapy/Upper_limb_stretching_sheet_2019_done.pdf>. Issued 2017-09-15, revised **2019-11-15**; **older source**, pediatric physiotherapy leaflet. Used only to cross-check familiar kneeling lat/shoulder techniques, not as adult effectiveness evidence.
- **[T5] Guy's and St Thomas' NHS Foundation Trust, “Low Back Pain: Physiotherapy and Exercises.”** <https://www.guysandstthomas.nhs.uk/health-information/low-back-pain/physiotherapy-and-exercises>. Resource **4876/VER2**, reviewed **March 2024**, next review March 2027; **older source**. Knee hugs and knee rolls read.
- **[T6] South Tees Hospitals NHS Foundation Trust, “Cat Stretch.”** <https://www.southtees.nhs.uk/resources/cat-stretch/>. Technique text read; review date **unknown**.
- **[T7] UMass Memorial Health, “Doorway Pectoral Stretch (Flexibility).”** <https://www.ummhealth.org/health-library/doorway-pectoral-stretch-flexibility>. Technique and lower-elbow modification read; review date **unknown**. Health-system-hosted patient education, not a research trial.
- **[T8] British Heart Foundation, “Stretching Exercises to Improve Your Flexibility in 10 Minutes.”** <https://www.bhf.org.uk/informationsupport/heart-matters-magazine/activity/stretching-exercises>. Published **2024-10-14**; **older source**. Exercise specialist's cross-body shoulder and overhead triceps instructions read; used for technique, not its broader physiological/outcome claims.
- **[T9] MedlinePlus, “Triceps Stretch.”** <https://medlineplus.gov/ency/imagepages/19488.htm>. Reviewed **2024-07-23**; **older source**. Federal health-information platform hosting reviewed A.D.A.M. patient education; overhead alternative technique read.
- **[T10] NHS, “Flexibility Exercises.”** <https://www.nhs.uk/live-well/exercise/flexibility-exercises/>. Reviewed **2023-11-20**, next review 2026-11-20; **older source**. Neck side-tilt technique read.

## Unsettled Questions

- **Unknown:** an exact universally optimal hold duration, frequency, and weekly per-muscle threshold; general-fitness guidance, exploratory meta-regression, and flexibility-maximization consensus do not prescribe the same dose. [E1–E2, E5–E6]
- **Unknown:** superiority of three circuits over two circuits or equal-volume consecutive sets for these routines; no such direct trial was established. [V; E1–E2]
- **Unknown:** effects of these exact bundled routines on dumbbell-training strength, injury rates, recovery, or clinical back/sciatic symptoms; they have not been validated by the evidence checked.
- **Unknown:** precise attribution of every multi-joint stretch's time to a particular muscle, and Ingram's full dose-normalization methods from the accessible abstract. Do not build a falsely precise muscle-dose dashboard from this report. [E2]
- **Unknown:** how the future player distinguishes timed movement from static holds in this fixed schema. Cues encode the distinction, but the player must not contradict them.
- **Unknown:** independent clinical-page verification of the video's exact Elephant Walks, Pancake, Figure-Four, Seated Side Bend, and Standing Active Twist variants. Their provenance is the video; the remaining proposed routine additions use the named health-system/public-health sources.

## Bundle JSON

All cues below are under 120 characters. The warm-up, Elephant Walks, Cat-Cow, and Knee Rolls use the `holdSeconds` field as a timed movement window, as explained above.

```json
[
  {
    "name": "Full-Body Quick Stretch",
    "kind": "stretch",
    "rounds": 1,
    "stretches": [
      {
        "name": "Hip Flexor Stretch",
        "perSide": true,
        "holdSeconds": 30,
        "cue": "Kneel in a lunge, gently tuck your pelvis, and shift forward without arching your back.",
        "easier": "Pad the back knee, use a chair for balance, and keep the forward shift small.",
        "harder": "If comfortable, bend the back knee and gently hold the back foot without forcing the knee or arching."
      },
      {
        "name": "Elephant Walks",
        "perSide": false,
        "holdSeconds": 30,
        "cue": "Fold forward with soft knees and slowly alternate straightening each leg without locking the knee.",
        "easier": "Rest your hands on a stable chair and keep both knees slightly bent.",
        "harder": "Lower your hands toward the floor while continuing slow, comfortable alternating knee extensions."
      },
      {
        "name": "Pancake Stretch",
        "perSide": false,
        "holdSeconds": 30,
        "cue": "Sit with legs comfortably wide and hinge forward from your hips while breathing steadily.",
        "easier": "Sit upright with your back against a wall and use a narrower leg position.",
        "harder": "Reach farther forward from your hips while keeping the position comfortable and unforced."
      },
      {
        "name": "Figure-Four Stretch",
        "perSide": true,
        "holdSeconds": 30,
        "cue": "Lie on your back, cross one ankle over the other thigh, and gently draw that thigh toward you.",
        "easier": "Leave the supporting foot on the floor and hold the ankle-over-thigh position without pulling.",
        "harder": "Draw the supporting thigh slightly closer while keeping your pelvis comfortable and avoiding knee pressure."
      },
      {
        "name": "Lat Stretch",
        "perSide": false,
        "holdSeconds": 30,
        "cue": "From hands and knees, reach forward with thumbs up and gently lower your chest without arching.",
        "easier": "Keep your hands closer and lower your chest only a little.",
        "harder": "If your shoulders allow, clasp your hands overhead and gently lower your chest farther."
      },
      {
        "name": "Seated Side Bend",
        "perSide": true,
        "holdSeconds": 30,
        "cue": "Sit tall, reach one arm overhead, and bend sideways while keeping both sit bones down.",
        "easier": "Sit on a firm chair and make a small overhead reach with your other hand supporting you.",
        "harder": "Lengthen the overhead reach and bend a little farther without lifting either hip or twisting."
      },
      {
        "name": "Standing Active Twist",
        "perSide": true,
        "holdSeconds": 5,
        "cue": "Stand tall, actively turn your torso to one side, and briefly hold without pulling with your hands.",
        "easier": "Use a smaller turn and keep your arms relaxed beside you.",
        "harder": "Turn a little farther under your own control without forcing your spine or knees."
      }
    ]
  },
  {
    "name": "Dynamic Lifting Warm-Up",
    "kind": "stretch",
    "rounds": 1,
    "stretches": [
      {
        "name": "Marching in Place",
        "perSide": false,
        "holdSeconds": 180,
        "cue": "Keep marching in place and swing your arms gently, starting slowly and building a comfortable rhythm.",
        "easier": "Hold a stable chair and take small, low steps.",
        "harder": "Raise your knees a little higher and increase your pace while remaining comfortable."
      },
      {
        "name": "Heel Digs",
        "perSide": false,
        "holdSeconds": 60,
        "cue": "Alternate placing each heel forward with toes up, keeping a soft bend in the supporting knee.",
        "easier": "Hold a stable chair and place each heel only a short distance forward.",
        "harder": "Reach each heel slightly farther forward and add gentle opposite-arm punches."
      },
      {
        "name": "Knee Lifts",
        "perSide": false,
        "holdSeconds": 30,
        "cue": "Keep alternating knee lifts toward the opposite hand while standing tall and keeping your back steady.",
        "easier": "Hold a stable chair and lift each knee only a little.",
        "harder": "Lift each knee slightly higher without leaning backward or speeding beyond control."
      },
      {
        "name": "Shoulder Rolls",
        "perSide": false,
        "holdSeconds": 45,
        "cue": "March gently and roll both shoulders five times forward, then five times backward, repeating smoothly.",
        "easier": "Stand still or sit tall and make smaller shoulder circles.",
        "harder": "Make slightly larger comfortable circles while maintaining a gentle marching rhythm."
      },
      {
        "name": "Knee Bends",
        "perSide": false,
        "holdSeconds": 45,
        "cue": "Stand with feet shoulder-width apart and repeat shallow knee bends, lowering slowly and rising smoothly.",
        "easier": "Hold a stable chair and use a very small bend.",
        "harder": "Use a slightly deeper comfortable bend while keeping your heels down and movement controlled."
      }
    ]
  },
  {
    "name": "Hips and Lower Back",
    "kind": "stretch",
    "rounds": 1,
    "stretches": [
      {
        "name": "Hip Flexor Stretch",
        "perSide": true,
        "holdSeconds": 30,
        "cue": "Kneel in a lunge, gently tuck your pelvis, and shift forward without arching your back.",
        "easier": "Pad the back knee, use a chair for balance, and keep the forward shift small.",
        "harder": "If comfortable, bend the back knee and gently hold the back foot without forcing the knee or arching."
      },
      {
        "name": "Figure-Four Stretch",
        "perSide": true,
        "holdSeconds": 30,
        "cue": "Lie on your back, cross one ankle over the other thigh, and gently draw that thigh toward you.",
        "easier": "Leave the supporting foot on the floor and hold the ankle-over-thigh position without pulling.",
        "harder": "Draw the supporting thigh slightly closer while keeping your pelvis comfortable and avoiding knee pressure."
      },
      {
        "name": "Supine Hamstring Stretch",
        "perSide": true,
        "holdSeconds": 30,
        "cue": "Lie on your back, hold behind one thigh, and gently straighten that knee until you feel a mild stretch.",
        "easier": "Keep the lifted knee more bent and use a towel around the thigh if reaching is difficult.",
        "harder": "Straighten the lifted leg a little more without locking the knee or pulling on the knee joint."
      },
      {
        "name": "Knee-to-Chest Stretch",
        "perSide": true,
        "holdSeconds": 30,
        "cue": "Lie with knees bent, hug behind one knee, and gently bring it toward your chest with your back relaxed.",
        "easier": "Draw the knee only a little toward you and leave the other foot on the floor.",
        "harder": "Bring the knee a little closer while keeping your pelvis relaxed and avoiding pressure on the knee joint."
      },
      {
        "name": "Cat-Cow",
        "perSide": false,
        "holdSeconds": 60,
        "cue": "On hands and knees, slowly alternate rounding your back and gently opening your chest as you breathe.",
        "easier": "Use a smaller spinal movement and pad your knees as needed.",
        "harder": "Explore a slightly larger comfortable range while staying slow and avoiding a forced back arch."
      },
      {
        "name": "Knee Rolls",
        "perSide": false,
        "holdSeconds": 60,
        "cue": "Lie with knees bent and feet down, then slowly roll your knees side to side with shoulders supported.",
        "easier": "Move your knees only a short distance from the center.",
        "harder": "Let your knees travel a little farther while keeping the movement comfortable and unforced."
      }
    ]
  },
  {
    "name": "Upper Body Reset",
    "kind": "stretch",
    "rounds": 1,
    "stretches": [
      {
        "name": "Doorway Chest Stretch",
        "perSide": false,
        "holdSeconds": 60,
        "cue": "Place both forearms on a doorway and step forward gently, staying upright with shoulders relaxed.",
        "easier": "Lower your elbows and take a smaller step forward.",
        "harder": "Take a slightly larger step without leaning, arching your back, or forcing your shoulders."
      },
      {
        "name": "Cross-Body Shoulder Stretch",
        "perSide": true,
        "holdSeconds": 30,
        "cue": "Bring one arm across your chest and gently support it above the elbow while keeping the shoulder down.",
        "easier": "Keep the arm lower and draw it only slightly across your chest.",
        "harder": "Draw the upper arm a little closer without pressing on the elbow joint or shrugging."
      },
      {
        "name": "Overhead Triceps Stretch",
        "perSide": true,
        "holdSeconds": 30,
        "cue": "Reach one hand behind your neck and support the raised elbow gently with your other hand.",
        "easier": "Let your raised elbow stay wider and avoid pulling it inward.",
        "harder": "Gently guide the elbow a little inward while keeping your ribs down and shoulder comfortable."
      },
      {
        "name": "Lat Stretch",
        "perSide": false,
        "holdSeconds": 30,
        "cue": "From hands and knees, reach forward with thumbs up and gently lower your chest without arching.",
        "easier": "Keep your hands closer and lower your chest only a little.",
        "harder": "If your shoulders allow, clasp your hands overhead and gently lower your chest farther."
      },
      {
        "name": "Seated Side Bend",
        "perSide": true,
        "holdSeconds": 30,
        "cue": "Sit tall, reach one arm overhead, and bend sideways while keeping both sit bones down.",
        "easier": "Sit on a firm chair and make a small overhead reach with your other hand supporting you.",
        "harder": "Lengthen the overhead reach and bend a little farther without lifting either hip or twisting."
      },
      {
        "name": "Neck Side Bend",
        "perSide": true,
        "holdSeconds": 15,
        "cue": "Sit tall and gently tilt one ear toward its shoulder, keeping the opposite shoulder down.",
        "easier": "Use a tiny tilt and leave both arms relaxed.",
        "harder": "Increase the tilt only slightly while keeping both shoulders down and never pulling on your head."
      }
    ]
  }
]
```
