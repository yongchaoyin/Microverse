extends Node

# AI移动控制器 - 控制AI角色的自主移动
# 挂载到每个AI角色上,配合CharacterController使用

class_name AIMovementController

# ========================================
# 移动状态
# ========================================

enum MovementState {
	IDLE,              # 空闲
	MOVING_TO_LOCATION,  # 前往地点
	MOVING_TO_POSITION,  # 前往坐标
	WAITING,           # 等待
	FOLLOWING          # 跟随
}

var current_state: MovementState = MovementState.IDLE
var target_location_id: String = ""
var target_position: Vector2 = Vector2.ZERO
var move_callback: Callable = Callable()

# 引用
var character_controller: CharacterBody2D  # CharacterController
var ai_agent: Node  # AIAgent引用

# 移动配置
var auto_move_enabled: bool = true  # 是否启用AI自主移动
var movement_speed_multiplier: float = 1.0  # 移动速度倍率

# 信号
signal movement_started(target)
signal movement_completed()
signal movement_failed(reason: String)
signal arrived_at_location(location_id: String)

# ========================================
# 初始化
# ========================================

func _ready():
	character_controller = get_parent()
	if not character_controller:
		push_error("[AIMovementController] 必须挂载到CharacterController节点上")
		return

	# 尝试获取AI代理
	await get_tree().process_frame
	ai_agent = character_controller.get_node_or_null("AIAgent")

	# 连接信号
	if character_controller.has_signal("navigation_completed"):
		character_controller.connect("navigation_completed", _on_navigation_completed)

func set_auto_move(enabled: bool):
	"""设置是否启用自主移动"""
	auto_move_enabled = enabled

# ========================================
# 地点移动
# ========================================

func move_to_location(location_id: String, callback: Callable = Callable()) -> bool:
	"""移动到指定地点"""
	if not auto_move_enabled:
		print("[AIMovementController] %s 自主移动已禁用" % character_controller.name)
		return false

	var location = LocationManager.get_location(location_id)
	if not location:
		print("[AIMovementController] 地点不存在: %s" % location_id)
		movement_failed.emit("地点不存在")
		return false

	print("[AIMovementController] %s 开始移动到: %s (%v)" % [
		character_controller.name,
		location.name_cn,
		location.position
	])

	target_location_id = location_id
	target_position = location.position
	move_callback = callback
	current_state = MovementState.MOVING_TO_LOCATION

	# 调用CharacterController的move_to
	character_controller.move_to(location.position)

	movement_started.emit(location_id)
	return true

func move_to_location_by_name(location_name: String, callback: Callable = Callable()) -> bool:
	"""根据地点名称移动"""
	var location = LocationManager.get_location_by_name(location_name)
	if not location:
		print("[AIMovementController] 未找到地点: %s" % location_name)
		movement_failed.emit("未找到地点")
		return false

	return move_to_location(location.id, callback)

func move_to_nearest_location(location_type: LocationManager.LocationType, callback: Callable = Callable()) -> bool:
	"""移动到最近的指定类型地点"""
	var location = LocationManager.get_nearest_location(
		character_controller.global_position,
		location_type
	)

	if not location:
		print("[AIMovementController] 未找到类型为 %s 的地点" % LocationManager.LocationType.keys()[location_type])
		movement_failed.emit("未找到地点")
		return false

	return move_to_location(location.id, callback)

# ========================================
# 坐标移动
# ========================================

func move_to_position(pos: Vector2, callback: Callable = Callable()) -> bool:
	"""移动到指定坐标"""
	if not auto_move_enabled:
		return false

	print("[AIMovementController] %s 移动到坐标: %v" % [character_controller.name, pos])

	target_position = pos
	target_location_id = ""
	move_callback = callback
	current_state = MovementState.MOVING_TO_POSITION

	character_controller.move_to(pos)

	movement_started.emit(pos)
	return true

# ========================================
# 特殊移动
# ========================================

func move_to_ai(target_ai: Node, min_distance: float = 50.0, callback: Callable = Callable()) -> bool:
	"""移动到另一个AI附近"""
	if not target_ai:
		return false

	var target_pos = target_ai.global_position
	var direction = (character_controller.global_position - target_pos).normalized()
	var final_pos = target_pos + direction * min_distance

	return move_to_position(final_pos, callback)

func wander_around(radius: float = 200.0):
	"""在当前位置附近随机游荡"""
	var random_offset = Vector2(
		randf_range(-radius, radius),
		randf_range(-radius, radius)
	)
	var wander_pos = character_controller.global_position + random_offset

	move_to_position(wander_pos)

# ========================================
# 移动到椅子
# ========================================

func move_to_chair_and_sit(chair: Node, callback: Callable = Callable()) -> bool:
	"""移动到椅子并坐下"""
	if not chair or chair.occupied:
		print("[AIMovementController] 椅子不可用")
		return false

	print("[AIMovementController] %s 移动到椅子并坐下" % character_controller.name)

	# 使用CharacterController的move_to_chair方法
	var success = character_controller.move_to_chair(chair)

	if success:
		move_callback = callback
		current_state = MovementState.MOVING_TO_POSITION
		movement_started.emit(chair)

	return success

# ========================================
# 移动控制
# ========================================

func stop_movement():
	"""停止当前移动"""
	current_state = MovementState.IDLE
	target_location_id = ""
	target_position = Vector2.ZERO
	move_callback = Callable()

	# 清空CharacterController的导航路径
	if character_controller.has_method("clear_navigation"):
		character_controller.clear_navigation()
	else:
		character_controller.navigation_path.clear()

	print("[AIMovementController] %s 停止移动" % character_controller.name)

func is_moving() -> bool:
	"""是否正在移动"""
	return current_state in [MovementState.MOVING_TO_LOCATION, MovementState.MOVING_TO_POSITION]

func get_current_location() -> String:
	"""获取AI当前所在地点ID"""
	var current_pos = character_controller.global_position
	var location = LocationManager.get_nearest_location(current_pos)

	if location and current_pos.distance_to(location.position) < 100.0:
		return location.id

	return ""

# ========================================
# 移动完成回调
# ========================================

func _on_navigation_completed():
	"""导航完成回调"""
	print("[AIMovementController] %s 导航完成" % character_controller.name)

	# 如果是移动到地点
	if current_state == MovementState.MOVING_TO_LOCATION and target_location_id != "":
		arrived_at_location.emit(target_location_id)

		# 更新地点占用
		LocationManager.set_location_occupant(target_location_id, character_controller.name, true)

	# 调用回调
	if move_callback.is_valid():
		move_callback.call()
		move_callback = Callable()

	movement_completed.emit()

	# 重置状态
	current_state = MovementState.IDLE

func _process(delta):
	"""检查移动状态"""
	if not is_moving():
		return

	# 检查是否到达目标 (CharacterController的导航路径为空表示到达)
	if character_controller.navigation_path.is_empty() and current_state != MovementState.IDLE:
		_on_navigation_completed()

# ========================================
# 日程驱动移动
# ========================================

func execute_schedule_movement(activity_type: String, location_id: String = ""):
	"""根据日程活动类型执行移动"""
	print("[AIMovementController] %s 执行日程移动: %s → %s" % [
		character_controller.name,
		activity_type,
		location_id if location_id != "" else "自动选择"
	])

	# 如果指定了地点ID,直接移动
	if location_id != "":
		move_to_location(location_id)
		return

	# 根据活动类型自动选择地点
	match activity_type:
		"work":
			move_to_nearest_location(LocationManager.LocationType.OFFICE)

		"meeting":
			move_to_nearest_location(LocationManager.LocationType.MEETING_ROOM)

		"lunch", "dinner":
			move_to_nearest_location(LocationManager.LocationType.CAFETERIA)

		"coffee_break":
			move_to_nearest_location(LocationManager.LocationType.COFFEE_SHOP)

		"gym", "exercise":
			move_to_nearest_location(LocationManager.LocationType.GYM)

		"rest", "break":
			move_to_nearest_location(LocationManager.LocationType.LOUNGE)

		"bathroom":
			move_to_nearest_location(LocationManager.LocationType.BATHROOM)

		"library", "study":
			move_to_nearest_location(LocationManager.LocationType.LIBRARY)

		"home", "sleep":
			move_to_nearest_location(LocationManager.LocationType.HOME)

		_:
			# 未知活动类型,随机游荡
			wander_around(150.0)
