class_name ShadowAbilityCatalog
extends RefCounted

static func kit_for_weapon(family:String)->CombatKitDefinition:
	var loadout:=ShadowLoadout.profile(family)
	var normalized_family:=str(loadout.get("family",""))
	var prefix:="shadow" if normalized_family.is_empty() else "shadow."+normalized_family

	var a1:=CombatSkillDefinition.new()
	a1.id=StringName(prefix+".a1")
	a1.display_name=str(loadout.get("a1_name","Basic Attack"))
	a1.kind=CombatSkillDefinition.SkillKind.DEFAULT
	a1.target_rule=CombatSkillDefinition.TargetRule.SINGLE_ENEMY
	a1.unlock_level=1
	a1.base_cooldown=0
	a1.action_tags=[&"Action.Attack",&"Action.Default",&"Target.Single"]
	a1.base_values={
		"coeff":float(loadout.get("a1_coeff",1.0)),
		"guard_mult":float(loadout.get("a1_guard_mult",0.65))
	}
	a1.presentation_id=&"A1"

	var a2:=CombatSkillDefinition.new()
	a2.id=StringName(prefix+".a2")
	a2.display_name=str(loadout.get("a2_name","Shadow Lunge"))
	a2.kind=CombatSkillDefinition.SkillKind.ACTIVE
	a2.target_rule=CombatSkillDefinition.TargetRule.SINGLE_ENEMY
	a2.unlock_level=1
	a2.base_cooldown=int(loadout.get("a2_cd",3))
	a2.action_tags=[&"Action.Attack",&"Action.Active",&"Target.Single"]
	a2.base_values={
		"coeff":float(loadout.get("a2_coeff",1.30)),
		"guard_mult":float(loadout.get("a2_guard_mult",0.55)),
		"veil":float(loadout.get("a2_veil",0.15))
	}
	a2.presentation_id=&"A2"

	var kit:=CombatKitDefinition.new()
	kit.actor_id=&"shadow"
	kit.skills=[a1,a2]
	return kit
