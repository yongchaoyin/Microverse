# script/project/ProjectSystem.gd
extends Node

class_name ProjectSystem

# ========================================
# 信号定义
# ========================================

signal project_created(project: ProjectData)
signal project_started(project: ProjectData)
signal project_planning_completed(project: ProjectData)
signal project_epic_started(project: ProjectData, epic: EpicData)
signal project_epic_completed(project: ProjectData, epic: EpicData)
signal project_completed(project: ProjectData)
signal project_failed(project: ProjectData, reason: String)
signal project_evaluated(project: ProjectData, evaluation: Dictionary)
signal bonus_distributed(project: ProjectData, bonus_data: Dictionary)

# ========================================
# 常量
# ========================================

const PROJECT_SAVE_PATH := "user://projects/"
const MAX_CONCURRENT_PROJECTS := 1  # 同时只能有一个活跃项目
const EPIC_REVIEW_INTERVAL_HOURS := 24  # Epic检查间隔(每天检查一次)

# ========================================
# 依赖系统
# ========================================

var _task_system: TaskSystem = null
var _economy_manager: Node = null
var _memory_manager: Node = null
var _relationship_manager: Node = null
var _time_system: Node = null
var _api_manager: Node = null
var _character_manager: Node = null

# ========================================
# 数据存储
# ========================================

var _active_project: ProjectData = null  # 当前活跃项目
var _project_history: Array = []         # 历史项目列表
var _llm_request_queue: Array = []       # LLM请求队列

# ========================================
# 初始化
# ========================================

func _ready() -> void:
	_initialize_dependencies()
	_load_projects()
	_connect_signals()

	print("[ProjectSystem] 项目系统已初始化")

func _initialize_dependencies() -> void:
	"""初始化依赖系统引用"""
	_task_system = get_node_or_null("/root/TaskSystem")
	_economy_manager = get_node_or_null("/root/EconomyManager")
	_memory_manager = get_node_or_null("/root/MemoryManager")
	_relationship_manager = get_node_or_null("/root/RelationshipManager")
	_time_system = get_node_or_null("/root/TimeSystem")
	_api_manager = get_node_or_null("/root/APIManager")
	_character_manager = get_node_or_null("/root/CharacterManager")

	if not _task_system:
		push_warning("[ProjectSystem] TaskSystem未找到!")
	if not _economy_manager:
		push_warning("[ProjectSystem] EconomyManager未找到!")

func _connect_signals() -> void:
	"""连接系统信号"""
	if _time_system:
		_time_system.day_changed.connect(_on_day_changed)
		_time_system.hour_changed.connect(_on_hour_changed)

	if _task_system:
		_task_system.task_completed.connect(_on_task_completed)

# ========================================
# 项目创建API
# ========================================

func create_project(config: Dictionary) -> ProjectData:
	"""创建新项目

	Args:
		config: {
			"type_template_id": "novel_writing",
			"title": "科幻小说:星际迷航",
			"description": "用户输入的详细需求描述",
			"budget": 50000,
			"duration_days": 30,
			"quality_requirement": "high",
			"difficulty_mode": "balanced"
		}

	Returns:
		ProjectData对象
	"""

	# 检查是否已有活跃项目
	if _active_project != null and _active_project.status in [
		ProjectData.ProjectStatus.PLANNING,
		ProjectData.ProjectStatus.IN_PROGRESS,
		ProjectData.ProjectStatus.REVIEW
	]:
		push_warning("[ProjectSystem] 已有活跃项目,无法创建新项目")
		return null

	# 创建项目数据
	var project = ProjectData.new()
	project.id = _generate_project_id()
	project.type_template_id = config.get("type_template_id", "software_development")
	project.title = config.get("title", "未命名项目")
	project.description = config.get("description", "")
	project.budget = config.get("budget", 50000)
	project.duration_days = config.get("duration_days", 30)
	project.quality_requirement = config.get("quality_requirement", "medium")

	# 处理难度模式
	var difficulty_str = config.get("difficulty_mode", "balanced")
	if difficulty_str is String:
		match difficulty_str:
			"strict":
				project.difficulty_mode = ProjectData.DifficultyMode.STRICT
			"relaxed":
				project.difficulty_mode = ProjectData.DifficultyMode.RELAXED
			_:
				project.difficulty_mode = ProjectData.DifficultyMode.BALANCED
	else:
		project.difficulty_mode = difficulty_str

	project.created_at = _get_current_timestamp()
	project.status = ProjectData.ProjectStatus.NOT_STARTED
	project.bonus_pool = project.budget

	# 分配角色
	_assign_roles_to_project(project)

	# 保存项目
	_active_project = project
	_save_project(project)

	project_created.emit(project)

	print("[ProjectSystem] 项目已创建: %s (ID: %s)" % [project.title, project.id])

	return project

func start_project(project_id: String) -> bool:
	"""启动项目 (开始LLM规划)"""

	if _active_project == null or _active_project.id != project_id:
		push_warning("[ProjectSystem] 项目不存在或非活跃项目")
		return false

	if _active_project.status != ProjectData.ProjectStatus.NOT_STARTED:
		push_warning("[ProjectSystem] 项目状态不正确,无法启动")
		return false

	# 更新项目状态
	_active_project.status = ProjectData.ProjectStatus.PLANNING
	_active_project.started_at = _get_current_timestamp()
	_active_project.deadline = _active_project.started_at + (_active_project.duration_days * 86400)

	project_started.emit(_active_project)

	# 创建记忆: 项目启动
	_create_project_memory(
		_active_project,
		"项目启动",
		"公司接到新项目: %s,预算%d金币,工期%d天" % [
			_active_project.title,
			_active_project.budget,
			_active_project.duration_days
		]
	)

	# 启动LLM规划
	_request_llm_planning(_active_project)

	print("[ProjectSystem] 项目已启动,正在规划中: %s" % _active_project.title)

	return true

func cancel_project(project_id: String, reason: String = "用户取消") -> bool:
	"""取消项目"""

	if _active_project == null or _active_project.id != project_id:
		return false

	_active_project.status = ProjectData.ProjectStatus.CANCELLED
	_active_project.completed_at = _get_current_timestamp()

	# 创建记忆
	_create_project_memory(
		_active_project,
		"项目取消",
		"项目被取消: %s" % reason
	)

	# 移动到历史记录
	_project_history.append(_active_project)
	_active_project = null

	print("[ProjectSystem] 项目已取消: %s" % reason)

	return true

# ========================================
# 角色分配
# ========================================

func _assign_roles_to_project(project: ProjectData) -> void:
	"""为项目分配角色"""

	var template_manager = get_node_or_null("/root/ProjectTypeTemplates")
	if not template_manager:
		push_error("[ProjectSystem] ProjectTypeTemplates未找到")
		return

	var template = template_manager.get_template(project.type_template_id)
	if template.is_empty():
		push_error("[ProjectSystem] 项目模板未找到: %s" % project.type_template_id)
		return

	var role_mapping = template.get("role_mapping", {})
	var role_definitions = template.get("role_definitions", {})

	# 分配角色
	project.role_assignments = {}
	project.character_roles = {}

	for role_id in role_mapping.keys():
		var candidates = role_mapping[role_id]
		if candidates.is_empty():
			continue

		# 选择第一个候选人
		var selected_character = candidates[0]

		# 添加到role_assignments
		if not project.role_assignments.has(role_id):
			project.role_assignments[role_id] = []
		project.role_assignments[role_id].append(selected_character)

		# 添加到character_roles
		var role_def = role_definitions.get(role_id, {})
		project.character_roles[selected_character] = {
			"role_id": role_id,
			"title": role_def.get("title", "未知角色")
		}

	print("[ProjectSystem] 角色分配完成: %d个角色已分配" % project.character_roles.size())

func get_character_role_in_project(character_name: String, project: ProjectData = null) -> Dictionary:
	"""获取角色在项目中的职责"""

	if project == null:
		project = _active_project

	if project == null:
		return {}

	return project.character_roles.get(character_name, {})

# ========================================
# LLM规划流程
# ========================================

func _request_llm_planning(project: ProjectData) -> void:
	"""请求LLM生成项目Epic规划"""

	var prompt = _build_planning_prompt(project)

	# 调用APIManager发送LLM请求
	if _api_manager:
		var character_name = "Stephen"  # 默认项目经理负责规划
		# APIManager需要character_name, prompt, callback
		# 注意: Godot 4.x中funcref已废弃,使用Callable
		var callback = Callable(self, "_on_llm_planning_response").bind(project.id)

		# 检查APIManager是否有send_request方法
		if _api_manager.has_method("send_request"):
			_api_manager.send_request(character_name, prompt, callback)
			print("[ProjectSystem] 已发送LLM规划请求,等待响应...")
		else:
			push_warning("[ProjectSystem] APIManager没有send_request方法,使用降级方案")
			_fallback_generate_epics(project)
	else:
		push_error("[ProjectSystem] APIManager未找到,无法请求LLM规划")
		# 降级: 使用模板生成Epic
		_fallback_generate_epics(project)

func _build_planning_prompt(project: ProjectData) -> String:
	"""构建LLM规划提示词"""

	var template_manager = get_node_or_null("/root/ProjectTypeTemplates")
	if not template_manager:
		return ""

	var template = template_manager.get_template(project.type_template_id)
	var epic_templates = template.get("epic_templates", [])

	var prompt = """# 项目规划任务

你是一位经验丰富的项目经理,需要为以下项目制定详细的执行计划。

## 项目信息
- **项目类型**: %s
- **项目名称**: %s
- **需求描述**:
%s

- **预算**: %d 金币
- **工期**: %d 天
- **质量要求**: %s

## 可用团队成员
%s

## 参考Epic模板
以下是该类型项目的典型Epic模板,你可以参考但不限于此:
%s

## 你的任务
请根据项目需求,将项目拆分成若干个Epic(大阶段),每个Epic应包含:
1. **标题**: Epic名称 (简洁明了)
2. **描述**: Epic详细描述 (包含具体工作内容)
3. **预估天数**: 该Epic预计需要多少天完成
4. **负责角色**: 需要哪些角色参与 (从可用团队成员中选择)
5. **依赖关系**: 是否依赖其他Epic (可选)

## 输出格式 (严格JSON)
请输出一个JSON对象,格式如下:
```json
{
  "epics": [
    {
      "title": "Epic标题",
      "description": "Epic详细描述",
      "estimated_days": 3,
      "assigned_roles": ["role_id_1", "role_id_2"],
      "dependencies": []
    }
  ],
  "planning_notes": "规划总结和建议"
}
```

**重要提示:**
- Epic总天数应控制在 %d 天左右
- Epic数量建议在5-10个之间
- 确保Epic有合理的依赖顺序
- 确保JSON格式正确,可以被解析
- 只输出JSON,不要添加其他文本

现在开始规划:
""" % [
		template.get("name", "未知类型"),
		project.title,
		project.description,
		project.budget,
		project.duration_days,
		project.quality_requirement,
		_format_team_members(project),
		_format_epic_templates(epic_templates),
		project.duration_days
	]

	return prompt

func _format_team_members(project: ProjectData) -> String:
	"""格式化团队成员信息"""
	var lines = []
	for character_name in project.character_roles.keys():
		var role_data = project.character_roles[character_name]
		lines.append("- %s (%s)" % [character_name, role_data.get("title", "")])
	return "\n".join(lines)

func _format_epic_templates(templates: Array) -> String:
	"""格式化Epic模板信息"""
	var lines = []
	for i in range(templates.size()):
		var template = templates[i]
		lines.append("%d. **%s** (%d天) - %s" % [
			i + 1,
			template.get("title", ""),
			template.get("typical_duration", 1),
			template.get("description", "")
		])
	return "\n".join(lines)

func _on_llm_planning_response(response_text: String, project_id: String) -> void:
	"""LLM规划响应回调"""

	if _active_project == null or _active_project.id != project_id:
		print("[ProjectSystem] 项目已不存在,忽略规划响应")
		return

	print("[ProjectSystem] 收到LLM规划响应,开始解析...")

	# 解析JSON
	var planning_result = _parse_llm_planning_response(response_text)

	if planning_result.is_empty():
		push_error("[ProjectSystem] LLM规划响应解析失败,使用降级方案")
		_fallback_generate_epics(_active_project)
		return

	# 保存规划结果
	_active_project.llm_planning_result = planning_result

	# 生成Epic
	var epics_data = planning_result.get("epics", [])
	_create_epics_from_llm_result(_active_project, epics_data)

	# 更新项目状态
	_active_project.status = ProjectData.ProjectStatus.IN_PROGRESS

	project_planning_completed.emit(_active_project)

	# 创建记忆
	_create_project_memory(
		_active_project,
		"项目规划完成",
		"项目规划已完成,共%d个Epic,开始执行" % _active_project.epics.size()
	)

	# 启动第一个Epic
	_start_next_epic(_active_project)

	print("[ProjectSystem] 项目规划完成,共%d个Epic" % _active_project.epics.size())

func _parse_llm_planning_response(response_text: String) -> Dictionary:
	"""解析LLM规划响应"""

	# 尝试提取JSON部分
	var json_start = response_text.find("{")
	var json_end = response_text.rfind("}")

	if json_start == -1 or json_end == -1:
		push_error("[ProjectSystem] 响应中未找到JSON")
		return {}

	var json_str = response_text.substr(json_start, json_end - json_start + 1)
	var result = JSON.parse_string(json_str)

	if typeof(result) != TYPE_DICTIONARY:
		push_error("[ProjectSystem] JSON解析失败")
		return {}

	return result

func _create_epics_from_llm_result(project: ProjectData, epics_data: Array) -> void:
	"""根据LLM结果创建Epic"""

	project.epics.clear()

	for i in range(epics_data.size()):
		var epic_data = epics_data[i]

		var epic = EpicData.new()
		epic.id = "%s_epic_%d" % [project.id, i + 1]
		epic.project_id = project.id
		epic.title = epic_data.get("title", "Epic %d" % (i + 1))
		epic.description = epic_data.get("description", "")
		epic.estimated_days = epic_data.get("estimated_days", 1)
		epic.assigned_roles = epic_data.get("assigned_roles", [])
		epic.dependencies = epic_data.get("dependencies", [])
		epic.status = EpicData.EpicStatus.PENDING

		# 分配角色
		_assign_characters_to_epic(project, epic)

		project.epics.append(epic)

	project.current_epic_index = 0

func _assign_characters_to_epic(project: ProjectData, epic: EpicData) -> void:
	"""为Epic分配具体角色"""

	epic.assigned_characters.clear()

	for role_id in epic.assigned_roles:
		var characters = project.role_assignments.get(role_id, [])
		for character_name in characters:
			if character_name not in epic.assigned_characters:
				epic.assigned_characters.append(character_name)

func _fallback_generate_epics(project: ProjectData) -> void:
	"""降级方案: 使用模板生成Epic"""

	print("[ProjectSystem] 使用模板降级方案生成Epic")

	var template_manager = get_node_or_null("/root/ProjectTypeTemplates")
	if not template_manager:
		push_error("[ProjectSystem] ProjectTypeTemplates未找到")
		return

	var template = template_manager.get_template(project.type_template_id)
	var epic_templates = template.get("epic_templates", [])

	project.epics.clear()

	for i in range(epic_templates.size()):
		var template_data = epic_templates[i]

		var epic = EpicData.new()
		epic.id = "%s_epic_%d" % [project.id, i + 1]
		epic.project_id = project.id
		epic.title = template_data.get("title", "Epic %d" % (i + 1))
		epic.description = template_data.get("description", "")
		epic.estimated_days = template_data.get("typical_duration", 1)
		epic.assigned_roles = template_data.get("typical_roles", [])
		epic.status = EpicData.EpicStatus.PENDING

		_assign_characters_to_epic(project, epic)

		project.epics.append(epic)

	project.current_epic_index = 0
	project.status = ProjectData.ProjectStatus.IN_PROGRESS

	project_planning_completed.emit(project)

	# 启动第一个Epic
	_start_next_epic(project)

# ========================================
# Epic执行流程
# ========================================

func _start_next_epic(project: ProjectData) -> void:
	"""启动下一个Epic"""

	if project.current_epic_index >= project.epics.size():
		print("[ProjectSystem] 所有Epic已完成,进入项目验收")
		_start_project_review(project)
		return

	var epic = project.epics[project.current_epic_index]

	# 检查依赖
	if not _check_epic_dependencies(project, epic):
		push_warning("[ProjectSystem] Epic依赖未满足,无法启动: %s" % epic.title)
		return

	# 启动Epic
	epic.status = EpicData.EpicStatus.IN_PROGRESS
	epic.started_at = _get_current_timestamp()

	project_epic_started.emit(project, epic)

	# 创建记忆
	_create_project_memory(
		project,
		"新Epic启动",
		"开始新阶段: %s" % epic.title,
		epic.assigned_characters
	)

	# 为Epic生成每日任务
	_generate_tasks_for_epic(project, epic)

	print("[ProjectSystem] Epic已启动: %s (预计%d天)" % [epic.title, epic.estimated_days])

func _check_epic_dependencies(project: ProjectData, epic: EpicData) -> bool:
	"""检查Epic依赖是否满足"""

	for dep_id in epic.dependencies:
		var dep_epic = _find_epic_by_id(project, dep_id)
		if dep_epic == null or dep_epic.status != EpicData.EpicStatus.COMPLETED:
			return false

	return true

func _find_epic_by_id(project: ProjectData, epic_id: String) -> EpicData:
	"""根据ID查找Epic"""
	for epic in project.epics:
		if epic.id == epic_id:
			return epic
	return null

func _generate_tasks_for_epic(project: ProjectData, epic: EpicData) -> void:
	"""为Epic生成每日工作任务"""

	# 为Epic中的每个角色生成任务
	for character_name in epic.assigned_characters:
		var task_payload = {
			"id": "%s_task_%s" % [epic.id, character_name],
			"name": "%s - %s的工作" % [epic.title, character_name],
			"description": "%s\n\n你的职责: %s" % [
				epic.description,
				_get_character_role_description(project, character_name)
			],
			"deadline_offset_minutes": epic.estimated_days * 24 * 60,
			"estimated_minutes": 240,  # 4小时工作
			"domain": "work",
			"tags": ["project", project.id, epic.id],
			"context": {
				"project_id": project.id,
				"epic_id": epic.id,
				"project_title": project.title,
				"epic_title": epic.title
			}
		}

		# 分配任务到TaskSystem
		if _task_system:
			var task = _task_system.assign_task(character_name, task_payload)
			if not task.is_empty():
				epic.work_tasks.append(task.get("id", ""))

	print("[ProjectSystem] 已为Epic '%s' 生成 %d 个任务" % [epic.title, epic.assigned_characters.size()])

func _get_character_role_description(project: ProjectData, character_name: String) -> String:
	"""获取角色职责描述"""

	var role_data = project.character_roles.get(character_name, {})
	if role_data.is_empty():
		return "参与项目工作"

	var role_id = role_data.get("role_id", "")
	var template_manager = get_node_or_null("/root/ProjectTypeTemplates")
	if not template_manager:
		return role_data.get("title", "项目成员")

	var template = template_manager.get_template(project.type_template_id)
	var role_def = template.get("role_definitions", {}).get(role_id, {})
	var responsibilities = role_def.get("responsibilities", [])

	if responsibilities.is_empty():
		return role_data.get("title", "项目成员")

	return "%s: %s" % [
		role_data.get("title", ""),
		", ".join(responsibilities)
	]

func _on_task_completed(ai_id: String, task: Dictionary, result: Dictionary) -> void:
	"""任务完成回调"""

	if _active_project == null:
		return

	# 检查任务是否属于当前项目
	var tags = task.get("tags", [])
	if not _active_project.id in tags:
		return

	# 更新Epic进度
	var current_epic = _active_project.get_current_epic()
	if current_epic == null:
		return

	_update_epic_progress(current_epic)

func _update_epic_progress(epic: EpicData) -> void:
	"""更新Epic进度"""

	if not _task_system:
		return

	# 统计Epic相关任务的完成情况
	var total_tasks = epic.work_tasks.size()
	var completed_tasks = 0

	for character_name in epic.assigned_characters:
		var history = _task_system.get_task_history(character_name)

		for task in history:
			if task.get("id", "") in epic.work_tasks and task.get("state", -1) == TaskSystem.TaskState.COMPLETED:
				completed_tasks += 1

	if total_tasks > 0:
		epic.progress = float(completed_tasks) / float(total_tasks)

	# 检查Epic是否完成
	if epic.progress >= 0.8:  # 80%完成度视为Epic完成
		_complete_epic(_active_project, epic)

func _complete_epic(project: ProjectData, epic: EpicData) -> void:
	"""完成Epic"""

	epic.status = EpicData.EpicStatus.COMPLETED
	epic.completed_at = _get_current_timestamp()
	epic.quality_score = _evaluate_epic_quality(epic)

	project_epic_completed.emit(project, epic)

	# 创建记忆
	_create_project_memory(
		project,
		"Epic完成",
		"阶段 '%s' 已完成,质量评分: %.1f" % [epic.title, epic.quality_score],
		epic.assigned_characters
	)

	# 更新团队关系 (Epic协作影响)
	_update_relationships_after_epic(epic)

	# 启动下一个Epic
	project.current_epic_index += 1
	_start_next_epic(project)

func _evaluate_epic_quality(epic: EpicData) -> float:
	"""评估Epic质量 (简化版,基于任务完成情况)"""

	if not _task_system:
		return 75.0

	var total_quality = 0.0
	var task_count = 0

	for character_name in epic.assigned_characters:
		var history = _task_system.get_task_history(character_name)

		for task in history:
			if task.get("id", "") in epic.work_tasks:
				var quality = task.get("result", {}).get("quality_score", 0.75)
				total_quality += quality * 100.0
				task_count += 1

	if task_count == 0:
		return 75.0

	return total_quality / float(task_count)

func _update_relationships_after_epic(epic: EpicData) -> void:
	"""Epic完成后更新角色关系"""

	if not _relationship_manager:
		return

	# 团队协作提升关系
	for i in range(epic.assigned_characters.size()):
		for j in range(i + 1, epic.assigned_characters.size()):
			var char_a = epic.assigned_characters[i]
			var char_b = epic.assigned_characters[j]

			# 根据Epic质量决定关系变化
			var quality_tier = "good" if epic.quality_score >= 70 else "barely"
			var trust_change = 5.0 if quality_tier == "good" else 2.0
			var respect_change = 3.0 if quality_tier == "good" else 1.0

			var changes = {
				"trust": trust_change,
				"respect": respect_change,
				"affection": 1.0
			}

			_relationship_manager.modify_relationship(char_a, char_b, changes, "共同完成项目阶段")

# ========================================
# 项目验收流程
# ========================================

func _start_project_review(project: ProjectData) -> void:
	"""开始项目验收"""

	project.status = ProjectData.ProjectStatus.REVIEW

	print("[ProjectSystem] 项目进入验收阶段: %s" % project.title)

	# 请求LLM评估项目
	_request_llm_evaluation(project)

func _request_llm_evaluation(project: ProjectData) -> void:
	"""请求LLM评估项目完成质量"""

	var prompt = _build_evaluation_prompt(project)

	if _api_manager:
		var character_name = "Stephen"  # 项目经理负责验收
		var callback = Callable(self, "_on_llm_evaluation_response").bind(project.id)

		if _api_manager.has_method("send_request"):
			_api_manager.send_request(character_name, prompt, callback)
			print("[ProjectSystem] 已发送LLM评估请求...")
		else:
			_fallback_evaluate_project(project)
	else:
		# 降级: 简单评估
		_fallback_evaluate_project(project)

func _build_evaluation_prompt(project: ProjectData) -> String:
	"""构建LLM评估提示词"""

	var epics_summary = _format_epics_summary(project)
	var template_manager = get_node_or_null("/root/ProjectTypeTemplates")
	var template_name = "未知"
	if template_manager:
		var template = template_manager.get_template(project.type_template_id)
		template_name = template.get("name", "未知")

	var prompt = """# 项目验收评估

你是一位专业的项目验收评估专家,需要对以下已完成的项目进行质量评估。

## 项目信息
- **项目名称**: %s
- **项目类型**: %s
- **需求描述**:
%s

- **预算**: %d 金币
- **原定工期**: %d 天
- **实际工期**: %d 天 (%s)
- **质量要求**: %s

## Epic完成情况
%s

## 你的任务
请根据以上信息,对项目进行综合评估,给出:
1. **完成度评分** (0-100分): 项目需求完成的程度
2. **质量评分** (0-100分): 项目质量的整体水平
3. **优点** (列举3-5条)
4. **缺点** (列举3-5条)
5. **总体评价** (1-2句话总结)

## 输出格式 (严格JSON)
```json
{
  "completion_rate": 0.85,
  "quality_score": 78,
  "strengths": ["优点1", "优点2", "优点3"],
  "weaknesses": ["缺点1", "缺点2"],
  "summary": "总体评价文字",
  "bonus_adjustment": 1.0
}
```

**说明:**
- `completion_rate`: 完成度 (0.0-1.0)
- `quality_score`: 质量分 (0-100)
- `bonus_adjustment`: 奖金调整系数 (0.5-1.5,基于综合表现)
- 只输出JSON,不要添加其他文本

现在开始评估:
""" % [
		project.title,
		template_name,
		project.description,
		project.budget,
		project.duration_days,
		_calculate_actual_days(project),
		"延期" if project.is_overdue() else "准时",
		project.quality_requirement,
		epics_summary
	]

	return prompt

func _format_epics_summary(project: ProjectData) -> String:
	"""格式化Epic完成情况"""
	var lines = []
	for i in range(project.epics.size()):
		var epic = project.epics[i]
		var status_text = "✓" if epic.status == EpicData.EpicStatus.COMPLETED else "✗"
		lines.append("%d. %s %s - 质量: %.1f分 (进度: %.0f%%)" % [
			i + 1,
			status_text,
			epic.title,
			epic.quality_score,
			epic.progress * 100.0
		])
	return "\n".join(lines)

func _calculate_actual_days(project: ProjectData) -> int:
	"""计算实际用时天数"""
	if project.completed_at <= 0:
		var current_time = _get_current_timestamp()
		var duration_seconds = current_time - project.started_at
		return int(duration_seconds / 86400.0)
	var duration_seconds = project.completed_at - project.started_at
	return int(duration_seconds / 86400.0)

func _on_llm_evaluation_response(response_text: String, project_id: String) -> void:
	"""LLM评估响应回调"""

	if _active_project == null or _active_project.id != project_id:
		return

	print("[ProjectSystem] 收到LLM评估响应,开始解析...")

	var evaluation = _parse_llm_evaluation_response(response_text)

	if evaluation.is_empty():
		push_error("[ProjectSystem] LLM评估响应解析失败,使用降级方案")
		_fallback_evaluate_project(_active_project)
		return

	_finalize_project_evaluation(_active_project, evaluation)

func _parse_llm_evaluation_response(response_text: String) -> Dictionary:
	"""解析LLM评估响应"""

	var json_start = response_text.find("{")
	var json_end = response_text.rfind("}")

	if json_start == -1 or json_end == -1:
		return {}

	var json_str = response_text.substr(json_start, json_end - json_start + 1)
	var result = JSON.parse_string(json_str)

	if typeof(result) != TYPE_DICTIONARY:
		return {}

	return result

func _fallback_evaluate_project(project: ProjectData) -> void:
	"""降级评估方案"""

	print("[ProjectSystem] 使用降级评估方案")

	# 简单计算
	var avg_epic_quality = 0.0
	var completed_epics = 0

	for epic in project.epics:
		if epic.status == EpicData.EpicStatus.COMPLETED:
			completed_epics += 1
			avg_epic_quality += epic.quality_score

	var completion_rate = float(completed_epics) / max(1.0, float(project.epics.size()))
	var quality_score = avg_epic_quality / max(1.0, float(completed_epics))

	var evaluation = {
		"completion_rate": completion_rate,
		"quality_score": quality_score,
		"strengths": ["按时完成", "团队协作良好"],
		"weaknesses": ["部分细节待优化"],
		"summary": "项目整体完成情况良好",
		"bonus_adjustment": 1.0
	}

	_finalize_project_evaluation(project, evaluation)

func _finalize_project_evaluation(project: ProjectData, evaluation: Dictionary) -> void:
	"""完成项目评估并结算"""

	# 保存评估结果
	project.llm_evaluation_result = evaluation
	project.completion_rate = evaluation.get("completion_rate", 0.8)
	project.quality_score = evaluation.get("quality_score", 75.0)

	# 计算延期天数
	var actual_days = _calculate_actual_days(project)
	project.days_overdue = max(0, actual_days - project.duration_days)

	# 判断成功/失败
	if project.completion_rate >= 0.6:
		project.status = ProjectData.ProjectStatus.COMPLETED
		_complete_project_success(project, evaluation)
	else:
		project.status = ProjectData.ProjectStatus.FAILED
		_complete_project_failure(project, evaluation)

	project.completed_at = _get_current_timestamp()

	project_evaluated.emit(project, evaluation)

	# 移动到历史
	_project_history.append(project)
	_active_project = null

	_save_project(project)

func _complete_project_success(project: ProjectData, evaluation: Dictionary) -> void:
	"""项目成功完成"""

	print("[ProjectSystem] 项目验收成功: %s (完成度: %.1f%%, 质量: %.1f)" % [
		project.title,
		project.completion_rate * 100.0,
		project.quality_score
	])

	# 计算并发放奖金
	_distribute_project_bonus(project, evaluation)

	# 创建记忆
	_create_project_memory(
		project,
		"项目成功",
		"项目 '%s' 验收成功!完成度%.0f%%,质量%.0f分。%s" % [
			project.title,
			project.completion_rate * 100.0,
			project.quality_score,
			evaluation.get("summary", "")
		]
	)

	# 更新关系 (项目成功)
	_update_relationships_after_project(project, "perfect" if project.completion_rate >= 0.9 else "good")

	project_completed.emit(project)

func _complete_project_failure(project: ProjectData, evaluation: Dictionary) -> void:
	"""项目失败"""

	print("[ProjectSystem] 项目验收失败: %s (完成度: %.1f%%)" % [
		project.title,
		project.completion_rate * 100.0
	])

	# 创建记忆
	_create_project_memory(
		project,
		"项目失败",
		"项目 '%s' 验收失败...完成度仅%.0f%%。%s" % [
			project.title,
			project.completion_rate * 100.0,
			evaluation.get("summary", "")
		]
	)

	# 更新关系 (项目失败)
	_update_relationships_after_project(project, "failed")

	project_failed.emit(project, "完成度不足")

func _distribute_project_bonus(project: ProjectData, evaluation: Dictionary) -> void:
	"""分配项目奖金"""

	if not _economy_manager:
		return

	# 获取难度配置
	var difficulty_mode = _get_difficulty_mode_string(project.difficulty_mode)

	var difficulty_config = get_node_or_null("/root/ProjectDifficultyConfig")
	if not difficulty_config:
		push_warning("[ProjectSystem] ProjectDifficultyConfig未找到")
		return

	# 计算奖金系数
	var multiplier = difficulty_config.calculate_bonus_multiplier(
		difficulty_mode,
		project.completion_rate,
		project.quality_score,
		project.days_overdue
	)

	# LLM调整系数
	var llm_adjustment = evaluation.get("bonus_adjustment", 1.0)
	multiplier *= llm_adjustment

	# 总奖金
	var total_bonus = int(float(project.bonus_pool) * multiplier)

	# 平均分配给所有参与角色
	var participants = project.character_roles.keys()
	var bonus_per_person = int(total_bonus / max(1, participants.size()))

	var bonus_data = {}

	for character_name in participants:
		# 发放奖金
		if _economy_manager.has_method("add_money"):
			_economy_manager.add_money(character_name, bonus_per_person, "项目奖金: %s" % project.title)

		bonus_data[character_name] = bonus_per_person
		project.bonus_paid[character_name] = bonus_per_person

		print("[ProjectSystem] %s 获得项目奖金: %d" % [character_name, bonus_per_person])

	bonus_distributed.emit(project, bonus_data)

func _get_difficulty_mode_string(mode: int) -> String:
	"""将难度模式枚举转为字符串"""
	match mode:
		ProjectData.DifficultyMode.STRICT:
			return "strict"
		ProjectData.DifficultyMode.BALANCED:
			return "balanced"
		ProjectData.DifficultyMode.RELAXED:
			return "relaxed"
		_:
			return "balanced"

func _update_relationships_after_project(project: ProjectData, result: String) -> void:
	"""项目完成后更新关系"""

	if not _relationship_manager:
		return

	var difficulty_mode = _get_difficulty_mode_string(project.difficulty_mode)
	var difficulty_config = get_node_or_null("/root/ProjectDifficultyConfig")
	if not difficulty_config:
		return

	var effects = difficulty_config.get_relationship_effect(difficulty_mode, result)

	var boss_effect = effects.get("boss", 0)
	var team_effect = effects.get("team", 0)

	# 与老板的关系变化
	for character_name in project.character_roles.keys():
		if character_name == "Stephen":
			continue

		var changes = {
			"respect": boss_effect,
			"trust": boss_effect * 0.8
		}

		_relationship_manager.modify_relationship(character_name, "Stephen", changes, "项目结果")

	# 团队成员之间关系变化
	var participants = project.character_roles.keys()
	for i in range(participants.size()):
		for j in range(i + 1, participants.size()):
			var changes = {
				"trust": team_effect,
				"respect": team_effect * 0.6
			}

			_relationship_manager.modify_relationship(
				participants[i],
				participants[j],
				changes,
				"项目协作"
			)

# ========================================
# 时间事件
# ========================================

func _on_day_changed(day: int, season: String) -> void:
	"""每日检查"""

	if _active_project == null:
		return

	# 检查项目状态
	_check_project_deadline(_active_project)

func _on_hour_changed(hour: int) -> void:
	"""每小时检查"""
	pass

func _check_project_deadline(project: ProjectData) -> void:
	"""检查项目是否延期"""

	if project.deadline <= 0:
		return

	var current_time = _get_current_timestamp()
	if current_time > project.deadline:
		var overdue_days = int((current_time - project.deadline) / 86400.0)
		project.days_overdue = overdue_days

		if overdue_days == 1:
			# 第一天延期,创建记忆
			_create_project_memory(
				project,
				"项目延期",
				"警告: 项目已延期!"
			)

# ========================================
# 辅助函数
# ========================================

func get_active_project() -> ProjectData:
	"""获取当前活跃项目"""
	return _active_project

func get_project_history() -> Array:
	"""获取历史项目列表"""
	return _project_history.duplicate()

func has_active_project() -> bool:
	"""是否有活跃项目"""
	return _active_project != null

func _create_project_memory(
	project: ProjectData,
	memory_type: String,
	content: String,
	target_characters: Array = []
) -> void:
	"""创建项目相关记忆"""

	if not _memory_manager:
		return

	var characters = target_characters if not target_characters.is_empty() else project.character_roles.keys()

	for character_name in characters:
		if _memory_manager.has_method("add_memory"):
			_memory_manager.add_memory(
				character_name,
				content,
				0,  # MemoryType.EVENT 假设为0
				2   # MemoryImportance.HIGH 假设为2
			)

func _generate_project_id() -> String:
	"""生成项目ID"""
	return "project_%d" % Time.get_ticks_msec()

func _get_current_timestamp() -> float:
	"""获取当前时间戳"""
	if _time_system and _time_system.has_method("get_current_timestamp"):
		return _time_system.get_current_timestamp()
	return Time.get_unix_time_from_system()

func _save_project(project: ProjectData) -> void:
	"""保存项目数据"""
	# 确保目录存在
	var dir = DirAccess.open("user://")
	if dir:
		if not dir.dir_exists("projects"):
			dir.make_dir("projects")

	# 保存为JSON
	var save_path = PROJECT_SAVE_PATH + project.id + ".json"
	var file = FileAccess.open(save_path, FileAccess.WRITE)
	if file:
		var json_str = JSON.stringify(project.to_dict(), "\t")
		file.store_string(json_str)
		file.close()
		print("[ProjectSystem] 项目已保存: %s" % save_path)
	else:
		push_error("[ProjectSystem] 无法保存项目: %s" % save_path)

func _load_projects() -> void:
	"""加载项目数据"""
	var dir = DirAccess.open(PROJECT_SAVE_PATH)
	if not dir:
		print("[ProjectSystem] 项目保存目录不存在,跳过加载")
		return

	dir.list_dir_begin()
	var file_name = dir.get_next()

	while file_name != "":
		if file_name.ends_with(".json"):
			var file_path = PROJECT_SAVE_PATH + file_name
			var file = FileAccess.open(file_path, FileAccess.READ)
			if file:
				var json_str = file.get_as_text()
				file.close()

				var result = JSON.parse_string(json_str)
				if typeof(result) == TYPE_DICTIONARY:
					var project = ProjectData.from_dict(result)
					if project:
						# 根据状态决定是活跃项目还是历史项目
						if project.status in [
							ProjectData.ProjectStatus.PLANNING,
							ProjectData.ProjectStatus.IN_PROGRESS,
							ProjectData.ProjectStatus.REVIEW
						]:
							_active_project = project
							print("[ProjectSystem] 加载活跃项目: %s" % project.title)
						else:
							_project_history.append(project)

		file_name = dir.get_next()

	dir.list_dir_end()

	if _active_project:
		print("[ProjectSystem] 已加载活跃项目: %s" % _active_project.title)
	print("[ProjectSystem] 已加载%d个历史项目" % _project_history.size())
