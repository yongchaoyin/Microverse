# script/time/TimeSystem.gd
# 时间系统 - 管理游戏内时间流动和时间相关事件
# 职责:
#   1. 管理游戏时间的推进(年/季/日/时/分)
#   2. 发送时间相关事件到EventBus
#   3. 提供时间查询和控制接口
#   4. 支持时间暂停/恢复/倍速控制
#   5. 支持时间状态的保存和加载
extends Node

# ==================== 常量定义 ====================

# 时间流速配置
const REAL_SECONDS_PER_GAME_MINUTE: float = 6.0  # 1游戏分钟 = 6现实秒（×10倍速基准）
const GAME_MINUTES_PER_UPDATE: float = 10.0      # 每10游戏分钟为1个时间单位
const GAME_HOURS_PER_DAY: float = 20.0           # 游戏内一天20小时（6:00-26:00即次日2:00）

# 日历配置
const DAYS_PER_WEEK: int = 7
const DAYS_PER_SEASON: int = 28
const DAYS_PER_YEAR: int = 112  # 4季 × 28天

# 工作时间配置
const WORK_START_HOUR: int = 9
const WORK_LUNCH_START: int = 12
const WORK_LUNCH_END: int = 13
const WORK_END_HOUR: int = 18  # 硬性下班边界
const MAX_OVERTIME_HOURS: int = 4

# 枚举和常量
const SEASONS = ["Spring", "Summer", "Autumn", "Winter"]
const SEASONS_CN = ["春季", "夏季", "秋季", "冬季"]
const WEEKDAYS = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
const WEEKDAYS_CN = ["周一", "周二", "周三", "周四", "周五", "周六", "周日"]

# ==================== 时间状态 ====================

# 当前时间
var current_year: int = 1
var current_season: int = 0        # 0=春, 1=夏, 2=秋, 3=冬
var current_day: int = 1           # 1-28 (当前季节的第几天)
var current_weekday: int = 1       # 1-7 (1=周一)
var current_hour: float = 6.0      # 6.0-26.0 (6:00AM - 次日2:00AM)
var current_minute: int = 0        # 0-59 (当前分钟)

# 时间控制
var time_multiplier: float = 1.0   # 时间流速倍率 (观察者可调节: 0.5, 1, 2, 5, 10)
var time_paused: bool = false      # 是否暂停

# 内部状态
var _accumulated_time: float = 0.0  # 累积的现实时间（秒）
var _last_hour: int = 6             # 上一次的小时(用于检测小时变化)
var _last_day: int = 1              # 上一次的天数(用于检测日期变化)

# ==================== 生命周期方法 ====================

func _ready():
	print("[TimeSystem] 🕐 时间系统初始化")
	print("[TimeSystem] 📅 当前时间: %s" % get_full_time_string())
	print("[TimeSystem] ⚙️ 时间配置:")
	print("  - 1游戏分钟 = %.1f现实秒" % REAL_SECONDS_PER_GAME_MINUTE)
	print("  - 1游戏天 = %.1f现实分钟" % (GAME_HOURS_PER_DAY * 60 * REAL_SECONDS_PER_GAME_MINUTE / 60))
	print("  - 工作时间: %02d:00 - %02d:00" % [WORK_START_HOUR, WORK_END_HOUR])
	print("  - 午休时间: %02d:00 - %02d:00" % [WORK_LUNCH_START, WORK_LUNCH_END])

	# 初始化上一次状态
	_last_hour = int(current_hour)
	_last_day = current_day

func _process(delta: float):
	if time_paused:
		return

	# 累积时间
	_accumulated_time += delta * time_multiplier

	# 计算应该前进多少游戏分钟
	var game_minutes_to_advance = _accumulated_time / REAL_SECONDS_PER_GAME_MINUTE

	# 每累积足够时间,游戏时间前进10分钟
	if game_minutes_to_advance >= GAME_MINUTES_PER_UPDATE:
		var updates = int(game_minutes_to_advance / GAME_MINUTES_PER_UPDATE)
		_accumulated_time -= updates * GAME_MINUTES_PER_UPDATE * REAL_SECONDS_PER_GAME_MINUTE

		_advance_time(updates * GAME_MINUTES_PER_UPDATE)

# ==================== 核心时间推进逻辑 ====================

## 推进游戏时间
## @param game_minutes: 游戏分钟数
func _advance_time(game_minutes: float) -> void:
	var old_hour = int(current_hour)
	var old_day = current_day
	var old_season = current_season
	var old_year = current_year

	# 推进小时
	current_hour += game_minutes / 60.0

	# 检查是否跨天
	if current_hour >= 26.0:  # 26:00 = 次日2:00
		current_hour -= 24.0
		current_day += 1
		current_weekday += 1

		# 周循环
		if current_weekday > 7:
			current_weekday = 1

		# 检查是否跨季节
		if current_day > DAYS_PER_SEASON:
			current_day = 1
			_advance_season()

		# 日期变化,发送信号
		if current_day != old_day:
			EventBus.day_changed.emit(current_year, current_season, current_day)

			# 如果是周一,发送周变化信号
			if current_weekday == 1:
				EventBus.emit_event("week_changed", {"week_number": get_current_week()})

			_last_day = current_day

	# 检查是否跨小时
	var new_hour = int(current_hour)
	if new_hour != old_hour:
		EventBus.hour_changed.emit(new_hour)

		# 检测时段变化
		_check_time_period_change(old_hour, new_hour)

		_last_hour = new_hour

	# 每个时间单位发送tick信号
	EventBus.time_tick.emit(int(game_minutes))

## 推进季节
func _advance_season() -> void:
	var old_season = current_season
	current_season = (current_season + 1) % 4

	# 如果回到春季,说明跨年了
	if current_season == 0:
		current_year += 1
		EventBus.year_changed.emit(current_year)

	EventBus.season_changed.emit(current_season)

## 检查时段变化
func _check_time_period_change(old_hour: int, new_hour: int) -> void:
	var old_period = _get_time_period_from_hour(old_hour)
	var new_period = _get_time_period_from_hour(new_hour)

	if old_period != new_period:
		# 发送时段变化事件
		EventBus.emit_event("time_period_changed", {
			"old_period": old_period,
			"new_period": new_period
		})

		# 发送特定时段开始事件
		match new_period:
			"dawn":
				EventBus.emit_event("dawn_started", {})
			"morning":
				EventBus.emit_event("morning_started", {})
			"noon":
				EventBus.emit_event("noon_started", {})
			"afternoon":
				EventBus.emit_event("afternoon_started", {})
			"evening":
				EventBus.emit_event("evening_started", {})
			"night":
				EventBus.emit_event("night_started", {})
			"late_night":
				EventBus.emit_event("late_night_started", {})

## 从小时获取时段
func _get_time_period_from_hour(hour: int) -> String:
	if hour >= 6 and hour < 8:
		return "dawn"      # 黎明 6:00-8:00
	elif hour >= 8 and hour < 12:
		return "morning"   # 上午 8:00-12:00
	elif hour >= 12 and hour < 14:
		return "noon"      # 午间 12:00-14:00
	elif hour >= 14 and hour < 18:
		return "afternoon" # 下午 14:00-18:00
	elif hour >= 18 and hour < 20:
		return "evening"   # 傍晚 18:00-20:00
	elif hour >= 20 and hour < 24:
		return "night"     # 夜间 20:00-24:00
	else:
		return "late_night" # 深夜 0:00-6:00

# ==================== 时间控制接口 ====================

## 暂停时间
func pause() -> void:
	time_paused = true
	EventBus.time_paused.emit()
	print("[TimeSystem] ⏸️ 时间已暂停")

## 恢复时间
func resume() -> void:
	time_paused = false
	EventBus.time_resumed.emit()
	print("[TimeSystem] ▶️ 时间已恢复")

## 切换暂停状态
func toggle_pause() -> void:
	if time_paused:
		resume()
	else:
		pause()

## 设置时间倍速
## @param multiplier: 倍速值 (0.5, 1, 2, 5, 10)
func set_time_multiplier(multiplier: float) -> void:
	if multiplier <= 0:
		push_warning("[TimeSystem] ⚠️ 时间倍速必须大于0, 使用pause()来暂停时间")
		return

	time_multiplier = multiplier
	EventBus.time_speed_changed.emit(multiplier)
	print("[TimeSystem] ⚡ 时间流速已设置为 ×%.1f" % multiplier)

## 快进到指定小时
## @param target_hour: 目标小时 (6-26)
func fast_forward_to_hour(target_hour: int) -> void:
	print("[TimeSystem] ⏩ 快进到 %02d:00" % target_hour)

	var original_speed = time_multiplier
	set_time_multiplier(10.0)

	# 使用异步等待
	while int(current_hour) != target_hour:
		await get_tree().create_timer(0.1).timeout
		if int(current_hour) == target_hour:
			break

	set_time_multiplier(original_speed)
	print("[TimeSystem] ✅ 快进完成: %s" % get_current_time_string())

## 跳到下一天的早上6:00
func skip_to_next_day() -> void:
	print("[TimeSystem] ⏭️ 跳到下一天")

	current_hour = 6.0
	current_day += 1
	current_weekday += 1

	if current_weekday > 7:
		current_weekday = 1

	if current_day > DAYS_PER_SEASON:
		current_day = 1
		_advance_season()

	EventBus.day_changed.emit(current_year, current_season, current_day)

	print("[TimeSystem] ✅ 已跳转到: %s" % get_full_time_string())

# ==================== 时间查询接口 ====================

## 获取当前小时(浮点数)
## @return: 当前小时 (如 14.5 = 14:30)
func get_current_hour() -> float:
	return current_hour

## 获取当前分钟
## @return: 当前分钟 (0-59)
func get_current_minute() -> int:
	return int((current_hour - int(current_hour)) * 60)

## 获取当前时间字符串
## @return: 时间字符串 (如 "14:30")
func get_current_time_string() -> String:
	var hour = int(current_hour)
	var minute = get_current_minute()
	return "%02d:%02d" % [hour, minute]

## 获取总天数(从游戏开始算起)
## @return: 总天数
func get_total_days() -> int:
	return (current_year - 1) * DAYS_PER_YEAR + get_day_of_year()

## 获取当年的第几天
## @return: 天数 (1-112)
func get_day_of_year() -> int:
	return current_season * DAYS_PER_SEASON + current_day

## 获取当前第几周
## @return: 周数
func get_current_week() -> int:
	return int((get_total_days() - 1) / 7) + 1

## 获取星期几的名称(英文)
## @return: 星期名称
func get_weekday_name() -> String:
	return WEEKDAYS[current_weekday - 1]

## 获取星期几的名称(中文)
## @return: 星期名称
func get_weekday_name_cn() -> String:
	return WEEKDAYS_CN[current_weekday - 1]

## 是否是周末
## @return: 如果是周六或周日返回true
func is_weekend() -> bool:
	return current_weekday >= 6  # 6=周六, 7=周日

## 是否是工作日
## @return: 如果是周一到周五返回true
func is_workday() -> bool:
	return current_weekday <= 5

## 是否在工作时间
## @return: 如果在工作时间返回true
func is_work_time() -> bool:
	if is_weekend():
		return false

	var hour = int(current_hour)

	# 上午工作时间 9:00-12:00
	if hour >= WORK_START_HOUR and hour < WORK_LUNCH_START:
		return true

	# 下午工作时间 13:00-18:00
	if hour >= WORK_LUNCH_END and hour < WORK_END_HOUR:
		return true

	return false

## 是否在午休时间
## @return: 如果在午休时间返回true
func is_lunch_time() -> bool:
	if is_weekend():
		return false

	var hour = int(current_hour)
	return hour >= WORK_LUNCH_START and hour < WORK_LUNCH_END

## 获取当前时段
## @return: 时段标识符
func get_time_period() -> String:
	return _get_time_period_from_hour(int(current_hour))

## 获取当前时段名称(中文)
## @return: 时段名称
func get_time_period_cn() -> String:
	match get_time_period():
		"dawn": return "黎明"
		"morning": return "上午"
		"noon": return "午间"
		"afternoon": return "下午"
		"evening": return "傍晚"
		"night": return "夜间"
		"late_night": return "深夜"
		_: return "未知"

## 获取当前时间的完整字典
## @return: 时间数据字典
func get_current_time_dict() -> Dictionary:
	return {
		"year": current_year,
		"season": current_season,
		"season_name": get_season_name(),
		"season_name_cn": get_season_name_cn(),
		"day": current_day,
		"day_of_year": get_day_of_year(),
		"weekday": current_weekday,
		"weekday_name": get_weekday_name(),
		"weekday_name_cn": get_weekday_name_cn(),
		"hour": int(current_hour),
		"minute": get_current_minute(),
		"time_string": get_current_time_string(),
		"time_period": get_time_period(),
		"time_period_cn": get_time_period_cn(),
		"is_weekend": is_weekend(),
		"is_work_time": is_work_time(),
		"total_days": get_total_days()
	}

## 获取季节名称(英文)
## @return: 季节名称
func get_season_name() -> String:
	return SEASONS[current_season]

## 获取季节名称(中文)
## @return: 季节名称
func get_season_name_cn() -> String:
	return SEASONS_CN[current_season]

## 获取季节数据
## @param season_name: 季节名称(可选)
## @return: 季节数据字典
func get_season_data(season_name: String = "") -> Dictionary:
	if season_name == "":
		season_name = get_season_name()

	var season_data = {
		"Spring": {
			"name_cn": "春季",
			"color_tint": Color(1.0, 1.0, 0.9),
			"weather_chances": {"sunny": 0.6, "rainy": 0.3, "cloudy": 0.1},
			"ai_mood_modifier": 10,
			"events": ["Spring Festival", "Flower Dance"],
			"description": "樱花盛开，春意盎然"
		},
		"Summer": {
			"name_cn": "夏季",
			"color_tint": Color(1.0, 0.95, 0.8),
			"weather_chances": {"sunny": 0.8, "rainy": 0.1, "cloudy": 0.1},
			"ai_mood_modifier": 5,
			"events": ["Beach Party", "Summer Festival"],
			"description": "阳光明媚，热情似火"
		},
		"Autumn": {
			"name_cn": "秋季",
			"color_tint": Color(1.0, 0.9, 0.7),
			"weather_chances": {"sunny": 0.7, "rainy": 0.1, "cloudy": 0.2},
			"ai_mood_modifier": 8,
			"events": ["Harvest Festival", "Halloween"],
			"description": "金秋时节，凉爽宜人"
		},
		"Winter": {
			"name_cn": "冬季",
			"color_tint": Color(0.9, 0.95, 1.0),
			"weather_chances": {"sunny": 0.3, "snowy": 0.5, "cloudy": 0.2},
			"ai_mood_modifier": -5,
			"events": ["Winter Festival", "New Year"],
			"description": "白雪皑皑，银装素裹"
		}
	}

	return season_data.get(season_name, {})

## 获取当前日期字符串
## @return: 日期字符串
func get_current_date_string() -> String:
	return "第%d年 %s 第%d天" % [current_year, get_season_name_cn(), current_day]

## 获取完整时间字符串
## @return: 完整时间字符串
func get_full_time_string() -> String:
	return "%s %s (%s)" % [get_current_date_string(), get_current_time_string(), get_weekday_name_cn()]

# ==================== 保存/加载接口 ====================

## 保存时间状态
## @return: 状态数据字典
func save_state() -> Dictionary:
	return {
		"year": current_year,
		"season": current_season,
		"day": current_day,
		"weekday": current_weekday,
		"hour": current_hour,
		"minute": current_minute,
		"paused": time_paused,
		"multiplier": time_multiplier
	}

## 加载时间状态
## @param state: 状态数据字典
func load_state(state: Dictionary) -> void:
	current_year = state.get("year", 1)
	current_season = state.get("season", 0)
	current_day = state.get("day", 1)
	current_weekday = state.get("weekday", 1)
	current_hour = state.get("hour", 6.0)
	current_minute = state.get("minute", 0)
	time_paused = state.get("paused", false)
	time_multiplier = state.get("multiplier", 1.0)
	_accumulated_time = 0.0

	# 更新上一次状态
	_last_hour = int(current_hour)
	_last_day = current_day

	print("[TimeSystem] ✅ 时间状态已加载: %s" % get_full_time_string())

# ==================== 调试接口 ====================

## 获取调试信息
## @return: 调试信息字符串
func get_debug_info() -> String:
	return """
[时间系统调试信息]
%s
时间: %s
时段: %s
流速: ×%.1f
暂停: %s
总天数: %d
工作日: %s
工作时间: %s
""".strip_edges() % [
		"=" * 60,
		get_full_time_string(),
		get_time_period_cn(),
		time_multiplier,
		"是" if time_paused else "否",
		get_total_days(),
		"是" if is_workday() else "否(周末)",
		"是" if is_work_time() else "否"
	]

## 打印调试信息
func print_debug_info() -> void:
	print(get_debug_info())
