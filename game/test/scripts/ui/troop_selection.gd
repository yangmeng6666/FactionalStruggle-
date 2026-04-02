extends Control

signal troop_selected(troop_type: String)

enum TroopType {
	INFANTRY,
	CAVALRY,
}

const TROOP_NAMES: Array[String] = ["Infantry", "Cavalry"]

var _selected_troop: TroopType = TroopType.INFANTRY

@onready var _troop_buttons: Array[Button] = []
@onready var _confirm_button: Button
@onready var _status_label: Label

func _ready() -> void:
	# Get references to UI elements
	var vbox = $PanelContainer/VBox
	var troop_list = vbox.get_node("TroopList")
	_troop_buttons = [
		troop_list.get_node("TroopOption0"),
		troop_list.get_node("TroopOption1"),
	]
	_confirm_button = vbox.get_node("ConfirmButton")
	_status_label = $StatusLabel

	# Connect signals
	for i in range(_troop_buttons.size()):
		var btn = _troop_buttons[i]
		btn.pressed.connect(_on_troop_button_pressed.bind(i))

	_confirm_button.pressed.connect(_on_confirm_pressed)

	# Set initial selection
	_update_selection_ui()


func _on_troop_button_pressed(index: int) -> void:
	_selected_troop = index as TroopType
	_update_selection_ui()


func _on_confirm_pressed() -> void:
	var troop_name: String = TROOP_NAMES[_selected_troop]
	_status_label.text = "Deploying %s..." % troop_name
	troop_selected.emit(TROOP_NAMES[_selected_troop].to_lower())


func _update_selection_ui() -> void:
	for i in range(_troop_buttons.size()):
		var btn = _troop_buttons[i]
		btn.button_pressed = (i == _selected_troop)

	var troop_name: String = TROOP_NAMES[_selected_troop]
	_status_label.text = "Selected: %s" % troop_name