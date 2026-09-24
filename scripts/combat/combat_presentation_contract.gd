class_name CombatPresentationContract
extends RefCounted

const INTER_BEAT_GAP := 0.18
const REDUCED_INTER_BEAT_GAP := 0.04
const REDUCED_RECOVERY := 0.08

static func shadow_timing(skill: String, reduced_motion: bool = false) -> Dictionary:
	if reduced_motion:
		return {"anticipation":0.0,"active":0.0,"contact":0.0,"recovery_end":REDUCED_RECOVERY}
	if skill == "A2":
		return {"anticipation":0.09,"active":0.08,"contact":0.17,"recovery_end":0.32}
	return {"anticipation":0.09,"active":0.10,"contact":0.19,"recovery_end":0.34}

static func enemy_timing(action: String, reduced_motion: bool = false) -> Dictionary:
	if reduced_motion:
		return {"anticipation":0.0,"active":0.0,"contact":0.0,"recovery_end":REDUCED_RECOVERY}
	if action in ["RUSH_PREP","BRACE_EXIT","NONE"]:
		return {"anticipation":0.14,"active":0.0,"contact":0.0,"recovery_end":0.30}
	return {"anticipation":0.08,"active":0.10,"contact":0.18,"recovery_end":0.30}

static func inter_beat_gap(reduced_motion: bool = false) -> float:
	return REDUCED_INTER_BEAT_GAP if reduced_motion else INTER_BEAT_GAP

static func remainder_after_contact(timing: Dictionary) -> float:
	return maxf(0.0, float(timing.get("recovery_end",0.0)) - float(timing.get("contact",0.0)))
