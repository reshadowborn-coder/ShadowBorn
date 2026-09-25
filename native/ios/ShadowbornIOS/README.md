# ShadowbornIOS native bridge

This directory contains the source contract for Shadowborn's iOS-only native bridge.

## Architecture boundary

The native bridge is intentionally narrow. It exposes Apple platform facts and presentation-only actions:

- thermal state
- Low Power Mode
- haptic capability and semantic haptic dispatch
- diagnostic metadata

It must never contain combat rules, Chapter/Act progression, save-field knowledge, item rules, AI decisions or economy logic.

Godot-side gameplay talks to `PlatformRuntimeService`; that service may use the `ShadowbornIOS` singleton when present and degrades safely when it is absent.

## Godot compatibility

The production project is pinned to Godot 4.4.1. Native plugin binaries must be built against headers generated from the same engine version as the iOS export template. Do not reuse a binary built against a different Godot revision.

The checked-in `.gdip.in` is a template only and intentionally lives outside `res://ios/plugins`. This prevents Godot from detecting a plugin for which no verified binary exists.

After a verified build, copy:

- `ShadowbornIOS.debug.xcframework`
- `ShadowbornIOS.release.xcframework`
- `ShadowbornIOS.gdip`

into `res://ios/plugins/shadowborn_ios/` and enable the plugin in the iPhone export preset.

## Haptics

Gameplay uses semantic IDs, not UIKit styles. The bridge keeps persistent `UIImpactFeedbackGenerator` instances and reuses them. This avoids the simple but wasteful pattern of allocating a new generator for every contact.

Current semantic families:
- light: ui_confirm, light_contact
- medium: ui_reject, guarded_contact, perfect_timing, rune_complete
- heavy: guard_break, heavy_impact, summon_commit

The Godot service performs rate limiting and global intensity policy. Richer Core Haptics patterns can replace individual mappings later without changing gameplay code.

## Game Mode

`LSSupportsGameMode` is owned by the Godot iOS export preset, not by this native plugin. That keeps Info.plist policy stable even before the native bridge binary is installed.

## Source references

Architecture and build shape were studied from Godot's MIT-licensed iOS plugin repository and current Godot iOS plugin documentation. Haptic API design was also compared with the MIT-licensed `kyoz/godot-haptics` implementation. Shadowborn's source here is independently authored for this project rather than copied wholesale.

## Status

SOURCE CONTRACT / NOT YET PRODUCTION BINARY.

Promotion requires:
1. Godot 4.4.1 header-compatible build.
2. Debug and Release XCFrameworks.
3. Xcode compile in CI.
4. Physical iPhone 13 Pro thermal/haptic/Low Power validation.
5. No gameplay-semantic differences when the native bridge is absent.
