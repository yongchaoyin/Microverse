# script/world/DayNightCycle.gd
# 昼夜循环系统 - 控制全局光照颜色模拟昼夜变化
# 基于TimeSystem的时间变化,平滑过渡不同时段的光照颜色

extends CanvasModulate
class_name DayNightCycle

## 昼夜循环系统
##
## 功能:
## - 根据TimeSystem的时间自动调整全局光照颜色
## - 平滑过渡不同时段(黎明、早晨、正午、下午、黄昏、傍晚、夜晚)
## - 触发昼夜事件(用于控制灯光开关)
## - 支持自定义颜色预设
##
## 使用方法:
## 1. 将此脚本附加到场景中的CanvasModulate节点
## 2. 系统会自动连接TimeSystem的hour_changed信号
## 3. 可通过Inspector调整颜色预设

# ========================================
# 导出变量 (可在Inspector中调整)
# ========================================

## 是否启用昼夜循环
@export var enabled: bool = true

## 颜色过渡时间(秒) - 每小时颜色变化的过渡时长
@export var transition_duration: float = 30.0

## 是否在启动时立即更新光照(否则等待下一次hour_changed)
@export var update_on_ready: bool = true

## 自定义颜色预设(如果不设置,使用默认预设)
@export_group("Color Presets")
@export var custom_dawn: Color = Color.TRANSPARENT  # 黎明(5:00-6:59)
@export var custom_morning: Color = Color.TRANSPARENT  # 早晨(7:00-10:59)
@export var custom_noon: Color = Color.TRANSPARENT  # 正午(11:00-14:59)
@export var custom_afternoon: Color = Color.TRANSPARENT  # 下午(15:00-17:59)
@export var custom_dusk: Color = Color.TRANSPARENT  # 黄昏(18:00-19:59)
@export var custom_evening: Color = Color.TRANSPARENT  # 傍晚(20:00-21:59)
@export var custom_night: Color = Color.TRANSPARENT  # 夜晚(22:00-4:59)

# ========================================
# 私有变量
# ========================================

# 当前小时
var current_hour: int = 6

# 默认颜色预设(现代小镇温馨风格)
var default_color_presets = {
	"dawn": Color(1.0, 0.88, 0.75),     # 黎明(柔和橙黄)
	"morning": Color(1.0, 0.97, 0.92),  # 早晨(明亮温暖)
	"noon": Color(1.0, 1.0, 1.0),       # 正午(纯白)
	"afternoon": Color(1.0, 0.98, 0.95),# 下午(微暖)
	"dusk": Color(1.0, 0.75, 0.6),      # 黄昏(温暖橙)
	"evening": Color(0.75, 0.7, 0.85),  # 傍晚(淡紫蓝)
	"night": Color(0.3, 0.35, 0.5)      # 夜晚(柔和深蓝)
}

# 实际使用的颜色预设(合并默认和自定义)
var color_presets: Dictionary = {}

# 当前正在进行的颜色过渡Tween
var current_tween: Tween = null

# TimeSystem引用
var time_system = null

# ========================================
# 信号
# ========================================

## 昼夜时段变化信号
signal time_period_changed(period: String)

## 夜晚开始信号(19:00)
signal night_time_start()

## 白天开始信号(6:00)
signal day_time_start()

# ========================================
# 生命周期方法
# ========================================

func _ready():
	"""初始化昼夜循环系统"""
	# 初始化颜色预设
	_initialize_color_presets()

	# 获取TimeSystem引用
	time_system = get_node_or_null("/root/TimeSystem")

	if time_system:
		# 连接时间系统信号
		if not time_system.is_connected("hour_changed", _on_hour_changed):
			time_system.connect("hour_changed", _on_hour_changed)

		# 获取当前时间
		current_hour = time_system.current_hour

		# 启动时立即更新
		if update_on_ready:
			update_lighting(false)  # 不使用过渡

		print("[DayNightCycle] 昼夜循环系统已启动 - 当前时间: %d:00" % current_hour)
	else:
		push_warning("[DayNightCycle] 未找到TimeSystem,使用默认时间6:00")
		current_hour = 6
		if update_on_ready:
			update_lighting(false)

# ========================================
# 颜色预设管理
# ========================================

func _initialize_color_presets():
	"""初始化颜色预设(合并默认和自定义)"""
	# 从默认预设开始
	color_presets = default_color_presets.duplicate()

	# 覆盖自定义颜色(如果设置了)
	if custom_dawn.a > 0:
		color_presets["dawn"] = custom_dawn
	if custom_morning.a > 0:
		color_presets["morning"] = custom_morning
	if custom_noon.a > 0:
		color_presets["noon"] = custom_noon
	if custom_afternoon.a > 0:
		color_presets["afternoon"] = custom_afternoon
	if custom_dusk.a > 0:
		color_presets["dusk"] = custom_dusk
	if custom_evening.a > 0:
		color_presets["evening"] = custom_evening
	if custom_night.a > 0:
		color_presets["night"] = custom_night

func get_color_preset(preset_name: String) -> Color:
	"""获取颜色预设"""
	return color_presets.get(preset_name, Color.WHITE)

func set_color_preset(preset_name: String, new_color: Color):
	"""设置颜色预设"""
	color_presets[preset_name] = new_color

# ========================================
# 时间事件处理
# ========================================

func _on_hour_changed(hour: int):
	"""时间变化回调"""
	if not enabled:
		return

	current_hour = hour
	update_lighting(true)  # 使用平滑过渡

	# 触发特殊事件
	_trigger_special_events(hour)

func _trigger_special_events(hour: int):
	"""触发特殊时间事件"""
	match hour:
		19:  # 19:00 - 夜晚开始,开灯
			print("[DayNightCycle] 夜晚降临,灯光点亮 (19:00)")
			night_time_start.emit()

		6:   # 6:00 - 白天开始,关灯
			print("[DayNightCycle] 黎明到来,灯光熄灭 (6:00)")
			day_time_start.emit()

# ========================================
# 光照更新
# ========================================

func update_lighting(use_transition: bool = true):
	"""
	根据当前时间更新光照

	@param use_transition: 是否使用平滑过渡
	"""
	if not enabled:
		return

	var target_color: Color = _get_color_for_hour(current_hour)
	var period: String = _get_period_for_hour(current_hour)

	# 发送时段变化信号
	time_period_changed.emit(period)

	# 应用颜色
	if use_transition and transition_duration > 0:
		_transition_to_color(target_color)
	else:
		color = target_color

func _get_color_for_hour(hour: int) -> Color:
	"""
	根据小时获取对应的光照颜色

	@param hour: 小时(0-23)
	@return: 光照颜色
	"""
	match hour:
		5, 6:  # 黎明 5:00-6:59
			return color_presets.dawn
		7, 8, 9, 10:  # 早晨 7:00-10:59
			return color_presets.morning
		11, 12, 13, 14:  # 正午 11:00-14:59
			return color_presets.noon
		15, 16, 17:  # 下午 15:00-17:59
			return color_presets.afternoon
		18, 19:  # 黄昏 18:00-19:59
			return color_presets.dusk
		20, 21:  # 傍晚 20:00-21:59
			return color_presets.evening
		_:  # 夜晚 22:00-4:59
			return color_presets.night

func _get_period_for_hour(hour: int) -> String:
	"""
	根据小时获取时段名称

	@param hour: 小时(0-23)
	@return: 时段名称
	"""
	match hour:
		5, 6:
			return "dawn"
		7, 8, 9, 10:
			return "morning"
		11, 12, 13, 14:
			return "noon"
		15, 16, 17:
			return "afternoon"
		18, 19:
			return "dusk"
		20, 21:
			return "evening"
		_:
			return "night"

func _transition_to_color(target_color: Color):
	"""
	平滑过渡到目标颜色

	@param target_color: 目标颜色
	"""
	# 停止当前过渡
	if current_tween and current_tween.is_valid():
		current_tween.kill()

	# 创建新的过渡
	current_tween = create_tween()
	current_tween.set_ease(Tween.EASE_IN_OUT)
	current_tween.set_trans(Tween.TRANS_SINE)
	current_tween.tween_property(self, "color", target_color, transition_duration)

# ========================================
# 公共方法
# ========================================

func set_enabled(is_enabled: bool):
	"""
	启用/禁用昼夜循环

	@param is_enabled: 是否启用
	"""
	enabled = is_enabled

	if enabled:
		update_lighting(true)
	else:
		# 禁用时恢复纯白光照
		color = Color.WHITE

func force_time_period(period: String, use_transition: bool = true):
	"""
	强制设置时段(用于测试或特殊效果)

	@param period: 时段名称(dawn/morning/noon/afternoon/dusk/evening/night)
	@param use_transition: 是否使用过渡
	"""
	if not color_presets.has(period):
		push_error("[DayNightCycle] 无效的时段名称: %s" % period)
		return

	var target_color = color_presets[period]

	if use_transition:
		_transition_to_color(target_color)
	else:
		color = target_color

	time_period_changed.emit(period)
	print("[DayNightCycle] 强制切换到时段: %s" % period)

func get_current_period() -> String:
	"""获取当前时段"""
	return _get_period_for_hour(current_hour)

func get_current_color() -> Color:
	"""获取当前光照颜色"""
	return color

# ========================================
# 调试方法
# ========================================

func _get_configuration_warnings() -> PackedStringArray:
	"""编辑器配置警告"""
	var warnings: PackedStringArray = []

	if not get_node_or_null("/root/TimeSystem"):
		warnings.append("未找到TimeSystem Autoload,昼夜循环可能无法正常工作")

	return warnings
