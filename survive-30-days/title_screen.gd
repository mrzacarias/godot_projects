extends Control

# Preload the game scene for faster loading
const GAME_SCENE = preload("res://game.tscn")

# Title screen music system
var title_music_player: AudioStreamPlayer
var is_fading_out = false
var fade_duration = 1.0  # 1 second fade out
var fade_timer = 0.0

@onready var title_label = %TitleLabel
@onready var menu_container = %MenuContainer
@onready var new_game_button = %NewGameButton
@onready var how_to_play_button = %HowToPlayButton
@onready var quit_button = %QuitButton
@onready var how_to_play_screen = %HowToPlayScreen
@onready var back_button = %BackButton

# How to Play instruction labels
@onready var movement_label = %MovementLabel
@onready var axe_label = %AxeLabel
@onready var rock_label = %RockLabel
@onready var chests_label = %ChestsLabel
@onready var hourglass_label = %HourglassLabel
@onready var flashlight_label = %FlashlightLabel
@onready var night_label = %NightLabel

# Custom gamepad navigation variables
var previous_stick_y = 0.0  # Track previous stick state for edge detection
var deadzone = 0.9
var navigation_processed = false  # Prevent multiple navigations per stick movement

func _ready():
	# Setup title screen music
	setup_title_music()
	
	# Connect button signals if not already connected in the scene
	if not new_game_button.pressed.is_connected(_on_new_game_button_pressed):
		new_game_button.pressed.connect(_on_new_game_button_pressed)
	if not how_to_play_button.pressed.is_connected(_on_how_to_play_button_pressed):
		how_to_play_button.pressed.connect(_on_how_to_play_button_pressed)
	if not quit_button.pressed.is_connected(_on_quit_button_pressed):
		quit_button.pressed.connect(_on_quit_button_pressed)
	if not back_button.pressed.is_connected(_on_back_button_pressed):
		back_button.pressed.connect(_on_back_button_pressed)
	
	# Set up text from constants
	setup_text_from_constants()
	
	# Set up focus navigation
	setup_focus_navigation()
	
	# Make sure we start with the main menu visible
	show_main_menu()
	
	# HTML5-specific: Ensure proper focus for gamepad input
	if OS.has_feature("web"):
		# Small delay to ensure everything is initialized
		await get_tree().process_frame
		get_viewport().gui_get_focus_owner()
		new_game_button.grab_focus()

func setup_text_from_constants():
	"""Set up all text from GameText constants for consistency"""
	if movement_label:
		movement_label.text = GameText.HOW_TO_PLAY_MOVEMENT
	if axe_label:
		axe_label.text = GameText.HOW_TO_PLAY_AXE
	if rock_label:
		rock_label.text = GameText.HOW_TO_PLAY_ROCKS
	if chests_label:
		chests_label.text = GameText.HOW_TO_PLAY_CHESTS
	if hourglass_label:
		hourglass_label.text = GameText.HOW_TO_PLAY_HOURGLASS
	if flashlight_label:
		flashlight_label.text = GameText.HOW_TO_PLAY_FLASHLIGHT
	if night_label:
		night_label.text = GameText.HOW_TO_PLAY_NIGHT

func setup_focus_navigation():
	# Set up circular navigation between buttons
	new_game_button.focus_neighbor_top = quit_button.get_path()
	new_game_button.focus_neighbor_bottom = how_to_play_button.get_path()
	
	how_to_play_button.focus_neighbor_top = new_game_button.get_path()
	how_to_play_button.focus_neighbor_bottom = quit_button.get_path()
	
	quit_button.focus_neighbor_top = how_to_play_button.get_path()
	quit_button.focus_neighbor_bottom = new_game_button.get_path()

func show_main_menu():
	title_label.visible = true
	menu_container.visible = true
	how_to_play_screen.visible = false
	# Set initial focus to the first button
	new_game_button.grab_focus()

func show_how_to_play():
	title_label.visible = false
	menu_container.visible = false
	how_to_play_screen.visible = true

func _on_new_game_button_pressed():
	# Start fade out of title music before changing scene
	start_music_fade_out()

func _on_how_to_play_button_pressed():
	show_how_to_play()

func _on_quit_button_pressed():
	get_tree().quit()

func _on_back_button_pressed():
	show_main_menu()

func _process(delta):
	# Handle music fade out
	if is_fading_out:
		handle_music_fade_out(delta)
	
	# Handle custom gamepad navigation
	handle_gamepad_navigation(delta)

# Handle input for navigation
func _input(event):
	# Handle back button (Esc key and B gamepad button)
	if event.is_action_pressed("ui_cancel"):
		if how_to_play_screen.visible:
			show_main_menu()
		else:
			get_tree().quit()
	
	# Handle confirm action (Enter key and A gamepad button)
	if event.is_action_pressed("ui_accept"):
		if menu_container.visible:
			# Get the currently focused button and activate it
			var focused_control = get_viewport().gui_get_focus_owner()
			if focused_control and focused_control is Button:
				focused_control.pressed.emit()
		elif how_to_play_screen.visible:
			# In how to play screen, confirm acts as back
			show_main_menu()

# Title Screen Music Functions
func setup_title_music():
	"""Initialize the title screen music player"""
	title_music_player = AudioStreamPlayer.new()
	title_music_player.name = "TitleMusicPlayer"
	title_music_player.volume_db = 0.0
	title_music_player.autoplay = false
	
	# Load and setup the title screen music with looping
	var title_stream = load("res://assets/sounds/title_screen.mp3")
	if title_stream:
		title_stream.loop = true  # Enable looping
	title_music_player.stream = title_stream
	add_child(title_music_player)
	
	# Start playing the music with fade in
	title_music_player.volume_db = -80.0  # Start silent
	title_music_player.play()
	
	# Fade in over 1 second
	var fade_in_tween = create_tween()
	fade_in_tween.tween_property(title_music_player, "volume_db", 0.0, 1.0)

func start_music_fade_out():
	"""Start fading out the title music before transitioning to game"""
	if title_music_player and title_music_player.playing:
		is_fading_out = true
		fade_timer = 0.0

func handle_music_fade_out(delta):
	"""Handle the fade out process"""
	if not title_music_player:
		return
	
	fade_timer += delta
	var fade_progress = fade_timer / fade_duration
	
	if fade_progress >= 1.0:
		# Fade complete - stop music and change scene
		title_music_player.stop()
		is_fading_out = false
		get_tree().change_scene_to_packed(GAME_SCENE)
	else:
		# Update volume during fade
		var fade_volume = lerp(0.0, -80.0, fade_progress)  # Fade from 0dB to -80dB (silent)
		title_music_player.volume_db = fade_volume

func handle_gamepad_navigation(_delta):
	"""Handle custom gamepad left stick navigation with edge detection"""
	# Only handle navigation in main menu
	if not menu_container.visible:
		return
	
	# Get left stick Y-axis directly
	var current_stick_y = Input.get_joy_axis(0, JOY_AXIS_LEFT_Y)  # Device 0, left stick Y-axis
	
	# Check if stick is currently in deadzone (neutral position)
	var stick_in_deadzone = abs(current_stick_y) < deadzone
	
	# Reset navigation flag when stick returns to neutral
	if stick_in_deadzone:
		navigation_processed = false
		previous_stick_y = current_stick_y
		return
	
	# If we've already processed navigation for this stick movement, don't do it again
	if navigation_processed:
		previous_stick_y = current_stick_y
		return
	
	# Check for transitions from deadzone to active (true edge detection)
	var previous_in_deadzone = abs(previous_stick_y) < deadzone
	var navigate_up = current_stick_y < -deadzone and previous_in_deadzone
	var navigate_down = current_stick_y > deadzone and previous_in_deadzone
	
	if navigate_up or navigate_down:
		var current_focus = get_viewport().gui_get_focus_owner()
		if current_focus and current_focus is Button:
			var next_button: Button = null
			
			if navigate_up:  # Up movement
				if current_focus == new_game_button:
					next_button = quit_button
				elif current_focus == how_to_play_button:
					next_button = new_game_button
				elif current_focus == quit_button:
					next_button = how_to_play_button
			elif navigate_down:  # Down movement
				if current_focus == new_game_button:
					next_button = how_to_play_button
				elif current_focus == how_to_play_button:
					next_button = quit_button
				elif current_focus == quit_button:
					next_button = new_game_button
			
			# Apply navigation and mark as processed
			if next_button:
				next_button.grab_focus()
				navigation_processed = true
	
	# Store current stick position for next frame
	previous_stick_y = current_stick_y
