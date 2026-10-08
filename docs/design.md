# Blocklog design rules

Every UI ticket follows these rules, and the checkpoint design review checks each screen against them. Each rule says what a screen must do; the feature ticket that builds the screen implements it. Where a ticket gives more detail, the ticket wins for that screen.

## Principles

- Native and calm: stock `NavigationStack`, `TabView`, `List`, `Form`, sheets, `fullScreenCover`, swipe actions, context menus and `Menu`. No custom component styles, fonts or theme.
- Content first. No decoration for its own sake: no gradients, card shadows, custom backgrounds or ornamental symbols in screens.
- Fast: every tap answers within a frame. A tap changes the state immediately and animates from there; nothing waits on a spinner except import and export.
- Toolbar buttons use semantic placements (`.confirmationAction`, `.cancellationAction`, `.primaryAction`), so the system styles them. A screen has at most one prominent button.

## Color

- Accent: **Amber**, `AccentColor` in `App/Resources/Assets.xcassets`: `#B45309` in light mode, `#E8710A` in dark mode. Views get it through the default tint; never hard-code `.orange` or a hex value in a view.
  - Why amber: it nods to PowerBlock's yellow-and-black branding and reads as warm and energetic, while staying clearly apart from the green of completed sets, the red of destructive actions and the default system blue.
  - Contrast (WCAG): light `#B45309` is 5.0:1 on white and 4.5:1 on the grouped background, and white text on it is 5.0:1. Dark `#E8710A` is 5.5:1 on the dark cell background (`#1C1C1E`) and 6.8:1 on black, and white text on it is 3.1:1, which passes only for large text (at least 18 pt regular or 14 pt bold). So white text on the accent, such as a prominent button's label, uses `.headline` (17 pt semibold) or a larger text style, never a smaller one.
- Completed sets: the row background is `Color.green.opacity(0.15)` (system green, so it adapts to dark mode), and the check-off symbol is `checkmark.circle.fill` in `.green`. Unchecked sets use `circle` in `.secondary` on the normal row background.
- The accent marks what the user can act on, plus one highlight: a weight pre-filled by progression shows in the accent until the user changes it or checks off the set (ticket 19).
- Everything else uses semantic styles: `.primary`, `.secondary` and `.tertiary` for text; system grouped backgrounds; `role: .destructive` for red. No other custom colors in views. The PowerBlock diagram's rail bands are the one exception, because they copy the physical block (ticket 14).

## Typography

- System text styles only (`.body`, `.headline`, `.title2` …), never fixed point sizes, so Dynamic Type works everywhere.
- Numbers the user watches or edits (weights, reps, durations, elapsed time, the rest countdown, summary stats) use `.fontDesign(.rounded)` with `.monospacedDigit()`, so they don't jitter. In set rows they keep the row's text style; the rest countdown uses `.title2.weight(.semibold)`; the finish summary's stats use `.title`.
- A changing number animates with `.contentTransition(.numericText(value:))` inside an animation; the rest countdown uses `.numericText(countsDown: true)`.
- Secondary information (Previous, setup line, progression note, footnotes) uses `.subheadline` or `.footnote` with `.secondary`.

## Motion

- Use SwiftUI's default animation (`withAnimation { }` or `.animation(.default, value:)`, a spring). No custom timing curves, and nothing longer than about half a second.
- Rows and sections insert and remove with animation: change the data inside `withAnimation`.
- Bars and banners (the rest timer bar) enter and leave from their edge with `.move(edge:).combined(with: .opacity)`.
- Confirmations use SF Symbol effects, played once: `.symbolEffect(.bounce, value:)` on the checkmark when a set is checked off (not when unchecked), on the progression arrow when the workout opens, and on the finish summary's checkmark.
- Reduce Motion: read `@Environment(\.accessibilityReduceMotion)`. When it is on, every transition is `.opacity`, sliding and scaling (rows, the timer bar, the diagram's pin and adders) become cross-fades, and symbol bounces don't play. Numeric-text transitions stay; the system already tones them down.
- No looping, pulsing or attention-seeking animation. The rest ring drains continuously, which is information, not decoration.

## Haptics

Haptics go through SwiftUI's `.sensoryFeedback(_:trigger:)`, which follows the system haptics setting. Fire them only for the user's own action or the timer, never for programmatic changes such as pre-fill, relaunch or import restoring data. This table is the contract later tickets cite:

| Action | Feedback | SwiftUI |
|---|---|---|
| Weight step (−, +, or a menu pick), set-type change, ±15 s on the timer, tapping Previous to copy it | selection | `.selection` |
| Set checked off | success | `.success` |
| Set unchecked | light impact | `.impact(weight: .light)` |
| Set or exercise deleted | medium impact | `.impact(weight: .medium)` |
| Rest timer at 3, 2 and 1 seconds left (app in foreground) | light impact | `.impact(weight: .light)` |
| Rest timer reaches zero (app in foreground) | warning | `.warning` |
| Workout finished (summary appears) | success | `.success` |
| Import completed | success | `.success` |

Nothing else gives haptic feedback. A − or + that can't step (5 lb or 90 lb) is disabled and silent.

## Sound

- One sound only: `App/Resources/rest-chime.caf`, a soft two-tone chime (A5 then E6) of 0.6 seconds. `scripts/make-chime.swift` synthesizes it, and `just chime` regenerates it; never replace it with a downloaded file.
- When the rest timer reaches zero with the app in the foreground, the app plays the chime with `AVAudioPlayer` through an `AVAudioSession` in the `.ambient` category. That category mixes with the user's music (never pausing or ducking it) and is silenced by the ring/silent switch.
- The rest notification uses the same file: `UNNotificationSound(named: UNNotificationSoundName("rest-chime.caf"))`.
- Settings has a "Timer Sound" switch (`@AppStorage("timerSoundEnabled")`, on by default). Off means no foreground chime and a notification with no sound; the haptics still play.

## Small touches

Each touch is specified in its feature ticket; this is the rule that ticket implements.

- Reps and duration fields use `.keyboardType(.numberPad)` with a keyboard toolbar (`ToolbarItemGroup(placement: .keyboard)`): a spacer, then "Next", which focuses the next empty field in the workout or dismisses the keyboard when there is none, then "Done", which dismisses it.
- Set rows have a long-press `.contextMenu` (ticket 08) as well as swipe actions.
- Empty states use `ContentUnavailableView` with an SF Symbol and one sentence; an empty search uses `ContentUnavailableView.search`.
- Destructive actions confirm with a destructive-role button that names the action ("Discard Workout", "Delete Routine"), plus Cancel. Confirm: discarding a workout, deleting a workout or routine, removing an exercise that has checked sets, and replacing data on import. Exception: deleting a single set (swipe or menu) happens at once, because it is quick to redo.
- Finishing a workout shows a short summary (ticket 06).
- Tapping a Previous value copies it into an unchecked set (ticket 09).
- The setup diagram animates between setups (ticket 14).

## SF Symbols

Use these names so the same idea looks the same everywhere. A new symbol is added here in the ticket that introduces it.

| Meaning | Symbol |
|---|---|
| Workout tab | `dumbbell.fill` |
| History tab | `clock.arrow.circlepath` |
| Settings tab | `gearshape` |
| Minimize the workout | `chevron.down` |
| Set not done / done | `circle` / `checkmark.circle.fill` |
| Weight down / up | `minus` / `plus` |
| Add exercise, add set, new item | `plus` |
| Delete, discard, remove | `trash` |
| Duplicate | `plus.square.on.square` |
| Reorder | `arrow.up.arrow.down` |
| Rest time | `timer` |
| Progression note | `arrow.up.circle.fill` |
| Finish summary | `checkmark.seal.fill` |
| More actions menu | `ellipsis.circle` |
| Filter the exercise list | `line.3.horizontal.decrease.circle` |
| Export data / import data | `square.and.arrow.up` / `square.and.arrow.down` |

## Accessibility

- Every interactive element has a label that reads naturally, with units spelled out, and its state as the value: "Weight, 35 pounds", "Reps, 10", "Set 1, done", "Previous, 35 pounds times 10". Symbol-only buttons get a text label ("Minimize", "Increase weight").
- Tap targets are at least 44 × 44 points, including − and + and the check-off button.
- Every screen works at the largest accessibility text size: rows wrap rather than truncate (no `.lineLimit(1)` on content), set rows stack their parts vertically when `dynamicTypeSize.isAccessibilitySize`, and toolbars don't collide (move secondary actions into a `Menu`).
- Color is never the only signal: a completed set also shows its filled checkmark.
- Every interactive element has an `accessibilityIdentifier` (`AGENTS.md` rule 13).

## Feel-check list

The user runs these on the phone at each checkpoint; the checkpoint ticket sends the lines for its phase. Each line is one thing to try and what it should feel like.

Phase 1 (tickets 06–10):

- [ ] The home-screen icon looks right in light, dark and tinted modes.
- [ ] Weight − and +: a selection tick on each step, the number rolls, digits don't jitter.
- [ ] Weight menu pick: a selection tick, the number rolls.
- [ ] Check off a set: a success tap, the checkmark bounces, the row tints green.
- [ ] Uncheck a set: a light tap, the tint fades.
- [ ] Add Set: the row slides in.
- [ ] Swipe to delete a set: a medium thump, the row collapses, no confirmation.
- [ ] Remove an exercise that has checked sets: it confirms first, then a medium thump.
- [ ] Change a set's type from the label menu or the long-press menu: a selection tick.
- [ ] Long-press a set row: the menu offers Set Type, Duplicate and Delete.
- [ ] Reps keyboard: Next jumps to the next empty field, Done closes the keyboard.
- [ ] Elapsed time ticks without jitter.
- [ ] Tap a Previous value: a selection tick, and the copied numbers roll.
- [ ] Finish: the summary appears with a success tap and a checkmark effect.
- [ ] Discard: it confirms first.
- [ ] Search the exercise picker for nonsense: the empty search view shows.
- [ ] Import: it confirms before replacing, then a success tap.
- [ ] With Reduce Motion on, rows and sheets cross-fade instead of sliding.
- [ ] At the largest text size, set rows wrap and the toolbar fits.

Phase 2 (tickets 13–15):

- [ ] Check off a set: the rest bar rises from the bottom, the ring drains smoothly, the countdown rolls.
- [ ] −15 and +15: a selection tick each.
- [ ] Last three seconds: a light tap at 3, 2 and 1.
- [ ] Zero in the foreground: a warning buzz and the chime, then the bar drops away.
- [ ] Zero with music playing: the chime plays over the music, which keeps its volume.
- [ ] Zero with the silent switch on: no chime, the haptics still play.
- [ ] Timer Sound off: no chime in the app, and the notification is silent.
- [ ] Rest with the app in the background: the notification arrives with the chime.
- [ ] Skip: the bar leaves with no buzz or chime.
- [ ] Change the weight in the diagram sheet: the pin slides and the adders fade.
- [ ] Rest before a weight change: the change line fades in; tapping it shows the diagram moving from now to next.
- [ ] With Reduce Motion on, the rest bar and the diagram cross-fade.

Phase 3 (tickets 18–20):

- [ ] Start a routine that progressed: the arrow bounces once, and the new weight shows in amber.
- [ ] Delete a routine: it confirms first.
- [ ] Finish a routine workout after adding a set: the Update Routine prompt appears.

Phase 4 (tickets 23–24):

- [ ] An empty history shows the empty state.
- [ ] Delete a past workout: it confirms first.
- [ ] Edit a past workout: swipe-deleting a set gives a medium thump with no confirmation.

## App icon

- A PowerBlock seen from its long side, flat and with no perspective: two flat-topped end stacks of plates, the bars of the five nested plates stepping down between them, and the handle as one straight bar across the top, in amber (`#E8710A`) on a warm off-white background (light) or near-black (dark); the tinted variant is the silhouette in light gray on black. The light icon uses the brighter dark-mode amber because the darker text-contrast amber looks brown at icon size.
- `scripts/render-icon.swift` draws it in SwiftUI and writes the three 1024 × 1024 PNGs into `App/Resources/Assets.xcassets/AppIcon.appiconset`; `just icon` regenerates them. Change the icon by editing the script, never the PNGs.
