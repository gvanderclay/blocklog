# Should Blocklog add Impeccable to its AI configuration?

**Short answer: partially adopt its UX review and copy guidance, not the whole installed system.** Adapt the **Cognitive Load Assessment**, **Nielsen heuristics**, and relevant **persona walkthroughs** from `critique.md`, plus the **`clarify.md` copy playbook**, into an explicitly invoked, Blocklog-specific review skill. Current Impeccable genuinely supports native iOS and Pi; rejecting it as web-only would be inaccurate. Its best incremental contribution here is structured usability reasoning, while its native implementation advice mostly repeats the existing guidance and its detector/live tooling does not apply to SwiftUI. This is a recommendation based on the comparison below, not a measured improvement in agent output. [I1][I2][I3][I4][B1][B2][B3]

## Date, versions, and method

Checked **2026-10-10**, approximately 09:46–10:00 UTC. All external evidence below is first-party repository source or GitHub API data; issue descriptions are first-party tracker reports, **not independently reproduced bugs**.

- Impeccable: commit **`d631a8827f99414d2b6daba4ef08b7f8701751d7`**, package/skill **4.5.2**, bundled engine pin **0.1.14**. `git -C /tmp/impeccable-evaluation-src rev-parse HEAD` returned that commit; `package.json` reports `4.5.2`; `ENGINE_VERSION` and the compiled plugin's `scripts/VERSION` contain `0.1.14`. Latest release API returned `skill-v4.5.2`, published `2026-10-09T15:30:51Z`. [I5][I6]
- Blocklog: **`a0a5ba90b8397b92f091cd5b5bd994246be76d59`**. Its working tree already had concurrent app/test/design changes; this research did not modify them. Citations to unchanged tracked files mean that commit. `docs/design.md` was read from the working tree; its relevant general design rules also exist at that commit. Snapshot SHA-256: `3c9afd7c122641ffe273ed76c85e9a0a93048aa5f6b124e6f583feb358dfaad5`. Commands: `git rev-parse HEAD`, `git status --short`, `git diff -- docs/design.md`, `shasum -a 256 docs/design.md`.
- Apple's local exported skills: Xcode **27.0**, build **27A266a**, from `xcodebuild -version`; exports are gitignored, not commit-pinned. `swiftui-specialist/SKILL.md` SHA-256 `1222786ea81aabd7bf18052d7fe5e688687c63059c6cfbcb1342d1d1b6c08093`; `swiftui-whats-new-27/SKILL.md` SHA-256 `2b0fea2d9fe5215cb2f6335a1c2bf98aff613e7d83c4cff57aa529ded9b040e8`, from `shasum -a 256 .agents/skills/apple/*/SKILL.md`. These identify the inspected local artifacts; their stated Apple authorship was not separately authenticated against a remote Apple publication. [B3]
- Pi: locally installed **1.0.4**, verified in the installed package's `package.json:3`; consulted its complete `docs/skills.md`, `docs/settings.md`, and `docs/packages.md`. [P1]
- Local discovery: `rg -n -i 'impeccable' docs .scratch AGENTS.md` and `git log --all --oneline --grep=impeccable` returned no matches. This does not establish that no past session ever discussed it.

## What Impeccable now is

At this version it is **one Agent Skill with 24 command playbooks**, not 24 independent skills. Its umbrella `SKILL.md` routes requests to Markdown references for planning, review, refinement, implementation, and browser iteration. The README lists `shape`, `critique`, `audit`, `polish`, `distill`, `harden`, `clarify`, `adapt`, `animate`, and other commands, and advertises **59 deterministic detector rules**. These are the project's advertised inventory; this research did not benchmark or independently count detector behavior. [I1][I2]

It is more than a static prompt collection. Each installed skill carries launchers and supporting references/scripts; invoking the skill ordinarily runs `impeccable context`. A self-contained engine is present beside the launcher or downloaded once to `~/.impeccable/bin/`. Node is required for the `npx` installer, not for the engine's normal execution. The Unix launcher checks a downloaded engine against its SHA-256 sidecar and refuses an unverifiable download. Image-generation and browser features are additional capabilities, not prerequisites for borrowing a Markdown checklist. [I1][I2][I7]

Whole-system adoption also brings its own project-state convention: `init` writes **`PRODUCT.md`**, `document` generates root **`DESIGN.md`**, and workflows maintain `.impeccable/` configuration, surface briefs, review reports, screenshots, and caches. Automatic detector hooks are provided for Claude Code, Cursor, Codex, GitHub Copilot, and Grok Build—not Pi in the inspected provider definition. Pi's entry has neither a hook emitter nor a native agent format declaration; do not assume installing the skill creates Pi-native reviewer delegates. [I1][I8]

## Web-specific versus native-relevant

### There is real native support

The dedicated iOS reference says: **“Default to the platform's components; depart only for a reason the user would thank you for.”** It specifies SF Symbols, semantic colors, system navigation, 44-by-44-point targets, Dynamic Type, SF Pro for UI text, grouped lists, system transitions, Reduce Motion, and **Simulator screenshots, never browser screenshots**. `audit.native.md` expressly audits SwiftUI/UIKit source without browser tooling, and `adapt.native.md` supplies a separate native adaptation path. These are concrete native instructions, not merely generic design slogans. [I3][I9][I10]

The skill's **Operate** mode places “Scanability, consistency, native expectations, and the real usage scene” above expression. Its extended guidance says **“Familiarity is often a feature here”** and permits system fonts and standard affordances. That matters: the README's blanket anti-pattern language against system fonts is **not** the complete policy for a correctly routed native product screen. [I2][I11]

`clarify.md` adds largely platform-independent advice: review the whole interaction, preserve domain terminology, explain what failed and how to recover, distinguish first-use/filtered/error empty states, and keep action labels specific. `critique.md` adds a systematic cognitive-load checklist, ten usability heuristics, emotional-journey review, and persona walkthroughs. These are the most transferable pieces for Blocklog. [I4][I12]

### The tooling and much implementation detail remain web-centric

The routing reference explicitly says **“`live`, `generate`, and the bundled `impeccable detect` are web-only.”** The build workflow says the detector reads HTML/CSS and **“has no verdict on native code.”** Consequently the 59-rule detector, browser overlay, URL scanning, and live variant editing do not provide a SwiftUI linting or simulator-inspection service. [I13][I14]

Examples of non-transferable implementation advice include CSS Grid/Flexbox and `clamp()` in `adapt.md`, React memoization/React DevTools Profiler in `optimize.md`, CSS transitions/Web Animations/View Transitions in `animate.md`, and HTML injection for Vite/React development servers in `live-setup.md`. Native-aware routing avoids some of this: `animate.md` explicitly directs native platforms to their platform motion reference instead of the web tooling. [I15][I16][I17][I18]

The fit is therefore **mixed, not “web-only” and not “platform-neutral.”** There is no useful supported numerical percentage of native content: two commands have explicitly separate native variants, iOS has a dedicated platform reference, several other playbooks are transferable, but the most distinctive automated tools remain web-specific. This qualitative assessment follows the command table and routing/source examples, not marketing assumptions. [I2][I3][I13]

## Installation into Pi or `.agents/skills`

**Supported whole install, if desired later:** from the project root, the upstream documented installer options imply:

```sh
npx impeccable@4.5.2 install --providers=pi --scope=project --no-hooks
```

The version-qualified `npx` form pins the npm installer version; the Pi provider maps to `.pi`, and global Pi installs map to `~/.pi/agent/skills`. Upstream also documents copying `dist/pi/.pi` from a compiled distribution or linking provider output from a Git submodule. The inspected source checkout does not contain `dist/`, so do not treat that manual copy command as usable directly against every raw checkout. None of these installation commands was executed during this evaluation. [I1][I8][I19]

Pi 1.0.4 itself discovers portable directories containing `SKILL.md`, including recursively under project `.agents/skills/`; it documents invocation as **`/skill:impeccable critique …`**, with following arguments passed as the request. Upstream's `/impeccable …` spelling should not be assumed to be Pi's native command syntax without a harness-specific alias. A compiled skill folder can therefore live under `.agents/skills/impeccable/`; keep its references and launcher together, and do not install duplicate copies under both skill roots. Pi warns on name collisions. [P1]

**Individual pieces:** the current distribution is one umbrella skill. `pin clarify` or `pin audit` makes shortcuts; it is not evidence of an independently maintained, dependency-free install of just that playbook. For a genuinely small adoption, copy/adapt the selected reference sections into a locally owned `SKILL.md` plus reference files. Preserve Apache license/attribution and mark modifications; retain relevant notice material if copied. This is a local derivative, not an upstream-supported partial installer. [I1][I2][I20][I21]

**Upkeep:** an ordinary upstream install uses `npx impeccable update`; a submodule uses Git updates followed by `link`. A local adaptation instead needs an upstream commit/version recorded and intentional diff reviews of just the borrowed files. Recommend pinning the adaptation and refreshing only when there is a concrete improvement to borrow, rather than adding automatic updates or a new submodule solely for two Markdown resources. This upkeep recommendation reflects the small scope and the whole system's documented artifact/update machinery. [I1][I2]

## Incremental value, duplication, and conflicts

### What Blocklog already has

Blocklog's design spec already covers color, text hierarchy, animation, haptics, sound, native components, accessible labels, targets, Dynamic Type, and a phone feel-check checklist. Apple exports provide implementation-level structure, data flow, identity, observation, localization, animation, and iOS 27 API guidance. Checkpoint-only `swiftui-pro` already reviews Human Interface Guidelines, adaptivity, accessibility, performance, localization, navigation, and system styling. Thus another native technical audit largely duplicates existing checks. [B1][B2][B3][I3][I9]

The incremental gap is a **repeatable user-task critique**, rather than another palette/component guide: hierarchy and working-memory burden across a flow, error recovery wording, recognition versus recall, unnecessary decisions, and distracted/first-time user walkthroughs. Impeccable makes those evaluation dimensions explicit in one place; the inspected local skill entry points/design spec do not provide an equivalent scored persona/heuristic method. This is a comparison of the inspected guidance, not a claim that existing reviewers cannot already reason about usability. [I4][I12][B1][B2][B3]

### Concrete constraints that must win

1. **Design authority:** `AGENTS.md` says architecture rules override skills; rule 14 names `docs/design.md`. Impeccable defaults to root `DESIGN.md` and its own `PRODUCT.md`/surface records. Do not generate a competing source of truth or infer that the absence of root `DESIGN.md` permits a redesign. Upstream does say missing `DESIGN.md` alone is not greenfield and “the brief wins,” which mitigates—but does not remove—the integration burden. [B1][I2]
2. **Visual/motion rules:** Blocklog forbids custom fonts/theme/decorative backgrounds, mandates system text styles/default spring animation, and deliberately uses one-shot SF Symbol bounces. Impeccable's README says avoid system fonts and bounce/elastic easing, while its native/Operate guidance permits system fonts and native transitions. Applying the broad marketing bans indiscriminately would break the app's rules; native/Operate routing and the explicit Blocklog brief are essential. Do not “fix” the approved bounce or add accent colors, custom display type, timing curves, or decorative effects from enhancement commands. [B2:7–35][I1][I3][I11][I17]
3. **Accessibility identifiers:** Impeccable's native audit checks labels, traversal, scaling, targets, motion, and contrast; that is not Blocklog's automation contract. Rule 13 separately requires dot-separated `accessibilityIdentifier`s and specifies the `.searchable` exception. Borrowed guidance must retain that requirement, not equate accessible labels with test identifiers. [B1:58–60][I9]
4. **Product-specific exceptions:** `clarify` prefers undo over confirmation when safe, whereas Blocklog names the destructive actions that must confirm. Those are useful review questions, not authority to reverse settled decisions. Its copy guidance should also use existing `CONTEXT.md`, not invent a second glossary. [I12:781–805][I4][B2:78–81][B1:56]
5. **Architecture/workflow:** generic `harden`, `extract`, or `optimize` changes cannot move rules into views, bypass save-and-rollback logic, or add wrappers/packages outside Blocklog's rules. The full critique protocol mandates two isolated assessments plus detector/browser work; the detector requirement has no native exception inside `critique.md`, despite native skipping in routing/new-work. That is a source-level inconsistency to remove in an adaptation, not a reason to run an HTML detector on Swift files. Its additional persistence and command handoffs also overlap the ticket/reviewer/blind-tester flow. [B1:44–61,64–73][I12:1–18,101–143][I13][I14]

## Maturity and limits of the evidence

GitHub repository API at the check time reported **79,175 stars**, **4,708 forks**, **69 open issues** (GitHub's repository count includes pull requests), creation **2025-11-16**, and `archived: false`. These are mutable popularity/activity signals, not evidence of effectiveness on native iOS. Command: `gh api repos/pbakaus/impeccable`; selected output: `stargazers_count=79175`, `forks_count=4708`, `open_issues_count=69`, `pushed_at=2026-10-09T18:44:27Z`. [G1]

Recent commit API output showed the 4.5.2 release on October 9, two CLI recognition/version fixes that day, generated provider-output syncs, and October 8/9 work on HTML decision sketches and Operate/Read handling. This is actively maintained, not a dormant prompt pack. The platform references are explicitly credited to a third-party HIG/Material distillation in `NOTICE.md`; they are **not Apple's own SwiftUI SDK documentation**, so they should not supersede the existing Apple exports. [G2][I21][B3]

Recent open issue **#1002** reports Windows-launcher concurrency and live-browser state/scroll-loop bugs; **#1009** requests Persian/RTL coverage and alleges Latin-first typography pitfalls. These are unverified user reports, mostly outside Blocklog's native scope, but illustrate ongoing tooling and coverage refinement. The API also shows recently merged fixes #999/#1000. No inference is made that these issues make the selected Markdown guidance unreliable. [G3][G4][G2]

The repository is **Apache-2.0**, copyright Paul Bakaus; section 4 requires license delivery, marking modifications, retaining applicable notices, and applicable NOTICE attribution when redistributing derivatives. That permits a locally adapted skill with those obligations. This is a source reading, not legal advice. [I20][I21]

**Unknown:** actual improvement in Blocklog agent-produced UI/UX, native false-positive rate, extra token/time cost, and whether the entire installed skill's delegates integrate smoothly with this project's Pi extensions. No installation, engine execution, simulator flow, or controlled before/after ticket trial was performed. The skill discovery contract and native/web boundaries were checked from source, not exercised. [P1][I8][I13]

## Source index

All `I` links are pinned to Impeccable commit `d631a8827f99414d2b6daba4ef08b7f8701751d7`, checked October 10, 2026. GitHub APIs/issues are dated snapshots rather than immutable counts.

- **[I1]** [README.md](https://github.com/pbakaus/impeccable/blob/d631a8827f99414d2b6daba4ef08b7f8701751d7/README.md), especially lines 3–16, 20–67, 83–139, 230–234, 354–440, 451–510.
- **[I2]** [skill/SKILL.src.md](https://github.com/pbakaus/impeccable/blob/d631a8827f99414d2b6daba4ef08b7f8701751d7/skill/SKILL.src.md).
- **[I3]** [skill/reference/ios.md](https://github.com/pbakaus/impeccable/blob/d631a8827f99414d2b6daba4ef08b7f8701751d7/skill/reference/ios.md).
- **[I4]** [skill/reference/clarify.md](https://github.com/pbakaus/impeccable/blob/d631a8827f99414d2b6daba4ef08b7f8701751d7/skill/reference/clarify.md).
- **[I5]** [package.json](https://github.com/pbakaus/impeccable/blob/d631a8827f99414d2b6daba4ef08b7f8701751d7/package.json), [ENGINE_VERSION](https://github.com/pbakaus/impeccable/blob/d631a8827f99414d2b6daba4ef08b7f8701751d7/ENGINE_VERSION), and compiled [scripts/VERSION](https://github.com/pbakaus/impeccable/blob/d631a8827f99414d2b6daba4ef08b7f8701751d7/plugin/skills/impeccable/scripts/VERSION).
- **[I6]** [Latest release API](https://api.github.com/repos/pbakaus/impeccable/releases/latest), command and output recorded above.
- **[I7]** [skill/scripts/impeccable](https://github.com/pbakaus/impeccable/blob/d631a8827f99414d2b6daba4ef08b7f8701751d7/skill/scripts/impeccable), lines 77–205.
- **[I8]** [scripts/lib/transformers/providers.js](https://github.com/pbakaus/impeccable/blob/d631a8827f99414d2b6daba4ef08b7f8701751d7/scripts/lib/transformers/providers.js), especially Pi entry lines 120–126.
- **[I9]** [skill/reference/audit.native.md](https://github.com/pbakaus/impeccable/blob/d631a8827f99414d2b6daba4ef08b7f8701751d7/skill/reference/audit.native.md).
- **[I10]** [skill/reference/adapt.native.md](https://github.com/pbakaus/impeccable/blob/d631a8827f99414d2b6daba4ef08b7f8701751d7/skill/reference/adapt.native.md), native variant linked by the inspected command table.
- **[I11]** [skill/reference/operate.md](https://github.com/pbakaus/impeccable/blob/d631a8827f99414d2b6daba4ef08b7f8701751d7/skill/reference/operate.md).
- **[I12]** [skill/reference/critique.md](https://github.com/pbakaus/impeccable/blob/d631a8827f99414d2b6daba4ef08b7f8701751d7/skill/reference/critique.md), especially assessment requirements, Cognitive Load Assessment, Heuristics Scoring Guide, and Persona-Based Design Testing.
- **[I13]** [skill/reference/routing.md](https://github.com/pbakaus/impeccable/blob/d631a8827f99414d2b6daba4ef08b7f8701751d7/skill/reference/routing.md), lines 19–22.
- **[I14]** [skill/reference/new-work.md](https://github.com/pbakaus/impeccable/blob/d631a8827f99414d2b6daba4ef08b7f8701751d7/skill/reference/new-work.md), lines 140–146; engine also skips native fallback in [context_cli.rs:209–220](https://github.com/pbakaus/impeccable/blob/d631a8827f99414d2b6daba4ef08b7f8701751d7/crates/context/src/context_cli.rs#L209-L220).
- **[I15]** [skill/reference/adapt.md](https://github.com/pbakaus/impeccable/blob/d631a8827f99414d2b6daba4ef08b7f8701751d7/skill/reference/adapt.md), lines 140–142, 213.
- **[I16]** [skill/reference/optimize.md](https://github.com/pbakaus/impeccable/blob/d631a8827f99414d2b6daba4ef08b7f8701751d7/skill/reference/optimize.md), lines 153–161.
- **[I17]** [skill/reference/animate.md](https://github.com/pbakaus/impeccable/blob/d631a8827f99414d2b6daba4ef08b7f8701751d7/skill/reference/animate.md).
- **[I18]** [skill/reference/live-setup.md](https://github.com/pbakaus/impeccable/blob/d631a8827f99414d2b6daba4ef08b7f8701751d7/skill/reference/live-setup.md), lines 17–45.
- **[I19]** [crates/skills/src/providers.rs](https://github.com/pbakaus/impeccable/blob/d631a8827f99414d2b6daba4ef08b7f8701751d7/crates/skills/src/providers.rs), lines 11–69 and 121–128.
- **[I20]** [LICENSE](https://github.com/pbakaus/impeccable/blob/d631a8827f99414d2b6daba4ef08b7f8701751d7/LICENSE), sections 2 and 4 and copyright footer.
- **[I21]** [NOTICE.md](https://github.com/pbakaus/impeccable/blob/d631a8827f99414d2b6daba4ef08b7f8701751d7/NOTICE.md).
- **[B1]** Blocklog `AGENTS.md:16–17,42–61,64–86` at `a0a5ba90b8397b92f091cd5b5bd994246be76d59`.
- **[B2]** Blocklog `docs/design.md:3–37,39–86,115–192`, working-tree snapshot identified above; cited general rules unchanged from `a0a5ba90b8397b92f091cd5b5bd994246be76d59`.
- **[B3]** Blocklog `.agents/skills/swiftui-pro/SKILL.md:1–38` and `references/design.md:3–40` at `a0a5ba90b8397b92f091cd5b5bd994246be76d59`; `.agents/skills/apple/swiftui-specialist/SKILL.md:1–28` and `swiftui-whats-new-27/SKILL.md:1–29`, local Xcode exports identified above; `justfile:37–47` at the same commit documents export/provisioning.
- **[P1]** Installed Pi 1.0.4 primary docs under `/Users/gvanderclay/workspace/dotfiles/pi/.pi/agent/install/releases/1.0.4/node_modules/@earendil-works/pi-coding-agent/`: `docs/skills.md` sections “Understand how skills load,” “Add it to Pi,” and “Write portable frontmatter”; `docs/settings.md` section “Resources”; `docs/packages.md` sections “Choose a source” and “Select package resources”; `package.json:3` reports `1.0.4`. These installed-version references avoid assuming current remote Pi docs match this harness.
- **[G1]** [Repository API](https://api.github.com/repos/pbakaus/impeccable), `gh api repos/pbakaus/impeccable`, October 10 snapshot/output recorded above.
- **[G2]** [Recent commits API](https://api.github.com/repos/pbakaus/impeccable/commits?per_page=8), `gh api 'repos/pbakaus/impeccable/commits?per_page=8'`; release commit `d631a882…` at `2026-10-09T04:19:38Z`, fixes `ab3a5e28…` and `18e75111…`, HTML decision sketch `98703c42…`, and Operate/Read change `158618e6…`.
- **[G3]** [Issue #1002](https://github.com/pbakaus/impeccable/issues/1002), open at check time, created October 9, 2026; body read through `gh api repos/pbakaus/impeccable/issues/1002`.
- **[G4]** [Issue #1009](https://github.com/pbakaus/impeccable/issues/1009), open at check time, created October 9, 2026; body read through `gh api repos/pbakaus/impeccable/issues/1009`.

## Recommendation

**Adopt specific pieces: an adapted critique checklist and the `clarify` playbook; skip whole-system installation.** The critique adaptation should keep the cognitive-load questions, Nielsen heuristics as qualitative prompts rather than a shipping score, and first-time/distracted/accessibility persona walkthroughs grounded in real Blocklog use. The copy adaptation should keep terminology, outcome, recovery, and localization checks. Remove browser/detector/persistence requirements and mandatory `polish` handoffs; replace web zoom checks with Dynamic Type/VoiceOver, and make the review findings-only unless a ticket authorizes changes. Invoke it explicitly at checkpoint or UX-focused ticket review, alongside—not instead of—`swiftui-pro` and blind testing. These are proposed future configuration changes; this report installs nothing. [I4][I12][B1][B2][P1]

The reasons are: **(1)** this adds a concrete usability/copy method beyond the current implementation/design rules; **(2)** native technical guidance mostly duplicates what Blocklog already has and the flagship automation is web-only; **(3)** a small pinned adaptation avoids competing design documents, broad automatic routing, and workflow churn while preserving the app's deliberate native design and accessibility contracts. A whole install is technically possible, but its additional weight is not justified by the demonstrated incremental value for this project. [I2][I3][I8][I13][B1][B2][B3]

