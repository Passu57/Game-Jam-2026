extends Node2D

@onready var quest_title: Label = $HudLayer/Overlay/QuestPanel/ContentMargin/Content/QuestTitle
@onready var quest_description: Label = $HudLayer/Overlay/QuestPanel/ContentMargin/Content/QuestDescription
@onready var instructions_text: Label = $HudLayer/Overlay/QuestPanel/ContentMargin/Content/InstructionsText
@onready var link_status: Label = $HudLayer/Overlay/QuestPanel/ContentMargin/Content/Header/LinkStatus

var _quest_controller: Node


func _ready() -> void:
	_quest_controller = get_node_or_null("/root/QuestController")
	if _quest_controller:
		if not _quest_controller.is_connected("quest_log_changed", _refresh_quest_box):
			_quest_controller.connect("quest_log_changed", _refresh_quest_box)
	_refresh_quest_box()


func _refresh_quest_box() -> void:
	if _quest_controller == null:
		return

	var quest: Dictionary = _quest_controller.call("get_active_quest")
	if quest.is_empty():
		quest_title.text = "NO ACTIVE QUEST"
		quest_description.text = "Add a quest with QuestController.add_quest()."
		instructions_text.text = "Quest instructions will appear here."
	else:
		quest_title.text = str(quest.get("title", "Untitled quest"))
		quest_description.text = str(quest.get("description", ""))
		instructions_text.text = str(quest.get("instructions", ""))

	link_status.text = "■ %d / %d" % [
		int(_quest_controller.call("get_completed_count")),
		int(_quest_controller.call("get_quest_count"))
	]
