extends Control

## Start screen shown when the game launches.

@onready var start_button: Button = $VBoxContainer/StartButton
@onready var quit_button: Button = $VBoxContainer/QuitButton


func _ready() -> void:
	start_button.pressed.connect(_on_start_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	start_button.grab_focus()


func _on_start_pressed() -> void:
	LevelFlowManager.start_new_run()


func _on_quit_pressed() -> void:
	get_tree().quit()
