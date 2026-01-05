class_name Accessory
extends Resource

# Accessory system for Let it Climb

@export var accessory_type: GameConstants.AccessoryType = GameConstants.AccessoryType.VIT_RING
@export var tier: int = 1
@export var level: int = 1

# Calculated bonus values
var bonus_value: float

func _init(acc_type: GameConstants.AccessoryType = GameConstants.AccessoryType.VIT_RING):
	accessory_type = acc_type
	calculate_bonus()

func calculate_bonus():
	"""Calculate bonus value based on tier and level"""
	# Base bonus percentage: 5% at tier 1 level 1
	var base_bonus = 0.05
	
	# Tier multiplier: +5% per tier
	var tier_bonus = (tier - 1) * 0.05
	
	# Level multiplier: +2% per level
	var level_bonus = (level - 1) * 0.02
	
	bonus_value = base_bonus + tier_bonus + level_bonus

func apply_to_character(character: Character):
	"""Apply accessory effects to character"""
	var accessory_data = GameConstants.ACCESSORIES[accessory_type]
	
	match accessory_data.type:
		"stat_boost":
			apply_stat_boost(character, accessory_data.stat)
		"weapon_stat":
			# Weapon stat bonuses are applied when weapon calculates stats
			pass
		"element_boost":
			# Element bonuses are applied during damage calculation
			pass
		"special":
			apply_special_effect(character)

func remove_from_character(character: Character):
	"""Remove accessory effects from character"""
	var accessory_data = GameConstants.ACCESSORIES[accessory_type]
	
	match accessory_data.type:
		"stat_boost":
			remove_stat_boost(character, accessory_data.stat)
		"special":
			remove_special_effect(character)

func apply_stat_boost(character: Character, stat_name: String):
	"""Apply stat boost to character"""
	# This would modify character stats
	# For now, we'll store the bonus and apply it during stat calculations
	pass

func remove_stat_boost(character: Character, stat_name: String):
	"""Remove stat boost from character"""
	# Remove the previously applied bonus
	pass

func apply_special_effect(character: Character):
	"""Apply special accessory effects"""
	match accessory_type:
		GameConstants.AccessoryType.SECOND_WIND_RING:
			# This would add revival capability
			pass
		GameConstants.AccessoryType.GREED_RING:
			# This would modify resource retention on death
			pass

func remove_special_effect(character: Character):
	"""Remove special accessory effects"""
	match accessory_type:
		GameConstants.AccessoryType.SECOND_WIND_RING:
			# Remove revival capability
			pass
		GameConstants.AccessoryType.GREED_RING:
			# Remove resource retention bonus
			pass

func get_stat_bonus(stat_name: String) -> float:
	"""Get stat bonus for a specific stat"""
	var accessory_data = GameConstants.ACCESSORIES[accessory_type]
	
	if accessory_data.type == "stat_boost" and accessory_data.stat == stat_name:
		return bonus_value
	
	return 0.0

func get_weapon_stat_bonus(weapon_stat: String) -> float:
	"""Get weapon stat bonus"""
	var accessory_data = GameConstants.ACCESSORIES[accessory_type]
	
	if accessory_data.type == "weapon_stat" and accessory_data.stat == weapon_stat:
		return bonus_value
	
	return 0.0

func get_element_damage_bonus(element: GameConstants.ElementType) -> float:
	"""Get element damage bonus"""
	var accessory_data = GameConstants.ACCESSORIES[accessory_type]
	
	if accessory_data.type == "element_boost" and accessory_data.element == element:
		return bonus_value
	
	return 0.0

func get_second_wind_data() -> Dictionary:
	"""Get second wind ring data"""
	if accessory_type != GameConstants.AccessoryType.SECOND_WIND_RING:
		return {}
	
	# Number of revivals and HP percentage based on tier and level
	var revivals = tier
	var hp_percentage = 0.25 + (level - 1) * 0.05  # 25% + 5% per level
	
	return {"revivals": revivals, "hp_percentage": hp_percentage}

func get_greed_data() -> Dictionary:
	"""Get greed ring data"""
	if accessory_type != GameConstants.AccessoryType.GREED_RING:
		return {}
	
	# Resource retention percentage
	var retention_percentage = bonus_value
	
	return {"retention_percentage": retention_percentage}

func level_up() -> bool:
	"""Level up the accessory"""
	if level >= 4:  # Max level per tier
		return false
	
	level += 1
	calculate_bonus()
	return true

func upgrade_tier() -> bool:
	"""Upgrade accessory tier"""
	if tier >= 4:  # Max tier
		return false
	
	tier += 1
	level = 1  # Reset level when upgrading tier
	calculate_bonus()
	return true

func get_accessory_name() -> String:
	"""Get display name of the accessory"""
	return GameConstants.ACCESSORIES[accessory_type].name

func get_accessory_description() -> String:
	"""Get description of the accessory including current effects"""
	var accessory_data = GameConstants.ACCESSORIES[accessory_type]
	var description = "Tier %d Level %d %s\n" % [tier, level, accessory_data.name]
	
	match accessory_data.type:
		"stat_boost":
			description += "+%.1f%% %s" % [bonus_value * 100, accessory_data.stat.to_upper()]
		"weapon_stat":
			description += "+%.1f%% %s" % [bonus_value * 100, accessory_data.stat.replace("_", " ").capitalize()]
		"element_boost":
			var element_name = GameConstants.ELEMENT_EFFECTS[accessory_data.element].name
			description += "+%.1f%% %s damage" % [bonus_value * 100, element_name]
		"special":
			match accessory_type:
				GameConstants.AccessoryType.SECOND_WIND_RING:
					var data = get_second_wind_data()
					description += "%d revivals with %.1f%% HP" % [data.revivals, data.hp_percentage * 100]
				GameConstants.AccessoryType.GREED_RING:
					var data = get_greed_data()
					description += "Retain %.1f%% of resources on death" % [data.retention_percentage * 100]
	
	return description

func to_save_data() -> Dictionary:
	"""Convert accessory to save data"""
	return {
		"accessory_type": accessory_type,
		"tier": tier,
		"level": level
	}

func from_save_data(data: Dictionary):
	"""Load accessory from save data"""
	accessory_type = data.get("accessory_type", GameConstants.AccessoryType.VIT_RING)
	tier = data.get("tier", 1)
	level = data.get("level", 1)
	calculate_bonus()
