extends Control

# 脚本引用
var BackgroundStoryManager = preload("res://script/ai/background_story/BackgroundStoryManager.gd")

# 项目系统UI场景引用
const PROJECT_CREATION_UI_SCENE = preload("res://scene/ui/project/ProjectCreationUI.tscn")
const PROJECT_MONITOR_UI_SCENE = preload("res://scene/ui/project/ProjectMonitorUI.tscn")

# 面板引用
@onready var left_panel = $HBoxContainer/LeftPanel
@onready var right_panel = $HBoxContainer/RightPanel
@onready var right_panel_container = $HBoxContainer/RightPanel/VBoxContainer
@onready var character_list = $HBoxContainer/LeftPanel/VBoxContainer/CharacterList
@onready var character_detail = $HBoxContainer/LeftPanel/VBoxContainer/CharacterDetail
@onready var toggle_ui_button = $HBoxContainer/RightPanel/VBoxContainer/ToggleUIButton

# 弹窗引用
@onready var implant_memory_popup = $Popups/ImplantMemoryPopup
@onready var disease_popup = $Popups/DiseasePopup
@onready var money_popup = $Popups/MoneyPopup
@onready var emotion_popup = $Popups/EmotionPopup
@onready var task_popup = $Popups/TaskPopup
@onready var background_popup = $Popups/BackgroundPopup

# 角色详情面板引用
@onready var task_detail_list = $HBoxContainer/LeftPanel/VBoxContainer/CharacterDetail/TabContainer/任务/TaskDetailList
@onready var ai_settings_container = $HBoxContainer/LeftPanel/VBoxContainer/CharacterDetail/TabContainer/AI设置/AISettingsContainer
@onready var avatar_sprite = $HBoxContainer/LeftPanel/VBoxContainer/CharacterDetail/HBoxContainer/Avatar/AnimatedSprite2D
@onready var schedule_activity_name_label = $HBoxContainer/LeftPanel/VBoxContainer/CharacterDetail/TabContainer/Schedule/ScheduleContainer/CurrentActivityPanel/ActivityNameLabel
@onready var schedule_activity_location_label = $HBoxContainer/LeftPanel/VBoxContainer/CharacterDetail/TabContainer/Schedule/ScheduleContainer/CurrentActivityPanel/ActivityLocationLabel
@onready var schedule_activity_time_label = $HBoxContainer/LeftPanel/VBoxContainer/CharacterDetail/TabContainer/Schedule/ScheduleContainer/CurrentActivityPanel/ActivityTimeLabel
@onready var schedule_agenda_list = $HBoxContainer/LeftPanel/VBoxContainer/CharacterDetail/TabContainer/Schedule/ScheduleContainer/AgendaList
@onready var schedule_empty_label = $HBoxContainer/LeftPanel/VBoxContainer/CharacterDetail/TabContainer/Schedule/ScheduleContainer/AgendaList/AgendaEmptyLabel
@onready var finance_balance_label = $HBoxContainer/LeftPanel/VBoxContainer/CharacterDetail/TabContainer/经济/FinanceContainer/BalancePanel/BalanceValueLabel
@onready var finance_payroll_label = $HBoxContainer/LeftPanel/VBoxContainer/CharacterDetail/TabContainer/经济/FinanceContainer/BalancePanel/PayrollInfoLabel
@onready var finance_transaction_list = $HBoxContainer/LeftPanel/VBoxContainer/CharacterDetail/TabContainer/经济/FinanceContainer/TransactionList
@onready var finance_empty_label = $HBoxContainer/LeftPanel/VBoxContainer/CharacterDetail/TabContainer/经济/FinanceContainer/TransactionList/TransactionEmptyLabel

# 当前选中的角色
var selected_character = null
var all_characters = []
var ui_visible = true
var _time_system = null
var _time_label: Label = null
var _time_control_buttons: Dictionary = {}
var _event_bus = null
var _schedule_manager = null
var _task_system = null
var _economy_manager = null
var _last_payroll_summary = {}
var _project_system = null
var _project_creation_ui: Control = null
var _project_monitor_ui: Control = null

const TASK_STATE_LABELS := {
	0: "进行中",
	1: "已完成",
	2: "已失败",
	3: "已取消"
}

const TASK_STATE_COLORS := {
	0: Color(0.95, 0.95, 0.95),
	1: Color(0.6, 0.9, 0.6),
	2: Color(0.95, 0.6, 0.6),
	3: Color(0.7, 0.7, 0.7)
}

const LOCATION_LABELS := {
	"OFFICE": "办公室",
	"DEV_DESK": "开发工位",
	"QA_LAB": "测试实验室",
	"HR_OFFICE": "人力资源部",
	"PRODUCT_WAR_ROOM": "产品战情室",
	"EXECUTIVE_OFFICE": "行政办公室",
	"ADMIN_DESK": "行政中心",
	"FRONT_DESK": "前台",
	"BOARD_ROOM": "董事会议室",
	"MEETING_ROOM": "会议室",
	"SCRUM_AREA": "项目讨论区",
	"WORKSHOP": "培训室",
	"CAFETERIA": "餐厅",
	"CAFE": "咖啡馆",
	"COFFEE_SHOP": "咖啡馆",
	"FITNESS": "健身房",
	"GYM": "健身房",
	"LOUNGE": "休闲区",
	"LOBBY": "大厅",
	"PENTHOUSE": "顶层公寓",
	"HOME": "住宅",
	"HOME_DESK": "家庭工位",
	"MARKET": "市集",
	"PARK": "公园"
}

func _ready():
	# 初始隐藏头像动画节点
	if avatar_sprite:
		avatar_sprite.visible = false
	
	# 连接按钮信号
	$HBoxContainer/RightPanel/VBoxContainer/ImplantMemoryButton.pressed.connect(_on_implant_memory_pressed)
	$HBoxContainer/RightPanel/VBoxContainer/DiseaseButton.pressed.connect(_on_disease_pressed)
	$HBoxContainer/RightPanel/VBoxContainer/MoneyButton.pressed.connect(_on_money_pressed)
	$HBoxContainer/RightPanel/VBoxContainer/EmotionButton.pressed.connect(_on_emotion_pressed)
	$HBoxContainer/RightPanel/VBoxContainer/TaskButton.pressed.connect(_on_task_pressed)
	$HBoxContainer/RightPanel/VBoxContainer/BackgroundButton.pressed.connect(_on_background_pressed)
	$HBoxContainer/RightPanel/VBoxContainer/CreateProjectButton.pressed.connect(_on_create_project_pressed)
	toggle_ui_button.pressed.connect(_on_toggle_ui_pressed)
	
	# 连接角色列表信号
	character_list.item_selected.connect(_on_character_selected)
	
	# 连接弹窗按钮信号
	implant_memory_popup.get_node("VBoxContainer/HBoxContainer/CancelButton").pressed.connect(func(): implant_memory_popup.hide())
	implant_memory_popup.get_node("VBoxContainer/HBoxContainer/ConfirmButton").pressed.connect(_on_implant_memory_confirm)
	
	disease_popup.get_node("VBoxContainer/HBoxContainer/CancelButton").pressed.connect(func(): disease_popup.hide())
	disease_popup.get_node("VBoxContainer/HBoxContainer/ConfirmButton").pressed.connect(_on_disease_confirm)
	
	money_popup.get_node("VBoxContainer/HBoxContainer/CancelButton").pressed.connect(func(): money_popup.hide())
	money_popup.get_node("VBoxContainer/HBoxContainer/ConfirmButton").pressed.connect(_on_money_confirm)
	
	emotion_popup.get_node("VBoxContainer/HBoxContainer/CancelButton").pressed.connect(func(): emotion_popup.hide())
	emotion_popup.get_node("VBoxContainer/HBoxContainer/ConfirmButton").pressed.connect(_on_emotion_confirm)
	
	task_popup.get_node("VBoxContainer/ButtonContainer/CloseButton").pressed.connect(func(): task_popup.hide())
	task_popup.get_node("VBoxContainer/ButtonContainer/RefreshButton").pressed.connect(_on_refresh_tasks)
	task_popup.get_node("VBoxContainer/AddTaskContainer/AddTaskButton").pressed.connect(_on_add_task)
	task_popup.get_node("VBoxContainer/AddTaskContainer/PriorityContainer/PrioritySlider").value_changed.connect(_on_priority_changed)
	
	# 连接弹窗的close_requested信号（点击右上角X按钮时触发）
	implant_memory_popup.close_requested.connect(func(): implant_memory_popup.hide())
	disease_popup.close_requested.connect(func(): disease_popup.hide())
	money_popup.close_requested.connect(func(): money_popup.hide())
	emotion_popup.close_requested.connect(func(): emotion_popup.hide())
	task_popup.close_requested.connect(func(): task_popup.hide())
	background_popup.close_requested.connect(func(): background_popup.hide())
	
	# 连接滑块信号
	disease_popup.get_node("VBoxContainer/SeveritySlider").value_changed.connect(_on_disease_severity_changed)
	emotion_popup.get_node("VBoxContainer/EmotionStrength").value_changed.connect(_on_emotion_strength_changed)
	
	_setup_observer_bindings()
	
	# 初始化任务系统
	_init_task_system()
	
	# 初始化疾病选项
	var disease_selector = disease_popup.get_node("VBoxContainer/DiseaseSelector")
	disease_selector.add_item("感冒")
	disease_selector.add_item("发烧")
	disease_selector.add_item("过敏")
	disease_selector.add_item("抑郁")
	disease_selector.add_item("焦虑")
	disease_selector.add_item("受伤")
	
	# 初始化情感类型选项
	var emotion_selector = emotion_popup.get_node("VBoxContainer/EmotionType")
	emotion_selector.add_item("喜欢")
	emotion_selector.add_item("尊敬")
	emotion_selector.add_item("嫉妒")
	emotion_selector.add_item("愤怒")
	emotion_selector.add_item("信任")
	emotion_selector.add_item("怀疑")
	emotion_selector.add_item("崇拜")
	
	# 获取场景中的角色
	_update_character_lists()
	
	_setup_time_controls()
	
	# 初始关闭UI
	_toggle_ui(true)

# 每帧更新一次角色列表，确保能捕获到动态添加的角色
func _process(_delta):
	# 每隔一段时间更新角色列表
	if Engine.get_process_frames() % 60 == 0:  # 每约1秒检查一次
		_update_character_lists()

func _setup_observer_bindings():
	_event_bus = get_node_or_null("/root/EventBus")
	_schedule_manager = get_node_or_null("/root/ScheduleManager")
	_task_system = get_node_or_null("/root/TaskSystem")
	_economy_manager = get_node_or_null("/root/EconomyManager")

	if _schedule_manager and _schedule_manager.has_signal("activity_changed") and not _schedule_manager.activity_changed.is_connected(_on_schedule_manager_activity):
		_schedule_manager.activity_changed.connect(_on_schedule_manager_activity)

	if _task_system:
		if _task_system.has_signal("task_list_refreshed") and not _task_system.task_list_refreshed.is_connected(_on_task_list_signal):
			_task_system.task_list_refreshed.connect(_on_task_list_signal)
		if _task_system.has_signal("task_assigned") and not _task_system.task_assigned.is_connected(_on_task_assigned_signal):
			_task_system.task_assigned.connect(_on_task_assigned_signal)
		if _task_system.has_signal("task_completed") and not _task_system.task_completed.is_connected(_on_task_completed_signal):
			_task_system.task_completed.connect(_on_task_completed_signal)
		if _task_system.has_signal("task_failed") and not _task_system.task_failed.is_connected(_on_task_failed_signal):
			_task_system.task_failed.connect(_on_task_failed_signal)
		if _task_system.has_signal("task_cancelled") and not _task_system.task_cancelled.is_connected(_on_task_cancelled_signal):
			_task_system.task_cancelled.connect(_on_task_cancelled_signal)

	if _economy_manager:
		if _economy_manager.has_signal("balance_changed") and not _economy_manager.balance_changed.is_connected(_on_economy_balance_changed):
			_economy_manager.balance_changed.connect(_on_economy_balance_changed)
		if _economy_manager.has_signal("transaction_recorded") and not _economy_manager.transaction_recorded.is_connected(_on_economy_transaction):
			_economy_manager.transaction_recorded.connect(_on_economy_transaction)
		if _economy_manager.has_signal("payroll_processed") and not _economy_manager.payroll_processed.is_connected(_on_economy_payroll_processed):
			_economy_manager.payroll_processed.connect(_on_economy_payroll_processed)

	# 项目系统集成
	_project_system = get_node_or_null("/root/ProjectSystem")
	if _project_system:
		if _project_system.has_signal("project_started") and not _project_system.project_started.is_connected(_on_project_started):
			_project_system.project_started.connect(_on_project_started)
		if _project_system.has_signal("project_completed") and not _project_system.project_completed.is_connected(_on_project_ended):
			_project_system.project_completed.connect(_on_project_ended)
		if _project_system.has_signal("project_failed") and not _project_system.project_failed.is_connected(_on_project_ended):
			_project_system.project_failed.connect(_on_project_ended)
		if _project_system.has_signal("project_cancelled") and not _project_system.project_cancelled.is_connected(_on_project_ended):
			_project_system.project_cancelled.connect(_on_project_ended)

		# 检查是否已有活跃项目，如果有则显示监控UI
		var active_project = _project_system.get_active_project()
		if active_project:
			_show_project_monitor_ui()

		print("[GodUI] 项目系统集成完成")

func _is_selected_ai(ai_id: String) -> bool:
	return selected_character != null and selected_character.name == ai_id

func _on_schedule_manager_activity(ai_id: String, _activity: Dictionary) -> void:
	if _is_selected_ai(ai_id):
		_refresh_schedule_view()

func _on_task_list_signal(ai_id: String, _tasks: Array) -> void:
	if _is_selected_ai(ai_id):
		_update_task_detail()
	if _task_popup_is_tracking(ai_id):
		_update_task_list()

func _on_task_assigned_signal(ai_id: String, _task: Dictionary) -> void:
	if _is_selected_ai(ai_id):
		_update_task_detail()
	if _task_popup_is_tracking(ai_id):
		_update_task_list()

func _on_task_completed_signal(ai_id: String, _task: Dictionary, _result: Dictionary) -> void:
	if _is_selected_ai(ai_id):
		_update_task_detail()
	if _task_popup_is_tracking(ai_id):
		_update_task_list()

func _on_task_failed_signal(ai_id: String, _task: Dictionary, _reason: String) -> void:
	if _is_selected_ai(ai_id):
		_update_task_detail()
	if _task_popup_is_tracking(ai_id):
		_update_task_list()

func _on_task_cancelled_signal(ai_id: String, _task: Dictionary, _reason: String) -> void:
	if _is_selected_ai(ai_id):
		_update_task_detail()
	if _task_popup_is_tracking(ai_id):
		_update_task_list()

func _on_economy_balance_changed(ai_id: String, _new_balance: float, _delta: float) -> void:
	if _is_selected_ai(ai_id):
		_refresh_finance_view()

func _on_economy_transaction(ai_id: String, _transaction: Dictionary) -> void:
	if _is_selected_ai(ai_id):
		_refresh_finance_view()

func _on_economy_payroll_processed(summary: Array) -> void:
	for item in summary:
		var ai_id: String = item.get("ai_id", "")
		if ai_id == "":
			continue
		_last_payroll_summary[ai_id] = item
	if selected_character:
		var current_name := selected_character.name
		if _last_payroll_summary.has(current_name):
			_refresh_finance_view()

func _task_popup_is_tracking(ai_id: String) -> bool:
	var character_selector = task_popup.get_node("VBoxContainer/CharacterSelector")
	if character_selector.selected < 0 or character_selector.selected >= all_characters.size():
		return false
	return all_characters[character_selector.selected].name == ai_id

func _reset_schedule_view():
	schedule_activity_name_label.text = "未选择角色"
	schedule_activity_location_label.text = ""
	schedule_activity_time_label.text = ""
	_clear_agenda_entries()
	schedule_empty_label.show()

func _reset_finance_view():
	finance_balance_label.text = "余额：0"
	finance_payroll_label.text = ""
	_clear_transaction_entries()
	finance_empty_label.show()

func _refresh_finance_view():
	if not selected_character:
		_reset_finance_view()
		return

	var balance := float(selected_character.get_meta("money", 0.0))
	finance_balance_label.text = "\u4F59\u989D\uFF1A" + _format_currency(balance)

	var payroll_info := _last_payroll_summary.get(selected_character.name, null)
	if payroll_info:
		var base_salary := float(payroll_info.get("base_salary", 0.0))
		var bonus := float(payroll_info.get("bonus", payroll_info.get("bonus_pay", payroll_info.get("bonus", 0.0))))
		var overtime := float(payroll_info.get("overtime_pay", 0.0))
		finance_payroll_label.text = "上次发薪：基础%s + 奖金%s + 加班%s" % [
			_format_currency(base_salary),
			_format_currency(bonus),
			_format_currency(overtime)
		]
	else:
		finance_payroll_label.text = "上次发薪：暂无记录"

	_clear_transaction_entries()

	var transactions: Array = []
	if _economy_manager and _economy_manager.has_method("get_transactions"):
		transactions = _economy_manager.get_transactions(selected_character.name, 10)
	else:
		var character_data = selected_character.get_meta("character_data", {})
		transactions = character_data.get("transactions", [])

	if transactions.is_empty():
		finance_empty_label.show()
		return

	finance_empty_label.hide()
	for txn in transactions:
		if typeof(txn) != TYPE_DICTIONARY:
			continue

		var item_container := VBoxContainer.new()
		item_container.add_theme_constant_override("separation", 2)
		item_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var header := HBoxContainer.new()
		header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		header.add_theme_constant_override("separation", 8)

		var type_label := Label.new()
		type_label.text = _format_transaction_type(String(txn.get("type", "")))
		type_label.custom_minimum_size = Vector2(90, 0)
		header.add_child(type_label)

		var amount_label := Label.new()
		var amount := float(txn.get("amount", 0.0))
		var direction := String(txn.get("direction", "income"))
		var amount_text := _format_currency(amount)
		if direction == "expense":
			amount_label.text = "-" + amount_text
			amount_label.modulate = Color(0.9, 0.3, 0.3)
		else:
			amount_label.text = "+" + amount_text
			amount_label.modulate = Color(0.3, 0.75, 0.3)
		header.add_child(amount_label)

		var balance_label := Label.new()
		balance_label.text = "余额：" + _format_currency(float(txn.get("balance_after", balance)))
		balance_label.modulate = Color(0.6, 0.6, 0.6)
		header.add_child(balance_label)

		var time_label := Label.new()
		time_label.text = _format_timestamp(int(txn.get("timestamp", 0)))
		time_label.modulate = Color(0.6, 0.6, 0.6)
		header.add_child(time_label)

		item_container.add_child(header)

		var metadata := txn.get("metadata", {})
		var description_text := ""
		if typeof(metadata) == TYPE_DICTIONARY:
			if metadata.has("description"):
				description_text = String(metadata["description"])
			elif String(txn.get("type", "")) == "salary":
				description_text = "基础%s 奖金%s 加班%s" % [
					_format_currency(float(metadata.get("base_salary", 0.0))),
					_format_currency(float(metadata.get("bonus", metadata.get("bonus_pay", 0.0)))),
					_format_currency(float(metadata.get("overtime_pay", 0.0)))
				]

		if description_text != "":
			var desc_label := Label.new()
			desc_label.text = description_text
			desc_label.modulate = Color(0.55, 0.55, 0.55)
			desc_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			item_container.add_child(desc_label)

		finance_transaction_list.add_child(item_container)

func _clear_transaction_entries():
	for child in finance_transaction_list.get_children():
		if child != finance_empty_label:
			child.queue_free()

func _format_transaction_type(txn_type: String) -> String:
	match txn_type:
		"salary":
			return "工资"
		"bonus":
			return "奖金"
		"purchase":
			return "支出"
		"fine":
			return "罚款"
		"transfer_in":
			return "转入"
		"transfer_out":
			return "转出"
		"adjust":
			return "调整"
		_:
			return txn_type.capitalize()

func _format_currency(amount: float, decimals: int = 0, include_sign: bool = false) -> String:
	var precision := clamp(decimals, 0, 4)
	var value := abs(amount)
	var format_string := "%.*f" % [precision, value]
	var prefix := ""
	if include_sign:
		if amount > 0.0:
			prefix = "+"
		elif amount < 0.0:
			prefix = "-"
	else:
		if amount < 0.0:
			prefix = "-"
	return prefix + format_string + "元"

func _format_timestamp(timestamp: int) -> String:
	if timestamp <= 0:
		return "-"
	var dict := Time.get_datetime_dict_from_unix_time(timestamp)
	return "%02d-%02d %02d:%02d" % [dict.month, dict.day, dict.hour, dict.minute]

func _refresh_schedule_view():
	if not selected_character:
		_reset_schedule_view()
		return

	var character_data = selected_character.get_meta("character_data", {})
	var activity = character_data.get("current_activity", {})

	if activity.is_empty():
		schedule_activity_name_label.text = "暂无活动"
		schedule_activity_location_label.text = ""
		schedule_activity_time_label.text = ""
	else:
		var activity_name = String(activity.get("activity", "未知活动"))
		schedule_activity_name_label.text = activity_name

		var location_type = String(activity.get("location_type", ""))
		var location_id = String(activity.get("location_id", ""))
		var location_text = "地点：" + _format_location_label(location_type, location_id)
		schedule_activity_location_label.text = location_text

		var start_minute = int(activity.get("start_minute", -1))
		var end_minute = int(activity.get("end_minute", -1))
		if start_minute >= 0 and end_minute >= 0:
			var time_label = "时间：%s - %s" % [_format_minutes(start_minute), _format_minutes(end_minute)]
			var current_minute = _current_minutes_of_day()
			if current_minute >= start_minute and current_minute < end_minute:
				var remaining = end_minute - current_minute
				time_label += "（剩余%d分钟）" % remaining
			schedule_activity_time_label.text = time_label
		else:
			schedule_activity_time_label.text = ""

	var agenda: Array = []
	if _schedule_manager:
		agenda = _schedule_manager.get_agenda(selected_character.name)
	else:
		agenda = character_data.get("agenda", [])

	_populate_schedule_agenda(agenda)

func _clear_agenda_entries():
	for child in schedule_agenda_list.get_children():
		if child != schedule_empty_label:
			child.queue_free()

func _populate_schedule_agenda(entries: Array):
	_clear_agenda_entries()
	if entries.is_empty():
		schedule_empty_label.show()
		return

	schedule_empty_label.hide()

	for i in range(entries.size()):
		var entry = entries[i]
		if typeof(entry) != TYPE_DICTIONARY:
			continue

		var block = VBoxContainer.new()
		block.add_theme_constant_override("separation", 2)
		block.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var header = HBoxContainer.new()
		header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		header.add_theme_constant_override("separation", 8)

		var time_label = Label.new()
		time_label.custom_minimum_size = Vector2(120, 0)
		time_label.text = _format_minutes_range(entry)
		header.add_child(time_label)

		var name_label = Label.new()
		name_label.text = String(entry.get("activity", ""))
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_label.add_theme_font_size_override("font_size", 13)
		header.add_child(name_label)

		var location_label = Label.new()
		location_label.text = _format_location_label(String(entry.get("location_type", "")), String(entry.get("location_id", "")))
		location_label.modulate = Color(0.7, 0.7, 0.7)
		header.add_child(location_label)

		block.add_child(header)

		var metadata: Dictionary = entry.get("metadata", {})
		if metadata and metadata.size() > 0:
			var meta_label = Label.new()
			meta_label.modulate = Color(0.6, 0.6, 0.6)
			meta_label.text = _format_schedule_metadata(metadata)
			block.add_child(meta_label)

		schedule_agenda_list.add_child(block)

		if i < entries.size() - 1:
			var separator = HSeparator.new()
			separator.modulate = Color(0.4, 0.4, 0.4, 0.4)
			schedule_agenda_list.add_child(separator)

func _format_schedule_metadata(metadata: Dictionary) -> String:
	var parts: Array = []
	for key in metadata.keys():
		parts.append("%s: %s" % [str(key), str(metadata[key])])
	return ", ".join(parts)

func _format_minutes_range(entry: Dictionary) -> String:
	var start_minute = int(entry.get("start_minute", -1))
	var end_minute = int(entry.get("end_minute", -1))
	if start_minute >= 0 and end_minute >= 0:
		return "%s-%s" % [_format_minutes(start_minute), _format_minutes(end_minute)]
	return entry.get("start", "--:--")

func _format_minutes(value: int) -> String:
	var minutes = clamp(value, 0, 24 * 60)
	var hour = minutes / 60
	var minute = minutes % 60
	return "%02d:%02d" % [hour, minute]

func _current_minutes_of_day() -> int:
	if _time_system:
		return _time_system.get_current_hour() * 60 + _time_system.get_current_minute()
	var now = Time.get_datetime_dict_from_system()
	return now.hour * 60 + now.minute

func _format_location_label(location_type: String, location_id: String) -> String:
	if location_type == "":
		return location_id if location_id != "" else "未指定地点"
	var upper = location_type.to_upper()
	if LOCATION_LABELS.has(upper):
		return LOCATION_LABELS[upper]
	return location_type.capitalize()

func _compute_task_stats(tasks: Array) -> Dictionary:
	var stats = {
		"total": tasks.size(),
		"active": 0,
		"completed": 0,
		"failed": 0,
		"cancelled": 0
	}
	for task in tasks:
		match int(task.get("state", 0)):
			0:
				stats["active"] += 1
			1:
				stats["completed"] += 1
			2:
				stats["failed"] += 1
			3:
				stats["cancelled"] += 1
	return stats

func _format_task_name(task: Dictionary) -> String:
	if task.has("name") and String(task["name"]).strip_edges() != "":
		return String(task["name"])
	if task.has("description") and String(task["description"]).strip_edges() != "":
		return String(task["description"])
	return String(task.get("id", "未命名任务"))

func _format_task_deadline(task: Dictionary) -> String:
	if not task.has("deadline"):
		return "截止：未设置"
	var deadline_ts = int(task["deadline"])
	var deadline_dict = Time.get_datetime_dict_from_unix_time(deadline_ts)
	var deadline_text = "%02d-%02d %02d:%02d" % [
		deadline_dict.month,
		deadline_dict.day,
		deadline_dict.hour,
		deadline_dict.minute
	]
	var diff = deadline_ts - _current_timestamp()
	var diff_text = ""
	if diff >= 0:
		diff_text = "剩余" + _format_duration(diff)
	else:
		diff_text = "已超时" + _format_duration(-diff)
	return "截止：%s（%s）" % [deadline_text, diff_text]

func _format_duration(seconds: int) -> String:
	var abs_seconds = max(0, seconds)
	var hours = abs_seconds / 3600
	var minutes = (abs_seconds % 3600) / 60
	if hours > 0 and minutes > 0:
		return "%d小时%d分钟" % [hours, minutes]
	elif hours > 0:
		return "%d小时" % hours
	else:
		return "%d分钟" % max(1, minutes)

func _current_timestamp() -> int:
	if _time_system:
		return _time_system.get_current_timestamp()
	return Time.get_unix_time_from_system()

func _update_character_lists():
	# 获取所有角色
	var new_characters = get_tree().get_nodes_in_group("controllable_characters")
	
	# 检查是否有变化
	var has_changes = false
	if new_characters.size() != all_characters.size():
		has_changes = true
	else:
		for i in range(new_characters.size()):
			if not (i < all_characters.size() and new_characters[i] == all_characters[i]):
				has_changes = true
				break
	
	if not has_changes:
		return
		
	# 更新角色列表
	all_characters = new_characters
	
	# 清空角色列表
	character_list.clear()
	
	# 更新所有弹窗的角色选择器
	var popup_selectors = [
		implant_memory_popup.get_node("VBoxContainer/CharacterSelector"),
		disease_popup.get_node("VBoxContainer/CharacterSelector"),
		money_popup.get_node("VBoxContainer/CharacterSelector"),
		emotion_popup.get_node("VBoxContainer/CharacterSelectorA"),
		emotion_popup.get_node("VBoxContainer/CharacterSelectorB"),
		task_popup.get_node("VBoxContainer/CharacterSelector")
	]
	
	for selector in popup_selectors:
		selector.clear()
	
	# 添加角色到列表和选择器
	for character in all_characters:
		var name = character.name
		character_list.add_item(name)
		
		for selector in popup_selectors:
			selector.add_item(name)
	
	# 如果之前有选中的角色，尝试保持选中状态
	if selected_character:
		var index = all_characters.find(selected_character)
		if index >= 0:
			character_list.select(index)
		else:
			selected_character = null
			_update_character_detail() # 清空详情

func _on_character_selected(index):
	if index >= 0 and index < all_characters.size():
		selected_character = all_characters[index]
		_update_character_detail()

func _update_character_detail():
	if not selected_character:
		# 清空详情显示
		character_detail.get_node("NameLabel").text = "姓名："
		character_detail.get_node("HBoxContainer/VBoxContainer/MoneyLabel").text = "存款：0"
		character_detail.get_node("HBoxContainer/VBoxContainer/MoodLabel").text = "心情：普通"
		character_detail.get_node("HBoxContainer/VBoxContainer/HealthLabel").text = "健康：良好"
		character_detail.get_node("TabContainer/人设/PersonalityText").text = "选择一个角色查看人设..."
		_clear_children(character_detail.get_node("TabContainer/记忆/MemoryList"))
		_clear_children(character_detail.get_node("TabContainer/情感/RelationList"))
		
		# 隐藏Avatar动画节点
		if avatar_sprite:
			avatar_sprite.stop()
			avatar_sprite.visible = false
		
		# 清空AI设置界面
		if ai_settings_container and ai_settings_container.has_method("set_character"):
			ai_settings_container.set_character("")
		
		_reset_schedule_view()
		_reset_finance_view()
		
		return
	
	# 基本信息
	character_detail.get_node("NameLabel").text = "姓名：" + selected_character.name
	
	# 尝试获取角色属性，如果不存在则使用默认值
	var money = selected_character.get_meta("money", 0)
	var mood = selected_character.get_meta("mood", "普通")
	var health = selected_character.get_meta("health", "良好")
	
	character_detail.get_node("HBoxContainer/VBoxContainer/MoneyLabel").text = "存款：" + str(money)
	character_detail.get_node("HBoxContainer/VBoxContainer/MoodLabel").text = "心情：" + str(mood)
	character_detail.get_node("HBoxContainer/VBoxContainer/HealthLabel").text = "健康：" + str(health)
	
	# 人设
	var personality_data = CharacterPersonality.get_personality(selected_character.name)
	var personality_text = ""
	if personality_data.has("personality"):
		personality_text = "人设：" + personality_data["personality"] + "\n\n"
	if personality_data.has("position"):
		personality_text += "职位：" + personality_data["position"] + "\n\n"
	if personality_data.has("speaking_style"):
		personality_text += "说话风格：" + personality_data["speaking_style"] + "\n\n"
	if personality_data.has("work_duties"):
		personality_text += "工作职责：" + personality_data["work_duties"] + "\n\n"
	if personality_data.has("work_habits"):
		personality_text += "工作习惯：" + personality_data["work_habits"]
	
	if personality_text.is_empty():
		personality_text = "未设置人设"
	
	character_detail.get_node("TabContainer/人设/PersonalityText").text = personality_text
	
	# 记忆 - 使用MemoryManager获取记忆信息
	var memory_list = character_detail.get_node("TabContainer/记忆/MemoryList")
	_clear_children(memory_list)
	
	
	var memories = MemoryManager.get_character_memories(selected_character)
	for memory in memories:
		var memory_label = Label.new()
		# 处理不同格式的记忆数据
		var memory_text = ""
		if typeof(memory) == TYPE_DICTIONARY:
			# 使用MemoryManager的格式化函数处理Dictionary格式
			memory_text = MemoryManager._format_memory_for_display(memory)
		elif typeof(memory) == TYPE_STRING:
			# 直接使用String格式的记忆
			memory_text = memory
		else:
			# 其他类型转换为字符串
			memory_text = str(memory)
		
		memory_label.text = memory_text
		memory_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		memory_list.add_child(memory_label)
		memory_list.add_child(HSeparator.new())
	
	# 情感关系
	var relation_list = character_detail.get_node("TabContainer/情感/RelationList")
	_clear_children(relation_list)
	
	var relations = selected_character.get_meta("relations", {})
	for target_name in relations:
		var relation = relations[target_name]
		var relation_label = Label.new()
		var emotion_text = relation["type"] if relation.has("type") else "未知"
		var strength = relation["strength"] if relation.has("strength") else 0
		relation_label.text = "对 " + target_name + " 的情感：" + emotion_text + " (强度：" + str(strength) + ")"
		relation_list.add_child(relation_label)
	
	# 更新Avatar动画
	_update_avatar_animation()
	
	# 更新任务信息
	_update_task_detail()
	_refresh_finance_view()
	_refresh_schedule_view()
	
	# 更新AI设置界面
	if ai_settings_container and ai_settings_container.has_method("set_character"):
		ai_settings_container.set_character(selected_character.name)

# 更新Avatar动画
func _update_avatar_animation():
	if not avatar_sprite or not selected_character:
		return
	
	# 显示Avatar动画节点
	avatar_sprite.visible = true
	
	# 根据角色名称设置对应的动画
	# 这里假设动画名称格式为 "角色名_idle"（全小写）
	var animation_name = selected_character.name.to_lower() + "_idle"
	
	# 检查是否存在该动画
	if avatar_sprite.sprite_frames and avatar_sprite.sprite_frames.has_animation(animation_name):
		avatar_sprite.play(animation_name)
	else:
		# 如果没有找到特定角色的动画，尝试播放默认动画
		if avatar_sprite.sprite_frames and avatar_sprite.sprite_frames.has_animation("default"):
			avatar_sprite.play("default")
		else:
			# 如果连默认动画都没有，尝试播放第一个可用的动画
			var animations = avatar_sprite.sprite_frames.get_animation_names()
			if animations.size() > 0:
				avatar_sprite.play(animations[0])
			else:
				print("警告：没有找到可用的动画")

func _clear_children(node):
	for child in node.get_children():
		child.queue_free()

func _on_toggle_ui_pressed():
	_toggle_ui(!ui_visible)

func _toggle_ui(show):
	ui_visible = show
	left_panel.visible = show
	right_panel.visible = show # 确保右侧面板也能切换
	toggle_ui_button.visible = true # 总是保持可见
	toggle_ui_button.text = "隐藏 UI" if show else "显示 UI"

func _on_implant_memory_pressed():
	implant_memory_popup.popup_centered()

func _on_disease_pressed():
	disease_popup.popup_centered()

func _on_money_pressed():
	money_popup.popup_centered()

func _on_emotion_pressed():
	emotion_popup.popup_centered()
	
func _on_task_pressed():
	task_popup.popup_centered()
	_update_task_list()

func _on_implant_memory_confirm():
	var character_selector = implant_memory_popup.get_node("VBoxContainer/CharacterSelector")
	var memory_input = implant_memory_popup.get_node("VBoxContainer/MemoryInput")
	
	if character_selector.selected < 0 or all_characters.size() <= character_selector.selected:
		return
	
	var character = all_characters[character_selector.selected]
	var memory_text = memory_input.text
	
	if memory_text.strip_edges().is_empty():
		return
	
	# 使用MemoryManager添加记忆，设置为高重要性（玩家植入的记忆应该被优先考虑）
	MemoryManager.add_memory(character, memory_text, MemoryManager.MemoryType.PERSONAL, MemoryManager.MemoryImportance.HIGH)
	print("记忆已通过MemoryManager保存: ", memory_text)
	
	# 更新角色详情
	if selected_character == character:
		_update_character_detail()
	
	memory_input.text = ""
	implant_memory_popup.hide()

func _on_disease_confirm():
	var character_selector = disease_popup.get_node("VBoxContainer/CharacterSelector")
	var disease_selector = disease_popup.get_node("VBoxContainer/DiseaseSelector")
	var severity_slider = disease_popup.get_node("VBoxContainer/SeveritySlider")
	
	if character_selector.selected < 0 or all_characters.size() <= character_selector.selected:
		return
	
	var character = all_characters[character_selector.selected]
	var disease_type = disease_selector.get_item_text(disease_selector.selected)
	var severity = int(severity_slider.value)
	
	# 设置疾病
	var health_info = disease_type + " (严重程度：" + str(severity) + "/10)"
	character.set_meta("health", health_info)
	
	# 添加疾病相关记忆
	var character_data = character.get_meta("character_data", {})
	if not character_data.has("memories"):
		character_data["memories"] = []
	
	var current_time = Time.get_datetime_dict_from_system()
	var time_str = "%04d-%02d-%02d %02d:%02d" % [
		current_time.year, current_time.month, current_time.day,
		current_time.hour, current_time.minute
	]
	
	var severity_text = "轻微"
	if severity > 3 and severity <= 7:
		severity_text = "中等"
	elif severity > 7:
		severity_text = "严重"
		
	# 使用MemoryManager添加疾病记忆
	var memory_text = "感到身体不适，患上了%s程度的%s" % [severity_text, disease_type]
	MemoryManager.add_memory(character, memory_text, MemoryManager.MemoryType.PERSONAL, MemoryManager.MemoryImportance.HIGH)
	
	# 更新角色详情
	if selected_character == character:
		_update_character_detail()
	
	disease_popup.hide()

func _on_money_confirm():
	var character_selector = money_popup.get_node("VBoxContainer/CharacterSelector")
	var money_input = money_popup.get_node("VBoxContainer/MoneyInput")
	var reason_input = money_popup.get_node("VBoxContainer/ReasonInput")
	
	if character_selector.selected < 0 or all_characters.size() <= character_selector.selected:
		return
	
	var character = all_characters[character_selector.selected]
	var amount = int(money_input.value)
	var reason = reason_input.text
	
	# 调试信息：打印原因输入
	print("原因输入框内容: '", reason, "'")
	print("原因输入框内容长度: ", reason.length())
	print("去除空格后的原因: '", reason.strip_edges(), "'")
	
	if reason.strip_edges().is_empty():
		reason = "未知原因"
		print("原因为空，设置为: ", reason)
	else:
		print("使用用户输入的原因: ", reason)
	
	# 修改金钱
	if not character.has_meta("money"):
		character.set_meta("money", 0)
	
	var current_money = character.get_meta("money", 0)
	current_money += amount
	character.set_meta("money", current_money)
	
	# 添加金钱相关记忆
	var character_data = character.get_meta("character_data", {})
	if not character_data.has("memories"):
		character_data["memories"] = []
	
	var current_time = Time.get_datetime_dict_from_system()
	var time_str = "%04d-%02d-%02d %02d:%02d" % [
		current_time.year, current_time.month, current_time.day,
		current_time.hour, current_time.minute
	]
	
	var memory_text = ""
	if amount > 0:
		memory_text = "获得了 " + str(amount) + " 元，原因是：" + reason
	else:
		memory_text = "损失了 " + str(abs(amount)) + " 元，原因是：" + reason
	
	# 使用MemoryManager添加金钱记忆
	MemoryManager.add_memory(character, memory_text, MemoryManager.MemoryType.PERSONAL, MemoryManager.MemoryImportance.NORMAL)
	print("记忆已通过MemoryManager保存: ", memory_text)
	
	# 更新角色详情
	if selected_character == character:
		_update_character_detail()
	
	money_input.value = 0
	reason_input.text = ""
	money_popup.hide()

func _on_emotion_confirm():
	var selector_a = emotion_popup.get_node("VBoxContainer/CharacterSelectorA")
	var selector_b = emotion_popup.get_node("VBoxContainer/CharacterSelectorB")
	var emotion_type = emotion_popup.get_node("VBoxContainer/EmotionType")
	var emotion_strength = emotion_popup.get_node("VBoxContainer/EmotionStrength")
	
	if selector_a.selected < 0 or selector_b.selected < 0 or all_characters.size() <= selector_a.selected or all_characters.size() <= selector_b.selected:
		return
	
	var character_a = all_characters[selector_a.selected]
	var character_b = all_characters[selector_b.selected]
	
	if character_a == character_b:
		return
	
	var type = emotion_type.get_item_text(emotion_type.selected)
	var strength = int(emotion_strength.value)
	
	# 设置情感关系
	if not character_a.has_meta("relations"):
		character_a.set_meta("relations", {})
	
	var relations = character_a.get_meta("relations", {})
	relations[character_b.name] = {
		"type": type,
		"strength": strength
	}
	character_a.set_meta("relations", relations)
	
	# 添加情感相关记忆
	if not character_a.has_meta("memories"):
		character_a.set_meta("memories", [])
	
	var current_time = Time.get_datetime_dict_from_system()
	var time_str = "%04d-%02d-%02d %02d:%02d" % [
		current_time.year, current_time.month, current_time.day,
		current_time.hour, current_time.minute
	]
	
	var strength_text = ""
	if strength < -5:
		strength_text = "强烈地"
	elif strength < 0:
		strength_text = "轻微地"
	elif strength == 0:
		strength_text = "中立地"
	elif strength <= 5:
		strength_text = "轻微地"
	else:
		strength_text = "强烈地"
	
	var emotion_text = ""
	if strength < 0:
		emotion_text = "对%s产生了%s%s的负面情感" % [character_b.name, strength_text, type]
	elif strength == 0:
		emotion_text = "对%s的%s情感变为中立" % [character_b.name, type]
	else:
		emotion_text = "对%s产生了%s%s的正面情感" % [character_b.name, strength_text, type]
	
	# 使用MemoryManager添加情感记忆
	MemoryManager.add_memory(character_a, emotion_text, MemoryManager.MemoryType.EMOTION, MemoryManager.MemoryImportance.NORMAL)
	
	# 更新角色详情
	if selected_character == character_a:
		_update_character_detail()
	
	emotion_popup.hide()

func _on_disease_severity_changed(value):
	var severity_text = ""
	if value <= 3:
		severity_text = "轻微"
	elif value <= 7:
		severity_text = "中等"
	else:
		severity_text = "严重"
	
	disease_popup.get_node("VBoxContainer/SeverityLabel").text = severity_text + " (" + str(int(value)) + "/10)"

func _on_emotion_strength_changed(value):
	var strength_text = ""
	if value < -5:
		strength_text = "强烈厌恶"
	elif value < 0:
		strength_text = "轻度厌恶"
	elif value == 0:
		strength_text = "中立"
	elif value <= 5:
		strength_text = "轻度喜欢"
	else:
		strength_text = "强烈喜欢"
	
	emotion_popup.get_node("VBoxContainer/StrengthLabel").text = strength_text + " (" + str(int(value)) + "/10)"

# 初始化任务系统
func _init_task_system():
	if _task_system:
		return

	# 为每个角色初始化任务列表
	for character in all_characters:
		if not character.has_meta("tasks"):
			character.set_meta("tasks", [])
		
		# 为每个角色设置每日任务刷新的时间戳
		if not character.has_meta("last_task_refresh"):
			character.set_meta("last_task_refresh", Time.get_unix_time_from_system())

# 更新任务列表UI
func _update_task_list():
	var character_selector = task_popup.get_node("VBoxContainer/CharacterSelector")
	if character_selector.selected < 0 or character_selector.selected >= all_characters.size():
		return
	
	var selected_character = all_characters[character_selector.selected]
	var character_data = selected_character.get_meta("character_data", {})
	var tasks = character_data.get("tasks", [])
	
	var task_container = task_popup.get_node("VBoxContainer/TaskList/TaskContainer")
	for child in task_container.get_children():
		child.queue_free()
	
	tasks.sort_custom(func(a, b):
		var state_a = int(a.get("state", 0))
		var state_b = int(b.get("state", 0))
		if state_a != state_b:
			return state_a < state_b
		return int(a.get("priority", 0)) > int(b.get("priority", 0))
	)
	
	for i in range(tasks.size()):
		var task = tasks[i]
		var state = int(task.get("state", 0))
		
		var task_item = VBoxContainer.new()
		task_item.add_theme_constant_override("separation", 2)
		task_item.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		
		var header = HBoxContainer.new()
		header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		header.add_theme_constant_override("separation", 6)
		
		var task_label = Label.new()
		task_label.text = "%d. %s" % [i + 1, _format_task_name(task)]
		task_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		task_label.modulate = TASK_STATE_COLORS.get(state, Color(0.95, 0.95, 0.95))
		header.add_child(task_label)
		
		var complete_button = Button.new()
		complete_button.text = "完成"
		complete_button.disabled = state != 0
		complete_button.pressed.connect(_on_complete_task.bind(i))
		header.add_child(complete_button)
		
		var cancel_button = Button.new()
		cancel_button.text = "取消"
		cancel_button.disabled = state == 3
		cancel_button.pressed.connect(_on_delete_task.bind(i))
		header.add_child(cancel_button)
		
		task_item.add_child(header)
		
		var info_label = Label.new()
		info_label.text = "状态：%s | 优先级：%d" % [
			TASK_STATE_LABELS.get(state, "未知状态"),
			int(task.get("priority", 0))
		]
		info_label.modulate = Color(0.7, 0.7, 0.7)
		task_item.add_child(info_label)
		
		var deadline_preview = Label.new()
		deadline_preview.text = _format_task_deadline(task)
		deadline_preview.modulate = Color(0.6, 0.6, 0.6)
		task_item.add_child(deadline_preview)
		
		task_container.add_child(task_item)
	
	if not _task_system:
		_check_daily_task_refresh(selected_character)
# 获取任务列表
	var character_data = selected_character.get_meta("character_data", {})
	var tasks = character_data.get("tasks", [])
	
	# 清空当前任务容器
	var task_container = task_popup.get_node("VBoxContainer/TaskList/TaskContainer")
	for child in task_container.get_children():
		child.queue_free()
		
	# 按渴望程度排序任务（从高到低）
	tasks.sort_custom(func(a, b): return a["priority"] > b["priority"])
	
	# 添加任务到UI
	for i in range(tasks.size()):
		var task = tasks[i]
		
		# 创建任务项容器
		var task_item = HBoxContainer.new()
		task_item.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		
		# 创建任务描述标签
		var task_label = Label.new()
		task_label.text = "%d. %s (渴望程度: %d/10)" % [i + 1, task["description"], task["priority"]]
		task_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		task_item.add_child(task_label)
		
		# 创建完成按钮
		var complete_button = Button.new()
		complete_button.text = "完成"
		complete_button.pressed.connect(_on_complete_task.bind(i))
		task_item.add_child(complete_button)
		
		# 创建删除按钮
		var delete_button = Button.new()
		delete_button.text = "删除"
		delete_button.pressed.connect(_on_delete_task.bind(i))
		task_item.add_child(delete_button)
		
		# 添加任务项到容器
		task_container.add_child(task_item)
		
	# 检查是否需要刷新每日任务
	_check_daily_task_refresh(selected_character)

# 添加新任务
func _on_add_task():
	var character_selector = task_popup.get_node("VBoxContainer/CharacterSelector")
	if character_selector.selected < 0 or character_selector.selected >= all_characters.size():
		return

	var target_character: Node = all_characters[character_selector.selected]
	var task_input = task_popup.get_node("VBoxContainer/AddTaskContainer/TaskInput")
	var priority_slider = task_popup.get_node("VBoxContainer/AddTaskContainer/PriorityContainer/PrioritySlider")
	var task_description = task_input.text.strip_edges()
	var priority = int(priority_slider.value)

	if task_description.is_empty():
		return

	if _task_system:
		var task_id = "manual_%s_%d" % [target_character.name, Time.get_unix_time_from_system()]
		var manual_task = {
			"id": task_id,
			"name": task_description,
			"description": task_description,
			"default_priority": priority,
			"priority": priority,
			"estimated_minutes": 60,
			"deadline_offset_minutes": max(120, (11 - priority) * 45),
			"domain": "daily",
			"tags": ["手动创建"]
		}
		_task_system.assign_task(target_character.name, manual_task)
	else:
		var tasks = target_character.get_meta("tasks", [])
		var new_task = {
			"id": "legacy_%s_%d" % [target_character.name, Time.get_unix_time_from_system()],
			"name": task_description,
			"description": task_description,
			"priority": priority,
			"created_at": Time.get_unix_time_from_system(),
			"completed": false
		}
		tasks.append(new_task)
		target_character.set_meta("tasks", tasks)
		_update_task_list()
		if target_character == selected_character:
			_update_character_detail()

	task_input.text = ""
	priority_slider.value = 5

	var memory_text = "你给自己安排了一个新任务：%s（优先级：%d/10）" % [task_description, priority]
	MemoryManager.add_memory(target_character, memory_text, MemoryManager.MemoryType.TASK, MemoryManager.MemoryImportance.NORMAL)

# 完成任务
func _on_complete_task(task_index):
	var character_selector = task_popup.get_node("VBoxContainer/CharacterSelector")
	if character_selector.selected < 0 or character_selector.selected >= all_characters.size():
		return

	var target_character: Node = all_characters[character_selector.selected]
	var character_data = target_character.get_meta("character_data", {})
	var tasks = character_data.get("tasks", [])

	if task_index < 0 or task_index >= tasks.size():
		return

	var task: Dictionary = tasks[task_index]
	var task_id = String(task.get("id", ""))

	if _task_system and task_id != "":
		_task_system.complete_task(target_character.name, task_id, {})
	else:
		task["completed"] = true
		task["completed_at"] = Time.get_unix_time_from_system()
		tasks.remove_at(task_index)
		character_data["tasks"] = tasks
		target_character.set_meta("character_data", character_data)
		_update_task_list()
		if target_character == selected_character:
			_update_character_detail()

	var memory_text = "你完成了任务：%s" % [_format_task_name(task)]
	MemoryManager.add_memory(target_character, memory_text, MemoryManager.MemoryType.TASK, MemoryManager.MemoryImportance.NORMAL)

# 删除任务
func _on_delete_task(task_index):
	var character_selector = task_popup.get_node("VBoxContainer/CharacterSelector")
	if character_selector.selected < 0 or character_selector.selected >= all_characters.size():
		return

	var target_character: Node = all_characters[character_selector.selected]
	var character_data = target_character.get_meta("character_data", {})
	var tasks = character_data.get("tasks", [])

	if task_index < 0 or task_index >= tasks.size():
		return

	var task: Dictionary = tasks[task_index]
	var task_id = String(task.get("id", ""))

	if _task_system and task_id != "":
		_task_system.cancel_task(target_character.name, task_id, "cancelled_by_player")
	else:
		tasks.remove_at(task_index)
		character_data["tasks"] = tasks
		target_character.set_meta("character_data", character_data)
		_update_task_list()
		if target_character == selected_character:
			_update_character_detail()

# 刷新任务列表
func _on_refresh_tasks():
	var character_selector = task_popup.get_node("VBoxContainer/CharacterSelector")
	if character_selector.selected < 0 or character_selector.selected >= all_characters.size():
		return

	var target_character: Node = all_characters[character_selector.selected]

	if _task_system:
		_task_system.refresh_daily_tasks(target_character.name)
	else:
		_refresh_daily_tasks(target_character)
		_update_task_list()

# 判断是否需要刷新每日任务
func _check_daily_task_refresh(character_node):
	if _task_system or not character_node:
		return

	var character_data = character_node.get_meta("character_data", {})
	var last_refresh = character_data.get("last_task_refresh", 0)
	var current_time = Time.get_unix_time_from_system()
	var time_diff = current_time - last_refresh
	if time_diff >= 86400:
		_refresh_daily_tasks(character_node)

# 刷新每日任务
func _refresh_daily_tasks(character_node):
	if not character_node:
		return

	if _task_system:
		_task_system.refresh_daily_tasks(character_node.name)
		return

	var character_data = character_node.get_meta("character_data", {})
	var tasks = character_data.get("tasks", [])
	var incomplete_tasks = []
	for task in tasks:
		if not task.get("completed", false):
			incomplete_tasks.append(task)

	incomplete_tasks.sort_custom(func(a, b): return a["priority"] > b["priority"])

	while incomplete_tasks.size() < 10:
		var new_task = _generate_random_task(character_node)
		incomplete_tasks.append(new_task)

	character_data["tasks"] = incomplete_tasks
	character_data["last_task_refresh"] = Time.get_unix_time_from_system()
	character_node.set_meta("character_data", character_data)
func _generate_random_task(character_node):
	if not character_node:
		return null
		
	# 通用任务池
	var tasks_pool = [
		"检查邮件",
		"整理工作区",
		"与同事交流",
		"参加会议",
		"休息放松一下",
		"准备明天的工作",
		"回复重要邮件",
		"整理文件",
		"学习新技能",
		"思考工作改进方案",
		"与上级沟通工作进展",
		"帮助同事解决问题",
		"制定工作计划",
		"总结今日工作",
		"准备工作报告"
	]
	
	# 随机选择一个任务
	var random_task = tasks_pool[randi() % tasks_pool.size()]
	
	# 随机生成优先级（1-10）
	var random_priority = randi() % 10 + 1
	
	# 创建任务对象
	return {
		"description": random_task,
		"priority": random_priority,
		"created_at": Time.get_unix_time_from_system(),
		"completed": false
	}

# 更新任务详情显示
func _update_task_detail():
	if not selected_character:
		return

	_clear_children(task_detail_list)
	var character_data = selected_character.get_meta("character_data", {})
	var tasks: Array = character_data.get("tasks", [])

	if tasks.is_empty():
		var no_task_label = Label.new()
		no_task_label.text = "暂无任务"
		task_detail_list.add_child(no_task_label)
		return

	# 按状态（进行中优先）和优先级排序
	tasks.sort_custom(func(a, b):
		var state_a = int(a.get("state", 0))
		var state_b = int(b.get("state", 0))
		if state_a != state_b:
			return state_a < state_b
		var priority_a = int(a.get("priority", 0))
		var priority_b = int(b.get("priority", 0))
		return priority_a > priority_b
	)

	var stats = _compute_task_stats(tasks)
	var stats_label = Label.new()
	stats_label.text = "总数：%d | 进行中：%d | 已完成：%d | 失败：%d | 取消：%d" % [
		stats["total"], stats["active"], stats["completed"], stats["failed"], stats["cancelled"]
	]
	stats_label.add_theme_font_size_override("font_size", 14)
	task_detail_list.add_child(stats_label)
	task_detail_list.add_child(HSeparator.new())

	for i in range(tasks.size()):
		var task = tasks[i]
		var state := int(task.get("state", 0))
		var task_container = VBoxContainer.new()
		task_container.add_theme_constant_override("separation", 3)
		task_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var title_label = Label.new()
		title_label.text = "%d. %s" % [i + 1, _format_task_name(task)]
		title_label.add_theme_font_size_override("font_size", 13)
		title_label.modulate = TASK_STATE_COLORS.get(state, Color(0.95, 0.95, 0.95))
		task_container.add_child(title_label)

		var details_label = Label.new()
		var domain_text = String(task.get("domain", "未知类型"))
		var priority_value = int(task.get("priority", 0))
		var estimated_minutes = int(task.get("estimated_minutes", 0))
		var detail_text = "状态：%s | 优先级：%d | 分类：%s" % [
			TASK_STATE_LABELS.get(state, "未知状态"),
			priority_value,
			domain_text
		]
		if estimated_minutes > 0:
			detail_text += " | 预计耗时：%d分钟" % estimated_minutes
		details_label.text = detail_text
		details_label.modulate = Color(0.7, 0.7, 0.7)
		task_container.add_child(details_label)

		var deadline_label = Label.new()
		deadline_label.text = _format_task_deadline(task)
		task_container.add_child(deadline_label)

		var description = String(task.get("description", ""))
		var name = String(task.get("name", ""))
		if description != "" and description != name:
			var desc_label = Label.new()
			desc_label.text = description
			desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			task_container.add_child(desc_label)

		var tags: Array = task.get("tags", [])
		if tags.size() > 0:
			var tags_label = Label.new()
			tags_label.text = "标签：" + ", ".join(tags)
			tags_label.modulate = Color(0.6, 0.6, 0.6)
			task_container.add_child(tags_label)

		task_detail_list.add_child(task_container)

		if i < tasks.size() - 1:
			task_detail_list.add_child(HSeparator.new())

# 更新优先级滑块的值显示
func _on_priority_changed(value):
	var priority_value_label = task_popup.get_node("VBoxContainer/AddTaskContainer/PriorityContainer/PriorityValueLabel")
	priority_value_label.text = "%d/10" % int(value)

func _input(event):
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_F1:
			# 检查是否有任何设置UI可见
			var settings_ui_visible = false
			var settings = get_node_or_null("/root/GlobalSettings")
			if settings != null and settings.has_method("is_settings_visible"):
				settings_ui_visible = settings.is_settings_visible()

			if not settings_ui_visible:
				_toggle_ui(!ui_visible)

		# Ctrl+P 打开项目创建界面
		if event.keycode == KEY_P and event.ctrl_pressed:
			_on_create_project_pressed()

# 故事背景按钮点击
func _on_background_pressed():
	background_popup.popup_centered()
	_init_background_popup()

# 初始化故事背景弹窗
func _init_background_popup():
	# 初始化地图选择器
	var map_selector = background_popup.get_node("VBoxContainer/MapSelectionContainer/MapSelector")
	map_selector.clear()
	var available_maps = BackgroundStoryManager.get_available_maps()
	for map_name in available_maps:
		map_selector.add_item(map_name)
	
	# 设置当前选中的地图
	var current_map = BackgroundStoryManager.get_current_map_name()
	for i in range(map_selector.get_item_count()):
		if map_selector.get_item_text(i) == current_map:
			map_selector.selected = i
			break
	
	# 连接地图选择器信号
	if not map_selector.item_selected.is_connected(_on_map_selected):
		map_selector.item_selected.connect(_on_map_selected)
	
	# 连接弹窗按钮信号
	var add_rule_button = background_popup.get_node("VBoxContainer/AddRuleContainer/AddRuleButton")
	var clear_rules_button = background_popup.get_node("VBoxContainer/ButtonContainer/ClearRulesButton")
	var refresh_button = background_popup.get_node("VBoxContainer/ButtonContainer/RefreshButton")
	var close_button = background_popup.get_node("VBoxContainer/ButtonContainer/CloseButton")
	var add_rule_input = background_popup.get_node("VBoxContainer/AddRuleContainer/AddRuleInput")
	
	if not add_rule_button.pressed.is_connected(_on_add_rule_pressed):
		add_rule_button.pressed.connect(_on_add_rule_pressed)
	if not clear_rules_button.pressed.is_connected(_on_clear_rules_pressed):
		clear_rules_button.pressed.connect(_on_clear_rules_pressed)
	if not refresh_button.pressed.is_connected(_on_refresh_background_pressed):
		refresh_button.pressed.connect(_on_refresh_background_pressed)
	if not close_button.pressed.is_connected(func(): background_popup.hide()):
		close_button.pressed.connect(func(): background_popup.hide())
	if not add_rule_input.text_submitted.is_connected(_on_rule_input_submitted):
		add_rule_input.text_submitted.connect(_on_rule_input_submitted)
	
	# 刷新显示
	_refresh_background_display()

# 地图选择改变
func _on_map_selected(index: int):
	var map_selector = background_popup.get_node("VBoxContainer/MapSelectionContainer/MapSelector")
	var selected_map = map_selector.get_item_text(index)
	BackgroundStoryManager.set_background(selected_map)
	_refresh_background_display()

# 刷新故事背景显示
func _refresh_background_display():
	# 更新地图信息
	var map_info_label = background_popup.get_node("VBoxContainer/BackgroundInfoContainer/MapInfoLabel")
	var company_info_label = background_popup.get_node("VBoxContainer/BackgroundInfoContainer/CompanyInfoLabel")
	
	map_info_label.text = "当前地图：" + BackgroundStoryManager.get_current_map_name()
	company_info_label.text = "机构名称：" + BackgroundStoryManager.get_current_company_name()
	
	# 更新预设规则
	_update_preset_rules_display()
	
	# 更新自定义规则
	_update_custom_rules_display()

# 更新预设规则显示
func _update_preset_rules_display():
	var preset_rules_list = background_popup.get_node("VBoxContainer/PresetRulesContainer/PresetRulesScroll/PresetRulesList")
	
	# 清空现有内容
	for child in preset_rules_list.get_children():
		child.queue_free()
	
	# 添加预设规则
	var preset_rules = BackgroundStoryManager.get_preset_rules()
	for i in range(preset_rules.size()):
		var rule = preset_rules[i]
		var rule_label = Label.new()
		rule_label.text = "%d. %s" % [i + 1, rule]
		rule_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		rule_label.add_theme_color_override("font_color", Color.CYAN)
		preset_rules_list.add_child(rule_label)

# 更新自定义规则显示
func _update_custom_rules_display():
	var custom_rules_list = background_popup.get_node("VBoxContainer/CustomRulesContainer/CustomRulesScroll/CustomRulesList")
	
	# 清空现有内容
	for child in custom_rules_list.get_children():
		child.queue_free()
	
	# 添加自定义规则
	var custom_rules = BackgroundStoryManager.get_custom_rules()
	for i in range(custom_rules.size()):
		var rule = custom_rules[i]
		
		# 创建规则容器
		var rule_container = HBoxContainer.new()
		
		# 规则文本
		var rule_label = Label.new()
		rule_label.text = "%d. %s" % [i + 1, rule]
		rule_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		rule_label.add_theme_color_override("font_color", Color.YELLOW)
		rule_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		
		# 删除按钮
		var delete_button = Button.new()
		delete_button.text = "删除"
		delete_button.size_flags_horizontal = Control.SIZE_SHRINK_END
		delete_button.pressed.connect(func(): _on_delete_rule_pressed(i))
		
		rule_container.add_child(rule_label)
		rule_container.add_child(delete_button)
		custom_rules_list.add_child(rule_container)

# 添加规则按钮点击
func _on_add_rule_pressed():
	var add_rule_input = background_popup.get_node("VBoxContainer/AddRuleContainer/AddRuleInput")
	var rule_text = add_rule_input.text.strip_edges()
	if rule_text.is_empty():
		return
	
	if BackgroundStoryManager.add_custom_rule(rule_text):
		add_rule_input.text = ""
		_update_custom_rules_display()

# 输入框回车提交
func _on_rule_input_submitted(text: String):
	_on_add_rule_pressed()

# 删除规则按钮点击
func _on_delete_rule_pressed(index: int):
	if BackgroundStoryManager.remove_custom_rule(index):
		_update_custom_rules_display()

# 清空所有自定义规则
func _on_clear_rules_pressed():
	# 显示确认对话框
	var dialog = AcceptDialog.new()
	dialog.dialog_text = "确定要清空所有自定义规则吗？此操作不可撤销。"
	dialog.title = "确认清空"
	
	# 添加取消按钮
	dialog.add_cancel_button("取消")
	
	get_tree().current_scene.add_child(dialog)
	dialog.popup_centered()
	
	# 连接确认信号
	dialog.confirmed.connect(func():
		BackgroundStoryManager.clear_custom_rules()
		_update_custom_rules_display()
		dialog.queue_free()
	)
	
	# 连接取消信号
	dialog.canceled.connect(func():
		dialog.queue_free()
	)

# 刷新按钮点击
func _on_refresh_background_pressed():
	_refresh_background_display()

# 清空角色选择（供CharacterManager调用）
func clear_character_selection():
	selected_character = null
	# 清空角色列表的选择
	if character_list:
		character_list.deselect_all()
	# 更新角色详情显示
	_update_character_detail()

# --------------------------------------
# 时间系统工具
# --------------------------------------

func _setup_time_controls():
	_time_system = get_node_or_null("/root/TimeSystem")
	if not _time_system or not right_panel_container:
		return
	
	if _time_system.has_signal("time_updated"):
		_time_system.time_updated.connect(_on_time_updated)
	if _time_system.has_signal("hour_changed"):
		_time_system.hour_changed.connect(func(_hour): _refresh_time_label())
	if _time_system.has_signal("season_changed"):
		_time_system.season_changed.connect(func(_season_name, _season_index, _year): _refresh_time_label())
	if _time_system.has_signal("day_changed"):
		_time_system.day_changed.connect(func(_day, _season): _refresh_time_label())
	
	_time_label = Label.new()
	_time_label.name = "SimulationTimeLabel"
	_time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_time_label.add_theme_font_size_override("font_size", 16)
	_time_label.modulate = Color(0.9, 0.95, 1.0)
	right_panel_container.add_child(_time_label)
	right_panel_container.move_child(_time_label, 0)
	
	var controls := HBoxContainer.new()
	controls.name = "SimulationTimeControls"
	controls.add_theme_constant_override("separation", 6)
	controls.alignment = BoxContainer.ALIGNMENT_CENTER
	right_panel_container.add_child(controls)
	right_panel_container.move_child(controls, 1)
	
	var button_defs = [
		{"label": "暂停", "scale": 0.0, "tooltip": "暂停时间流逝"},
		{"label": "1x", "scale": 1.0, "tooltip": "恢复正常速度"},
		{"label": "2x", "scale": 2.0, "tooltip": "时间加速到2倍"},
		{"label": "4x", "scale": 4.0, "tooltip": "时间加速到4倍"}
	]
	
	for def in button_defs:
		var btn := Button.new()
		btn.text = def["label"]
		btn.toggle_mode = true
		btn.tooltip_text = def["tooltip"]
		btn.focus_mode = Control.FOCUS_NONE
		btn.pressed.connect(_on_time_scale_button_pressed.bind(btn, def["scale"]))
		controls.add_child(btn)
		_time_control_buttons[def["scale"]] = btn
	
	_refresh_time_label()
	_update_time_control_state()

func _on_time_updated(time_snapshot: Dictionary):
	_refresh_time_label(time_snapshot)

func _refresh_time_label(snapshot: Dictionary = {}):
	if not _time_label or not _time_system:
		return
	
	var time_dict := snapshot if snapshot.has("timestamp") else _time_system.get_current_time_dict()
	var date_text := str(time_dict.get("date_string", "")).strip_edges()
	var time_text := str(time_dict.get("time_string", "")).strip_edges()
	var components: Array = []
	if date_text != "":
		components.append(date_text)
	if time_text != "":
		components.append(time_text)
	
	var scale := _time_system.time_speed_multiplier
	if _time_system.is_paused:
		scale = 0.0
	var label_text := " ".join(PackedStringArray(components))
	if label_text.is_empty():
		label_text = "Time %.0f" % time_dict.get("timestamp", 0)
	label_text += "  x%.1f" % scale
	_time_label.text = label_text
	_update_time_control_state()

func _on_time_scale_button_pressed(_button: Button, scale: float):
	if not _time_system:
		return
	
	if scale <= 0.0:
		_time_system.pause()
	else:
		if _time_system.is_paused:
			_time_system.resume()
		_time_system.set_time_scale(scale)
	_refresh_time_label()

func _update_time_control_state():
	if not _time_system:
		return
	var active_scale := _time_system.time_speed_multiplier
	if _time_system.is_paused:
		active_scale = 0.0
	for scale in _time_control_buttons.keys():
		var btn: Button = _time_control_buttons[scale]
		if not is_instance_valid(btn):
			continue
		var should_press := is_equal_approx(scale, active_scale)
		if scale == 0.0 and _time_system.is_paused:
			should_press = true
		btn.set_pressed_no_signal(should_press)

func _on_relationship_changed(ai_id: String, target_id: String, rel: Dictionary):
	if not selected_character or selected_character.name != ai_id:
		return
	relation_manager_cache[target_id] = rel
	relation_tags_cache[target_id] = _relationship_manager.get_tags(ai_id, target_id)
	relation_dirty = true


func _on_tags_changed(ai_id: String, target_id: String, tags: Array):
	if not selected_character or selected_character.name != ai_id:
		return
	relation_tags_cache[target_id] = tags
	relation_dirty = true


func _on_relationship_removed(ai_id: String, target_id: String):
	if not selected_character or selected_character.name != ai_id:
		return
	relation_manager_cache.erase(target_id)
	relation_tags_cache.erase(target_id)
	relation_dirty = true


func _refresh_relationship_view():
	if not selected_character:
		_relation_list_clear()
		return
	relation_manager_cache = _relationship_manager.get_relationships(selected_character.name)
	relation_tags_cache = {}
	for target in relation_manager_cache.keys():
		relation_tags_cache[target] = _relationship_manager.get_tags(selected_character.name, target)
	_relation_list_render()


# ========================================
# 项目系统UI管理
# ========================================

# 创建项目按钮点击处理
func _on_create_project_pressed() -> void:
	if not _project_system:
		print("[GodUI] ProjectSystem未找到")
		return
	
	# 检查是否已有活跃项目
	var active_project = _project_system.get_active_project()
	if active_project:
		print("[GodUI] 已有活跃项目: %s，无法创建新项目" % active_project.title)
		return
	
	# 关闭现有的创建UI
	if _project_creation_ui:
		_project_creation_ui.queue_free()
	
	# 创建新的UI实例
	_project_creation_ui = PROJECT_CREATION_UI_SCENE.instantiate()
	get_tree().root.add_child(_project_creation_ui)
	
	print("[GodUI] 打开项目创建界面")

# 显示项目监控界面
func _show_project_monitor_ui() -> void:
	if _project_monitor_ui:
		return  # 已经显示
	
	_project_monitor_ui = PROJECT_MONITOR_UI_SCENE.instantiate()
	get_tree().root.add_child(_project_monitor_ui)
	
	print("[GodUI] 显示项目监控界面")

# 隐藏项目监控界面
func _hide_project_monitor_ui() -> void:
	if not _project_monitor_ui:
		return
	
	_project_monitor_ui.queue_free()
	_project_monitor_ui = null
	
	print("[GodUI] 隐藏项目监控界面")

# 项目启动回调
func _on_project_started(project) -> void:
	print("[GodUI] 项目已启动: %s" % project.title)
	
	# 关闭创建UI
	if _project_creation_ui:
		_project_creation_ui.queue_free()
		_project_creation_ui = null
	
	# 显示监控UI
	_show_project_monitor_ui()

# 项目结束回调
func _on_project_ended(project, reason: String = "") -> void:
	var end_reason = "完成" if reason.is_empty() else reason
	print("[GodUI] 项目已结束: %s (%s)" % [project.title, end_reason])
	
	# 隐藏监控UI
	_hide_project_monitor_ui()
