# Glossary

The domain terms Blocklog uses in code, tests and UI text. A term in parentheses is its type name in code. Each word names one thing: plans (routines, starter routines, programmes) are what you start from, and records (workouts, sets) are what you did. "Session" is not a Blocklog term; say routine or workout.

Terms marked *(planned, phase N)* name features planned in `.scratch/blocklog/spec.md` (phases 4–8) and not built yet.

## Workouts

- **Exercise** (`Exercise`): a movement or held position the user can log, a starter exercise or a custom one. It has a muscle group, equipment, an exercise type and an optional rest override.
- **Starter exercise**: an exercise bundled in `starter-exercises.json` and seeded into the store. Seeding adds each starter exercise whose name, ignoring case, the store lacks, and changes nothing else.
- **Custom exercise**: an exercise the user creates from the exercise picker (`isCustom`). It is listed and logged like a starter exercise.
- **Exercise picker** (`ExercisePicker`): the Add Exercise sheet. It lists exercises by muscle group, searches and filters them by equipment, and creates custom exercises.
- **Workout** (`Workout`): the record of one training day you did or are doing: a title, a start date, an end date once finished, and its ordered workout exercises. Starting a routine or a starter routine creates one; a workout is never a plan. Finished workouts are the history that previous numbers and progression read.
- **History** (`WorkoutHistory`): the History tab's list of finished workouts, newest start date first. A row shows the title (with the programme's name when the routine belongs to one, "Push · PPL"), the start date, the duration ("42m", "1h 05m") and the exercise count; it opens a detail that can be switched to editing mode (`PastWorkoutEditing`): every set of a past workout counts as done, so a set is **valid** when it has its exercise type's required values (reps, or seconds above 0), and Done is enabled only while every set is valid. Deleting a workout asks first and removes its exercises and sets.
- **Total time**: a finished workout's end date minus its start date, shown on the finish summary as "Total Time".
- **In-progress workout**: the workout with no end date. At most one exists; the app reopens into it at launch, and starting another workout is disabled while it exists.
- **All sets done**: the prompt that appears when checking off a workout's last unchecked set. It offers Finish or Keep Going, and that check-off starts no rest.
- **Freeform workout**: a workout started empty, from no routine or starter routine. It gets no progression note and never asks to update a routine. (A workout started from a starter routine, or whose routine was deleted, also has no routine link, so a missing link alone doesn't mean freeform.)
- **Workout exercise** (`WorkoutExercise`): one exercise inside one workout, with its position and ordered sets. Doing the same exercise in two workouts gives two workout exercises.
- **Exercise type** (`ExerciseType`): what a set of the exercise records: weight × reps (dumbbell weight and reps), bodyweight reps (reps, with optional added PowerBlock weight), or duration (seconds). The New Exercise form labels it "Type".
- **Set** (`WorkoutSet`): one row in a workout exercise, for one effort: its position, set type, the values its exercise type records, and whether it is checked off. A routine start creates sets before they are done; Finish deletes the unchecked ones.
- **Set values** (`SetValues`): the weight, reps and seconds a set records, as one choice per exercise type holding only that type's values: weight × reps has a weight and reps, bodyweight reps has an optional added weight and reps, duration has seconds. Reps and seconds stay empty until the user fills them in.
- **Set type** (`SetType`): normal, warm-up, drop or to failure (taken until another rep isn't possible). The set label shows a number for a normal set and "W", "D" or "F" for the others.
- **Counted set**: any set except a warm-up. Counted sets get an ordinal 1, 2, 3… in order, used to pair sets with previous numbers; only a normal set shows its ordinal as its label.
- **Progression set**: a normal or to-failure set. Progression looks only at progression sets; warm-up and drop sets never count towards it.

## Routines

- **Routine** (`Routine`): the plan for one training day, such as "Push", holding ordered routine exercises. Starting it creates a workout. It stores structure, rep ranges and target durations, never weights: weights come from history. It belongs to at most one programme; one with none is listed in My Routines.
- **Routine exercise** (`RoutineExercise`): one exercise in a routine: its position, its planned set types, and its **target**: a rep range (low–high, such as 8–12) for a rep exercise, or a target duration in seconds ("Target Duration" in the routine editor) for a duration exercise. The exercise's type decides which; a routine exercise can store neither (`RoutineTarget`).
- **Planned set**: one set of a routine exercise. It holds only a set type; weights and reps come from history.
- **Routine draft** (`RoutineDraft`): the routine editor's unsaved copy of a routine. Save writes it to the routine; Cancel drops it.
- **Pre-fill**: the values a workout started from a routine gives each set: last time's weight and reps by counted-set order, last time's warm-ups by order among warm-ups, the target duration for a duration set, and 5 lb (or "BW") with empty reps when there is nothing from last time.
- **Progression note**: the line under an exercise in a workout started from a routine that explains a pre-filled step up, such as "↑ Up from 35 lb: you hit 12 on every set", or "You hit 12 on every set: consider adding weight" for bodyweight without added weight. It is not stored.
- **Structural change**: a difference between a finished workout and the routine it started from that makes Finish ask to update the routine: an exercise added, removed, swapped or reordered, or a set added or removed. Weight, reps, duration and set-type edits are not structural.
- **Starter routine** (`StarterRoutine`): a read-only routine bundled with the app, such as Push or Golden Six, listed in the starter library. Starting one gives a workout titled with its name, pre-filled like a routine start but with no routine link. "Add to My Routines" opens the routine editor on a routine draft of it.
- **Starter programme** (`StarterProgramme`): starter routines meant to rotate as one programme, such as Push/Pull/Legs. "Add Programme" creates a programme holding copies of them, in order.
- **Starter library**: the sheet listing the starter programmes, the starter routines that belong to none, and, under "Stretching", the stretch routines.
- **Stretch routine**: a starter routine whose format is stretch (`StarterRoutine.Format.stretch`), such as Full-Body Quick Stretch: one timed set of a stretch per entry, its target duration the hold. It plays in the guided player; until phase 7 it can't be copied into My Routines or a programme.
- **Estimated time**: a starter routine's rough length, every set taking the default rest plus 40 seconds. A stretch routine's is one round: each hold, twice for a per-side stretch, plus a 5-second lead-in before each, without pauses between sides.
- **Programme** (`Programme`) *(planned, phase 4)*: an ordered list of routines you rotate through, such as PPL: Push → Pull → Legs. It owns its routines: adding a routine copies it in, and a routine that leaves the programme, or whose programme is deleted, moves to My Routines. A routine's **programme membership** (`ProgrammeMembership`) is its programme and its position in it, from 0, held together.
- **Up next** *(planned, phase 4)*: a programme's next routine: the one after the routine of the programme's newest finished workout, wrapping round, or the first with none. It is worked out, never stored; workouts of other routines never move it.
- **Routine format** *(phase 7; starter routines carry it from phase 6)*: how a routine plays: Sets (the default), Timed AMRAP or Stretch. The bundled starter routines mark stretch routines with `"format": "stretch"` (`StarterRoutine.Format`).

## PowerBlock

- **PowerBlock setting**: one of the 27 weights the user's PowerBlock Elite EXP 90 can make, in pounds per dumbbell, from 5 to 90. Every weight in the app is a PowerBlock setting; 12.5, 22.5, 32.5 … 82.5 do not exist.
- **Handle only**: the setup with the pin in no slot, so only the handle is lifted: 5, 7.5 or 10 lb depending on the adders.
- **Slot**: a plate position the magnetic pin selects. There are eight: the first slot and the slots printed 30 to 90.
- **First slot**: the top plate slot, 20 lb with both adders. It has no printed number, so setup text calls it "first slot".
- **Adder**: a 2.5 lb weight that fits in the handle. 0, 1 or 2 are installed.
- **Printed number**: the number on a slot: its total weight with both adders installed. Setup text names the printed number and the adder count, never arithmetic, so 27.5 lb is "Pin 30 · 1 adder", not "25 + 2.5".
- **Setup**: how to set the block for one PowerBlock setting: handle only, the first slot or a slot, plus an adder count. Each setting has exactly one setup.
- **Setup line**: a setup as one line of text, such as "Handle only · no adders", "Pin first slot · 2 adders" or "Pin 30 · 1 adder". It shows under every set that has a weight.
- **Change line**: what to change on the block between two weights, such as "Pin 30 → 40 · remove 1 adder". The rest timer shows it when the next set's weight differs; it is nil for equal weights.

## Rest and history

- **Previous numbers**: what the user did last time, shown as "Previous" beside each set: the sets of the most recent finished workout containing the exercise, paired with the current sets by counted-set order. Warm-ups get none.
- **Default rest**: the app-wide rest length, 90 seconds unless changed in Settings, stored with `@AppStorage`. It applies to every exercise without a rest override.
- **Rest override**: an exercise's own rest length in seconds. It replaces the default rest for that exercise in every workout.
- **Rest timer** (`RestTimer`): the countdown that starts when a set is checked off. It stores its end date and total length, never a ticking counter; ±15 moves both, Skip, Finish and Discard end it, and Minimize leaves it running.
- **Overtime**: the rest timer after its end date. It counts up as "+m:ss" until Skip, the next check-off, Finish or Discard; reaching zero never ends the rest timer by itself.
- **Rest notification**: the "Rest over" system notification (identifier `rest-timer`) scheduled at the rest timer's end date, so a locked or backgrounded phone still alerts. The app shows nothing for it in the foreground.
- **Timer Sounds**: the Settings switch for every timer sound: the rest chime, in the foreground and on the rest notification, and the guided players' ticks and chimes. The haptics play either way.
- **Backup document**: the versioned JSON file Export writes and Import reads, holding the training data: every exercise, routine and finished workout (and programme, from phase 4), not the settings. Import validates the whole document, then replaces all training data; it never merges.

## Guided routines *(stretching built in phase 6; timed AMRAP planned, phase 7)*

- **Round**: one pass through a guided routine's exercises in order. A stretch routine plays 1 to 3 rounds; a timed AMRAP repeats rounds until the time cap.
- **Guided player**: the full-screen player that runs a stretch routine or a timed AMRAP on a clock, instead of the workout screen's sets. The stretch player (`StretchPlayer`) offers Pause, Skip (leave the current hold uncounted for the next hold's lead-in), Back (to the previous hold's lead-in) and +15 (add 15 seconds to the current lead-in or hold), with the rounds chosen before Start. Starting is refused while a workout is in progress.
- **Countdown phase** (`PhasedCountdown.Phase`): one timed part of a guided player's countdown, such as a lead-in or a hold, run in order on the injected clock. A **signalled** countdown phase ticks through its last 5 seconds and chimes at its end; a **completed** phase ran to its end.
- **Stretch log**: a stretch routine played in the stretch player is logged as a finished workout titled with the routine's name, with no routine link, holding one completed duration set per stretch per round whose hold (either side) was completed, its seconds the hold's length with +15s, the longer side's for a per-side stretch. Finishing logs it; quitting after a completed hold asks "Save what you did?", where Save logs it and Discard drops it. Nothing is stored until then, so if the app is closed mid-routine (the player pauses in the background), the holds done so far are lost.
- **Stretch**: a starter exercise of type duration in the picker's "Stretching" group (`MuscleGroup.stretching`).
- **Per side** (`isPerSide`): an exercise done on each side in turn. The stretch player plays it as two holds, one per side; the workout logs one set per round holding the per-side seconds.
- **Hold**: one timed stretch on one side (or both, if not per side), its length the routine exercise's target duration.
- **Lead-in**: the 5 seconds before a hold to get into position; between the sides of a per-side stretch it reads "Switch sides".
- **Cue** and **variation** (`StretchCue`): a stretch's one-line instruction, and its Easier and Harder alternatives, from the bundled `stretch-cues.json`, keyed by exercise name. Not stored.
- **Timed AMRAP**: a routine format: as many rounds as possible of its exercises, each at a fixed rep count, before the time cap. Cindy is the starter one.
- **Time cap**: a timed AMRAP's length, such as 20 minutes.
- **Extra reps**: the reps done in the unfinished round when the time cap ends, counted in exercise order.
- **AMRAP score**: completed rounds plus extra reps, shown as "14 rounds + 7 reps" and stored on the workout.

## Process

- **Checkpoint**: the ticket that ends a phase. It runs the accessibility audits and a design review on the phone, installs the app on the phone, waits for the user's feel check and real workout, and tags the commit `phase-N`.
