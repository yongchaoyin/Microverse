extends Node

# 地点管理系统 - Autoload单例
# 管理游戏中所有命名地点及其坐标

class_name LocationManager

# ========================================
# 地点数据结构
# ========================================

class Location:
	var id: String
	var name_cn: String  # 中文名称
	var name_en: String  # 英文名称
	var position: Vector2  # 世界坐标
	var type: LocationType  # 地点类型
	var capacity: int = 10  # 容纳人数
	var current_occupants: Array = []  # 当前在此地点的AI
	var interaction_points: Dictionary = {}  # 交互点 {"sit": [Vector2, Vector2], "work": Vector2}
	var description: String = ""

	func _init(_id: String, _name_cn: String, _pos: Vector2, _type: LocationType):
		id = _id
		name_cn = _name_cn
		position = _pos
		type = _type

	func add_occupant(ai_id: String):
		if ai_id not in current_occupants:
			current_occupants.append(ai_id)

	func remove_occupant(ai_id: String):
		current_occupants.erase(ai_id)

	func is_full() -> bool:
		return current_occupants.size() >= capacity

	func to_dict() -> Dictionary:
		return {
			"id": id,
			"name_cn": name_cn,
			"position": position,
			"type": LocationType.keys()[type],
			"occupants": current_occupants.size()
		}

# 地点类型枚举
enum LocationType {
	OFFICE,           # 办公室
	COFFEE_SHOP,      # 咖啡馆
	HOME,             # 家
	MEETING_ROOM,     # 会议室
	BATHROOM,         # 洗手间
	CAFETERIA,        # 食堂
	GYM,              # 健身房
	PARK,             # 公园
	LIBRARY,          # 图书馆
	ENTRANCE,         # 入口/大门
	HALLWAY,          # 走廊
	LOUNGE,           # 休息室
	OTHER             # 其他
}

# ========================================
# 地点存储
# ========================================

var locations: Dictionary = {}  # Key: location_id, Value: Location
var locations_by_type: Dictionary = {}  # Key: LocationType, Value: Array[Location]

# 信号
signal location_occupant_changed(location_id: String, occupants_count: int)

# ========================================
# 初始化
# ========================================

func _ready():
	_initialize_location_types()
	_load_locations_from_scene()

func _initialize_location_types():
	"""初始化地点类型分类字典"""
	for type in LocationType.values():
		locations_by_type[type] = []

# ========================================
# 地点注册
# ========================================

func register_location(
	id: String,
	name_cn: String,
	position: Vector2,
	type: LocationType,
	capacity: int = 10,
	interaction_points: Dictionary = {}
) -> Location:
	"""注册一个新地点"""
	var location = Location.new(id, name_cn, position, type)
	location.capacity = capacity
	location.interaction_points = interaction_points

	locations[id] = location
	locations_by_type[type].append(location)

	print("[LocationManager] 注册地点: %s (%s) at %v" % [name_cn, id, position])
	return location

func unregister_location(id: String):
	"""注销地点"""
	if locations.has(id):
		var location = locations[id]
		locations_by_type[location.type].erase(location)
		locations.erase(id)
		print("[LocationManager] 注销地点: %s" % id)

# ========================================
# 地点查询
# ========================================

func get_location(id: String) -> Location:
	"""根据ID获取地点"""
	return locations.get(id, null)

func get_location_by_name(name_cn: String) -> Location:
	"""根据中文名称获取地点"""
	for location in locations.values():
		if location.name_cn == name_cn:
			return location
	return null

func get_locations_by_type(type: LocationType) -> Array:
	"""获取指定类型的所有地点"""
	return locations_by_type.get(type, [])

func get_nearest_location(from_position: Vector2, type: LocationType = -1) -> Location:
	"""获取最近的地点,可选类型过滤"""
	var nearest: Location = null
	var nearest_distance = INF

	var search_locations = locations.values()
	if type != -1:
		search_locations = get_locations_by_type(type)

	for location in search_locations:
		var distance = from_position.distance_to(location.position)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest = location

	return nearest

func get_available_location(type: LocationType) -> Location:
	"""获取指定类型的未满地点"""
	var available_locations = get_locations_by_type(type)
	for location in available_locations:
		if not location.is_full():
			return location
	return null

# ========================================
# 地点占用管理
# ========================================

func set_location_occupant(location_id: String, ai_id: String, entering: bool):
	"""设置AI进入/离开地点"""
	var location = get_location(location_id)
	if not location:
		return

	if entering:
		location.add_occupant(ai_id)
	else:
		location.remove_occupant(ai_id)

	location_occupant_changed.emit(location_id, location.current_occupants.size())

func get_occupants(location_id: String) -> Array:
	"""获取地点内的所有AI"""
	var location = get_location(location_id)
	if location:
		return location.current_occupants
	return []

# ========================================
# 从场景加载地点
# ========================================

func _load_locations_from_scene():
	"""从当前场景的标记节点加载地点"""
	await get_tree().process_frame  # 等待场景加载完成

	# 查找所有标记为地点的节点 (需要在场景中添加group: "location")
	var location_nodes = get_tree().get_nodes_in_group("location")

	print("[LocationManager] 从场景加载 %d 个地点标记..." % location_nodes.size())

	for node in location_nodes:
		if node has meta("location_id"):
			var id = node.get_meta("location_id")
			var name_cn = node.get_meta("location_name_cn", id)
			var type_str = node.get_meta("location_type", "OTHER")
			var type = _parse_location_type(type_str)
			var capacity = node.get_meta("location_capacity", 10)

			register_location(
				id,
				name_cn,
				node.global_position,
				type,
				capacity
			)

func _parse_location_type(type_str: String) -> LocationType:
	"""解析地点类型字符串"""
	match type_str.to_upper():
		"OFFICE": return LocationType.OFFICE
		"COFFEE_SHOP": return LocationType.COFFEE_SHOP
		"HOME": return LocationType.HOME
		"MEETING_ROOM": return LocationType.MEETING_ROOM
		"BATHROOM": return LocationType.BATHROOM
		"CAFETERIA": return LocationType.CAFETERIA
		"GYM": return LocationType.GYM
		"PARK": return LocationType.PARK
		"LIBRARY": return LocationType.LIBRARY
		"ENTRANCE": return LocationType.ENTRANCE
		"HALLWAY": return LocationType.HALLWAY
		"LOUNGE": return LocationType.LOUNGE
		_: return LocationType.OTHER

# ========================================
# 调试和工具函数
# ========================================

func get_all_locations() -> Array:
	"""获取所有地点"""
	return locations.values()

func print_locations():
	"""打印所有地点信息"""
	print("\n=== 地点列表 ===")
	for location in locations.values():
		print("- %s (%s): %v, 类型: %s, 占用: %d/%d" % [
			location.name_cn,
			location.id,
			location.position,
			LocationType.keys()[location.type],
			location.current_occupants.size(),
			location.capacity
		])
	print("================\n")

func get_location_summary(location_id: String) -> String:
	"""获取地点摘要信息"""
	var location = get_location(location_id)
	if not location:
		return "未知地点"

	return "%s (占用: %d/%d人)" % [
		location.name_cn,
		location.current_occupants.size(),
		location.capacity
	]
