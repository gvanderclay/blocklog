---
name: ux-critique
description: Findings-only usability and copy critique of Blocklog screens and flows, walking them as a first-time, a distracted mid-workout and a VoiceOver user, checking cognitive load, Nielsen's heuristics and UI text. Use for a checkpoint design review, a UX-focused ticket such as the polish pass, or when asked to critique, review the UX of, or find what is confusing about a screen or flow.
license: Apache-2.0
metadata:
  upstream: Impeccable 4.5.2 by Paul Bakaus, adapted; see UPSTREAM.md
---

# UX critique

Critique how a Blocklog flow feels to use: what the user must notice, remember, decide and read at each step. Implementation quality is another review's job (`swiftui-pro`, code-review), and whether a flow works is the blind tester's.

## Ground rules

- **Findings only.** Change no file. A ticket that authorizes fixes acts on the findings afterwards; this skill does not.
- **The project's documents win.** `AGENTS.md`, `docs/design.md` and `CONTEXT.md` are settled decisions, and the ticket under review wins for its own screen. When a finding would break one of them, report it under "Questions for the user", naming the rule and its `path:line`, not as a fix. Known cases: the app uses system fonts, and only the colors and type sizes `docs/design.md` allows; it plays one-shot SF Symbol bounces on purpose; it confirms the destructive actions `docs/design.md` lists under Small touches instead of offering undo; it adds no decoration or custom component styles.
- **Use the glossary's words.** Judge and suggest UI text with the terms in `CONTEXT.md`. Propose a new term only as a question, because a new term changes `CONTEXT.md` too.
- **Evidence for every finding.** Cite the view's `path:line`, the on-screen text or the accessibility label. A finding you could not check against the source or the running app is marked "unverified".

## Steps

1. **Fix the scope.** Name the flows under review as user goals ("log a set and rest", "finish an AMRAP early"), from the ticket or the request. Done when each flow has a start screen and an end state.
2. **Read the sources.** Read `docs/design.md`, the parts of `CONTEXT.md` the flows touch, the ticket, and every view in each flow (`App/Views`), following navigation, sheets, dialogs and alerts to their ends. Done when you can list every screen, control and string a user meets in each flow.
3. **Look at the running app when you can.** Read screens through the accessibility tree (a device or simulator tool that dumps it), not a headless simulator screenshot, which can be stale or blank. Without such a tool, critique from source and say so in the report.
4. **Walk each flow as each persona** (below), step by step, and note where the persona stalls, misreads, mis-taps or loses work. Done when every flow has been walked by all three personas.
5. **Run the checklists**: cognitive load, the heuristics and the copy checks below, against every screen in scope.
6. **Write the report** in the format below.

## Personas

Walk the primary path as each one and report what broke for them, naming the exact control or string. Skip generic persona prose.

- **First-timer**: has never used Blocklog or a PowerBlock workout logger. Takes every label literally and hesitates at anything unexplained. Asks: is the first action obvious within five seconds? Does every icon-only button make sense? Is a domain term (AMRAP, progression, set type letters W, D, F) explained where it first appears? After each action, is it clear it worked and what comes next?
- **Distracted lifter**: mid-workout, sweaty, one-handed, the phone on a bench or the floor, glancing between sets and interrupted by rest timers, calls and app switches. Asks: are the frequent actions within thumb reach and at least 44 × 44 points? Can a mis-tap be undone or is it confirmed? Does leaving and returning (backgrounding, locking, relaunch) keep every entry and the clock? Is the key number readable at arm's length? Does any step need typing where a tap would do?
- **VoiceOver user**: navigates by swipe and double-tap, at times with the largest accessibility text size. Asks: does every control read as a natural label with its value and units ("Weight, 35 pounds")? Is the swipe order the visual order? Are state changes (set done, timer ended, time up, saved) announced or otherwise findable? Does any meaning rest on color, position or an animation alone? At the largest text size, does anything truncate, overlap or push a primary action off screen? Do timed steps leave enough time, or offer pause?

## Cognitive load

For each screen and decision point, check:

- **Single focus**: the primary task is clear and nothing competes with it.
- **Hierarchy**: the most important element is obvious at a glance; one prominent action per screen (`docs/design.md` Principles).
- **Chunking and grouping**: related items sit together, in groups of about four or fewer.
- **Choices**: about four or fewer visible options at a decision point; more belong in a menu or a later step.
- **Working memory**: nothing must be remembered from an earlier screen to act on this one; needed context is repeated where it is used.
- **Progressive disclosure**: rare options stay out of the way until needed.
- **Consistency**: the same action looks and behaves the same on every screen (Finish, Discard, Cancel, − and +, swipe actions).
- **Context switches**: one decision never needs a trip to another screen and back.

Report each failed check with the screen and the elements involved.

## Heuristics

Use Nielsen's heuristics as prompts for finding problems. Give no scores: a number per heuristic invites false precision on a small app.

1. **System status**: every tap answers at once; timers, progress and saved state are visible; the user always knows which workout, exercise and set they are on.
2. **Real-world match**: words a lifter uses, in the order a workout happens.
3. **Control and freedom**: a clear way out of every sheet, dialog and player; a mistake is quick to undo or redo.
4. **Consistency**: platform conventions and the app's own patterns hold everywhere.
5. **Error prevention**: invalid states can't be entered (weights only from the PowerBlock table, disabled steppers at their limits); destructive actions confirm as `docs/design.md` lists.
6. **Recognition over recall**: previous numbers, targets and next steps are shown, not remembered.
7. **Efficiency**: the frequent path (log a set, start a routine) takes the fewest taps; accelerators (Previous copy, keyboard Done) don't complicate the basic path.
8. **Minimalism**: every element on screen earns its place; nothing decorative.
9. **Error recovery**: an error message says what failed, why when known, and how to recover, and keeps the user's input.
10. **Help**: help sits in context at the point of confusion: footnotes, empty states, labels.

## Copy

Read text along the whole flow, not string by string.

- Each state says one fact the user needs now, then the next action. Say each idea once: a message under a title that already explains the state adds something new or goes.
- A button names its outcome with a verb and object ("Delete Routine", "Save What I Did") when the outcome isn't already obvious; plain Save, Cancel and Done are fine where their effect is clear. A consequential confirmation never uses Yes, No or OK, and a destructive one names the object and the consequence.
- Errors answer what failed, why when known, and how to recover, without blame, internal codes or a promised cause the app can't know.
- Empty states tell first use apart from no search results, and offer the next useful action.
- Routine success is brief; a success message mentions what comes next only when it changes what the user does.
- Terms match `CONTEXT.md`, with one word per concept and consistent capitalization.
- Messages are whole translatable sentences, not concatenated fragments; numbers and names can grow (long exercise names, pluralization, large text) without breaking the layout.
- Accessibility labels match the visible label and say the outcome; punctuation, color or an icon never carries a message alone.

## Report

1. **Overall**: two or three sentences: what works, what doesn't, and the single biggest opportunity.
2. **What works**: two or three specific strengths, with why they work, so later changes keep them.
3. **Findings**, most severe first. For each: severity, the flow and screen, what the user meets, which persona, check or heuristic it fails, why it matters to the user, a concrete suggestion, and the evidence (`path:line`, string or label).
   - P0: stops the user finishing the task or loses data.
   - P1: causes real confusion or a likely mistake.
   - P2: an annoyance with an easy workaround.
   - P3: polish.
4. **Questions for the user**: every finding that conflicts with `AGENTS.md`, `docs/design.md`, `CONTEXT.md` or the ticket, each naming the rule it would change, plus any open design intent the findings raised. Offer two or three concrete options for each, and recommend one.
5. **Not checked**: flows, personas or states you couldn't verify, and whether the critique used the running app or source only.
