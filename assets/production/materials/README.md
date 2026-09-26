# ACT 0 production materials

This folder is reserved for approved runtime PBR material families.

## Cemetery wet cobble

Acquire the current candidate with:

```bash
python3 tools/acquire_polyhaven_texture.py
```

Expected runtime files:

- `cemetery_wet_cobble/cobblestone_01_diff_2k.png`
- `cemetery_wet_cobble/cobblestone_01_nor_gl_2k.png`
- `cemetery_wet_cobble/cobblestone_01_arm_2k.png`
- `cemetery_wet_cobble/SOURCE.json`

The Godot material library automatically uses these maps when all three exist.
Otherwise the current procedural graybox material remains active.

Do not add 4K/8K runtime maps by default. Camera-first review and physical iPhone
profiling are required before increasing texture resolution.

Source candidate: Poly Haven Cobblestone 01, CC0.
