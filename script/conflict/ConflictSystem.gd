# ============================================================
# ConflictSystem.gd
# ============================================================
# ConflictSystem - 冲突管理系统
#
# 功能:
# - 触发和管理 AI 角色之间的冲突
# - 冲突升级和降级机制
# - 冲突调解和解决
# - 冷却期管理
# - 冲突历史记录
# - 与 RelationshipManager 和 DatabaseManager 集成
#
# 作者: Claude (Sonnet 4.5)
# 创建日期: 2025-10-20
# 版本: 1.0.0
# ============================================================

extends Node

# ============================================================
# 枚举定义
# ============================================================

enum ConflictType {
	INTEREST,          # 利益冲突 (资源争夺、工作分配)
	VALUES,            # 价值观冲突 (理念分歧)
	PERSONALITY,       # 性格冲突 (互相看不惯)
	MISUNDERSTANDING,  # 误会 (沟通不畅)
	TASK_DISPUTE,      # 任务纠纷 (工作分歧)
	RESOURCE,          # 资源冲突 (物资争夺)
	TERRITORIAL,       # 地盘冲突 (位置争夺)
	ROMANTIC,          # 情感冲突 (三角恋等)
}

enum ConflictSeverity {
	MINOR = 1,      # 小摩擦
	MODERATE = 3,   # 中等冲突
	MAJOR = 6,      # 严重冲突
	CRITICAL = 9,   # 极端冲突
}

enum ConflictStatus {
	TRIGGERED,      # 刚触发
	ESCALATING,     # 升级中
	PEAK,           # 高峰期
	COOLING_DOWN,   # 冷却期
	MEDIATED,       # 调解中
	RESOLVED,       # 已解决
	UNRESOLVED,     # 未解决 (双方不愿妥协)
}

enum ResolutionType {
	MEDIATION,      # 调解
	COMPROMISE,     # 妥协
	APOLOGY,        # 道歉
	TIME_HEALED,    # 时间治愈
	FORCED,         # 强制和解
	NONE,           # 未解决
}

# ============================================================
# 常量
# ============================================================

# 冷却期时长 (游戏小时)
const COOLDOWN_DURATION = {
	ConflictSeverity.MINOR: 24,      # 1 天
	ConflictSeverity.MODERATE: 72,   # 3 天
	ConflictSeverity.MAJOR: 168,     # 7 天
	ConflictSeverity.CRITICAL: 336,  # 14 天
}

# 自动升级阈值 (小时)
const AUTO_ESCALATE_THRESHOLD = 12  # 12 小时无处理自动升级

# 最大冲突历史保存数量
const MAX_CONFLICT_HISTORY = 100

# ============================================================
# 信号
# ============================================================

signal conflict_triggered(conflict_id: String, conflict_data: Dictionary)
signal conflict_escalated(conflict_id: String, new_severity: int)
signal conflict_resolved(conflict_id: String, resolution_data: Dictionary)
signal mediation_started(conflict_id: String, mediator_id: String)
signal cooldown_started(conflict_id: String, duration: float)
signal trust_below_threshold(source_id: String, target_id: String, trust_value: float)

# ============================================================
# 变量
# ============================================================

# 活跃冲突 {conflict_id: conflict_data}
var _active_conflicts: Dictionary = {}

# 历史冲突 (已解决/未解决)
var _conflict_history: Array = []

# 冷却期 {pair_key: cooldown_end_time}
var _cooldowns: Dictionary = {}

# 冲突计数器 (用于生成唯一 ID)
var _conflict_counter: int = 0

# 是否已初始化
var _initialized: bool = false

# ============================================================
# 初始化
# ============================================================

func _ready():
	print("[ConflictSystem] 冲突系统初始化")
	_connect_signals()
	_initialized = true
	print("[ConflictSystem] 冲突系统初始化完成")

func _connect_signals():
	"""连接其他系统信号"""
	# 连接时间系统 (用于冲突自动升级和冷却期)
	if TimeSystem:
		TimeSystem.hour_changed.connect(_on_hour_changed)
		print("  - 已连接 TimeSystem.hour_changed 信号")

	# 连接关系系统 (监听信任度变化)
	if RelationshipManager:
		RelationshipManager.relationship_changed.connect(_on_relationship_changed)
		print("  - 已连接 RelationshipManager.relationship_changed 信号")

# ============================================================
# 核心功能 - 触发冲突
# ============================================================

func trigger_conflict(source_id: String, target_id: String, conflict_type: ConflictType, severity: int, reason: String, context: Dictionary = {}) -> String:
	"""
	触发冲突

	参数:
		source_id: 冲突发起方 ID
		target_id: 冲突对象 ID
		conflict_type: 冲突类型
		severity: 严重程度 (1-10)
		reason: 冲突原因描述
		context: 额外上下文信息

	返回:
		conflict_id: 冲突唯一 ID
	"""

	# 检查是否在冷却期
	if _is_in_cooldown(source_id, target_id):
		print("[ConflictSystem] %s 和 %s 仍在冷却期,无法触发新冲突" % [source_id, target_id])
		return ""

	# 生成冲突 ID
	var conflict_id = _generate_conflict_id()

	# 创建冲突数据
	var conflict_data = {
		"conflict_id": conflict_id,
		"conflict_type": ConflictType.keys()[conflict_type],
		"source_id": source_id,
		"target_id": target_id,
		"severity": severity,
		"status": ConflictStatus.keys()[ConflictStatus.TRIGGERED],
		"trigger_event": {
			"type": conflict_type,
			"timestamp": _get_current_timestamp(),
			"description": reason,
			"context": context
		},
		"escalation_history": [
			{
				"timestamp": _get_current_timestamp(),
				"severity": severity,
				"event": "冲突触发: %s" % reason
			}
		],
		"mediators": [],
		"resolution": null,
		"cooldown_until": 0.0,
		"created_at": _get_current_timestamp(),
		"resolved_at": 0.0,
		"last_updated": _get_current_timestamp()
	}

	# 添加到活跃冲突
	_active_conflicts[conflict_id] = conflict_data

	# 影响关系
	_apply_conflict_relationship_impact(source_id, target_id, severity)

	# 记录到数据库
	if DatabaseManager:
		DatabaseManager.log_relationship_change(
			source_id,
			target_id,
			"conflict",
			-severity,
			reason
		)

	# 发送信号
	conflict_triggered.emit(conflict_id, conflict_data)

	# 通过 EventBus 广播
	if EventBus:
		EventBus.emit_signal("conflict_triggered", conflict_id, conflict_data)

	print("[ConflictSystem] 冲突已触发: %s vs %s (类型: %s, 严重程度: %d)" % [
		source_id, target_id, ConflictType.keys()[conflict_type], severity
	])

	return conflict_id

# ============================================================
# 冲突升级
# ============================================================

func escalate_conflict(conflict_id: String, additional_severity: int, reason: String = ""):
	"""升级冲突严重程度"""

	if not _active_conflicts.has(conflict_id):
		push_warning("[ConflictSystem] 冲突不存在: %s" % conflict_id)
		return

	var conflict = _active_conflicts[conflict_id]

	# 更新严重程度
	var old_severity = conflict.severity
	conflict.severity = min(conflict.severity + additional_severity, 10)

	# 更新状态
	if conflict.severity >= 7:
		conflict.status = ConflictStatus.keys()[ConflictStatus.PEAK]
	else:
		conflict.status = ConflictStatus.keys()[ConflictStatus.ESCALATING]

	# 记录升级历史
	conflict.escalation_history.append({
		"timestamp": _get_current_timestamp(),
		"severity": conflict.severity,
		"event": reason if not reason.is_empty() else "冲突升级"
	})

	conflict.last_updated = _get_current_timestamp()

	# 影响关系
	_apply_conflict_relationship_impact(conflict.source_id, conflict.target_id, additional_severity)

	# 发送信号
	conflict_escalated.emit(conflict_id, conflict.severity)

	# 通过 EventBus 广播
	if EventBus:
		EventBus.emit_signal("conflict_escalated", conflict_id, conflict.severity)

	print("[ConflictSystem] 冲突升级: %s (%d → %d)" % [conflict_id, old_severity, conflict.severity])

# ============================================================
# 冲突调解
# ============================================================

func start_mediation(conflict_id: String, mediator_id: String):
	"""开始调解冲突"""

	if not _active_conflicts.has(conflict_id):
		push_warning("[ConflictSystem] 冲突不存在: %s" % conflict_id)
		return

	var conflict = _active_conflicts[conflict_id]

	# 添加调解员
	if not conflict.mediators.has(mediator_id):
		conflict.mediators.append(mediator_id)

	# 更新状态
	conflict.status = ConflictStatus.keys()[ConflictStatus.MEDIATED]
	conflict.last_updated = _get_current_timestamp()

	# 发送信号
	mediation_started.emit(conflict_id, mediator_id)

	# 通过 EventBus 广播
	if EventBus:
		EventBus.emit_signal("mediation_started", conflict_id, mediator_id)

	print("[ConflictSystem] 调解开始: %s (调解员: %s)" % [conflict_id, mediator_id])

# ============================================================
# 冲突解决
# ============================================================

func resolve_conflict(conflict_id: String, resolution_type: ResolutionType, outcome: Dictionary = {}):
	"""
	解决冲突

	参数:
		conflict_id: 冲突 ID
		resolution_type: 解决类型
		outcome: 结果详情 (包含 relationship_impact 等)
	"""

	if not _active_conflicts.has(conflict_id):
		push_warning("[ConflictSystem] 冲突不存在: %s" % conflict_id)
		return

	var conflict = _active_conflicts[conflict_id]

	# 创建解决数据
	var resolution = {
		"resolution_type": ResolutionType.keys()[resolution_type],
		"timestamp": _get_current_timestamp(),
		"mediator": conflict.mediators[0] if conflict.mediators.size() > 0 else "",
		"outcome": outcome.get("description", "冲突已解决"),
		"relationship_impact": outcome.get("relationship_impact", {})
	}

	conflict.resolution = resolution
	conflict.resolved_at = _get_current_timestamp()

	# 更新状态
	if resolution_type == ResolutionType.NONE:
		conflict.status = ConflictStatus.keys()[ConflictStatus.UNRESOLVED]
	else:
		conflict.status = ConflictStatus.keys()[ConflictStatus.RESOLVED]

	# 应用关系影响
	if resolution.relationship_impact:
		_apply_resolution_relationship_impact(conflict, resolution.relationship_impact)

	# 开始冷却期
	var cooldown_duration = _calculate_cooldown_duration(conflict.severity)
	_start_cooldown(conflict.source_id, conflict.target_id, cooldown_duration)

	# 移到历史
	_conflict_history.append(conflict)
	_active_conflicts.erase(conflict_id)

	# 清理旧历史
	if _conflict_history.size() > MAX_CONFLICT_HISTORY:
		_conflict_history.remove_at(0)

	# 发送信号
	conflict_resolved.emit(conflict_id, resolution)

	# 通过 EventBus 广播
	if EventBus:
		EventBus.emit_signal("conflict_resolved", conflict_id, resolution)

	print("[ConflictSystem] 冲突已解决: %s (类型: %s)" % [conflict_id, ResolutionType.keys()[resolution_type]])

# ============================================================
# 查询功能
# ============================================================

func get_conflict(conflict_id: String) -> Dictionary:
	"""获取冲突详情"""
	if _active_conflicts.has(conflict_id):
		return _active_conflicts[conflict_id]

	# 查找历史
	for conflict in _conflict_history:
		if conflict.conflict_id == conflict_id:
			return conflict

	return {}

func get_active_conflicts() -> Array:
	"""获取所有活跃冲突"""
	return _active_conflicts.values()

func get_character_conflicts(ai_id: String) -> Array:
	"""获取角色相关的所有冲突 (活跃 + 历史)"""
	var conflicts = []

	# 活跃冲突
	for conflict in _active_conflicts.values():
		if conflict.source_id == ai_id or conflict.target_id == ai_id:
			conflicts.append(conflict)

	# 历史冲突 (最近10个)
	var count = 0
	for i in range(_conflict_history.size() - 1, -1, -1):
		if count >= 10:
			break
		var conflict = _conflict_history[i]
		if conflict.source_id == ai_id or conflict.target_id == ai_id:
			conflicts.append(conflict)
			count += 1

	return conflicts

func get_conflict_history(source_id: String, target_id: String) -> Array:
	"""获取两个角色之间的冲突历史"""
	var history = []

	for conflict in _conflict_history:
		if (conflict.source_id == source_id and conflict.target_id == target_id) or \
		   (conflict.source_id == target_id and conflict.target_id == source_id):
			history.append(conflict)

	return history

func can_interact(ai_a: String, ai_b: String) -> bool:
	"""检查两个角色是否可以互动 (不在冷却期)"""
	return not _is_in_cooldown(ai_a, ai_b)

func is_in_conflict(ai_a: String, ai_b: String) -> bool:
	"""检查两个角色是否处于冲突中"""
	for conflict in _active_conflicts.values():
		if (conflict.source_id == ai_a and conflict.target_id == ai_b) or \
		   (conflict.source_id == ai_b and conflict.target_id == ai_a):
			return true
	return false

# ============================================================
# 冷却期管理
# ============================================================

func _start_cooldown(source_id: String, target_id: String, duration_hours: float):
	"""开始冷却期"""
	var pair_key = _get_pair_key(source_id, target_id)
	var cooldown_end = _get_current_timestamp() + (duration_hours * 3600.0)

	_cooldowns[pair_key] = cooldown_end

	# 发送信号
	cooldown_started.emit("%s_%s" % [source_id, target_id], duration_hours)

	print("[ConflictSystem] 冷却期开始: %s <-> %s (%d 小时)" % [source_id, target_id, duration_hours])

func _is_in_cooldown(source_id: String, target_id: String) -> bool:
	"""检查是否在冷却期"""
	var pair_key = _get_pair_key(source_id, target_id)

	if not _cooldowns.has(pair_key):
		return false

	var cooldown_end = _cooldowns[pair_key]
	if _get_current_timestamp() < cooldown_end:
		return true

	# 冷却期结束,移除
	_cooldowns.erase(pair_key)
	return false

func _calculate_cooldown_duration(severity: int) -> float:
	"""根据严重程度计算冷却期时长"""
	if severity <= 2:
		return COOLDOWN_DURATION[ConflictSeverity.MINOR]
	elif severity <= 5:
		return COOLDOWN_DURATION[ConflictSeverity.MODERATE]
	elif severity <= 8:
		return COOLDOWN_DURATION[ConflictSeverity.MAJOR]
	else:
		return COOLDOWN_DURATION[ConflictSeverity.CRITICAL]

# ============================================================
# 关系影响
# ============================================================

func _apply_conflict_relationship_impact(source_id: String, target_id: String, severity: int):
	"""应用冲突对关系的影响"""
	if not RelationshipManager:
		return

	# 根据严重程度计算影响
	var affection_delta = -severity * 2.0
	var trust_delta = -severity * 1.5

	# 应用影响
	RelationshipManager.apply_delta(source_id, target_id, "affection", affection_delta, "冲突影响")
	RelationshipManager.apply_delta(source_id, target_id, "trust", trust_delta, "冲突影响")

func _apply_resolution_relationship_impact(conflict: Dictionary, impact: Dictionary):
	"""应用冲突解决对关系的影响"""
	if not RelationshipManager:
		return

	for pair_key in impact.keys():
		var changes = impact[pair_key]
		var pair_parts = pair_key.split("_")
		if pair_parts.size() != 2:
			continue

		var source_id = pair_parts[0]
		var target_id = pair_parts[1]

		for channel in changes.keys():
			var delta = changes[channel]
			RelationshipManager.apply_delta(source_id, target_id, channel, delta, "冲突解决")

# ============================================================
# 自动处理
# ============================================================

func _on_hour_changed(hour: int):
	"""每小时检查冲突状态"""
	_check_auto_escalation()
	_cleanup_expired_cooldowns()

func _check_auto_escalation():
	"""检查是否需要自动升级冲突"""
	var current_time = _get_current_timestamp()

	for conflict in _active_conflicts.values():
		if conflict.status == ConflictStatus.keys()[ConflictStatus.TRIGGERED] or \
		   conflict.status == ConflictStatus.keys()[ConflictStatus.ESCALATING]:

			var hours_since_last_update = (current_time - conflict.last_updated) / 3600.0

			if hours_since_last_update >= AUTO_ESCALATE_THRESHOLD:
				escalate_conflict(conflict.conflict_id, 1, "自动升级 (无人处理)")

func _cleanup_expired_cooldowns():
	"""清理过期的冷却期"""
	var current_time = _get_current_timestamp()
	var expired_keys = []

	for pair_key in _cooldowns.keys():
		if current_time >= _cooldowns[pair_key]:
			expired_keys.append(pair_key)

	for key in expired_keys:
		_cooldowns.erase(key)
		print("[ConflictSystem] 冷却期结束: %s" % key)

func _on_relationship_changed(ai_id: String, target_id: String, relationship: Dictionary):
	"""监听关系变化,检查信任阈值"""
	var trust = relationship.get("trust", 50.0)

	# 如果信任度低于阈值,发送信号
	if trust < 30.0:
		trust_below_threshold.emit(ai_id, target_id, trust)

# ============================================================
# 工具函数
# ============================================================

func _generate_conflict_id() -> String:
	"""生成唯一冲突 ID"""
	_conflict_counter += 1
	return "conflict_%d_%d" % [Time.get_unix_time_from_system(), _conflict_counter]

func _get_pair_key(source_id: String, target_id: String) -> String:
	"""获取角色对的唯一键 (顺序无关)"""
	var ids = [source_id, target_id]
	ids.sort()
	return "%s_%s" % [ids[0], ids[1]]

func _get_current_timestamp() -> float:
	"""获取当前时间戳"""
	if TimeSystem:
		return TimeSystem.get_current_timestamp()
	return Time.get_unix_time_from_system()

# ============================================================
# 公共 API
# ============================================================

func is_initialized() -> bool:
	"""检查是否已初始化"""
	return _initialized

func get_statistics() -> Dictionary:
	"""获取统计信息"""
	return {
		"active_conflicts": _active_conflicts.size(),
		"total_conflicts": _conflict_counter,
		"historical_conflicts": _conflict_history.size(),
		"active_cooldowns": _cooldowns.size()
	}

func clear_all_conflicts():
	"""清除所有冲突 (用于测试)"""
	_active_conflicts.clear()
	_conflict_history.clear()
	_cooldowns.clear()
	print("[ConflictSystem] 所有冲突已清除")
