# Physical combat presentation QA

Purpose: execute `T_CH00_CONTACT_FRAME_PARITY_V01` without changing combat balance.

The debug build emits structured `SB_TRACE` JSON for:
- command commit;
- presentation start;
- semantic contact;
- combat-state projection;
- HUD property update;
- impact VFX creation;
- recovery unlock;
- first eligible Godot render frame after each event.

This instrumentation is observability only. The deterministic resolver remains authoritative.

## Required matrix

Run the representative Hound / Armless / Shield contacts in four presentation modes:
1. 60 FPS, normal motion;
2. 30 FPS, normal motion;
3. 60 FPS, Reduced Motion;
4. 30 FPS, Reduced Motion.

Use at least 20 repetitions for each representative contact path after warm-up. Keep the deterministic encounter/script version unchanged.

For Shield, preserve the D1 visible Guard decision and record the HOLD line separately from the deliberate A2-into-Guard line. Veil 15% vs 20% remains a separate A/B build/configuration; do not change the value during one capture series.

## Capture Godot trace on Android

Clear prior logs, then start logcat using the Android monotonic clock and microsecond precision:

```bash
adb logcat -c
adb logcat -v monotonic -v usec | grep SB_TRACE > shadowborn_trace.log
```

The external logcat timestamp is time-since-boot. Each JSON row also contains Godot's monotonic `Time.get_ticks_usec()` timestamp. Keep both: the pair provides a correlation anchor between engine-relative timing and Android system timing.

Do not use wall-clock time for latency calculations.

## Capture physical frame pacing

Before the measured segment:

```bash
adb shell dumpsys SurfaceFlinger --timestats -clear -enable
```

Run the selected test segment, then dump:

```bash
adb shell dumpsys SurfaceFlinger --timestats -dump > surfaceflinger_timestats.txt
```

Filter the output to the game's rendered layer. Record average FPS and the present-to-present interval distribution. For a deeper capture, use Android Performance Analyzer / Perfetto and inspect `actual_frame_timeline_slice` / actual display-update timestamps.

A configured `Engine.max_fps = 30` or `60` is only the requested game cadence. It is not proof that the physical display presented frames at that same cadence.

## Evidence classification

Combat-semantic failure:
- damage, HP, status, Guard, Fray, Veil or cooldown outcome differs by FPS/motion mode;
- semantic event order changes.

Engine-presentation failure:
- HUD/VFX update misses the first eligible engine-rendered frame after semantic contact without an authored reason;
- recovery unlock occurs before the required feedback.

Frame-pacing/performance failure:
- SurfaceFlinger/Perfetto shows repeated, missed or irregular physical presents around an otherwise-correct engine trace;
- requested 30/60 mode is not sustained under the measured device conditions.

Human-readability failure:
- a blind first-time tester does not recognize Shield Guard before input;
- the tester cannot explain why HOLD/A1 preserves A2;
- Veil 15% vs 20% is not perceptibly distinguishable when the technical trace is correct.

Do not fix a human-readability failure by changing combat coefficients until semantic, engine-frame and physical-frame evidence are clean.

## Current instrumentation boundary

The current trace records HUD and VFX timing but reports `sfx=false` in `trace_capabilities` because the current graybox has no combat SFX timing path wired into this contract. Add SFX instrumentation when combat audio exists; do not fabricate an SFX timestamp now.

## References

- Godot 4.4 RenderingServer `frame_pre_draw` / `frame_post_draw`
- Godot Time `get_ticks_usec()` monotonic timing
- Android Logcat `monotonic` and `usec` modifiers
- Android game frame-rate measurement with SurfaceFlinger / Android Performance Analyzer


## Observer-effect control

The trace is a measurement tool and must not be assumed free. Console JSON output can itself add CPU/I/O pressure.

Before interpreting a device result, run a matched A/B on the same device and scene:
- A: normal debug capture with `CombatFrameTrace.console_output = true`;
- B: identical debug build/path with `console_output = false` while keeping the same gameplay/presentation code.

The quiet trace still completes rows in memory through `row_completed`; only console serialization/output is removed.

Do not accept a contact-latency or frame-pacing conclusion if enabling live console output introduces additional missed/repeated presents or a new hitch cluster that is absent in the quiet baseline. In that case, treat live logging as intrusive and use buffered/quiet evidence plus external Perfetto/SurfaceFlinger capture.

CI now runs `tests/combat_frame_trace_tests.gd` to prove that trace rows preserve payload/context, bind pending events to the next eligible engine frame, capture state projection/recovery, and do not mutate observed combat state. This is schema/invariant evidence only; it does not replace the physical A/B.
