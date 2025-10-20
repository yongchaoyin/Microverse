# script/world/ViewportCulling.gd
# 视野裁剪优化系统 - 只渲染相机可见范围内的对象
# 提升大地图性能,减少不必要的渲染和处理

extends Node
class_name ViewportCulling

## 视野裁剪优化系统
##
## 功能:
## - 自动裁剪相机视野外的对象
## - 支持多种对象类型(树木、装饰物、建筑等)
## - 可配置缓冲区(避免物体突然出现/消失)
## - 支持分层裁剪(重要对象永远可见)
## - 性能监控和统计
##
## 使用方法:
## 1. 将此脚本附加到场景的根节点或专门的Optimization节点
## 2. 添加需要裁剪的对象到对应的组("trees", "decorations"等)
## 3. 系统会自动根据相机位置启用/禁用对象

# ========================================
# 导出变量
# ========================================

## 是否启用视野裁剪
@export var enabled: bool = true

## 缓冲区大小(tiles) - 相机视野外多少距离内的对象仍然可见
@export var buffer_tiles: int = 5

## 更新间隔(秒) - 多久检查一次裁剪
@export var update_interval: float = 0.5

## 是否裁剪树木
@export var cull_trees: bool = true

## 是否裁剪装饰物
@export var cull_decorations: bool = true

## 是否裁剪建筑(通常不裁剪)
@export var cull_buildings: bool = false

## 是否裁剪角色(通常不裁剪)
@export var cull_characters: bool = false

## 是否禁用不可见对象的处理(更激进的优化)
@export var disable_processing: bool = true

## 是否显示调试信息
@export var show_debug_info: bool = false

# ========================================
# 私有变量
# ========================================

# 相机可见范围(加上缓冲区)
var visible_rect: Rect2 = Rect2()

# 相机引用
var camera: Camera2D = null

# 更新计时器
var update_timer: float = 0.0

# 需要裁剪的对象组
var culling_groups: Dictionary = {
	"trees": true,
	"decorations": true,
	"buildings": false,
	"characters": false,
	"effects": true
}

# 性能统计
var stats: Dictionary = {
	"total_objects": 0,
	"visible_objects": 0,
	"culled_objects": 0,
	"last_update_time": 0.0
}

# 缓存的对象列表
var cached_objects: Dictionary = {}

# 是否已初始化
var is_initialized: bool = false

# ========================================
# 生命周期方法
# ========================================

func _ready():
	"""初始化视野裁剪系统"""
	# 延迟初始化(确保场景完全加载)
	await get_tree().process_frame

	# 查找相机
	camera = _find_camera()

	if not camera:
		push_warning("[ViewportCulling] 未找到相机,视野裁剪系统将无法工作")
		enabled = false
		return

	# 缓存所有需要裁剪的对象
	_cache_objects()

	is_initialized = true

	print("[ViewportCulling] 视野裁剪系统已启动 - 管理 %d 个对象" % stats.total_objects)
	if show_debug_info:
		_print_stats()

func _process(delta):
	"""更新裁剪"""
	if not enabled or not is_initialized:
		return

	# 更新计时器
	update_timer += delta

	if update_timer >= update_interval:
		update_timer = 0.0
		_update_culling()

# ========================================
# 相机查找
# ========================================

func _find_camera() -> Camera2D:
	"""查找场景中的相机"""
	# 方法1: 从当前场景查找
	var current_scene = get_tree().current_scene
	if current_scene:
		for child in current_scene.get_children():
			if child is Camera2D:
				return child

		# 递归查找
		for child in current_scene.get_children():
			var cam = _find_camera_recursive(child)
			if cam:
				return cam

	# 方法2: 从视口获取
	var viewport = get_viewport()
	if viewport:
		var cam = viewport.get_camera_2d()
		if cam:
			return cam

	return null

func _find_camera_recursive(node: Node) -> Camera2D:
	"""递归查找相机"""
	if node is Camera2D:
		return node

	for child in node.get_children():
		var result = _find_camera_recursive(child)
		if result:
			return result

	return null

# ========================================
# 对象缓存
# ========================================

func _cache_objects():
	"""缓存所有需要裁剪的对象"""
	cached_objects.clear()
	stats.total_objects = 0

	# 根据配置缓存不同组的对象
	if cull_trees:
		cached_objects["trees"] = get_tree().get_nodes_in_group("trees")
		stats.total_objects += cached_objects["trees"].size()

	if cull_decorations:
		cached_objects["decorations"] = get_tree().get_nodes_in_group("decorations")
		stats.total_objects += cached_objects["decorations"].size()

	if cull_buildings:
		cached_objects["buildings"] = get_tree().get_nodes_in_group("buildings")
		stats.total_objects += cached_objects["buildings"].size()

	if cull_characters:
		cached_objects["characters"] = get_tree().get_nodes_in_group("characters")
		stats.total_objects += cached_objects["characters"].size()

	# 额外的自定义组
	var effects = get_tree().get_nodes_in_group("effects")
	if effects.size() > 0:
		cached_objects["effects"] = effects
		stats.total_objects += effects.size()

	print("[ViewportCulling] 已缓存 %d 个对象" % stats.total_objects)

func refresh_cache():
	"""重新缓存对象(场景变化后调用)"""
	_cache_objects()

# ========================================
# 裁剪更新
# ========================================

func _update_culling():
	"""更新裁剪状态"""
	if not camera:
		return

	var start_time = Time.get_ticks_msec()

	# 计算相机可见范围
	_calculate_visible_rect()

	# 裁剪所有组的对象
	stats.visible_objects = 0
	stats.culled_objects = 0

	for group_name in cached_objects:
		var objects = cached_objects[group_name]
		_cull_object_group(objects)

	# 性能统计
	stats.last_update_time = Time.get_ticks_msec() - start_time

	if show_debug_info and stats.last_update_time > 16:  # 超过一帧(60fps)
		push_warning("[ViewportCulling] 裁剪更新耗时过长: %d ms" % stats.last_update_time)

func _calculate_visible_rect():
	"""计算相机可见范围"""
	if not camera:
		return

	# 获取视口大小
	var viewport_size = get_viewport().get_visible_rect().size

	# 获取相机位置和缩放
	var camera_pos = camera.global_position
	var zoom = camera.zoom.x if camera.zoom.x > 0 else 1.0

	# 计算可见范围(考虑缩放)
	var half_size = viewport_size / (2.0 * zoom)

	# 添加缓冲区
	var buffer_pixels = buffer_tiles * 16  # 假设tile是16像素

	visible_rect = Rect2(
		camera_pos - half_size - Vector2(buffer_pixels, buffer_pixels),
		viewport_size / zoom + Vector2(buffer_pixels * 2, buffer_pixels * 2)
	)

func _cull_object_group(objects: Array):
	"""
	裁剪一组对象

	@param objects: 对象数组
	"""
	for obj in objects:
		if not is_instance_valid(obj):
			continue

		# 检查对象是否在可见范围内
		var is_visible = _is_object_visible(obj)

		# 更新对象状态
		if is_visible:
			_make_object_visible(obj)
			stats.visible_objects += 1
		else:
			_make_object_invisible(obj)
			stats.culled_objects += 1

func _is_object_visible(obj: Node) -> bool:
	"""
	检查对象是否在可见范围内

	@param obj: 要检查的对象
	@return: 是否可见
	"""
	# 获取对象位置
	var obj_pos: Vector2

	if obj is Node2D:
		obj_pos = obj.global_position
	elif obj is Control:
		obj_pos = obj.global_position
	else:
		return true  # 不是2D节点,总是可见

	# 检查是否在可见矩形内
	return visible_rect.has_point(obj_pos)

func _make_object_visible(obj: Node):
	"""
	使对象可见

	@param obj: 对象节点
	"""
	# 如果对象已经可见,跳过
	if obj.visible:
		return

	obj.visible = true

	# 启用处理
	if disable_processing:
		obj.process_mode = Node.PROCESS_MODE_INHERIT

func _make_object_invisible(obj: Node):
	"""
	使对象不可见

	@param obj: 对象节点
	"""
	# 如果对象已经不可见,跳过
	if not obj.visible:
		return

	obj.visible = false

	# 禁用处理(更激进的优化)
	if disable_processing:
		obj.process_mode = Node.PROCESS_MODE_DISABLED

# ========================================
# 公共方法
# ========================================

func set_enabled(is_enabled: bool):
	"""
	启用/禁用视野裁剪

	@param is_enabled: 是否启用
	"""
	enabled = is_enabled

	if not enabled:
		# 禁用时,显示所有对象
		_show_all_objects()

func _show_all_objects():
	"""显示所有对象"""
	for group_name in cached_objects:
		var objects = cached_objects[group_name]
		for obj in objects:
			if is_instance_valid(obj):
				obj.visible = true
				obj.process_mode = Node.PROCESS_MODE_INHERIT

func add_object(obj: Node, group_name: String = "decorations"):
	"""
	添加对象到裁剪系统

	@param obj: 对象节点
	@param group_name: 组名
	"""
	if not cached_objects.has(group_name):
		cached_objects[group_name] = []

	if obj not in cached_objects[group_name]:
		cached_objects[group_name].append(obj)
		stats.total_objects += 1

func remove_object(obj: Node, group_name: String = "decorations"):
	"""
	从裁剪系统移除对象

	@param obj: 对象节点
	@param group_name: 组名
	"""
	if cached_objects.has(group_name):
		if obj in cached_objects[group_name]:
			cached_objects[group_name].erase(obj)
			stats.total_objects -= 1

func get_stats() -> Dictionary:
	"""获取性能统计"""
	return stats.duplicate()

func get_visible_rect() -> Rect2:
	"""获取当前可见范围"""
	return visible_rect

# ========================================
# 调试方法
# ========================================

func _print_stats():
	"""打印性能统计"""
	print("[ViewportCulling] 统计:")
	print("  总对象数: %d" % stats.total_objects)
	print("  可见对象: %d" % stats.visible_objects)
	print("  已裁剪: %d" % stats.culled_objects)
	print("  更新耗时: %d ms" % stats.last_update_time)
	print("  裁剪率: %.1f%%" % (float(stats.culled_objects) / max(stats.total_objects, 1) * 100))

func _draw():
	"""绘制调试信息"""
	if not show_debug_info or not enabled:
		return

	# 绘制可见范围矩形(需要将此节点设为CanvasItem)
	# draw_rect(visible_rect, Color.GREEN, false, 2.0)

# ========================================
# 配置警告
# ========================================

func _get_configuration_warnings() -> PackedStringArray:
	"""编辑器配置警告"""
	var warnings: PackedStringArray = []

	if not _find_camera():
		warnings.append("场景中未找到Camera2D节点,视野裁剪将无法工作")

	return warnings
