# script/project/ProjectData.gd
class_name ProjectData
extends Resource

# ========================================
# 枚举定义
# ========================================

enum ProjectType {
	SOFTWARE_DEVELOPMENT,  # 软件开发
	NOVEL_WRITING,         # 小说创作
	FILM_PRODUCTION,       # 影视制作
	DESIGN_BRANDING,       # 品牌设计
	MARKETING_CAMPAIGN,    # 营销活动
	RESEARCH_REPORT,       # 研究报告
	GAME_DEVELOPMENT,      # 游戏开发
	MUSIC_PRODUCTION,      # 音乐制作
	CUSTOM                 # 自定义
}

enum ProjectStatus {
	NOT_STARTED,     # 未开始
	PLANNING,        # 规划中 (LLM正在生成Epic)
	IN_PROGRESS,     # 进行中
	REVIEW,          # 验收中 (LLM评估完成度)
	COMPLETED,       # 已完成
	FAILED,          # 失败
	CANCELLED        # 取消
}

enum DifficultyMode {
	STRICT,    # 严格模式 (高风险高回报)
	BALANCED,  # 平衡模式 (中等风险)
	RELAXED    # 轻松模式 (低风险)
}

# ========================================
# 核心数据
# ========================================

var id: String = ""                          # 项目唯一ID
var type: int = ProjectType.SOFTWARE_DEVELOPMENT  # 项目类型
var type_template_id: String = ""            # 项目类型模板ID (如 "novel_writing")

# 用户输入
var title: String = ""                  # 项目名称 (如 "科幻小说:星际迷航")
var description: String = ""            # 需求描述 (用户自由输入,可多行)
var budget: int = 50000                 # 预算 (金币)
var duration_days: int = 30             # 工期 (天数)
var quality_requirement: String = "medium"  # 质量要求 (high/medium/low)
var difficulty_mode: int = DifficultyMode.BALANCED  # 难度模式

# 项目状态
var status: int = ProjectStatus.NOT_STARTED
var created_at: float = 0.0             # 创建时间戳
var started_at: float = 0.0             # 开始时间戳
var deadline: float = 0.0               # 截止时间戳
var completed_at: float = 0.0           # 完成时间戳

# 进度数据
var completion_rate: float = 0.0        # 完成度 (0.0-1.0)
var quality_score: float = 0.0          # 质量分 (0-100)
var days_overdue: int = 0               # 延期天数

# ========================================
# 角色分配
# ========================================

# 角色映射: {role_id: [character_names]}
# 示例: {"project_lead": ["Stephen"], "main_writer": ["Alice"]}
var role_assignments: Dictionary = {}

# 角色职责: {character_name: {role_id, title}}
# 示例: {"Alice": {"role_id": "main_writer", "title": "主笔作家"}}
var character_roles: Dictionary = {}

# ========================================
# Epic与任务
# ========================================

var epics: Array = []  # Array of EpicData
var current_epic_index: int = 0  # 当前进行中的Epic索引

# ========================================
# 经济数据
# ========================================

var bonus_pool: int = 0                 # 奖金池 (=budget)
var bonus_allocated: Dictionary = {}    # 已分配奖金计划 {character_id: planned_amount}
var bonus_paid: Dictionary = {}         # 实际发放奖金 {character_id: paid_amount}

# ========================================
# LLM规划结果
# ========================================

var llm_planning_result: Dictionary = {}
# {
#   "epics": [...],
#   "budget_allocation": {...},
#   "planning_notes": "..."
# }

var llm_evaluation_result: Dictionary = {}
# {
#   "completion_rate": 0.85,
#   "quality_score": 78,
#   "strengths": [...],
#   "weaknesses": [...],
#   "bonus_adjustment": 1.0
# }

# ========================================
# 元数据
# ========================================

var metadata: Dictionary = {}  # 项目特殊配置

# ========================================
# 方法
# ========================================

func to_dict() -> Dictionary:
	"""序列化为字典"""
	var epics_array = []
	for epic in epics:
		if epic is EpicData:
			epics_array.append(epic.to_dict())
		else:
			epics_array.append(epic)

	return {
		"id": id,
		"type": type,
		"type_template_id": type_template_id,
		"title": title,
		"description": description,
		"budget": budget,
		"duration_days": duration_days,
		"quality_requirement": quality_requirement,
		"difficulty_mode": difficulty_mode,
		"status": status,
		"created_at": created_at,
		"started_at": started_at,
		"deadline": deadline,
		"completed_at": completed_at,
		"completion_rate": completion_rate,
		"quality_score": quality_score,
		"days_overdue": days_overdue,
		"role_assignments": role_assignments.duplicate(true),
		"character_roles": character_roles.duplicate(true),
		"epics": epics_array,
		"current_epic_index": current_epic_index,
		"bonus_pool": bonus_pool,
		"bonus_allocated": bonus_allocated.duplicate(true),
		"bonus_paid": bonus_paid.duplicate(true),
		"llm_planning_result": llm_planning_result.duplicate(true),
		"llm_evaluation_result": llm_evaluation_result.duplicate(true),
		"metadata": metadata.duplicate(true)
	}

static func from_dict(data: Dictionary) -> ProjectData:
	"""从字典反序列化"""
	var project = ProjectData.new()
	project.id = data.get("id", "")
	project.type = data.get("type", ProjectType.SOFTWARE_DEVELOPMENT)
	project.type_template_id = data.get("type_template_id", "")
	project.title = data.get("title", "")
	project.description = data.get("description", "")
	project.budget = data.get("budget", 50000)
	project.duration_days = data.get("duration_days", 30)
	project.quality_requirement = data.get("quality_requirement", "medium")
	project.difficulty_mode = data.get("difficulty_mode", DifficultyMode.BALANCED)
	project.status = data.get("status", ProjectStatus.NOT_STARTED)
	project.created_at = data.get("created_at", 0.0)
	project.started_at = data.get("started_at", 0.0)
	project.deadline = data.get("deadline", 0.0)
	project.completed_at = data.get("completed_at", 0.0)
	project.completion_rate = data.get("completion_rate", 0.0)
	project.quality_score = data.get("quality_score", 0.0)
	project.days_overdue = data.get("days_overdue", 0)
	project.role_assignments = data.get("role_assignments", {}).duplicate(true)
	project.character_roles = data.get("character_roles", {}).duplicate(true)

	# 反序列化epics
	var epics_data = data.get("epics", [])
	for epic_data in epics_data:
		if epic_data is Dictionary:
			var epic = load("res://script/project/EpicData.gd")
			if epic:
				project.epics.append(epic.from_dict(epic_data))
		else:
			project.epics.append(epic_data)

	project.current_epic_index = data.get("current_epic_index", 0)
	project.bonus_pool = data.get("bonus_pool", 0)
	project.bonus_allocated = data.get("bonus_allocated", {}).duplicate(true)
	project.bonus_paid = data.get("bonus_paid", {}).duplicate(true)
	project.llm_planning_result = data.get("llm_planning_result", {}).duplicate(true)
	project.llm_evaluation_result = data.get("llm_evaluation_result", {}).duplicate(true)
	project.metadata = data.get("metadata", {}).duplicate(true)

	return project

func get_progress_percentage() -> float:
	"""获取进度百分比"""
	return completion_rate * 100.0

func get_days_remaining() -> int:
	"""获取剩余天数"""
	if deadline <= 0.0:
		return 0

	var current_time = Time.get_unix_time_from_system()
	var remaining_seconds = deadline - current_time
	return int(remaining_seconds / 86400.0)

func is_overdue() -> bool:
	"""是否延期"""
	return days_overdue > 0

func get_current_epic() -> Resource:
	"""获取当前Epic"""
	if current_epic_index >= 0 and current_epic_index < epics.size():
		return epics[current_epic_index]
	return null

func get_completed_epics_count() -> int:
	"""获取已完成Epic数量"""
	var count = 0
	for epic in epics:
		if epic is Resource and epic.has_method("is_completed"):
			if epic.is_completed():
				count += 1
		elif epic is Dictionary:
			if epic.get("status", -1) == 3:  # EpicStatus.COMPLETED
				count += 1
	return count

func get_status_text() -> String:
	"""获取状态文本"""
	match status:
		ProjectStatus.NOT_STARTED:
			return "未开始"
		ProjectStatus.PLANNING:
			return "规划中"
		ProjectStatus.IN_PROGRESS:
			return "进行中"
		ProjectStatus.REVIEW:
			return "验收中"
		ProjectStatus.COMPLETED:
			return "已完成"
		ProjectStatus.FAILED:
			return "失败"
		ProjectStatus.CANCELLED:
			return "已取消"
		_:
			return "未知状态"

func get_difficulty_text() -> String:
	"""获取难度文本"""
	match difficulty_mode:
		DifficultyMode.STRICT:
			return "严格模式"
		DifficultyMode.BALANCED:
			return "平衡模式"
		DifficultyMode.RELAXED:
			return "轻松模式"
		_:
			return "未知难度"
