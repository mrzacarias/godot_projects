class_name Weapon
extends Resource

# Base weapon system for Let it Climb

signal attack_performed
signal enemy_hit(enemy: Node, damage: int)

@export var weapon_type: GameConstants.WeaponType = GameConstants.WeaponType.SWORD
@export var tier: int = 1
@export var level: int = 1

# Base stats (modified by tier and level)
var base_damage: int
var base_speed: float
var base_range: int
var element_type: GameConstants.ElementType = GameConstants.ElementType.NONE

# Current calculated stats
var current_damage: int
var current_speed: float
var current_range: int
var attack_cooldown: float

# Owner character stats for scaling
var owner_character: Character

# Attack timing
var last_attack_time: float = 0.0

func _init(w_type: GameConstants.WeaponType = GameConstants.WeaponType.SWORD):
	weapon_type = w_type
	initialize_weapon()

func initialize_weapon():
	"""Initialize weapon with base stats from GameConstants"""
	var weapon_data = GameConstants.WEAPONS[weapon_type]
	base_damage = weapon_data.base_damage
	base_speed = weapon_data.base_speed
	base_range = weapon_data.base_range
	
	calculate_stats()

func calculate_stats():
	"""Calculate current weapon stats based on tier, level, and owner stats"""
	# Base calculations with tier and level bonuses
	var tier_multiplier = 1.0 + (tier - 1) * 0.5  # 50% increase per tier
	var level_multiplier = 1.0 + (level - 1) * 0.2  # 20% increase per level
	
	current_damage = int(base_damage * tier_multiplier * level_multiplier)
	current_speed = base_speed * (1.0 + (tier - 1) * 0.3) * (1.0 + (level - 1) * 0.1)
	current_range = int(base_range * (1.0 + (tier - 1) * 0.2) * (1.0 + (level - 1) * 0.1))
	
	# Calculate attack cooldown (lower is faster)
	attack_cooldown = 1.0 / current_speed
	
	# Apply character stat scaling if owner is set
	if owner_character:
		apply_character_scaling()
	
	# Apply element type based on tier
	update_element_type()

func apply_character_scaling():
	"""Apply character stat scaling to weapon damage"""
	if not owner_character:
		return
	
	var weapon_data = GameConstants.WEAPONS[weapon_type]
	var scaling_stat = weapon_data.stat_scaling
	
	var stat_value = 0
	match scaling_stat:
		"str":
			stat_value = owner_character.current_str
		"dex":
			stat_value = owner_character.current_dex
	
	# Scale damage based on stat (10 is baseline, each point above/below adds/removes 5%)
	var stat_multiplier = 1.0 + (stat_value - 10) * 0.05
	current_damage = int(current_damage * stat_multiplier)
	
	# Apply attack speed from character SPD
	var speed_multiplier = owner_character.get_attack_speed_multiplier()
	attack_cooldown = attack_cooldown / speed_multiplier

func update_element_type():
	"""Update element type based on weapon tier"""
	var weapon_data = GameConstants.WEAPONS[weapon_type]
	
	if tier >= 3 and "tier_3_element" in weapon_data:
		element_type = weapon_data.tier_3_element
	else:
		element_type = GameConstants.ElementType.NONE

func set_owner_stats(character: Character):
	"""Set the owner character for stat scaling"""
	owner_character = character
	calculate_stats()

func can_attack() -> bool:
	"""Check if weapon can attack (cooldown finished)"""
	var current_time = Time.get_time_dict_from_system()
	var time_since_last = (current_time.hour * 3600 + current_time.minute * 60 + current_time.second) - last_attack_time
	return time_since_last >= attack_cooldown

func update_attack(delta: float, player_position: Vector2, facing_direction: Vector2):
	"""Update weapon attack logic (called from player)"""
	# Update internal timing
	last_attack_time += delta
	
	# Check if we can attack and have targets
	if last_attack_time >= attack_cooldown and has_targets_nearby(player_position):
		perform_attack(player_position, facing_direction)
		last_attack_time = 0.0

func has_targets_nearby(player_position: Vector2) -> bool:
	"""Check if there are enemies within attack range"""
	# This would be implemented with area detection
	# For now, return false as placeholder
	return false

func perform_attack(player_position: Vector2, facing_direction: Vector2):
	"""Perform the weapon attack"""
	var weapon_data = GameConstants.WEAPONS[weapon_type]
	
	match weapon_data.category:
		GameConstants.WeaponCategory.MELEE:
			perform_melee_attack(player_position, facing_direction)
		GameConstants.WeaponCategory.RANGED:
			perform_ranged_attack(player_position, facing_direction)
	
	attack_performed.emit()

func perform_melee_attack(player_position: Vector2, facing_direction: Vector2):
	"""Perform melee weapon attack"""
	# Create attack area based on weapon range and facing direction
	var attack_area = create_melee_attack_area(player_position, facing_direction)
	
	# Check for enemies in attack area and deal damage
	var enemies_hit = get_enemies_in_area(attack_area)
	for enemy in enemies_hit:
		deal_damage_to_enemy(enemy)

func perform_ranged_attack(player_position: Vector2, facing_direction: Vector2):
	"""Perform ranged weapon attack"""
	var weapon_data = GameConstants.WEAPONS[weapon_type]
	var shots = 1
	
	# Get number of shots based on tier
	if "tier_upgrades" in weapon_data and tier <= weapon_data.tier_upgrades.size():
		shots = weapon_data.tier_upgrades[tier - 1]
	
	# Fire projectiles
	for i in range(shots):
		create_projectile(player_position, facing_direction, i, shots)

func create_melee_attack_area(player_position: Vector2, facing_direction: Vector2) -> Area2D:
	"""Create attack area for melee weapons"""
	# This would create an Area2D node with appropriate collision shape
	# Placeholder implementation
	return null

func create_projectile(start_position: Vector2, direction: Vector2, shot_index: int, total_shots: int):
	"""Create a projectile for ranged weapons"""
	# Calculate spread for multiple shots
	var spread_angle = 0.0
	if total_shots > 1:
		var max_spread = PI / 6  # 30 degrees total spread
		var spread_step = max_spread / (total_shots - 1)
		spread_angle = -max_spread / 2 + shot_index * spread_step
	
	var final_direction = direction.rotated(spread_angle)
	
	# This would instantiate a projectile scene
	# Placeholder for now

func get_enemies_in_area(area: Area2D) -> Array:
	"""Get all enemies in the specified area"""
	# Placeholder implementation
	return []

func deal_damage_to_enemy(enemy: Node):
	"""Deal damage to an enemy"""
	if enemy.has_method("take_damage"):
		var final_damage = current_damage
		
		# Apply element effects
		if element_type != GameConstants.ElementType.NONE:
			apply_element_effect(enemy)
		
		enemy.take_damage(final_damage)
		enemy_hit.emit(enemy, final_damage)

func apply_element_effect(enemy: Node):
	"""Apply elemental effects to enemy"""
	match element_type:
		GameConstants.ElementType.FIRE:
			apply_burn_effect(enemy)
		GameConstants.ElementType.ICE:
			apply_freeze_effect(enemy)
		GameConstants.ElementType.LIGHTNING:
			apply_lightning_effect(enemy)

func apply_burn_effect(enemy: Node):
	"""Apply burn status effect"""
	if enemy.has_method("apply_status_effect"):
		var burn_damage = int(current_damage * GameConstants.ELEMENT_EFFECTS[GameConstants.ElementType.FIRE].damage_percent)
		var duration = GameConstants.ELEMENT_EFFECTS[GameConstants.ElementType.FIRE].duration
		enemy.apply_status_effect("burn", burn_damage, duration)

func apply_freeze_effect(enemy: Node):
	"""Apply freeze status effect"""
	if enemy.has_method("apply_status_effect"):
		var effect_data = GameConstants.ELEMENT_EFFECTS[GameConstants.ElementType.ICE]
		var duration = randf_range(effect_data.min_duration, effect_data.max_duration)
		enemy.apply_status_effect("freeze", 0, duration)

func apply_lightning_effect(enemy: Node):
	"""Apply lightning area damage effect"""
	# This would create an area damage effect at the enemy's position
	var effect_data = GameConstants.ELEMENT_EFFECTS[GameConstants.ElementType.LIGHTNING]
	var area_damage = int(current_damage * effect_data.damage_multiplier)
	create_lightning_area_effect(enemy.global_position, effect_data.area_radius, area_damage)

func create_lightning_area_effect(position: Vector2, radius: int, damage: int):
	"""Create lightning area damage effect"""
	# Placeholder for area effect implementation
	pass

func level_up() -> bool:
	"""Level up the weapon"""
	if level >= 4:  # Max level per tier
		return false
	
	level += 1
	calculate_stats()
	return true

func upgrade_tier() -> bool:
	"""Upgrade weapon tier"""
	if tier >= 5:  # Max tier (now 5)
		return false
	
	tier += 1
	level = 1  # Reset level when upgrading tier
	calculate_stats()
	return true

func get_stat_requirement() -> Dictionary:
	"""Get stat requirements for this weapon at current tier/level"""
	var weapon_data = GameConstants.WEAPONS[weapon_type]
	var scaling_stat = weapon_data.stat_scaling
	
	# Calculate required stat (base 10 + tier*5 + level*2)
	var required_value = 10 + (tier - 1) * 5 + (level - 1) * 2
	
	return {scaling_stat: required_value}

func can_be_equipped_by(character: Character) -> bool:
	"""Check if character meets requirements to equip this weapon"""
	var requirements = get_stat_requirement()
	
	for stat_name in requirements:
		var required_value = requirements[stat_name]
		var character_value = character.get_stat_value(stat_name)
		if character_value < required_value:
			return false
	
	return true

func get_weapon_name() -> String:
	"""Get display name of the weapon"""
	return GameConstants.WEAPONS[weapon_type].name

func get_weapon_description() -> String:
	"""Get description of the weapon including current stats"""
	var weapon_data = GameConstants.WEAPONS[weapon_type]
	var description = "Tier %d Level %d %s\n" % [tier, level, weapon_data.name]
	description += "Damage: %d\n" % current_damage
	description += "Speed: %.1f\n" % current_speed
	description += "Range: %d\n" % current_range
	
	if element_type != GameConstants.ElementType.NONE:
		var element_name = GameConstants.ELEMENT_EFFECTS[element_type].name
		description += "Element: %s" % element_name
	
	return description

func to_save_data() -> Dictionary:
	"""Convert weapon to save data"""
	return {
		"weapon_type": weapon_type,
		"tier": tier,
		"level": level
	}

func from_save_data(data: Dictionary):
	"""Load weapon from save data"""
	weapon_type = data.get("weapon_type", GameConstants.WeaponType.SWORD)
	tier = data.get("tier", 1)
	level = data.get("level", 1)
	initialize_weapon()
