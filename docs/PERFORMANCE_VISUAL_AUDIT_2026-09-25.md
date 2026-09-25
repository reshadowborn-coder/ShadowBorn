# Shadowborn Performance & Visual Consistency Audit — 2026-09-25

## Scope

This audit targets the current Godot 4.4.1 Act 0 implementation with iPhone/iOS as the primary platform and iPhone 13 Pro as the reference 60 FPS device.

The audit intentionally separates:
- safe runtime/code-quality fixes,
- visual-consistency fixes,
- provisional performance guardrails,
- gameplay/content migrations that require their own compatibility plan.

## Fixed on this branch

### 1. Reduced Motion changed composition instead of only motion

Before this branch, combat and reveal modes used different camera offset, rotation and FOV when Reduced Motion was enabled. That changed information framing and silhouette readability for accessibility users.

Resolution:
- normal and Reduced Motion now share the same combat/reveal framing constants,
- Reduced Motion removes transition travel by snapping to the same framing,
- CI now verifies offset, rotation and FOV parity.

### 2. Impact VFX allocated a new scene node on every contact

Impact mesh/material resources were cached, but every contact still created a new MeshInstance3D and queue-freed it after the tween.

Resolution:
- a small bounded pool of impact nodes is preallocated,
- mesh/material resources remain cached,
- repeated contacts reuse nodes and tweens,
- impact flashes do not cast shadows,
- CI verifies repeated impacts do not grow the scene tree.

### 3. iPhone policy fixture did not match the selected iPhone 13 Pro target

The safe-area unit fixture still used a 2796x1290 physical screen even after iPhone 13 Pro became the project reference.

Resolution:
- the representative target fixture now uses 2532x1170 physical pixels,
- the test is explicitly labelled as a representative iPhone 13 Pro fixture,
- runtime DisplayServer safe-area data remains authoritative on device.

### 4. Engine boot and LaunchShell background colors drifted

The engine boot background and LaunchShell background used two different near-black colors, producing an unnecessary OLED luminance/color step on startup.

Resolution:
- LaunchShell uses the exact authored boot background color,
- iPhone policy CI checks the match.

### 5. Runtime geometry budget mixed resource memory with render work

The previous budget test counted vertex/index data only once per unique mesh resource. That is useful for loaded-resource size, but reused mesh instances still incur per-instance rendering work.

Resolution:
- unique resource vertices/indices are tracked separately,
- per-instance vertex/index references are tracked,
- rendered mesh-surface count is tracked,
- broad CI guardrails are explicitly marked provisional until physical iPhone 13 Pro calibration.

### 6. Starter weapon support could drift across systems without detection

Starter families are declared independently in Act0Contract, Act0Progression, ShadowLoadout, Covenant UI metadata and ShadowProxy visuals.

Resolution:
- a CI contract test compares contract/progression/loadout/UI family sets,
- it instantiates every starter family in ShadowProxy and requires visible proxy geometry.

## Open inconsistencies / follow-up work

### A. Dual Daggers conflicts with the current production-3D contract

The playable Act 0 implementation currently exposes and balances:
- sword_shield
- bow
- two_hand_axe
- dual_daggers
- mage_staff

The current production research contract marks dual-wield daggers as future-only until a dedicated dual-wield animation, grip, sheath and self-clearance profile exists.

This branch does **not** silently replace dual_daggers because that would change:
- existing saves,
- forged item IDs,
- balance profiles,
- Catacomb playability fixtures,
- proxy visuals,
- UI choice semantics.

Required follow-up:
1. choose the canonical replacement/migration policy,
2. migrate saved `weapon_family=dual_daggers`,
3. update Act0Contract/Act0Progression/ShadowLoadout/UI/ShadowProxy/tests atomically,
4. add single-dagger production animation/grip/clearance evidence before promotion.

### B. Chapter00Game is a responsibility hotspot

Chapter00Game currently coordinates save/lifecycle, combat, navigation, Temple interactions, Room 5 orchestration, UI gating, equipment application, camera presentation and iOS memory/suspend handling.

This is covered by substantial tests, so a large refactor should not be mixed into performance fixes.

Recommended extraction order:
1. lifecycle/save adapter,
2. Room 5 encounter coordinator,
3. Temple interaction coordinator,
4. presentation/navigation coordinator.

Keep the current class as facade until extracted services pass the existing deterministic fixtures.

### C. Modal blocker/style setup is duplicated

SettingsMenu and CovenantMenu independently construct the same full-screen 45% black modal blocker. UI visual tokens are also spread between scenes and scripts.

Recommended follow-up:
- introduce a small UI visual-token/helper layer,
- centralize blocker opacity, panel colors, border/highlight states and typography constants,
- preserve screen-specific layout in the owning UI.

### D. Graybox HUD still uses mostly default Godot control styling

The gameplay world has a deliberate cold dark-fantasy palette, while several HUD panels/buttons still rely on default engine visuals.

This is acceptable for a graybox but is a visible style inconsistency and should not survive the art-target pass.

Recommended follow-up:
- define one Shadowborn UI theme resource,
- keep combat readability/state colors independent from decoration,
- screenshot-regress iPhone 13 Pro landscape layouts before promotion.

### E. Performance budgets are still CI guardrails, not measured device limits

Current numeric limits protect against accidental growth but are not claims about A15 hardware capability.

Authority order:
1. packaged build on physical iPhone 13 Pro,
2. Xcode/Metal + Godot timing/memory evidence,
3. CI regression budgets calibrated from those measurements.

## Regression tests added

- `tests/perf_visual_consistency_tests.gd`
- `tests/starter_weapon_visual_contract_tests.gd`

Updated:
- `tests/ios_iphone_policy_tests.gd`
- `tests/ios_runtime_budget_tests.gd`

The CI workflow runs these alongside existing deterministic, iPhone policy, asset budget, runtime budget and platform export tests.
