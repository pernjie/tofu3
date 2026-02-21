extends Control

## Victory screen shown when the player wins.

@onready var stats_label: Label = $VBoxContainer/StatsLabel
@onready var return_button: Button = $VBoxContainer/ReturnButton


func _ready() -> void:
	return_button.pressed.connect(_on_return_pressed)
	_update_stats()


func _update_stats() -> void:
	var stats = GameManager.run_stats
	stats_label.text = "Final Reputation: %d\nLevels Completed: %d\nGuests Ascended: %d\nGuests Descended: %d" % [
		GameManager.reputation,
		stats.get("levels_completed", 0),
		stats.get("guests_ascended", 0),
		stats.get("guests_descended", 0)
	]


func _on_return_pressed() -> void:
	get_tree().change_scene_to_file("res://src/ui/screens/start/start_screen.tscn")
