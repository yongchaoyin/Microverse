# script/world/Building.gd
# 建筑基类 - 所有建筑物的基础类
# 管理建筑的入口、灯光、所有权等

extends StaticBody2D
class_name Building

## 建筑基类
##
## 功能:
## - 管理建筑入口和交互区域
## - 控制窗户灯光
## - 处理角色进入/离开建筑
## - 管理建筑所有权(如住宅)
## - 支持室内/室外场景切换
##
## 节点结构:
## Building (StaticBody2D)
## ├── Sprite2D (建筑外观)
## ├── CollisionShape2D (碰撞形状)
## ├── EntranceZone (InteractionZone) - 入口交互区域
## ├── Windows (Node2D) - 窗户灯光容器
## │   ├── WindowLight1 (Light2D)
## │   ├── WindowLight2 (Light2D)
## │   └── ...
## └── InteriorSpawn (Marker2D) - 室内场景生成点(可选)

# ========================================
# 导出变量
# ========================================

## 建筑名称
@export var building_name: String = "Building"

## 建筑类型
@export_enum("住宅:house", "办公室:office", "咖啡馆:cafe", "酒吧:bar", "商店:shop", "公共建筑:public")
var building_type: String = "house"

## 建筑所有者ID(如果是住宅)
@export var owner_id: String = ""

## 室内场景路径(如果有)
@export var interior_scene_path: String = ""

## 是否允许访客进入
@export var allow_visitors: bool = true

## 访问所需的最低关系等级(如果restrict_by_relationship=true)
@export var min_relationship_level: String = "acquaintance"

## 是否根据关系限制访问
@export var restrict_by_relationship: bool = true

## 访问时间限制(24小时制)
@export var access_hour_start: int = 8  # 早上8点
@export var access_hour_end: int = 22   # 晚上10点

## 是否启用窗户灯光
@export var enable_window_lights: bool = true

# ========================================
# 节点引用
# ========================================

@onready var sprite: Sprite2D = $Sprite2D if has_node("Sprite2D") else null
@onready var collision_shape: CollisionShape2D = $CollisionShape2D if has_node("CollisionShape2D") else null
@onready var entrance_zone: InteractionZone = $EntranceZone if has_node("EntranceZone") else null
@onready var windows_container: Node2D = $Windows if has_node("Windows") else null
@onready var interior_spawn: Marker2D = $InteriorSpawn if has_node("InteriorSpawn") else null

# ========================================
# 私有变量
# ========================================

# 窗户灯光列表
var window_lights: Array[Light2D] = []

# 当前在建筑内的角色
var characters_inside: Array = []

# TimeSystem引用
var time_system = null

# RelationshipManager引用
var relationship_manager = null

# ========================================
# 信号
# ========================================

## 角色进入建筑信号
signal character_entered_building(character: Node, building_name: String)

## 角色离开建筑信号
signal character_exited_building(character: Node, building_name: String)

## 建筑状态变化信号(开门/关门等)
signal building_state_changed(state: String)

# ========================================
# 生命周期方法
# ========================================

func _ready():
	"""初始化建筑"""
	# 添加到建筑组
	add_to_group("buildings")

	# 根据建筑类型添加到特定组
	match building_type:
		"house":
			add_to_group("houses")
		"office":
			add_to_group("offices")
		"cafe":
			add_to_group("cafes")
		"bar":
			add_to_group("bars")
		"shop":
			add_to_group("shops")
		"public":
			add_to_group("public_buildings")

	# 获取系统引用
	time_system = get_node_or_null("/root/TimeSystem")
	relationship_manager = get_node_or_null("/root/RelationshipManager")

	# 初始化入口区域
	if entrance_zone:
		entrance_zone.interaction_triggered.connect(_on_entrance_triggered)
		entrance_zone.zone_name = building_name + "_Entrance"
		entrance_zone.interaction_type = "enter"

	# 初始化窗户灯光
	if enable_window_lights:
		_initialize_window_lights()

	print("[Building] 建筑已初始化: %s (类型: %s)" % [building_name, building_type])

# ========================================
# 窗户灯光管理
# ========================================

func _initialize_window_lights():
	"""初始化窗户灯光"""
	window_lights.clear()

	if not windows_container:
		return

	# 收集所有Light2D子节点
	for child in windows_container.get_children():
		if child is Light2D:
			window_lights.append(child)
			child.add_to_group("window_lights")  # 添加到窗户灯光组
			child.enabled = false  # 默认关闭

	print("[Building] %s 已初始化 %d 个窗户灯光" % [building_name, window_lights.size()])

func add_window_light(light: Light2D):
	"""
	添加窗户灯光

	@param light: Light2D节点
	"""
	if light and light not in window_lights:
		window_lights.append(light)
		light.add_to_group("window_lights")

		if windows_container:
			windows_container.add_child(light)

func get_window_lights() -> Array[Light2D]:
	"""获取所有窗户灯光"""
	return window_lights

# ========================================
# 入口交互处理
# ========================================

func _on_entrance_triggered(zone_name: String, character: Node):
	"""
	入口区域触发

	@param zone_name: 区域名称
	@param character: 触发的角色
	"""
	var character_name = _get_character_name(character)

	print("[Building] %s 尝试进入 %s" % [character_name, building_name])

	# 检查是否允许进入
	if can_character_enter(character):
		enter_building(character)
	else:
		print("[Building] %s 无法进入 %s - 权限不足或时间不对" % [character_name, building_name])
		_show_access_denied_feedback(character)

func can_character_enter(character: Node) -> bool:
	"""
	检查角色是否可以进入建筑

	@param character: 角色节点
	@return: 是否可以进入
	"""
	var character_name = _get_character_name(character)
	var character_id = _get_character_id(character)

	# 1. 检查是否是所有者
	if not owner_id.is_empty() and character_id == owner_id:
		return true  # 所有者总是可以进入

	# 2. 检查是否允许访客
	if not allow_visitors:
		return false

	# 3. 检查时间限制
	if not _is_within_access_hours():
		return false

	# 4. 检查关系限制(如果启用)
	if restrict_by_relationship and not owner_id.is_empty():
		if not _check_relationship_requirement(character_id):
			return false

	# 5. 特殊建筑类型检查
	match building_type:
		"bar":
			# 酒吧只在晚上营业
			if time_system:
				var hour = time_system.current_hour
				if hour < 18 or hour >= 2:  # 18:00-2:00营业
					return false

		"office":
			# 办公室工作时间
			if time_system:
				var hour = time_system.current_hour
				if hour < 8 or hour >= 19:  # 8:00-19:00
					return false

	return true

func _is_within_access_hours() -> bool:
	"""检查当前是否在访问时间内"""
	if not time_system:
		return true  # 如果没有时间系统,默认允许

	var current_hour = time_system.current_hour

	# 处理跨午夜的情况(如22:00-8:00)
	if access_hour_start > access_hour_end:
		return current_hour >= access_hour_start or current_hour < access_hour_end
	else:
		return current_hour >= access_hour_start and current_hour < access_hour_end

func _check_relationship_requirement(character_id: String) -> bool:
	"""
	检查关系要求

	@param character_id: 角色ID
	@return: 是否满足关系要求
	"""
	if not relationship_manager or owner_id.is_empty():
		return true  # 如果没有关系系统或没有所有者,默认允许

	var relationship = relationship_manager.get_relationship(character_id, owner_id)
	if not relationship:
		return false

	# 关系等级排序(从低到高)
	var relationship_hierarchy = [
		"stranger",
		"acquaintance",
		"friend",
		"close_friend",
		"best_friend",
		"romantic"
	]

	var current_level = relationship.get("relationship_level", "stranger")
	var required_level = min_relationship_level

	var current_index = relationship_hierarchy.find(current_level)
	var required_index = relationship_hierarchy.find(required_level)

	if current_index == -1 or required_index == -1:
		return false

	return current_index >= required_index

# ========================================
# 进入/离开建筑
# ========================================

func enter_building(character: Node):
	"""
	角色进入建筑

	@param character: 角色节点
	"""
	var character_name = _get_character_name(character)

	# 添加到建筑内角色列表
	if character not in characters_inside:
		characters_inside.append(character)

	# 隐藏角色(进入室内)
	character.visible = false

	# 更新角色位置信息
	if character.has_meta("character_data"):
		var data = character.get_meta("character_data")
		if not data.has("current_data"):
			data["current_data"] = {}
		data["current_data"]["location"] = building_name
		data["current_data"]["is_indoor"] = true
		character.set_meta("character_data", data)

	# 发送进入信号
	character_entered_building.emit(character, building_name)

	print("[Building] %s 进入了 %s" % [character_name, building_name])

	# 加载室内场景(如果有)
	if not interior_scene_path.is_empty():
		_load_interior_scene(character)

func exit_building(character: Node):
	"""
	角色离开建筑

	@param character: 角色节点
	"""
	var character_name = _get_character_name(character)

	# 从建筑内角色列表移除
	if character in characters_inside:
		characters_inside.erase(character)

	# 显示角色(回到室外)
	character.visible = true

	# 更新角色位置(设置到出口位置)
	if entrance_zone:
		character.global_position = entrance_zone.global_position + Vector2(0, 32)  # 出口偏移

	# 更新角色数据
	if character.has_meta("character_data"):
		var data = character.get_meta("character_data")
		if data.has("current_data"):
			data["current_data"]["location"] = "Outdoor"
			data["current_data"]["is_indoor"] = false
			character.set_meta("character_data", data)

	# 发送离开信号
	character_exited_building.emit(character, building_name)

	print("[Building] %s 离开了 %s" % [character_name, building_name])

func _load_interior_scene(character: Node):
	"""
	加载室内场景

	@param character: 进入的角色
	"""
	# 这里是简化实现,实际应该使用SceneManager
	print("[Building] 加载室内场景: %s" % interior_scene_path)

	# 实际实现示例:
	# SceneManager.load_scene(interior_scene_path, {
	#     "character": character,
	#     "building": self
	# })

func _show_access_denied_feedback(character: Node):
	"""
	显示访问被拒绝的反馈

	@param character: 被拒绝的角色
	"""
	# 简单实现: 打印消息
	# 实际可以显示UI提示、播放音效等
	print("[Building] 访问被拒绝")

	# 可以添加视觉反馈,如门口出现X标记等

# ========================================
# 辅助方法
# ========================================

func _get_character_name(character: Node) -> String:
	"""获取角色名称"""
	if character.has_meta("character_data"):
		var data = character.get_meta("character_data")
		return data.get("character_name", character.name)
	return character.name

func _get_character_id(character: Node) -> String:
	"""获取角色ID"""
	if character.has_meta("character_data"):
		var data = character.get_meta("character_data")
		return data.get("id", "")
	return ""

# ========================================
# 公共方法
# ========================================

func get_characters_inside() -> Array:
	"""获取当前在建筑内的所有角色"""
	return characters_inside.duplicate()

func is_character_inside(character: Node) -> bool:
	"""
	检查角色是否在建筑内

	@param character: 角色节点
	@return: 是否在建筑内
	"""
	return character in characters_inside

func set_owner(new_owner_id: String):
	"""
	设置建筑所有者

	@param new_owner_id: 新所有者ID
	"""
	owner_id = new_owner_id
	print("[Building] %s 的新所有者: %s" % [building_name, owner_id])

func get_building_info() -> Dictionary:
	"""
	获取建筑信息

	@return: 建筑信息字典
	"""
	return {
		"name": building_name,
		"type": building_type,
		"owner_id": owner_id,
		"allow_visitors": allow_visitors,
		"characters_inside": characters_inside.size(),
		"has_interior_scene": not interior_scene_path.is_empty()
	}

# ========================================
# 调试方法
# ========================================

func _get_configuration_warnings() -> PackedStringArray:
	"""编辑器配置警告"""
	var warnings: PackedStringArray = []

	if not has_node("Sprite2D"):
		warnings.append("缺少Sprite2D子节点,建筑将不可见")

	if not has_node("CollisionShape2D"):
		warnings.append("缺少CollisionShape2D子节点,建筑将无碰撞")

	if not has_node("EntranceZone"):
		warnings.append("缺少EntranceZone子节点,角色无法进入建筑")

	if building_name == "Building":
		warnings.append("建议设置有意义的building_name")

	if building_type == "house" and owner_id.is_empty():
		warnings.append("住宅类型建筑建议设置owner_id")

	return warnings
