extends Node2D
class_name Speed

# GameText is available globally via class_name

@export var speed_increase: float = GameConstants.SPEED_INCREASE  # Amount to increase speed
@export var max_speed_cap: float = GameConstants.MAX_SPEED_CAP  # Maximum speed cap

func _ready():
	# Initialize speed item
	pass

func get_speed_increase() -> float:
	"""Get the amount of speed this item provides"""
	return speed_increase

func can_give_to_player(player) -> bool:
	"""Check if player can benefit from speed item"""
	if not player:
		return false
	
	# Speed item benefits player if speed is below cap
	return player.speed < max_speed_cap

func give_to_player(hud, player) -> bool:
	"""Give speed to player (increase speed up to cap)"""
	if not player or not can_give_to_player(player):
		return false
	
	var _old_speed = player.speed
	var speed_increased = false
	
	# Check if we can increase speed (under the cap)
	if player.speed < max_speed_cap:
		# Increase speed, but don't exceed the cap
		var actual_increase = min(speed_increase, max_speed_cap - player.speed)
		player.speed += actual_increase
		speed_increased = true
		
		# Show appropriate message to player
		if speed_increased:
			hud.show_message(GameText.FOUND_SPEED)
		
		return true
	else:
		# At max speed cap, item has no effect
		hud.show_message("Speed already at maximum! (%d)" % max_speed_cap)
		return false
