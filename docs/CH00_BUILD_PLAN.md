# Shadowborn — Chapter 0 first location

Route: Awakening -> ruined cemetery -> Skeleton Hound -> broken stair/ruins -> Armless Skeleton -> Temple reveal -> Shield Skeleton -> Temple gate.

## Performance contract
- Mobile renderer first.
- 60 FPS target, 30 FPS battery option.
- Baked/static lighting for environment; one important dynamic shadow light max in the graybox target.
- Opaque/alpha-scissor materials preferred; avoid stacked transparency/fog cards.
- Modular stone kit, shared materials, atlases, LODs for distant silhouettes.
- Collision only on playable surfaces and meaningful blockers.
- Decorative skyline is non-playable proxy geometry/impostors.

## Next implementation pass
1. Split route into streaming cells CEM_01, RUIN_01, TEMPLE_EXT_01.
2. Build camera volumes and composition anchors.
3. Add encounter gates for Hound, Armless, Shield Boss.
4. Add mobile combat HUD A1/A2 + target selection.
5. Implement Shield Guard telegraph BEFORE the first decision that can spend A2.
6. Add checkpoint/retry and atomic save snapshot.
7. Profile on real Android/iOS hardware before art-density increase.
