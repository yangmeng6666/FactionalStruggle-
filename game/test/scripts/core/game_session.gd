extends Node

signal selection_changed(selected_count: int)
signal phase_changed(phase: String)

var current_phase: String = "day"
var _selected_squads: Array = []

func _ready() -> void:
	add_to_group("game_session")

func set_selected_squads(squads: Array) -> void:
	_cleanup_selected_squads()

	var next_selected: Array = []
	var seen: Dictionary = {}
	for squad in squads:
		if not is_instance_valid(squad):
			continue
		var instance_id: int = squad.get_instance_id()
		if seen.has(instance_id):
			continue
		seen[instance_id] = true
		next_selected.append(squad)

	for squad in _selected_squads:
		if is_instance_valid(squad) and squad.has_method("set_selected") and not next_selected.has(squad):
			squad.set_selected(false)

	for squad in next_selected:
		if squad.has_method("set_selected"):
			squad.set_selected(true)

	_selected_squads = next_selected
	selection_changed.emit(_selected_squads.size())

func clear_selection() -> void:
	set_selected_squads([])

func get_selected_squads() -> Array:
	_cleanup_selected_squads()
	return _selected_squads.duplicate()

func set_phase(phase: String) -> void:
	if current_phase == phase:
		return
	current_phase = phase
	phase_changed.emit(current_phase)

func get_phase() -> String:
	return current_phase

func _cleanup_selected_squads() -> void:
	var alive: Array = []
	for squad in _selected_squads:
		if is_instance_valid(squad):
			alive.append(squad)
	_selected_squads = alive
