extends RefCounted
## Independent records avoid rewriting the history when a new run is saved.

const DEFAULT_DIRECTORY := "user://bitacora/ensayos"
var _directory: String


func _init(directory: String = DEFAULT_DIRECTORY) -> void:
	_directory = directory


func new_id() -> String:
	var millis := int(Time.get_unix_time_from_system() * 1000)
	return "ensayo-%013d-%s" % [millis, Crypto.new().generate_random_bytes(8).hex_encode()]


func save(record: Dictionary) -> Error:
	if not _valid_record(record):
		return ERR_INVALID_DATA
	var error := DirAccess.make_dir_recursive_absolute(_directory)
	if error != OK:
		return error
	var filename := _directory.path_join(str(record["run_id"]) + ".json")
	if FileAccess.file_exists(filename):
		return ERR_ALREADY_EXISTS
	var temporary := filename + "." + new_id() + ".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(record, "  "))
	file.flush()
	error = file.get_error()
	file.close()
	if error == OK:
		if FileAccess.file_exists(filename):
			error = ERR_ALREADY_EXISTS
		else:
			error = DirAccess.rename_absolute(temporary, filename)
	if error != OK:
		DirAccess.remove_absolute(temporary)
	return error


func recent(limit: int = 20) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	var folder := DirAccess.open(_directory)
	if folder == null or limit <= 0:
		return results
	var filenames := folder.get_files()
	filenames.sort()
	filenames.reverse()
	for name in filenames:
		if not name.ends_with(".json"):
			continue
		var file := FileAccess.open(_directory.path_join(name), FileAccess.READ)
		if file == null:
			continue
		var record: Variant = JSON.parse_string(file.get_as_text())
		file.close()
		if _valid_record(record) and name == str(record["run_id"]) + ".json":
			results.append(record)
		if results.size() >= limit:
			break
	return results


func _valid_record(record: Variant) -> bool:
	if not record is Dictionary or record.get("schema_version") != 1:
		return false
	for field in ["run_id", "experiment_id", "model_version", "quantity", "unit", "source", "validity"]:
		if not record.get(field) is String or record[field].is_empty():
			return false
	var run_id: String = record["run_id"]
	if not run_id.begins_with("ensayo-") or not run_id.is_valid_filename():
		return false
	if record["source"] not in ["test", "simulation"]:
		return false
	if record["source"] == "test" and record["validity"] != "prueba":
		return false
	var value: Variant = record.get("value")
	return record.get("parameters") is Dictionary and (value is float or value is int) and is_finite(float(value))
