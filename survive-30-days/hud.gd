extends CanvasLayer

signal toggle_pause
signal quit_game

# GameText is available globally via class_name

var score = 0.0
var game_started = false

# Inventory references
var inventory_node: Control
var material_inventory_node: Control

func _ready():
	# Initialize inventory visibility - show it for gameplay
	var inventory = get_inventory()
	if inventory:
		inventory.show()
	
	# Initialize material inventory visibility - show it for gameplay
	var material_inventory = get_material_inventory()
	if material_inventory:
		material_inventory.show()

func update_score(new_score: float):
	score = new_score  # Score now represents days survived
	# Day display is now handled by update_day_display() called from game.gd

func update_day_display(day_number: int):
	"""Update the day display with the correct day number"""
	%ScoreLabel.text = GameText.DAY_FORMAT % day_number

func show_message(text: String):
	%MessageLabel.text = text
	%MessageLabel.show()
	%MessageTimer.start()

func start_game_ui():
	%MessageLabel.hide()
	%ScoreLabel.show()
	%ScoreLabel.text = GameText.DAY_ONE
	
	# Ensure inventory is visible during gameplay
	var inventory = get_inventory()
	if inventory:
		inventory.show()
	
	# Ensure material inventory is visible during gameplay
	var material_inventory = get_material_inventory()
	if material_inventory:
		material_inventory.show()

func _on_quit_button_pressed() -> void:
	hide_pause_menu()
	quit_game.emit()

func show_pause_menu():
	%PauseMenu.show()
	
	# Set focus to the quit button
	%QuitButton.grab_focus()
	
	# Hide inventory in pause menu
	var inventory = get_inventory()
	if inventory:
		inventory.hide()
	
	# Hide material inventory in pause menu
	var material_inventory = get_material_inventory()
	if material_inventory:
		material_inventory.hide()

func hide_pause_menu():
	%PauseMenu.hide()
	
	# Show inventory when returning to gameplay
	if game_started:
		var inventory = get_inventory()
		if inventory:
			inventory.show()
		
		# Show material inventory when returning to gameplay
		var material_inventory = get_material_inventory()
		if material_inventory:
			material_inventory.show()

func set_game_started(started: bool):
	game_started = started

func _input(event):
	if (event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause_game")) and game_started:
		toggle_pause.emit()
	
	# Handle confirm action in pause menu (A button to activate focused button)
	if event.is_action_pressed("confirm_action") and %PauseMenu.visible:
		var focused_control = get_viewport().gui_get_focus_owner()
		if focused_control and focused_control is Button:
			focused_control.pressed.emit()

func _on_message_timer_timeout() -> void:
	%MessageLabel.hide()

# Inventory functions
func get_inventory() -> Control:
	"""Get reference to the inventory node."""
	if not inventory_node:
		inventory_node = %Inventory if has_node("%Inventory") else null
	return inventory_node

func add_item_to_inventory(item_name: String, texture: Texture2D, level: int = 1) -> bool:
	"""Add an item to the player's inventory."""
	var inventory = get_inventory()
	if inventory and inventory.has_method("add_item"):
		return inventory.add_item(item_name, texture, level)
	return false

func remove_item_from_inventory(item_name: String) -> bool:
	"""Remove an item from the player's inventory."""
	var inventory = get_inventory()
	if inventory and inventory.has_method("remove_item"):
		return inventory.remove_item(item_name)
	return false

func level_up_item_in_inventory(item_name: String) -> bool:
	"""Level up an item in the player's inventory."""
	var inventory = get_inventory()
	if inventory and inventory.has_method("level_up_item"):
		return inventory.level_up_item(item_name)
	return false

func get_item_level_from_inventory(item_name: String) -> int:
	"""Get the level of an item in the player's inventory."""
	var inventory = get_inventory()
	if inventory and inventory.has_method("get_item_level"):
		return inventory.get_item_level(item_name)
	return 1

# Material inventory functions
func get_material_inventory() -> Control:
	"""Get reference to the material inventory node."""
	if not material_inventory_node:
		material_inventory_node = %MaterialInventory if has_node("%MaterialInventory") else null
		if not material_inventory_node:
			print("ERROR: MaterialInventory node not found in HUD!")
		else:
			# MaterialInventory node found
			pass
	return material_inventory_node

func add_material_to_inventory(material_name: String, amount: int = 1) -> bool:
	"""Add a material to the material inventory."""
	# Adding material to inventory via HUD
	var material_inventory = get_material_inventory()
	if material_inventory and material_inventory.has_method("add_material"):
		# MaterialInventory found, calling add_material
		material_inventory.add_material(material_name, amount)
		return true
	else:
		print("HUD: ERROR - MaterialInventory not found or doesn't have add_material method")
		# Material inventory reference logged
		if material_inventory:
			# Method availability checked
			pass
	return false

func remove_material_from_inventory(material_name: String, amount: int = 1) -> bool:
	"""Remove a material from the material inventory."""
	var material_inventory = get_material_inventory()
	if material_inventory and material_inventory.has_method("remove_material"):
		return material_inventory.remove_material(material_name, amount)
	return false

func get_material_amount(material_name: String) -> int:
	"""Get the amount of a specific material."""
	var material_inventory = get_material_inventory()
	if material_inventory and material_inventory.has_method("get_material_amount"):
		return material_inventory.get_material_amount(material_name)
	return 0

func has_material(material_name: String, amount: int = 1) -> bool:
	"""Check if the material inventory has enough of a specific material."""
	var material_inventory = get_material_inventory()
	if material_inventory and material_inventory.has_method("has_material"):
		return material_inventory.has_material(material_name, amount)
	return false

# Convenience functions for specific materials
func add_wood(amount: int = 1) -> bool:
	"""Add wood to the material inventory."""
	return add_material_to_inventory(GameText.MATERIAL_WOOD, amount)

func add_rock(amount: int = 1) -> bool:
	"""Add rock to the material inventory."""
	return add_material_to_inventory(GameText.MATERIAL_ROCK, amount)
