extends SceneTree

const CombatCatalog = preload("res://scripts/combat/checkpoint01_combat_catalog.gd")
const PresentationCatalog = preload("res://scripts/presentation/checkpoint01_presentation_catalog.gd")

var failures := 0

func _init() -> void:
	var errors := PresentationCatalog.validate()
	_check(errors.is_empty(),"all Checkpoint 01 presentation profiles validate: %s" % [errors])

	for skill in [CombatCatalog.BASIC_SLASH,CombatCatalog.SHADOW_LUNGE,CombatCatalog.HOUND_BITE,CombatCatalog.HOUND_REND]:
		var profile = PresentationCatalog.profile_for(skill.skill_id)
		_check(profile != null,"%s has an explicit presentation profile" % skill.skill_id)
		if profile != null:
			_check(profile.presentation_action_id == skill.presentation_action_id,"%s combat/presentation action IDs match" % skill.skill_id)

	_check(PresentationCatalog.BASIC_SLASH.contact_root_gap > 0.0,"A1 uses semantic contact standoff instead of fixed short root travel")
	_check(PresentationCatalog.SHADOW_LUNGE.contact_root_gap > 0.0,"A2 uses semantic contact standoff")
	_check(PresentationCatalog.HOUND_BITE.contact_root_gap > 0.0,"Bite uses semantic contact standoff instead of fixed short root travel")
	_check(PresentationCatalog.HOUND_REND.contact_root_gap > 0.0,"Rend uses semantic contact standoff")
	_check(PresentationCatalog.HOUND_BITE.impact_vfx_family == &"basic_slash","current Bite placeholder VFX is represented explicitly, not hidden in BattleStage")
	_check(PresentationCatalog.profile_for(&"unknown") == null,"unknown skills have no presentation fallback")

	print("Presentation profile tests complete. failures=%d" % failures)
	quit(1 if failures > 0 else 0)

func _check(condition: bool,message: String) -> void:
	if condition:
		print("PASS: "+message)
	else:
		failures += 1
		push_error("FAIL: "+message)
