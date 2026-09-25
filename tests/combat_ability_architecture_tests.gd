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

func _run()->void:
	_test_shadow_skill_catalog_parity()
	_test_skill_rank_runtime_isolation()
	_test_passive_trigger_guards()
	_test_talent_graph_rules()
	_test_kit_contract()
	print("Combat ability architecture tests complete. failures=%d"%failures)
	quit(1 if failures>0 else 0)

func _test_shadow_skill_catalog_parity()->void:
	for family in ShadowLoadout.PROFILES:
		var loadout:=ShadowLoadout.profile(str(family))
		var kit:=ShadowAbilityCatalog.kit_for_weapon(str(family))
		_check(kit.validate().is_empty(),"Shadow kit validates for "+str(family))
		_check(kit.skills.size()==2,"Shadow early kit contains exactly A1 + one active for "+str(family))
		var a1:CombatSkillDefinition=kit.skills[0]
		var a2:CombatSkillDefinition=kit.skills[1]
		_check(a1.kind==CombatSkillDefinition.SkillKind.DEFAULT and a2.kind==CombatSkillDefinition.SkillKind.ACTIVE,"Shadow catalog preserves default/active slot identity: "+str(family))
		_check(is_equal_approx(float(a1.base_values.coeff),float(loadout.a1_coeff)),"A1 coefficient parity: "+str(family))
		_check(is_equal_approx(float(a2.base_values.coeff),float(loadout.a2_coeff)) and a2.base_cooldown==int(loadout.a2_cd),"A2 coefficient/cooldown parity: "+str(family))

func _test_skill_rank_runtime_isolation()->void:
	var skill:=CombatSkillDefinition.new()
	skill.id=&"test.skill"
	skill.display_name="Test Skill"
	skill.kind=CombatSkillDefinition.SkillKind.ACTIVE
	skill.base_cooldown=4
	skill.base_values={"coeff":1.0,"chance_bp":6000}
	skill.rank_patches=[
		{"rank":1,"key":"coeff","op":"multiply_bp","value":11000},
		{"rank":2,"key":"chance_bp","op":"add","value":1000},
		{"rank":3,"key":"cooldown","op":"cooldown_delta","value":-1},
		{"rank":4,"key":"tag","op":"add_tag","value":"Effect.Guaranteed"}
	]
	_check(skill.validate().is_empty(),"ranked active skill definition validates")
	var low:=skill.create_spec(0)
	var high:=skill.create_spec(4)
	_check(is_equal_approx(float(low.runtime_values.coeff),1.0),"rank 0 keeps base coefficient")
	_check(is_equal_approx(float(high.runtime_values.coeff),1.1),"rank patch multiplies runtime coefficient without mutating definition")
	_check(int(high.runtime_values.chance_bp)==7000 and high.cooldown_max()==3,"rank patches can improve effect chance and cooldown")
	_check(high.has_tag(&"Effect.Guaranteed"),"rank patch can add semantic behavior tag")
	_check(is_equal_approx(float(skill.base_values.coeff),1.0) and skill.base_cooldown==4,"runtime skill ranks never mutate static definition")
	_check(high.commit_use() and high.cooldown_remaining==3,"active skill commits its computed cooldown")
	high.advance_actionable_owner_turn()
	_check(high.cooldown_remaining==2,"skill cooldown advances only through explicit actionable owner turns")

func _passive(
	id:StringName,
	event_type:StringName,
	relation:CombatPassiveDefinition.OwnerRelation
)->CombatPassiveDefinition:
	var passive:=CombatPassiveDefinition.new()
	passive.id=id
	passive.display_name=str(id)
	passive.trigger_event=event_type
	passive.owner_relation=relation
	passive.reaction_kind=CombatReactionQueue.KIND_FOLLOW_UP
	passive.once_per_turn=true
	passive.internal_cooldown_owner_turns=1
	return passive

func _test_passive_trigger_guards()->void:
	var runtime:=CombatPassiveRuntime.new()
	_check(runtime.register_actor(&"shadow",&"ally"),"passive runtime registers Shadow team")
	_check(runtime.register_actor(&"warden",&"ally"),"passive runtime registers allied Warden")
	_check(runtime.register_actor(&"rat",&"enemy"),"passive runtime registers enemy")
	var self_hit:=_passive(&"shadow.after_hit",CombatEventTypes.AFTER_HIT,CombatPassiveDefinition.OwnerRelation.SELF_SOURCE)
	self_hit.priority=20
	self_hit.effect_steps=[{"op":"turn_meter","target":"self","value_bp":1000}]
	var ally_guard:=_passive(&"warden.guard",CombatEventTypes.ACTIVE_DAMAGE_TAKEN,CombatPassiveDefinition.OwnerRelation.ALLY_TARGET)
	ally_guard.priority=30
	ally_guard.reaction_kind=CombatReactionQueue.KIND_ASSIST
	_check(runtime.register_passive(&"shadow",self_hit),"self-source passive registers")
	_check(runtime.register_passive(&"warden",ally_guard),"ally-target passive registers")

	var hit:=CombatTriggerEvent.new(CombatEventTypes.AFTER_HIT,&"shadow",&"rat",7)
	hit.source_team=&"ally"
	hit.target_team=&"enemy"
	var reactions:=runtime.collect_reactions(hit)
	_check(reactions.size()==1 and StringName(reactions[0].passive_id)==&"shadow.after_hit","self-source passive fires on matching event")
	_check(runtime.collect_reactions(hit).is_empty(),"once-per-turn passive cannot trigger twice on the same turn serial")
	runtime.advance_owner_turn(&"shadow")
	var next_hit:=CombatTriggerEvent.new(CombatEventTypes.AFTER_HIT,&"shadow",&"rat",8)
	next_hit.source_team=&"ally"
	next_hit.target_team=&"enemy"
	_check(runtime.collect_reactions(next_hit).size()==1,"owner-turn internal cooldown can expire deterministically")

	var ally_damage:=CombatTriggerEvent.new(CombatEventTypes.ACTIVE_DAMAGE_TAKEN,&"rat",&"shadow",9)
	ally_damage.source_team=&"enemy"
	ally_damage.target_team=&"ally"
	runtime.set_passives_blocked(&"warden",true)
	_check(runtime.collect_reactions(ally_damage).is_empty(),"Block Passive Skills suppresses ordinary passive triggers")
	runtime.set_passives_blocked(&"warden",false)
	_check(runtime.collect_reactions(ally_damage).size()==1,"clearing passive block restores eligible ally reaction")

func _talent(
	id:StringName,
	branch:StringName,
	tier:int,
	level:int,
	prereqs:Array[StringName]=[]
)->CombatTalentDefinition:
	var t:=CombatTalentDefinition.new()
	t.id=id
	t.display_name=str(id)
	t.branch=branch
	t.tier=tier
	t.min_level=level
	t.prerequisite_ids=prereqs
	return t

func _test_talent_graph_rules()->void:
	var graph:=CombatTalentGraph.new()
	var root_a:=_talent(&"a.root",&"a",1,1)
	var deep_a:=_talent(&"a.deep",&"a",2,10,[&"a.root"])
	var root_b:=_talent(&"b.root",&"b",1,1)
	var root_c:=_talent(&"c.root",&"c",1,1)
	root_b.exclusive_group=&"opening_choice"
	root_c.exclusive_group=&"opening_choice"
	_check(graph.add_definition(root_a) and graph.add_definition(deep_a) and graph.add_definition(root_b) and graph.add_definition(root_c),"talent graph registers valid nodes")
	_check(graph.validate_graph().is_empty(),"talent graph validates acyclic prerequisites")
	var ranks:Dictionary={}
	_check(not bool(graph.can_purchase(ranks,&"a.deep",5,5).ok),"talent respects level gate before prerequisite checks can be bypassed")
	_check(bool(graph.can_purchase(ranks,&"a.root",1,1).ok),"tier root can be purchased")
	ranks["a.root"]=1
	_check(bool(graph.can_purchase(ranks,&"a.deep",10,1).ok),"deep talent unlocks after level + prerequisite")
	ranks["b.root"]=1
	_check(not bool(graph.can_purchase(ranks,&"c.root",10,1).ok),"mutually exclusive talent choice is enforced")
	var branches:=graph.active_branches(ranks)
	_check(branches.size()==2,"talent graph tracks active branches")
	var extra:=_talent(&"d.root",&"d",1,1)
	graph.add_definition(extra)
	_check(not bool(graph.can_purchase(ranks,&"d.root",10,1,2).ok),"talent selection cannot silently exceed configured branch cap")

func _test_kit_contract()->void:
	var kit:=CombatKitDefinition.new()
	kit.actor_id=&"test"
	var default_skill:=CombatSkillDefinition.new()
	default_skill.id=&"test.a1"
	default_skill.display_name="A1"
	default_skill.kind=CombatSkillDefinition.SkillKind.DEFAULT
	var active:=CombatSkillDefinition.new()
	active.id=&"test.a2"
	active.display_name="A2"
	active.kind=CombatSkillDefinition.SkillKind.ACTIVE
	active.base_cooldown=3
	var passive:=_passive(&"test.p1",CombatEventTypes.TURN_START,CombatPassiveDefinition.OwnerRelation.SELF_SOURCE)
	passive.unlock_level=10
	var aura:=CombatSkillDefinition.new()
	aura.id=&"test.aura"
	aura.display_name="Aura"
	aura.kind=CombatSkillDefinition.SkillKind.AURA
	aura.target_rule=CombatSkillDefinition.TargetRule.ALL_ALLIES
	aura.unlock_level=40
	kit.skills=[default_skill,active]
	kit.passives=[passive]
	kit.aura=aura
	_check(kit.validate().is_empty(),"kit supports A1 + active + level-gated passive + later aura without conflating their rules")
