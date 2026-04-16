extends Control

signal start_requested
signal quit_requested

@onready var _start_button: Button = $PanelContainer/VBox/StartButton
@onready var _quit_button: Button = $PanelContainer/VBox/QuitButton


func _ready() -> void:
	_start_button.pressed.connect(_on_start_pressed)
	_quit_button.pressed.connect(_on_quit_pressed)
	_start_button.grab_focus()


func _on_start_pressed() -> void:
	start_requested.emit()


func _on_quit_pressed() -> void:
	quit_requested.emit()
