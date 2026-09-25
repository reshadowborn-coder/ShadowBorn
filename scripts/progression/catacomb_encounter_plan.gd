class_name CatacombEncounterPlan
extends RefCounted

# Mutable encounter tuning. Room membership and encounter IDs live in
# Act0Contract so balance edits cannot silently alter the authored Act 0 flow.
const PROFILES := {
	"cat_r1_skeleton":{"label":"Restless Skeleton","hp":13.0,"def":3.0,"damage":2.2},
	"cat_r2_hound":{"label":"Crypt Hound","hp":14.0,"def":2.0,"damage":2.6},
	"cat_r3_guard":{"label":"Grave Guard","hp":17.0,"def":6.0,"damage":2.5,"guard":true},
	"cat_r4_revenant":{"label":"Hollow Revenant","hp":19.0,"def":4.0,"damage":3.0},
	"cat_r5_skeleton_a":{"label":"Bone Warden A","hp":15.0,"def":4.0,"damage":2.6},
	"cat_r5_skeleton_b":{"label":"Bone Warden B","hp":15.0,"def":4.0,"damage":2.6}
}

static func enemies(room:int)->Array:
	var out:Array=[]
	for id_value in Act0Contract.catacomb_encounter_ids(room):
		var id:=str(id_value)
		if not PROFILES.has(id):
			push_error("Missing mutable Catacomb profile for fixed Act 0 encounter: "+id)
			continue
		var profile:Dictionary=PROFILES[id].duplicate(true)
		profile["id"]=id
		out.append(profile)
	return out

static func is_solo_limit(room:int,summon_unlocked:bool)->bool:
	return room==5 and not summon_unlocked
