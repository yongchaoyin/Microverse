extends Node

class_name CareerSystem

# ========================================
# 信号定义
# ========================================

signal career_assigned(ai_id: String, career_id: String)
signal career_changed(ai_id: String, old_career_id: String, new_career_id: String)
signal career_performance_updated(ai_id: String, performance_data: Dictionary)
signal career_data_reloaded()

# ========================================
# 常量定义
# ========================================

const CAREER_DATA_PATH := "res://data/careers.json"

# 工作时间配置
const WORK_HOURS_START := 9.0    # 9:00 AM
const WORK_HOURS_END := 18.0     # 6:00 PM
const LUNCH_BREAK_START := 12.0  # 12:00 PM
const LUNCH_BREAK_END := 13.0    # 1:00 PM

# 绩效评估周期
const PERFORMANCE_REVIEW_WEEKDAY := 5  # Friday
const PERFORMANCE_REVIEW_HOUR := 17    # 5:00 PM

# ========================================
# 内部状态
# ========================================

var _careers: Dictionary = {}           # career_id -> career_data
var _character_career_map: Dictionary = {}  # character_name -> career_id
var _default_schedule: Dictionary = {}
var _agent_registry: Dictionary = {}    # ai_id -> {"career_id": String, "character_name": String}
var _career_performance: Dictionary = {}  # ai_id -> performance_data

var _time_system: Node = null
var _event_bus: Node = null
var _task_system: Node = null

# ========================================
# 初始化
# ========================================

func _ready():
	# 获取系统引用
	_time_system = get_node_or_null("/root/TimeSystem")
	_event_bus = get_node_or_null("/root/EventBus")
	_task_system = get_node_or_null("/root/TaskSystem")

	# 连接时间系统信号
	if _time_system:
		_time_system.hour_changed.connect(_on_hour_changed)

	# 加载职业数据
	_load_career_data()

	print("[CareerSystem] 职业系统初始化完成，加载了 %d 个职业" % _careers.size())

# ========================================
# 角色注册API
# ========================================

func register_character(ai_id: String, character_name: String, explicit_career_id: String = "") -> String:
	"""注册AI角色到职业系统"""
	var normalized_ai_id := ai_id.strip_edges()
	if normalized_ai_id.is_empty():
		push_warning("[CareerSystem] register_character called with empty ai_id")
		return ""

	var career_id := explicit_career_id.strip_edges()
	if career_id.is_empty():
		career_id = _character_career_map.get(character_name, "")

	if career_id.is_empty():
		print("[CareerSystem] %s 未在职业映射表中，使用默认职业模板" % character_name)
		career_id = "office_worker"  # 默认办公室职员

	if not _careers.has(career_id):
		print("[CareerSystem] 未找到职业 %s，降级到默认职业模板" % career_id)
		career_id = "office_worker"

	var previous := _agent_registry.get(normalized_ai_id, {})
	var previous_career := previous.get("career_id", "")

	# 更新注册信息
	_agent_registry[normalized_ai_id] = {
		"career_id": career_id,
		"character_name": character_name
	}

	# 初始化绩效数据
	if not _career_performance.has(normalized_ai_id):
		_career_performance[normalized_ai_id] = {
			"tasks_completed": 0,
			"tasks_failed": 0,
			"quality_score": 0.0,
			"punctuality_score": 0.0,
			"teamwork_score": 0.0,
			"overwork_hours": 0.0,
			"last_review_week": 0,
			"performance_rating": "C"  # A, B, C, D, F
		}

	# 发送信号
	if previous_career == "":
		career_assigned.emit(normalized_ai_id, career_id)
	elif previous_career != career_id:
		career_changed.emit(normalized_ai_id, previous_career, career_id)

	return career_id

func update_career(ai_id: String, new_career_id: String) -> bool:
	"""更新AI的职业"""
	if not _careers.has(new_career_id):
		print("[CareerSystem] Cannot assign unknown career %s" % new_career_id)
		return false

	if not _agent_registry.has(ai_id):
		print("[CareerSystem] Agent %s not registered, register first" % ai_id)
		return false

	var previous := _agent_registry[ai_id].get("career_id", "")
	if previous == new_career_id:
		return true

	_agent_registry[ai_id]["career_id"] = new_career_id
	career_changed.emit(ai_id, previous, new_career_id)

	# 重置绩效数据
	_reset_performance_data(ai_id)

	return true

# ========================================
# 查询API
# ========================================

func get_registered_career(ai_id: String) -> String:
	"""获取AI的职业ID"""
	if not _agent_registry.has(ai_id):
		return "unemployed"
	return _agent_registry[ai_id].get("career_id", "unemployed")

func get_career_data(career_id: String) -> Dictionary:
	"""获取职业数据"""
	if career_id == "" or not _careers.has(career_id):
		return _careers.get("office_worker", {}).duplicate(true)
	return _careers[career_id].duplicate(true)

func get_career_name(career_id: String) -> String:
	"""获取职业名称"""
	var career_data = get_career_data(career_id)
	return career_data.get("name", "未知职业")

func get_career_name_cn(career_id: String) -> String:
	"""获取职业中文名"""
	var career_data = get_career_data(career_id)
	return career_data.get("name_cn", "未知职业")

func get_schedule_for_career(career_id: String, is_weekend: bool = false) -> Array:
	"""获取职业日程"""
	var schedule_key := "weekend" if is_weekend else "weekday"
	var career_data = get_career_data(career_id)
	if career_data.is_empty():
		return _default_schedule.get(schedule_key, [])

	var schedule := career_data.get("daily_schedule", {})
	if not schedule.has(schedule_key):
		return _default_schedule.get(schedule_key, [])
	return schedule[schedule_key]

func get_work_hours(career_id: String) -> Dictionary:
	"""获取工作时间段"""
	var career_data = get_career_data(career_id)
	return {
		"start": career_data.get("work_start", WORK_HOURS_START),
		"end": career_data.get("work_end", WORK_HOURS_END),
		"lunch_start": career_data.get("lunch_start", LUNCH_BREAK_START),
		"lunch_end": career_data.get("lunch_end", LUNCH_BREAK_END)
	}

func get_salary_profile(career_id: String) -> Dictionary:
	"""获取工资配置"""
	var data := get_career_data(career_id)
	return {
		"daily_salary": data.get("daily_salary", 150),
		"weekly_base_salary": data.get("daily_salary", 150) * 5,
		"bonus_multiplier": data.get("bonus_multiplier", 1.0),
		"performance_bonus_rate": data.get("performance_bonus_rate", 0.2)
	}

func get_performance_data(ai_id: String) -> Dictionary:
	"""获取绩效数据"""
	if not _career_performance.has(ai_id):
		return {}
	return _career_performance[ai_id].duplicate(true)

func get_performance_rating(ai_id: String) -> String:
	"""获取绩效评级"""
	var performance = get_performance_data(ai_id)
	return performance.get("performance_rating", "C")

# ========================================
# 绩效管理
# ========================================

func record_task_completion(ai_id: String, task_quality: float, task_urgency: int):
	"""记录任务完成"""
	if not _career_performance.has(ai_id):
		return

	var performance = _career_performance[ai_id]
	performance.tasks_completed += 1

	# 更新质量分数
	var old_quality = performance.quality_score
	performance.quality_score = (old_quality * 0.7 + task_quality * 0.3)

	# 高紧急度任务权重更高
	if task_urgency >= 4:
		performance.quality_score *= 1.1

	_performance_event_emission(ai_id)

func record_task_failure(ai_id: String, failure_reason: String):
	"""记录任务失败"""
	if not _career_performance.has(ai_id):
		return

	var performance = _career_performance[ai_id]
	performance.tasks_failed += 1

	# 失败影响质量分数
	performance.quality_score = max(performance.quality_score - 0.2, 0.0)

	_performance_event_emission(ai_id)

func record_attendance(ai_id: String, is_late: bool = false):
	"""记录出勤"""
	if not _career_performance.has(ai_id):
		return

	var performance = _career_performance[ai_id]
	if is_late:
		performance.punctuality_score = max(performance.punctuality_score - 0.1, 0.0)
	else:
		performance.punctuality_score = min(performance.punctuality_score + 0.05, 1.0)

func record_overtime_work(ai_id: String, hours: float):
	"""记录加班"""
	if not _career_performance.has(ai_id):
		return

	var performance = _career_performance[ai_id]
	performance.overwork_hours += hours

	# 适度加班增加团队合作分数
	if hours > 0 and hours <= 2:
		performance.teamwork_score = min(performance.teamwork_score + 0.02, 1.0)

func _calculate_performance_rating(ai_id: String) -> String:
	"""计算绩效评级"""
	var performance = get_performance_data(ai_id)
	if performance.is_empty():
		return "C"

	var score = 0.0

	# 质量分数 (40%)
	score += performance.quality_score * 40.0

	# 准时分数 (20%)
	score += performance.punctuality_score * 20.0

	# 团队合作分数 (20%)
	score += performance.teamwork_score * 20.0

	# 加班分数 (20%)
	var overtime_score = min(performance.overwork_hours / 10.0, 1.0)  # 最多10小时满分
	score += overtime_score * 20.0

	# 任务完成率调整
	var total_tasks = performance.tasks_completed + performance.tasks_failed
	if total_tasks > 0:
		var completion_rate = float(performance.tasks_completed) / float(total_tasks)
		score *= completion_rate

	# 转换为字母评级
	if score >= 90:
		return "A"
	elif score >= 80:
		return "B"
	elif score >= 70:
		return "C"
	elif score >= 60:
		return "D"
	else:
		return "F"

func _performance_event_emission(ai_id: String):
	"""发送绩效更新事件"""
	var performance = get_performance_data(ai_id)
	performance.performance_rating = _calculate_performance_rating(ai_id)
	_career_performance[ai_id] = performance

	career_performance_updated.emit(ai_id, performance)

	if _event_bus:
		_event_bus.emit_event("career.performance_updated", {
			"ai_id": ai_id,
			"performance": performance
		})

func _reset_performance_data(ai_id: String):
	"""重置绩效数据"""
	_career_performance[ai_id] = {
		"tasks_completed": 0,
		"tasks_failed": 0,
		"quality_score": 0.5,
		"punctuality_score": 0.8,
		"teamwork_score": 0.5,
		"overwork_hours": 0.0,
		"last_review_week": 0,
		"performance_rating": "C"
	}

# ========================================
# 时间相关处理
# ========================================

func _on_hour_changed(hour: int):
	"""每小时检查工作相关事件"""
	if _time_system and _time_system.is_workday():
		var current_hour = _time_system.get_current_hour()

		# 检查迟到
		if current_hour >= WORK_HOURS_START and current_hour < WORK_HOURS_END:
			_check_attendance(current_hour)

		# 周五下午进行绩效评估
		if _time_system.get_weekday_name() == "Friday" and current_hour == PERFORMANCE_REVIEW_HOUR:
			_conduct_performance_reviews()

func _check_attendance(current_hour: float):
	"""检查出勤情况"""
	# 简化实现：在实际系统中，需要追踪每个角色的出勤状态
	for ai_id in _agent_registry.keys():
		var career_id = get_registered_career(ai_id)
		var work_hours = get_work_hours(career_id)

		# 如果是工作时间段且是工作时间开始时，检查出勤
		if current_hour == work_hours.start:
			var work_start = work_hours.start * 60
			var actual_start = _time_system.get_current_hour() * 60
			var is_late = actual_start > work_start + 10  # 允许10分钟迟到

			record_attendance(ai_id, is_late)

func _conduct_performance_reviews():
	"""进行周绩效评估"""
	print("[CareerSystem] 进行周绩效评估（周五 %d:00）" % PERFORMANCE_REVIEW_HOUR)

	var current_week = 0
	if _time_system:
		current_week = _time_system.get_current_week()

	for ai_id in _career_performance.keys():
		var performance = _career_performance[ai_id]
		if performance.get("last_review_week", 0) < current_week:

			# 计算新的绩效评级
			var old_rating = performance.get("performance_rating", "C")
			var new_rating = _calculate_performance_rating(ai_id)

			performance.last_review_week = current_week
			performance.performance_rating = new_rating
			_career_performance[ai_id] = performance

			# 发送绩效评估事件
			_performance_event_emission(ai_id)

			if old_rating != new_rating:
				print("  %s 绩效评级: %s -> %s" % [ai_id, old_rating, new_rating])

# ========================================
# 数据加载
# ========================================

func _load_career_data():
	"""加载职业配置数据"""
	var file := FileAccess.open(CAREER_DATA_PATH, FileAccess.READ)
	if file == null:
		print("[CareerSystem] 无法读取职业配置文件 %s，使用默认数据" % CAREER_DATA_PATH)
		_load_default_careers()
		return

	var text := file.get_as_text()
	file.close()

	var result := JSON.parse_string(text)
	if typeof(result) != TYPE_DICTIONARY:
		print("[CareerSystem] 职业配置格式错误，回退到默认数据")
		_load_default_careers()
		return

	_careers.clear()
	_character_career_map = result.get("character_careers", {})
	_default_schedule = result.get("default_schedule", {})

	for entry in result.get("careers", []):
		if typeof(entry) != TYPE_DICTIONARY or not entry.has("id"):
			continue
		var id := String(entry["id"])
		_careers[id] = entry

	if not _careers.has("office_worker"):
		_add_default_career()

func _load_default_careers():
	"""加载默认职业数据"""
	_careers.clear()
	_character_career_map.clear()
	_default_schedule = _create_default_schedule()

	# 默认办公室职员
	_careers["office_worker"] = {
		"id": "office_worker",
		"name": "Office Worker",
		"name_cn": "办公室职员",
		"description": "处理日常办公室工作",
		"work_start": WORK_HOURS_START,
		"work_end": WORK_HOURS_END,
		"lunch_start": LUNCH_BREAK_START,
		"lunch_end": LUNCH_BREAK_END,
		"daily_salary": 150,
		"bonus_multiplier": 1.0,
		"performance_bonus_rate": 0.2,
		"default_location_type": "OFFICE",
		"required_skills": ["basic_office"],
		"career_progression": ["senior_worker", "manager"]
	}

	# 工程师
	_careers["engineer"] = {
		"id": "engineer",
		"name": "Software Engineer",
		"name_cn": "软件工程师",
		"description": "开发和维护软件系统",
		"work_start": 9.0,
		"work_end": 18.0,
		"lunch_start": 12.0,
		"lunch_end": 13.0,
		"daily_salary": 180,
		"bonus_multiplier": 1.2,
		"performance_bonus_rate": 0.25,
		"default_location_type": "OFFICE",
		"required_skills": ["programming", "problem_solving"],
		"career_progression": ["senior_engineer", "tech_lead"]
	}

	# 经理
	_careers["manager"] = {
		"id": "manager",
		"name": "Manager",
		"name_cn": "经理",
		"description": "管理团队和项目",
		"work_start": 8.5,
		"work_end": 18.0,
		"lunch_start": 12.0,
		"lunch_end": 13.0,
		"daily_salary": 220,
		"bonus_multiplier": 1.5,
		"performance_bonus_rate": 0.3,
		"default_location_type": "OFFICE",
		"required_skills": ["leadership", "communication"],
		"career_progression": ["senior_manager", "director"]
	}

	# 角色职业映射
	_character_career_map = {
		"Stephen": "manager",
		"Tom": "engineer",
		"Lea": "engineer",
		"Alice": "office_worker",
		"Grace": "office_worker",
		"Jack": "engineer",
		"Joe": "engineer",
		"Monica": "office_worker"
	}

func _add_default_career():
	"""添加默认职业"""
	_careers["office_worker"] = {
		"id": "office_worker",
		"name": "Office Worker",
		"name_cn": "办公室职员",
		"description": "处理日常办公室工作",
		"work_start": WORK_HOURS_START,
		"work_end": WORK_HOURS_END,
		"lunch_start": LUNCH_BREAK_START,
		"lunch_end": LUNCH_BREAK_END,
		"daily_salary": 150,
		"bonus_multiplier": 1.0,
		"performance_bonus_rate": 0.2,
		"default_location_type": "OFFICE",
		"daily_schedule": _default_schedule
	}

func _create_default_schedule() -> Dictionary:
	"""创建默认日程"""
	return {
		"weekday": [
			{ "start": "09:00", "end": "12:00", "activity": "focused_work", "location_type": "OFFICE" },
			{ "start": "12:00", "end": "13:00", "activity": "lunch_break", "location_type": "CAFETERIA" },
			{ "start": "13:00", "end": "18:00", "activity": "project_work", "location_type": "OFFICE" },
			{ "start": "18:00", "end": "26:00", "activity": "rest", "location_type": "HOME" }
		],
		"weekend": [
			{ "start": "06:00", "end": "26:00", "activity": "rest", "location_type": "HOME" }
		]
	}

# ========================================
# 公共接口
# ========================================

func get_all_careers() -> Dictionary:
	"""获取所有职业"""
	return _careers.duplicate(true)

func get_career_count() -> int:
	"""获取职业数量"""
	return _careers.size()

func get_registered_agents() -> Array:
	"""获取已注册的AI"""
	return _agent_registry.keys()

def reload_data() -> void:
	_load_career_data()
	career_data_reloaded.emit()

# ========================================
# 保存/加载
# ========================================

func save_state() -> Dictionary:
	"""保存职业系统状态"""
	return {
		"agent_registry": _agent_registry,
		"career_performance": _career_performance,
		"timestamp": _time_system.get_current_timestamp() if _time_system else Time.get_unix_time_from_system()
	}

func load_state(state: Dictionary):
	"""加载职业系统状态"""
	_agent_registry = state.get("agent_registry", {})
	_career_performance = state.get("career_performance", {})
	print("[CareerSystem] 职业数据已加载，共%d个已注册AI" % _agent_registry.size())