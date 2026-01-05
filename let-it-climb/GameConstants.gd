extends Node

# Game Constants for Let it Climb

# Character Classes
enum CharacterClass {
	ALL_ROUNDER,
	STRIKER,
	SHOOTER,
	COLLECTOR,
	ATTACKER
}

# Character class data
const CHARACTER_CLASSES = {
	CharacterClass.ALL_ROUNDER: {
		"name": "All Rounder",
		"description": "Balanced fighter suitable for any playstyle",
		"unlock_floor": 0,
		"stat_growth": {"vit": 3, "str": 3, "dex": 3, "spd": 3, "luk": 2}
	},
	CharacterClass.STRIKER: {
		"name": "Striker", 
		"description": "Melee specialist with devastating close-combat power",
		"unlock_floor": 5,
		"stat_growth": {"vit": 3, "str": 5, "dex": 1, "spd": 3, "luk": 2}
	},
	CharacterClass.SHOOTER: {
		"name": "Shooter",
		"description": "Ranged specialist excelling at distance combat", 
		"unlock_floor": 10,
		"stat_growth": {"vit": 3, "str": 1, "dex": 5, "spd": 3, "luk": 2}
	},
	CharacterClass.COLLECTOR: {
		"name": "Collector",
		"description": "Resource gatherer with enhanced speed and luck",
		"unlock_floor": 15,
		"stat_growth": {"vit": 2, "str": 2, "dex": 2, "spd": 5, "luk": 5}
	},
	CharacterClass.ATTACKER: {
		"name": "Attacker",
		"description": "Glass cannon with extreme offensive capabilities",
		"unlock_floor": 20,
		"stat_growth": {"vit": 2, "str": 5, "dex": 5, "spd": 3, "luk": 2}
	}
}

# Character Tiers
const CHARACTER_TIERS = {
	1: {"max_level": 10, "accessories": 1, "bag_slots": 3, "collector_bag": 5},
	2: {"max_level": 20, "accessories": 2, "bag_slots": 5, "collector_bag": 7},
	3: {"max_level": 30, "accessories": 3, "bag_slots": 7, "collector_bag": 10},
	4: {"max_level": 50, "accessories": 5, "bag_slots": 10, "collector_bag": 15},
	5: {"max_level": 75, "accessories": 7, "bag_slots": 15, "collector_bag": 20}
}

# Weapon Types
enum WeaponType {
	SWORD,
	AXE,
	BAT,
	BOW,
	STAFF,
	KNIVES
}

# Weapon Categories
enum WeaponCategory {
	MELEE,
	RANGED
}

# Element Types
enum ElementType {
	NONE,
	FIRE,
	ICE,
	LIGHTNING
}

# Weapon data
const WEAPONS = {
	WeaponType.SWORD: {
		"name": "Sword",
		"category": WeaponCategory.MELEE,
		"stat_scaling": "str",
		"base_damage": 25,
		"base_speed": 1.0,
		"base_range": 80,
		"tier_3_element": ElementType.FIRE,
		"tier_4_special": "full_circle",
		"tier_5_special": "flame_wave"
	},
	WeaponType.AXE: {
		"name": "Axe",
		"category": WeaponCategory.MELEE,
		"stat_scaling": "str", 
		"base_damage": 35,
		"base_speed": 0.7,
		"base_range": 75,
		"tier_3_element": ElementType.LIGHTNING,
		"tier_4_special": "full_circle",
		"tier_5_special": "lightning_storm"
	},
	WeaponType.BAT: {
		"name": "Bat",
		"category": WeaponCategory.MELEE,
		"stat_scaling": "str",
		"base_damage": 50,
		"base_speed": 0.5,
		"base_range": 70,
		"tier_3_element": ElementType.ICE,
		"tier_4_special": "full_circle",
		"tier_5_special": "area_slam"
	},
	WeaponType.BOW: {
		"name": "Bow",
		"category": WeaponCategory.RANGED,
		"stat_scaling": "dex",
		"base_damage": 20,
		"base_speed": 0.8,
		"base_range": 300,
		"tier_upgrades": [1, 2, 3, 5, 8],  # shots per attack
		"tier_3_element": ElementType.FIRE,
		"tier_5_special": "arrow_rain"
	},
	WeaponType.STAFF: {
		"name": "Staff",
		"category": WeaponCategory.RANGED,
		"stat_scaling": "dex",
		"base_damage": 40,
		"base_speed": 0.6,
		"base_range": 400,
		"tier_upgrades": [1, 2, 3, 5, 8],
		"tier_3_element": ElementType.LIGHTNING,
		"tier_5_special": "magic_burst"
	},
	WeaponType.KNIVES: {
		"name": "Knives",
		"category": WeaponCategory.RANGED,
		"stat_scaling": "dex",
		"base_damage": 15,
		"base_speed": 1.5,
		"base_range": 200,
		"tier_upgrades": [1, 2, 3, 5, 8],
		"tier_3_element": ElementType.ICE,
		"tier_5_special": "ice_shards"
	}
}

# Element Effects
const ELEMENT_EFFECTS = {
	ElementType.FIRE: {
		"name": "Burn",
		"description": "Deals 10% of weapon base attack as damage over time",
		"duration": 3.0,
		"damage_percent": 0.1
	},
	ElementType.ICE: {
		"name": "Freeze",
		"description": "Immobilizes enemy for 1-2 seconds",
		"min_duration": 1.0,
		"max_duration": 2.0
	},
	ElementType.LIGHTNING: {
		"name": "Area Damage",
		"description": "Creates damage zone at impact point",
		"area_radius": 100,
		"damage_multiplier": 0.5
	}
}

# Resource Types
enum ResourceType {
	# Wood
	SIMPLE_WOOD,
	RED_WOOD,
	DARK_WOOD,
	# Metal
	IRON,
	STEEL,
	DARK_STEEL,
	# Elemental Stones
	FIRE_STONE,
	ICE_STONE,
	LIGHTNING_STONE
}

# Resource Rarity
enum ResourceRarity {
	COMMON,
	UNCOMMON,
	RARE
}

const RESOURCES = {
	ResourceType.SIMPLE_WOOD: {"name": "Simple Wood", "rarity": ResourceRarity.COMMON},
	ResourceType.RED_WOOD: {"name": "Red Wood", "rarity": ResourceRarity.UNCOMMON},
	ResourceType.DARK_WOOD: {"name": "Dark Wood", "rarity": ResourceRarity.RARE},
	ResourceType.IRON: {"name": "Iron", "rarity": ResourceRarity.COMMON},
	ResourceType.STEEL: {"name": "Steel", "rarity": ResourceRarity.UNCOMMON},
	ResourceType.DARK_STEEL: {"name": "Dark Steel", "rarity": ResourceRarity.RARE},
	ResourceType.FIRE_STONE: {"name": "Fire Stone", "rarity": ResourceRarity.UNCOMMON},
	ResourceType.ICE_STONE: {"name": "Ice Stone", "rarity": ResourceRarity.UNCOMMON},
	ResourceType.LIGHTNING_STONE: {"name": "Lightning Stone", "rarity": ResourceRarity.UNCOMMON}
}

# Accessory Types
enum AccessoryType {
	VIT_RING,
	STR_RING,
	DEX_RING,
	SPD_RING,
	LUK_RING,
	FIRE_RATE_RING,
	RANGE_RING,
	FIRE_RING,
	LIGHTNING_RING,
	ICE_RING,
	SECOND_WIND_RING,
	GREED_RING
}

const ACCESSORIES = {
	AccessoryType.VIT_RING: {"name": "VIT Ring", "stat": "vit", "type": "stat_boost"},
	AccessoryType.STR_RING: {"name": "STR Ring", "stat": "str", "type": "stat_boost"},
	AccessoryType.DEX_RING: {"name": "DEX Ring", "stat": "dex", "type": "stat_boost"},
	AccessoryType.SPD_RING: {"name": "SPD Ring", "stat": "spd", "type": "stat_boost"},
	AccessoryType.LUK_RING: {"name": "LUK Ring", "stat": "luk", "type": "stat_boost"},
	AccessoryType.FIRE_RATE_RING: {"name": "Fire Rate Ring", "stat": "fire_rate", "type": "weapon_stat"},
	AccessoryType.RANGE_RING: {"name": "Range Ring", "stat": "range", "type": "weapon_stat"},
	AccessoryType.FIRE_RING: {"name": "Fire Ring", "element": ElementType.FIRE, "type": "element_boost"},
	AccessoryType.LIGHTNING_RING: {"name": "Lightning Ring", "element": ElementType.LIGHTNING, "type": "element_boost"},
	AccessoryType.ICE_RING: {"name": "Ice Ring", "element": ElementType.ICE, "type": "element_boost"},
	AccessoryType.SECOND_WIND_RING: {"name": "Second Wind Ring", "type": "special"},
	AccessoryType.GREED_RING: {"name": "Greed Ring", "type": "special"}
}

# Game Balance Constants
const HP_PER_VIT = 10
const MAX_STACK_SIZE = 9
const BASE_MOVEMENT_SPEED = 300.0
const TOUCH_SPEED_MULTIPLIER = 0.6

# Floor Constants
const FLOORS_PER_PORTAL = 5
const MAX_TOWER_FLOORS = 100  # Placeholder - can be adjusted

# Combat Constants
const DAMAGE_COOLDOWN_DURATION = 1.0
const KNOCKBACK_DURATION = 0.3
