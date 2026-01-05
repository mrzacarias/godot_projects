class_name PlayerData
extends Resource

# Player persistent data for Let it Climb

signal data_changed

@export var current_character: Character
@export var unlocked_characters: Array[GameConstants.CharacterClass] = []
@export var unlocked_weapons: Array[GameConstants.WeaponType] = []
@export var unlocked_accessories: Array[GameConstants.AccessoryType] = []

# Progression
@export var highest_floor: int = 1
@export var total_experience: int = 0

# Resources in storage
@export var stored_resources: Dictionary = {}

# Equipment blueprints and R&D progress
@export var weapon_progress: Dictionary = {}  # weapon_type -> {tier: int, level: int}
@export var accessory_progress: Dictionary = {}  # accessory_type -> {tier: int, level: int}

func _init():
	# Initialize with starting character and equipment
	current_character = Character.new(GameConstants.CharacterClass.ALL_ROUNDER)
	unlocked_characters = [GameConstants.CharacterClass.ALL_ROUNDER]
	unlocked_weapons = [GameConstants.WeaponType.SWORD]
	
	# Initialize weapon progress with starting sword
	weapon_progress[GameConstants.WeaponType.SWORD] = {"tier": 1, "level": 1}

func unlock_character_class(char_class: GameConstants.CharacterClass):
	"""Unlock a new character class"""
	if char_class not in unlocked_characters:
		unlocked_characters.append(char_class)
		data_changed.emit()

func unlock_weapon(weapon_type: GameConstants.WeaponType):
	"""Unlock a new weapon"""
	if weapon_type not in unlocked_weapons:
		unlocked_weapons.append(weapon_type)
		weapon_progress[weapon_type] = {"tier": 1, "level": 1}
		data_changed.emit()

func unlock_accessory(accessory_type: GameConstants.AccessoryType):
	"""Unlock a new accessory"""
	if accessory_type not in unlocked_accessories:
		unlocked_accessories.append(accessory_type)
		accessory_progress[accessory_type] = {"tier": 1, "level": 1}
		data_changed.emit()

func add_resources(resource_type: GameConstants.ResourceType, amount: int):
	"""Add resources to storage"""
	if resource_type not in stored_resources:
		stored_resources[resource_type] = 0
	stored_resources[resource_type] += amount
	data_changed.emit()

func remove_resources(resource_type: GameConstants.ResourceType, amount: int) -> bool:
	"""Remove resources from storage, return true if successful"""
	if resource_type not in stored_resources or stored_resources[resource_type] < amount:
		return false
	
	stored_resources[resource_type] -= amount
	data_changed.emit()
	return true

func get_resource_count(resource_type: GameConstants.ResourceType) -> int:
	"""Get count of specific resource"""
	return stored_resources.get(resource_type, 0)

func handle_death():
	"""Handle player death - lose carried items but keep permanent progress"""
	# Permanent progress is kept (character levels, unlocked items, R&D progress)
	# Only carried items would be lost, but those are handled by the tower scene
	pass

func handle_victory():
	"""Handle tower completion victory"""
	# Award bonus experience or resources
	total_experience += 1000
	data_changed.emit()

func check_character_unlocks():
	"""Check and unlock character classes based on highest floor"""
	var unlocked_any = false
	
	for char_class in GameConstants.CharacterClass.values():
		if char_class not in unlocked_characters:
			var class_data = GameConstants.CHARACTER_CLASSES[char_class]
			if highest_floor >= class_data.unlock_floor:
				unlock_character_class(char_class)
				unlocked_any = true
	
	return unlocked_any

func to_save_data() -> Dictionary:
	"""Convert to save data"""
	return {
		"current_character": current_character.to_save_data() if current_character else {},
		"unlocked_characters": unlocked_characters,
		"unlocked_weapons": unlocked_weapons,
		"unlocked_accessories": unlocked_accessories,
		"highest_floor": highest_floor,
		"total_experience": total_experience,
		"stored_resources": stored_resources,
		"weapon_progress": weapon_progress,
		"accessory_progress": accessory_progress
	}

func from_save_data(data: Dictionary):
	"""Load from save data"""
	# Load character
	if "current_character" in data and data.current_character:
		current_character = Character.new()
		current_character.from_save_data(data.current_character)
	
	# Convert arrays to proper types (JSON loses type information and may convert ints to floats)
	var chars_data = data.get("unlocked_characters", [GameConstants.CharacterClass.ALL_ROUNDER])
	unlocked_characters.clear()
	for char_class in chars_data:
		unlocked_characters.append(int(char_class))  # Ensure it's an int
	
	var weapons_data = data.get("unlocked_weapons", [GameConstants.WeaponType.SWORD])
	unlocked_weapons.clear()
	for weapon_type in weapons_data:
		unlocked_weapons.append(int(weapon_type))  # Ensure it's an int
	
	var accessories_data = data.get("unlocked_accessories", [])
	unlocked_accessories.clear()
	for accessory_type in accessories_data:
		unlocked_accessories.append(int(accessory_type))  # Ensure it's an int
	highest_floor = data.get("highest_floor", 1)
	total_experience = data.get("total_experience", 0)
	stored_resources = data.get("stored_resources", {})
	weapon_progress = data.get("weapon_progress", {GameConstants.WeaponType.SWORD: {"tier": 1, "level": 1}})
	accessory_progress = data.get("accessory_progress", {})
	
	data_changed.emit()
