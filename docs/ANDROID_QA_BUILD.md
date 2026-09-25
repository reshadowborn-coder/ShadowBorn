# Android Act 0 QA build

This preset exists only to make the current physical Act 0 test reproducible. It is not the production package identity.

Preset: `Android QA`  
Package: `org.shadowborn.chapter0.qa`  
Architecture: ARM64 only  
Output: `build/android/Shadowborn-Act0-QA.apk`

## Local requirements

Godot 4.4 Android export requires the Android export templates plus an Android SDK/JDK setup. Godot 4.4 documentation recommends OpenJDK 17 for Android export.

After Android export is configured in the Godot editor, the checked-in preset is marked Runnable, so a connected USB or wireless-ADB device can use one-click deploy.

Verify the device first:

```bash
adb devices
```

Then either use Godot one-click deploy, or export a debug APK:

```bash
godot --path . --export-debug "Android QA" build/android/Shadowborn-Act0-QA.apk
```

The editor binary must have matching 4.4.x Android export templates installed.

## Physical combat trace

Normal trace build uses:

```
debug/shadowborn/combat_trace_console=true
```

For the matched observer-effect baseline, set that project setting to `false` before exporting the quiet APK, or launch a supported local build with:

```
-- --shadowborn-trace-quiet
```

Do not compare a release build against a debug trace build for observer-effect conclusions; use equivalent QA/debug builds and change only trace console output.

Continue with `docs/PHYSICAL_COMBAT_QA.md` for the 60/30 FPS + Reduced Motion capture matrix.

## Boundary

A checked-in preset proves reproducible export configuration only. It does not prove:
- the current machine has Android SDK/JDK/export templates installed;
- the APK exported successfully;
- install/start works on a physical phone;
- frame pacing or readability passes.

Those remain explicit execution evidence.


## CI APK artifact

The Act 0 workflow contains a separate `android-qa-apk` job after the strict headless suite. It installs the Godot 4.4.1 export templates and the Godot 4.4 Android toolchain requirements, exports the checked-in `Android QA` preset, and verifies:

- package ID is `org.shadowborn.chapter0.qa`;
- the APK contains ARM64 native libraries;
- ARMv7, x86 and x86_64 native library folders are absent;
- the APK has a recorded SHA-256.

A successful job uploads `shadowborn-act0-android-qa` as a short-lived GitHub Actions artifact. This proves the repository can produce the QA APK from a clean CI checkout. It still does not prove install/start, physical frame pacing, touch feel or blind readability on a phone.
