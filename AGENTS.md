# Blocklog

A SwiftUI and SwiftData workout logger for iOS 27, built for PowerBlock dumbbells. `README.md` covers one-time setup and signing.

## Commands

Run every command from the repository root. If `just` is not on `PATH`, run it as `mise exec -- just <recipe>`.

- `just` (the `default` recipe): list the recipes.
- `just generate`: regenerate `Blocklog.xcodeproj` from `project.yml`. Run it after adding, moving or deleting a file; the build and test recipes also run it first.
- `just build`: compile for the simulator, the fastest check that the code builds.
- `just build-tests`: compile the app and the test bundle without running it, so a later test recipe only relinks.
- `just test` / `just test-unit`: run every unit test.
- `just test-one <identifier>`: run one test or suite, such as `just test-one BlocklogTests/RoutineTests` (quote an identifier that ends in `()`).

Local checks: before review and commit, `just test-unit` must pass. Acceptance of a flow or screen is checked by a `blind-tester` delegate when the ticket needs it, not by UI tests. CI runs the unit tests on every push.

- `just ci-test Blocklog`: the exact command CI runs; use it to reproduce a CI failure.
- Every test recipe turns on test timeouts (240 s per test, 300 s at most), so a hung test fails in minutes.
- `just ci-report <run-id>`: download a failed CI run's artifacts and print its test failures, crash reports and log tail; use it first when CI fails.
- `just run`: install and launch on the simulator and save `build/run.png`, for a manual check.
- `just device`: build, sign and install on the connected iPhone; checkpoints use it.
- `just fmt`: format the Swift sources; run it before every commit that changes Swift files.
- `just chime` / `just icon`: regenerate `App/Resources/rest-chime.caf` and the app icons from `scripts/`; change the scripts, never the generated files.
- `just skills`: export Apple's SwiftUI skills into the gitignored `.agents/skills/apple/`; run it when that folder is missing.

When a build or test fails, read the full log in `build/logs/`; the terminal shows a shortened version.

`Blocklog.xcodeproj` is generated and gitignored: change targets, settings and resources in `project.yml`, never in the Xcode project.

## Layout

- `App/Model`: SwiftData models (data only, see rule 3).
- `App/PowerBlock`: the PowerBlock weight table and the block diagram.
- `App/Logic`: every other rule the app applies.
- `App/Views`: SwiftUI views.
- `App/Resources`: the starter exercises, the asset catalog and sounds.
- `Tests/`: Swift Testing unit tests, hosted in the app. Tests that need a store use an in-memory `ModelContainer`.
- `scripts/`: generators for committed assets, run through `just`.
- `docs/`: design and research documents.

## Architecture rules

The per-ticket code review checks every change against these rules. Where a skill's advice conflicts with them, these rules win.

1. Every rule the app applies (anything describable as "when X, the app does Y", such as set numbering or the default workout title) lives in `App/Logic` or `App/PowerBlock`, as a plain type tested through its public interface. Views call these types and render the results; they never compute a rule inline.
2. Changes to stored data go through `App/Logic` functions that also save, so killing the app loses nothing. When the save throws, the function rolls the context back before rethrowing, so a failed change leaves nothing pending for a later save to commit. Views don't edit model properties directly, except binding a single field of the row they show, such as a set's reps, which the view saves when it changes.
3. `App/Model` types hold stored data and relationships only; behaviour goes in `App/Logic`.
4. A protocol or injected dependency exists only where tests must replace a system service: the clock and notifications. There is no other protocol with a single implementation, no factory, and no wrapper that only delegates; tests use the real type, such as the PowerBlock table.
5. There are no singletons and no global mutable state: pass what a type needs into it. App-wide settings use `@AppStorage`.
6. Ask the user before adding a Swift package.
7. Before writing a helper, search `App/` with `rg` for an existing one and reuse it.
8. One module per file: a main type plus small types only it uses, named after the main type. A file over about 400 lines is a review flag that it may hold two modules.
9. Swift 6 strict concurrency: views and logic are `@MainActor`. `project.yml` sets no default isolation, so write `@MainActor` on each type in `App/Logic` and `App/PowerBlock`. `App/Model` is the exception: `@MainActor` on a `@Model` class breaks its generated `PersistentModel` conformance and `#Predicate` key paths, so model classes and their raw-value enums stay nonisolated, and only main-actor code (views, `App/Logic`, the main `ModelContext`) touches them. Every `@unchecked Sendable` and `nonisolated(unsafe)` has a comment saying why it is safe.
10. Tests check behaviour through public interfaces, never private helpers or view internals. A test is never weakened, skipped or deleted to make a change pass.
11. Names in code, tests and UI text follow `CONTEXT.md`, the glossary; read it before naming a type, property or test. A new domain term goes into `CONTEXT.md` in the same change.
12. Weights come only from the PowerBlock table, chosen with − and + or the weight menu. There is never a free-entry weight field.
13. Every interactive element has an `accessibilityIdentifier` following the convention below. The one exception is a `.searchable` field, which takes no identifier from SwiftUI; the blind tester finds it by its placeholder, "Search exercises".
    Identifiers are dot-separated lowerCamel words, `<screen>.<element>`, such as `workout.finish` or `finish.save`. Repeated rows add their zero-based position after the collection's name: `workout.exercise.<e>.set.<s>.<element>`, such as `workout.exercise.0.set.1.reps`. A row named by its content uses the name instead: `exercisePicker.row.<exercise name>`. Keyboard toolbar buttons use `keyboard.<element>`.
14. Every screen and interaction follows `docs/design.md`: color, type, motion, haptics, sound and accessibility. Read it before writing a view.
15. Once ticket 06 ships, the user's phone holds real data. A change to `App/Model` must be one SwiftData migrates automatically (adding a model, or adding an optional field), or it must come with a versioned-schema migration and a test that opens a store written by the previous version. Ask the user before any such change.
16. Stored fields that apply only in some cases (a set's weight, reps and seconds by exercise type; a routine exercise's rep range or target duration) stay flat optionals in `App/Model`, but one type in `App/Logic` reads them into a choice whose cases hold only the values that apply, and writes them back. Code outside that type, and import, read and write the fields only through it, never by branching on the raw fields. A new field of this kind gets its reading in the same change. Tickets 22d and 22e bring the existing code in line.

## Ticket workflow

Tickets live in the untracked `.scratch/blocklog/issues/`.

1. Read the ticket and every file its "Read first" names.
2. Implement it. Run `just fmt`, then the local checks above until they pass.
3. Review: hand the uncommitted change to a `reviewer` delegate, telling it to run the code-review skill with the ticket file as the spec. If you can't delegate, stop before committing and report "ready for review" to the session that gave you the ticket; it runs the review.
4. Fix the findings you agree with, then run the local checks again. Answer each remaining finding in the commit message, one line each.
5. Commit and push. Don't commit before the review.
6. Wait for CI with `gh run watch` until the run is green. CI skips pushes that change only `docs/` or Markdown files, so those have no run.

## Checkpoints and architecture reviews

- Tickets 11 and 12 define the routines: `.scratch/blocklog/issues/11-phase-1-architecture-review.md` and `12-phase-1-checkpoint.md`. Later phases repeat them.
- Each checkpoint ends with a `phase-N` git tag, so a later review can cover everything since `phase-N`.
- When an architecture review finds a missing rule, add it to the architecture rules above.

## Skills

- Writing or changing SwiftUI views: Apple's `swiftui-specialist` and `swiftui-whats-new-27` from `just skills`.
- Checkpoint design reviews only: `swiftui-pro`.
- Actor-isolation or `Sendable` compiler errors: `swift-concurrency`.
- Writing unit tests: `swift-testing-expert`.
- The per-ticket review: code-review.
- The phase architecture reviews: codebase-design and ponytail-audit.

## Tools evaluated

- `pi-xcode-mcp` (phase 2 checkpoint): skip. No view has a `#Preview`, so its preview render has nothing to render; `just build` and `just test-one` already cover builds and tests; and it needs two `sudo xcrun mcp-server approve` steps plus a slow workspace open. Revisit if the app gains previews.
