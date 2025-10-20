extends Panel

# ========================================
# ConflictLogPanel - 冲突日志面板
# ========================================
#
# 功能:
# - 显示所有活跃和历史冲突
# - 按状态/严重程度/角色过滤
# - 点击查看冲突详情
# - 实时更新
#
# ========================================

# 系统引用
var _conflict_system = null
var _time_system = null

# UI引用
@onready var conflict_list = $VBoxContainer/ConflictList
@onready var filter_container = $VBoxContainer/FilterContainer
@onready var status_filter = $VBoxContainer/FilterContainer/StatusFilter
@onready var severity_filter = $VBoxContainer/FilterContainer/SeverityFilter
@onready var empty_label = $VBoxContainer/EmptyLabel

# 过滤器状态
var _current_status_filter = "all"  # all, active, resolved
var _current_severity_filter = "all"  # all, minor, moderate, major, critical

# 对象池
var _item_pool = null  # ObjectPool实例
var _active_items: Array = []  # 当前显示的列表项

# 冲突颜色编码
const SEVERITY_COLORS = {
	1: Color(0.9, 0.9, 0.5),   # MINOR - 黄色
	2: Color(0.9, 0.9, 0.5),
	3: Color(0.9, 0.7, 0.3),   # MODERATE - 橙色
	4: Color(0.9, 0.7, 0.3),
	5: Color(0.9, 0.7, 0.3),
	6: Color(0.9, 0.4, 0.2),   # MAJOR - 深橙色
	7: Color(0.9, 0.4, 0.2),
	8: Color(0.9, 0.4, 0.2),
	9: Color(0.95, 0.2, 0.2)   # CRITICAL - 红色
}

const STATUS_LABELS = {
	"TRIGGERED": "已触发",
	"ESCALATING": "升级中",
	"PEAK": "高峰期",
	"COOLING_DOWN": "冷却期",
	"MEDIATED": "调解中",
	"RESOLVED": "已解决",
	"UNRESOLVED": "未解决"
}

const CONFLICT_TYPE_LABELS = {
	"INTEREST": "利益冲突",
	"VALUES": "价值观冲突",
	"PERSONALITY": "性格冲突",
	"MISUNDERSTANDING": "误会",
	"TASK_DISPUTE": "任务纠纷",
	"RESOURCE": "资源冲突",
	"TERRITORIAL": "地盘冲突",
	"ROMANTIC": "情感冲突"
}

# 信号
signal conflict_selected(conflict_id: String)

func _ready():
	"""初始化面板"""
	# 获取系统引用
	_conflict_system = get_node_or_null("/root/ConflictSystem")
	_time_system = get_node_or_null("/root/TimeSystem")

	# 初始化对象池
	_init_object_pool()

	# 连接冲突系统信号
	if _conflict_system:
		if _conflict_system.has_signal("conflict_triggered"):
			_conflict_system.conflict_triggered.connect(_on_conflict_triggered)
		if _conflict_system.has_signal("conflict_resolved"):
			_conflict_system.conflict_resolved.connect(_on_conflict_resolved)
		if _conflict_system.has_signal("conflict_escalated"):
			_conflict_system.conflict_escalated.connect(_on_conflict_escalated)

	# 初始化过滤器
	_setup_filters()

	# 初始化列表
	if empty_label:
		empty_label.visible = false

	print("[ConflictLogPanel] 冲突日志面板初始化完成")

func _init_object_pool():
	"""初始化对象池"""
	var ObjectPool = load("res://script/ui/observation/ObjectPool.gd")

	# 创建冲突项工厂函数
	var factory = func() -> PanelContainer:
		return _create_conflict_item_node()

	# 初始池大小15, 最大50
	_item_pool = ObjectPool.new(factory, 15, 50)

	print("[ConflictLogPanel] 对象池初始化完成")

func _setup_filters():
	"""设置过滤器选项"""
	if status_filter:
		status_filter.clear()
		status_filter.add_item("全部", 0)
		status_filter.add_item("活跃中", 1)
		status_filter.add_item("已解决", 2)
		status_filter.item_selected.connect(_on_status_filter_changed)

	if severity_filter:
		severity_filter.clear()
		severity_filter.add_item("全部严重程度", 0)
		severity_filter.add_item("轻微 (1-2)", 1)
		severity_filter.add_item("中等 (3-5)", 2)
		severity_filter.add_item("严重 (6-8)", 3)
		severity_filter.add_item("危急 (9)", 4)
		severity_filter.item_selected.connect(_on_severity_filter_changed)

func refresh_list():
	"""刷新冲突列表"""
	_clear_list()

	if not _conflict_system:
		_show_empty_message("冲突系统未加载")
		return

	# 获取所有冲突
	var all_conflicts = _conflict_system.get_all_conflicts()

	if all_conflicts.is_empty():
		_show_empty_message("暂无冲突记录")
		return

	# 应用过滤器
	var filtered_conflicts = _apply_filters(all_conflicts)

	if filtered_conflicts.is_empty():
		_show_empty_message("没有符合筛选条件的冲突")
		return

	# 显示冲突列表
	if empty_label:
		empty_label.visible = false

	for conflict in filtered_conflicts:
		_add_conflict_item(conflict)

func _clear_list():
	"""清空列表(使用对象池)"""
	# 释放所有活跃的列表项回对象池
	for item in _active_items:
		if item and is_instance_valid(item):
			if item.get_parent() == conflict_list:
				conflict_list.remove_child(item)
			if _item_pool:
				_item_pool.release(item)

	_active_items.clear()

func _show_empty_message(message: String):
	"""显示空消息

	Args:
		message: 消息文本
	"""
	if empty_label:
		empty_label.text = message
		empty_label.visible = true

func _apply_filters(conflicts: Array) -> Array:
	"""应用过滤器

	Args:
		conflicts: 冲突数组

	Returns:
		过滤后的冲突数组
	"""
	var filtered = []

	for conflict in conflicts:
		# 状态过滤
		if _current_status_filter == "active":
			var status = conflict.get("status", "")
			if status in ["RESOLVED", "UNRESOLVED"]:
				continue
		elif _current_status_filter == "resolved":
			var status = conflict.get("status", "")
			if status not in ["RESOLVED", "UNRESOLVED"]:
				continue

		# 严重程度过滤
		var severity = conflict.get("severity", 1)
		if _current_severity_filter == "minor" and severity > 2:
			continue
		elif _current_severity_filter == "moderate" and (severity < 3 or severity > 5):
			continue
		elif _current_severity_filter == "major" and (severity < 6 or severity > 8):
			continue
		elif _current_severity_filter == "critical" and severity != 9:
			continue

		filtered.append(conflict)

	# 按时间倒序排序(最新的在前)
	filtered.sort_custom(func(a, b): return a.get("created_at", 0.0) > b.get("created_at", 0.0))

	return filtered

func _add_conflict_item(conflict: Dictionary):
	"""添加冲突列表项(使用对象池)

	Args:
		conflict: 冲突数据
	"""
	if not _item_pool:
		return

	var conflict_id = conflict.get("conflict_id", "")
	var source_id = conflict.get("source_id", "")
	var target_id = conflict.get("target_id", "")
	var conflict_type = conflict.get("conflict_type", "UNKNOWN")
	var severity = conflict.get("severity", 1)
	var status = conflict.get("status", "TRIGGERED")
	var created_at = conflict.get("created_at", 0.0)

	# 从对象池获取列表项
	var item = _item_pool.acquire()
	if not item:
		push_warning("[ConflictLogPanel] 对象池无法提供更多对象")
		return

	# 更新列表项内容
	_populate_conflict_item(item, conflict_id, source_id, target_id, conflict_type, severity, status, created_at)

	# 添加到列表
	if conflict_list and item.get_parent() != conflict_list:
		conflict_list.add_child(item)

	# 记录活跃项
	_active_items.append(item)

func _create_conflict_item_node() -> PanelContainer:
	"""创建冲突列表项节点结构(对象池工厂函数)

	Returns:
		PanelContainer节点
	"""
	# 创建列表项容器
	var item = PanelContainer.new()
	item.custom_minimum_size = Vector2(0, 60)

	# 创建水平布局
	var hbox = HBoxContainer.new()
	hbox.name = "HBox"
	item.add_child(hbox)

	# 严重程度指示器(ColorRect)
	var severity_indicator = ColorRect.new()
	severity_indicator.name = "SeverityIndicator"
	severity_indicator.custom_minimum_size = Vector2(5, 0)
	severity_indicator.color = Color.GRAY
	hbox.add_child(severity_indicator)

	# 添加间距
	var spacer1 = Control.new()
	spacer1.name = "Spacer1"
	spacer1.custom_minimum_size = Vector2(10, 0)
	hbox.add_child(spacer1)

	# 信息容器(VBoxContainer)
	var vbox = VBoxContainer.new()
	vbox.name = "VBox"
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(vbox)

	# 冲突双方和类型
	var title_label = Label.new()
	title_label.name = "TitleLabel"
	title_label.text = ""
	title_label.add_theme_font_size_override("font_size", 14)
	vbox.add_child(title_label)

	# 状态和时间
	var status_label = Label.new()
	status_label.name = "StatusLabel"
	status_label.text = ""
	status_label.add_theme_font_size_override("font_size", 11)
	status_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	vbox.add_child(status_label)

	return item

func _populate_conflict_item(item: PanelContainer, conflict_id: String, source_id: String,
							  target_id: String, conflict_type: String, severity: int,
							  status: String, created_at: float):
	"""填充冲突列表项内容

	Args:
		item: 列表项节点
		conflict_id: 冲突ID
		source_id: 源AI ID
		target_id: 目标AI ID
		conflict_type: 冲突类型
		severity: 严重程度
		status: 状态
		created_at: 创建时间
	"""
	# 更新元数据
	item.set_meta("conflict_id", conflict_id)

	# 更新严重程度指示器
	var hbox = item.get_node_or_null("HBox")
	if hbox:
		var severity_indicator = hbox.get_node_or_null("SeverityIndicator")
		if severity_indicator:
			severity_indicator.color = SEVERITY_COLORS.get(severity, Color.GRAY)

	# 更新标题
	var vbox = hbox.get_node_or_null("VBox") if hbox else null
	if vbox:
		var title_label = vbox.get_node_or_null("TitleLabel")
		if title_label:
			title_label.text = "%s vs %s - %s" % [
				_get_short_name(source_id),
				_get_short_name(target_id),
				CONFLICT_TYPE_LABELS.get(conflict_type, conflict_type)
			]

		# 更新状态
		var status_label = vbox.get_node_or_null("StatusLabel")
		if status_label:
			var time_str = _format_time(created_at)
			status_label.text = "状态: %s | 严重程度: %d | 时间: %s" % [
				STATUS_LABELS.get(status, status),
				severity,
				time_str
			]

	# 重新连接点击事件(先断开旧连接)
	if item.gui_input.is_connected(_on_conflict_item_gui_input):
		item.gui_input.disconnect(_on_conflict_item_gui_input)
	item.gui_input.connect(_on_conflict_item_gui_input.bind(conflict_id))

func _get_short_name(ai_id: String) -> String:
	"""获取简短名称

	Args:
		ai_id: AI ID

	Returns:
		简短名称
	"""
	# 简单处理: 移除后缀数字
	var parts = ai_id.split("_")
	if parts.size() > 0:
		return parts[0].capitalize()
	return ai_id

func _format_time(timestamp: float) -> String:
	"""格式化时间戳

	Args:
		timestamp: Unix时间戳

	Returns:
		格式化的时间字符串
	"""
	if not _time_system:
		return "未知时间"

	# 简单格式化(实际应该通过TimeSystem转换)
	var datetime = Time.get_datetime_dict_from_unix_time(int(timestamp))
	return "%02d:%02d" % [datetime.hour, datetime.minute]

func _on_conflict_item_gui_input(event: InputEvent, conflict_id: String):
	"""处理冲突项点击事件

	Args:
		event: 输入事件
		conflict_id: 冲突ID
	"""
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			conflict_selected.emit(conflict_id)
			print("[ConflictLogPanel] 选中冲突: %s" % conflict_id)

func _on_status_filter_changed(index: int):
	"""状态过滤器变化

	Args:
		index: 选项索引
	"""
	match index:
		0: _current_status_filter = "all"
		1: _current_status_filter = "active"
		2: _current_status_filter = "resolved"

	refresh_list()

func _on_severity_filter_changed(index: int):
	"""严重程度过滤器变化

	Args:
		index: 选项索引
	"""
	match index:
		0: _current_severity_filter = "all"
		1: _current_severity_filter = "minor"
		2: _current_severity_filter = "moderate"
		3: _current_severity_filter = "major"
		4: _current_severity_filter = "critical"

	refresh_list()

func _on_conflict_triggered(conflict_id: String, conflict_data: Dictionary):
	"""处理冲突触发事件

	Args:
		conflict_id: 冲突ID
		conflict_data: 冲突数据
	"""
	# 延迟刷新
	_delayed_refresh()

func _on_conflict_resolved(conflict_id: String, conflict_data: Dictionary):
	"""处理冲突解决事件

	Args:
		conflict_id: 冲突ID
		conflict_data: 冲突数据
	"""
	# 延迟刷新
	_delayed_refresh()

func _on_conflict_escalated(conflict_id: String, new_severity: int):
	"""处理冲突升级事件

	Args:
		conflict_id: 冲突ID
		new_severity: 新严重程度
	"""
	# 延迟刷新
	_delayed_refresh()

func _delayed_refresh():
	"""延迟刷新(避免频繁更新)"""
	if not has_node("RefreshTimer"):
		var timer = Timer.new()
		timer.name = "RefreshTimer"
		timer.wait_time = 0.3
		timer.one_shot = true
		timer.timeout.connect(refresh_list)
		add_child(timer)
		timer.start()
	else:
		get_node("RefreshTimer").start()
