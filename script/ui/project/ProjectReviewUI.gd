# script/ui/project/ProjectReviewUI.gd
extends Control

# ========================================
# UI节点引用
# ========================================

@onready var result_label: Label = $Panel/VBox/ResultLabel
@onready var project_name_label: Label = $Panel/VBox/ProjectNameLabel
@onready var completion_label: Label = $Panel/VBox/CompletionRow/CompletionLabel
@onready var quality_label: Label = $Panel/VBox/QualityRow/QualityLabel
@onready var duration_label: Label = $Panel/VBox/DurationRow/DurationLabel
@onready var summary_text: RichTextLabel = $Panel/VBox/SummaryRow/SummaryText
@onready var strengths_list: VBoxContainer = $Panel/VBox/StrengthsRow/StrengthsList
@onready var weaknesses_list: VBoxContainer = $Panel/VBox/WeaknessesRow/WeaknessesList
@onready var bonus_total_label: Label = $Panel/VBox/BonusSection/BonusTotalLabel
@onready var bonus_breakdown_list: VBoxContainer = $Panel/VBox/BonusSection/BonusBreakdownList
@onready var confirm_button: Button = $Panel/VBox/ButtonRow/ConfirmButton

# ========================================
# 数据
# ========================================

var _project: ProjectData = null
var _evaluation: Dictionary = {}

# ========================================
# 初始化
# ========================================

func _ready() -> void:
	# 连接ProjectSystem的项目评估信号
	var project_system = get_node_or_null("/root/ProjectSystem")
	if project_system:
		project_system.project_evaluated.connect(_on_project_evaluated)

	if confirm_button:
		confirm_button.pressed.connect(_on_confirm_button_pressed)

	visible = false

# ========================================
# 显示评估结果
# ========================================

func show_review(project: ProjectData, evaluation: Dictionary) -> void:
	"""显示项目评估结果"""
	_project = project
	_evaluation = evaluation

	_display_results()

	visible = true
	# 居中显示
	popup_centered()

func popup_centered() -> void:
	"""居中弹出"""
	if get_viewport():
		var viewport_size = get_viewport().get_visible_rect().size
		var window_size = size
		position = (viewport_size - window_size) / 2

func _display_results() -> void:
	"""显示结果"""
	if not _project or _evaluation.is_empty():
		return

	# 结果标题
	if result_label:
		if _project.status == ProjectData.ProjectStatus.COMPLETED:
			result_label.text = "✓ 项目验收成功!"
			result_label.add_theme_color_override("font_color", Color.GREEN)
		else:
			result_label.text = "✗ 项目验收失败"
			result_label.add_theme_color_override("font_color", Color.RED)

	# 项目名称
	if project_name_label:
		project_name_label.text = "项目名称: %s" % _project.title

	# 完成度
	if completion_label:
		var stars = _get_star_rating(_project.completion_rate)
		completion_label.text = "完成度: %s %.0f%%" % [stars, _project.completion_rate * 100.0]

	# 质量评分
	if quality_label:
		quality_label.text = "质量评分: %.0f 分" % _project.quality_score

	# 实际工期
	if duration_label:
		var actual_days = _calculate_actual_days()
		var status_text = "准时" if _project.days_overdue == 0 else "延期%d天" % _project.days_overdue
		duration_label.text = "实际工期: %d 天 (%s)" % [actual_days, status_text]

	# 评估总结
	if summary_text:
		var summary = _evaluation.get("summary", "项目已完成")
		summary_text.text = summary

	# 优点列表
	_display_list(strengths_list, _evaluation.get("strengths", []), Color.GREEN)

	# 缺点列表
	_display_list(weaknesses_list, _evaluation.get("weaknesses", []), Color.ORANGE)

	# 奖金信息
	_display_bonus_info()

func _calculate_actual_days() -> int:
	"""计算实际天数"""
	if _project.completed_at <= 0 or _project.started_at <= 0:
		return 0
	var duration_seconds = _project.completed_at - _project.started_at
	return int(duration_seconds / 86400.0)

func _get_star_rating(rate: float) -> String:
	"""获取星级评分"""
	var stars_count = int(rate * 5.0)
	var stars = ""
	for i in range(stars_count):
		stars += "★"
	for i in range(5 - stars_count):
		stars += "☆"
	return stars

func _display_list(container: VBoxContainer, items: Array, color: Color) -> void:
	"""显示列表"""
	if not container:
		return

	# 清空
	for child in container.get_children():
		child.queue_free()

	# 填充
	for item in items:
		var label = Label.new()
		label.text = "• %s" % item
		label.add_theme_color_override("font_color", color)
		container.add_child(label)

func _display_bonus_info() -> void:
	"""显示奖金信息"""
	if not _project:
		return

	# 计算奖金总额
	var total_bonus = 0
	for character_name in _project.bonus_paid.keys():
		total_bonus += _project.bonus_paid[character_name]

	if bonus_total_label:
		bonus_total_label.text = "总奖金: %d 金币" % total_bonus

	# 奖金明细
	if bonus_breakdown_list:
		# 清空
		for child in bonus_breakdown_list.get_children():
			child.queue_free()

		# 基础奖金
		var base_label = Label.new()
		base_label.text = "基础奖金: %d 金币" % _project.budget
		bonus_breakdown_list.add_child(base_label)

		# 系数
		var difficulty_config = get_node_or_null("/root/ProjectDifficultyConfig")
		if difficulty_config:
			var difficulty_mode = _get_difficulty_mode_string(_project.difficulty_mode)
			var multiplier = difficulty_config.calculate_bonus_multiplier(
				difficulty_mode,
				_project.completion_rate,
				_project.quality_score,
				_project.days_overdue
			)

			var multiplier_label = Label.new()
			multiplier_label.text = "综合系数: ×%.2f" % multiplier
			bonus_breakdown_list.add_child(multiplier_label)

		# 各角色分配
		for character_name in _project.bonus_paid.keys():
			var amount = _project.bonus_paid[character_name]
			var char_label = Label.new()
			char_label.text = "%s: +%d" % [character_name, amount]
			char_label.add_theme_color_override("font_color", Color.YELLOW)
			bonus_breakdown_list.add_child(char_label)

func _get_difficulty_mode_string(mode: int) -> String:
	"""获取难度模式字符串"""
	match mode:
		0:  # STRICT
			return "strict"
		1:  # BALANCED
			return "balanced"
		2:  # RELAXED
			return "relaxed"
		_:
			return "balanced"

# ========================================
# 信号处理
# ========================================

func _on_project_evaluated(project: ProjectData, evaluation: Dictionary) -> void:
	"""项目评估完成回调"""
	show_review(project, evaluation)

func _on_confirm_button_pressed() -> void:
	"""确认按钮"""
	queue_free()
