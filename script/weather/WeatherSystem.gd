extends Node

# ========================================
# WeatherSystem - 天气系统
# ========================================
#
# 功能:
# - 季节性天气变化
# - 天气对AI心情和效率的影响
# - 天气可视化和音效
# - 与TimeSystem集成
#
# ========================================

# 天气类型枚举
enum WeatherType {
	SUNNY,      # 晴朗
	RAINY,      # 下雨
	CLOUDY,     # 多云
	FOGGY,      # 有雾
	SNOWY,      # 下雪
	STORMY      # 暴风雨
}

# 系统引用
var _time_system = null
var _event_bus = null

# 天气数据
var _weather_config: Dictionary = {}
var _current_weather: WeatherType = WeatherType.SUNNY
var _temperature: float = 20.0
var _humidity: float = 60.0
var _wind_speed: float = 5.0

# 天气持续时间
var _weather_start_time: float = 0.0
var _weather_duration: float = 3600.0  # 默认1小时
var _next_weather: WeatherType = WeatherType.CLOUDY

# 信号
signal weather_changed(old_weather: String, new_weather: String)
signal temperature_changed(new_temp: float)
signal extreme_weather_started(weather_type: String)
signal weather_ended(weather_type: String)

func _ready():
	"""初始化天气系统"""
	# 加载配置
	_load_weather_config()

	# 获取系统引用
	_time_system = get_node_or_null("/root/TimeSystem")
	_event_bus = get_node_or_null("/root/EventBus")

	# 连接时间系统信号
	if _time_system:
		if _time_system.has_signal("hour_changed"):
			_time_system.hour_changed.connect(_on_hour_changed)
		if _time_system.has_signal("season_changed"):
			_time_system.season_changed.connect(_on_season_changed)

	# 初始化天气
	_initialize_weather()

	print("[WeatherSystem] 天气系统初始化完成")

func _load_weather_config():
	"""加载天气配置"""
	var config_path = "res://data/weather/weather_tables.json"

	if FileAccess.file_exists(config_path):
		var file = FileAccess.open(config_path, FileAccess.READ)
		if file:
			var json_text = file.get_as_text()
			file.close()

			var json = JSON.new()
			var parse_result = json.parse(json_text)

			if parse_result == OK:
				_weather_config = json.data
				print("[WeatherSystem] 天气配置加载成功")
			else:
				push_error("[WeatherSystem] JSON解析失败: %s" % json.get_error_message())
				_use_default_config()
		else:
			push_error("[WeatherSystem] 无法打开配置文件")
			_use_default_config()
	else:
		push_warning("[WeatherSystem] 配置文件不存在,使用默认配置")
		_use_default_config()

func _use_default_config():
	"""使用默认配置"""
	_weather_config = {
		"seasonal_probabilities": {
			"春季": {"SUNNY": 0.4, "RAINY": 0.3, "CLOUDY": 0.2, "FOGGY": 0.1},
			"夏季": {"SUNNY": 0.6, "RAINY": 0.15, "CLOUDY": 0.15, "STORMY": 0.1},
			"秋季": {"CLOUDY": 0.4, "RAINY": 0.3, "SUNNY": 0.2, "FOGGY": 0.1},
			"冬季": {"SNOWY": 0.4, "CLOUDY": 0.3, "SUNNY": 0.2, "FOGGY": 0.1}
		},
		"temperature_ranges": {
			"春季": {"min": 10, "max": 25},
			"夏季": {"min": 25, "max": 35},
			"秋季": {"min": 5, "max": 20},
			"冬季": {"min": -5, "max": 10}
		},
		"mood_modifiers": {
			"SUNNY": 5, "RAINY": -3, "CLOUDY": -1,
			"FOGGY": -2, "SNOWY": -2, "STORMY": -10
		},
		"work_efficiency_modifiers": {
			"SUNNY": 1.1, "RAINY": 0.95, "CLOUDY": 1.0,
			"FOGGY": 0.9, "SNOWY": 0.9, "STORMY": 0.8
		}
	}

func _initialize_weather():
	"""初始化天气状态"""
	_weather_start_time = _get_current_timestamp()

	# 根据当前季节随机选择天气
	var season = _get_current_season()
	_current_weather = _select_random_weather(season)
	_temperature = _generate_temperature(season)

	# 设置天气持续时间
	_weather_duration = _generate_weather_duration(_current_weather)

	# 预测下一个天气
	_next_weather = _select_random_weather(season)

	print("[WeatherSystem] 初始天气: %s, 温度: %.1f°C, 持续: %.1f小时" % [
		_get_weather_name(_current_weather),
		_temperature,
		_weather_duration / 3600.0
	])

func _on_hour_changed(year: int, season: String, day: int, hour: int):
	"""每小时检查天气变化

	Args:
		year: 年份
		season: 季节
		day: 天数
		hour: 小时
	"""
	# 检查是否需要更换天气
	var current_time = _get_current_timestamp()
	var elapsed_time = current_time - _weather_start_time

	if elapsed_time >= _weather_duration:
		_change_to_next_weather()

func _on_season_changed(year: int, new_season: String):
	"""季节变化时调整天气

	Args:
		year: 年份
		new_season: 新季节
	"""
	print("[WeatherSystem] 季节变化: %s, 重新生成天气" % new_season)

	# 立即切换到适合新季节的天气
	var new_weather = _select_random_weather(new_season)
	change_weather(new_weather)

	# 调整温度
	_temperature = _generate_temperature(new_season)
	temperature_changed.emit(_temperature)

func _change_to_next_weather():
	"""切换到下一个天气"""
	var old_weather = _current_weather
	_current_weather = _next_weather

	# 更新时间
	_weather_start_time = _get_current_timestamp()
	_weather_duration = _generate_weather_duration(_current_weather)

	# 预测下一个天气
	var season = _get_current_season()
	_next_weather = _select_random_weather(season)

	# 调整温度
	var temp_change = randf_range(-3.0, 3.0)
	_temperature = clamp(_temperature + temp_change, -10.0, 40.0)

	# 发送信号
	weather_changed.emit(_get_weather_name(old_weather), _get_weather_name(_current_weather))

	# 检查极端天气
	if _current_weather == WeatherType.STORMY:
		extreme_weather_started.emit("STORMY")

	# 发送事件
	if _event_bus:
		_event_bus.emit_event("weather_changed", {
			"old_weather": _get_weather_name(old_weather),
			"new_weather": _get_weather_name(_current_weather),
			"temperature": _temperature
		})

	print("[WeatherSystem] 天气变化: %s -> %s (温度: %.1f°C, 持续: %.1f小时)" % [
		_get_weather_name(old_weather),
		_get_weather_name(_current_weather),
		_temperature,
		_weather_duration / 3600.0
	])

# ========================================
# 公共API
# ========================================

func get_current_weather() -> Dictionary:
	"""获取当前天气信息

	Returns:
		天气数据字典
	"""
	return {
		"weather_type": _get_weather_name(_current_weather),
		"weather_enum": _current_weather,
		"temperature": _temperature,
		"humidity": _humidity,
		"wind_speed": _wind_speed,
		"description": get_weather_description(),
		"mood_modifier": get_mood_modifier(),
		"efficiency_modifier": get_work_efficiency_modifier(),
		"start_time": _weather_start_time,
		"duration": _weather_duration,
		"next_weather": _get_weather_name(_next_weather)
	}

func change_weather(new_weather: WeatherType, duration: float = -1.0):
	"""手动更改天气

	Args:
		new_weather: 新天气类型
		duration: 持续时间(秒), -1表示使用默认值
	"""
	var old_weather = _current_weather
	_current_weather = new_weather
	_weather_start_time = _get_current_timestamp()

	if duration > 0:
		_weather_duration = duration
	else:
		_weather_duration = _generate_weather_duration(new_weather)

	# 发送信号
	weather_changed.emit(_get_weather_name(old_weather), _get_weather_name(new_weather))

	print("[WeatherSystem] 手动切换天气: %s -> %s" % [
		_get_weather_name(old_weather),
		_get_weather_name(new_weather)
	])

func get_weather_description() -> String:
	"""获取天气描述

	Returns:
		天气描述文字
	"""
	var weather_name = _get_weather_name(_current_weather)
	var descriptions = _weather_config.get("weather_descriptions", {})

	if descriptions.has(weather_name):
		return descriptions[weather_name].get("description", "天气晴朗")

	# 默认描述
	match _current_weather:
		WeatherType.SUNNY: return "阳光明媚，天空万里无云"
		WeatherType.RAINY: return "淅淅沥沥的雨声，空气湿润"
		WeatherType.CLOUDY: return "云层密布，天色阴沉"
		WeatherType.FOGGY: return "大雾弥漫，能见度低"
		WeatherType.SNOWY: return "雪花飘飘，银装素裹"
		WeatherType.STORMY: return "狂风暴雨，雷电交加"

	return "天气状况未知"

func get_mood_modifier() -> int:
	"""获取天气对心情的影响值

	Returns:
		心情修正值
	"""
	var weather_name = _get_weather_name(_current_weather)
	var modifiers = _weather_config.get("mood_modifiers", {})

	return modifiers.get(weather_name, 0)

func get_work_efficiency_modifier() -> float:
	"""获取天气对工作效率的影响系数

	Returns:
		效率系数 (1.0为基准)
	"""
	var weather_name = _get_weather_name(_current_weather)
	var modifiers = _weather_config.get("work_efficiency_modifiers", {})

	return modifiers.get(weather_name, 1.0)

func is_raining() -> bool:
	"""检查是否下雨

	Returns:
		true表示正在下雨
	"""
	return _current_weather == WeatherType.RAINY

func is_snowing() -> bool:
	"""检查是否下雪

	Returns:
		true表示正在下雪
	"""
	return _current_weather == WeatherType.SNOWY

func is_extreme_weather() -> bool:
	"""检查是否极端天气

	Returns:
		true表示极端天气(暴风雨)
	"""
	return _current_weather == WeatherType.STORMY

func get_temperature() -> float:
	"""获取当前温度

	Returns:
		温度(摄氏度)
	"""
	return _temperature

func get_next_weather_change_time() -> float:
	"""获取下次天气变化时间

	Returns:
		Unix时间戳
	"""
	return _weather_start_time + _weather_duration

# ========================================
# 内部辅助方法
# ========================================

func _select_random_weather(season: String) -> WeatherType:
	"""根据季节随机选择天气

	Args:
		season: 季节名称

	Returns:
		天气类型
	"""
	var probabilities = _weather_config.get("seasonal_probabilities", {}).get(season, {})

	if probabilities.is_empty():
		return WeatherType.SUNNY

	# 加权随机选择
	var total_weight = 0.0
	for weight in probabilities.values():
		total_weight += weight

	var random_value = randf() * total_weight
	var cumulative = 0.0

	for weather_name in probabilities.keys():
		cumulative += probabilities[weather_name]
		if random_value <= cumulative:
			return _get_weather_enum(weather_name)

	return WeatherType.SUNNY

func _generate_temperature(season: String) -> float:
	"""生成季节性温度

	Args:
		season: 季节名称

	Returns:
		温度值
	"""
	var temp_ranges = _weather_config.get("temperature_ranges", {})
	var range_data = temp_ranges.get(season, {"min": 10, "max": 25})

	return randf_range(range_data.min, range_data.max)

func _generate_weather_duration(weather: WeatherType) -> float:
	"""生成天气持续时间

	Args:
		weather: 天气类型

	Returns:
		持续时间(秒)
	"""
	var durations = _weather_config.get("weather_durations", {})
	var weather_name = _get_weather_name(weather)
	var duration_data = durations.get(weather_name, {"min": 2, "max": 6})

	var hours = randf_range(duration_data.min, duration_data.max)
	return hours * 3600.0  # 转换为秒

func _get_current_season() -> String:
	"""获取当前季节

	Returns:
		季节名称
	"""
	if _time_system:
		return _time_system.current_season
	return "春季"

func _get_current_timestamp() -> float:
	"""获取当前时间戳

	Returns:
		Unix时间戳
	"""
	if _time_system:
		return float(_time_system.get_current_timestamp())
	return Time.get_unix_time_from_system()

func _get_weather_name(weather: WeatherType) -> String:
	"""获取天气类型名称

	Args:
		weather: 天气类型枚举

	Returns:
		天气名称字符串
	"""
	match weather:
		WeatherType.SUNNY: return "SUNNY"
		WeatherType.RAINY: return "RAINY"
		WeatherType.CLOUDY: return "CLOUDY"
		WeatherType.FOGGY: return "FOGGY"
		WeatherType.SNOWY: return "SNOWY"
		WeatherType.STORMY: return "STORMY"

	return "UNKNOWN"

func _get_weather_enum(weather_name: String) -> WeatherType:
	"""根据名称获取天气枚举

	Args:
		weather_name: 天气名称

	Returns:
		天气类型枚举
	"""
	match weather_name:
		"SUNNY": return WeatherType.SUNNY
		"RAINY": return WeatherType.RAINY
		"CLOUDY": return WeatherType.CLOUDY
		"FOGGY": return WeatherType.FOGGY
		"SNOWY": return WeatherType.SNOWY
		"STORMY": return WeatherType.STORMY

	return WeatherType.SUNNY

# ========================================
# 保存/加载
# ========================================

func save_state() -> Dictionary:
	"""保存天气系统状态

	Returns:
		状态字典
	"""
	return {
		"current_weather": _get_weather_name(_current_weather),
		"temperature": _temperature,
		"humidity": _humidity,
		"wind_speed": _wind_speed,
		"weather_start_time": _weather_start_time,
		"weather_duration": _weather_duration,
		"next_weather": _get_weather_name(_next_weather)
	}

func load_state(state: Dictionary):
	"""加载天气系统状态

	Args:
		state: 状态字典
	"""
	_current_weather = _get_weather_enum(state.get("current_weather", "SUNNY"))
	_temperature = state.get("temperature", 20.0)
	_humidity = state.get("humidity", 60.0)
	_wind_speed = state.get("wind_speed", 5.0)
	_weather_start_time = state.get("weather_start_time", 0.0)
	_weather_duration = state.get("weather_duration", 3600.0)
	_next_weather = _get_weather_enum(state.get("next_weather", "CLOUDY"))

	print("[WeatherSystem] 状态加载完成: %s, %.1f°C" % [
		_get_weather_name(_current_weather),
		_temperature
	])
