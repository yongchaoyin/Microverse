# script/ui/project/ProjectMonitorUI.gd
extends Control

# ========================================
# UI节点引用
# ========================================

@onready var title_label: Label = $Panel/VBox/TitleLabel
@onready var status_label: Label = $Panel/VBox/StatusRow/StatusLabel
@onready var budget_label: Label = $Panel/VBox/BudgetRow/BudgetLabel
@onready var duration_label: Label = $Panel/VBox/DurationRow/DurationLabel
@onready var progress_bar: ProgressBar = $Panel/VBox/ProgressRow/ProgressBar
@onready var current_epic_label: Label = $Panel/VBox/CurrentEpicRow/CurrentEpicLabel
@onready var current_epic_progress: ProgressBar = $Panel/VBox/CurrentEpicRow/CurrentEpicProgress
@onready var completed_epics_list: VBoxContainer = $Panel/VBox/ScrollContainer/CompletedEpicsList
@onready var pending_epics_list: VBoxContainer = $Panel/VBox/ScrollContainer2/PendingEpicsList
@onready var team_members_label: Label = $Panel/VBox/TeamRow/TeamMembersLabel
@onready var cancel_button: Button = $Panel/VBox/ButtonRow/CancelButton

# ========================================
# 数据
# ========================================

var _project: ProjectData = null
var _project_system: Node = null
var _refresh_timer: Timer = null

# ========================================
# 初始化
# ========================================

func _ready() -> void:
	_project_system = get_node_or_null("/root/ProjectSystem")
	if not _project_system:
		push_error("[ProjectMonitorUI] ProjectSystem未找到")
		visible = false
		return

	# 连接信号
	_connect_signals()

	# 创建刷新计时器
	_refresh_timer = Timer.new()
	_refresh_timer.wait_time = 1.0
	_refresh_timer.one_shot = false
	_refresh_timer.timeout.connect(_refresh_display)
	add_child(_refresh_timer)
	_refresh_timer.start()

	# 首次刷新
	_refresh_display()

	if cancel_button:
		cancel_button.pressed.connect(_on_cancel_button_pressed)

func _connect_signals() -> void:
	"""连接ProjectSystem信号"""
	if _project_system:
		_project_system.project_epic_started.connect(_on_epic_started)
		_project_system.project_epic_completed.connect(_on_epic_completed)
		_project_system.project_completed.connect(_on_project_completed)
		_project_system.project_failed.connect(_on_project_failed)

# ========================================
# 刷新显示
# ========================================

func _refresh_display() -> void:
	"""刷新显示"""
	if not _project_system:
		return

	_project = _project_system.get_active_project()

	if not _project:
		visible = false
		return

	visible = true

	# 更新标题
	if title_label:
		title_label.text = "项目: %s" % _project.title

	# 更新状态
	if status_label:
		var status_text = _project.get_status_text()
		var status_color = _get_status_color(_project.status)
		status_label.text = "状态: %s" % status_text
		status_label.add_theme_color_override("font_color", status_color)

	# 更新预算
	if budget_label:
		budget_label.text = "预算: %d 金币" % _project.budget

	# 更新工期
	if duration_label:
		var elapsed_days = _calculate_elapsed_days()
		var remaining_days = _project.duration_days - elapsed_days
		duration_label.text = "工期: %d/%d 天 (剩余%d天)" % [
			elapsed_days,
			_project.duration_days,
			max(0, remaining_days)
		]

	# 更新总进度
	if progress_bar:
		progress_bar.value = _project.get_progress_percentage()

	# 更新当前Epic
	_update_current_epic()

	# 更新Epic列表
	_update_epic_lists()

	# 更新团队成员
	_update_team_members()

func _calculate_elapsed_days() -> int:
	"""计算已用天数"""
	if _project.started_at <= 0:
		return 0

	var time_system = get_node_or_null("/root/TimeSystem")
	var current_time = 0.0
	if time_system and time_system.has_method("get_current_timestamp"):
		current_time = time_system.get_current_timestamp()
	else:
		current_time = Time.get_unix_time_from_system()

	var duration_seconds = current_time - _project.started_at
	return int(duration_seconds / 86400.0)

func _get_status_color(status: int) -> Color:
	"""获取状态颜色"""
	match status:
		0:  # NOT_STARTED
			return Color.GRAY
		1:  # PLANNING
			return Color.YELLOW
		2:  # IN_PROGRESS
			return Color.GREEN
		3:  # REVIEW
			return Color.CYAN
		4:  # COMPLETED
			return Color.DARK_GREEN
		5:  # FAILED
			return Color.RED
		6:  # CANCELLED
			return Color.DARK_GRAY
		_:
			return Color.WHITE

func _update_current_epic() -> void:
	"""更新当前Epic显示"""
	var current_epic = _project.get_current_epic()

	if not current_epic:
		if current_epic_label:
			current_epic_label.text = "当前阶段: 无"
		if current_epic_progress:
			current_epic_progress.visible = false
		return

	if current_epic_label:
		current_epic_label.text = "当前阶段: %s" % current_epic.title

	if current_epic_progress:
		current_epic_progress.visible = true
		current_epic_progress.value = current_epic.get_progress_percentage()

func _update_epic_lists() -> void:
	"""更新Epic列表"""
	if not completed_epics_list or not pending_epics_list:
		return

	# 清空列表
	for child in completed_epics_list.get_children():
		child.queue_free()

	for child in pending_epics_list.get_children():
		child.queue_free()

	# 填充Epic
	for epic in _project.epics:
		var epic_label = Label.new()
		var status_icon = "✓" if epic.status == 3 else "●" if epic.status == 1 else "○"  # 3=COMPLETED, 1=IN_PROGRESS
		var quality_text = " (质量: %.0f)" % epic.quality_score if epic.quality_score > 0 else ""

		epic_label.text = "%s %s%s" % [status_icon, epic.title, quality_text]

		if epic.status == 3:  # COMPLETED
			epic_label.add_theme_color_override("font_color", Color.DARK_GREEN)
			completed_epics_list.add_child(epic_label)
		elif epic.status == 1:  # IN_PROGRESS
			epic_label.add_theme_color_override("font_color", Color.GREEN)
			# 进度条
			var progress = ProgressBar.new()
			progress.value = epic.get_progress_percentage()
			progress.custom_minimum_size = Vector2(200, 20)

			var row = HBoxContainer.new()
			row.add_child(epic_label)
			row.add_child(progress)
			completed_epics_list.add_child(row)
		else:  # PENDING
			epic_label.add_theme_color_override("font_color", Color.GRAY)
			pending_epics_list.add_child(epic_label)

func _update_team_members() -> void:
	"""更新团队成员显示"""
	if not team_members_label:
		return

	var members = []
	for character_name in _project.character_roles.keys():
		var role_data = _project.character_roles[character_name]
		var title = role_data.get("title", "")
		members.append("%s (%s)" % [character_name, title])

	team_members_label.text = "团队成员: %s" % ", ".join(members)

# ========================================
# 信号处理
# ========================================

func _on_epic_started(project: ProjectData, epic: EpicData) -> void:
	"""Epic启动回调"""
	_refresh_display()

func _on_epic_completed(project: ProjectData, epic: EpicData) -> void:
	"""Epic完成回调"""
	_refresh_display()

func _on_project_completed(project: ProjectData) -> void:
	"""项目完成回调"""
	_refresh_display()
	# 可以在这里显示验收结果UI
	if _refresh_timer:
		_refresh_timer.stop()

func _on_project_failed(project: ProjectData, reason: String) -> void:
	"""项目失败回调"""
	_refresh_display()
	if _refresh_timer:
		_refresh_timer.stop()

func _on_cancel_button_pressed() -> void:
	"""取消项目按钮"""
	if not _project or not _project_system:
		return

	# 确认对话框
	var confirm_dialog = ConfirmationDialog.new()
	confirm_dialog.dialog_text = "确定要取消项目 '%s' 吗?" % _project.title
	confirm_dialog.confirmed.connect(_confirm_cancel_project)
	add_child(confirm_dialog)
	confirm_dialog.popup_centered()

func _confirm_cancel_project() -> void:
	"""确认取消项目"""
	if _project_system and _project:
		_project_system.cancel_project(_project.id, "用户取消")
		queue_free()
