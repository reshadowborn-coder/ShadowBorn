# Chapter 0 Playable v0.6 — persistence pass

Implemented:
- versioned JSON save at user://chapter00_save.json
- temp-file + rename commit to reduce partial-save risk
- checkpoint position + route index persistence
- cleared encounter ledger; defeated encounters do not retrigger after restart
- defeated enemy proxy visuals hidden on load
- 30 Battery / 60 Smooth runtime cap persisted in save schema
- invalid/missing save falls back to deterministic Chapter 0 defaults

Validation status:
- source/archive structure checked in the workspace
- Godot runtime execution is NOT yet verified in this environment
- atomic-save crash/fault-injection tests remain required on a real Godot runtime/device
