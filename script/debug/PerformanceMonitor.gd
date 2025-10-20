extends Node

# ========================================
# PerformanceMonitor - 性能监控系统
# ========================================
#
# 功能:
# - 实时FPS监控
# - 内存使用追踪
# - LLM API调用统计
# - 系统状态监控
# - 性能数据导出
#
# ========================================

# 性能指标数据
var _metrics: Dictionary = {
	# FPS数据
	"fps_history": [],
	"fps_max_samples": 120,  # 保留最近2分钟(60fps)

	# 内存数据
	"memory_history": [],
	"memory_max_samples": 60,  # 保留最近1分钟

	# 节点数据
	"node_count_history": [],

	# LLM统计
	"llm_total_calls": 0,
	"llm_success_count": 0,
	"llm_fail_count": 0,
	"llm_total_time": 0.0,  # 总响应时间(秒)
	"llm_total_tokens": 0,
	"llm_calls_by_character": {},  # 按角色统计

	# 系统状态
	"active_dialogs": 0,
	"active_tasks": 0,
	"active_conflicts": 0,
	"total_transactions": 0,

	# 时间戳
	"start_time": 0.0,
	"last_update": 0.0
}

# 性能警告阈值
const FPS_WARNING_THRESHOLD = 30
const FPS_CRITICAL_THRESHOLD = 15
const MEMORY_WARNING_MB = 512
const MEMORY_CRITICAL_MB = 1024

# 信号
signal fps_warning(current_fps: float)
signal fps_critical(current_fps: float)
signal memory_warning(memory_mb: float)
signal performance_data_updated()

func _ready():
	"""初始化性能监控"""
	_metrics.start_time = Time.get_ticks_msec() / 1000.0
	_metrics.last_update = _metrics.start_time

	# 每秒更新一次
	var timer = Timer.new()
	timer.wait_time = 1.0
	timer.timeout.connect(_on_update_timer)
	add_child(timer)
	timer.start()

	print("[PerformanceMonitor] 性能监控系统初始化完成")

func _on_update_timer():
	"""定时更新性能数据"""
	# 记录FPS
	var fps = Engine.get_frames_per_second()
	record_fps(fps)

	# 记录内存
	var memory_mb = OS.get_static_memory_usage() / 1024.0 / 1024.0
	record_memory(memory_mb)

	# 记录节点数量
	var node_count = _count_total_nodes()
	record_node_count(node_count)

	# 检查警告
	_check_performance_warnings(fps, memory_mb)

	# 发送更新信号
	performance_data_updated.emit()

	_metrics.last_update = Time.get_ticks_msec() / 1000.0

# ========================================
# FPS监控
# ========================================

func record_fps(fps: float):
	"""记录FPS数据

	Args:
		fps: 当前FPS值
	"""
	_metrics.fps_history.append(fps)

	# 限制历史记录数量
	if _metrics.fps_history.size() > _metrics.fps_max_samples:
		_metrics.fps_history.pop_front()

func get_current_fps() -> float:
	"""获取当前FPS

	Returns:
		FPS值
	"""
	return Engine.get_frames_per_second()

func get_average_fps(samples: int = 60) -> float:
	"""获取平均FPS

	Args:
		samples: 采样数量

	Returns:
		平均FPS
	"""
	if _metrics.fps_history.is_empty():
		return 0.0

	var count = min(samples, _metrics.fps_history.size())
	var sum = 0.0

	for i in range(_metrics.fps_history.size() - count, _metrics.fps_history.size()):
		sum += _metrics.fps_history[i]

	return sum / count

func get_min_fps(samples: int = 60) -> float:
	"""获取最低FPS

	Args:
		samples: 采样数量

	Returns:
		最低FPS
	"""
	if _metrics.fps_history.is_empty():
		return 0.0

	var count = min(samples, _metrics.fps_history.size())
	var min_fps = 999.0

	for i in range(_metrics.fps_history.size() - count, _metrics.fps_history.size()):
		min_fps = min(min_fps, _metrics.fps_history[i])

	return min_fps

func get_fps_history() -> Array:
	"""获取FPS历史记录

	Returns:
		FPS数组
	"""
	return _metrics.fps_history.duplicate()

# ========================================
# 内存监控
# ========================================

func record_memory(memory_mb: float):
	"""记录内存使用

	Args:
		memory_mb: 内存使用量(MB)
	"""
	_metrics.memory_history.append(memory_mb)

	# 限制历史记录数量
	if _metrics.memory_history.size() > _metrics.memory_max_samples:
		_metrics.memory_history.pop_front()

func get_current_memory_mb() -> float:
	"""获取当前内存使用(MB)

	Returns:
		内存使用量
	"""
	return OS.get_static_memory_usage() / 1024.0 / 1024.0

func get_memory_history() -> Array:
	"""获取内存历史记录

	Returns:
		内存数组(MB)
	"""
	return _metrics.memory_history.duplicate()

# ========================================
# 节点计数
# ========================================

func record_node_count(count: int):
	"""记录节点数量

	Args:
		count: 节点数量
	"""
	_metrics.node_count_history.append(count)

	# 限制历史记录数量
	if _metrics.node_count_history.size() > _metrics.memory_max_samples:
		_metrics.node_count_history.pop_front()

func get_current_node_count() -> int:
	"""获取当前节点数量

	Returns:
		节点数量
	"""
	return _count_total_nodes()

func _count_total_nodes() -> int:
	"""统计所有节点数量

	Returns:
		节点总数
	"""
	var root = get_tree().root
	return _count_children_recursive(root)

func _count_children_recursive(node: Node) -> int:
	"""递归统计子节点

	Args:
		node: 起始节点

	Returns:
		子节点总数
	"""
	var count = 1  # 计算自己
	for child in node.get_children():
		count += _count_children_recursive(child)
	return count

# ========================================
# LLM API监控
# ========================================

func record_llm_call(character_name: String, success: bool, response_time: float, tokens: int = 0):
	"""记录LLM API调用

	Args:
		character_name: 角色名称
		success: 是否成功
		response_time: 响应时间(秒)
		tokens: Token数量
	"""
	_metrics.llm_total_calls += 1

	if success:
		_metrics.llm_success_count += 1
	else:
		_metrics.llm_fail_count += 1

	_metrics.llm_total_time += response_time
	_metrics.llm_total_tokens += tokens

	# 按角色统计
	if not _metrics.llm_calls_by_character.has(character_name):
		_metrics.llm_calls_by_character[character_name] = {
			"total": 0,
			"success": 0,
			"fail": 0,
			"total_time": 0.0,
			"tokens": 0
		}

	var char_stats = _metrics.llm_calls_by_character[character_name]
	char_stats.total += 1
	if success:
		char_stats.success += 1
	else:
		char_stats.fail += 1
	char_stats.total_time += response_time
	char_stats.tokens += tokens

func get_llm_total_calls() -> int:
	"""获取LLM总调用次数

	Returns:
		调用次数
	"""
	return _metrics.llm_total_calls

func get_llm_success_rate() -> float:
	"""获取LLM成功率

	Returns:
		成功率(0.0-1.0)
	"""
	if _metrics.llm_total_calls == 0:
		return 0.0
	return float(_metrics.llm_success_count) / float(_metrics.llm_total_calls)

func get_llm_average_response_time() -> float:
	"""获取LLM平均响应时间

	Returns:
		平均响应时间(秒)
	"""
	if _metrics.llm_total_calls == 0:
		return 0.0
	return _metrics.llm_total_time / float(_metrics.llm_total_calls)

func get_llm_total_tokens() -> int:
	"""获取LLM总Token消耗

	Returns:
		Token总数
	"""
	return _metrics.llm_total_tokens

func get_llm_stats_by_character() -> Dictionary:
	"""获取按角色分组的LLM统计

	Returns:
		角色统计字典
	"""
	return _metrics.llm_calls_by_character.duplicate(true)

# ========================================
# 系统状态监控
# ========================================

func update_active_dialogs(count: int):
	"""更新活跃对话数量

	Args:
		count: 对话数量
	"""
	_metrics.active_dialogs = count

func update_active_tasks(count: int):
	"""更新活跃任务数量

	Args:
		count: 任务数量
	"""
	_metrics.active_tasks = count

func update_active_conflicts(count: int):
	"""更新活跃冲突数量

	Args:
		count: 冲突数量
	"""
	_metrics.active_conflicts = count

func record_transaction():
	"""记录经济交易"""
	_metrics.total_transactions += 1

func get_system_status() -> Dictionary:
	"""获取系统状态概览

	Returns:
		状态字典
	"""
	return {
		"active_dialogs": _metrics.active_dialogs,
		"active_tasks": _metrics.active_tasks,
		"active_conflicts": _metrics.active_conflicts,
		"total_transactions": _metrics.total_transactions
	}

# ========================================
# 综合性能报告
# ========================================

func get_performance_summary() -> Dictionary:
	"""获取性能摘要

	Returns:
		性能摘要字典
	"""
	var uptime = (Time.get_ticks_msec() / 1000.0) - _metrics.start_time

	return {
		# 运行时间
		"uptime_seconds": uptime,
		"uptime_formatted": _format_uptime(uptime),

		# FPS
		"current_fps": get_current_fps(),
		"average_fps": get_average_fps(),
		"min_fps": get_min_fps(),

		# 内存
		"current_memory_mb": get_current_memory_mb(),

		# 节点
		"current_node_count": get_current_node_count(),

		# LLM
		"llm_total_calls": get_llm_total_calls(),
		"llm_success_rate": get_llm_success_rate(),
		"llm_avg_response_time": get_llm_average_response_time(),
		"llm_total_tokens": get_llm_total_tokens(),

		# 系统
		"system_status": get_system_status()
	}

func export_metrics_csv() -> String:
	"""导出性能指标为CSV格式

	Returns:
		CSV字符串
	"""
	var csv = "Timestamp,FPS,Memory(MB),NodeCount\n"

	var min_size = min(
		_metrics.fps_history.size(),
		min(_metrics.memory_history.size(), _metrics.node_count_history.size())
	)

	for i in range(min_size):
		csv += "%d,%.2f,%.2f,%d\n" % [
			i,
			_metrics.fps_history[i],
			_metrics.memory_history[i],
			_metrics.node_count_history[i]
		]

	return csv

func reset_metrics():
	"""重置所有指标"""
	_metrics.fps_history.clear()
	_metrics.memory_history.clear()
	_metrics.node_count_history.clear()

	_metrics.llm_total_calls = 0
	_metrics.llm_success_count = 0
	_metrics.llm_fail_count = 0
	_metrics.llm_total_time = 0.0
	_metrics.llm_total_tokens = 0
	_metrics.llm_calls_by_character.clear()

	_metrics.active_dialogs = 0
	_metrics.active_tasks = 0
	_metrics.active_conflicts = 0
	_metrics.total_transactions = 0

	_metrics.start_time = Time.get_ticks_msec() / 1000.0

	print("[PerformanceMonitor] 性能指标已重置")

# ========================================
# 内部辅助方法
# ========================================

func _check_performance_warnings(fps: float, memory_mb: float):
	"""检查性能警告

	Args:
		fps: 当前FPS
		memory_mb: 当前内存(MB)
	"""
	# FPS警告
	if fps < FPS_CRITICAL_THRESHOLD:
		fps_critical.emit(fps)
	elif fps < FPS_WARNING_THRESHOLD:
		fps_warning.emit(fps)

	# 内存警告
	if memory_mb > MEMORY_CRITICAL_MB:
		memory_warning.emit(memory_mb)
	elif memory_mb > MEMORY_WARNING_MB:
		memory_warning.emit(memory_mb)

func _format_uptime(seconds: float) -> String:
	"""格式化运行时间

	Args:
		seconds: 秒数

	Returns:
		格式化字符串
	"""
	var hours = int(seconds / 3600)
	var minutes = int((seconds - hours * 3600) / 60)
	var secs = int(seconds - hours * 3600 - minutes * 60)

	return "%02d:%02d:%02d" % [hours, minutes, secs]

# ========================================
# 调试命令
# ========================================

func print_summary():
	"""打印性能摘要到控制台"""
	var summary = get_performance_summary()

	print("========== Performance Summary ==========")
	print("Uptime: %s" % summary.uptime_formatted)
	print("FPS: Current=%.1f, Avg=%.1f, Min=%.1f" % [
		summary.current_fps,
		summary.average_fps,
		summary.min_fps
	])
	print("Memory: %.2f MB" % summary.current_memory_mb)
	print("Nodes: %d" % summary.current_node_count)
	print("LLM: Calls=%d, Success=%.1f%%, AvgTime=%.2fs, Tokens=%d" % [
		summary.llm_total_calls,
		summary.llm_success_rate * 100,
		summary.llm_avg_response_time,
		summary.llm_total_tokens
	])
	print("System: Dialogs=%d, Tasks=%d, Conflicts=%d, Transactions=%d" % [
		summary.system_status.active_dialogs,
		summary.system_status.active_tasks,
		summary.system_status.active_conflicts,
		summary.system_status.total_transactions
	])
	print("=========================================")
