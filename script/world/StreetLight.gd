# script/world/StreetLight.gd
# 单个路灯节点 - 路灯场景的控制脚本
# 控制路灯的开关、光晕效果

extends Node2D
class_name StreetLight

## 单个路灯节点
##
## 功能:
## - 控制路灯的开启/关闭
## - 管理光晕效果
## - 可选的闪烁动画
##
## 节点结构:
## StreetLight (Node2D)
## ├── Sprite2D (路灯杆sprite)
## ├── Light2D (光源)
## └── GlowSprite (光晕sprite,可选)

# ========================================
# 导出变量
# ========================================

## 路灯类型
@export_enum("复古路灯", "现代路灯", "公园灯") var light_type: int = 0

## 光照颜色
@export var light_color: Color = Color(1.0, 0.9, 0.7)  # 暖黄色

## 光照范围(像素)
@export var light_range: float = 64.0

## 光照能量
@export var light_energy: float = 1.0

## 是否在启动时开启
@export var start_enabled: bool = false

# ========================================
# 节点引用
# ========================================

@onready var sprite: Sprite2D = $Sprite2D if has_node("Sprite2D") else null
@onready var light: Light2D = $Light2D if has_node("Light2D") else null
@onready var glow_sprite: Sprite2D = $GlowSprite if has_node("GlowSprite") else null

# ========================================
# 私有变量
# ========================================

# 路灯是否开启
var is_on: bool = false

# 闪烁Tween
var flicker_tween: Tween = null

# ========================================
# 生命周期方法
# ========================================

func _ready():
	"""初始化路灯"""
	# 添加到路灯组
	add_to_group("street_lights")

	# 初始化Light2D
	if light:
		light.color = light_color
		light.texture_scale = light_range / 64.0  # 假设默认贴图是64像素
		light.energy = light_energy
		light.enabled = start_enabled
	else:
		# 如果没有Light2D子节点,创建一个
		_create_light2d()

	# 初始化光晕
	if glow_sprite:
		glow_sprite.modulate = light_color
		glow_sprite.visible = start_enabled
	else:
		# 如果没有光晕sprite,创建一个简单的
		_create_glow_sprite()

	# 设置初始状态
	is_on = start_enabled
	if not is_on:
		turn_off()

func _create_light2d():
	"""创建Light2D节点(如果不存在)"""
	light = Light2D.new()
	light.name = "Light2D"
	light.color = light_color
	light.energy = light_energy
	light.texture_scale = light_range / 64.0
	light.enabled = false

	# 使用默认纹理(圆形光照)
	# 如果有自定义光照纹理,可以在这里加载
	# light.texture = load("res://assets/textures/light_radial.png")

	add_child(light)
	print("[StreetLight] 自动创建Light2D节点")

func _create_glow_sprite():
	"""创建光晕Sprite(如果不存在)"""
	glow_sprite = Sprite2D.new()
	glow_sprite.name = "GlowSprite"
	glow_sprite.modulate = light_color
	glow_sprite.visible = false

	# 使用简单的圆形纹理作为光晕
	# 实际项目中应该加载光晕贴图
	# glow_sprite.texture = load("res://assets/textures/light_glow.png")

	add_child(glow_sprite)

# ========================================
# 路灯控制
# ========================================

func turn_on():
	"""开启路灯"""
	if is_on:
		return

	is_on = true

	# 启用光源
	if light:
		light.enabled = true

		# 渐变开启
		var tween = create_tween()
		tween.tween_property(light, "energy", light_energy, 0.3)

	# 显示光晕
	if glow_sprite:
		glow_sprite.visible = true

		# 光晕淡入
		glow_sprite.modulate.a = 0.0
		var tween = create_tween()
		tween.tween_property(glow_sprite, "modulate:a", 1.0, 0.3)

func turn_off():
	"""关闭路灯"""
	if not is_on:
		return

	is_on = false

	# 停止闪烁
	if flicker_tween and flicker_tween.is_valid():
		flicker_tween.kill()

	# 渐变关闭光源
	if light:
		var tween = create_tween()
		tween.tween_property(light, "energy", 0.0, 0.3)
		tween.finished.connect(func():
			if light:
				light.enabled = false
		)

	# 隐藏光晕
	if glow_sprite:
		var tween = create_tween()
		tween.tween_property(glow_sprite, "modulate:a", 0.0, 0.3)
		tween.finished.connect(func():
			if glow_sprite:
				glow_sprite.visible = false
		)

func toggle():
	"""切换路灯状态"""
	if is_on:
		turn_off()
	else:
		turn_on()

# ========================================
# 特效
# ========================================

func start_flicker():
	"""启动闪烁效果(循环)"""
	if not is_on or not light:
		return

	# 停止现有闪烁
	if flicker_tween and flicker_tween.is_valid():
		flicker_tween.kill()

	# 创建循环闪烁
	flicker_tween = create_tween()
	flicker_tween.set_loops()

	# 降低亮度
	flicker_tween.tween_property(light, "energy", light_energy * 0.9, 1.0)
	# 提高亮度
	flicker_tween.tween_property(light, "energy", light_energy * 1.1, 1.0)

func stop_flicker():
	"""停止闪烁效果"""
	if flicker_tween and flicker_tween.is_valid():
		flicker_tween.kill()

	# 恢复正常亮度
	if light:
		light.energy = light_energy

# ========================================
# 属性设置
# ========================================

func set_light_color(new_color: Color):
	"""
	设置光照颜色

	@param new_color: 新颜色
	"""
	light_color = new_color

	if light:
		light.color = new_color

	if glow_sprite:
		glow_sprite.modulate = new_color

func set_light_range(new_range: float):
	"""
	设置光照范围

	@param new_range: 新范围(像素)
	"""
	light_range = new_range

	if light:
		light.texture_scale = new_range / 64.0

func set_light_energy(new_energy: float):
	"""
	设置光照能量

	@param new_energy: 新能量值
	"""
	light_energy = new_energy

	if light and is_on:
		light.energy = new_energy

# ========================================
# 查询方法
# ========================================

func is_light_on() -> bool:
	"""路灯是否开启"""
	return is_on

func get_light_node() -> Light2D:
	"""获取Light2D节点"""
	return light

# ========================================
# 调试
# ========================================

func _get_configuration_warnings() -> PackedStringArray:
	"""编辑器配置警告"""
	var warnings: PackedStringArray = []

	if not has_node("Light2D"):
		warnings.append("缺少Light2D子节点,将自动创建")

	return warnings
