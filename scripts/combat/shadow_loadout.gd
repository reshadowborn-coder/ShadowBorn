class_name ShadowLoadout
extends RefCounted

const DEFAULT := {
	"family":"",
	"a1_name":"Basic Attack",
	"a1_coeff":1.00,
	"a1_guard_mult":0.65,
	"a2_name":"Shadow Lunge",
	"a2_coeff":1.30,
	"a2_cd":3,
	"a2_veil":0.15,
	"a2_guard_mult":0.55
}

const PROFILES := {
	"sword_shield":{
		"family":"sword_shield",
		"a1_name":"Guarded Cut",
		"a1_coeff":0.95,
		"a1_guard_mult":0.70,
		"a2_name":"Shadow Break",
		"a2_coeff":1.20,
		"a2_cd":3,
		"a2_veil":0.30,
		"a2_guard_mult":0.60
	},
	"bow":{
		"family":"bow",
		"a1_name":"Shade Shot",
		"a1_coeff":1.00,
		"a1_guard_mult":0.85,
		"a2_name":"Piercing Dusk",
		"a2_coeff":1.25,
		"a2_cd":3,
		"a2_veil":0.10,
		"a2_guard_mult":0.85
	},
	"two_hand_axe":{
		"family":"two_hand_axe",
		"a1_name":"Heavy Cleave",
		"a1_coeff":1.10,
		"a1_guard_mult":0.60,
		"a2_name":"Grave Splitter",
		"a2_coeff":1.55,
		"a2_cd":4,
		"a2_veil":0.05,
		"a2_guard_mult":0.55
	},
	"dual_daggers":{
		"family":"dual_daggers",
		"a1_name":"Twin Fang",
		"a1_coeff":0.95,
		"a1_guard_mult":0.70,
		"a2_name":"Veil Rush",
		"a2_coeff":1.20,
		"a2_cd":2,
		"a2_veil":0.15,
		"a2_guard_mult":0.65
	},
	"mage_staff":{
		"family":"mage_staff",
		"a1_name":"Umbral Bolt",
		"a1_coeff":1.00,
		"a1_guard_mult":0.75,
		"a2_name":"Night Pulse",
		"a2_coeff":1.25,
		"a2_cd":3,
		"a2_veil":0.20,
		"a2_guard_mult":0.70
	}
}

static func profile(family:String)->Dictionary:
	if PROFILES.has(family):
		return PROFILES[family].duplicate(true)
	return DEFAULT.duplicate(true)
