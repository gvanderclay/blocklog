# Countdown tick timing

**Question:** Why is the first of five countdown ticks late in Blocklog on an iPhone, and what should change so the ticks land on their seconds?

**Short answer:** The strongest explanation is the *long first task sleep with unspecified tolerance*, not silence in the sound. Swift's dispatch-backed sleep path turns `nil` tolerance into `dispatch_after_f`; Apple's published dispatch source gives that operation leeway proportional to the delay. A 25-second delay permits roughly 1.25–2.5 seconds of coalescing in that implementation, versus 50–100 milliseconds for a one-second delay. The countdown already anchors subsequent deadlines to the phase end, so a late first tick followed by an on-time second tick naturally produces the reported short first gap. This is a source-supported mechanism, not yet a measured diagnosis of this particular phone. [S1–S5, L1]

**Recommendation:** First make the existing sleep's tolerance explicitly `.zero` and measure wake lateness and audible onset on the phone. That is the smallest change addressing the best-supported cause. If the actual requirement is audio-clock-accurate spacing independent of task scheduling, queue the five ticks and chime ahead of time on an audio timeline; merely replacing `AVAudioPlayer` with an engine but still issuing each sound after a sleep does not solve scheduling jitter. No cited API promises exact acoustic arrival at a wall-clock second on every route. [S3, S6, A1–A5, F1]

## Date, versions, and evidence scope

- Research date: **2026-10-10**, from `date -u +%Y-%m-%d`.
- Local checkout: `12f160308d69a3629bef743d47aa5c085c77a764`. `TimerSounds.swift` and `StretchPlayerScreen.swift` also had uncommitted preparation changes when examined; the line references below describe that working tree. `git diff -- App/Logic/TimerSounds.swift App/Views/StretchPlayerScreen.swift` showed preparation/cached players and an `onAppear` call, but no change to the sleep. No code was edited for this report.
- Local tools: `swift --version` returned Apple Swift **6.4**, `swiftlang-6.4.0.34.1`; `xcodebuild -version` returned **Xcode 27.0**, build **27A266a**. These commands inspect versions; no build or app run was performed.
- Swift source checked: commit `10973e278de2000130ddcad6384f1823dddbdd09`, dated 2026-10-10. This is a pinned public snapshot, **not proof that the phone ships the identical runtime**. [S1–S4]
- Darwin dispatch source checked: Apple OSS commit `2361ffb78a76f7ee488cd052eb0bc5c767118bf9`, dated **2025-10-16 (older source)**. Cross-platform corelibs dispatch was checked separately and differs. The exact dispatch implementation and effective QoS on the user's iOS 27 phone remain **unknown**. [S5, S7]
- Apple API documentation was fetched live on the research date; its API availability explicitly includes iOS 27 for the new throwing player-node start method. Documentation pages do not expose a revision date. The Swift proposal, WWDC20 talk, and 2019 engineer forum answer below are explicitly older sources, used for API semantics and architecture, not evidence of a new iOS 27 regression. [S8, A6, W1, F1]

## Likely causes, ranked, with evidence

### 1. Long first sleep's default tolerance — strongest match

**The source chain is specific, not an inference from Foundation `Timer` guidance:**

1. `Task.sleep(for:tolerance:clock:)` defaults to `tolerance: nil`, `clock: .continuous` and forwards to the clock. `ContinuousClock.sleep` documents that omitted tolerance permits coalescing CPU wake-ups. [S1, S2]
2. In the global fallback, Swift encodes missing tolerance as `(0, -1)` and submits the deadline to the concurrency runtime. The new scheduling-executor path is separate, so this is a description of the dispatch-backed fallback, not a claim about every custom executor. The inspected `MainActor` enqueues jobs on the main executor and does not declare a `SchedulingExecutor` conformance. [S3, S4]
3. `DispatchGlobalExecutor.cpp` tests `tnsec != -1`: an explicit tolerance uses a dispatch timer source with that leeway; `-1` uses `dispatch_after_f`. Thus `.zero` and `nil` select materially different scheduling paths. [S4]
4. Apple's published `_dispatch_after_leeway` uses `delta / 10` for unspecified/background/utility QoS, `delta / 15` for default/user-initiated QoS, and `delta / 20` for user-interactive and above. `_dispatch_after` clamps the result to 1 millisecond–60 seconds and sets the timer deadline to target plus leeway. [S5]

Calculated allowances in that Darwin source:

| Requested remaining delay | Background/utility, 10% | Default/user-initiated, 1/15 | User-interactive, 5% |
| --- | ---: | ---: | ---: |
| 25 seconds | 2,500 ms | 1,666.7 ms | 1,250 ms |
| 1 second | 100 ms | 66.7 ms | 50 ms |

These are **coalescing allowances, not predicted measured delays or hard worst-case task-resumption bounds**. Apple's dispatch timer documentation explicitly says latency is possible even with zero leeway. CPU contention, the main executor, and audio output are additional stages. `nil` is implementation-selected tolerance in SE-0329; the API does **not** guarantee a fixed 10 percent. In particular, the corelibs source's unconditional 10 percent is not the best source for Darwin today. [S5–S8]

**Why this produces this symptom in this app:** `StretchPlayerScreen.swift:52–59` sleeps to `nextWake` and then calls `advance()` and immediate playback. `PhasedCountdown.swift:82–85` computes wakes as `endDate - ticksLeft`, rather than adding one second to the previous wake. After a late first wake, the next wait therefore shortens. `advance()` uses rounded-up remaining seconds and suppresses duplicate ticks (`PhasedCountdown.swift:91–105`); if lateness exceeds a second it can skip a countdown tick altogether rather than queue catch-up sounds. `TimelineView` is independent of this task (`StretchPlayerScreen.swift:199`), so seeing the numeral change does not establish that the sound task has resumed. [L1]

For example, a first wake 300 ms late and a second wake on its deadline produce an approximately 700 ms acoustic gap if playback delay is otherwise the same. This is arithmetic derived from the anchored deadline model, not a measured 300 ms result. [L1]

**Unknown:** Actual wake error, effective QoS, and exact runtime/dispatch path on the affected phone. Device logging below settles this without another speculative audio rewrite.

### 2. Audio startup/output latency — real alternative, not established as the first-tick cause

Apple says `AVAudioPlayer.prepareToPlay()` preloads audio buffers and acquires audio hardware, activates the session, and *minimizes* the delay between `play()` and sound output. It does not say it removes all latency. Apple also says stopping **or letting a sound finish** undoes this preparation. Cached player objects alone are therefore not proof that every replay remains prepared. [A1]

The working tree prepares both players and activates the ambient session on appearance (`TimerSounds.swift:19–21`, `StretchPlayerScreen.swift:65–69`), but every tick still originates after the sleep and calls asynchronous `play()` (`TimerSounds.swift:24–28`). This preparation change cannot affect timer coalescing. The task explicitly reports that the change failed on hardware; that observation weighs against simple player-construction/initial-preparation latency as the sole cause, but is not a controlled measurement of hardware behavior. [L1, task-supplied observation]

Output latency is independently real: `AVAudioSession.outputLatency` exposes it, and Apple mentions that AirPlay can introduce a two-second delay. An approximately constant delay applied to every tick shifts the whole sequence; it does **not** by itself shorten only the first gap. A larger first-play delay could, but a claim that this phone's route powers down after exactly 25 seconds, despite preparation, is **unknown**: no applicable Apple-engineer source or device measurement was found supporting that mechanism or giving its size. [A4, arithmetic]

`AVAudioPlayer.play(atTime:)` is already an audio-device-timeline scheduling API, intended for precise synchronization of multiple players. An engine is not required merely to request a future playback time. However, `deviceCurrentTime` has lifecycle constraints: Apple says it returns to zero when no connected player is playing or paused. A scheduling implementation must maintain a valid clock origin and retain/cancel scheduled players; do not simply sample an idle clock independently for each tick. [A2, A3]

`AVAudioPlayerNode` can queue buffers at sample or host times, and `stop()` unschedules its queue and resets the player timeline. That allows one node to own the entire five-tick sequence. Scheduling `at: nil` from a timer handler just means near-future or sequential playback; it does **not** give the timer handler sample-accurate timing. [A5]

`AudioServicesPlaySystemSound` plays asynchronously and immediately; it has no future deadline argument, no simultaneous playback or programmatic volume control, and Apple's documented routing behavior differs from `AVAudioPlayer`. It is not an evidence-based timing fix for a callback that itself is late. [A7]

### 3. Leading silence in the CAF assets — ruled out as a meaningful explanation

`afinfo App/Resources/timer-tick.caf` reported 44,100 Hz, mono Int16, **2,205 valid frames, 0 priming frames, 0 remainder**, duration 0.050000 seconds. The chime has **26,460 valid frames, 0 priming, 0 remainder**, duration 0.600000 seconds. Reading the stored PCM samples gave the following results. [M1]

| Asset | Exact leading zero samples | First nonzero sample | First sample ≥ −60 dBFS | First sample ≥ −40 dBFS |
| --- | ---: | ---: | ---: | ---: |
| `timer-tick.caf` | 1 | 0.022676 ms | 0.045351 ms | 0.113379 ms |
| `rest-chime.caf` | 1 | 0.022676 ms | 0.068027 ms | 0.725624 ms |

The threshold measures are first crossings, not psychoacoustic audibility measurements. They use Int16 absolute sample thresholds 1, 33, and 328 respectively. The tick's synthesis has a 2 ms attack, while the chime has a 12 ms attack (`scripts/make-chime.swift:13–16, 64–67`); neither begins with a long silent pad. The same file plays every tick, so any fixed asset-onset offset would affect all ticks equally. There is no reason to regenerate either sound for this symptom. [L1, M1]

## How precise timer/audio implementations actually do it

**Apple's guidance:** Quinn, an Apple DTS engineer, says that if timing is for audio, the timer should synchronize with audio and the implementation should use audio frameworks; general-purpose timers are for other contexts. This is a **2019 answer**, not a new iOS 27 statement. WWDC20's Core Audio presentation distinguishes framework-owned realtime audio rendering threads from ordinary application work; the audio frameworks already handle the realtime workgroup membership. The recommendation is to hand scheduled audio to those frameworks, not to make SwiftUI's main-actor task a realtime thread. [F1, W1]

**A concrete first-party example, better evidence than guessing about closed-source interval apps:** Apple's live sample, *Building an audio sequencer to arrange and play clips*, establishes a transport grid, queues buffers with `atTime: AVAudioTime(hostTime: startHostTime)`, and starts the node with the iOS 27 throwing `playAudio(at:)` API. A 50 ms timer checks for buffers approaching their end and queues the next iteration with 100 ms look-ahead; the timer is a **scheduler feeder**, not the instant at which the sound is initiated. This is an audio sequencer, not a workout timer, but demonstrates the architecture for precise sound spacing directly. [A8, A6]

**Open-source timer apps do not establish a universal best practice:**

- **OpenHIIT**, an older cross-platform project created in 2023, uses `background_hiit_timer` **1.2.3** in its pinned lockfile. That exact package creates a periodic Dart timer and calls immediate `player.play(AssetSource(...))`; its countdown tests are at remaining values 3.5, 2.5, and 1.5 seconds. It also emits a blank sound at other second boundaries. This is evidence of a real timer-driven approach and empirical lead compensation, **not** audio-clock scheduling or a guarantee of acoustic precision. [O1, O2]
- **WorkoutTimer**, a newer native SwiftUI example, sleeps to a succession of one-second continuous-clock deadlines, emits countdown events, and calls an engine node's `scheduleBuffer(..., at: nil, options: .interrupts)`. It does **not** pre-schedule each tick at a future audio-clock time. Its fixed short sleep may avoid Blocklog's unusually long first-sleep allowance, but this code cannot prove exact sound timing. This is a comparison example, not an established precision benchmark. [O3]
- **LoopTimer**, another newer native example, uses a `DispatchSourceTimer` and makes a new `AVAudioPlayer` followed by immediate `play()` for its chimes. It likewise does not establish future-timed tick scheduling. [O4]

**Unknown:** How well-known closed-source commercial interval timer apps implement their audio. No claim that “all good timer apps use AVAudioEngine” is supported by the available code. Neither an engine nor a system-sound API alone fixes delayed event delivery. [A2, A5, A7, O1–O4]

## Recommended fix: the smallest justified change

### First fix and controlled test: explicit zero sleep tolerance

In `App/Views/StretchPlayerScreen.swift:55`, change only the sleep request:

```swift
try await Task.sleep(
    for: .seconds(max(wake.timeIntervalSinceNow, 0)),
    tolerance: .zero
)
```

Keep `PhasedCountdown.nextWake`'s end-date anchoring, and keep `TimelineView` separate. Do not switch to repeating `now + 1` deadlines; that would accumulate callback delay. No sound generation, stored model, or audio category change is justified by the evidence. This sketch deliberately addresses **timer leeway**, not a promise of perfectly punctual scheduling. [S4–S6, L1]

Do not describe the existing preparation as “so the first sound plays on the beat”: Apple guarantees neither zero preparation delay nor zero callback delay. Check `prepareToPlay()` and `play()` results during the diagnostic; currently the player helper ignores the first Boolean and playback ignores the second. [A1, L1]

**Decision gate:** If the long wake's lateness disappears and the first audible gap becomes normal on the device, ship this narrow fix. If wake lateness is already small but the first sound remains late, audio startup is implicated. If all sounds must be audio-clock spaced regardless of main-thread load, use the scheduled design below rather than adding arbitrary early offsets or periodic warm-up sounds. [S6, A2, A5, F1; recommendation]

### If precise audio spacing is the requirement: queue the whole sound plan ahead

This is a larger, deterministic **render-timing** design, not necessary before testing the one-line fix. Put the domain decision about tick dates in `App/Logic/PhasedCountdown.swift`, for example:

```swift
// Inside PhasedCountdown; enum Signal gets Equatable as it already has.
struct ScheduledSignal {
    let date: Date
    let signal: Signal
}

var upcomingSignals: [ScheduledSignal] {
    guard case .running(let endDate) = state,
          phase?.isSignalled == true else { return [] }
    let date = now()
    let ticks = (1...Self.tickSeconds).reversed().compactMap { left in
        let deadline = endDate - TimeInterval(left)
        // Keep the existing policy: don't replay seconds already passed.
        return deadline > date
            ? ScheduledSignal(date: deadline, signal: .tick) : nil
    }
    return ticks + (endDate > date
        ? [ScheduledSignal(date: endDate, signal: .chime)] : [])
}
```

This is a design sketch: define what happens when starting/resuming exactly on a tick boundary and cover it in the public-interface tests. The existing `nextWake` also deliberately selects the *next* boundary rather than replaying a current second. [L1]

`App/Logic/TimerSounds.swift` can keep immediate playback for existing callers, but own one prepared engine/player node and loaded PCM buffers for a scheduled stretch plan. Read samples from the existing CAFs, connect the node with their format to the engine mixer, and start the engine before scheduling. Its scheduling core is:

```swift
// TimerSounds: engine and node already connected; buffers already loaded.
// Stop resets the node timeline and clears all old scheduled signals.
func schedule(_ events: [(date: Date, sound: Sound)]) throws {
    node.stop()
    guard !events.isEmpty else { return }
    if !engine.isRunning { try engine.start() }

    // Take one date/host-clock pair; every signal uses that same origin.
    let wallNow = Date.now
    let hostNow = mach_absolute_time()
    for event in events {
        let delay = event.date.timeIntervalSince(wallNow)
        guard delay > 0, let buffer = buffers[event.sound] else { continue }
        let host = hostNow + AVAudioTime.hostTime(forSeconds: delay)
        node.scheduleBuffer(
            buffer, at: AVAudioTime(hostTime: host),
            options: [], completionHandler: nil
        )
    }
    try node.playAudio() // iOS 27 throwing start; older play() is deprecated.
}

func cancelScheduled() { node.stop() }
```

The sketch follows the host-time scheduling semantics and iOS 27 start API; it was **not compiled**. Use the actual SDK overload available in the project (`at:` or the new `atTime:`). Ordinary audio I/O/output latency can still move acoustic arrival relative to a display; do not subtract a guessed constant. If absolute alignment needs compensation, measure the active route and establish which presentation latency the timeline already accounts for. [A5, A6, A8, A9]

In `StretchPlayerScreen.swift`, schedule the plan when countdown state/phase changes, *before* the long sleep. Continue the zero-tolerance task for logic transitions and haptics, but remove the immediate sound calls from the `play(signal)` path when the scheduled path owns audio, or every signal will sound twice. Cancel/rebuild on pause/resume, skip/back, added time, background, dismissal, finish, sound-setting changes, audio interruptions and route/engine configuration changes; a finished/silent/paused plan is empty. Keep `.ambient` so the user's music/silent-switch behavior is unchanged. Avoid a cancelled old task's cleanup stopping a newly scheduled plan: prefer one lifecycle owner for cancel/reschedule, rather than unconditional task `defer` cleanup across overlapping state tasks. These are integration requirements derived from the existing control/state behavior and the node's queue semantics, not code written by this research. [L1, A5; design recommendation]

**Smaller alternative to an engine:** `AVAudioPlayer.play(atTime:)` can schedule prepared players on the device clock. The same retained tick player cannot represent five independent simultaneously queued playback requests as a documented queue; use separate tick players or a single assembled PCM sequence containing the five clicks and chime. That keeps AVAudioPlayer but needs a valid advancing device clock, queue cancellation, and sequence construction/retention. For this app, first trying explicit tolerance is smaller than either audio redesign; if independent queued events are required, a player node is the clearer documented queue. [A2, A3, A5; design comparison]

## How to verify it on a device

1. **Log the deadline and task resumption before touching audio.** For every iteration, capture the intended `wake`, the `Date.now` immediately after `Task.sleep`, `wakeErrorMs = now.timeIntervalSince(wake) * 1000`, the signal from `advance()`, and the `Date.now` immediately before calling playback. Record `ContinuousClock.now` alongside these to distinguish elapsed-time scheduling from wall-clock adjustment. Record requested sleep duration. Compare the first long sleep with the later approximately one-second sleeps; these stages are separate in the current code. [L1, S1–S4; proposed measurement]
2. **Record audio conditions.** Log whether session activation, `prepareToPlay`, and `play` succeed, plus route, `outputLatency`, and `ioBufferDuration`. Test the built-in speaker first, ringer unmuted, Timer Sounds enabled, foreground, without other audio; then with music, low-power mode, and separately headphones/Bluetooth. Keep the conditions identical for baseline and `.zero`. Route latency is a separate quantity from callback lateness. [A1, A4; proposed measurement]
3. **Measure acoustic onset, not just call time.** Externally record several consecutive holds with audio and video; detect click waveform starts and calculate each adjacent gap. The primary symptom metric is whether the first gap differs systematically from the next three and from the last tick-to-chime gap. For absolute display alignment, high-frame-rate video or another synchronized recording is needed; console call times alone cannot prove when sound reaches the listener. This is a proposed verification method, not a test performed here.
4. **Interpret the result.** A late first wake with a proportionately short first gap supports cause 1; a punctual first wake with delayed acoustic onset supports cause 2. If `.zero` reduces wake error but audio remains late, schedule ahead and repeat the same measurement rather than silently declaring the timer fix complete. [L1, S6, A1–A5; diagnostic inference]
5. **Exercise schedule invalidation if adopting queued audio.** Pause during the last five seconds, resume, add 15 seconds immediately before/after a tick, skip/back, background the app, quit, change the sound setting, and interrupt/change the route. Verify no old-phase clicks survive and no duplicates occur. Add `PhasedCountdown` public tests for planned dates, shortened phases, late entry, pause/resume and added time; ordinary unit tests cannot validate acoustic latency. [L1, A5; proposed checks]

**Not checked:** No build, simulator run, or device run; no real acoustic measurements. Exact iOS 27 dispatch behavior, a hardware-idle wake penalty, and closed-source timer implementations remain unknown. The evidence establishes the default-tolerance mechanism and rules out meaningful asset-leading silence, but device stage measurements are required to prove the root cause of this occurrence.

## Sources and reproducible measurements

### Local evidence

**[L1]** Checkout `12f160308d69a3629bef743d47aa5c085c77a764`, plus the described existing uncommitted preparation changes: `App/Views/StretchPlayerScreen.swift:52–59,65–69,91–101,199–209`; `App/Logic/PhasedCountdown.swift:71–105,108–155`; `App/Logic/TimerSounds.swift:19–38`; `scripts/make-chime.swift:13–16,56–67`. History: `git log -4 --all --oneline -- App/Logic/TimerSounds.swift` returned `12f1603 Stretching: the guided stretch player (ticket 32b)`; no prior committed timing fix appeared in that inspected history.

**[M1]** Commands: `afinfo App/Resources/timer-tick.caf`, `afinfo App/Resources/rest-chime.caf`, and the following `/usr/bin/python3` sample inspection (Python 3.9 compatible). CAF description reported `(44100.0, b'lpcm', 2, 2, 1, 1, 16)`; `afinfo` confirms Int16. The data contains a four-byte edit count before PCM.

```python
import struct
for name in ['timer-tick', 'rest-chime']:
    b = open('App/Resources/' + name + '.caf', 'rb').read()
    offset = 8
    while offset < len(b):
        kind = b[offset:offset + 4]
        size = struct.unpack('>q', b[offset + 4:offset + 12])[0]
        chunk = b[offset + 12:offset + 12 + size]
        offset += 12 + size
        if kind == b'data':
            data = chunk[4:]
    samples = struct.unpack('<' + 'h' * (len(data) // 2), data)
    for threshold in [1, 33, 328]:
        i = next(i for i, v in enumerate(samples) if abs(v) >= threshold)
        print(name, threshold, i, i / 44100 * 1000)
```

Output:

```text
timer-tick 1   1 0.022675736961451247
timer-tick 33  2 0.045351473922902494
timer-tick 328 5 0.11337868480725624
rest-chime 1   1 0.022675736961451247
rest-chime 33  3 0.06802721088435373
rest-chime 328 32 0.7256235827664399
```

`shasum -a 256` identifies the measured assets:

```text
51ce8c41aaef7d68d54d0d671909d0d9d3f6ffa23c7286ea28be0ecdf72481b5  App/Resources/timer-tick.caf
00345f1e4a1a7bbb57fd3d92281ecf2c2f59d3e396c3b7aaf670e27393ff2628  App/Resources/rest-chime.caf
```

### Swift and dispatch primary sources

- **[S1]** [Swift TaskSleepDuration.swift, pinned commit, lines 220–245](https://github.com/swiftlang/swift/blob/10973e278de2000130ddcad6384f1823dddbdd09/stdlib/public/Concurrency/TaskSleepDuration.swift#L220-L245).
- **[S2]** [Swift ContinuousClock.swift, lines 104–120](https://github.com/swiftlang/swift/blob/10973e278de2000130ddcad6384f1823dddbdd09/stdlib/public/Concurrency/ContinuousClock.swift#L104-L120).
- **[S3]** [Swift sleep scheduling/fallback, lines 120–156](https://github.com/swiftlang/swift/blob/10973e278de2000130ddcad6384f1823dddbdd09/stdlib/public/Concurrency/TaskSleepDuration.swift#L120-L156); [MainActor source](https://github.com/swiftlang/swift/blob/10973e278de2000130ddcad6384f1823dddbdd09/stdlib/public/Concurrency/MainActor.swift).
- **[S4]** [Swift DispatchGlobalExecutor.cpp, lines 311–341](https://github.com/swiftlang/swift/blob/10973e278de2000130ddcad6384f1823dddbdd09/stdlib/public/Concurrency/DispatchGlobalExecutor.cpp#L311-L341).
- **[S5]** [Apple Darwin libdispatch source.c, lines 1372–1450, pinned 2025-10-16 source](https://github.com/apple-oss-distributions/libdispatch/blob/2361ffb78a76f7ee488cd052eb0bc5c767118bf9/src/source.c#L1372-L1450).
- **[S6]** [Apple dispatch_source_set_timer documentation, discussion of leeway and latency even at zero](https://developer.apple.com/documentation/dispatch/dispatch_source_set_timer), read directly with `ketch scrape`.
- **[S7]** [Swift corelibs libdispatch source.c, pinned commit bcae6574b8e6ab2dbc5b3bcaa271cc1478e92074, lines 1338–1374](https://github.com/swiftlang/swift-corelibs-libdispatch/blob/bcae6574b8e6ab2dbc5b3bcaa271cc1478e92074/src/source.c#L1338-L1374), unconditional `delta / 10`; not a Darwin binary guarantee.
- **[S8]** [SE-0329 Clock, Instant, Duration, pinned proposal text, lines 149–158](https://github.com/swiftlang/swift-evolution/blob/01180b65b4b9c1122d4a349170059d299a03a5f8/proposals/0329-clock-instant-duration.md#L149-L158), older proposal: omitted tolerance is implementer's choice.

### Apple audio documentation, session and engineer answer

All API pages below were read directly with `ketch scrape` on 2026-10-10.

- **[A1]** [AVAudioPlayer.prepareToPlay()](https://developer.apple.com/documentation/avfaudio/avaudioplayer/preparetoplay()), including preparation being undone on completion.
- **[A2]** [AVAudioPlayer.play(atTime:)](https://developer.apple.com/documentation/avfaudio/avaudioplayer/play(attime:)), future audio-device timeline time and synchronization example.
- **[A3]** [AVAudioPlayer.deviceCurrentTime](https://developer.apple.com/documentation/avfaudio/avaudioplayer/devicecurrenttime), clock reset behavior.
- **[A4]** [AVAudioSession.outputLatency](https://developer.apple.com/documentation/avfaudio/avaudiosession/outputlatency).
- **[A5]** [AVAudioPlayerNode](https://developer.apple.com/documentation/avfaudio/avaudioplayernode), scheduling interpretation, player timeline, stop/unschedule semantics.
- **[A6]** [AVAudioPlayerNode.playAudio(at:)](https://developer.apple.com/documentation/avfaudio/avaudioplayernode/playaudio(at:)), available iOS 27.0, throwing start API.
- **[A7]** [AudioServicesPlaySystemSound(_:)](https://developer.apple.com/documentation/audiotoolbox/audioservicesplaysystemsound(_:)).
- **[A8]** [Apple sample: Building an audio sequencer to arrange and play clips](https://developer.apple.com/documentation/avfaudio/building-an-audio-sequencer-to-arrange-and-play-clips), sections “Quantize clip launches” and “Create drift-free looping”, current iOS 27-style APIs in sample code.
- **[A9]** [AVAudioNode.outputPresentationLatency](https://developer.apple.com/documentation/avfaudio/avaudionode/outputpresentationlatency), maximum downstream render-pipeline latency.
- **[W1]** [WWDC20: Meet Audio Workgroups, Doug Wyatt, Core Audio](https://developer.apple.com/videos/play/wwdc2020/10224/), **older, 2020**, transcript explanation of framework-managed realtime threads/workgroups; read directly.
- **[F1]** [Apple Developer Forums: High-precision timer, Quinn's DTS reply, August 2019](https://developer.apple.com/forums/thread/121764), **older**. Only the explicitly identified Apple engineer reply is used; the accepted answer is by a community participant and is not evidence of Swift's default tolerance. Read directly.

### Open-source timer comparisons

- **[O1]** OpenHIIT, commit `f95cf5028eeb4dd7d5255e28266e4aab540e4585`: [pubspec.lock:76–83](https://github.com/a-mabe/OpenHIIT/blob/f95cf5028eeb4dd7d5255e28266e4aab540e4585/pubspec.lock#L76-L83), [run_timer/workout.dart](https://github.com/a-mabe/OpenHIIT/blob/f95cf5028eeb4dd7d5255e28266e4aab540e4585/lib/features/run_timer/workout.dart). `gh api repos/a-mabe/OpenHIIT --jq '{created_at,stargazers_count}'` returned creation `2023-04-27`, 115 stars on research date; this describes age/adoption, not timing quality.
- **[O2]** First-party `background_hiit_timer` **1.2.3** package: [version API](https://pub.dev/api/packages/background_hiit_timer/versions/1.2.3), [exact archive](https://pub.dev/api/archives/background_hiit_timer-1.2.3.tar.gz), SHA-256 `d78169aca6a1fe2f448af7ec1fc9bd187085423e8ad90b0fdb56c7a8f24ef26f`, matching OpenHIIT lockfile. Inspected archive `lib/background_timer.dart:267–312` and `lib/utils/utils.dart:5–11`; source belongs to the app's author, repository [a-mabe/background_hiit_timer](https://github.com/a-mabe/background_hiit_timer).
- **[O3]** WorkoutTimer, commit `54af243629f23b8bec13e73e1a51e60654574031`: [TimerEngine.swift:188–212](https://github.com/wollodev/WorkoutTimer/blob/54af243629f23b8bec13e73e1a51e60654574031/Shared/Model/TimerEngine.swift#L188-L212), [ToneFeedbackChannel.swift:26–42](https://github.com/wollodev/WorkoutTimer/blob/54af243629f23b8bec13e73e1a51e60654574031/WorkoutTimeriOS/Services/ToneFeedbackChannel.swift#L26-L42), [ToneSynthesizer.swift:53–92](https://github.com/wollodev/WorkoutTimer/blob/54af243629f23b8bec13e73e1a51e60654574031/WorkoutTimeriOS/Services/ToneSynthesizer.swift#L53-L92). GitHub API returned creation 2026-03-28, one star; not presented as established.
- **[O4]** LoopTimer, commit `4af38252b222aacb8af4fcddd63ddc00d06456a3`: [TimerService.swift](https://github.com/monsur/LoopTimer/blob/4af38252b222aacb8af4fcddd63ddc00d06456a3/LoopTimer/Services/TimerService.swift), [AudioService.swift:63–71](https://github.com/monsur/LoopTimer/blob/4af38252b222aacb8af4fcddd63ddc00d06456a3/LoopTimer/Services/AudioService.swift#L63-L71). GitHub API returned creation 2026-01-18, zero stars; not presented as established.

## Outcome (2026-10-10, measured on the iPhone)

Logged wake lateness with devicectl --console. Default tolerance: the first-tick wake after a 25 s sleep came 742 and 743 ms late, 1 s sleeps 10–77 ms. With `tolerance: .zero`: every wake 0–4 ms late, and the user heard the ticks on the beat. Shipped the zero-tolerance fix in the stretch player and the rest timer; the audio redesign was not needed.
