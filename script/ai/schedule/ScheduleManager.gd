extends Node

class_name ScheduleManager

# ========================================
# 信号定义
# ========================================

signal schedule_registered(ai_id: String, career_id: String, agenda: Array)
signal schedule_updated(ai_id: String, agenda: Array)
signal activity_changed(ai_id: String, activity: Dictionary)
signal schedule_conflict(ai_id: String, conflict_info: Dictionary)

# ========================================
# 常量定义
# ========================================

const DEFAULT_ACTIVITY := {
	"id": "idle",
	"activity": "idle",
	"location_type": "HOME",
	"location_enum": LocationManager.LocationType.HOME,
	"start_minute": 0,
	"end_minute": 1440,
	"is_default": true,
	"priority": 0
}

const ACTIVITY_PRIORITIES := {
	"work": 10,           # 工作活动最高优先级
	"meeting": 9,         # 会议高优先级
	"deadline": 8,        # 截止日期任务高优先级
	"focused_work": 8,    # 专注工作高优先级
	"lunch_break": 7,     # 午餐中等优先级
	"project_work": 6,    # 项目工作中优先级
	"social": 5,          # 社交活动中优先级
	"romantic": 5,        # 恋爱活动中优先级
	"rest": 3,            # 休息低优先级
	"leisure": 2,         # 娱乐很低优先级
	"idle": 0             # 空闲最低优先级
}

const LOCATION_TYPE_ALIASES := {
	"OFFICE": LocationManager.LocationType.OFFICE,
	"DEV_DESK": LocationManager.LocationType.OFFICE,
	"QA_LAB": LocationManager.LocationType.OFFICE,
	"HR_OFFICE": LocationManager.LocationType.OFFICE,
	"PRODUCT_WAR_ROOM": LocationManager.LocationType.OFFICE,
	"EXECUTIVE_OFFICE": LocationManager.LocationType.OFFICE,
	"ADMIN_DESK": LocationManager.LocationType.OFFICE,
	"FRONT_DESK": LocationManager.LocationType.ENTRANCE,
	"BOARD_ROOM": LocationManager.LocationType.MEETING_ROOM,
	"MEETING_ROOM": LocationManager.LocationType.MEETING_ROOM,
	"SCRUM_AREA": LocationManager.LocationType.MEETING_ROOM,
	"WORKSHOP": LocationManager.LocationType.MEETING_ROOM,
	"CAFETERIA": LocationManager.LocationType.CAFETERIA,
	"CAFE": LocationManager.LocationType.COFFEE_SHOP,
	"COFFEE_SHOP": LocationManager.LocationType.COFFEE_SHOP,
	"FITNESS": LocationManager.LocationType.GYM,
	"GYM": LocationManager.LocationType.GYM,
	"LOUNGE": LocationManager.LocationType.LOUNGE,
	"LOBBY": LocationManager.LocationType.ENTRANCE,
	"HOME": LocationManager.LocationType.HOME,
	"PENTHOUSE": LocationManager.LocationType.HOME,
	"HOME_DESK": LocationManager.LocationType.HOME,
	"MARKET": LocationManager.LocationType.OTHER,
	"PARK": LocationManager.LocationType.PARK,
	"REST": LocationManager.LocationType.HOME,
	"GARDEN": LocationManager.LocationType.PARK,
	"LIBRARY": LocationManager.LocationType.OTHER,
	"SUPERMARKET": LocationManager.LocationType.OTHER
}

# ========================================
# 内部状态
# ========================================

var _career_system: CareerSystem = null
var _time_system: TimeSystem = null
var _event_bus: EventBus = null
var _task_system: Node = null
var _relationship_manager: Node = null

var _agents: Dictionary = {}  # ai_id -> { career_id, agenda, current_activity, overrides, preferences }
var _activity_history: Dictionary = {}  # ai_id -> [activity_history]
var _pending_activities: Dictionary = {}  # ai_id -> [pending_activities]

# ========================================
# 初始化
# ========================================

func _ready():
	# 获取系统引用
	_career_system = get_node_or_null("/root/CareerSystem")
	_time_system = get_node_or_null("/root/TimeSystem")
	_event_bus = get_node_or_null("/root/EventBus")
	_task_system = get_node_or_null("/root/TaskSystem")
	_relationship_manager = get_node_or_null("/root/RelationshipManager")

	# 连接时间系统信号
	if _time_system:
		_time_system.time_updated.connect(_on_time_updated)
		_time_system.day_changed.connect(_on_day_changed)
	else:
		push_warning("[ScheduleManager] TimeSystem missing – schedule events will not update in real time.")

	# 连接EventBus信号
	if _event_bus:
		_event_bus.subscribe("schedule.refresh_request", self, "_on_refresh_request")
		_event_bus.subscribe("schedule.override_request", self, "_on_override_request")
		_event_bus.subscribe("task.assigned", self, "_on_task_assigned")
		_event_bus.subscribe("social.invitation", self, "_on_social_invitation")

	print("[ScheduleManager] 日程管理器初始化完成")

# ========================================
# 代理注册API
# ========================================

func register_agent(ai_id: String, character_name: String, career_id: String = "", overrides: Dictionary = {}, preferences: Dictionary = {}) -> void:
	"""注册AI代理到日程系统"""
	if _career_system == null:
		print("[ScheduleManager] CareerSystem not available. Cannot register agent %s" % ai_id)
		return

	# 解析职位
	var resolved_career := career_id
	if resolved_career == "":
		resolved_career = _career_system.register_character(ai_id, character_name, career_id)

	# 构建日程
	var agenda := _build_daily_agenda(resolved_career, preferences)

	# 初始化活动历史
	if not _activity_history.has(ai_id):
		_activity_history[ai_id] = []

	# 初始化待办活动
	if not _pending_activities.has(ai_id):
		_pending_activities[ai_id] = []

	# 注册代理
	_agents[ai_id] = {
		"career_id": resolved_career,
		"character_name": character_name,
		"agenda": agenda,
		"overrides": overrides,
		"current_activity": DEFAULT_ACTIVITY.duplicate(true),
		"preferences": preferences,
		"last_activity_change": 0
	}

	# 更新当前活动
	_update_current_activity(ai_id, true)

	print("[ScheduleManager] 注册代理: %s -> %s" % [character_name, resolved_career])
	schedule_registered.emit(ai_id, resolved_career, agenda)

func set_manual_override(ai_id: String, override: Dictionary) -> void:
	"""设置手动覆盖日程"""
	if not _agents.has(ai_id):
		print("[ScheduleManager] Agent %s not registered" % ai_id)
		return

	_agents[ai_id]["overrides"] = override
	_agents[ai_id]["last_activity_change"] = _current_timestamp()
	_update_current_activity(ai_id, true)

func clear_manual_override(ai_id: String) -> void:
	"""清除手动覆盖"""
	if not _agents.has(ai_id):
		return

	_agents[ai_id]["overrides"] = {}
	_agents[ai_id]["last_activity_change"] = _current_timestamp()
	_update_current_activity(ai_id, true)

func add_temporary_activity(ai_id: String, temp_activity: Dictionary, priority_override: int = -1) -> bool:
	"""添加临时活动"""
	if not _agents.has(ai_id):
		return false

	var activity := _validate_and_hydrate_activity(temp_activity)
	if activity.is_empty():
		return false

	# 设置优先级
	if priority_override >= 0:
		activity.priority = priority_override
	elif not activity.has("priority"):
		activity.priority = ACTIVITY_PRIORITIES.get(activity.activity, 5)

	# 添加到待办活动
	var pending = _pending_activities.get(ai_id, [])
	pending.append(activity)
	_pending_activities[ai_id] = pending

	print("[ScheduleManager] 为 %s 添加临时活动: %s (优先级 %d)" % [ai_id, activity.activity, activity.priority])

	# 立即检查是否需要切换活动
	_check_activity_conflicts(ai_id)
	_update_current_activity(ai_id)

	return true

func schedule_social_activity(ai_id: String, partner_id: String, activity_type: String, start_time: String, duration: float = 2.0) -> bool:
	"""安排社交活动"""
	var social_activity := {
		"activity": activity_type,
		"start": start_time,
		"end": _calculate_end_time(start_time, duration),
		"location_type": "COFFEE_SHOP",
		"participants": [ai_id, partner_id],
		"priority": ACTIVITY_PRIORITIES.get("social", 5),
		"is_social": true,
		"metadata": {
			"partner": partner_id,
			"activity_type": activity_type
		}
	}

	return add_temporary_activity(ai_id, social_activity)

# ========================================
# 查询API
# ========================================

func get_current_activity(ai_id: String) -> Dictionary:
	"""获取当前活动"""
	if not _agents.has(ai_id):
		return DEFAULT_ACTIVITY.duplicate(true)
	return _agents[ai_id]["current_activity"].duplicate(true)

func get_agenda(ai_id: String) -> Array:
	"""获取日程"""
	if not _agents.has(ai_id):
		return []
	return _agents[ai_id]["agenda"].duplicate(true)

func get_activity_history(ai_id: String, limit: int = 10) -> Array:
	"""获取活动历史"""
	if not _activity_history.has(ai_id):
		return []
	var history = _activity_history[ai_id]
	return history.slice(max(0, history.size() - limit), history.size())

func is_available_for_social(ai_id: String, start_time: String, duration: float = 2.0) -> bool:
	"""检查是否可用于社交活动"""
	if not _agents.has(ai_id):
		return false

	var start_minute = _time_to_minutes(start_time)
	var end_minute = start_minute + duration * 60
	var agenda = get_agenda(ai_id)

	# 检查是否有高优先级冲突
	for activity in agenda:
		var activity_start = activity.get("start_minute", 0)
		var activity_end = activity.get("end_minute", 0)
		var activity_priority = activity.get("priority", 0)

		# 如果时间重叠且优先级较高/相等，则不可用
		if _time_ranges_overlap(start_minute, end_minute, activity_start, activity_end):
			if activity_priority >= ACTIVITY_PRIORITIES.get("social", 5):
				return false

	return true

func get_next_activity(ai_id: String) -> Dictionary:
	"""获取下一个活动"""
	if not _agents.has(ai_id):
		return {}

	var current_time = _current_timestamp()
	var agenda = get_agenda(ai_id)
	var next_activity = {}

	for activity in agenda:
		if activity.get("start_minute", 0) > current_time:
			if next_activity.is_empty() or activity.get("start_minute", 0) < next_activity.get("start_minute", 1440):
				next_activity = activity

	return next_activity

# ========================================
# 日程管理
# ========================================

func refresh_agent_schedule(ai_id: String) -> void:
	"""刷新代理日程"""
	if not _agents.has(ai_id):
		return

	var agent_data = _agents[ai_id]
	var career_id = agent_data["career_id"]
	var preferences = agent_data.get("preferences", {})

	agent_data["agenda"] = _build_daily_agenda(career_id, preferences)
	_update_current_activity(ai_id, true)

	print("[ScheduleManager] 刷新 %s 的日程" % ai_id)
	schedule_updated.emit(ai_id, agent_data["agenda"])

func refresh_all() -> void:
	"""刷新所有代理日程"""
	for ai_id in _agents.keys():
		refresh_agent_schedule(ai_id)

# ========================================
# 内部处理
# ========================================

func _on_time_updated(time_snapshot: Dictionary) -> void:
	"""时间更新处理"""
	if _agents.is_empty():
		return

	var current_minute = time_snapshot.get("hour", 6) * 60 + time_snapshot.get("minute", 0)

	for ai_id in _agents.keys():
		_update_current_activity(ai_id)

func _on_day_changed(year: int, season: int, day: int) -> void:
	"""日期变化处理"""
	refresh_all()

func _on_refresh_request(payload: Dictionary) -> void:
	"""刷新请求处理"""
	if payload.has("ai_id"):
		refresh_agent_schedule(payload["ai_id"])
	else:
		refresh_all()

func _on_override_request(payload: Dictionary) -> void:
	"""覆盖请求处理"""
	var ai_id = payload.get("ai_id", "")
	var override = payload.get("override", {})
	var duration = payload.get("duration", 0)

	if not override.is_empty():
		set_manual_override(ai_id, override)
		if duration > 0:
			# 设置定时清除
			_schedule_override_clear(ai_id, duration)

func _on_task_assigned(payload: Dictionary) -> void:
	"""任务分配处理"""
	var ai_id = payload.get("ai_id", "")
	var task = payload.get("task", {})

	if ai_id != "" and not task.is_empty():
		var task_activity = _convert_task_to_activity(task)
		if not task_activity.is_empty():
			add_temporary_activity(ai_id, task_activity)

func _on_social_invitation(payload: Dictionary) -> void:
	"""社交邀请处理"""
	var ai_id = payload.get("target_id", "")
	var inviter_id = payload.get("inviter_id", "")
	var activity_type = payload.get("activity_type", "coffee")
	var start_time = payload.get("start_time", "14:00")

	if ai_id != "" and inviter_id != "":
		schedule_social_activity(ai_id, inviter_id, activity_type, start_time)

func _update_current_activity(ai_id: String, force_emit: bool = false) -> void:
	"""更新当前活动"""
	var state := _agents.get(ai_id, null)
	if state == null:
		return

	var agenda: Array = state["agenda"]
	var overrides: Dictionary = state.get("overrides", {})
	var pending: Array = _pending_activities.get(ai_id, [])
	var now_minutes := _current_timestamp()

	# 确定当前活动
	var selected_activity := _resolve_current_activity(now_minutes, agenda, overrides, pending)

	var previous := state.get("current_activity", DEFAULT_ACTIVITY)
	state["current_activity"] = selected_activity
	_agents[ai_id] = state

	# 检查是否发生变化
	var changed := force_emit or not _are_activities_equal(previous, selected_activity)
	if changed:
		agents[ai_id]["last_activity_change"] = now_minutes
		activity_changed.emit(ai_id, selected_activity)
		_emit_bus_activity(ai_id, selected_activity)

		# 记录活动历史
		_record_activity_change(ai_id, previous, selected_activity)

		# 处理待办活动
		_process_completed_activities(ai_id)

func _resolve_current_activity(now_minutes: int, agenda: Array, overrides: Dictionary, pending: Array) -> Dictionary:
	"""解析当前应该进行的活动"""
	# 1. 检查手动覆盖
	if overrides.has("active"):
		var manual := overrides["active"]
		if manual is Dictionary:
			# 检查是否在覆盖时间范围内
			var override_start = manual.get("start_minute", 0)
			var override_end = manual.get("end_minute", 1440)
			if now_minutes >= override_start and now_minutes < override_end:
				return _hydrate_activity_entry(manual)

	# 2. 检查待办活动（高优先级优先）
	for activity in pending:
		if activity.get("start_minute", 0) <= now_minutes and now_minutes < activity.get("end_minute", 1440):
			return _hydrate_activity_entry(activity)

	# 3. 检查常规日程
	for entry in agenda:
		var start := entry.get("start_minute", 0)
		var end := entry.get("end_minute", 0)
		if now_minutes >= start and now_minutes < end:
			return _hydrate_activity_entry(entry)

	# 4. 返回默认活动
	return DEFAULT_ACTIVITY.duplicate(true)

func _resolve_activity(now_minutes: int, agenda: Array, overrides: Dictionary, pending: Array) -> Dictionary:
	"""解析活动（兼容旧版本）"""
	return _resolve_current_activity(now_minutes, agenda, overrides, pending)

# ========================================
# 日程构建
# ========================================

func _build_daily_agenda(career_id: String, preferences: Dictionary = {}) -> Array:
	"""构建日程安排"""
	if _career_system == null:
		return [DEFAULT_ACTIVITY.duplicate(true)]

	var is_weekend := false
	if _time_system:
		is_weekend = _time_system.is_weekend()

	# 获取基础职业日程
	var raw_schedule := _career_system.get_schedule_for_career(career_id, is_weekend)
	if raw_schedule.is_empty():
		raw_schedule = _career_system.get_schedule_for_career("office_worker", is_weekend)

	# 转换为内部格式
	var agenda: Array = []
	var work_hours = _career_system.get_work_hours(career_id)

	for i in range(raw_schedule.size()):
		var item := raw_schedule[i]
		if typeof(item) != TYPE_DICTIONARY:
			continue

		var activity := _create_activity_from_schedule_item(item, i, career_id, work_hours)
		if not activity.is_empty():
			# 应用个人偏好
			_apply_preferences(activity, preferences)
			agenda.append(activity)

	# 如果仍为空，返回默认活动
	if agenda.is_empty():
		agenda.append(DEFAULT_ACTIVITY.duplicate(true))
	else:
		# 按开始时间排序并检查冲突
		agenda.sort_custom(func(a, b): return a["start_minute"] < b["start_minute"])
		_resolve_schedule_conflicts(agenda)

	return agenda

func _create_activity_from_schedule_item(item: Dictionary, index: int, career_id: String, work_hours: Dictionary) -> Dictionary:
	"""从日程项创建活动"""
	var start_time := item.get("start", "09:00")
	var end_time := item.get("end", "18:00")
	var start_minutes := _time_to_minutes(start_time)
	var end_minutes := _time_to_minutes(end_time)

	# 验证时间合理性
	if end_minutes <= start_minutes:
		end_minutes = min(start_minutes + 60, 1440)

	var activity_type := item.get("activity", "work")
	return {
		"id": item.get("id", "%s_%d" % [career_id, index]),
		"activity": activity_type,
		"location_type": item.get("location_type", "OFFICE"),
		"location_enum": _resolve_location_enum(item.get("location_type", "OFFICE")),
		"start": start_time,
		"end": end_time,
		"start_minute": start_minutes,
		"end_minute": end_minutes,
		"priority": ACTIVITY_PRIORITIES.get(activity_type, 5),
		"metadata": item.get("metadata", {}),
		"is_default": false
	}

func _apply_preferences(activity: Dictionary, preferences: Dictionary):
	"""应用个人偏好到活动"""
	# 根据偏好调整优先级
	if preferences.has("work_priority") and activity.activity.begins_with("work"):
		activity.priority += preferences["work_priority"]

	if preferences.has("social_priority") and activity.activity in ["social", "coffee", "lunch_with_colleagues"]:
		activity.priority += preferences["social_priority"]

	# 根据偏好调整地点
	if preferences.has("work_location_preference") and activity.location_type == "OFFICE":
		var pref_loc = preferences["work_location_preference"]
		if pref_loc in LOCATION_TYPE_ALIASES:
			activity.location_type = pref_loc

# ========================================
# 工具函数
# ========================================

func _time_to_minutes(time_string: String) -> int:
	"""时间字符串转换为分钟"""
	var parts := time_string.split(":")
	if parts.size() != 2:
		return 0
	var hour := int(parts[0])
	var minute := int(parts[1])
	if hour == 24 and minute == 0:
		return 1440
	return clamp(hour * 60 + minute, 0, 1440)

func _current_timestamp() -> int:
	"""获取当前时间戳（分钟）"""
	if _time_system:
		return int(_time_system.get_current_hour()) * 60 + int(_time_system.get_current_minute())
	var now := Time.get_datetime_dict_from_system()
	return now.hour * 60 + now.minute

func _calculate_end_time(start_time: String, duration: float) -> String:
	"""计算结束时间"""
	var start_minutes = _time_to_minutes(start_time)
	var end_minutes = start_minutes + int(duration * 60)
	end_minutes = min(end_minutes, 1440)

	var end_hour = end_minutes / 60
	var end_minute = end_minutes % 60
	return "%02d:%02d" % [end_hour, end_minute]

func _time_ranges_overlap(start1: int, end1: int, start2: int, end2: int) -> bool:
	"""检查时间范围是否重叠"""
	return not (end1 <= start2 or end2 <= start1)

def _are_activities_equal(a: Dictionary, b: Dictionary) -> bool:
	return a.get("activity", "") == b.get("activity", "") \
		and a.get("location_type", "") == b.get("location_type", "") \
		and a.get("start_minute", 0) == b.get("start_minute", 0) \
		and a.get("end_minute", 0) == b.get("end_minute", 0)

# ========================================
# 活动验证和水化
# ========================================

func _validate_and_hydrate_activity(activity: Dictionary) -> Dictionary:
	"""验证和水化活动数据"""
	if not activity is Dictionary:
		return {}

	if not activity.has("activity"):
		return {}

	return _hydrate_activity_entry(activity)

func _hydrate_activity_entry(entry: Dictionary) -> Dictionary:
	"""水化活动条目"""
	var copy := entry.duplicate(true)

	if not copy.has("location_type"):
		copy["location_type"] = "OFFICE"
	if not copy.has("location_enum"):
		copy["location_enum"] = _resolve_location_enum(copy["location_type"])
	if not copy.has("start_minute") and copy.has("start"):
		copy["start_minute"] = _time_to_minutes(copy["start"])
	if not copy.has("end_minute") and copy.has("end"):
		copy["end_minute"] = _time_to_minutes(copy["end"])
	if not copy.has("priority"):
		copy["priority"] = ACTIVITY_PRIORITIES.get(copy.get("activity", "idle"), 0)

	return copy

def _resolve_location_enum(location_type: String) -> int:
	var upper := location_type.to_upper()
	if LOCATION_TYPE_ALIASES.has(upper):
		return LOCATION_TYPE_ALIASES[upper]
	return LocationManager.LocationType.OTHER

# ========================================
# 活动管理
# ========================================

func _check_activity_conflicts(ai_id: String):
	"""检查活动冲突"""
	if not _agents.has(ai_id):
		return

	var agent = _agents[ai_id]
	var agenda = agent["agenda"]
	var pending = _pending_activities.get(ai_id, [])
	var conflicts = []

	# 检查待办活动与日程的冲突
	for pending_activity in pending:
		var pending_start = pending_activity.get("start_minute", 0)
		var pending_end = pending_activity.get("end_minute", 0)
		var pending_priority = pending_activity.get("priority", 0)

		for scheduled_activity in agenda:
			var scheduled_start = scheduled_activity.get("start_minute", 0)
			var scheduled_end = scheduled_activity.get("end_minute", 0)
			var scheduled_priority = scheduled_activity.get("priority", 0)

			# 检查时间重叠
			if _time_ranges_overlap(pending_start, pending_end, scheduled_start, scheduled_end):
				# 如果待办活动优先级更高，产生冲突
				if pending_priority > scheduled_priority:
					conflicts.append({
						"pending": pending_activity,
						"scheduled": scheduled_activity,
						"conflict_type": "time_overlap"
					})

	if conflicts.size() > 0:
		schedule_conflict.emit(ai_id, {
			"conflicts": conflicts,
			"ai_id": ai_id
		})

func _resolve_schedule_conflicts(agenda: Array):
	"""解决日程冲突"""
	# 简单的冲突解决：移除重叠的低优先级活动
	var filtered_agenda = []

	for i in range(agenda.size()):
		var current = agenda[i]
		var current_start = current.get("start_minute", 0)
		var current_end = current.get("end_minute", 0)
		var current_priority = current.get("priority", 0)

		var has_conflict = false
		for j in range(i + 1, agenda.size()):
			var other = agenda[j]
			var other_start = other.get("start_minute", 0)
			var other_end = other.get("end_minute", 0)
			var other_priority = other.get("priority", 0)

			if _time_ranges_overlap(current_start, current_end, other_start, other_end):
				# 保留高优先级的，移除低优先级的
				if current_priority < other_priority:
					has_conflict = true
					break

		if not has_conflict:
			filtered_agenda.append(current)

	return filtered_agenda

func _process_completed_activities(ai_id: String):
	"""处理已完成的待办活动"""
	if not _pending_activities.has(ai_id):
		return

	var now = _current_timestamp()
	var pending = _pending_activities.get(ai_id, [])
	var remaining = []

	for activity in pending:
		if activity.get("end_minute", 0) > now:
			remaining.append(activity)

	_pending_activities[ai_id] = remaining

def _record_activity_change(ai_id: String, old_activity: Dictionary, new_activity: Dictionary):
	"""记录活动变化"""
	if not _activity_history.has(ai_id):
		_activity_history[ai_id] = []

	var history_entry = {
		"timestamp": _current_timestamp(),
		"old_activity": old_activity.duplicate(true),
		"new_activity": new_activity.duplicate(true),
		"change_type": "activity_change"
	}

	var history = _activity_history[ai_id]
	history.append(history_entry)

	# 保持历史记录在合理范围内
	if history.size() > 50:
		history.pop_front()

	_activity_history[ai_id] = history

def _convert_task_to_activity(task: Dictionary) -> Dictionary:
	"""将任务转换为活动"""
	if not task.has("activity"):
		return {}

	return {
		"activity": task.get("activity", "work"),
		"start": task.get("start_time", "09:00"),
		"end": task.get("end_time", "10:00"),
		"location_type": task.get("location", "OFFICE"),
		"priority": task.get("priority", 8),  # 任务通常高优先级
		"metadata": {
			"task_id": task.get("id", ""),
			"task_type": task.get("type", "work")
		}
	}

def _schedule_override_clear(ai_id: String, delay: float):
	"""计划 clearing override"""
	# 简化实现，实际应该使用计时器
	await get_tree().create_timer(delay).timeout
	if _agents.has(ai_id):
		clear_manual_override(ai_id)

# ========================================
# 事件发送
# ========================================

func _emit_bus_activity(ai_id: String, activity: Dictionary) -> void:
	"""发送活动变化事件到EventBus"""
	if _event_bus == null:
		return

	_event_bus.emit_event("schedule.activity_changed", {
		"ai_id": ai_id,
		"activity": activity
	})

# ========================================
# 保存/加载
# ========================================

func save_state() -> Dictionary:
	"""保存日程系统状态"""
	return {
		"agents": _agents,
		"activity_history": _activity_history,
		"pending_activities": _pending_activities,
		"timestamp": _current_timestamp()
	}

func load_state(state: Dictionary):
	"""加载日程系统状态"""
	_agents = state.get("agents", {})
	_activity_history = state.get("activity_history", {})
	_pending_activities = state.get("pending_activities", {})
	print("[ScheduleManager] 日程数据已加载，共%d个代理" % _agents.size())

# ========================================
# 调试信息
# ========================================

func get_debug_info() -> String:
	"""获取调试信息"""
	var info = "[ScheduleManager] 调试信息:\n"
	info += "已注册代理: %d\n" % _agents.size()

	for ai_id in _agents.keys():
		var agent = _agents[ai_id]
		var current = agent.get("current_activity", {})
		info += "  %s (%s): %s @ %s\n" % [
			ai_id,
			agent.get("character_name", ""),
			current.get("activity", "idle"),
			current.get("location_type", "HOME")
		]

	return info