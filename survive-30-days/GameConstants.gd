extends Node

# GameConstants - Global constants for the game
# Available as autoload singleton

# Movement and Physics Constants
const TOUCH_MOVEMENT_THRESHOLD = 15.0
const TOUCH_SPEED_MULTIPLIER = 0.78
const KNOCKBACK_DURATION = 0.4
const DAMAGE_COOLDOWN_DURATION = 1.0

# World and Distance Constants
const WORLD_MARGIN = 100.0  # Margin from world edges
const CAMPFIRE_SAFE_ZONE = 300.0  # Safe zone around campfire
const INTERACTION_DISTANCE = 240.0  # Chest interaction distance
const MIN_TREE_DISTANCE = 500.0
const MIN_BOULDER_DISTANCE = 400.0
const MIN_BOULDER_TREE_DISTANCE = 100.0
const CHEST_MIN_DISTANCE = 900.0
const CHEST_MIN_DISTANCE_BETWEEN = 500.0

# Combat Constants
const ATTACK_RANGE = 90.0
const ATTACK_COOLDOWN = 1.0
const MOB_KNOCKBACK_STRENGTH = 800.0
const BOSS_KNOCKBACK_STRENGTH = 1200.0
const BOSS_DAYLIGHT_DAMAGE = 25.0  # 5x max axe damage

# Animation and Visual Constants
const DAMAGE_FLASH_DURATION = 0.1
const HURT_ANIMATION_DURATION = 0.5

# Spawn and Game Logic Constants
const BASE_MOB_SPAWN_INTERVAL = 5.0
const MIN_MOB_SPAWN_INTERVAL = 1.0
const MAX_MOBS = 15
const CHESTS_PER_DAY = 3
const CHEST_RESPAWN_DELAY = 8.0

# Resource Spawn Constants
const MIN_TREES_PER_DAY = 30
const MAX_TREES_PER_DAY = 40
const MIN_BOULDERS_PER_DAY = 15
const MAX_BOULDERS_PER_DAY = 20

# Day/Night Cycle Constants
const DAY_NIGHT_CYCLE_TIME = 50.0
const DAY_DURATION = 30.0
const NIGHT_DURATION = 20.0

# Item Constants
const HEALTH_INCREASE = 50.0
const MAX_HEALTH_CAP = 300.0
const SPEED_INCREASE = 100.0
const MAX_SPEED_CAP = 1000.0

# Material Constants
const MAX_WOOD_CAP = 25
const MAX_ROCK_CAP = 15

# Boss Target Days
const BOSS_TARGET_DAYS = [10, 20, 30]
const WIN_DAY = 30
