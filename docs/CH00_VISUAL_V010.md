# Chapter 0 visual prototype v0.10

## Implemented
- VisualGeometry and GameplayCollision are separate runtime roots.
- Cemetery boundary walls now have explicit StaticBody3D blockers independent of render meshes.
- Replaced repeated slab graves with a small modular grave assembly (base/marker/cap).
- Replaced forecourt box-columns with reusable broken-column assemblies and a fallen column.
- Shadow proxy proportions refined for a stronger mobile silhouette; proxy now reuses its materials.

## Production rule
Future art replacement should target VisualGeometry while preserving gameplay triggers/collision. Collision remains intentionally simple and must not mirror decorative mesh detail.

## Still graybox/proxy
No claim of final art, final materials, final lighting, or device performance. Godot runtime validation remains required.
