# Chapter 0 Playable v0.7

## Added
- Persistent Settings overlay with explicit 30 FPS Battery / 60 FPS Smooth modes.
- Performance selection writes through the Chapter 0 save contract.
- Combat simulation remains independent from presentation frame cap.
- Replaced visible player capsule with a low-cost humanoid Shadow proxy.
- Proxy uses only primitive meshes/materials; no cloth simulation, skinning, transparency or expensive shader work.

## Still blocked
No Godot executable is available in the current runtime, so engine parse/runtime validation and device profiling are still required.
