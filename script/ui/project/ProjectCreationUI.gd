# script/ui/project/ProjectCreationUI.gd
extends Control

# ========================================
# UI节点引用
# ========================================

@onready var type_dropdown: OptionButton = $Panel/VBox/TypeRow/TypeDropdown
@onready var title_input: LineEdit = $Panel/VBox/TitleRow/TitleInput
@onready var description_text: TextEdit = $Panel/VBox/DescriptionRow/DescriptionText
@onready var budget_slider: HSlider = $Panel/VBox/BudgetRow/BudgetSlider
@onready var budget_label: Label = $Panel/VBox/BudgetRow/BudgetLabel
@onready var duration_slider: HSlider = $Panel/VBox/DurationRow/DurationSlider
@onready var duration_label: Label = $Panel/VBox/DurationRow/DurationLabel
@onready var quality_high: CheckBox = $Panel/VBox/QualityRow/QualityHigh
@onready var quality_medium: CheckBox = $Panel/VBox/QualityRow/QualityMedium
@onready var quality_low: CheckBox = $Panel/VBox/QualityRow/QualityLow
@onready var difficulty_strict: CheckBox = $Panel/VBox/DifficultyRow/DifficultyStrict
@onready var difficulty_balanced: CheckBox = $Panel/VBox/DifficultyRow/DifficultyBalanced
@onready var difficulty_relaxed: CheckBox = $Panel/VBox/DifficultyRow/DifficultyRelaxed
@onready var create_button: Button = $Panel/VBox/ButtonRow/CreateButton
@onready var cancel_button: Button = $Panel/VBox/ButtonRow/CancelButton

# ========================================
# 数据
# ========================================

var _template_list: Array = []
var _selected_template_id: String = "software_development"

# ========================================
# 初始化
# ========================================

func _ready() -> void:
	_populate_project_types()
	_connect_signals()
	_set_default_values()

func _populate_project_types() -> void:
	"""填充项目类型下拉列表"""
	var template_manager = get_node_or_null("/root/ProjectTypeTemplates")
	if not template_manager:
		push_error("[ProjectCreationUI] ProjectTypeTemplates未找到")
		return

	_template_list = template_manager.get_template_list()

	if type_dropdown:
		type_dropdown.clear()
		for i in range(_template_list.size()):
			var template = _template_list[i]
			type_dropdown.add_item(template.get("name", ""), i)

		if _template_list.size() > 0:
			type_dropdown.selected = 0
			_selected_template_id = _template_list[0].get("id", "software_development")

func _connect_signals() -> void:
	"""连接信号"""
	if type_dropdown:
		type_dropdown.item_selected.connect(_on_type_selected)

	if budget_slider:
		budget_slider.value_changed.connect(_on_budget_changed)

	if duration_slider:
		duration_slider.value_changed.connect(_on_duration_changed)

	# 质量要求单选
	if quality_high:
		quality_high.toggled.connect(_on_quality_high_toggled)
	if quality_medium:
		quality_medium.toggled.connect(_on_quality_medium_toggled)
	if quality_low:
		quality_low.toggled.connect(_on_quality_low_toggled)

	# 难度模式单选
	if difficulty_strict:
		difficulty_strict.toggled.connect(_on_difficulty_strict_toggled)
	if difficulty_balanced:
		difficulty_balanced.toggled.connect(_on_difficulty_balanced_toggled)
	if difficulty_relaxed:
		difficulty_relaxed.toggled.connect(_on_difficulty_relaxed_toggled)

	if create_button:
		create_button.pressed.connect(_on_create_button_pressed)

	if cancel_button:
		cancel_button.pressed.connect(_on_cancel_button_pressed)

func _set_default_values() -> void:
	"""设置默认值"""
	if budget_slider:
		budget_slider.min_value = 10000
		budget_slider.max_value = 200000
		budget_slider.step = 5000
		budget_slider.value = 50000

	if duration_slider:
		duration_slider.min_value = 5
		duration_slider.max_value = 90
		duration_slider.step = 1
		duration_slider.value = 30

	# 默认中等质量
	if quality_medium:
		quality_medium.button_pressed = true

	# 默认平衡难度
	if difficulty_balanced:
		difficulty_balanced.button_pressed = true

	_update_budget_label(50000)
	_update_duration_label(30)

# ========================================
# 信号处理
# ========================================

func _on_type_selected(index: int) -> void:
	"""项目类型选择改变"""
	if index >= 0 and index < _template_list.size():
		_selected_template_id = _template_list[index].get("id", "software_development")
		print("[ProjectCreationUI] 选择项目类型: %s" % _selected_template_id)

func _on_budget_changed(value: float) -> void:
	"""预算滑块改变"""
	_update_budget_label(int(value))

func _on_duration_changed(value: float) -> void:
	"""工期滑块改变"""
	_update_duration_label(int(value))

func _update_budget_label(value: int) -> void:
	"""更新预算标签"""
	if budget_label:
		budget_label.text = "%d 金币" % value

func _update_duration_label(value: int) -> void:
	"""更新工期标签"""
	if duration_label:
		duration_label.text = "%d 天" % value

# 质量要求单选处理
func _on_quality_high_toggled(pressed: bool) -> void:
	if pressed:
		if quality_medium:
			quality_medium.button_pressed = false
		if quality_low:
			quality_low.button_pressed = false

func _on_quality_medium_toggled(pressed: bool) -> void:
	if pressed:
		if quality_high:
			quality_high.button_pressed = false
		if quality_low:
			quality_low.button_pressed = false

func _on_quality_low_toggled(pressed: bool) -> void:
	if pressed:
		if quality_high:
			quality_high.button_pressed = false
		if quality_medium:
			quality_medium.button_pressed = false

# 难度模式单选处理
func _on_difficulty_strict_toggled(pressed: bool) -> void:
	if pressed:
		if difficulty_balanced:
			difficulty_balanced.button_pressed = false
		if difficulty_relaxed:
			difficulty_relaxed.button_pressed = false

func _on_difficulty_balanced_toggled(pressed: bool) -> void:
	if pressed:
		if difficulty_strict:
			difficulty_strict.button_pressed = false
		if difficulty_relaxed:
			difficulty_relaxed.button_pressed = false

func _on_difficulty_relaxed_toggled(pressed: bool) -> void:
	if pressed:
		if difficulty_strict:
			difficulty_strict.button_pressed = false
		if difficulty_balanced:
			difficulty_balanced.button_pressed = false

func _on_create_button_pressed() -> void:
	"""创建项目按钮"""
	var config = {
		"type_template_id": _selected_template_id,
		"title": title_input.text if title_input else "未命名项目",
		"description": description_text.text if description_text else "",
		"budget": int(budget_slider.value) if budget_slider else 50000,
		"duration_days": int(duration_slider.value) if duration_slider else 30,
		"quality_requirement": _get_selected_quality(),
		"difficulty_mode": _get_selected_difficulty()
	}

	# 验证输入
	if config["title"].strip_edges().is_empty():
		print("[ProjectCreationUI] 错误: 项目名称不能为空")
		return

	if config["description"].strip_edges().is_empty():
		print("[ProjectCreationUI] 错误: 需求描述不能为空")
		return

	# 调用ProjectSystem创建项目
	var project_system = get_node_or_null("/root/ProjectSystem")
	if not project_system:
		push_error("[ProjectCreationUI] ProjectSystem未找到")
		return

	var project = project_system.create_project(config)

	if project:
		print("[ProjectCreationUI] 项目创建成功: %s" % project.title)

		# 启动项目
		project_system.start_project(project.id)

		# 关闭UI
		queue_free()
	else:
		print("[ProjectCreationUI] 项目创建失败")

func _on_cancel_button_pressed() -> void:
	"""取消按钮"""
	queue_free()

# ========================================
# 辅助方法
# ========================================

func _get_selected_quality() -> String:
	"""获取选中的质量要求"""
	if quality_high and quality_high.button_pressed:
		return "high"
	elif quality_low and quality_low.button_pressed:
		return "low"
	else:
		return "medium"

func _get_selected_difficulty() -> String:
	"""获取选中的难度模式"""
	if difficulty_strict and difficulty_strict.button_pressed:
		return "strict"
	elif difficulty_relaxed and difficulty_relaxed.button_pressed:
		return "relaxed"
	else:
		return "balanced"
