# PowerBlock achievable weights and physical selection

## Question and short answer

For each current or commonly encountered recent PowerBlock adjustable dumbbell, which **per-dumbbell** weights are achievable, and how does the user physically select them?

Elite EXP, Elite USA, the discontinued Pro EXP, and Sport EXP share a **gapped** weight scheme: 5, 7.5, 10, then 15/17.5/20, 25/27.5/30, and so on. They do **not** make 12.5, 22.5, 32.5, etc. Pro 50 does make every 2.5-pound step from 5 to 50. Pro 100 EXP follows the gapped scheme through 100, including a manual-confirmed 7.5-pound handle-only setting that its product page omits. Commercial models can require swapping the entire handle instead of adding micro weights. Sources and full enumerations follow. [E][U][R1][R2][P50][P100][M100][C100]

A model/stage-specific list is sufficient to constrain the app's weight picker. To show setup instructions, each entry also needs a **selection recipe**: rail identity/printed label, handle-only versus nested plates, number of micro weights, or which interchangeable handle to use. Preserve hardware identity separately from display units; localized kg copy contains rounding and outright errors. This is a design recommendation based on the mechanisms documented below, not a PowerBlock specification.

## Date, scope, evidence quality

- Checked **2026-10-07** (`date +%F` returned `2026-10-07`). Product pages describe the catalog served on that date, not a historical catalog snapshot. Their publication/update dates are **unknown**. Manual versions are recorded in the source register; the June 2025 and June 2026 manuals are older than one month. Image URLs retain their source version parameters.
- Local-first check: `fd . docs/research` found only `docs/research/tuist-vs-xcodegen.md`; `rg -n -i powerblock docs` produced no matches; `git log -5 --oneline` reported `fatal: not a git repository (or any of the parent directories): .git`. No local answer/history was available.
- All weights below are **nominal manufacturer labels**, not measured masses. PowerBlock itself calls micro weights “approximately” 2.5 lb in its Pro 100 manual. [M100]
- Main evidence is PowerBlock's own pages, manuals, and product photographs. Retailer-specification evidence is explicitly identified below; independent authorization of those retailers was **unknown** in this check. Do not treat a retailer's copied specification as equivalent to a manufacturer-confirmed mechanical detail.
- This covers the named families and current commercial lineup, not every historical Rexan, Classic, Urethane, Sport 5.0/5.5/9.0, or regional private-label generation. Those should not silently inherit recipes from similarly named products. Official compatibility pages expressly distinguish several of them. [X][PX2][SX3]

## Shared scheme A: 50 → 70 → 90 pounds

The following lists apply separately to **Elite EXP**, **Elite USA 50/70/90**, **old Pro EXP**, and **Sport EXP** with the respective stages installed. Manufacturer evidence directly supports the Elite lists; the old Pro and Sport base lists additionally rely on retailer specifications. [E][U][MUSA][R1][R2][PX2][PX3][SX2][SX3]

| Installed equipment | Range per dumbbell | Full achievable weights, lb |
|---|---|---|
| Stage 1 / 50 | 5–50 | 5, 7.5, 10, 15, 17.5, 20, 25, 27.5, 30, 35, 37.5, 40, 45, 47.5, 50 |
| Stage 1 + Stage 2 / 70 | 5–70 | 5, 7.5, 10, 15, 17.5, 20, 25, 27.5, 30, 35, 37.5, 40, 45, 47.5, 50, 55, 57.5, 60, 65, 67.5, 70 |
| Stage 1 + Stage 2 + Stage 3 / 90 | 5–90 | 5, 7.5, 10, 15, 17.5, 20, 25, 27.5, 30, 35, 37.5, 40, 45, 47.5, 50, 55, 57.5, 60, 65, 67.5, 70, 75, 77.5, 80, 85, 87.5, 90 |

**Not supported:** 12.5, 22.5, 32.5, 42.5, 52.5, 62.5, 72.5, or 82.5 lb. This follows directly from the enumerations, not from a generic “2.5-pound increment” claim. [E][U][R1][R2]

### Elite EXP

**Selection:** The empty handle is 5 lb; each handle accepts two removable 2.5 lb cylindrical micro/adder weights. They slide into handle tubes controlled by an **Auto Lock**. Remove the handle, hold it facing up, open the lock, insert zero/one/two adders, close the lock, return it to the stack, and insert the tethered magnetic selector pin at the desired colored rail. The lock must be closed when using the handle by itself; the manual describes automatic activation when reinserting into the first plate. [E][MEXP]

The official guide gives the complete recipe map below. Printed rail totals assume **both adders installed**; a rail marked 30 is **25 with neither adder**, not a 25-pound plate to which the handle is added again. [E][MEXP]

| Stage | Rail identity | Printed/full-adder total, lb | No adders | One adder | Two adders |
|---|---|---:|---:|---:|---:|
| 1 | Handle only; no plates | 10 | 5 | 7.5 | 10 |
| 1 | 1: black | 20 | 15 | 17.5 | 20 |
| 1 | 2: white | 30 | 25 | 27.5 | 30 |
| 1 | 3: purple | 40 | 35 | 37.5 | 40 |
| 1 | 4: green | 50 | 45 | 47.5 | 50 |
| 2 | 5: yellow | 60 | 55 | 57.5 | 60 |
| 2 | 6: blue | 70 | 65 | 67.5 | 70 |
| 3 | 7: red | 80 | 75 | 77.5 | 80 |
| 3 | 8: black | 90 | 85 | 87.5 | 90 |

Stage 2 adds two 10-pound nested plate assemblies per dumbbell; Stage 3 adds two more. The current localized product page offers 50/70/90 equivalents, while the manual explains nesting the existing set into each expansion in sequence. Expansion kits must match **Elite EXP**, not Elite USA. [EK][MEXP][U][X]

**Identification:** PowerBlock's guide photographs show a square, closed/wrist-support handle, colored rail bands, and rail decals in lb/kg; the documented product is called **Elite EXP**. Exact wording on every production-year handle decal is **unknown**. Record the user's actual decal/photo and whether the lock is the EXP Auto Lock; do not identify it from “Elite 90” or maximum weight alone. Elite USA parts and expansions are explicitly incompatible with Elite EXP. [E][EK][U]

**Kg:** A kg-displayed/localized Elite EXP offering exists, but evidence establishes lb-equivalent weights, not an independently calibrated whole-kilogram hardware version. The official kg chart and localized product page provide the following values; chart uses **9.0** for 20 lb while the product page uses **9.1**. [Ekg][EK]

- Stage 1: **2.3, 3.4, 4.5, 6.8, 7.9, 9.0/9.1, 11.3, 12.5, 13.6, 15.9, 17.0, 18.1, 20.4, 21.5, 22.7 kg**.
- Stage 2 adds **24.9, 26.1, 27.2, 29.5, 30.6, 31.8 kg**; all Stage 1 entries remain.
- Stage 3 adds **34.0, 35.2, 36.3, 38.6, 39.7, 40.8 kg**; all preceding entries remain.
- Range: **2.3–22.7 → 2.3–31.8 → 2.3–40.8 kg**. Marketing also rounds these maxima to 23/32/41 kg. The manual equates each 2.5 lb adder to 1.1 kg. Do not add rounded kg components to calculate the final display value. [Ekg][EK][MEXP]

### Elite USA 50 / 70 / 90

**Weights:** Use the complete Stage 1/2/3 lists in scheme A. The USA manual explicitly describes 5–50, then 5–70, then 5–90. The current product page sells capacity variants and lists the full 90-pound sequence. [MUSA][U]

**Selection:** The handle is 5/7.5/10 lb with zero/one/two 2.5 lb adders. Unlike EXP's described automatic lock, the USA manual names a **selector disk**, with an open/close decal on the top face controlling the adder tubes. Open, add/remove cylinders with the handle removed, close, then choose the color-coded rail using the magnetic pin. Optional Elite stands have storage ports for removed adders. [MUSA]

Expansion is by nesting the 50-pound set into the Stage 2 kit (yellow rail up), then nesting the 70-pound set into Stage 3 (red rail up). These are USA-family kits; the manual excludes Classic 50 Plus and Personal Trainer, and the product page excludes Elite EXP. [MUSA][U]

**Identification:** Current catalog calls it **Elite USA 90**, while its manual also calls capacities **Elite 50**, **Elite 70**, and **Elite 90**. Current product images show the closed square handle and stainless knurled grip; the older manual covers an earlier generation. Exact on-hardware decal text across these generations is **unknown**. A USA manual/country label and compatible USA expansion/part identity are better discriminators than shape alone. [U][MUSA]

**Kg:** USA manual is lb-based; the international catalog still lists Elite USA, and the shared lb sequence can be displayed as the same conversions as scheme A. Whether a **distinct kg-calibrated USA SKU** exists is **unknown**; do not invent 1-kg intervals. The official USA page's physical range is 5–90 lb, not a metric progression. [U][MUSA][S24kg]

### Pro EXP (old 50/70/90, not Pro 100 EXP)

**Weights:** Scheme A, with 5–50 Stage 1, 5–70 with Stage 2, and 5–90 with Stage 3. Dotmar's PowerBlock-branded listing enumerates the base weights and describes micro-loaded adders/automatic locking; PowerBlock's own expansion pages confirm the stage capacities and compatibility. **Retailer specification evidence:** the complete old base sequence comes from Dotmar, not a surviving current manufacturer base product page. [R1][PX2][PX3]

**Selection:** Open handle, urethane-coated nested plates, magnetic/tethered selector pin, two micro adders, and automatic adder locking on return to the stack. The Pro-series manual describes opening the adder lock left/down, closing right/up, and optional stand storage for adders. The 5/7.5/10 handle and 10-pound plate increments are supported by the retailer sequence and expansion specifications; the exact old Pro EXP rail-color-to-total mapping across production years is **unknown** here. Use printed rail/chart values rather than copying Elite colors. [R1][MPRO][PX2][PX3]

Stage 2 adds 50–70, Stage 3 adds 70–90, and Stage 3 requires Stage 2. The manufacturer says Stage 1 was discontinued in **2024**, but expansions remain listed; Stage 2 is compatible with U90, not U50/U70 or Pro Rexan. **Pro 50 is not expandable**, despite the similarity of its name. [PX2][PX3]

**Identification:** Retail listing uses **Pro EXP** / **Pro 50 EXP**, SKU **504-00114-01**, urethane plates and open handle. Exact printed handle label is **unknown**. Verify “EXP” and expansion slots; **Pro 50** and **Pro 100 EXP** are different products. [R1][PX2][P50][P100]

**Kg:** Old Pro EXP metric retail listings exist; distinct metric-native hardware is **unknown**. The lb-equivalent scheme-A kg values above are conversions, not independently verified old Pro EXP decal text. Bodytrading lists the 5–50 lb base and metric equivalents under **PBPROSET1**, but its table includes 5.7/10.2/14.7/19.3 kg (12.5/22.5/32.5/42.5 lb equivalents), conflicting with Dotmar’s gapped old Pro EXP list, and even equates 50 lb to 20.7 kg in prose. Treat this as inconsistent retailer copy, not evidence for additional native-kg settings. [R6][R1]

### Sport EXP

**Weights:** Scheme A. Fitness Warehouse's 90-pound retailer specification enumerates every entry; PowerBlock's own expansion pages confirm Stage 2 50–70 and Stage 3 70–90. **Retailer specification evidence:** complete base/full sequence and two 2.5 lb adders are from that retailer listing. Its isolated “2.5 (adder weight)” is a loose component, **not a 2.5 lb assembled dumbbell setting**. [R2][SX2][SX3]

**Selection:** Magnetic selector pin, open-handle Sport design, micro adders in the handle, numbered side rails. PowerBlock specifically describes Stage 2 rails numbered **60 and 70** and two additional 10-pound weights per dumbbell. For a verified model with scheme A, use the printed full-adder rail total minus 5/2.5/0 lb for zero/one/two adders; exact Sport EXP lock geometry and every rail color for each generation are **unknown** from the accessible manufacturer text. [R2][SX2][SX3][MSPORT]

Stage 2 and Stage 3 must be installed sequentially. PowerBlock describes Sport EXP as discontinued while continuing to list the expansions; Sport EXP expansions are not compatible with Sport 50, Sport 24, Sport 5.5, Sport 9.0 or Elite EXP. [X][SX2][SX3]

**Identification:** Model name is **Sport EXP**, not simply Sport 50. Official kit images/descriptions show numbered rails and the compatible Sport EXP frame. Exact printed model decal across generations is **unknown**; capacity alone does not distinguish a Sport EXP Stage 1 from a nonexpandable Sport 50. [SX2][SX3][R2][R3]

**Kg:** Manufacturer has localized Stage 2 **23–32 kg** and Stage 3 **32–41 kg** copy and calls each added assembly 4.5 kg. This supports metric presentation of the lb family, not a separate integer-kg mechanism. Scheme-A conversions apply for app display; historical Sport EXP decal rounding is **unknown**. Bodytrading’s metric base list reads **2.2, 3.4, 4.5, 6.8, 7.9, 9, 11.3, 12.5, 13.6, 15.8, 17, 18.1, 20.4, 21.5, 22.7 kg**, with an additional loose 1.1 kg adder listed separately; it uses inconsistent rounding (and the same incorrect 50 lb = 20.7 kg prose), so it is not a precise calibration source. [SX2kg][SX3][R7]

## Pro 100 EXP (current residential expandable model)

**Full physically supported lb weights:** product page plus manual-confirmed 7.5-pound handle setting. [P100][M100]

| Stage | Range | Full achievable weights, lb |
|---|---|---|
| 1 | 5–40 | 5, 7.5, 10, 15, 17.5, 20, 25, 27.5, 30, 35, 37.5, 40 |
| 2 | 5–60 | 5, 7.5, 10, 15, 17.5, 20, 25, 27.5, 30, 35, 37.5, 40, 45, 47.5, 50, 55, 57.5, 60 |
| 3 | 5–80 | 5, 7.5, 10, 15, 17.5, 20, 25, 27.5, 30, 35, 37.5, 40, 45, 47.5, 50, 55, 57.5, 60, 65, 67.5, 70, 75, 77.5, 80 |
| 4 | 5–100 | 5, 7.5, 10, 15, 17.5, 20, 25, 27.5, 30, 35, 37.5, 40, 45, 47.5, 50, 55, 57.5, 60, 65, 67.5, 70, 75, 77.5, 80, 85, 87.5, 90, 95, 97.5, 100 |

**Selection:** Empty 5 lb handle; two 2.5 lb cylinders in lower handle tubes; Auto Lock lever; choose colored rail with magnetic tethered pin. Handle-only 5/7.5/10 is explicitly permitted, with the Auto Lock manually closed. The printed handle chart assumes both adders installed. [P100][M100]

Official rail photograph maps **handle 10; black 20; white 30; orange 40; green 50; yellow 60; blue 70; red 80; purple 90; gray 100**. At each plate rail, subtract 5 or 2.5 lb for zero or one adder. Notice that **40 is orange here, purple on Elite EXP**. [P100img][E]

Each expansion adds 20 lb per dumbbell. The manual says nest Stage 1 into Stage 2 with green rail up (40→60), Stage 2 into Stage 3 with blue rail up (60→80), and Stage 3 into Stage 4 with purple rail up (80→100). These kits fit only this family and must be installed in sequence. [M100][P100]

**Identification:** Official photograph's handle says **PRO 100 EXP** above the PowerBlock logo. Urethane plates, open handle, 40/60/80/100 stages, and internal adders distinguish it from the commercial model. The product page states that **Hammer Strength 100 is the same set** and uses these expansions/accessories. [P100img][P100]

**Kg:** Localized offering exists; manual explicitly gives 2.3–18.1 → 2.3–27.2 → 2.3–36.3 → 2.3–45.4 kg. A distinct kg-native mass scheme is **unknown**. Correct lb-equivalent displayed sequence, combining official Elite chart values through 90 with Pro 100 values above 90, is: [M100][P100kg][Ekg]

**2.3, 3.4, 4.5, 6.8, 7.9, 9.0/9.1, 11.3, 12.5, 13.6, 15.9, 17.0, 18.1, 20.4, 21.5, 22.7, 24.9, 26.1, 27.2, 29.5, 30.6, 31.8, 34.0, 35.2, 36.3, 38.6, 39.7, 40.8, 43.1, 44.2, 45.4 kg**. Stage maxima truncate this list at 18.1/27.2/36.3/45.4.

**Discrepancies:** The US product/compare lists omit **7.5** despite the manual explicitly documenting it and the page claiming 30 pairs replaced while enumerating 29 entries. The localized product list also omits 3.4, and prints **26.3 and 28.6** in the positions corresponding to **80 and 85 lb**; these conflict with the manual's 80 lb = 36.3 kg and the official Elite conversion chart's 85 lb = 38.6 kg. Its prose alternates 1 kg and 1.1 kg for micro weights. Do not ingest localized copy as a literal new hardware schedule. [P100][CMP][M100][P100kg][Ekg]

## Pro 50 (residential, nonexpandable)

**Range and full lb list:** **5–50 lb**: **5, 7.5, 10, 12.5, 15, 17.5, 20, 22.5, 25, 27.5, 30, 32.5, 35, 37.5, 40, 42.5, 45, 47.5, 50**. No expansion. [P50]

**Selection:** 5 lb empty handle, two 2.5 lb adders, **5 lb** nested plate increments (not 10 lb). Adders live in each handle; magnetic pin selects a colored plate rail. Pro-series manual documents opening/closing the adder lock and optional stand storage. Nine 5 lb plate steps plus the variable handle give the listed range; this nine-step count is arithmetic from the documented 5 lb handle/plates and 50 lb maximum. [P50][MPRO]

For a printed/full-adder rail total `R`, the resulting weights are `R−5`, `R−2.5`, and `R` with zero/one/two adders. Handle-only is 5/7.5/10. Multiple configurations can produce the same weight (e.g. 10 with handle + both adders, or empty handle + first 5 lb plate). This is a mechanical derivation from the documented components; exact recommended color/recipe for each overlapping weight is **unknown** until the user's actual chart is inspected. [P50][MPRO]

**Identification:** Current title **Pro 50**; black urethane plates, open/V-shaped handle and contoured TPR grip in stock product photos. Exact printed model decal is **unknown** from the readable text. The manufacturer specifically says its handle lacks expansion slots and cannot accept Pro EXP expansion plates; Pro 100 EXP and Pro 100 Commercial handles do not fit. [P50][PX2]

**Kg:** Localized product exists, says 2.3–23 kg, and publishes **2.3, 3, 5, 6, 7, 8, 9, 10, 11, 12, 14, 15, 16, 17, 18, 19, 20, 22, 23 kg**. This is coarse/inconsistent rounding of the 19 lb settings, not evidence of those exact whole-kg physical masses; it also identifies included adders as 1.1 kg while prose says 1 kg. A distinct native-kg model is **unknown**. [P50kg]

For app unit conversion, the corresponding one-decimal numerical conversions of the lb list are **2.3, 3.4, 4.5, 5.7, 6.8, 7.9, 9.1, 10.2, 11.3, 12.5, 13.6, 14.7, 15.9, 17.0, 18.1, 19.3, 20.4, 21.5, 22.7 kg**. These are **calculated conversions**, not a manufacturer decal transcription (see conversion method below).

## Pro 32 (residential) and Commercial Pro 32

**Each model's range and complete advertised list:** **4–32 lb**: **4, 8, 12, 16, 20, 24, 28, 32**. Both are nonexpandable. Commercial page confirms 4 lb increments; residential page and compare chart enumerate the list. [P32][C32][CMP][X]

**Selection:** Magnetic selector pin at colored rails; Commercial Pro 32 explicitly describes matching the color bands to the handle chart. No micro-weight steps appear in either schedule. A directly stated bare-handle mass and whether the advertised 4-pound setting is bare-handle or first-rail on every generation are **unknown** in the manufacturer text inspected; do not add a speculative 2-pound/other bare-handle entry. Neither source describes interchangeable handles for this size. [P32][C32]

**Identification:** Product titles distinguish **Pro 32** from **Commercial Pro 32**; both have black urethane plates. Commercial page describes contoured TPR grips and no compatible knurled handle/grip. Exact printed handle model text and generation-specific visual distinction are **unknown**. The weight list may be shared, but commercial warranty/hardware identity should not be inferred from that list. [P32][C32]

**Kg:** Localized residential Pro 32 list is **1.8, 3.6, 5.4, 7.3, 9.1, 10.9, 12.7, 14.5 kg**, range 1.8–14.5. These are the lb list's displayed equivalents. A distinct metric-calibrated model or different Commercial Pro 32 metric schedule is **unknown**; converting its identical lb list gives those same values. [P32kg][C32]

## Sport 24

**Advertised range/list:** **3–24 lb**: **3, 6, 9, 12, 15, 18, 21, 24**. Nonexpandable; no micro/adder weights. Magnetic selector pin and colored rails select the desired chart value. [S24][MS24][X]

**Important bare-handle discrepancy:** The current manufacturer's “What's included / Handles” text explicitly says **1.5 lb handles**, yet the same product page and compare table start at **3 lb**, not 1.5. The localized page similarly says a 0.7 kg handle while its selectable list starts at 1.4. Therefore **1.5 lb (approximately 0.7 kg) handle-only is a manufacturer-reported component weight, but its inclusion as an intended exercise setting and how it reconciles with the first plate/3-pound chart setting are unknown**. Do not present this report as having settled the exact physical low end; ask for an actual handle/plate photograph or PowerBlock clarification. [S24][S24kg][CMP]

**Identification:** Product/manual title **Sport 24**; current product photos show gray powder-coated plates and colored bands, smaller rectangular frame, contoured TPR grip. Exact printed generation-specific model decal is **unknown**; older Sport 2.4 is mentioned separately in official accessory compatibility copy, so do not silently assume every older labeled unit has the same component masses. [S24][MS24][P100]

**Kg:** Official localized list is **1.4, 2.7, 4.1, 5.4, 6.8, 8.2, 9.5, 10.9 kg** (1.4–10.9), plus the unresolved 0.7 kg bare-handle claim. Manual explicitly gives 3–24 lb / 1.4–10.9 kg and color-coded selection. Distinct kg-native plates are **unknown**. [S24kg][MS24]

## Sport 50 (recent nonexpandable model)

**Retailer-listed range and sequence:** **10–50 lb**: **10, 15, 20, 25, 30, 35, 40, 45, 50**. Manufacturer lists Sport 50 as nonexpandable and still sells a replacement handle. Its current full weight schedule/bare-handle mass is **unknown** in the accessible manufacturer pages. [R3][X][S50H]

**Selection:** Manufacturer replacement-handle page confirms selector-pin adjustment. The retailer's nine-setting schedule implies 5 lb changes, but its bare-handle mass and exact number/mass of plate assemblies are **unknown** without assuming that 10 is the bare handle. Exact colors, adder presence, and lock design for each Sport 50 generation remain **unknown**. [S50H][R3]

**Material discrepancy:** Total Fitness USA's title says “5–50,” while its specification says “10–50” and enumerates nine values beginning at 10. Fitness Warehouse's Sport 50 listing instead claims **two 2.5 lb chrome weights per handle**, which would suggest a different/incorrectly copied micro-loading specification; this conflicts with the nine-step listing. These are **retailer specification claims, not independently confirmed manufacturer schedules**. Do not merge them into a fabricated 5–50-by-2.5 model. Keep Sport 50 unverified until the user's actual hardware/label is identified. [R3][R4]

**Identification:** Manufacturer calls the replacement **Sport 50 Handle** and lists a Sport 50 parts collection. Exact on-hardware model text and whether multiple historic Sport 50 configurations explain the conflicting retailer specs are **unknown**. It is not Sport EXP. [S50H][X][SX3]

**Kg:** Metric retailers sell Sport 50 and describe 2.2 kg steps, but exact metric SKU/calibration is **unknown**. The nine-setting lb list numerically converts to **4.5, 6.8, 9.1, 11.3, 13.6, 15.9, 18.1, 20.4, 22.7 kg**; this is a calculation, not a verified Sport 50 decal. A 5-pound handle, if independently confirmed, would additionally be 2.3 kg; it is **not confirmed here**. [R3][R8]

## Commercial Pro 50

**Advertised range/list:** **10–50 lb**: **10, 15, 20, 25, 30, 35, 40, 45, 50**. Nonexpandable; no micro weights. Manufacturer FAQ explicitly says **the handle is 5 lb**, although the advertised list starts at 10. [C50]

Consequently the manufacturer's own component description additionally supports a **5 lb bare-handle mass**, but the page does not explicitly advertise exercising with it. Intended handle-only use and why it is omitted from “Weight Range” are **unknown**. Distinguish the advertised nine-step list from potential handle-only use instead of losing this discrepancy. [C50]

**Selection:** Commercial-grade magnetic selector pin, 5-pound plate-step advertised increments, color-coded rails/chart; no adder/lock operation. Exact bare-handle-versus-first-rail recipe at the low end should be verified on the unit. [C50][MCOMM]

**Identification:** Current product title **Commercial Pro 50**, black urethane finish and contoured TPR grip; exact printed handle label is **unknown**. It does **not** share the residential Pro 50's micro-adjustable schedule. [C50][P50]

**Kg:** Official localized advertised list **4.5, 6.8, 9.1, 11.3, 13.6, 15.9, 18.1, 20.4, 22.7 kg**; the reported 5 lb handle corresponds to roughly 2.3 kg. A separate metric-native version is **unknown**. [C50kg][C50]

## Commercial Pro 100

**Range and full list:** **5–100 lb**: **5, 10, 15, 20, 25, 30, 35, 40, 45, 50, 55, 60, 65, 70, 75, 80, 85, 90, 95, 100**. Fully supplied 100-pound capacity; not expandable past 100. [C100]

**Selection:** Two interchangeable complete handles per dumbbell: **5 lb and 10 lb**, not adders. Choose the handle, insert it into the nested stack, refer to that handle's color-coded chart, and insert the magnetic tethered pin at the colored rail. With a given stack of 10-pound plate increments, the 5-pound handle produces 5/15/25/…/95, and the 10-pound handle produces 10/20/30/…/100; the progression is a derivation of the stated handles and full schedule. The rack stores the unused handles. [C100][MC100][MCOMM]

**Identification:** Product title **Commercial Pro 100**, supplied stand and two pairs of knurled handles; check that handles are separate 5/10-pound pieces rather than Pro 100 EXP's lower micro-weight tubes. Exact readable model text on every production-year handle is **unknown**. [C100][P100]

**Kg:** Manufacturer localized list is **2.3, 4.5, 6.8, 9.0, 11.3, 13.6, 15.9, 18.1, 20.4, 22.7, 24.9, 27.2, 29.5, 31.8, 34.0, 36.3, 38.6, 40.8, 43.1, 45.4 kg**; manual names the handles **2.3 and 4.5 kg**. Localized prose also rounds these to 2 and 5 kg. Distinct native-kg hardware is **unknown**. [C100kg][MC100]

## Commercial Pro 125 and Pro 175

**Advertised full lists:** [C125][C175]

- **Pro 125, 12.5–125 lb:** **12.5, 20, 27.5, 35, 42.5, 50, 57.5, 65, 72.5, 80, 87.5, 95, 102.5, 110, 120, 125**.
- **Pro 175, 12.5–175 lb:** **12.5, 20, 27.5, 35, 42.5, 50, 57.5, 65, 72.5, 80, 87.5, 95, 102.5, 110, 120, 125, 137.5, 145, 152.5, 160, 167.5, 175**.
- Pro 125 can take a **125–175 expansion kit**; Pro 175 cannot expand beyond 175. The advertised maximum capacity increases by 50 lb per dumbbell; the kit page also says it contains three 15 lb plates (45 lb), an unresolved component-total discrepancy. It is the only expandable current commercial family identified by the manufacturer's FAQ. [C125][C175][CK]

**Selection:** Two complete interchangeable handles weighing **12.5 and 20 lb**, no internal micro weights. Store unused handles on the included Pro Max stand; insert the selected handle into the nested plates and use the commercial magnetic pin/color-coded chart. [C125][C175][MCOMM]

**Exact recipe and discrepancy:** The manufacturer's high-resolution product photograph supplies actual handle charts: [C125img]

| Rail position | 12.5 lb handle's printed totals | 20 lb handle's printed totals |
|---|---|---|
| Handle only | 12.5 | 20 |
| 1 | 27.5 | 35 |
| 2 | 42.5 | 50 |
| 3 | 57.5 | 65 |
| 4 | 72.5 | 80 |
| 5 | 87.5 | 95 |
| 6 | 102.5 | 110 |
| 7 | **120.0** | **125** |
| 8, expansion | 137.5 | 145 |
| 9, expansion | 152.5 | 160 |
| 10, expansion | 167.5 | 175 |

The photographed handle decal says **POWERBLOCK / PRO COMMERCIAL 125/175**. Its 12.5-handle chart visibly prints **120.0**, matching the web list. However, the same selected plates plus handles differing by **7.5 lb** cannot produce **120 and 125** (only 5 lb apart). A consistent 15-pound plate scheme would instead give **117.5/125** at rail 7. **Whether 120 is a label error, a special rail/handle interaction, or another production variation is unknown.** Do not silently replace 120 with 117.5, and do not claim 120 is physically verified solely because the decal and page agree. Exact physical achievable mass at this anomalous setting requires manufacturer clarification or weighing the actual unit. [C125img][C125][C175]

Thus the lists above are **complete published nominal lists, not a fully reconciled mechanical proof**. The normal positions' recipes can use the table; mark rail 7/12.5-handle as unverified. “7.5 and 10 lb increments” in the web specification is also not a uniform progression: the published 120→125 jump is 5 lb and 125→137.5 is 12.5 lb. [C125][C175]

**Kg:** Localized Pro 175 page publishes coarse nominal values **6, 9, 12, 16, 19, 23, 26, 29, 33, 36, 40, 43, 47, 50, 54, 57, 62, 66, 69, 73, 76, 79 kg** (its range line says 5.6–79 kg). The first 16 entries correspond to the 125-pound advertised capacity. The photograph's actual paired lb/kg charts are more specific: [C175kg][C125img]

- 12.5 lb handle: **5.7, 12.5, 19.3, 26.1, 32.9, 39.7, 46.5, 54.4, 62.4, 69.2, 76.0 kg**, corresponding to the lower-handle totals in the table.
- 20 lb handle: **9.0, 15.9, 22.7, 29.5, 36.3, 43.1, 49.9, 56.7, 65.7, 72.6, 79.4 kg**, corresponding to the upper-handle totals.
- Distinct native-kg versions are **unknown**. The 54.4/56.7 pair inherits the unresolved 120/125 inconsistency; the coarse localized list is not a replacement for actual handle-chart instructions. [C175kg][C125img]

## Travel and Personal Trainer

**Travel:** A current **TravelBench** exists, but this is a bench, not a confirmed dumbbell model. No first-party Travel dumbbell product/manual was identified in the checked catalog/searches. Current sale status, achievable weights, handle mass, physical mechanism, kg version, and product labeling of a dumbbell called “Travel” are all **unknown**. Do not create a Travel dumbbell preset from the bench listing or travel-oriented marketing. [IM][TR]

**Personal Trainer:** PowerBlock's expansion collection lists **Personal Trainer Set** among nonexpandable models, and the Elite USA manual explicitly excludes it from Elite expansion compatibility. It does not appear in the checked current comparison lineup. A surviving first-party full weight list, handle/adder configuration, exact label, kg version and current sale status were **unknown**; therefore no guessed 5–50 or 2.5-step schedule is supplied. Secondary reviews describe a 5–50 model, but those are insufficient to settle its exact physical settings for this task. [X][MUSA][CMP]

## App implications and unresolved checks

1. **Store capacity stages, not just marketing model names.** Scheme-A models may share numeric arrays, but not expansion compatibility, locks, pin identity, or rail colors. Pro 100 has a different 40/60/80/100 staging scheme. [MEXP][MUSA][PX2][SX2][M100]
2. **Use exact entries rather than min/max/step.** Scheme A and Pro 100 have deliberate gaps; Commercial 125/175 has a published anomaly. [E][P100][C125][C175]
3. **Keep recipes optional.** For confirmed presets, an entry can store `weight`, `railOrdinal`/`railLabel`, `microWeightCount`, and optionally `handleWeight`; handle-only entries have no selected plates. This is a suggested data shape, not a need for a hardware simulation. Preserve more than one recipe only when useful (Pro 50 overlaps).
4. **Match instructions to what is actually printed.** For Elite EXP 27.5 lb, say “white rail / 30 label; one 2.5 lb micro weight installed,” not “pin at 25, add 2.5” unless the user's chart really marks the empty-handle 25 setting. Explain that printed full-adder totals already include the handle. [E][MEXP][M100]
5. **Treat kg as a display conversion unless the user supplies a metric-specific chart.** Do not round the underlying available weights to integer kilograms and thereby authorize unavailable loads. Locale-specific manufacturer prose demonstrably contains inconsistent conversions. [P50kg][P100kg][C100kg][C175kg]
6. **Require verification/custom entries for unresolved hardware.** Specifically Sport 50, Personal Trainer/Travel, Sport 24 handle-only 1.5, Commercial Pro 50 handle-only 5, the exact Pro 32 bare handle, and Commercial 125/175's lower-handle rail 7. These unknowns prevent claiming a universally exact physical inventory from web copy alone.

### Conversion method

Where explicitly labeled calculated, multiply lb by **0.45359237** and round to one decimal; this is not transcription of hardware decals. This exact conversion is defined by the international pound. [NIST] Published PowerBlock values sometimes truncate or round differently (e.g. 20 lb as 9.0 rather than 9.1); preserve chart labels separately from numerical display conversions. [Ekg][C100kg][C125img]

## Source register

All live pages retrieved 2026-10-07; undated unless stated. PowerBlock-hosted manuals are primary manufacturer sources. Retailers are specification listings with authorization status not independently established, explicitly weaker than first-party evidence.

### Manufacturer products, charts and expansions

- [E] **Elite EXP Weight Range Guide**, complete lb rail/micro-weight map and handle instructions: https://powerblock.com/pages/elite-exp-weight-range-guide
- [Ekg] **Elite EXP kg chart**, image version `1768940893`, visually read: https://powerblock.com/cdn/shop/files/elite-exp-kg-micro-weight-chart.png?v=1768940893&width=1600
- [EK] **Elite EXP localized product**, full lb-equivalent kg list: https://powerblock.com/en-de/products/elite-exp-adjustable-dumbbells (US base URL returned HTTP 404 during this check).
- [U] **Elite USA 90** product, selectable lb list, variants and Elite EXP incompatibility: https://powerblock.com/products/elite-usa-90-adjustable-dumbbells
- [P100] **Pro 100 EXP** product, full advertised lb list, adder specification, stage capacities, Hammer Strength alias: https://powerblock.com/products/pro-100-exp-adjustable-dumbbells
- [P100img] **Pro 100 EXP rail/handle photo**, version `1762986270`, visually read: https://powerblock.com/cdn/shop/files/Pro_100_EXP_Rails.jpg?v=1762986270&width=1800
- [P100kg] **Pro 100 EXP localized product**, including erroneous metric sequence: https://powerblock.com/en-de/products/pro-100-exp-adjustable-dumbbells
- [P50] **Pro 50**, explicit full lb list, 5 lb plates/handle, two 2.5 lb adders, nonexpandability: https://powerblock.com/products/pro-50-adjustable-dumbbells
- [P50kg] **Pro 50 localized product**: https://powerblock.com/en-de/products/pro-50-adjustable-dumbbells
- [P32] **Pro 32**: https://powerblock.com/products/pro-32-adjustable-dumbbells
- [P32kg] **Pro 32 localized product**: https://powerblock.com/en-de/products/pro-32-adjustable-dumbbells
- [S24] **Sport 24**, selectable lb list and 1.5 lb handle claim: https://powerblock.com/products/sport-24-adjustable-dumbbells
- [S24kg] **Sport 24 localized product**, kg list and 0.7 kg handle claim: https://powerblock.com/en-de/products/sport-24-adjustable-dumbbells
- [S50H] **Sport 50 replacement handle**: https://powerblock.com/products/sport-50
- [PX2] **Pro EXP Stage 2 50–70**, discontinuation year and compatibility: https://powerblock.com/products/pro-exp-stage-2-kit-50-70
- [PX3] **Pro EXP Stage 3 70–90**: https://powerblock.com/products/pro-exp-stage-3-kit-70-90
- [SX2] **Sport EXP Stage 2 50–70**, plate count/mass and rail numbers: https://powerblock.com/products/sport-exp-stage-2-kit-50-70
- [SX2kg] **Sport EXP Stage 2 localized copy**: https://powerblock.com/en-de/products/sport-exp-stage-2-kit-50-70
- [SX3] **Sport EXP Stage 3 70–90**, compatibility exclusions: https://powerblock.com/products/sport-exp-stage-3-kit-70-90
- [X] **Expansion collection**, discontinued/nonexpandable models: https://powerblock.com/collections/expansion-kits
- [CMP] **Current comparison chart**, explicit full selectable lists: https://powerblock.com/pages/compare-powerblock-adjustable-dumbbells
- [C32] **Commercial Pro 32**: https://powerblock.com/products/commercial-pro-32
- [C50] **Commercial Pro 50**, nine-entry list, 5 lb handle and no micro weights: https://powerblock.com/products/commercial-pro-50
- [C50kg] **Commercial Pro 50 localized list**: https://powerblock.com/en-de/products/commercial-pro-50
- [C100] **Commercial Pro 100**, interchangeable handles and full list: https://powerblock.com/products/commercial-pro-100-adjustable-dumbbells
- [C100kg] **Commercial Pro 100 localized list**: https://powerblock.com/en-de/products/commercial-pro-100-adjustable-dumbbells
- [C125] **Commercial Pro 125**, complete nominal lb list: https://powerblock.com/products/commercial-pro-125-lb-adjustable-dumbbell
- [C175] **Commercial Pro 175**, complete nominal lb list: https://powerblock.com/products/commercial-pro-175-lb-adjustable-dumbbell
- [C175kg] **Commercial Pro 175 localized list**: https://powerblock.com/en-de/products/commercial-pro-175-lb-adjustable-dumbbell
- [C125img] **Commercial 125/175 handle/rail charts**, photo version `1782161958`, visually read at 2000px; includes printed 120.0 anomaly: https://powerblock.com/cdn/shop/files/commercial-pro-125-knurled-adjustable-dumbells.jpg?v=1782161958&width=2000
- [CK] **Commercial 125–175 expansion**: https://powerblock.com/products/pro-125-175-expansion-kit
- [TR] **TravelBench**, not a dumbbell: https://powerblock.com/products/travel-bench

### Manufacturer manuals (older sources)

- [IM] Manufacturer's manual index: https://powerblock.com/pages/instruction-manuals
- [MEXP] **Elite EXP Owner's Manual, version 2, June 2025**: https://powerblock.com/cdn/shop/files/UK_Elite_EXP_Owner_s_Manual_Version_2_06.2025_3.pdf?v=7294129617768004003
- [MUSA] **Elite USA Owner's Manual**, revision date unknown; older Owatonna contact/version text: https://powerblock.com/cdn/shop/files/UK_Elite_USA_Manual_1.pdf?v=13537847407405009081
- [M100] **Pro 100 EXP Owner's Manual, version 2, June 2025**; sections “PowerBlock Dumbbells 101,” “Using the Pro 100 EXP Dumbbells,” and “Expand your Pro 100 EXP”: https://powerblock.com/cdn/shop/files/UK_Pro_100_EXP_Owner_s_Manual_Version_2_06.2025_3.pdf?v=14900325325075042089
- [MPRO] **Pro Series Owner's Manual, version 1, June 2025**; general adder-lock mechanics; contains mixed home/commercial warranty copy, so not used to infer a specific model's weight schedule: https://powerblock.com/cdn/shop/files/UK_Pro_Series_Dumbbells_Owner_s_Manual_2.pdf?v=10163355502905445949
- [MSPORT] **Sport Series manual**, revision date unknown; text extraction returned warranty text only, not a usable full mechanical/weight table: https://powerblock.com/cdn/shop/files/UK_Sport_Series_Dumbbells_Owner_s_Manual_1.pdf?v=4755830959497212956
- [MS24] **Sport 24 Owner's Manual**, revision date unknown: https://powerblock.com/cdn/shop/files/UK_Sport_24_Owner_s_Manual_1.pdf?v=5038989855702974857
- [MCOMM] **Pro Series Commercial manual**, revision date unknown; generic 5/10-handle directions, not specific evidence for the 125/175 handle masses: https://powerblock.com/cdn/shop/files/UK_Commercial_Pro_Series_Manual.pdf?v=4575186963193113620
- [MC100] **Commercial Pro 100 Owner's Manual, version 1, June 2026**; confirms 5 lb/2.3 kg and 10 lb/4.5 kg handles. Contains an erroneous home-use sentence despite commercial title/warranty; used only for mechanical selection: https://powerblock.com/cdn/shop/files/pro-100-commercial-manual.pdf?v=12018972684481834039

### Retailer specifications (not independently verified authorization; legacy evidence)

- [R1] **Dotmar, PowerBlock Pro EXP**, SKU 504-00114-01; explicit base lb sequence and Auto Lock: https://dotmarfitness.com/products/powerblock-pro-exp
- [R2] **Fitness Warehouse USA, Sport EXP 5–90**, full lb sequence and adders: https://fitnesswarehouseusa.com/product/sport-exp-set-5-90-lb/
- [R3] **Total Fitness USA, Sport 50**, title/body discrepancy and nine-setting list: https://tfusa.net/products/powerblock-sport-50-5-50lb-not-expandable
- [R4] **Fitness Warehouse USA, Sport 50**, conflicting micro-weight claim: https://fitnesswarehouseusa.com/product/sport-50-set/
- [R6] **Bodytrading, Pro EXP base**, regional listing: https://www.bodytrading.com/products/powerblock-pro-exp-set-5-50-pbproset1
- [R7] **Bodytrading, Sport EXP base**, regional listing: https://www.bodytrading.com/products/powerblock-sport-exp-set-5-50-pbspset1
- [R8] **Exagym, Sport 50**, metric retailer search result; full underlying mechanical details not independently confirmed: https://www.exagym.com.au/product/powerblock-sport-50/

### Unit standard

- [NIST] NIST Handbook 44, 2026 edition, Appendix C, General Tables of Units of Measurement; international avoirdupois pound = 0.45359237 kg: https://www.nist.gov/document/2026-nist-handbook-44-appendix-c
