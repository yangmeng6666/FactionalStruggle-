extends Node

signal battle_started(troop_type: String)

const TROOP_SELECTION_SCENE: String = "res://scenes/troop_selection.tscn"
const BATTLE_ROOT_SCENE: String = "res://scenes/battle_root.tscn"

@onready var _troop_selection: Control = null
@onready var _battle_root: Node2D = null
@onready var _ui_root: CanvasLayer = null

var _current_troop: String = "infantry"


func _ready() -> void:
	add_to_group("flow_controller")
	_show_troop_selection()


func _show_troop_selection() -> void:
	# Clean up existing battle if any
	if _battle_root != null:
		_battle_root.queue_free()
		_battle_root = null

	# Create troop selection UI
	_troop_selection = load(TROOP_SELECTION_SCENE).instantiate()
	add_child(_troop_selection)
	_troop_selection.troop_selected.connect(_on_troop_selected)


func _on_troop_selected(troop_type: String) -> void:
	_current_troop = troop_type
	_start_battle()


func _start_battle() -> void:
	# Remove troop selection
	if _troop_selection != null:
		_troop_selection.queue_free()
		_troop_selection = null

	# Create battle scene
	_battle_root = load(BATTLE_ROOT_SCENE).instantiate()
	add_child(_battle_root)

	# Initialize battle with selected troop
	if _battle_root.has_method("spawn_player_units"):
		_battle_root.spawn_player_units(_current_troop)

	battle_started.emit(_current_troop)


func get_current_troop() -> String:
	return _current_troop