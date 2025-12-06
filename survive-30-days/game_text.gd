extends Node
class_name GameText

# This script contains all text constants used throughout the game
# Include this script in any other script that needs text with: const GameText = preload("res://game_text.gd")

# Main Menu and UI Text
const GAME_TITLE = "Survive 30 Days!"
const NEW_GAME_BUTTON = "New Game"
const HOW_TO_PLAY_BUTTON = "How to Play"
const QUIT_BUTTON = "Quit"
const BEST_SCORE_FORMAT = "Best: %d days"
const DAY_FORMAT = "Day %d"
const DAY_ONE = "Day 1"

# How to Play Screen Text
const HOW_TO_PLAY_TITLE = "How to Play"
const HOW_TO_PLAY_MOVEMENT = "• This game supports gamepad, keyboard, mouse and mobile touch interaction"
const HOW_TO_PLAY_AXE = "• You start with an axe, use it fight and get resources like wood and rocks"
const HOW_TO_PLAY_FLASHLIGHT = "• Mobs don't like light, you can find shelter near the campfire and use a flashlight in your favor"
const HOW_TO_PLAY_ROCKS = "• You can collect rocks and throw them at enemies"
const HOW_TO_PLAY_CHESTS = "• You can find chests in the forest, they contain precious upgrades and items"
const HOW_TO_PLAY_HOURGLASS = "• Hourglasses can make the days count increase faster, use that!"
const HOW_TO_PLAY_NIGHT = "• Be careful at night, mobs and something worse can attack you"
const BACK_BUTTON = "Back"

# Game Messages
const SURVIVE_MESSAGE = "Survive for 30 days!"
const LAST_DAY_MESSAGE = "Last day! Almost there!"
const GAME_OVER = "Game Over"
const YOU_SURVIVED = "You Survived!"

# Campfire Text
const CAMPFIRE_FULL = "Campfire Full"
const NEED_WOOD = "Need 3x Wood"
const ADD_WOOD = "Add 3x Wood"
const CAMPFIRE_HEALTH_FORMAT = "Campfire Health: %d/3"
const CAMPFIRE_EXTINGUISHED = "Campfire extinguished! Find wood to relight it!"
const NEED_WOOD_TO_FUEL = "Need at least 3 wood to fuel campfire!"
const CAMPFIRE_FULL_HEALTH = "Campfire is already at full health!"

# Chest Text
const CHEST_OPEN = "Open"

# Item Messages
const FOUND_FLASHLIGHT = "You found a flashlight"
const FOUND_HOURGLASS = "You found a hourglass"
const HOURGLASS_UPGRADED = "Your hourglass was upgraded!"
const HOURGLASS_MAX_POWER = "Your hourglass is already at maximum power!"
const FOUND_WOOD = "You found some wood"
const FOUND_ROCKS = "You found some rocks"

# Boss Messages
const BOSS_APPROACHES = "Boss approaches..."
const BOSS_WARNING = "The Boss will show up tonight..."
const DEFEAT_THE_BOSS = "DEFEAT THE BOSS"
const BOSS_SPAWNED = "Boss spawned!"
const BOSS_DESTROYED = "Boss destroyed!"
const FINAL_BOSS_DEFEATED = "Final boss defeated - game won!"
const BOSS_NIGHT_ENDED = "Boss night ended"
const HEALTH_RESTORED = "You get some health back"
const FOUND_BETTER_AXE = "You found a better axe"

# Debug/Console Messages
const START_BUTTON_PRESSED = "Start button pressed!"
const HUD_START_GAME_SIGNAL = "HUD start_game signal received!"
const PLAYER_ENTERED_CAMPFIRE = "Player entered campfire interaction area"
const PLAYER_EXITED_CAMPFIRE = "Player exited campfire interaction area"
const PLAYER_ENTERED_CHEST = "Player entered chest interaction area"
const PLAYER_EXITED_CHEST = "Player exited chest interaction area"

# Day/Cycling Messages
const DAY_CYCLING_TREES = "Day %d: Cycling trees"
const DAY_CYCLING_BOULDERS = "Day %d: Cycling boulders"
const DAY_SPAWNING_CHESTS = "Day %d: Spawning %d daily chests"
const SPAWNED_TREE_AT = "Spawned tree at: %s"
const SPAWNED_BOULDER_AT = "Spawned boulder at: %s"
const SPAWNED_CHEST_AT = "Spawned chest %d at: %s"
const FAILED_CHEST_POSITION = "Failed to find valid position for chest %d"
const CLEARED_CHESTS = "Cleared all chests for new day"
const SPAWNING_REPLACEMENT_CHEST = "Spawning replacement chest..."
const MAX_CHESTS_PRESENT = "Maximum chests already present, not spawning replacement"
const SPAWNED_REPLACEMENT_CHEST = "Spawned replacement chest at: %s (Total chests: %d)"
const FAILED_REPLACEMENT_CHEST = "Failed to find valid position for replacement chest"

# Tree Messages
const TREE_CUT_DOWN = "Tree cut down, but keeping in scene with new sprite"
const ADDED_WOOD_TO_INVENTORY = "Added 1 wood to material inventory"

# Boulder Messages
const BOULDER_DESTROYED = "Boulder destroyed and removed from scene"
const ADDED_ROCK_TO_INVENTORY = "Added 1 rock to material inventory"

# Campfire Health Messages
const CAMPFIRE_HEALTH_CHANGED = "Campfire health changed to: %d"
const CAMPFIRE_EXTINGUISHED_DEBUG = "Campfire extinguished! No more safe zone!"
const CAMPFIRE_HAS_BEEN_EXTINGUISHED = "Campfire has been extinguished!"
const ADDED_HEALTH_TO_CAMPFIRE = "Added %d health to campfire using %d wood"

# Chest Opening Messages
const OPENING_CHEST = "Opening chest!"
const CHEST_OPENED_BY_PLAYER = "Chest opened by player!"
const REMOVED_CHEST_FROM_ARRAY = "Removed chest from array. Remaining chests: %d"
const STARTED_CHEST_RESPAWN_TIMER = "Started chest respawn timer (10 seconds)"

# Item Discovery Messages
const FLASHLIGHT_AVAILABLE = "Flashlight available for chest"
const FLASHLIGHT_EXCLUDED = "Flashlight already in inventory - excluded from chest"
const HOURGLASS_AVAILABLE = "Hourglass available for chest"
const AVAILABLE_CHEST_ITEMS = "Available chest items: %s"
const NO_ITEMS_AVAILABLE = "No items available in chest"
const RANDOM_INDEX_SELECTED = "Random index: %d / %d - Selected chest item: %s"
const ABOUT_TO_GIVE_ITEM = "About to give item: %s"
const GIVING_FLASHLIGHT = "Giving flashlight"
const GIVING_HOURGLASS = "Giving hourglass"
const GIVING_WOOD_BUNDLE = "Giving wood bundle"
const GIVING_ROCK_BUNDLE = "Giving rock bundle"
const GIVING_HEALTH = "Giving health"
const GIVING_AXE_UPGRADE = "Giving axe upgrade"
const UNKNOWN_ITEM_ERROR = "ERROR: Unknown item selected: %s"

# Inventory Messages
const ADDED_FLASHLIGHT_TO_INVENTORY = "Added flashlight to player inventory"
const FAILED_ADD_FLASHLIGHT = "Failed to add flashlight - inventory might be full"
const ADDED_HOURGLASS_TO_INVENTORY = "Added hourglass to player inventory"
const FAILED_ADD_HOURGLASS = "Failed to add hourglass - inventory might be full"
const ADDED_WOOD_TO_PLAYER_INVENTORY = "Added 5 wood to player inventory"
const ADDED_ROCKS_TO_PLAYER_INVENTORY = "Added 5 rocks to player inventory"
const RESTORED_PLAYER_HEALTH = "Restored player health to full"
const RESTORED_PLAYER_HEALTH_FALLBACK = "Restored player health to full (fallback)"
const UPGRADED_PLAYER_AXE = "Upgraded player's axe"
const AXE_MAX_LEVEL_WOOD_INSTEAD = "Axe at max level - gave wood instead"
const COULD_NOT_UPGRADE_AXE = "Could not upgrade axe - gave wood instead"

# Chest Reset Messages
const CHEST_RESET = "Chest reset for new day"

# Mob Messages
const SPAWNED_MOB_AT = "Spawned mob at: %s (Total mobs: %d)"
const CLEARED_ALL_MOBS = "Cleared all mobs (daybreak)"
const MOB_DESTROYED = "Mob destroyed!"
const REMAINING_MOBS = "Remaining mobs: %d"
const MOB_SPAWN_RATE_UPDATED = "Day %d: Mob spawn rate updated to every %s seconds"
const DAYBREAK_DESTRUCTION = "Daybreak! Starting destruction sequence for %d mobs"

# Hourglass Messages
const HOURGLASS_MAX_LEVEL = "Hourglass is already at maximum level (5x speed)"
const HOURGLASS_EFFECT_LEVEL = "Hourglass effect level %d - time runs %sx faster!"

# Player Messages
const OVERLAPPING_MOBS = "Overlapping mobs: %d - Player moving: %s"
const HEALTH_AFTER_DAMAGE = "Health after damage: %s"
const PLAYER_AXE_HIT_TREE = "Player's axe hit tree: %s"
const PLAYER_AXE_HIT_ENEMY = "Player's axe hit enemy: %s"
const ADDED_STARTING_AXE = "Added starting axe to inventory at level %d"
const PLAYER_HEALED_TO_FULL = "Player healed to full health: %s"
const FOUND_HEALTH = "You feel healthier!"
const FOUND_SPEED = "You feel faster!"
const PLAYER_HEALED = "Player healed by %d HP. Health: %d/%d"

# Axe Messages
const AXE_SPRITE_LOAD_WARNING = "Warning: Could not load axe sprite for level %d"
const AXE_LEVEL_STATS = "Axe Level %d - Damage: %s - Attack Rate: %s"
const AXE_LEVELED_UP = "Axe leveled up to %d!"
const AXE_RESET_TO_LEVEL_ONE = "Axe reset to level 1"
const AXE_HIT_TREE = "Axe hit tree at %s for %s damage"
const AXE_HIT_BOULDER = "Axe hit boulder at %s for %s damage"
const AXE_HIT_ENEMY = "Axe hit enemy at %s for %s damage"

# Material Names (for consistency)
const MATERIAL_WOOD = "wood"
const MATERIAL_ROCK = "rock"

# Item Names (for consistency)
const ITEM_FLASHLIGHT = "flashlight"
const ITEM_HOURGLASS = "hourglass"
const ITEM_AXE = "axe"
const ITEM_HEALTH = "health"
const ITEM_SPEED = "speed"
const ITEM_AXE_UPGRADE = "axe_upgrade"
