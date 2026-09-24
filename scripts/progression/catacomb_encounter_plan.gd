class_name CatacombEncounterPlan
extends RefCounted

const ROOMS := {
	1: [{"id":"cat_r1_skeleton","label":"Restless Skeleton","hp":13.0,"def":3.0,"damage":2.2}],
	2: [{"id":"cat_r2_hound","label":"Crypt Hound","hp":14.0,"def":2.0,"damage":2.6}],
	3: [{"id":"cat_r3_guard","label":"Grave Guard","hp":17.0,"def":6.0,"damage":2.5,"guard":true}],
	4: [{"id":"cat_r4_revenant","label":"Hollow Revenant","hp":19.0,"def":4.0,"damage":3.0}],
	5: [
		{"id":"cat_r5_skeleton_a","label":"Bone Warden A","hp":15.0,"def":4.0,"damage":2.6},
		{"id":"cat_r5_skeleton_b","label":"Bone Warden B","hp":15.0,"def":4.0,"damage":2.6}
	]
}

static func enemies(room:int)->Array:
	return ROOMS.get(room,[]).duplicate(true)

static func is_solo_limit(room:int,summon_unlocked:bool)->bool:
	return room==5 and not summon_unlocked
