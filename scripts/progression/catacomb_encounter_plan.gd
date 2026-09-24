class_name CatacombEncounterPlan
extends RefCounted

const ROOMS := {
	1: [{"id":"cat_r1_skeleton","hp":13.0,"def":3.0,"damage":2.2}],
	2: [{"id":"cat_r2_hound","hp":14.0,"def":2.0,"damage":2.6}],
	3: [{"id":"cat_r3_guard","hp":17.0,"def":6.0,"damage":2.5,"guard":true}],
	4: [{"id":"cat_r4_revenant","hp":19.0,"def":4.0,"damage":3.0}],
	5: [
		{"id":"cat_r5_skeleton_a","hp":15.0,"def":4.0,"damage":2.6},
		{"id":"cat_r5_skeleton_b","hp":15.0,"def":4.0,"damage":2.6}
	]
}

static func enemies(room:int)->Array:
	return ROOMS.get(room,[]).duplicate(true)

static func is_solo_limit(room:int,summon_unlocked:bool)->bool:
	return room==5 and not summon_unlocked
