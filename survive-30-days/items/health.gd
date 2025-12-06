extends Node2D
class_name Health

# GameText is available globally via class_name

@export var heal_amount: float = 25.0  # Amount of health to restore
@export var max_health_increase: float = GameConstants.HEALTH_INCREASE  # Amount to increase max health
@export var max_health_cap: float = GameConstants.MAX_HEALTH_CAP  # Maximum health cap

func _ready():
	# Initialize health item
	pass

func get_heal_amount() -> float:
	"""Get the amount of health this item restores"""
	return heal_amount

func can_give_to_player(player) -> bool:
	"""Check if player can benefit from health item"""
	if not player:
		return false
	
	# Health item benefits player if:
	# 1. Max health is below cap (can increase max health), OR
	# 2. Current health is below max health (can restore health)
	return player.max_health < max_health_cap or player.health < player.max_health

func give_to_player(hud, player) -> bool:
	"""Give health to player (increase max health up to cap and fully replenish current health)"""
	if not player or not can_give_to_player(player):
		return false
	
	var _old_health = player.health
	var max_health_increased = false
	
	# Check if we can increase max health (under the cap)
	if player.max_health < max_health_cap:
		# Increase max health, but don't exceed the cap
		var health_increase = min(max_health_increase, max_health_cap - player.max_health)
		player.max_health += health_increase
		max_health_increased = true
	
	# Always fully replenish current health to max health
	player.health = player.max_health
	
	# Update player health bar display
	if player.has_node("%HealthBar"):
		player.get_node("%HealthBar").max_value = player.max_health
		player.get_node("%HealthBar").value = player.health
		# Update health bar size if player has the update function
		if player.has_method("update_health_bar_size"):
			player.update_health_bar_size()
	
	# Show appropriate message to player
	if max_health_increased:
		hud.show_message(GameText.FOUND_HEALTH)
	else:
		hud.show_message("Health fully restored! (Max health at cap: %d)" % max_health_cap)
	
	return true
