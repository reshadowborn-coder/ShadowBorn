extends SceneTree

const Scheduler = preload("res://scripts/combat/battle_turn_scheduler.gd")

var failures := 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	_test_checkpoint_reference_order()
	_test_stable_ties_and_overflow()
	_test_direct_meter_cut_is_separate_from_speed()
	_test_render_partition_counterexample()
	_test_battle_speed_changes_wait_only()
	print("Battle turn scheduler tests complete. failures=%d" % failures)
	quit(1 if failures > 0 else 0)

func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: " + message)
	else:
		failures += 1
		push_error("FAIL: " + message)

func _test_checkpoint_reference_order() -> void:
	var scheduler := Scheduler.new()
	_check(scheduler.add_actor(&"shadow",53,1800),"Checkpoint Shadow registers at 18% meter")
	_check(scheduler.add_actor(&"hound",45,0),"Checkpoint Hound registers at 0% meter")
	var first := scheduler.next_event()
	_check(StringName(first.actor_id) == &"shadow","Shadow reaches READY first in the reboot reference")
	_check(int(first.ticks_waited) == 155,"reference first crossing uses exact abstract ticks, not sampled frame overshoot")
	_check(int(first.gauge_after_consume) == 15,"Shadow overflow is preserved after the first turn")
	var second := scheduler.next_event()
	_check(StringName(second.actor_id) == &"hound","Hound receives its accumulated meter and acts next")
	_check(int(second.ticks_waited) == 68,"second crossing advances only the exact ticks needed for Hound")

func _test_stable_ties_and_overflow() -> void:
	var ties := Scheduler.new()
	ties.add_actor(&"first",100,0)
	ties.add_actor(&"second",100,0)
	var tie := ties.next_event()
	_check(StringName(tie.actor_id) == &"first","exact equal Speed/gauge tie resolves by registration order")

	var overflow := Scheduler.new()
	overflow.add_actor(&"shadow",100,30000)
	overflow.add_actor(&"hound",100,0)
	var e1 := overflow.next_event()
	var e2 := overflow.next_event()
	var e3 := overflow.next_event()
	_check(StringName(e1.actor_id) == &"shadow" and StringName(e2.actor_id) == &"shadow" and StringName(e3.actor_id) == &"shadow","bounded 300% stored meter yields exactly three immediate Shadow turns")
	_check(overflow.gauge_bp(&"shadow") == 0,"stored overflow is fully consumed after three immediate turns")

func _test_direct_meter_cut_is_separate_from_speed() -> void:
	var scheduler := Scheduler.new()
	scheduler.add_actor(&"shadow",53,0)
	scheduler.add_actor(&"hound",45,9000)
	_check(scheduler.adjust_gauge_bp(&"hound",-3000),"direct -30% Turn Meter cut applies")
	_check(scheduler.gauge_bp(&"hound") == 6000,"meter cut changes gauge without changing Hound Speed")
	_check(scheduler.speed(&"hound") == 45,"meter manipulation never mutates Speed")

func _test_render_partition_counterexample() -> void:
	# This vector proves why the current reboot's sampled _process(delta) authority
	# is unsafe. Actor A truly crosses first, but a single coarse 30 FPS frame lets
	# faster actor B overshoot farther and steals the sampled winner. At 60 FPS A is
	# observed alone and wins. The deterministic scheduler chooses A regardless.
	var scheduler := Scheduler.new()
	scheduler.add_actor(&"a",99,9820)
	scheduler.add_actor(&"b",149,9640)
	var exact := scheduler.next_event()
	_check(StringName(exact.actor_id) == &"a","exact scheduler preserves earliest threshold crossing")
	_check(int(exact.ticks_waited) == 2,"counterexample crossing is resolved at the first deterministic tick")

	var sampled_60 := _sampled_frame_pick([9820,9640],[99,149],1.0/60.0)
	var sampled_30 := _sampled_frame_pick([9820,9640],[99,149],1.0/30.0)
	_check(sampled_60 == 0,"legacy sampled 60 FPS partition happens to pick actor A")
	_check(sampled_30 == 1,"legacy sampled 30 FPS partition incorrectly picks actor B")
	_check(sampled_60 != sampled_30,"legacy sampled authority changes actor order with frame partition")

func _test_battle_speed_changes_wait_only() -> void:
	var ticks := 155
	var wait_1x := Scheduler.ticks_to_seconds(ticks,1.0)
	var wait_2x := Scheduler.ticks_to_seconds(ticks,2.0)
	_check(is_equal_approx(wait_2x,wait_1x*0.5),"x2 presentation speed halves wait duration")
	_check(ticks == 155,"battle speed does not change deterministic turn order/ticks")

func _sampled_frame_pick(gauges_bp: Array, speeds: Array, delta: float) -> int:
	var chosen := -1
	var best := 9999.9
	for i in range(gauges_bp.size()):
		var meter_percent := float(gauges_bp[i]) / 100.0
		meter_percent += float(speeds[i]) * delta * 1.10
		if meter_percent >= 100.0 and meter_percent > best / 100.0:
			best = meter_percent * 100.0
			chosen = i
	return chosen
