class_name Checkpoint01Save
extends RefCounted

const SAVE_VERSION := 1
const FORMAT_ID := "shadowborn_checkpoint01"
const SAVE_PATH := "user://checkpoint01_save_v1.json"
const TMP_PATH := SAVE_PATH + ".tmp"
const BAK_PATH := SAVE_PATH + ".bak"
const MAX_SAVE_BYTES := 32768
const VALID_CHECKPOINTS := ["title","awakening","first_battle"]

static func default_state() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"generation": 0,
		"checkpoint": "title"
	}

static func load_state() -> Dictionary:
	var primary: Variant = _read_state(SAVE_PATH)
	if primary != null:
		return primary

	# If promotion was interrupted after primary->backup but before tmp->primary,
	# the fully flushed/read-back temporary generation is newer than the backup.
	var temporary: Variant = _read_state(TMP_PATH)
	if temporary != null:
		return temporary

	var backup: Variant = _read_state(BAK_PATH)
	if backup != null:
		return backup
	return default_state()

static func save_checkpoint(checkpoint: String) -> bool:
	if checkpoint not in VALID_CHECKPOINTS:
		return false

	var previous := load_state()
	var state := {
		"version": SAVE_VERSION,
		"generation": clampi(int(previous.get("generation",0))+1,1,2147483647),
		"checkpoint": checkpoint
	}
	var payload_json := JSON.stringify(state)
	var envelope := {
		"format": FORMAT_ID,
		"payload": payload_json,
		"sha256": payload_json.sha256_text()
	}
	var encoded := JSON.stringify(envelope)
	if encoded.to_utf8_buffer().size() > MAX_SAVE_BYTES:
		return false

	var file := FileAccess.open(TMP_PATH,FileAccess.WRITE)
	if file == null:
		return false
	var stored := file.store_string(encoded)
	file.flush()
	var write_error := file.get_error()
	file.close()
	if not stored or write_error != OK:
		_remove_if_exists(TMP_PATH)
		return false

	# Never rotate away the last-good primary until the just-written candidate
	# passes its own checksum/schema readback.
	if _read_state(TMP_PATH) == null:
		_remove_if_exists(TMP_PATH)
		return false

	var save_abs := ProjectSettings.globalize_path(SAVE_PATH)
	var tmp_abs := ProjectSettings.globalize_path(TMP_PATH)
	var bak_abs := ProjectSettings.globalize_path(BAK_PATH)

	_remove_if_exists(BAK_PATH)
	if FileAccess.file_exists(SAVE_PATH):
		var backup_error := DirAccess.rename_absolute(save_abs,bak_abs)
		if backup_error != OK:
			_remove_if_exists(TMP_PATH)
			return false

	var promote_error := DirAccess.rename_absolute(tmp_abs,save_abs)
	if promote_error != OK:
		# Best-effort rollback leaves the previous valid generation authoritative.
		if FileAccess.file_exists(BAK_PATH) and not FileAccess.file_exists(SAVE_PATH):
			DirAccess.rename_absolute(bak_abs,save_abs)
		return false
	return true

static func has_resume_checkpoint() -> bool:
	return str(load_state().get("checkpoint","title")) != "title"

static func _read_state(path: String):
	if not FileAccess.file_exists(path):
		return null
	var file := FileAccess.open(path,FileAccess.READ)
	if file == null:
		return null
	var length := file.get_length()
	if length <= 0 or length > MAX_SAVE_BYTES:
		file.close()
		return null
	var text := file.get_as_text()
	file.close()

	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return null
	var envelope: Dictionary = parsed
	if str(envelope.get("format","")) != FORMAT_ID:
		return null
	var payload = envelope.get("payload","")
	if typeof(payload) != TYPE_STRING:
		return null
	var payload_json := str(payload)
	if payload_json.is_empty() or payload_json.to_utf8_buffer().size() > MAX_SAVE_BYTES:
		return null
	var checksum = envelope.get("sha256","")
	if typeof(checksum) != TYPE_STRING or str(checksum) != payload_json.sha256_text():
		return null

	var state_variant = JSON.parse_string(payload_json)
	if typeof(state_variant) != TYPE_DICTIONARY:
		return null
	return _validate_state(state_variant)

static func _validate_state(raw: Dictionary):
	var version_value = raw.get("version",null)
	if typeof(version_value) not in [TYPE_INT,TYPE_FLOAT]:
		return null
	var version_number := float(version_value)
	if version_number != floor(version_number) or int(version_number) != SAVE_VERSION:
		return null
	var generation_value = raw.get("generation",null)
	if typeof(generation_value) not in [TYPE_INT,TYPE_FLOAT]:
		return null
	var generation_number := float(generation_value)
	if generation_number != floor(generation_number):
		return null
	var generation := int(generation_number)
	if generation < 0 or generation > 2147483647:
		return null
	if typeof(raw.get("checkpoint",null)) != TYPE_STRING:
		return null
	var checkpoint := str(raw.get("checkpoint",""))
	if checkpoint not in VALID_CHECKPOINTS:
		return null
	# Return only the canonical bounded schema; unknown fields never propagate.
	return {
		"version": SAVE_VERSION,
		"generation": generation,
		"checkpoint": checkpoint
	}

static func _remove_if_exists(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
