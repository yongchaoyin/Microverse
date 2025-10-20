# script/world/InteractionZone.gd
# 交互区域基类 - 定义可交互的区域(门口、工作位、座位等)
# AI角色进入区域后触发相应的交互行为

extends Area2D
class_name InteractionZone

## 交互区域基类
##
## 功能:
## - 检测AI角色进入/离开
## - 触发不同类型的交互(进入建筑、工作、坐下、对话)
## - 提供可视化高亮效果(鼠标悬停)
## - 支持启用/禁用
##
## 使用方法:
## 1. 创建Area2D节点,附加此脚本
## 2. 添加CollisionShape2D子节点定义交互范围
## 3. 设置zone_name和interaction_type
## 4. 连接interaction_triggered信号处理交互逻辑

# ========================================
# 导出变量
# ========================================

## 区域名称(用于标识)
@export var zone_name: String = "UnnamedZone"

## 交互类型
@export_enum("进入建筑:enter", "工作:work", "坐下:sit", "对话:talk", "休息:rest", "自定义:custom")
var interaction_type: String = "enter"

## 是否启用此交互区域
@export var enabled: bool = true

## 是否显示鼠标悬停高亮
@export var show_highlight_on_hover: bool = true

## 高亮颜色
@export var highlight_color: Color = Color(1.0, 1.0, 0.0, 0.3)  # 黄色半透明

## 是否只允许特定角色交互
@export var restrict_to_characters: bool = false

## 允许交互的角色名称列表
@export var allowed_characters: Array[String] = []

## 交互冷却时间(秒) - 防止频繁触发
@export var cooldown_duration: float = 1.0

# ========================================
# 节点引用
# ========================================

@onready var collision_shape: CollisionShape2D = $CollisionShape2D if has_node("CollisionShape2D") else null
@onready var highlight_sprite: Sprite2D = $HighlightSprite if has_node("HighlightSprite") else null

# ========================================
# 私有变量
# ========================================

# 当前在区域内的角色列表
var characters_in_zone: Array = []

# 冷却计时器
var cooldown_timer: float = 0.0

# 是否在冷却中
var is_in_cooldown: bool = false

# 高亮矩形(如果没有HighlightSprite)
var highlight_rect: ColorRect = null

# ========================================
# 信号
# ========================================

## 交互触发信号
## @param zone_name: 区域名称
## @param character: 触发交互的角色节点
signal interaction_triggered(zone_name: String, character: Node)

## 角色进入区域信号
signal character_entered(character: Node)

## 角色离开区域信号
signal character_exited(character: Node)

# ========================================
# 生命周期方法
# ========================================

func _ready():
	"""初始化交互区域"""
	# 设置碰撞层级
	collision_layer = 0  # 不与其他物体碰撞
	collision_mask = 2   # 只检测Layer 2(角色层)

	# 连接信号
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

	# 鼠标交互(仅在编辑器或调试时)
	if show_highlight_on_hover:
		mouse_entered.connect(_on_mouse_entered)
		mouse_exited.connect(_on_mouse_exited)

	# 初始化高亮
	_initialize_highlight()

	# 添加到交互区域组
	add_to_group("interaction_zones")

	print("[InteractionZone] 交互区域已创建: %s (类型: %s)" % [zone_name, interaction_type])

func _process(delta):
	"""更新冷却计时器"""
	if is_in_cooldown:
		cooldown_timer -= delta
		if cooldown_timer <= 0:
			is_in_cooldown = false

# ========================================
# 高亮效果
# ========================================

func _initialize_highlight():
	"""初始化高亮效果"""
	if highlight_sprite:
		highlight_sprite.visible = false
		highlight_sprite.modulate = highlight_color
	else:
		# 如果没有HighlightSprite,创建一个简单的ColorRect
		if collision_shape and collision_shape.shape:
			_create_highlight_rect()

func _create_highlight_rect():
	"""创建高亮矩形"""
	highlight_rect = ColorRect.new()
	highlight_rect.name = "HighlightRect"
	highlight_rect.color = highlight_color
	highlight_rect.visible = false
	highlight_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# 根据CollisionShape设置大小
	if collision_shape.shape is RectangleShape2D:
		var rect_shape = collision_shape.shape as RectangleShape2D
		highlight_rect.size = rect_shape.size
		highlight_rect.position = collision_shape.position - rect_shape.size / 2

	elif collision_shape.shape is CircleShape2D:
		var circle_shape = collision_shape.shape as CircleShape2D
		var diameter = circle_shape.radius * 2
		highlight_rect.size = Vector2(diameter, diameter)
		highlight_rect.position = collision_shape.position - Vector2(circle_shape.radius, circle_shape.radius)

	add_child(highlight_rect)

func _on_mouse_entered():
	"""鼠标进入区域"""
	if not enabled:
		return

	if highlight_sprite:
		highlight_sprite.visible = true
	elif highlight_rect:
		highlight_rect.visible = true

func _on_mouse_exited():
	"""鼠标离开区域"""
	if highlight_sprite:
		highlight_sprite.visible = false
	elif highlight_rect:
		highlight_rect.visible = false

# ========================================
# 角色检测
# ========================================

func _on_body_entered(body: Node):
	"""
	物体进入区域

	@param body: 进入的物体节点
	"""
	# 检查是否是AI角色
	if not _is_ai_character(body):
		return

	# 检查是否在允许列表中
	if restrict_to_characters and not _is_character_allowed(body):
		return

	# 添加到区域内角色列表
	if body not in characters_in_zone:
		characters_in_zone.append(body)

	# 发送进入信号
	character_entered.emit(body)

	# 触发交互(如果启用且不在冷却中)
	if enabled and not is_in_cooldown:
		_trigger_interaction(body)

func _on_body_exited(body: Node):
	"""
	物体离开区域

	@param body: 离开的物体节点
	"""
	if not _is_ai_character(body):
		return

	# 从区域内角色列表移除
	if body in characters_in_zone:
		characters_in_zone.erase(body)

	# 发送离开信号
	character_exited.emit(body)

func _is_ai_character(node: Node) -> bool:
	"""
	检查节点是否是AI角色

	@param node: 要检查的节点
	@return: 是否是AI角色
	"""
	# 方法1: 检查是否在characters组
	if node.is_in_group("characters"):
		return true

	# 方法2: 检查类型(如果有AICharacter类)
	# if node is AICharacter:
	#     return true

	# 方法3: 检查是否有character_data元数据
	if node.has_meta("character_data"):
		return true

	return false

func _is_character_allowed(character: Node) -> bool:
	"""
	检查角色是否允许交互

	@param character: 角色节点
	@return: 是否允许
	"""
	if allowed_characters.is_empty():
		return true

	# 获取角色名称
	var character_name = ""
	if character.has_meta("character_data"):
		var data = character.get_meta("character_data")
		character_name = data.get("character_name", "")
	else:
		character_name = character.name

	return character_name in allowed_characters

# ========================================
# 交互触发
# ========================================

func _trigger_interaction(character: Node):
	"""
	触发交互

	@param character: 触发交互的角色
	"""
	print("[InteractionZone] %s 触发交互: %s (类型: %s)" % [
		_get_character_name(character),
		zone_name,
		interaction_type
	])

	# 发送交互信号
	interaction_triggered.emit(zone_name, character)

	# 执行特定类型的交互
	match interaction_type:
		"enter":
			_handle_enter_interaction(character)
		"work":
			_handle_work_interaction(character)
		"sit":
			_handle_sit_interaction(character)
		"talk":
			_handle_talk_interaction(character)
		"rest":
			_handle_rest_interaction(character)
		"custom":
			_handle_custom_interaction(character)

	# 启动冷却
	_start_cooldown()

func _handle_enter_interaction(character: Node):
	"""
	处理进入建筑交互

	@param character: 角色节点
	"""
	print("[InteractionZone] %s 进入建筑: %s" % [_get_character_name(character), zone_name])

	# 实际的进入建筑逻辑由Building类处理
	# 这里只是触发信号

func _handle_work_interaction(character: Node):
	"""
	处理工作交互

	@param character: 角色节点
	"""
	print("[InteractionZone] %s 开始工作于: %s" % [_get_character_name(character), zone_name])

	# 播放工作动画(如果角色有此方法)
	if character.has_method("play_action"):
		character.play_action("work")

	# 通知任务系统
	# EventBus.emit_signal("work_started", character)

func _handle_sit_interaction(character: Node):
	"""
	处理坐下交互

	@param character: 角色节点
	"""
	print("[InteractionZone] %s 坐下于: %s" % [_get_character_name(character), zone_name])

	# 播放坐下动画
	if character.has_method("play_action"):
		character.play_action("sit")

func _handle_talk_interaction(character: Node):
	"""
	处理对话交互

	@param character: 角色节点
	"""
	# 检查是否有其他AI在附近
	for other in characters_in_zone:
		if other != character and _is_ai_character(other):
			print("[InteractionZone] %s 和 %s 在 %s 开始对话" % [
				_get_character_name(character),
				_get_character_name(other),
				zone_name
			])

			# 触发对话事件
			# EventBus.emit_signal("ai_dialogue_started", character, other)
			break

func _handle_rest_interaction(character: Node):
	"""
	处理休息交互

	@param character: 角色节点
	"""
	print("[InteractionZone] %s 在 %s 休息" % [_get_character_name(character), zone_name])

	# 播放休息动画
	if character.has_method("play_action"):
		character.play_action("idle")

func _handle_custom_interaction(character: Node):
	"""
	处理自定义交互(由外部脚本连接信号处理)

	@param character: 角色节点
	"""
	# 只发送信号,不做具体处理
	pass

# ========================================
# 冷却管理
# ========================================

func _start_cooldown():
	"""启动冷却"""
	is_in_cooldown = true
	cooldown_timer = cooldown_duration

# ========================================
# 辅助方法
# ========================================

func _get_character_name(character: Node) -> String:
	"""
	获取角色名称

	@param character: 角色节点
	@return: 角色名称
	"""
	if character.has_meta("character_data"):
		var data = character.get_meta("character_data")
		return data.get("character_name", character.name)
	return character.name

# ========================================
# 公共方法
# ========================================

func set_enabled(is_enabled: bool):
	"""
	启用/禁用交互区域

	@param is_enabled: 是否启用
	"""
	enabled = is_enabled

	if not enabled:
		# 禁用时清空区域内角色列表
		characters_in_zone.clear()

func get_characters_in_zone() -> Array:
	"""获取当前在区域内的所有角色"""
	return characters_in_zone.duplicate()

func is_character_in_zone(character: Node) -> bool:
	"""
	检查指定角色是否在区域内

	@param character: 角色节点
	@return: 是否在区域内
	"""
	return character in characters_in_zone

func force_trigger_interaction(character: Node):
	"""
	强制触发交互(忽略冷却)

	@param character: 角色节点
	"""
	if enabled and _is_ai_character(character):
		_trigger_interaction(character)

# ========================================
# 调试方法
# ========================================

func _get_configuration_warnings() -> PackedStringArray:
	"""编辑器配置警告"""
	var warnings: PackedStringArray = []

	if not has_node("CollisionShape2D"):
		warnings.append("缺少CollisionShape2D子节点,交互区域将无法工作")

	if zone_name == "UnnamedZone":
		warnings.append("建议设置有意义的zone_name")

	return warnings
