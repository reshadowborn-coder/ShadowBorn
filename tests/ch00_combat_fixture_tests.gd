extends SceneTree

const CombatModelScript = preload("res://scripts/combat/ch00_combat_model.gd")
const FIXTURE_PATH := "res://tests/fixtures/ch00_combat_fixtures.csv"
const FLOAT_TOL := 0.00001
const WATCHDOG_SECONDS := 5.0

var failures := 0
var checked_rows := 0
var fixture_count := 0
var finished := false

func _init() -> void:
	var watchdog := create_timer(WATCHDOG_SECONDS)
	watchdog.timeout.connect(_watchdog_timeout)
	call_deferred("_run")

func _watchdog_timeout() -> void:
	if finished:
		return
	push_error("FAIL: Chapter 0 combat fixture test watchdog expired")
	quit(1)

func _fail(message: String) -> void:
	failures += 1
	push_error("FAIL: " + message)

func _check(condition: bool, message: String) -> void:
	if not condition:
		_fail(message)

func _float_close(actual: float, expected: float) -> bool:
	return absf(actual - expected) <= FLOAT_TOL

func _as_bool(value: String) -> bool:
	return value.strip_edges().to_upper() == "Y"

func _cell(row: PackedStringArray, columns: Dictionary, name: String) -> String:
	var index := int(columns.get(name, -1))
	if index < 0 or index >= row.size():
		return ""
	return row[index].strip_edges()

func _check_float(result: Dictionary, key: String, expected_text: String, fixture_id: String, decision: int) -> void:
	if not result.has(key):
		_fail("%s D%d missing %s" % [fixture_id, decision, key])
		return
	var expected := float(expected_text)
	var actual := float(result[key])
	if not _float_close(actual, expected):
		_fail("%s D%d %s expected %.6f got %.6f" % [fixture_id, decision, key, expected, actual])

func _check_int(result: Dictionary, key: String, expected_text: String, fixture_id: String, decision: int) -> void:
	if not result.has(key):
		_fail("%s D%d missing %s" % [fixture_id, decision, key])
		return
	var expected := int(expected_text)
	var actual := int(result[key])
	if actual != expected:
		_fail("%s D%d %s expected %d got %d" % [fixture_id, decision, key, expected, actual])

func _check_bool(result: Dictionary, key: String, expected_text: String, fixture_id: String, decision: int) -> void:
	if not result.has(key):
		_fail("%s D%d missing %s" % [fixture_id, decision, key])
		return
	var expected := _as_bool(expected_text)
	var actual := bool(result[key])
	if actual != expected:
		_fail("%s D%d %s expected %s got %s" % [fixture_id, decision, key, str(expected), str(actual)])

func _check_string(result: Dictionary, key: String, expected: String, fixture_id: String, decision: int) -> void:
	if not result.has(key):
		_fail("%s D%d missing %s" % [fixture_id, decision, key])
		return
	var actual := str(result[key])
	if actual != expected:
		_fail("%s D%d %s expected %s got %s" % [fixture_id, decision, key, expected, actual])

func _finish() -> void:
	finished = true
	print("Chapter 0 combat fixture tests complete. rows=%d fixtures=%d failures=%d" % [checked_rows, fixture_count, failures])
	quit(1 if failures > 0 else 0)

func _run() -> void:
	var file := FileAccess.open(FIXTURE_PATH, FileAccess.READ)
	if file == null:
		_fail("cannot open fixture file: " + FIXTURE_PATH)
		_finish()
		return

	var lines := file.get_as_text().split("\n", false)
	file.close()
	if lines.size() < 2:
		_fail("fixture file has no data rows")
		_finish()
		return

	var header := lines[0].strip_edges().split(",", false)
	var columns := {}
	for i in range(header.size()):
		columns[header[i].strip_edges()] = i

	var required_columns := [
		"fixture_id", "encounter_script_id", "variant", "decision", "visible_state",
		"shadow_hp_before", "enemy_hp_before", "a2_cd_before", "fray_before", "veil_before",
		"action", "outgoing_damage", "enemy_action", "incoming_damage", "veil_prevented",
		"shadow_hp_after", "enemy_hp_after", "a2_cd_after", "fray_after", "veil_after", "terminal"
	]
	for column_name in required_columns:
		_check(columns.has(column_name), "fixture header missing column " + str(column_name))
	if failures > 0:
		_finish()
		return

	var current_fixture := ""
	var model = null

	for line_index in range(1, lines.size()):
		var line := lines[line_index].strip_edges()
		if line.is_empty():
			continue
		var row := line.split(",", false)
		var fixture_id := _cell(row, columns, "fixture_id")
		if fixture_id.is_empty():
			continue

		var script_id := _cell(row, columns, "encounter_script_id")
		var variant := _cell(row, columns, "variant")
		var decision := int(_cell(row, columns, "decision"))

		if fixture_id != current_fixture:
			current_fixture = fixture_id
			fixture_count += 1
			model = CombatModelScript.new()
			var veil_strength := 0.20 if variant == "VEIL_20" else 0.15
			if not model.setup(script_id, veil_strength):
				_fail("%s setup failed for %s" % [fixture_id, script_id])
				continue

		var action := _cell(row, columns, "action")
		var result: Dictionary = model.step(action)
		if result.has("error"):
			_fail("%s D%d model error: %s" % [fixture_id, decision, str(result["error"])])
			continue

		checked_rows += 1
		_check_string(result, "encounter_script_id", script_id, fixture_id, decision)
		_check_int(result, "decision", _cell(row, columns, "decision"), fixture_id, decision)
		_check_string(result, "visible_state", _cell(row, columns, "visible_state"), fixture_id, decision)
		_check_float(result, "shadow_hp_before", _cell(row, columns, "shadow_hp_before"), fixture_id, decision)
		_check_float(result, "enemy_hp_before", _cell(row, columns, "enemy_hp_before"), fixture_id, decision)
		_check_int(result, "a2_cd_before", _cell(row, columns, "a2_cd_before"), fixture_id, decision)
		_check_bool(result, "fray_before", _cell(row, columns, "fray_before"), fixture_id, decision)
		_check_bool(result, "veil_before", _cell(row, columns, "veil_before"), fixture_id, decision)
		_check_string(result, "action", action, fixture_id, decision)
		_check_float(result, "outgoing_damage", _cell(row, columns, "outgoing_damage"), fixture_id, decision)
		_check_string(result, "enemy_action", _cell(row, columns, "enemy_action"), fixture_id, decision)
		_check_float(result, "incoming_damage", _cell(row, columns, "incoming_damage"), fixture_id, decision)
		_check_float(result, "veil_prevented", _cell(row, columns, "veil_prevented"), fixture_id, decision)
		_check_float(result, "shadow_hp_after", _cell(row, columns, "shadow_hp_after"), fixture_id, decision)
		_check_float(result, "enemy_hp_after", _cell(row, columns, "enemy_hp_after"), fixture_id, decision)
		_check_int(result, "a2_cd_after", _cell(row, columns, "a2_cd_after"), fixture_id, decision)
		_check_bool(result, "fray_after", _cell(row, columns, "fray_after"), fixture_id, decision)
		_check_bool(result, "veil_after", _cell(row, columns, "veil_after"), fixture_id, decision)
		_check_string(result, "terminal", _cell(row, columns, "terminal"), fixture_id, decision)

	_check(checked_rows == 44, "expected 44 fixture decision rows, got %d" % checked_rows)
	_check(fixture_count == 9, "expected 9 fixture branches, got %d" % fixture_count)
	_finish()
