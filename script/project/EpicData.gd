# script/project/EpicData.gd
class_name EpicData
extends Resource

# ========================================
# 枚举定义
# ========================================

enum EpicStatus {
	PENDING,       # 待开始
	IN_PROGRESS,   # 进行中
	BLOCKED,       # 阻塞 (依赖未完成)
	COMPLETED,     # 已完成
	FAILED         # 失败
}

# ========================================
# 核心数据
# ========================================

var id: String = ""                     # Epic唯一ID
var project_id: String = ""             # 所属项目ID
var title: String = ""                  # Epic名称 (如 "第一幕: 开篇(1-5章)")
var description: String = ""            # Epic描述

# 角色分配
var assigned_roles: Array = []          # 负责的角色类型 (如 ["main_writer", "editor"])
var assigned_characters: Array = []     # 负责的具体角色名 (如 ["Alice", "Tom"])

# 时间数据
var estimated_days: int = 1             # 预估天数
var started_at: float = 0.0             # 开始时间戳
var completed_at: float = 0.0           # 完成时间戳

# 进度数据
var progress: float = 0.0               # 进度 (0.0-1.0)
var status: int = EpicStatus.PENDING

# 依赖关系
var dependencies: Array = []            # 依赖的Epic ID列表 (必须这些Epic完成才能开始)

# 任务关联
var work_tasks: Array = []              # 关联的TaskSystem任务ID列表

# 质量评估
var quality_score: float = 0.0          # 质量分 (0-100)

# 元数据
var metadata: Dictionary = {}

# ========================================
# 方法
# ========================================

func to_dict() -> Dictionary:
	"""序列化为字典"""
	return {
		"id": id,
		"project_id": project_id,
		"title": title,
		"description": description,
		"assigned_roles": assigned_roles.duplicate(),
		"assigned_characters": assigned_characters.duplicate(),
		"estimated_days": estimated_days,
		"started_at": started_at,
		"completed_at": completed_at,
		"progress": progress,
		"status": status,
		"dependencies": dependencies.duplicate(),
		"work_tasks": work_tasks.duplicate(),
		"quality_score": quality_score,
		"metadata": metadata.duplicate(true)
	}

static func from_dict(data: Dictionary) -> EpicData:
	"""从字典反序列化"""
	var epic = EpicData.new()
	epic.id = data.get("id", "")
	epic.project_id = data.get("project_id", "")
	epic.title = data.get("title", "")
	epic.description = data.get("description", "")
	epic.assigned_roles = data.get("assigned_roles", []).duplicate()
	epic.assigned_characters = data.get("assigned_characters", []).duplicate()
	epic.estimated_days = data.get("estimated_days", 1)
	epic.started_at = data.get("started_at", 0.0)
	epic.completed_at = data.get("completed_at", 0.0)
	epic.progress = data.get("progress", 0.0)
	epic.status = data.get("status", EpicStatus.PENDING)
	epic.dependencies = data.get("dependencies", []).duplicate()
	epic.work_tasks = data.get("work_tasks", []).duplicate()
	epic.quality_score = data.get("quality_score", 0.0)
	epic.metadata = data.get("metadata", {}).duplicate(true)
	return epic

func can_start() -> bool:
	"""是否可以开始 (依赖已完成)"""
	return dependencies.is_empty()

func get_progress_percentage() -> float:
	"""获取进度百分比"""
	return progress * 100.0

func is_completed() -> bool:
	"""是否已完成"""
	return status == EpicStatus.COMPLETED

func get_status_text() -> String:
	"""获取状态文本"""
	match status:
		EpicStatus.PENDING:
			return "待开始"
		EpicStatus.IN_PROGRESS:
			return "进行中"
		EpicStatus.BLOCKED:
			return "阻塞"
		EpicStatus.COMPLETED:
			return "已完成"
		EpicStatus.FAILED:
			return "失败"
		_:
			return "未知状态"

func get_elapsed_days() -> int:
	"""获取已用天数"""
	if started_at <= 0.0:
		return 0

	var end_time = completed_at if completed_at > 0.0 else Time.get_unix_time_from_system()
	var duration_seconds = end_time - started_at
	return int(duration_seconds / 86400.0)

func is_overdue() -> bool:
	"""是否超期"""
	var elapsed = get_elapsed_days()
	return elapsed > estimated_days and status != EpicStatus.COMPLETED
