extends Node

signal quest_log_changed
signal quest_completed(quest_id: String)

const SAVE_PATH := "user://quest_log.json"

var _quests: Array = []
var _active_quest_id := ""


func _ready() -> void:
	_load_quests()
	if _quests.is_empty():
		add_quest(
			"restore_first_color",
			"Restore the first color",
			"Find the relay switch. Reach the core to bring the world back to life.",
			"MOVE  A / D  or  ← / →\nJUMP  Space  or  W / ↑\nStep on the relay to rebuild the bridge.",
			true
		)


func add_quest(id: String, title: String, description: String, instructions: String = "", make_active: bool = true) -> void:
	if id.strip_edges().is_empty():
		push_warning("QuestController.add_quest requires a non-empty id.")
		return

	var existing_index := _find_quest_index(id)
	var quest := {
		"id": id,
		"title": title,
		"description": description,
		"instructions": instructions,
		"completed": false
	}
	if existing_index >= 0:
		_quests[existing_index] = quest
	else:
		_quests.append(quest)

	if make_active or _active_quest_id.is_empty():
		_active_quest_id = id
	_save_and_notify()


func set_active_quest(id: String) -> bool:
	if _find_quest_index(id) < 0:
		return false
	_active_quest_id = id
	_save_and_notify()
	return true


func update_quest(id: String, changes: Dictionary) -> bool:
	var index := _find_quest_index(id)
	if index < 0:
		return false

	for key in ["title", "description", "instructions"]:
		if changes.has(key):
			_quests[index][key] = str(changes[key])
	_save_and_notify()
	return true


func complete_quest(id: String) -> bool:
	var index := _find_quest_index(id)
	if index < 0:
		return false

	if not bool(_quests[index].get("completed", false)):
		_quests[index]["completed"] = true
		quest_completed.emit(id)
	_save_and_notify()
	return true


func remove_quest(id: String) -> bool:
	var index := _find_quest_index(id)
	if index < 0:
		return false

	_quests.remove_at(index)
	if _active_quest_id == id:
		_active_quest_id = ""
		for quest in _quests:
			if not bool(quest.get("completed", false)):
				_active_quest_id = str(quest.get("id", ""))
				break
	_save_and_notify()
	return true


func clear_quests() -> void:
	_quests.clear()
	_active_quest_id = ""
	_save_and_notify()


func get_active_quest() -> Dictionary:
	var index := _find_quest_index(_active_quest_id)
	if index < 0:
		return {}
	return _quests[index].duplicate(true)


func get_quests() -> Array:
	return _quests.duplicate(true)


func get_quest_count() -> int:
	return _quests.size()


func get_completed_count() -> int:
	var completed := 0
	for quest in _quests:
		if bool(quest.get("completed", false)):
			completed += 1
	return completed


func _find_quest_index(id: String) -> int:
	for index in range(_quests.size()):
		if str(_quests[index].get("id", "")) == id:
			return index
	return -1


func _save_and_notify() -> void:
	var data := {
		"active_quest_id": _active_quest_id,
		"quests": _quests
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data, "\t"))
		file.close()
	quest_log_changed.emit()


func _load_quests() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()

	if not parsed is Dictionary:
		return
	var stored_quests: Variant = parsed.get("quests", [])
	if not stored_quests is Array:
		return

	_quests.clear()
	for stored in stored_quests:
		if stored is Dictionary and not str(stored.get("id", "")).is_empty():
			_quests.append(stored.duplicate(true))
	_active_quest_id = str(parsed.get("active_quest_id", ""))
	if _find_quest_index(_active_quest_id) < 0:
		_active_quest_id = ""
		for quest in _quests:
			if not bool(quest.get("completed", false)):
				_active_quest_id = str(quest.get("id", ""))
				break
