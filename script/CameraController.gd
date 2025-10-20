extends Camera2D
class_name CameraController

## 相机控制器 - 扩展版
##
## 功能:
## - 跟随角色/自由浏览
## - 多级缩放
## - 拖拽移动
## - 地图边界限制
## - 平滑移动

# ========================================
# 导出变量
# ========================================

## 跟随模式
@export var follow_speed: float = 5.0  # 相机跟随速度
@export var character_zoom: float = 1.5  # 跟随角色时的缩放级别

## 缩放配置
@export var zoom_level: float = 0.8    # 默认缩放级别（全局视图，显示更多内容）
@export var zoom_speed: float = 0.1  # 滚轮缩放速度
@export var min_zoom: float = 0.5  # 最小缩放级别
@export var max_zoom: float = 2.0  # 最大缩放级别

## 预设缩放级别
@export var zoom_levels: Array[float] = [0.5, 0.75, 1.0, 1.5, 2.0]

## 拖拽配置
@export var drag_speed: float = 1.0  # 拖拽移动的速度
@export var enable_middle_mouse_drag: bool = true  # 是否启用中键拖拽

## 地图边界(像素坐标)
@export var map_bounds: Rect2 = Rect2(0, 0, 2400, 1920)  # 150×120 tiles @ 16px

## 是否启用平滑移动
@export var position_smoothing_enabled: bool = true
@export var position_smoothing_speed: float = 5.0

# ========================================
# 私有变量
# ========================================

var target: Node2D = null
var original_position: Vector2
var is_dragging: bool = false
var drag_start_position: Vector2
var camera_start_position: Vector2
var manual_position: Vector2  # 手动拖拽后的位置
var is_manual_mode: bool = false  # 是否处于手动控制模式
var manual_zoom: float = 0.8  # 手动模式下的缩放级别

var current_zoom_index: int = 2  # 当前缩放级别索引(默认1.0x)
var follow_mode: bool = true  # 是否处于跟随模式

func _ready():
	"""初始化相机"""
	# 设置初始位置为地图中心
	position = map_bounds.get_center()

	# 保存初始位置
	original_position = position
	manual_position = position

	# 设置初始缩放为全局视图
	zoom = Vector2(zoom_level, zoom_level)

	# 设置相机限制(地图边界)
	_setup_camera_limits()

	# 启用平滑
	if position_smoothing_enabled:
		# Godot 4.x使用不同的平滑方式,这里手动实现
		pass

	make_current()

	print("[CameraController] 相机已初始化 - 中心位置: %s" % str(position))

func _setup_camera_limits():
	"""设置相机边界限制"""
	limit_left = int(map_bounds.position.x)
	limit_top = int(map_bounds.position.y)
	limit_right = int(map_bounds.position.x + map_bounds.size.x)
	limit_bottom = int(map_bounds.position.y + map_bounds.size.y)

	print("[CameraController] 相机边界: (%d, %d) -> (%d, %d)" % [
		limit_left, limit_top, limit_right, limit_bottom
	])

func _process(delta):
	if is_manual_mode:
		# 手动模式：保持在手动设置的位置和缩放
		position = position.lerp(manual_position, follow_speed * delta)
		zoom = zoom.lerp(Vector2(manual_zoom, manual_zoom), follow_speed * delta)
	elif target:
		# 平滑跟随目标
		position = position.lerp(target.position, follow_speed * delta)
		# 平滑缩放
		zoom = zoom.lerp(Vector2(character_zoom, character_zoom), follow_speed * delta)
	else:
		# 如果没有目标，回到原始位置和缩放
		position = position.lerp(original_position, follow_speed * delta)
		zoom = zoom.lerp(Vector2(zoom_level, zoom_level), follow_speed * delta)

func _input(event):
	# 处理鼠标拖拽(右键或中键)
	if event is InputEventMouseButton:
		var is_drag_button = event.button_index == MOUSE_BUTTON_RIGHT
		if enable_middle_mouse_drag:
			is_drag_button = is_drag_button or event.button_index == MOUSE_BUTTON_MIDDLE

		if is_drag_button:
			if event.pressed:
				# 开始拖拽
				is_dragging = true
				drag_start_position = event.position
				camera_start_position = position
				# 保存当前缩放级别
				manual_zoom = zoom.x
				follow_mode = false  # 退出跟随模式
			else:
				# 结束拖拽
				is_dragging = false

	if event is InputEventMouseMotion and is_dragging:
		# 拖拽移动相机
		var mouse_delta = event.position - drag_start_position
		# 将屏幕坐标转换为世界坐标（考虑缩放）
		var world_delta = mouse_delta / zoom.x * drag_speed
		manual_position = camera_start_position - world_delta
		is_manual_mode = true
	# 处理鼠标滚轮缩放
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			# 放大
			zoom_camera(zoom_speed)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			# 缩小
			zoom_camera(-zoom_speed)
	
	# 处理键盘快捷键
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_SPACE:  # 空格键恢复视角
				restore_view()
			KEY_R:  # R键重置相机
				reset_camera()
			KEY_F:  # F键切换跟随模式
				toggle_follow_mode()
			KEY_F12:  # F12导出当前视口PNG
				_export_map_screenshot()
			KEY_F11:  # F11生成纯绘制镇区地图PNG
				_generate_town_map_image()

func zoom_camera(delta_zoom: float):
	"""缩放相机，限制在最小和最大缩放范围内"""
	var current_zoom = zoom.x
	var new_zoom = clamp(current_zoom + delta_zoom, min_zoom, max_zoom)
	
	if is_manual_mode:
		# 手动模式下更新manual_zoom
		manual_zoom = new_zoom
	elif target:
		# 跟随角色模式下更新character_zoom
		character_zoom = new_zoom
	else:
		# 地图模式下更新zoom_level
		zoom_level = new_zoom

func restore_view():
	"""恢复到选中角色的中心视角，如果没有选中角色则居中显示地图"""
	is_manual_mode = false
	if target:
		# 恢复跟随选中角色
		follow_character(target)
	else:
		# 回到地图中心
		position = original_position
		zoom = Vector2(zoom_level, zoom_level)

func follow_character(character: Node2D):
	"""
	跟随指定角色

	@param character: 要跟随的角色节点
	"""
	if character:
		target = character
		is_manual_mode = false  # 退出手动模式
		follow_mode = true
		print("[CameraController] 开始跟随角色: %s" % character.name)
	else:
		target = null

func reset_camera():
	"""重置相机到初始状态"""
	current_zoom_index = 2
	zoom = Vector2(1.0, 1.0)
	if target:
		global_position = target.global_position
	else:
		position = original_position
	follow_mode = true
	is_manual_mode = false
	print("[CameraController] 相机已重置")

func toggle_follow_mode():
	"""切换跟随模式"""
	follow_mode = !follow_mode
	is_manual_mode = not follow_mode
	print("[CameraController] 跟随模式: %s" % ("开启" if follow_mode else "关闭"))

func zoom_in():
	"""放大(使用预设级别)"""
	if current_zoom_index < zoom_levels.size() - 1:
		current_zoom_index += 1
		var target_zoom = zoom_levels[current_zoom_index]
		var tween = create_tween()
		tween.tween_property(self, "zoom", Vector2(target_zoom, target_zoom), 0.2)
		print("[CameraController] 放大到: %.2fx" % target_zoom)

func zoom_out():
	"""缩小(使用预设级别)"""
	if current_zoom_index > 0:
		current_zoom_index -= 1
		var target_zoom = zoom_levels[current_zoom_index]
		var tween = create_tween()
		tween.tween_property(self, "zoom", Vector2(target_zoom, target_zoom), 0.2)
		print("[CameraController] 缩小到: %.2fx" % target_zoom)

func get_visible_rect() -> Rect2:
	"""
	获取相机当前可见的矩形范围

	@return: 可见矩形(世界坐标)
	"""
	var viewport_size = get_viewport().get_visible_rect().size
	var camera_pos = global_position
	var zoom_factor = zoom.x if zoom.x > 0 else 1.0

	var half_size = viewport_size / (2.0 * zoom_factor)

	return Rect2(
		camera_pos - half_size,
		viewport_size / zoom_factor
	)

func _export_map_screenshot(output_path: String = "user://TownMap.png"):
	var viewport := get_viewport()
	if viewport:
		var tex := viewport.get_texture()
		if tex:
			var img := tex.get_image()
			var err := img.save_png(output_path)
			if err == OK:
				print("[CameraController] ✓ 地图图片已保存 -> %s" % output_path)
			else:
				push_error("[CameraController] 保存PNG失败: %s (code=%d)" % [output_path, err])
		else:
			push_error("[CameraController] 视口没有纹理，无法导出")
	else:
		push_error("[CameraController] 未找到视口")

func export_full_map_png(output_path: String = "user://TownMap_Full.png"):
	var exporter := TownMapExporter.new()
	add_child(exporter)
	await exporter.export_current_scene(output_path, Vector2i(int(map_bounds.size.x), int(map_bounds.size.y)))
	exporter.queue_free()

func _generate_town_map_image(output_path: String = "user://TownMap_Generated.png"):
	var gen := TownMapImageGenerator.new()
	add_child(gen)
	await gen.generate(output_path, Vector2i(int(map_bounds.size.x), int(map_bounds.size.y)))
	gen.queue_free()
