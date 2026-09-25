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
	var packed:=load("res://scenes/chapter00/chapter00_graybox.tscn") as PackedScene
	_check(packed!=null,"Chapter 0 scene loads for Temple NPC life audit")
	if packed==null:
		quit(1)
		return

	var chapter:=packed.instantiate()
	root.add_child(chapter)
	await process_frame
	await process_frame

	var ambient:=get_nodes_in_group("temple_ambient_npc")
	_check(ambient.size()>=4,"Temple has at least four ambient service NPC proxies")

	var roles:Dictionary={}
	for npc in ambient:
		if npc is Node3D:
			roles[str(npc.get_meta("role",""))]=npc
	for role in ["keeper","smith","merchant","engraver"]:
		_check(roles.has(role),"Temple ambient roster contains %s"%role)
		if roles.has(role):
			var npc:=roles[role] as Node3D
			_check(npc.get_script()!=null,"%s ambient NPC has an animation controller"%role)
			_check(npc.get_node_or_null("Body")!=null,"%s has a body proxy"%role)
			_check(npc.get_node_or_null("Head")!=null,"%s has a head proxy"%role)

	if roles.has("smith"):
		var smith:=roles["smith"] as Node3D
		var arm:=smith.get_node_or_null("WorkArm") as Node3D
		_check(arm!=null,"smith has a work arm")
		_check(arm!=null and arm.get_node_or_null("WorkProp")!=null,"smith carries a hammer/work prop")
		if arm:
			var before:=arm.rotation_degrees
			smith._process(0.6)
			_check(not arm.rotation_degrees.is_equal_approx(before),"smith work arm changes pose during ambient cycle")

	if roles.has("merchant"):
		var merchant:=roles["merchant"] as Node3D
		var head:=merchant.get_node_or_null("Head") as Node3D
		var focus:=merchant.get_node_or_null("FocusProp") as Node3D
		_check(focus!=null,"merchant has goods to inspect")
		if head:
			var before:=head.rotation_degrees
			merchant._process(0.8)
			_check(not head.rotation_degrees.is_equal_approx(before),"merchant changes gaze during ambient cycle")

	if roles.has("engraver"):
		var engraver:=roles["engraver"] as Node3D
		var focus:=engraver.get_node_or_null("FocusProp") as Node3D
		_check(focus!=null,"engraver has a rune focus prop")
		if focus:
			var before:=focus.scale
			engraver._process(0.7)
			_check(not focus.scale.is_equal_approx(before),"engraver rune focus pulses during ambient cycle")

	if roles.has("keeper"):
		var keeper:=roles["keeper"] as Node3D
		var head:=keeper.get_node_or_null("Head") as Node3D
		if head:
			var before:=head.rotation_degrees
			keeper._process(0.9)
			_check(not head.rotation_degrees.is_equal_approx(before),"Keeper changes gaze subtly instead of remaining static")

	chapter.queue_free()
	await process_frame
	print("Temple NPC life tests complete. failures=%d"%failures)
	quit(1 if failures>0 else 0)
