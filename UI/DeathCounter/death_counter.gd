extends Node
## Autoload: DeathCounter
## Counts how many times the robot has died this run. Not shown during play:
## it appears in the pause menu and at the end of the credits.
##
## Hooks itself up to any player with a "died" signal, so the player script
## doesn't need to know about it. Starts again from 0 on the main menu
## (every START GAME is a new run).
##
## From anywhere:  DeathCounter.deaths

## Emitted whenever the count changes.
signal changed(deaths: int)

const MAIN_MENU := "res://UI/MainMenu/MainMenu.tscn"

## Deaths in the current run.
var deaths: int = 0

var _hooked: Array = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().node_added.connect(_on_node_added)
	for node in get_tree().root.find_children("*", "", true, false):
		_on_node_added(node)


func _process(_delta: float) -> void:
	# Back on the main menu = the next START GAME is a new run.
	var scene := get_tree().current_scene
	if deaths != 0 and scene != null and scene.scene_file_path == MAIN_MENU:
		reset()


## Back to 0 (a new run).
func reset() -> void:
	deaths = 0
	changed.emit(deaths)


func _on_node_added(node: Node) -> void:
	if node.has_signal("died") and node.has_method("die") and not _hooked.has(node):
		_hooked.append(node)
		node.connect("died", _on_died)
		node.tree_exited.connect(func(): _hooked.erase(node))


func _on_died() -> void:
	deaths += 1
	changed.emit(deaths)
