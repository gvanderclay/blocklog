# Upstream

- Source: https://github.com/pbakaus/impeccable, files `skill/reference/critique.md` and `skill/reference/clarify.md`
- Version: 4.5.2, commit d631a8827f99414d2b6daba4ef08b7f8701751d7 (2026-10-09)
- License: Apache-2.0, copied to `LICENSE` from the repository root. Upstream's `NOTICE.md` covers only its iOS and Android platform references, which this skill does not use; `NOTICE.md` here records the adaptation.
- Why only these parts: `docs/research/impeccable-evaluation.md`, Recommendation.

Local changes to the adapted guidance (`LICENSE` is a verbatim copy; `SKILL.md` is rewritten):

- `SKILL.md` keeps, rewritten: the cognitive-load checklist, Nielsen's ten heuristics and the P0–P3 severities from `critique.md`; the first-timer, distracted mobile and accessibility personas; and the copy checks from `clarify.md`.
- Removed: Assessment B (the `impeccable detect` detector and browser overlay), the two-sub-agent requirement and degraded banner, snapshot persistence and trends under `.impeccable/`, the ignore list, `PRODUCT.md`/`DESIGN.md` context, the design-specificity verdict, the emotional-journey section, the power-user and stress-tester personas, and every handoff to other Impeccable commands, including `polish`.
- Heuristics are qualitative prompts with no 0–4 scores or totals.
- Personas are rewritten for Blocklog: the distracted user is a lifter mid-workout; the accessibility user checks VoiceOver and Dynamic Type instead of keyboard navigation and browser zoom.
- The critique is findings-only, and `AGENTS.md`, `docs/design.md` and `CONTEXT.md` win: a conflicting finding (system fonts, bounce effects, confirmations on destructive actions) becomes a question for the user.
- The copy checks drop web items (alt text, link text, 200% zoom, placeholder labels) and use `CONTEXT.md` as the glossary.

To refresh: diff the two upstream files between the pinned commit and the new one, and carry over only changes that fit the list above.
