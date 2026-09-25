extends SceneTree

var failures:=0

func _init()->void:
	call_deferred("_run")

func _check(condition:bool,message:String)->void:
	if condition:
		print("PASS: "+message)
	else:
		failures+=1
		push_error("FAIL: "+message)

func _finite_number(value)->bool:
	if typeof(value) not in [TYPE_INT,TYPE_FLOAT]:
		return false
	var number:=float(value)
	return number==number and not is_inf(number)

func _run()->void:
	_validate_weapon_loadouts()
	_validate_catacomb_profiles()
	_validate_pre_temple_scripts()
	_validate_story_companion()
	print("Act 0 content validation complete. failures=%d"%failures)
	quit(1 if failures>0 else 0)

func _validate_weapon_loadouts()->void:
	_check(ShadowLoadout.PROFILES.size()==Act0Contract.WEAPON_FAMILIES.size(),"all five fixed weapon families have combat loadouts")
	for family in Act0Contract.WEAPON_FAMILIES:
		_check(ShadowLoadout.PROFILES.has(family),"weapon loadout exists: "+family)
		if not ShadowLoadout.PROFILES.has(family):
			continue
		var p:Dictionary=ShadowLoadout.PROFILES[family]
		_check(str(p.get("family",""))==family,"weapon profile family matches key: "+family)
		_check(not str(p.get("a1_name","")).is_empty() and not str(p.get("a2_name","")).is_empty(),"weapon skill names are non-empty: "+family)
		for key in ["a1_coeff","a2_coeff"]:
			_check(_finite_number(p.get(key)) and float(p[key])>0.0 and float(p[key])<=5.0,"%s is finite and bounded: %s"%[key,family])
		for key in ["a1_guard_mult","a2_guard_mult"]:
			_check(_finite_number(p.get(key)) and float(p[key])>0.0 and float(p[key])<=1.0,"%s is a valid mitigation multiplier: %s"%[key,family])
		_check(_finite_number(p.get("a2_veil")) and float(p.a2_veil)>=0.0 and float(p.a2_veil)<=0.95,"A2 Veil stays inside safe mitigation range: "+family)
		_check(_finite_number(p.get("a2_cd")) and int(p.a2_cd)>=1 and int(p.a2_cd)<=10,"A2 cooldown stays inside authored bounds: "+family)

func _validate_catacomb_profiles()->void:
	var expected:Array=Act0Contract.all_catacomb_encounter_ids()
	_check(CatacombEncounterPlan.PROFILES.size()==expected.size(),"Catacomb profile count matches fixed encounter contract")
	for id_value in expected:
		var id:=str(id_value)
		_check(CatacombEncounterPlan.PROFILES.has(id),"Catacomb tuning exists: "+id)
		if not CatacombEncounterPlan.PROFILES.has(id):
			continue
		var p:Dictionary=CatacombEncounterPlan.PROFILES[id]
		_check(not str(p.get("label","")).is_empty(),"Catacomb enemy label is non-empty: "+id)
		_check(_finite_number(p.get("hp")) and float(p.hp)>0.0 and float(p.hp)<=10000.0,"Catacomb HP is finite and bounded: "+id)
		_check(_finite_number(p.get("def")) and float(p.def)>=0.0 and float(p.def)<=10000.0,"Catacomb defense is finite and bounded: "+id)
		_check(_finite_number(p.get("damage")) and float(p.damage)>=0.0 and float(p.damage)<=10000.0,"Catacomb damage is finite and bounded: "+id)
		if p.has("guard"):
			_check(typeof(p.guard)==TYPE_BOOL,"Catacomb guard flag is boolean: "+id)

func _validate_pre_temple_scripts()->void:
	var seen:Dictionary={}
	for script_value in EncounterController.PRE_TEMPLE_SCRIPTS.values():
		var script_id:=str(script_value)
		if seen.has(script_id):
			continue
		seen[script_id]=true
		var p:Dictionary=Ch00CombatModel._profile(script_id)
		_check(not p.is_empty(),"pre-Temple scripted profile exists: "+script_id)
		if p.is_empty():
			continue
		for key in ["shadow_hp","enemy_hp","enemy_atk","enemy_def"]:
			_check(_finite_number(p.get(key)) and float(p[key])>=0.0 and float(p[key])<=10000.0,"%s is finite and bounded: %s"%[key,script_id])
		var beats=p.get("script",[])
		_check(typeof(beats)==TYPE_ARRAY and beats.size()>0 and beats.size()<=20,"pre-Temple script beat count is bounded: "+script_id)
		if typeof(beats)!=TYPE_ARRAY:
			continue
		for beat_value in beats:
			_check(typeof(beat_value)==TYPE_DICTIONARY,"pre-Temple beat is a dictionary: "+script_id)
			if typeof(beat_value)!=TYPE_DICTIONARY:
				continue
			var beat:Dictionary=beat_value
			_check(not str(beat.get("visible_state","")).is_empty(),"pre-Temple beat has a visible state: "+script_id)
			_check(typeof(beat.get("guard",false))==TYPE_BOOL,"pre-Temple guard is boolean: "+script_id)
			_check(_finite_number(beat.get("enemy_coeff",0.0)) and float(beat.get("enemy_coeff",0.0))>=0.0 and float(beat.get("enemy_coeff",0.0))<=10.0,"pre-Temple enemy coefficient is finite and bounded: "+script_id)

func _validate_story_companion()->void:
	var p:=StoryCompanion.profile()
	_check(str(p.get("id",""))==StoryCompanion.ID and not str(p.get("name","")).is_empty(),"story companion identity is stable")
	for key in ["hp","atk","def"]:
		_check(_finite_number(p.get(key)) and float(p[key])>=0.0 and float(p[key])<=10000.0,"story companion %s is finite and bounded"%key)
	var a1=p.get("a1",{})
	_check(typeof(a1)==TYPE_DICTIONARY,"story companion A1 profile is a dictionary")
	if typeof(a1)==TYPE_DICTIONARY:
		_check(not str(a1.get("name","")).is_empty(),"story companion A1 name is non-empty")
		_check(_finite_number(a1.get("coeff")) and float(a1.coeff)>0.0 and float(a1.coeff)<=5.0,"story companion A1 coefficient is finite and bounded")
