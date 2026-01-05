extends Node2D

# Base hub scene for Let it Climb

signal enter_tower(floor: int)
signal character_upgraded

var player_data: PlayerData

# UI references
@onready var mage_button = %MageButton
@onready var blacksmith_button = %BlacksmithButton
@onready var tavern_button = %TavernButton
@onready var storage_button = %StorageButton
@onready var stairs_button = %StairsButton
@onready var portal_button = %PortalButton
@onready var character_info = %CharacterInfo

func _ready():
	# Connect button signals
	mage_button.pressed.connect(_on_mage_pressed)
	blacksmith_button.pressed.connect(_on_blacksmith_pressed)
	tavern_button.pressed.connect(_on_tavern_pressed)
	storage_button.pressed.connect(_on_storage_pressed)
	stairs_button.pressed.connect(_on_stairs_pressed)
	portal_button.pressed.connect(_on_portal_pressed)

func setup_base(data: PlayerData):
	"""Setup base with player data"""
	player_data = data
	update_ui()

func update_ui():
	"""Update UI with current player data"""
	if not player_data or not player_data.current_character:
		return
	
	var character = player_data.current_character
	var info_text = "Character: %s\n" % character.get_class_name()
	info_text += "Level: %d / Tier: %d\n" % [character.level, character.tier]
	info_text += "VIT: %d | STR: %d | DEX: %d\n" % [character.current_vit, character.current_str, character.current_dex]
	info_text += "SPD: %d | LUK: %d\n" % [character.current_spd, character.current_luk]
	info_text += "HP: %d/%d" % [character.current_hp, character.max_hp]
	
	character_info.text = info_text
	
	# Update portal button based on unlocked floors
	var portal_floors = []
	for floor_num in range(5, player_data.highest_floor + 1, 5):
		portal_floors.append(floor_num)
	
	if portal_floors.size() > 0:
		portal_button.text = "Portal\n(Floors: %s)" % str(portal_floors)
		portal_button.disabled = false
	else:
		portal_button.text = "Portal\n(No floors unlocked)"
		portal_button.disabled = true

func _on_mage_pressed():
	"""Handle mage interaction - character upgrades"""
	show_mage_dialog()

func _on_blacksmith_pressed():
	"""Handle blacksmith interaction - R&D"""
	show_blacksmith_dialog()

func _on_tavern_pressed():
	"""Handle tavern interaction - character selection"""
	show_tavern_dialog()

func _on_storage_pressed():
	"""Handle storage interaction - resource management"""
	show_storage_dialog()

func _on_stairs_pressed():
	"""Handle stairs - go to floor 1"""
	enter_tower.emit(1)

func _on_portal_pressed():
	"""Handle portal - select special floor"""
	show_portal_dialog()

func show_mage_dialog():
	"""Show mage upgrade dialog"""
	# Close any existing dialogs first
	close_all_dialogs()
	
	# Wait a frame to ensure dialogs are properly closed
	await get_tree().process_frame
	
	var dialog = AcceptDialog.new()
	dialog.title = "Mage - Character Upgrades"
	
	var vbox = VBoxContainer.new()
	
	if not player_data or not player_data.current_character:
		vbox.add_child(Label.new())
		vbox.get_child(-1).text = "No character data available"
	else:
		var character = player_data.current_character
		
		# Level up button
		if character.level < character.get_max_level():
			var level_button = Button.new()
			level_button.text = "Level Up (Cost: %d EXP)" % (character.level * 100)
			level_button.pressed.connect(func(): level_up_character(dialog))
			vbox.add_child(level_button)
		
		# Tier upgrade button
		if character.level >= character.get_max_level() and character.tier < 4:
			var tier_button = Button.new()
			tier_button.text = "Upgrade Tier (Cost: %d EXP)" % (character.tier * 500)
			tier_button.pressed.connect(func(): upgrade_character_tier(dialog))
			vbox.add_child(tier_button)
		
		# Current stats display
		var stats_label = Label.new()
		stats_label.text = "Current Stats:\nLevel: %d/%d (Tier %d)\nEXP: %d" % [
			character.level, character.get_max_level(), character.tier, player_data.total_experience
		]
		vbox.add_child(stats_label)
	
	dialog.add_child(vbox)
	add_child(dialog)
	dialog.popup_centered()

func level_up_character(dialog: AcceptDialog):
	"""Level up the character"""
	if not player_data or not player_data.current_character:
		return
	
	var character = player_data.current_character
	var cost = character.level * 100
	
	if player_data.total_experience >= cost:
		player_data.total_experience -= cost
		character.level_up()
		character_upgraded.emit()
		update_ui()
		dialog.queue_free()
		# Wait a frame before showing new dialog to avoid exclusive window conflict
		await get_tree().process_frame
		show_mage_dialog()  # Refresh dialog
	else:
		# Close current dialog first, then show message
		dialog.queue_free()
		await get_tree().process_frame
		show_message("Not enough experience!")

func upgrade_character_tier(dialog: AcceptDialog):
	"""Upgrade character tier"""
	if not player_data or not player_data.current_character:
		return
	
	var character = player_data.current_character
	var cost = character.tier * 500
	
	if player_data.total_experience >= cost:
		player_data.total_experience -= cost
		character.upgrade_tier()
		character_upgraded.emit()
		update_ui()
		dialog.queue_free()
		# Wait a frame before showing new dialog to avoid exclusive window conflict
		await get_tree().process_frame
		show_mage_dialog()  # Refresh dialog
	else:
		# Close current dialog first, then show message
		dialog.queue_free()
		await get_tree().process_frame
		show_message("Not enough experience!")

func show_blacksmith_dialog():
	"""Show blacksmith R&D dialog"""
	var dialog = AcceptDialog.new()
	dialog.title = "Blacksmith - Research & Development"
	
	var vbox = VBoxContainer.new()
	var label = Label.new()
	label.text = "Weapon and Accessory upgrades coming soon!\n\nUnlocked Weapons: %d\nUnlocked Accessories: %d" % [
		player_data.unlocked_weapons.size() if player_data else 0,
		player_data.unlocked_accessories.size() if player_data else 0
	]
	vbox.add_child(label)
	
	dialog.add_child(vbox)
	add_child(dialog)
	dialog.popup_centered()

func show_tavern_dialog():
	"""Show tavern character selection dialog"""
	var dialog = AcceptDialog.new()
	dialog.title = "Tavern - Character Selection"
	
	var vbox = VBoxContainer.new()
	
	if not player_data:
		vbox.add_child(Label.new())
		vbox.get_child(-1).text = "No player data available"
	else:
		for char_class in player_data.unlocked_characters:
			var button = Button.new()
			var class_data = GameConstants.CHARACTER_CLASSES[char_class]
			button.text = "%s\n%s" % [class_data.name, class_data.description]
			
			if player_data.current_character and player_data.current_character.character_class == char_class:
				button.text += "\n[CURRENT]"
				button.disabled = true
			else:
				button.pressed.connect(func(): select_character(char_class, dialog))
			
			vbox.add_child(button)
	
	dialog.add_child(vbox)
	add_child(dialog)
	dialog.popup_centered()

func select_character(char_class: GameConstants.CharacterClass, dialog: AcceptDialog):
	"""Select a different character class"""
	if player_data:
		player_data.current_character = Character.new(char_class)
		update_ui()
		dialog.queue_free()
		show_message("Character changed to %s!" % GameConstants.CHARACTER_CLASSES[char_class].name)

func show_storage_dialog():
	"""Show storage resource management dialog"""
	var dialog = AcceptDialog.new()
	dialog.title = "Storage - Resources"
	
	var vbox = VBoxContainer.new()
	
	if not player_data or player_data.stored_resources.is_empty():
		var label = Label.new()
		label.text = "No resources in storage"
		vbox.add_child(label)
	else:
		var label = Label.new()
		label.text = "Stored Resources:"
		vbox.add_child(label)
		
		for resource_type in player_data.stored_resources:
			var count = player_data.stored_resources[resource_type]
			if count > 0:
				var resource_data = GameConstants.RESOURCES[resource_type]
				var resource_label = Label.new()
				resource_label.text = "%s: %d" % [resource_data.name, count]
				vbox.add_child(resource_label)
	
	dialog.add_child(vbox)
	add_child(dialog)
	dialog.popup_centered()

func show_portal_dialog():
	"""Show portal floor selection dialog"""
	# Close any existing dialogs first
	close_all_dialogs()
	
	# Wait a frame to ensure dialogs are properly closed
	await get_tree().process_frame
	
	var dialog = AcceptDialog.new()
	dialog.title = "Portal - Select Floor"
	
	var vbox = VBoxContainer.new()
	
	var available_floors = []
	for floor_num in range(5, player_data.highest_floor + 1, 5):
		available_floors.append(floor_num)
	
	if available_floors.is_empty():
		var label = Label.new()
		label.text = "No special floors unlocked yet.\nReach floor 5 to unlock the first portal floor."
		vbox.add_child(label)
	else:
		var label = Label.new()
		label.text = "Select a floor to enter:"
		vbox.add_child(label)
		
		for floor_num in available_floors:
			var button = Button.new()
			button.text = "Floor %d" % floor_num
			button.pressed.connect(func(): enter_portal_floor(floor_num, dialog))
			vbox.add_child(button)
	
	dialog.add_child(vbox)
	add_child(dialog)
	dialog.popup_centered()

func enter_portal_floor(floor_number: int, dialog: AcceptDialog):
	"""Enter a specific floor via portal"""
	dialog.queue_free()
	enter_tower.emit(floor_number)

func close_all_dialogs():
	"""Close all existing dialogs immediately"""
	for child in get_children():
		if child is AcceptDialog:
			child.queue_free()

func show_message(text: String):
	"""Show a simple message dialog"""
	# Close any existing dialogs first
	close_all_dialogs()
	
	# Wait a frame to ensure dialogs are properly closed
	await get_tree().process_frame
	
	var dialog = AcceptDialog.new()
	dialog.dialog_text = text
	add_child(dialog)
	dialog.popup_centered()
