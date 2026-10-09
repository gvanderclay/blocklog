# Glossary

The domain terms Blocklog uses in code, tests and UI text. A term in parentheses is its type name in code.

## Workouts

- **Exercise** (`Exercise`): a movement the user can log, from the starter list or custom. It has a muscle group, equipment, an exercise kind and an optional rest override.
- **Custom exercise**: an exercise the user creates from the exercise picker (`isCustom`). It is listed and logged like a starter exercise.
- **Exercise picker** (`ExercisePicker`): the Add Exercise sheet. It lists exercises by muscle group, searches and filters them by equipment, and creates custom exercises.
- **Workout** (`Workout`): one training session: a title, a start date, an end date once finished, and its ordered workout exercises. Finished workouts are the history that previous numbers and progression read.
- **In-progress workout**: the workout with no end date. At most one exists; the app reopens into it at launch, and starting another workout is disabled while it exists.
- **Freeform workout**: a workout started empty rather than from a routine. It has no routine link, so it gets no progression note and never asks to update a routine.
- **Workout exercise** (`WorkoutExercise`): one exercise inside one workout, with its position and ordered sets. Doing the same exercise in two workouts gives two workout exercises.
- **Exercise kind** (`ExerciseKind`): what a set of the exercise records: weight × reps (dumbbell weight and reps), bodyweight reps (reps, with optional added PowerBlock weight), or duration (seconds).
- **Set** (`WorkoutSet`): one logged effort in a workout exercise: its position, set type, the values its exercise kind records, and whether it is checked off. Finish deletes unchecked sets.
- **Set type** (`SetType`): normal, warm-up, drop or failure. The set label shows a counted number for a normal set and "W", "D" or "F" for the others.
- **Counted set**: any set except a warm-up. Counted sets are numbered 1, 2, 3… in order, and previous numbers pair sets by that order.
- **Working set**: a normal or failure set. Progression looks only at working sets; warm-up and drop sets never count.

## Routines

- **Routine** (`Routine`): a named plan a workout can start from, holding ordered routine exercises. It stores structure, rep ranges and target durations, never weights: weights come from history.
- **Routine exercise** (`RoutineExercise`): one exercise in a routine: its position, its planned set types, and either a rep range (low–high, such as 8–12) or a target duration in seconds.
- **Progression note**: the line under an exercise in a workout started from a routine that explains a pre-filled step up, such as "↑ Up from 35 lb: you hit 12 on every set", or "You hit 12 on every set: consider adding weight" for bodyweight without added weight. It is not stored.
- **Structural change**: a difference between a finished workout and the routine it started from that makes Finish ask to update the routine: an exercise added, removed, swapped or reordered, or a set added or removed. Weight, reps, duration and set-type edits are not structural.

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
- **Timer Sound**: the Settings switch for the rest chime, both in the foreground and on the rest notification. The haptics play either way.
- **Backup document**: the versioned JSON file Export writes and Import reads, holding every exercise, routine and finished workout. Import validates the whole document, then replaces all data; it never merges.

## Process

- **Checkpoint**: the ticket that ends a phase. It runs the accessibility audits and a design review on the phone, installs the app on the phone, waits for the user's feel check and real workout, and tags the commit `phase-N`.
