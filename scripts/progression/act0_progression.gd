class_name Act0Progression
extends Node

signal stage_changed(stage: String)
signal weapon_selected(family: String)
signal forge_committed(item: Dictionary)

const WEAPONS := {
	"sword_shield":{"label":"Sword + Shield","a1":"Guarded Cut","a2":"Shadow Break","feel":"steady / defensive"},
	"bow":{"label":"Bow","a1":"Shade Shot","a2":"Piercing Dusk","feel":"precise / ranged"},
	"two_hand_axe":{"label":"2H Axe","a1":"Heavy Cleave","a2":"Grave Splitter","feel":"slow / crushing"},
	"dual_daggers":{"label":"Dual Daggers","a1":"Twin Fang","a2":"Veil Rush","feel":"fast / setup"},
	"mage_staff":{"label":"2H Mage Staff","a1":"Umbral Bolt","a2":"Night Pulse","feel":"control / arcane"}
}

var stage:=Act0Contract.STAGE_EXTERIOR
var covenant_joined:=false
var weapon_family:=""
var silver:=0
var forged_item:={}
var first_forge_done:=false
var hound_residual_absorbed:=false
var faded_sigil_activated:=false

func restore(state:Dictionary)->void:
	stage=Act0Contract.normalize_stage(str(state.get("act0_stage",Act0Contract.STAGE_EXTERIOR)))
	covenant_joined=bool(state.get("covenant_joined",false))
	weapon_family=str(state.get("weapon_family",""))
	silver=maxi(0,int(state.get("silver",0)))
	forged_item=Dictionary(state.get("forged_item",{})).duplicate(true)
	first_forge_done=bool(state.get("first_forge_done",false))
	hound_residual_absorbed=bool(state.get("hound_residual_absorbed",false))
	faded_sigil_activated=bool(state.get("faded_sigil_activated",false))

func snapshot()->Dictionary:
	return {
		"act0_stage":stage,
		"covenant_joined":covenant_joined,
		"weapon_family":weapon_family,
		"silver":silver,
		"forged_item":forged_item.duplicate(true),
		"first_forge_done":first_forge_done,
		"hound_residual_absorbed":hound_residual_absorbed,
		"faded_sigil_activated":faded_sigil_activated
	}

func transition_to(next_stage:String)->bool:
	if stage==next_stage:
		return true
	if not Act0Contract.can_transition(stage,next_stage):
		return false
	stage=next_stage
	stage_changed.emit(stage)
	return true

func mark_hound_residual_absorbed()->bool:
	if hound_residual_absorbed or stage!=Act0Contract.STAGE_EXTERIOR:
		return false
	hound_residual_absorbed=true
	return true

func activate_faded_sigil()->bool:
	if faded_sigil_activated or stage!=Act0Contract.STAGE_TEMPLE_ENTRY:
		return false
	faded_sigil_activated=true
	return true

func join_covenant()->bool:
	if covenant_joined or not faded_sigil_activated or stage!=Act0Contract.STAGE_TEMPLE_ENTRY:
		return false
	covenant_joined=true
	if not transition_to(Act0Contract.STAGE_WEAPON_CHOICE):
		covenant_joined=false
		return false
	return true

func choose_weapon(family:String)->bool:
	if not covenant_joined or stage!=Act0Contract.STAGE_WEAPON_CHOICE or not weapon_family.is_empty():
		return false
	if family not in Act0Contract.WEAPON_FAMILIES or not WEAPONS.has(family):
		return false
	weapon_family=family
	if not transition_to(Act0Contract.STAGE_FIRST_FORGE):
		weapon_family=""
		return false
	weapon_selected.emit(family)
	return true

func can_first_forge()->bool:
	return not first_forge_done and covenant_joined and stage==Act0Contract.STAGE_FIRST_FORGE and WEAPONS.has(weapon_family) and silver>=1

static func canonical_first_forge_item(family:String)->Dictionary:
	if family not in Act0Contract.WEAPON_FAMILIES:
		return {}
	return {"id":"shadow_"+family+"_01","family":family,"level":0,"bonus_unlocked":false,"equipped":true}

static func is_valid_first_forge_item(candidate:Dictionary,family:String)->bool:
	var expected:=canonical_first_forge_item(family)
	if expected.is_empty():
		return false
	return (
		str(candidate.get("id",""))==str(expected.id)
		and str(candidate.get("family",""))==family
		and int(candidate.get("level",-1))==0
		and not bool(candidate.get("bonus_unlocked",true))
		and bool(candidate.get("equipped",false))
	)

func first_forge_candidate()->Dictionary:
	if not can_first_forge():
		return {}
	return canonical_first_forge_item(weapon_family)

func apply_first_forge(candidate:Dictionary)->bool:
	if not can_first_forge() or not is_valid_first_forge_item(candidate,weapon_family):
		return false
	if not Act0Contract.can_transition(stage,Act0Contract.STAGE_CATACOMBS):
		return false
	silver-=1
	forged_item=candidate.duplicate(true)
	first_forge_done=true
	stage=Act0Contract.STAGE_CATACOMBS
	forge_committed.emit(forged_item)
	stage_changed.emit(stage)
	return true

func commit_first_forge()->bool:
	var candidate:=first_forge_candidate()
	if candidate.is_empty():
		return false
	return apply_first_forge(candidate)
