extends Node

class_name TaskSystem

signal task_assigned(ai_id: String, task: Dictionary)
signal task_completed(ai_id: String, task: Dictionary, result: Dictionary)
signal task_failed(ai_id: String, task: Dictionary, reason: String)
signal task_cancelled(ai_id: String, task: Dictionary, reason: String)
signal task_list_refreshed(ai_id: String, tasks: Array)

const TASK_TEMPLATE_PATH := "res://data/tasks/task_templates.json"
const MAX_ACTIVE_TASKS := 8
const PERFORMANCE_DECAY_HOURS := 168   # one week

enum TaskState {
	ACTIVE,
	COMPLETED,
	FAILED,
	CANCELLED
}

var _templates: Dictionary = {}
var _active_tasks: Dictionary = {}      # ai_id -> Array[Dictionary]
var _task_history: Dictionary = {}      # ai_id -> Array[Dictionary]
var _performance_snapshot: Dictionary = {}  # ai_id -> Dictionary metrics

var _career_system: CareerSystem = null
var _schedule_manager: ScheduleManager = null
var _time_system: TimeSystem = null
var _event_bus: EventBus = null

func _ready() -> void:
	_load_templates()

	_career_system = get_node_or_null("/root/CareerSystem")
	_schedule_manager = get_node_or_null("/root/ScheduleManager")
	_time_system = get_node_or_null("/root/TimeSystem")
	_event_bus = get_node_or_null("/root/EventBus")

	if _event_bus:
		_event_bus.subscribe("task.request_refresh", self, "_on_refresh_request")

	if _time_system:
		_time_system.hour_changed.connect(_on_hour_changed)
		_time_system.day_changed.connect(_on_day_changed)

# -------------------------------------------------------------------
# Task API
# -------------------------------------------------------------------

func assign_task(ai_id: String, task_payload: Dictionary) -> Dictionary:
	if ai_id.strip_edges().is_empty():
		push_warning("[TaskSystem] assign_task called with empty ai_id.")
		return {}

	var task := _sanitize_task(task_payload)
	if task.is_empty():
		return {}

	var current := _active_tasks.get(ai_id, [])
	if current.size() >= MAX_ACTIVE_TASKS:
		push_warning("[TaskSystem] %s has reached max active tasks." % ai_id)
		return {}

	current.append(task)
	_active_tasks[ai_id] = current
	task_assigned.emit(ai_id, task)
	task_list_refreshed.emit(ai_id, current)

	_emit_task_event("task.assigned", ai_id, task)
	return task

func auto_assign_for_ai(ai_id: String, max_count: int = 3) -> void:
	var career_id := ""
	if _career_system:
		career_id = _career_system.get_registered_career(ai_id)

	var generated := _generate_tasks_for_career(career_id, max_count)
	for task in generated:
		assign_task(ai_id, task)

func complete_task(ai_id: String, task_id: String, result: Dictionary = {}) -> bool:
	return _close_task(ai_id, task_id, TaskState.COMPLETED, result.get("reason", ""), result)

func fail_task(ai_id: String, task_id: String, reason: String = "") -> bool:
	return _close_task(ai_id, task_id, TaskState.FAILED, reason)

func cancel_task(ai_id: String, task_id: String, reason: String = "") -> bool:
	return _close_task(ai_id, task_id, TaskState.CANCELLED, reason)

func get_active_tasks(ai_id: String) -> Array:
	return _active_tasks.get(ai_id, []).duplicate(true)

func get_task_history(ai_id: String) -> Array:
	return _task_history.get(ai_id, []).duplicate(true)

func refresh_daily_tasks(ai_id: String, desired_count: int = 5) -> void:
	var active := get_active_tasks(ai_id)
	while active.size() < desired_count:
		var injected := _generate_tasks_for_career(_career_system.get_registered_career(ai_id), 1)
		if injected.is_empty():
			break
		active.append(injected[0])
	_assign_task_list(ai_id, active)

func clear_tasks(ai_id: String) -> void:
	_active_tasks.erase(ai_id)
	task_list_refreshed.emit(ai_id, [])

# -------------------------------------------------------------------
# Weekly performance interface (for EconomySystem)
# -------------------------------------------------------------------

func get_weekly_performance(ai_id: String) -> Dictionary:
	var snapshot := _performance_snapshot.get(ai_id, {})
	if snapshot.is_empty():
		return {
			"completion_rate": 0.8,
			"average_quality": 0.75,
			"punctuality_rate": 0.85,
			"late_count": 0,
			"early_leave_count": 0,
			"overtime_hours": 0.0,
			"work_tasks_completed": 0,
			"work_tasks_total": 0
		}
	return snapshot.duplicate(true)

func reset_weekly_performance(ai_id: String) -> void:
	_performance_snapshot.erase(ai_id)

# -------------------------------------------------------------------
# Events & signals
# -------------------------------------------------------------------

func _on_hour_changed(_hour: int) -> void:
	_check_deadlines()

func _on_day_changed(_day: int, _season: String) -> void:
	_decay_performance()

func _on_refresh_request(payload: Dictionary) -> void:
	if payload.has("ai_id"):
		refresh_daily_tasks(payload["ai_id"])
	else:
		for ai_id in _active_tasks.keys():
			refresh_daily_tasks(ai_id)

# -------------------------------------------------------------------
# Internals
# -------------------------------------------------------------------

func _load_templates() -> void:
	var file := FileAccess.open(TASK_TEMPLATE_PATH, FileAccess.READ)
	if file == null:
		push_error("[TaskSystem] 无法读取任务模板 %s" % TASK_TEMPLATE_PATH)
		_templates = {}
		return

	var text := file.get_as_text()
	file.close()

	var result := JSON.parse_string(text)
	if typeof(result) != TYPE_DICTIONARY:
		push_error("[TaskSystem] 任务模板格式错误")
		_templates = {}
		return
	_templates = result

func _sanitize_task(task_payload: Dictionary) -> Dictionary:
	if not task_payload.has("id"):
		push_warning("[TaskSystem] 任务必须包含 id 字段")
		return {}

	var timestamp := _current_timestamp()
	var deadline_minutes := int(task_payload.get("deadline_offset_minutes", 240))
	var deadline := timestamp + (deadline_minutes * 60)

	var task := {
		"id": task_payload["id"],
		"name": task_payload.get("name", task_payload["id"]),
		"description": task_payload.get("description", ""),
		"state": TaskState.ACTIVE,
		"priority": task_payload.get("default_priority", 5),
		"tags": task_payload.get("tags", []),
		"created_at": timestamp,
		"deadline": deadline,
		"estimated_minutes": task_payload.get("estimated_minutes", 60),
		"success_metrics": task_payload.get("success_metrics", {}),
		"context": task_payload.get("context", {}),
		"domain": task_payload.get("domain", "work")
	}
	return task

func _generate_tasks_for_career(career_id: String, count: int) -> Array:
	var generated: Array = []
	var categories := ["work", "daily", "social", "growth"]
	if career_id == "":
		career_id = "default"

	for category in categories:
		if generated.size() >= count:
			break
		var pool: Array = _templates.get(category, [])
		if pool.is_empty():
			continue

		var filtered := []
		for task in pool:
			var allowed := task.get("career_ids", [])
			if allowed.is_empty() or allowed.has(career_id):
				filtered.append(task)
		if filtered.is_empty():
			filtered = pool

		filtered.shuffle()
		for candidate in filtered:
			if generated.size() >= count:
				break
			generated.append(_sanitize_task(candidate))
	return generated

func _close_task(ai_id: String, task_id: String, new_state: TaskState, reason: String = "", result: Dictionary = {}) -> bool:
	if not _active_tasks.has(ai_id):
		return false

	var tasks: Array = _active_tasks[ai_id]
	var removed := false
	for i in range(tasks.size()):
		var task := tasks[i]
		if task.get("id", "") != task_id:
			continue
		tasks.remove_at(i)
		task["state"] = new_state
		task["closed_at"] = _current_timestamp()
		task["reason"] = reason
		task["result"] = result
		_record_history(ai_id, task)
		_update_performance(ai_id, task)
		_active_tasks[ai_id] = tasks

		match new_state:
			TaskState.COMPLETED:
				task_completed.emit(ai_id, task, result)
				_emit_task_event("task.completed", ai_id, task, result)
			TaskState.FAILED:
				task_failed.emit(ai_id, task, reason)
				_emit_task_event("task.failed", ai_id, task, { "reason": reason })
			TaskState.CANCELLED:
				task_cancelled.emit(ai_id, task, reason)
				_emit_task_event("task.cancelled", ai_id, task, { "reason": reason })
		removed = true
		break

	if removed:
		task_list_refreshed.emit(ai_id, tasks)
	return removed

func _record_history(ai_id: String, task: Dictionary) -> void:
	var history := _task_history.get(ai_id, [])
	history.append(task)
	_task_history[ai_id] = history

func _update_performance(ai_id: String, task: Dictionary) -> void:
	var snapshot := _performance_snapshot.get(ai_id, {
		"completion_rate": 0.0,
		"average_quality": 0.0,
		"punctuality_rate": 0.0,
		"late_count": 0,
		"early_leave_count": 0,
		"overtime_hours": 0.0,
		"work_tasks_completed": 0,
		"work_tasks_total": 0,
		"_samples": 0
	})

	var now := _current_timestamp()
	var created := int(task.get("created_at", now))
	var deadline := int(task.get("deadline", now))
	var closed := int(task.get("closed_at", now))
	var domain := task.get("domain", "work")
	var success := task.get("state", TaskState.FAILED) == TaskState.COMPLETED

	if domain == "work":
		snapshot["work_tasks_total"] += 1
		if success:
			snapshot["work_tasks_completed"] += 1

	if success:
		var punctual := 1.0 if closed <= deadline else 0.0
		var duration_hours := float(task.get("estimated_minutes", 60)) / 60.0
		snapshot["_samples"] += 1
		var quality := task.get("result", {}).get("quality_score", task.get("success_metrics", {}).get("quality_score", 0.8))

		var completion_rate := float(snapshot["work_tasks_completed"]) / max(1.0, float(snapshot["work_tasks_total"]))
		snapshot["completion_rate"] = clamp(completion_rate, 0.0, 1.0)

		snapshot["average_quality"] = _running_average(snapshot["average_quality"], quality, snapshot["_samples"])
		snapshot["punctuality_rate"] = _running_average(snapshot["punctuality_rate"], punctual, snapshot["_samples"])

		if closed > deadline:
			var extra := float(closed - deadline) / 3600.0
			snapshot["overtime_hours"] += max(0.0, extra)
	else:
		snapshot["punctuality_rate"] = _running_average(snapshot["punctuality_rate"], 0.0, snapshot["_samples"] + 1)

	_performance_snapshot[ai_id] = snapshot

func _check_deadlines() -> void:
	var now := _current_timestamp()
	for ai_id in _active_tasks.keys():
		var tasks := _active_tasks[ai_id]
		for task in tasks:
			if task.get("state", TaskState.ACTIVE) != TaskState.ACTIVE:
				continue
			var deadline := int(task.get("deadline", now))
			if now > deadline + 3600:  # allow 1 hour grace
				fail_task(ai_id, task["id"], "deadline_missed")

func _assign_task_list(ai_id: String, tasks: Array) -> void:
	_active_tasks[ai_id] = tasks
	task_list_refreshed.emit(ai_id, tasks)

func _decay_performance() -> void:
	var cutoff := _current_timestamp() - PERFORMANCE_DECAY_HOURS * 3600
	for ai_id in _task_history.keys():
		var filtered := []
		for entry in _task_history[ai_id]:
			if int(entry.get("closed_at", 0)) >= cutoff:
				filtered.append(entry)
		_task_history[ai_id] = filtered

func _running_average(current: float, new_value: float, samples: int) -> float:
	if samples <= 1:
		return clamp(new_value, 0.0, 1.0)
	return clamp(((current * float(samples - 1)) + new_value) / float(samples), 0.0, 1.0)

func _current_timestamp() -> int:
	if _time_system:
		return _time_system.get_current_timestamp()
	return Time.get_unix_time_from_system()

func _emit_task_event(event_name: String, ai_id: String, task: Dictionary, extra: Dictionary = {}) -> void:
	if _event_bus == null:
		return
	var payload := {
		"ai_id": ai_id,
		"task": task,
		"extra": extra
	}
	_event_bus.emit_event(event_name, payload)

# ========================================
# Phase D: 关系系统集成
# ========================================

func can_collaborate(ai_a: String, ai_b: String) -> bool:
	"""检查两个AI是否可以合作完成任务

	Args:
		ai_a: AI A的ID
		ai_b: AI B的ID

	Returns:
		true表示可以合作, false表示不能
	"""
	var relationship_manager = get_node_or_null("/root/RelationshipManager")
	var conflict_system = get_node_or_null("/root/ConflictSystem")

	if not relationship_manager or not conflict_system:
		return true  # 如果系统未加载,允许合作

	# 检查是否在冲突冷却期
	if not conflict_system.can_interact(ai_a, ai_b):
		print("[TaskSystem] %s和%s处于冲突冷却期,无法合作" % [ai_a, ai_b])
		return false

	# 检查关系状态
	var relationship = relationship_manager.get_relationship(ai_a, ai_b)
	if not relationship.is_empty():
		var trust = relationship.get("trust", 0.0)
		var respect = relationship.get("respect", 0.0)

		# 如果信任度或尊重度太低,限制合作
		if trust < -50 or respect < -50:
			print("[TaskSystem] %s和%s关系不足以合作(信任: %.0f, 尊重: %.0f)" % [ai_a, ai_b, trust, respect])
			return false

	return true

func get_collaboration_bonus(ai_a: String, ai_b: String) -> float:
	"""获取合作加成系数

	基于两个AI的关系好坏,返回任务完成效率加成

	Args:
		ai_a: AI A的ID
		ai_b: AI B的ID

	Returns:
		加成系数 (0.5-1.5, 1.0为基准)
	"""
	var relationship_manager = get_node_or_null("/root/RelationshipManager")
	if not relationship_manager:
		return 1.0

	var relationship = relationship_manager.get_relationship(ai_a, ai_b)
	if relationship.is_empty():
		return 1.0

	var trust = relationship.get("trust", 0.0)
	var respect = relationship.get("respect", 0.0)

	# 综合信任和尊重计算加成
	var avg = (trust + respect) / 2.0

	# 映射到 0.5-1.5 范围
	# trust+respect 平均值: -100 -> 0.5, 0 -> 1.0, 100 -> 1.5
	var bonus = 1.0 + (avg / 200.0)
	return clamp(bonus, 0.5, 1.5)

func update_relationship_after_task_collaboration(ai_a: String, ai_b: String, task_success: bool):
	"""任务合作后更新关系

	成功的合作会增加信任和尊重,失败会降低

	Args:
		ai_a: AI A的ID
		ai_b: AI B的ID
		task_success: 任务是否成功
	"""
	var relationship_manager = get_node_or_null("/root/RelationshipManager")
	if not relationship_manager:
		return

	var changes = {}

	if task_success:
		# 成功合作增加信任和尊重
		changes = {
			"trust": 5.0,
			"respect": 3.0,
			"affection": 2.0
		}
		relationship_manager.modify_relationship(ai_a, ai_b, changes, "成功完成合作任务")
		print("[TaskSystem] 合作成功: %s <-> %s 关系提升" % [ai_a, ai_b])
	else:
		# 失败的合作降低信任
		changes = {
			"trust": -3.0,
			"respect": -2.0
		}
		relationship_manager.modify_relationship(ai_a, ai_b, changes, "合作任务失败")
		print("[TaskSystem] 合作失败: %s <-> %s 关系下降" % [ai_a, ai_b])

func check_task_conflict_potential(ai_a: String, ai_b: String, task: Dictionary) -> bool:
	"""检查任务是否可能引发冲突

	基于任务类型和当前关系状态判断

	Args:
		ai_a: AI A的ID
		ai_b: AI B的ID
		task: 任务数据

	Returns:
		true表示可能引发冲突
	"""
	var relationship_manager = get_node_or_null("/root/RelationshipManager")
	if not relationship_manager:
		return false

	var relationship = relationship_manager.get_relationship(ai_a, ai_b)
	if relationship.is_empty():
		return false

	var trust = relationship.get("trust", 0.0)
	var task_category = task.get("category", "")

	# 高风险任务类型
	var high_risk_categories = ["milestone", "urgent", "critical"]

	# 如果信任度低且任务是高风险类型,可能引发冲突
	if trust < 20 and task_category in high_risk_categories:
		print("[TaskSystem] 警告: %s和%s合作高风险任务,可能引发冲突" % [ai_a, ai_b])
		return true

	return false
