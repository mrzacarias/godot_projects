class_name PhysicsOptimizer

# Physics optimization utilities for better performance

# Distance calculation cache
class DistanceCache:
	var cached_distances: Dictionary = {}
	var cache_duration: float = 0.1  # Cache for 100ms
	var cache_timers: Dictionary = {}
	
	func get_distance(from: Vector2, to: Vector2, entity_id: String = "") -> float:
		"""Get cached distance or calculate and cache it"""
		var cache_key = str(from) + "_" + str(to) + "_" + entity_id
		
		# Check if we have a valid cached value
		if cached_distances.has(cache_key) and cache_timers.has(cache_key):
			if cache_timers[cache_key] > 0:
				return cached_distances[cache_key]
		
		# Calculate new distance
		var distance = from.distance_to(to)
		cached_distances[cache_key] = distance
		cache_timers[cache_key] = cache_duration
		
		return distance
	
	func get_squared_distance(from: Vector2, to: Vector2, entity_id: String = "") -> float:
		"""Get cached squared distance (faster for comparisons)"""
		var cache_key = str(from) + "_" + str(to) + "_sq_" + entity_id
		
		# Check if we have a valid cached value
		if cached_distances.has(cache_key) and cache_timers.has(cache_key):
			if cache_timers[cache_key] > 0:
				return cached_distances[cache_key]
		
		# Calculate new squared distance
		var distance_sq = from.distance_squared_to(to)
		cached_distances[cache_key] = distance_sq
		cache_timers[cache_key] = cache_duration
		
		return distance_sq
	
	func update_cache(delta: float):
		"""Update cache timers - call this every frame"""
		for key in cache_timers.keys():
			cache_timers[key] -= delta
			if cache_timers[key] <= 0:
				cached_distances.erase(key)
				cache_timers.erase(key)
	
	func clear_cache():
		"""Clear all cached values"""
		cached_distances.clear()
		cache_timers.clear()

# Collision detection optimizer
class CollisionOptimizer:
	var collision_cache: Dictionary = {}
	var cache_duration: float = 0.05  # Cache for 50ms (faster refresh for collisions)
	var cache_timers: Dictionary = {}
	
	func get_overlapping_areas(area: Area2D, entity_id: String = "") -> Array:
		"""Get cached overlapping areas"""
		if not area or not is_instance_valid(area):
			return []
		
		var cache_key = str(area.get_instance_id()) + "_" + entity_id
		
		# Check cache
		if collision_cache.has(cache_key) and cache_timers.has(cache_key):
			if cache_timers[cache_key] > 0:
				return collision_cache[cache_key]
		
		# Get fresh collision data
		var overlapping = area.get_overlapping_areas()
		collision_cache[cache_key] = overlapping
		cache_timers[cache_key] = cache_duration
		
		return overlapping
	
	func get_overlapping_bodies(area: Area2D, entity_id: String = "") -> Array:
		"""Get cached overlapping bodies"""
		if not area or not is_instance_valid(area):
			return []
		
		var cache_key = str(area.get_instance_id()) + "_bodies_" + entity_id
		
		# Check cache
		if collision_cache.has(cache_key) and cache_timers.has(cache_key):
			if cache_timers[cache_key] > 0:
				return collision_cache[cache_key]
		
		# Get fresh collision data
		var overlapping = area.get_overlapping_bodies()
		collision_cache[cache_key] = overlapping
		cache_timers[cache_key] = cache_duration
		
		return overlapping
	
	func update_cache(delta: float):
		"""Update collision cache timers"""
		for key in cache_timers.keys():
			cache_timers[key] -= delta
			if cache_timers[key] <= 0:
				collision_cache.erase(key)
				cache_timers.erase(key)
	
	func clear_cache():
		"""Clear collision cache"""
		collision_cache.clear()
		cache_timers.clear()

# Spatial partitioning for efficient entity queries
class SpatialGrid:
	var grid_size: float = 200.0  # Size of each grid cell
	var entity_grid: Dictionary = {}  # Grid cell -> Array of entities
	var entity_positions: Dictionary = {}  # Entity -> grid position
	
	func add_entity(entity: Node2D, entity_id: String):
		"""Add entity to spatial grid"""
		if not entity or not is_instance_valid(entity):
			return
		
		var grid_pos = world_to_grid(entity.global_position)
		var grid_key = str(grid_pos.x) + "_" + str(grid_pos.y)
		
		# Remove from old position if exists
		remove_entity(entity_id)
		
		# Add to new position
		if not entity_grid.has(grid_key):
			entity_grid[grid_key] = []
		
		entity_grid[grid_key].append({"entity": entity, "id": entity_id})
		entity_positions[entity_id] = grid_pos
	
	func remove_entity(entity_id: String):
		"""Remove entity from spatial grid"""
		if not entity_positions.has(entity_id):
			return
		
		var old_grid_pos = entity_positions[entity_id]
		var old_grid_key = str(old_grid_pos.x) + "_" + str(old_grid_pos.y)
		
		if entity_grid.has(old_grid_key):
			entity_grid[old_grid_key] = entity_grid[old_grid_key].filter(
				func(item): return item.id != entity_id
			)
			
			# Clean up empty grid cells
			if entity_grid[old_grid_key].is_empty():
				entity_grid.erase(old_grid_key)
		
		entity_positions.erase(entity_id)
	
	func get_nearby_entities(position: Vector2, radius: float) -> Array:
		"""Get entities within radius of position"""
		var nearby_entities = []
		var grid_pos = world_to_grid(position)
		var grid_radius = int(ceil(radius / grid_size))
		
		# Check surrounding grid cells
		for x in range(grid_pos.x - grid_radius, grid_pos.x + grid_radius + 1):
			for y in range(grid_pos.y - grid_radius, grid_pos.y + grid_radius + 1):
				var grid_key = str(x) + "_" + str(y)
				if entity_grid.has(grid_key):
					for item in entity_grid[grid_key]:
						var entity = item.entity
						if entity and is_instance_valid(entity):
							var distance = position.distance_to(entity.global_position)
							if distance <= radius:
								nearby_entities.append(entity)
		
		return nearby_entities
	
	func world_to_grid(world_pos: Vector2) -> Vector2i:
		"""Convert world position to grid coordinates"""
		return Vector2i(
			int(floor(world_pos.x / grid_size)),
			int(floor(world_pos.y / grid_size))
		)
	
	func update_entity(entity: Node2D, entity_id: String):
		"""Update entity position in grid if it moved"""
		if not entity or not is_instance_valid(entity):
			remove_entity(entity_id)
			return
		
		var new_grid_pos = world_to_grid(entity.global_position)
		
		# Check if entity moved to a different grid cell
		if entity_positions.has(entity_id):
			var old_grid_pos = entity_positions[entity_id]
			if old_grid_pos != new_grid_pos:
				add_entity(entity, entity_id)
		else:
			add_entity(entity, entity_id)
	
	func clear():
		"""Clear all entities from grid"""
		entity_grid.clear()
		entity_positions.clear()

# Global physics optimizer instance
static var instance: PhysicsOptimizer = null

var distance_cache: DistanceCache
var collision_optimizer: CollisionOptimizer
var spatial_grid: SpatialGrid

func _init():
	distance_cache = DistanceCache.new()
	collision_optimizer = CollisionOptimizer.new()
	spatial_grid = SpatialGrid.new()

static func get_instance() -> PhysicsOptimizer:
	"""Get global physics optimizer instance"""
	if not instance:
		instance = PhysicsOptimizer.new()
	return instance

func update_caches(delta: float):
	"""Update all caches - call this once per frame"""
	distance_cache.update_cache(delta)
	collision_optimizer.update_cache(delta)

func clear_all_caches():
	"""Clear all caches"""
	distance_cache.clear_cache()
	collision_optimizer.clear_cache()
	spatial_grid.clear()

# Utility functions for common optimizations
static func is_within_range_squared(from: Vector2, to: Vector2, range_squared: float) -> bool:
	"""Fast range check using squared distance"""
	return from.distance_squared_to(to) <= range_squared

static func get_direction_fast(from: Vector2, to: Vector2) -> Vector2:
	"""Fast direction calculation with caching for common directions"""
	var diff = to - from
	var length_sq = diff.length_squared()
	
	if length_sq < 0.001:  # Very close, return zero
		return Vector2.ZERO
	
	# Use fast inverse square root approximation for normalization
	var inv_length = 1.0 / sqrt(length_sq)
	return diff * inv_length

static func lerp_vector_fast(from: Vector2, to: Vector2, weight: float) -> Vector2:
	"""Fast vector lerp without clamping weight"""
	return Vector2(
		from.x + (to.x - from.x) * weight,
		from.y + (to.y - from.y) * weight
	)
