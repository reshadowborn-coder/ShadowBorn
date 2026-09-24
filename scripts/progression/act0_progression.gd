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
var stage:="exterior"
var covenant_joined:=false
var weapon_family:=""
var silver:=0
var forged_item:={}
var first_forge_done:=false

func restore(state:Dictionary)->void:
	stage=str(state.get("act0_stage","temple_entry"))
	covenant_joined=bool(state.get("covenant_joined",false))
	weapon_family=str(state.get("weapon_family",""))
	silver=int(state.get("silver",0))
	forged_item=state.get("forged_item",{}).duplicate(true)
	first_forge_done=bool(state.get("first_forge_done",false))

func snapshot()->Dictionary:
	return {"act0_stage":stage,"covenant_joined":covenant_joined,"weapon_family":weapon_family,"silver":silver,"forged_item":forged_item.duplicate(true),"first_forge_done":first_forge_done}

func join_covenant()->bool:
	if covenant_joined or stage!="temple_entry":
		return false
	covenant_joined=true
	stage="weapon_choice"
	stage_changed.emit(stage)
	return true

func choose_weapon(family:String)->bool:
	if not covenant_joined or stage!="weapon_choice" or not weapon_family.is_empty() or not WEAPONS.has(family):
		return false
	weapon_family=family
	stage="first_forge"
	weapon_selected.emit(family)
	stage_changed.emit(stage)
	return true

func can_first_forge()->bool:
	return not first_forge_done and covenant_joined and stage=="first_forge" and WEAPONS.has(weapon_family) and silver>=1

func first_forge_candidate()->Dictionary:
	if not can_first_forge():
		return {}
	return {"id":"shadow_"+weapon_family+"_01","family":weapon_family,"level":0,"bonus_unlocked":false,"equipped":true}

func apply_first_forge(candidate:Dictionary)->bool:
	if not can_first_forge():
		return false
	if str(candidate.get("family",""))!=weapon_family:
		return false
	silver-=1
	forged_item=candidate.duplicate(true)
	first_forge_done=true
	stage="catacombs"
	forge_committed.emit(forged_item)
	stage_changed.emit(stage)
	return true

func commit_first_forge()->bool:
	var candidate:=first_forge_candidate()
	if candidate.is_empty():
		return false
	return apply_first_forge(candidate)
