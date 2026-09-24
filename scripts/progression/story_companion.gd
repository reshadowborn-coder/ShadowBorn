class_name StoryCompanion
extends RefCounted

const ID:="gravebound_warden"
const DISPLAY_NAME:="Gravebound Warden"

static func profile()->Dictionary:
	return {
		"id":ID,
		"name":DISPLAY_NAME,
		"role":"protector",
		"hp":18.0,
		"atk":5.0,
		"def":7.0,
		"a1":{"name":"Warden Strike","coeff":0.85},
		"fixed_visual":true
	}
