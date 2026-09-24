class_name Ch00CombatModel
extends RefCounted

const K_DEF := 100.0
const SHADOW_ATK := 22.0
const SHADOW_DEF := 18.0
const A1_COEFF := 1.0
const A2_COEFF := 1.30
const A2_COOLDOWN := 3
const FRAY_DEF_REDUCTION := 0.10
const GUARD_MULT := 0.40

var encounter_script_id := ""
var veil_strength := 0.15
var decision := 0
var terminal := "CONTINUE"
var shadow := {}
var enemy := {}
var encounter_beats: Array = []

static func damage(atk: float, coeff: float, defense: float, state_mult: float = 1.0) -> float:
	return atk * coeff * (K_DEF / (K_DEF + maxf(defense, 0.0))) * state_mult

func setup(script_id: String, veil: float) -> bool:
	var profile := _profile(script_id)
	if profile.is_empty():
		return false
	encounter_script_id = script_id
	veil_strength = veil
	decision = 0
	terminal = "CONTINUE"
	shadow = {
		"hp": float(profile["shadow_hp"]),
		"max_hp": float(profile["shadow_hp"]),
		"atk": SHADOW_ATK,
		"def": SHADOW_DEF,
		"a2_cd": 0,
		"fray": false,
		"veil": false
	}
	enemy = {
		"hp": float(profile["enemy_hp"]),
		"max_hp": float(profile["enemy_hp"]),
		"atk": float(profile["enemy_atk"]),
		"def": float(profile["enemy_def"])
	}
	encounter_beats = profile["script"].duplicate(true)
	return true

func snapshot() -> Dictionary:
	var visible_state := "TERMINAL"
	var guard := false
	var intent := ""
	if terminal == "CONTINUE" and decision < encounter_beats.size():
		var beat: Dictionary = encounter_beats[decision]
		visible_state = str(beat.get("visible_state", "OPEN"))
		guard = bool(beat.get("guard", false))
		if visible_state == "RUSH_PREP_VISIBLE":
			intent = "RUSH PREP"
	return {
		"terminal": terminal,
		"decision": decision,
		"visible_state": visible_state,
		"shadow": {
			"hp": float(shadow.get("hp", 0.0)),
			"max_hp": float(shadow.get("max_hp", 0.0)),
			"atk": float(shadow.get("atk", SHADOW_ATK)),
			"def": float(shadow.get("def", SHADOW_DEF)),
			"a2_cd": int(shadow.get("a2_cd", 0)),
			"fray": bool(shadow.get("fray", false)),
			"veil": veil_strength if bool(shadow.get("veil", false)) else 0.0
		},
		"enemy": {
			"hp": float(enemy.get("hp", 0.0)),
			"max_hp": float(enemy.get("max_hp", 0.0)),
			"atk": float(enemy.get("atk", 0.0)),
			"def": float(enemy.get("def", 0.0)),
			"guard": guard,
			"intent": intent
		}
	}

func step(action: String) -> Dictionary:
	if terminal != "CONTINUE":
		return {"error": "encounter_already_terminal"}
	if decision >= encounter_beats.size():
		return {"error": "script_exhausted"}
	if action != "A1" and action != "A2":
		return {"error": "invalid_action"}
	if action == "A2" and int(shadow["a2_cd"]) > 0:
		return {"error": "a2_not_ready"}

	var beat: Dictionary = encounter_beats[decision]
	decision += 1

	var shadow_hp_before := float(shadow["hp"])
	var enemy_hp_before := float(enemy["hp"])
	var cd_before := int(shadow["a2_cd"])
	var fray_before := bool(shadow["fray"])
	var veil_before := bool(shadow["veil"])
	var guard := bool(beat.get("guard", false))
	var visible_state := str(beat.get("visible_state", "OPEN"))

	var effective_def := float(enemy["def"])
	if fray_before:
		effective_def *= (1.0 - FRAY_DEF_REDUCTION)

	var coeff := A1_COEFF if action == "A1" else A2_COEFF
	var state_mult := GUARD_MULT if guard else 1.0
	var outgoing := damage(SHADOW_ATK, coeff, effective_def, state_mult)
	enemy["hp"] = float(enemy["hp"]) - outgoing

	# A hit consumes an existing Fray; A1 then reapplies it for the next Shadow hit.
	if fray_before:
		shadow["fray"] = false
	if action == "A1":
		shadow["fray"] = true
		if int(shadow["a2_cd"]) > 0:
			shadow["a2_cd"] = int(shadow["a2_cd"]) - 1
	else:
		shadow["veil"] = true
		shadow["a2_cd"] = A2_COOLDOWN

	var post_action_shadow := {
		"hp": float(shadow.get("hp",0.0)),
		"max_hp": float(shadow.get("max_hp",0.0)),
		"atk": float(shadow.get("atk",SHADOW_ATK)),
		"def": float(shadow.get("def",SHADOW_DEF)),
		"a2_cd": int(shadow.get("a2_cd",0)),
		"fray": bool(shadow.get("fray",false)),
		"veil": veil_strength if bool(shadow.get("veil",false)) else 0.0
	}
	var post_action_enemy := {
		"hp": float(enemy.get("hp",0.0)),
		"max_hp": float(enemy.get("max_hp",0.0)),
		"atk": float(enemy.get("atk",0.0)),
		"def": float(enemy.get("def",0.0)),
		"guard": guard,
		"intent": "RUSH PREP" if visible_state == "RUSH_PREP_VISIBLE" else ""
	}

	var enemy_action := "NONE"
	var incoming := 0.0
	var veil_prevented := 0.0

	if float(enemy["hp"]) <= 0.0:
		terminal = "WIN"
	else:
		enemy_action = str(beat.get("enemy_action", "NONE"))
		var enemy_coeff := float(beat.get("enemy_coeff", 0.0))
		if enemy_coeff > 0.0:
			var base_incoming := damage(float(enemy["atk"]), enemy_coeff, SHADOW_DEF)
			if bool(shadow["veil"]):
				incoming = base_incoming * (1.0 - veil_strength)
				veil_prevented = base_incoming - incoming
				shadow["veil"] = false
			else:
				incoming = base_incoming
			shadow["hp"] = float(shadow["hp"]) - incoming
		else:
			# Veil is a one-response-window effect. A non-damaging enemy beat
			# provides no mitigation and the effect is gone before the next decision.
			shadow["veil"] = false

		if float(shadow["hp"]) <= 0.0:
			terminal = "LOSE"

	return {
		"encounter_script_id": encounter_script_id,
		"decision": decision,
		"visible_state": visible_state,
		"shadow_hp_before": shadow_hp_before,
		"enemy_hp_before": enemy_hp_before,
		"a2_cd_before": cd_before,
		"fray_before": fray_before,
		"veil_before": veil_before,
		"action": action,
		"outgoing_damage": outgoing,
		"enemy_action": enemy_action,
		"incoming_damage": incoming,
		"veil_prevented": veil_prevented,
		"shadow_hp_after": float(shadow["hp"]),
		"enemy_hp_after": float(enemy["hp"]),
		"a2_cd_after": int(shadow["a2_cd"]),
		"fray_after": bool(shadow["fray"]),
		"veil_after": bool(shadow["veil"]),
		"terminal": terminal,
		"post_action_shadow": post_action_shadow,
		"post_action_enemy": post_action_enemy
	}

static func _profile(script_id: String) -> Dictionary:
	match script_id:
		"ENC_HOUND_A1A2_V01":
			return {
				"shadow_hp": 80.0,
				"enemy_hp": 105.0,
				"enemy_atk": 28.0,
				"enemy_def": 8.0,
				"script": [
					{"visible_state":"OPEN","guard":false,"enemy_action":"BITE","enemy_coeff":0.90},
					{"visible_state":"OPEN","guard":false,"enemy_action":"RUSH_PREP","enemy_coeff":0.0},
					{"visible_state":"RUSH_PREP_VISIBLE","guard":false,"enemy_action":"RUSH","enemy_coeff":1.45},
					{"visible_state":"OPEN","guard":false,"enemy_action":"BITE","enemy_coeff":0.90},
					{"visible_state":"OPEN","guard":false,"enemy_action":"BITE","enemy_coeff":0.90}
				]
			}
		"ENC_ARMLESS_A1A2_V01":
			return {
				"shadow_hp": 60.0,
				"enemy_hp": 82.0,
				"enemy_atk": 22.0,
				"enemy_def": 14.0,
				"script": [
					{"visible_state":"OPEN","guard":false,"enemy_action":"BONE_LUNGE","enemy_coeff":0.92},
					{"visible_state":"OPEN","guard":false,"enemy_action":"BONE_LUNGE","enemy_coeff":0.92},
					{"visible_state":"OPEN","guard":false,"enemy_action":"BONE_LUNGE","enemy_coeff":0.92},
					{"visible_state":"OPEN","guard":false,"enemy_action":"BONE_LUNGE","enemy_coeff":0.92},
					{"visible_state":"OPEN","guard":false,"enemy_action":"BONE_LUNGE","enemy_coeff":0.92}
				]
			}
		"ENC_SHIELD_BRACE_V02_HP87_ATK20":
			return {
				"shadow_hp": 60.0,
				"enemy_hp": 87.0,
				"enemy_atk": 20.0,
				"enemy_def": 20.0,
				"script": [
					{"visible_state":"GUARD_VISIBLE","guard":true,"enemy_action":"BRACE_EXIT","enemy_coeff":0.0},
					{"visible_state":"OPEN","guard":false,"enemy_action":"BASH","enemy_coeff":1.0},
					{"visible_state":"OPEN","guard":false,"enemy_action":"BASH","enemy_coeff":1.0},
					{"visible_state":"OPEN","guard":false,"enemy_action":"HEAVY","enemy_coeff":1.15},
					{"visible_state":"OPEN","guard":false,"enemy_action":"BASH","enemy_coeff":1.0}
				]
			}
	return {}
