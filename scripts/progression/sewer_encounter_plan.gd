class_name SewerEncounterPlan
extends RefCounted

const PROFILES={
	"a1_r1_rat":{"id":"a1_r1_rat","label":"Sewer Rat","hp":12.0,"def":2.0,"damage":2.2,"speed":92,"guard":false},
	"a1_r2_poison_rat":{"id":"a1_r2_poison_rat","label":"Poison Rat","hp":14.0,"def":2.5,"damage":2.0,"speed":96,"guard":false,"poison_damage":0.75,"poison_turns":2},
	"a1_r3_rat_a":{"id":"a1_r3_rat_a","label":"Pack Rat","hp":16.0,"def":3.0,"damage":2.8,"speed":98},
	"a1_r3_rat_b":{"id":"a1_r3_rat_b","label":"Pack Rat","hp":16.0,"def":3.0,"damage":2.8,"speed":92}
}

static func enemies(room:int)->Array:
	var out:Array=[]
	for id_value in Act1Contract.encounter_ids(room):
		var id:=str(id_value)
		if PROFILES.has(id):
			out.append(Dictionary(PROFILES[id]).duplicate(true))
	return out