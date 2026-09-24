# Chapter 0 — Visual pass v0.8

Goal: move the first route away from a cube-only graybox without increasing mobile cost blindly.

Implemented:
- shared cached materials in the procedural builder instead of a new StandardMaterial3D per prop;
- sparse rock/moss/dead-tree framing while preserving a clean combat corridor;
- broken forecourt columns to stage the temple reveal;
- stronger temple silhouette with ruined dark-red roof planes, entry columns and lintel;
- existing single directional shadow light retained; no extra realtime shadow lights added.

Working mobile budget for this slice (validation target, not measured runtime yet):
- 1 important realtime shadow-casting directional light;
- <= 8 shared graybox material families before authored assets;
- avoid transparent foliage/fog cards in dense stacks;
- prefer large silhouette props over micro-clutter;
- 30/60 FPS must preserve identical combat state transitions;
- authored asset pass must profile draw calls, triangles, overdraw, GPU frame time and thermals on Android hardware.

Not validated in Godot runtime in this environment. ZIP/static structure checks do not substitute for device profiling.
