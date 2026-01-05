extends Control

# Main menu scene for Let it Climb

signal start_game
signal load_game
signal quit_game

@onready var start_button = %StartButton
@onready var load_button = %LoadButton
@onready var options_button = %OptionsButton
@onready var quit_button = %QuitButton

func _ready():
	# Connect button signals
	start_button.pressed.connect(_on_start_pressed)
	load_button.pressed.connect(_on_load_pressed)
	options_button.pressed.connect(_on_options_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	
	# Check if save file exists
	check_save_file()

func check_save_file():
	"""Check if save file exists and enable/disable load button"""
	var save_file = FileAccess.open("user://let_it_climb_save.dat", FileAccess.READ)
	if save_file:
		save_file.close()
		load_button.disabled = false
	else:
		load_button.disabled = true

func _on_start_pressed():
	"""Handle start game button"""
	start_game.emit()

func _on_load_pressed():
	"""Handle load game button"""
	load_game.emit()

func _on_options_pressed():
	"""Handle options button"""
	show_options_dialog()

func _on_quit_pressed():
	"""Handle quit game button"""
	quit_game.emit()

func show_options_dialog():
	"""Show options dialog"""
	var dialog = AcceptDialog.new()
	dialog.title = "Options"
	
	var vbox = VBoxContainer.new()
	
	var label = Label.new()
	label.text = "Options coming soon!\n\nGame Features:\n• Character progression system\n• Weapon and accessory upgrades\n• Tower climbing with increasing difficulty\n• Resource management\n• Multiple character classes"
	vbox.add_child(label)
	
	dialog.add_child(vbox)
	add_child(dialog)
	dialog.popup_centered()
