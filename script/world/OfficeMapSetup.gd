# script/world/OfficeMapSetup.gd
# Office地图初始化脚本
# 自动为Office场景添加昼夜循环、窗户灯光、交互区域等地图系统
#
# 使用方法:
# 1. 将此脚本附加到Office场景的根节点
# 2. 运行游戏,脚本会自动创建并配置所有地图系统节点
# 3. 系统节点会自动保存到场景中(在编辑器模式下)

extends Node2D
class_name OfficeMapSetup

## Office地图初始化系统
##
## 功能:
## - 自动创建DayNightCycle节点
## - 创建WindowLights系统和办公室窗户灯光
## - 为工位添加InteractionZone
## - 配置Camera地图边界
## - 添加OfficeAreaLights(天花板灯光)

# ========================================
# 导出变量
# ========================================

## 是否在启动时自动初始化(设为false可手动调用setup())
@export var auto_setup_on_ready: bool = true

## 是否启用昼夜循环
@export var enable_day_night_cycle: bool = true

## 是否启用窗户灯光
@export var enable_window_lights: bool = true

## 是否启用办公室天花板灯光
@export var enable_office_lights: bool = true

## 是否添加交互区域
@export var enable_interaction_zones: bool = true

## 是否配置相机边界
@export var configure_camera_bounds: bool = true

# ========================================
# 私有变量
# ========================================

var day_night_cycle: CanvasModulate = null
var window_lights_system: Node2D = null
var office_lights_system: Node2D = null
var interaction_zones_container: Node2D = null

var is_setup_complete: bool = false

# ========================================
# 生命周期方法
# ========================================

func _ready():
	"""初始化Office地图系统"""
	if auto_setup_on_ready:
		# 延迟一帧确保场景完全加载
		await get_tree().process_frame
		setup()

# ========================================
# 主设置方法
# ========================================

func setup():
	"""执行完整的地图系统设置"""
	if is_setup_complete:
		print("[OfficeMapSetup] 已经完成设置,跳过重复初始化")
		return

	print("[OfficeMapSetup] ========================================")
	print("[OfficeMapSetup] 开始Office地图系统初始化...")
	print("[OfficeMapSetup] ========================================")

	# 1. 创建昼夜循环
	if enable_day_night_cycle:
		_setup_day_night_cycle()

	# 2. 创建窗户灯光系统
	if enable_window_lights:
		_setup_window_lights()

	# 3. 创建办公室天花板灯光
	if enable_office_lights:
		_setup_office_area_lights()

	# 4. 添加交互区域
	if enable_interaction_zones:
		_setup_interaction_zones()

	# 5. 配置相机边界
	if configure_camera_bounds:
		_configure_camera()

	is_setup_complete = true
	print("[OfficeMapSetup] ========================================")
	print("[OfficeMapSetup] Office地图系统初始化完成!")
	print("[OfficeMapSetup] ========================================")

# ========================================
# 昼夜循环设置
# ========================================

func _setup_day_night_cycle():
	"""创建昼夜循环系统"""
	# 检查是否已存在
	var existing = get_node_or_null("DayNightCycle")
	if existing:
		day_night_cycle = existing
		print("[OfficeMapSetup] 检测到现有DayNightCycle节点")
		return

	# 创建CanvasModulate节点
	day_night_cycle = CanvasModulate.new()
	day_night_cycle.name = "DayNightCycle"

	# 加载DayNightCycle脚本
	var script = load("res://script/world/DayNightCycle.gd")
	if script:
		day_night_cycle.set_script(script)
		day_night_cycle.enabled = true
		day_night_cycle.transition_duration = 2.0
		print("[OfficeMapSetup] ✓ 创建DayNightCycle节点")
	else:
		push_warning("[OfficeMapSetup] 无法加载DayNightCycle脚本")
		return

	# 添加到场景根节点
	add_child(day_night_cycle)
	day_night_cycle.owner = get_tree().edited_scene_root if Engine.is_editor_hint() else self

# ========================================
# 窗户灯光设置
# ========================================

func _setup_window_lights():
	"""创建窗户灯光系统"""
	# 检查是否已存在
	var existing = get_node_or_null("WindowLights")
	if existing:
		window_lights_system = existing
		print("[OfficeMapSetup] 检测到现有WindowLights节点")
		return

	# 创建WindowLights节点
	window_lights_system = Node2D.new()
	window_lights_system.name = "WindowLights"

	# 加载WindowLights脚本
	var script = load("res://script/world/WindowLights.gd")
	if script:
		window_lights_system.set_script(script)
		window_lights_system.enabled = true
		window_lights_system.auto_init_on_ready = true
		print("[OfficeMapSetup] ✓ 创建WindowLights系统节点")
	else:
		push_warning("[OfficeMapSetup] 无法加载WindowLights脚本")
		return

	add_child(window_lights_system)
	window_lights_system.owner = get_tree().edited_scene_root if Engine.is_editor_hint() else self

	# 创建Windows容器
	var windows_container = Node2D.new()
	windows_container.name = "Windows"
	window_lights_system.add_child(windows_container)
	windows_container.owner = get_tree().edited_scene_root if Engine.is_editor_hint() else self

	# 添加窗户灯光(办公室北侧窗户区域)
	# 位置基于Office.tscn的布局分析,北侧窗户大约在y=64-128范围
	var window_positions = [
		# 北侧窗户(上方墙壁)
		Vector2(720, 32),
		Vector2(800, 32),
		Vector2(880, 32),
		Vector2(960, 32),
		# HR办公室窗户
		Vector2(144, 32),
		Vector2(208, 32),
		# 老板办公室窗户
		Vector2(880, 448),
		Vector2(960, 448),
	]

	for i in range(window_positions.size()):
		var light = Light2D.new()
		light.name = "WindowLight%d" % (i + 1)
		light.position = window_positions[i]
		light.enabled = false
		light.energy = 0.8
		light.color = Color(1.0, 0.9, 0.7)  # 暖黄色
		light.texture_scale = 1.5
		light.blend_mode = Light2D.BLEND_MODE_ADD

		windows_container.add_child(light)
		light.owner = get_tree().edited_scene_root if Engine.is_editor_hint() else self
		light.add_to_group("window_lights")

	print("[OfficeMapSetup] ✓ 添加了 %d 个窗户灯光" % window_positions.size())

# ========================================
# 办公室天花板灯光设置
# ========================================

func _setup_office_area_lights():
	"""创建办公室天花板灯光"""
	# 检查是否已存在
	var existing = get_node_or_null("OfficeAreaLights")
	if existing:
		office_lights_system = existing
		print("[OfficeMapSetup] 检测到现有OfficeAreaLights节点")
		return

	# 创建容器
	office_lights_system = Node2D.new()
	office_lights_system.name = "OfficeAreaLights"
	add_child(office_lights_system)
	office_lights_system.owner = get_tree().edited_scene_root if Engine.is_editor_hint() else self

	# 办公室区域天花板灯光位置
	# 根据Office.tscn分析:办公室主要在(700-1000, 100-400)区域
	var ceiling_light_positions = [
		# 员工办公区域(南侧)
		Vector2(800, 320),
		Vector2(920, 320),
		# 员工办公区域(北侧)
		Vector2(800, 160),
		Vector2(920, 160),
		# HR办公室
		Vector2(160, 120),
		# 会议室
		Vector2(480, 520),
		# 老板办公室
		Vector2(920, 520),
		# 茶水间
		Vector2(480, 160),
		# 健身房
		Vector2(480, 320),
	]

	for i in range(ceiling_light_positions.size()):
		var light = Light2D.new()
		light.name = "CeilingLight%d" % (i + 1)
		light.position = ceiling_light_positions[i]
		light.enabled = true
		light.energy = 0.6
		light.color = Color(1.0, 0.98, 0.95)  # 办公室白色灯光
		light.texture_scale = 3.0
		light.blend_mode = Light2D.BLEND_MODE_ADD

		office_lights_system.add_child(light)
		light.owner = get_tree().edited_scene_root if Engine.is_editor_hint() else self

	print("[OfficeMapSetup] ✓ 添加了 %d 个天花板灯光" % ceiling_light_positions.size())

# ========================================
# 交互区域设置
# ========================================

func _setup_interaction_zones():
	"""创建交互区域"""
	# 检查是否已存在
	var existing = get_node_or_null("InteractionZones")
	if existing:
		interaction_zones_container = existing
		print("[OfficeMapSetup] 检测到现有InteractionZones节点")
		return

	# 创建容器
	interaction_zones_container = Node2D.new()
	interaction_zones_container.name = "InteractionZones"
	add_child(interaction_zones_container)
	interaction_zones_container.owner = get_tree().edited_scene_root if Engine.is_editor_hint() else self

	# 加载InteractionZone脚本
	var zone_script = load("res://script/world/InteractionZone.gd")
	if not zone_script:
		push_warning("[OfficeMapSetup] 无法加载InteractionZone脚本")
		return

	# 定义交互区域配置
	var zone_configs = [
		# 工位区域(员工办公区南侧)
		{
			"name": "WorkDesk_Joe",
			"position": Vector2(848, 360),
			"size": Vector2(60, 60),
			"type": "work"
		},
		{
			"name": "WorkDesk_Jack",
			"position": Vector2(752, 360),
			"size": Vector2(60, 60),
			"type": "work"
		},
		{
			"name": "WorkDesk_Alice",
			"position": Vector2(976, 360),
			"size": Vector2(60, 60),
			"type": "work"
		},
		# 工位区域(员工办公区北侧)
		{
			"name": "WorkDesk_North1",
			"position": Vector2(752, 136),
			"size": Vector2(60, 60),
			"type": "work"
		},
		{
			"name": "WorkDesk_North2",
			"position": Vector2(848, 136),
			"size": Vector2(60, 60),
			"type": "work"
		},
		{
			"name": "WorkDesk_North3",
			"position": Vector2(944, 136),
			"size": Vector2(60, 60),
			"type": "work"
		},
		# HR办公室
		{
			"name": "HRDesk",
			"position": Vector2(160, 120),
			"size": Vector2(100, 80),
			"type": "work"
		},
		# 会议室
		{
			"name": "MeetingRoom",
			"position": Vector2(480, 520),
			"size": Vector2(120, 100),
			"type": "talk"
		},
		# 老板办公室
		{
			"name": "BossDesk",
			"position": Vector2(920, 520),
			"size": Vector2(100, 80),
			"type": "work"
		},
		# 健身房
		{
			"name": "GymArea",
			"position": Vector2(480, 320),
			"size": Vector2(100, 120),
			"type": "rest"
		},
		# 茶水间
		{
			"name": "TeaRoom",
			"position": Vector2(480, 160),
			"size": Vector2(80, 60),
			"type": "rest"
		},
	]

	for config in zone_configs:
		var zone = Area2D.new()
		zone.name = config["name"]
		zone.set_script(zone_script)
		zone.position = config["position"]
		zone.zone_name = config["name"]
		zone.interaction_type = config["type"]
		zone.enabled = true
		zone.show_highlight_on_hover = true
		zone.cooldown_duration = 2.0

		# 创建CollisionShape2D
		var collision = CollisionShape2D.new()
		collision.name = "CollisionShape2D"
		var shape = RectangleShape2D.new()
		shape.size = config["size"]
		collision.shape = shape
		zone.add_child(collision)
		collision.owner = get_tree().edited_scene_root if Engine.is_editor_hint() else self

		interaction_zones_container.add_child(zone)
		zone.owner = get_tree().edited_scene_root if Engine.is_editor_hint() else self

	print("[OfficeMapSetup] ✓ 添加了 %d 个交互区域" % zone_configs.size())

# ========================================
# 相机配置
# ========================================

func _configure_camera():
	"""配置相机地图边界"""
	var camera = get_node_or_null("MainCamera")
	if not camera:
		push_warning("[OfficeMapSetup] 未找到MainCamera节点")
		return

	# Office地图大小分析:
	# 从TileMap数据看,地图范围大约是(0,0)到(1200, 600)
	# 使用32x32的Tile,地图大约是37x19 tiles
	camera.map_bounds = Rect2(0, 0, 1200, 600)

	# 设置缩放等级
	if camera.has_method("reset_camera"):
		camera.zoom_levels = [0.5, 0.75, 1.0, 1.5, 2.0]
		camera.current_zoom_index = 2  # 默认1.0倍

	print("[OfficeMapSetup] ✓ 配置相机边界: %s" % str(camera.map_bounds))

# ========================================
# 公共方法
# ========================================

func get_day_night_cycle() -> CanvasModulate:
	"""获取昼夜循环节点"""
	return day_night_cycle

func get_window_lights_system() -> Node2D:
	"""获取窗户灯光系统节点"""
	return window_lights_system

func get_office_lights_system() -> Node2D:
	"""获取办公室灯光系统节点"""
	return office_lights_system

func get_interaction_zones_container() -> Node2D:
	"""获取交互区域容器节点"""
	return interaction_zones_container

func is_setup_done() -> bool:
	"""检查是否完成设置"""
	return is_setup_complete

func reset_setup():
	"""重置设置状态(允许重新初始化)"""
	is_setup_complete = false

# ========================================
# 调试方法
# ========================================

func _get_configuration_warnings() -> PackedStringArray:
	"""编辑器配置警告"""
	var warnings: PackedStringArray = []

	if not ResourceLoader.exists("res://script/world/DayNightCycle.gd"):
		warnings.append("缺少DayNightCycle脚本")

	if not ResourceLoader.exists("res://script/world/WindowLights.gd"):
		warnings.append("缺少WindowLights脚本")

	if not ResourceLoader.exists("res://script/world/InteractionZone.gd"):
		warnings.append("缺少InteractionZone脚本")

	if not has_node("MainCamera"):
		warnings.append("场景中缺少MainCamera节点")

	return warnings
