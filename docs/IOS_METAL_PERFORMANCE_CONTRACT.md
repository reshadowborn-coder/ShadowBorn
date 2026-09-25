# iOS / Metal performance contract

Status: research-backed engineering contract. Physical-device validation is still required.

## Product authority

- Primary reference device: iPhone 13 Pro.
- Primary shipping target: iOS/iPhone.
- Renderer: Godot Mobile rendering method on native Metal.
- Product frame modes: 60 FPS target and 30 FPS fallback.
- 120 FPS is not a v1 target even though iPhone 13 Pro has ProMotion.
- Gameplay simulation, combat timing, cooldowns, AI and saves must never depend on rendered-frame count.

## Frame pacing

A frame-rate request is a preference, not a guarantee. iOS can change available presentation cadence because of thermal state, Low Power Mode, accessibility settings and device capabilities.

Acceptance therefore uses measured presentation cadence and frame-time distribution, not the configured FPS value alone.

60 FPS budget: 16.67 ms.
30 FPS budget: 33.33 ms.

Record average plus P90/P99 and visible hitch count. A stable 30 is preferable to oscillation around an unsustainable 60. Never switch gameplay semantics when presentation cadence changes.

## Thermal state policy

Long-session testing is mandatory. The reference loop must include repeated combat, Temple traversal, VFX stress, save/resume and camera movement.

Quality adaptation order is evidence-driven, but only cosmetic/rendering cost may degrade. Candidate levers:
1. cosmetic particle density and translucent overdraw;
2. shadow distance/caster density;
3. world render scale;
4. reflection/post-processing extras;
5. distant environment detail.

Never remove Guard/Break/Mark/status readability, enemy tells, interaction state, UI semantics or required navigation cues.

Use hysteresis: do not bounce quality tiers from short spikes. A serious thermal condition may select the 30 FPS fallback, but combat time remains wall/simulation-time based.

## Metal/Godot compatibility gate

Godot's native Metal path is a real platform dependency and must be version-pinned and regression-tested. Renderer upgrades are not routine dependency bumps.

For every Godot upgrade:
1. build a clean iOS export;
2. run with Metal API Validation in Xcode;
3. run without validation on the physical device;
4. cold-launch and exercise all gameplay-critical materials/shaders;
5. background/foreground during active audio;
6. execute the Chapter 0 stress route;
7. compare screenshots and frame traces against the accepted engine version.

Do not promote a Godot version if an iOS/Metal regression is open for a feature Shadowborn uses.

## Cold shader / first-use gate

Warm-cache FPS is insufficient evidence. Acceptance starts from a clean/cold state where practical.

Critical first-use states include:
- Shadow body/armor material;
- Hound reveal and attacks;
- Skeleton Lunge;
- Shield Guard/Bash;
- Sigil/Ward;
- Temple reveal;
- common particles and transparent materials.

A first-use hitch on a tutorial decision beat is a P0 defect. Prefer targeted preparation and material simplification over global warmup that increases startup time or memory.

## GPU investigation ladder

When a frame misses budget:
1. determine CPU-bound vs GPU-bound;
2. identify the semantic beat and camera state;
3. inspect render-pass cost and screen coverage;
4. inspect translucency/overdraw;
5. inspect shadows and lights;
6. inspect texture bandwidth/residency;
7. inspect shader/material variants;
8. inspect geometry/visibility;
9. change one lever and recapture.

On Apple GPUs, Metal counter sampling can provide stage/command-boundary evidence where supported. Counter support must be queried rather than assumed.

## Lifecycle/audio regression gate

iOS background/foreground is part of the normal game loop. Test launch under abnormal audio conditions, background/foreground, interruption, route change and resume while several one-shot SFX are active.

The game state is checkpoint-authoritative. Transient renderer/audio resources may be recreated; rewards and combat progression may not duplicate or advance unseen.

## Required device evidence

No performance claim is final until a packaged build has run on physical iPhone 13 Pro.

Each capture records:
- build commit;
- Godot version;
- iOS version;
- device model;
- quality preset;
- requested FPS;
- actual cadence/frame-time distribution;
- thermal state;
- memory high-water;
- cold/warm state;
- semantic beat markers.

## Current implementation consequence

The existing project setting `window/ios/allow_high_refresh_rate=false` is intentionally compatible with the v1 60/30 product contract. Do not enable 120 Hz merely because the hardware supports it. Revisit only after 60 FPS thermal stability is proven.

## Primary evidence

- Apple Developer: CADisplayLink preferredFrameRateRange — choose a range the app can consistently maintain; system policy, Low Power Mode, thermal state and accessibility can change availability.
- Apple WWDC21: Optimize for variable refresh rate displays — query actual cadence at runtime, use display-link timing, and remain correct when cadence changes.
- Apple Metal documentation: GPU counter sample buffers — query supported counter sampling points and resolve counter data for profiling.
- Godot rendering architecture: native Metal supports Mobile and Forward+; Godot 4.7 uses Metal 4 on iOS 26+ and falls back to Metal 3 on older systems.
- Godot issue #116090: iOS Mobile renderer Metal API Validation regression in 4.6, fixed for the 4.7 milestone.
- Godot issue #120842: open iOS CoreAudio focus-in concurrency crash report affecting 4.6/4.7-era production builds; treat lifecycle/audio as an explicit regression test until resolved.

No proprietary code or art is copied by this document.
