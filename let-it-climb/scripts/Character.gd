class_name Character
extends Resource

# Character stats and progression system

signal stats_changed
signal level_changed
signal tier_changed

@export var character_class: GameConstants.CharacterClass = GameConstants.CharacterClass.ALL_ROUNDER
@export var level: int = 1
@export var tier: int = 1
@export var experience: int = 0

# Base stats
@export var base_vit: int = 10
@export var base_str: int = 10  
@export var base_dex: int = 10
@export var base_spd: int = 10
@export var base_luk: int = 10

# Current stats (calculated from base + level bonuses)
var current_vit: int
var current_str: int
var current_dex: int
var current_spd: int
var current_luk: int

# Derived stats
var max_hp: int
var current_hp: int

func _init(char_class: GameConstants.CharacterClass = GameConstants.CharacterClass.ALL_ROUNDER):
	character_class = char_class
	calculate_stats()
	current_hp = max_hp

func calculate_stats():
	"""Calculate current stats based on level and class"""
	var class_data = GameConstants.CHARACTER_CLASSES[character_class]
	var stat_growth = class_data.stat_growth
	
	# Calculate level bonuses (level - 1 because level 1 has no bonus)
	var level_bonus = level - 1
	
	current_vit = base_vit + (stat_growth.vit * level_bonus)
	current_str = base_str + (stat_growth.str * level_bonus)
	current_dex = base_dex + (stat_growth.dex * level_bonus)
	current_spd = base_spd + (stat_growth.spd * level_bonus)
	current_luk = base_luk + (stat_growth.luk * level_bonus)
	
	# Calculate derived stats
	max_hp = current_vit * GameConstants.HP_PER_VIT
	
	stats_changed.emit()

func level_up() -> bool:
	"""Level up the character if possible"""
	var tier_data = GameConstants.CHARACTER_TIERS[tier]
	if level >= tier_data.max_level:
		return false  # Cannot level up, need to upgrade tier
	
	level += 1
	calculate_stats()
	level_changed.emit()
	return true

func upgrade_tier() -> bool:
	"""Upgrade character tier if possible"""
	if tier >= 5:
		return false  # Max tier reached
	
	tier += 1
	calculate_stats()
	tier_changed.emit()
	return true

func get_max_level() -> int:
	"""Get maximum level for current tier"""
	return GameConstants.CHARACTER_TIERS[tier].max_level

func get_max_accessories() -> int:
	"""Get maximum accessories for current tier"""
	return GameConstants.CHARACTER_TIERS[tier].accessories

func get_bag_slots() -> int:
	"""Get bag slots for current tier and class"""
	var tier_data = GameConstants.CHARACTER_TIERS[tier]
	if character_class == GameConstants.CharacterClass.COLLECTOR:
		return tier_data.collector_bag
	else:
		return tier_data.bag_slots

func get_class_name() -> String:
	"""Get the display name of the character class"""
	return GameConstants.CHARACTER_CLASSES[character_class].name

func get_class_description() -> String:
	"""Get the description of the character class"""
	return GameConstants.CHARACTER_CLASSES[character_class].description

func is_class_unlocked(highest_floor: int) -> bool:
	"""Check if this character class is unlocked based on highest floor reached"""
	var unlock_floor = GameConstants.CHARACTER_CLASSES[character_class].unlock_floor
	return highest_floor >= unlock_floor

func heal_to_full():
	"""Heal character to full HP"""
	current_hp = max_hp

func take_damage(damage: int) -> bool:
	"""Take damage and return true if character dies"""
	current_hp = max(0, current_hp - damage)
	return current_hp <= 0

func heal(amount: int):
	"""Heal character by specified amount"""
	current_hp = min(max_hp, current_hp + amount)

func get_stat_value(stat_name: String) -> int:
	"""Get current value of a specific stat"""
	match stat_name.to_lower():
		"vit", "vitality":
			return current_vit
		"str", "strength":
			return current_str
		"dex", "dexterity":
			return current_dex
		"spd", "speed":
			return current_spd
		"luk", "luck":
			return current_luk
		"hp", "health":
			return current_hp
		"max_hp", "max_health":
			return max_hp
		_:
			push_error("Unknown stat: " + stat_name)
			return 0

func get_movement_speed() -> float:
	"""Get character movement speed based on SPD stat"""
	return GameConstants.BASE_MOVEMENT_SPEED * (1.0 + (current_spd - 10) * 0.05)

func get_attack_speed_multiplier() -> float:
	"""Get attack speed multiplier based on SPD stat"""
	return 1.0 + (current_spd - 10) * 0.03

func get_luck_multiplier() -> float:
	"""Get luck multiplier for drops and resources"""
	return 1.0 + (current_luk - 10) * 0.02

func to_save_data() -> Dictionary:
	"""Convert character to save data"""
	return {
		"character_class": character_class,
		"level": level,
		"tier": tier,
		"experience": experience,
		"base_vit": base_vit,
		"base_str": base_str,
		"base_dex": base_dex,
		"base_spd": base_spd,
		"base_luk": base_luk,
		"current_hp": current_hp
	}

func from_save_data(data: Dictionary):
	"""Load character from save data"""
	character_class = data.get("character_class", GameConstants.CharacterClass.ALL_ROUNDER)
	level = data.get("level", 1)
	tier = data.get("tier", 1)
	experience = data.get("experience", 0)
	base_vit = data.get("base_vit", 10)
	base_str = data.get("base_str", 10)
	base_dex = data.get("base_dex", 10)
	base_spd = data.get("base_spd", 10)
	base_luk = data.get("base_luk", 10)
	
	calculate_stats()
	current_hp = data.get("current_hp", max_hp)
