# script/world/StreetLights.gd
# 路灯系统 - 管理街道路灯的开关和效果
# 根据昼夜循环自动开启/关闭路灯,营造夜晚氛围

extends Node2D
class_name StreetLights

## 路灯管理系统
##
## 功能:
## - 管理场景中所有路灯的开关
## - 根据昼夜循环自动开启/关闭
## - 支持路灯闪烁效果(模拟真实性)
## - 支持程序化生成路灯
##
## 使用方法:
## 1. 将此脚本附加到场景的Lighting节点或专门的StreetLights节点
## 2. 手动放置StreetLight场景实例,或使用程序化生成
## 3. 系统会自动连接DayNightCycle的信号

# ========================================
# 导出变量
# ========================================

## 是否启用路灯系统
@export var enabled: bool = true

## 路灯场景预制体路径
@export var street_light_scene: PackedScene = null

## 是否在启动时根据当前时间自动设置路灯状态
@export var auto_init_on_ready: bool = true

## 路灯组名(用于查找路灯节点)
@export var light_group_name: String = "street_lights"

## 是否启用路灯闪烁效果
@export var enable_flicker: bool = true

## 路灯闪烁间隔范围(秒)
@export var flicker_interval_min: float = 2.0
@export var flicker_interval_max: float = 5.0

## 路灯闪烁强度变化范围
@export var flicker_energy_min: float = 0.9
@export var flicker_energy_max: float = 1.1

# ========================================
# 程序化生成配置
# ========================================

## 是否启用程序化生成路灯
@export_group("Procedural Generation")
@export var enable_procedural_generation: bool = false

## 路灯位置数组(手动配置)
@export var light_positions: Array[Vector2] = []

## 沿路径生成路灯(Path2D节点路径)
@export var path_node: NodePath = NodePath()

## 路灯间距(像素)
@export var light_spacing: float = 200.0

# ========================================
# 私有变量
# ========================================

# 所有路灯节点
var street_lights: Array = []

# DayNightCycle引用
var day_night_cycle = null

# TimeSystem引用
var time_system = null

# 当前是否是夜晚
var is_night_time: bool = false

# 闪烁定时器
var flicker_timers: Dictionary = {}

# ========================================
# 信号
# ========================================

## 所有路灯开启完成
signal all_lights_turned_on()

## 所有路灯关闭完成
signal all_lights_turned_off()

# ========================================
# 生命周期方法
# ========================================

func _ready():
	"""初始化路灯系统"""
	# 延迟初始化(确保场景完全加载)
	await get_tree().process_frame

	# 程序化生成路灯
	if enable_procedural_generation:
		_generate_street_lights()

	# 收集场景中所有路灯
	_collect_street_lights()

	# 连接昼夜循环系统
	_connect_day_night_cycle()

	# 初始化路灯状态
	if auto_init_on_ready:
		_initialize_lights_state()

	# 启动闪烁效果
	if enable_flicker:
		_start_flicker_effects()

	print("[StreetLights] 路灯系统已启动 - 管理 %d 个路灯" % street_lights.size())

# ========================================
# 路灯收集
# ========================================

func _collect_street_lights():
	"""收集场景中所有路灯节点"""
	street_lights.clear()

	# 从组中获取
	var lights_in_group = get_tree().get_nodes_in_group(light_group_name)
	for node in lights_in_group:
		if node not in street_lights:
			street_lights.append(node)

	# 从子节点中查找
	for child in get_children():
		if child.has_method("turn_on") and child not in street_lights:
			street_lights.append(child)

	print("[StreetLights] 已收集 %d 个路灯" % street_lights.size())

func add_street_light(light_node: Node):
	"""
	手动添加路灯

	@param light_node: 路灯节点(需要有turn_on/turn_off方法)
	"""
	if light_node and light_node not in street_lights:
		street_lights.append(light_node)
		light_node.add_to_group(light_group_name)
		print("[StreetLights] 添加路灯: %s" % light_node.name)

func remove_street_light(light_node: Node):
	"""
	移除路灯

	@param light_node: 路灯节点
	"""
	if light_node in street_lights:
		street_lights.erase(light_node)
		print("[StreetLights] 移除路灯: %s" % light_node.name)

# ========================================
# 程序化生成
# ========================================

func _generate_street_lights():
	"""程序化生成路灯"""
	if not street_light_scene:
		push_warning("[StreetLights] 未设置路灯场景预制体,无法生成路灯")
		return

	var generated_count = 0

	# 方法1: 从位置数组生成
	for pos in light_positions:
		_spawn_street_light(pos)
		generated_count += 1

	# 方法2: 沿路径生成
	if not path_node.is_empty():
		var path = get_node_or_null(path_node)
		if path and path is Path2D:
			_generate_lights_along_path(path)
			generated_count += int(path.curve.get_baked_length() / light_spacing)

	print("[StreetLights] 程序化生成了 %d 个路灯" % generated_count)

func _spawn_street_light(position: Vector2) -> Node:
	"""
	在指定位置生成路灯

	@param position: 世界坐标
	@return: 生成的路灯节点
	"""
	var light = street_light_scene.instantiate()
	light.position = position
	light.add_to_group(light_group_name)
	add_child(light)
	street_lights.append(light)
	return light

func _generate_lights_along_path(path: Path2D):
	"""
	沿路径生成路灯

	@param path: Path2D节点
	"""
	if not path.curve:
		return

	var path_length = path.curve.get_baked_length()
	var current_distance = 0.0

	while current_distance <= path_length:
		var path_pos = path.curve.sample_baked(current_distance)
		var world_pos = path.global_position + path_pos
		_spawn_street_light(world_pos)
		current_distance += light_spacing

# ========================================
# 昼夜循环连接
# ========================================

func _connect_day_night_cycle():
	"""连接DayNightCycle信号"""
	day_night_cycle = _find_day_night_cycle()

	if day_night_cycle:
		if not day_night_cycle.is_connected("night_time_start", _on_night_start):
			day_night_cycle.connect("night_time_start", _on_night_start)

		if not day_night_cycle.is_connected("day_time_start", _on_day_start):
			day_night_cycle.connect("day_time_start", _on_day_start)

		print("[StreetLights] 已连接DayNightCycle")
	else:
		push_warning("[StreetLights] 未找到DayNightCycle节点")

func _find_day_night_cycle() -> Node:
	"""查找DayNightCycle节点"""
	var root = get_tree().root
	for child in root.get_children():
		if child is CanvasModulate:
			var script = child.get_script()
			if script and script.resource_path.contains("DayNightCycle"):
				return child

	var current_scene = get_tree().current_scene
	if current_scene:
		for child in current_scene.get_children():
			if child is CanvasModulate:
				var script = child.get_script()
				if script and script.resource_path.contains("DayNightCycle"):
					return child

	return null

func _initialize_lights_state():
	"""根据当前时间初始化路灯状态"""
	time_system = get_node_or_null("/root/TimeSystem")

	if time_system:
		var current_hour = time_system.current_hour

		# 判断是否是夜晚(19:00-6:00)
		if current_hour >= 19 or current_hour < 6:
			is_night_time = true
			_turn_on_all_lights()
		else:
			is_night_time = false
			_turn_off_all_lights()

		print("[StreetLights] 初始化路灯状态 - 当前时间: %d:00, 夜晚: %s" % [current_hour, is_night_time])
	else:
		push_warning("[StreetLights] 未找到TimeSystem,默认关闭路灯")

# ========================================
# 昼夜事件处理
# ========================================

func _on_night_start():
	"""夜晚开始,开启所有路灯"""
	if not enabled:
		return

	print("[StreetLights] 夜晚降临,开启路灯")
	is_night_time = true
	_turn_on_all_lights()

func _on_day_start():
	"""白天开始,关闭所有路灯"""
	if not enabled:
		return

	print("[StreetLights] 黎明到来,关闭路灯")
	is_night_time = false
	_turn_off_all_lights()

# ========================================
# 路灯控制
# ========================================

func _turn_on_all_lights():
	"""开启所有路灯"""
	for light in street_lights:
		if not is_instance_valid(light):
			continue

		if light.has_method("turn_on"):
			light.turn_on()

	all_lights_turned_on.emit()

func _turn_off_all_lights():
	"""关闭所有路灯"""
	for light in street_lights:
		if not is_instance_valid(light):
			continue

		if light.has_method("turn_off"):
			light.turn_off()

	all_lights_turned_off.emit()

# ========================================
# 闪烁效果
# ========================================

func _start_flicker_effects():
	"""启动路灯闪烁效果"""
	if not enable_flicker:
		return

	for light in street_lights:
		if not is_instance_valid(light):
			continue

		# 为每个路灯创建闪烁定时器
		_start_light_flicker(light)

func _start_light_flicker(light_node: Node):
	"""
	启动单个路灯的闪烁效果

	@param light_node: 路灯节点
	"""
	# 随机间隔
	var interval = randf_range(flicker_interval_min, flicker_interval_max)

	# 创建定时器
	var timer = Timer.new()
	timer.wait_time = interval
	timer.one_shot = true
	add_child(timer)

	timer.timeout.connect(func():
		if is_instance_valid(light_node) and is_night_time:
			_flicker_light(light_node)
			# 重新启动定时器
			_start_light_flicker(light_node)
		timer.queue_free()
	)

	timer.start()
	flicker_timers[light_node] = timer

func _flicker_light(light_node: Node):
	"""
	执行路灯闪烁动画

	@param light_node: 路灯节点
	"""
	# 获取Light2D节点
	var light_2d = _get_light2d_from_node(light_node)
	if not light_2d:
		return

	# 保存原始energy
	var original_energy = light_2d.energy

	# 闪烁动画: 降低亮度 → 恢复
	var tween = create_tween()
	var flicker_energy = randf_range(flicker_energy_min, flicker_energy_max)

	tween.tween_property(light_2d, "energy", flicker_energy, 0.1)
	tween.tween_property(light_2d, "energy", original_energy, 0.1)

func _get_light2d_from_node(node: Node) -> Light2D:
	"""
	从路灯节点获取Light2D

	@param node: 路灯节点
	@return: Light2D节点,如果找不到则返回null
	"""
	# 如果节点本身就是Light2D
	if node is Light2D:
		return node

	# 查找子节点
	for child in node.get_children():
		if child is Light2D:
			return child

	# 查找命名节点
	var light = node.get_node_or_null("Light2D")
	if light and light is Light2D:
		return light

	return null

# ========================================
# 公共方法
# ========================================

func turn_on_light(light_node: Node):
	"""
	手动开启单个路灯

	@param light_node: 路灯节点
	"""
	if not is_instance_valid(light_node) or light_node not in street_lights:
		return

	if light_node.has_method("turn_on"):
		light_node.turn_on()

func turn_off_light(light_node: Node):
	"""
	手动关闭单个路灯

	@param light_node: 路灯节点
	"""
	if not is_instance_valid(light_node) or light_node not in street_lights:
		return

	if light_node.has_method("turn_off"):
		light_node.turn_off()

func get_lights_count() -> int:
	"""获取管理的路灯数量"""
	return street_lights.size()

func get_active_lights_count() -> int:
	"""获取当前开启的路灯数量"""
	var count = 0
	for light in street_lights:
		if not is_instance_valid(light):
			continue

		var light_2d = _get_light2d_from_node(light)
		if light_2d and light_2d.enabled:
			count += 1

	return count

func clear_all_lights():
	"""清除所有路灯"""
	for light in street_lights:
		if is_instance_valid(light):
			light.queue_free()

	street_lights.clear()
	flicker_timers.clear()

# ========================================
# 调试方法
# ========================================

func _get_configuration_warnings() -> PackedStringArray:
	"""编辑器配置警告"""
	var warnings: PackedStringArray = []

	if not _find_day_night_cycle():
		warnings.append("场景中未找到DayNightCycle节点,路灯可能无法自动开关")

	if enable_procedural_generation and not street_light_scene:
		warnings.append("启用了程序化生成但未设置路灯场景预制体")

	return warnings
