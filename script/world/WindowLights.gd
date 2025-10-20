# script/world/WindowLights.gd
# 窗户灯光系统 - 管理建筑物窗户的灯光开关
# 根据昼夜循环自动开启/关闭窗户灯光,增加夜晚氛围

extends Node2D
class_name WindowLights

## 窗户灯光管理系统
##
## 功能:
## - 自动收集场景中所有标记为窗户灯光的Light2D节点
## - 根据昼夜循环开启/关闭灯光
## - 支持随机延迟开灯(模拟真实性)
## - 支持渐变开启/关闭效果
##
## 使用方法:
## 1. 将此脚本附加到场景的根节点或专门的Lighting节点
## 2. 在建筑物中添加Light2D节点,并添加到"window_lights"组
## 3. 系统会自动连接DayNightCycle的信号

# ========================================
# 导出变量
# ========================================

## 是否启用窗户灯光系统
@export var enabled: bool = true

## 开灯随机延迟范围(秒) - 模拟不同居民开灯时间
@export var turn_on_delay_min: float = 0.0
@export var turn_on_delay_max: float = 2.0

## 关灯随机延迟范围(秒)
@export var turn_off_delay_min: float = 0.0
@export var turn_off_delay_max: float = 1.0

## 灯光渐变时间(秒)
@export var fade_duration: float = 0.5

## 是否在启动时根据当前时间自动设置灯光状态
@export var auto_init_on_ready: bool = true

## 窗户灯光组名(用于查找Light2D节点)
@export var light_group_name: String = "window_lights"

# ========================================
# 私有变量
# ========================================

# 所有窗户灯光节点
var window_lights: Array[Light2D] = []

# DayNightCycle引用
var day_night_cycle = null

# TimeSystem引用
var time_system = null

# 当前是否是夜晚
var is_night_time: bool = false

# ========================================
# 信号
# ========================================

## 所有灯光开启完成
signal all_lights_turned_on()

## 所有灯光关闭完成
signal all_lights_turned_off()

# ========================================
# 生命周期方法
# ========================================

func _ready():
	"""初始化窗户灯光系统"""
	# 延迟收集灯光(确保场景完全加载)
	await get_tree().process_frame

	# 收集场景中所有窗户灯光
	_collect_window_lights()

	# 连接昼夜循环系统
	_connect_day_night_cycle()

	# 获取当前时间并初始化灯光状态
	if auto_init_on_ready:
		_initialize_lights_state()

	print("[WindowLights] 窗户灯光系统已启动 - 管理 %d 个灯光" % window_lights.size())

# ========================================
# 灯光收集
# ========================================

func _collect_window_lights():
	"""收集场景中所有窗户灯光节点"""
	window_lights.clear()

	# 方法1: 从组中获取(推荐)
	var lights_in_group = get_tree().get_nodes_in_group(light_group_name)

	for node in lights_in_group:
		if node is Light2D:
			window_lights.append(node)
			# 设置默认状态(关闭)
			node.enabled = false
			node.energy = 0.0

	# 方法2: 从建筑物中查找
	var buildings = get_tree().get_nodes_in_group("buildings")
	for building in buildings:
		var windows_container = building.get_node_or_null("Windows")
		if windows_container:
			for child in windows_container.get_children():
				if child is Light2D and child not in window_lights:
					window_lights.append(child)
					child.enabled = false
					child.energy = 0.0

	print("[WindowLights] 已收集 %d 个窗户灯光" % window_lights.size())

func add_window_light(light: Light2D):
	"""
	手动添加窗户灯光

	@param light: Light2D节点
	"""
	if light and light not in window_lights:
		window_lights.append(light)
		print("[WindowLights] 添加窗户灯光: %s" % light.name)

func remove_window_light(light: Light2D):
	"""
	移除窗户灯光

	@param light: Light2D节点
	"""
	if light in window_lights:
		window_lights.erase(light)
		print("[WindowLights] 移除窗户灯光: %s" % light.name)

func refresh_lights():
	"""重新收集所有窗户灯光"""
	_collect_window_lights()

# ========================================
# 昼夜循环连接
# ========================================

func _connect_day_night_cycle():
	"""连接DayNightCycle信号"""
	# 尝试从场景树中查找DayNightCycle节点
	day_night_cycle = _find_day_night_cycle()

	if day_night_cycle:
		# 连接信号
		if not day_night_cycle.is_connected("night_time_start", _on_night_start):
			day_night_cycle.connect("night_time_start", _on_night_start)

		if not day_night_cycle.is_connected("day_time_start", _on_day_start):
			day_night_cycle.connect("day_time_start", _on_day_start)

		print("[WindowLights] 已连接DayNightCycle")
	else:
		push_warning("[WindowLights] 未找到DayNightCycle节点")

func _find_day_night_cycle() -> Node:
	"""查找DayNightCycle节点"""
	# 方法1: 从根节点查找
	var root = get_tree().root
	for child in root.get_children():
		if child is CanvasModulate:
			var script = child.get_script()
			if script and script.resource_path.contains("DayNightCycle"):
				return child

	# 方法2: 从当前场景查找
	var current_scene = get_tree().current_scene
	if current_scene:
		for child in current_scene.get_children():
			if child is CanvasModulate:
				var script = child.get_script()
				if script and script.resource_path.contains("DayNightCycle"):
					return child

	return null

func _initialize_lights_state():
	"""根据当前时间初始化灯光状态"""
	time_system = get_node_or_null("/root/TimeSystem")

	if time_system:
		var current_hour = time_system.current_hour

		# 判断是否是夜晚(19:00-6:00)
		if current_hour >= 19 or current_hour < 6:
			is_night_time = true
			_turn_on_all_lights(false)  # 立即开灯,无延迟
		else:
			is_night_time = false
			_turn_off_all_lights(false)  # 立即关灯,无延迟

		print("[WindowLights] 初始化灯光状态 - 当前时间: %d:00, 夜晚: %s" % [current_hour, is_night_time])
	else:
		push_warning("[WindowLights] 未找到TimeSystem,默认关闭灯光")

# ========================================
# 昼夜事件处理
# ========================================

func _on_night_start():
	"""夜晚开始,开启所有灯光"""
	if not enabled:
		return

	print("[WindowLights] 夜晚降临,开启窗户灯光")
	is_night_time = true
	_turn_on_all_lights(true)  # 使用随机延迟

func _on_day_start():
	"""白天开始,关闭所有灯光"""
	if not enabled:
		return

	print("[WindowLights] 黎明到来,关闭窗户灯光")
	is_night_time = false
	_turn_off_all_lights(true)  # 使用随机延迟

# ========================================
# 灯光控制
# ========================================

func _turn_on_all_lights(use_delay: bool):
	"""
	开启所有窗户灯光

	@param use_delay: 是否使用随机延迟
	"""
	var completed_count = 0
	var total_count = window_lights.size()

	for light in window_lights:
		if not is_instance_valid(light):
			continue

		# 随机延迟
		var delay = 0.0
		if use_delay:
			delay = randf_range(turn_on_delay_min, turn_on_delay_max)

		# 启动协程开灯
		call_deferred("_turn_on_light_delayed", light, delay)

	# 等待所有灯光开启完成
	if total_count > 0:
		await get_tree().create_timer(turn_on_delay_max + fade_duration).timeout
		all_lights_turned_on.emit()

func _turn_on_light_delayed(light: Light2D, delay: float):
	"""
	延迟开启单个灯光

	@param light: Light2D节点
	@param delay: 延迟时间(秒)
	"""
	if delay > 0:
		await get_tree().create_timer(delay).timeout

	if not is_instance_valid(light):
		return

	# 启用灯光
	light.enabled = true

	# 渐变开启
	if fade_duration > 0:
		var tween = create_tween()
		tween.tween_property(light, "energy", 1.0, fade_duration)
	else:
		light.energy = 1.0

func _turn_off_all_lights(use_delay: bool):
	"""
	关闭所有窗户灯光

	@param use_delay: 是否使用随机延迟
	"""
	var total_count = window_lights.size()

	for light in window_lights:
		if not is_instance_valid(light):
			continue

		# 随机延迟
		var delay = 0.0
		if use_delay:
			delay = randf_range(turn_off_delay_min, turn_off_delay_max)

		# 启动协程关灯
		call_deferred("_turn_off_light_delayed", light, delay)

	# 等待所有灯光关闭完成
	if total_count > 0:
		await get_tree().create_timer(turn_off_delay_max + fade_duration).timeout
		all_lights_turned_off.emit()

func _turn_off_light_delayed(light: Light2D, delay: float):
	"""
	延迟关闭单个灯光

	@param light: Light2D节点
	@param delay: 延迟时间(秒)
	"""
	if delay > 0:
		await get_tree().create_timer(delay).timeout

	if not is_instance_valid(light):
		return

	# 渐变关闭
	if fade_duration > 0:
		var tween = create_tween()
		tween.tween_property(light, "energy", 0.0, fade_duration)
		await tween.finished
	else:
		light.energy = 0.0

	# 禁用灯光
	light.enabled = false

# ========================================
# 公共方法
# ========================================

func turn_on_light(light: Light2D, use_fade: bool = true):
	"""
	手动开启单个灯光

	@param light: Light2D节点
	@param use_fade: 是否使用渐变
	"""
	if not is_instance_valid(light) or light not in window_lights:
		return

	light.enabled = true

	if use_fade and fade_duration > 0:
		var tween = create_tween()
		tween.tween_property(light, "energy", 1.0, fade_duration)
	else:
		light.energy = 1.0

func turn_off_light(light: Light2D, use_fade: bool = true):
	"""
	手动关闭单个灯光

	@param light: Light2D节点
	@param use_fade: 是否使用渐变
	"""
	if not is_instance_valid(light) or light not in window_lights:
		return

	if use_fade and fade_duration > 0:
		var tween = create_tween()
		tween.tween_property(light, "energy", 0.0, fade_duration)
		await tween.finished
	else:
		light.energy = 0.0

	light.enabled = false

func get_lights_count() -> int:
	"""获取管理的灯光数量"""
	return window_lights.size()

func get_active_lights_count() -> int:
	"""获取当前开启的灯光数量"""
	var count = 0
	for light in window_lights:
		if is_instance_valid(light) and light.enabled:
			count += 1
	return count

# ========================================
# 调试方法
# ========================================

func _get_configuration_warnings() -> PackedStringArray:
	"""编辑器配置警告"""
	var warnings: PackedStringArray = []

	# 检查是否有DayNightCycle
	if not _find_day_night_cycle():
		warnings.append("场景中未找到DayNightCycle节点,窗户灯光可能无法自动开关")

	return warnings
