extends CanvasLayer

# ========================================
# ObservationUI - 观察者UI主容器
# ========================================
#
# 功能:
# - 整合关系图、冲突日志、关系详情三个面板
# - 提供快捷键切换显示/隐藏
# - 协调各面板之间的交互
#
# 快捷键:
# - O键: 切换ObservationUI显示/隐藏
#
# ========================================

# UI引用
@onready var main_container = $MainContainer
@onready var tab_container = $MainContainer/TabContainer

# 面板引用(手动创建或从场景加载)
var relationship_graph_panel = null
var conflict_log_panel = null
var relationship_detail_panel = null

# 显示状态
var _is_visible: bool = false

func _ready():
	"""初始化UI"""
	# 应用统一主题
	_apply_theme()

	# 创建面板实例(如果使用纯代码创建)
	_create_panels()

	# 初始隐藏
	if main_container:
		main_container.visible = false

	print("[ObservationUI] 观察者UI初始化完成")

func _apply_theme():
	"""应用统一主题"""
	var MicroverseTheme = load("res://script/ui/themes/MicroverseTheme.gd")
	if MicroverseTheme:
		var theme = MicroverseTheme.create_theme()
		if main_container:
			main_container.theme = theme
		print("[ObservationUI] 主题已应用")

func _create_panels():
	"""创建面板实例"""
	if not tab_container:
		push_warning("[ObservationUI] TabContainer未找到")
		return

	# 加载面板脚本
	var RelationshipGraphPanel = load("res://script/ui/observation/RelationshipGraphPanel.gd")
	var ConflictLogPanel = load("res://script/ui/observation/ConflictLogPanel.gd")
	var RelationshipDetailPanel = load("res://script/ui/observation/RelationshipDetailPanel.gd")

	# 创建关系图面板
	if RelationshipGraphPanel:
		relationship_graph_panel = RelationshipGraphPanel.new()
		relationship_graph_panel.name = "关系图"
		relationship_graph_panel.custom_minimum_size = Vector2(800, 600)
		_setup_relationship_graph_panel()
		tab_container.add_child(relationship_graph_panel)

	# 创建冲突日志面板
	if ConflictLogPanel:
		conflict_log_panel = ConflictLogPanel.new()
		conflict_log_panel.name = "冲突日志"
		conflict_log_panel.custom_minimum_size = Vector2(800, 600)
		_setup_conflict_log_panel()
		tab_container.add_child(conflict_log_panel)

	# 创建关系详情面板
	if RelationshipDetailPanel:
		relationship_detail_panel = RelationshipDetailPanel.new()
		relationship_detail_panel.name = "关系详情"
		relationship_detail_panel.custom_minimum_size = Vector2(800, 600)
		tab_container.add_child(relationship_detail_panel)

func _setup_relationship_graph_panel():
	"""设置关系图面板"""
	if not relationship_graph_panel:
		return

	# 创建必要的子节点
	var graph_canvas = Control.new()
	graph_canvas.name = "GraphCanvas"
	graph_canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	graph_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	relationship_graph_panel.add_child(graph_canvas)

	var node_container = Control.new()
	node_container.name = "NodeContainer"
	node_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	node_container.mouse_filter = Control.MOUSE_FILTER_PASS
	relationship_graph_panel.add_child(node_container)

	var tooltip_label = Label.new()
	tooltip_label.name = "TooltipLabel"
	tooltip_label.visible = false
	relationship_graph_panel.add_child(tooltip_label)

	# 连接信号
	if relationship_graph_panel.has_signal("node_selected"):
		relationship_graph_panel.node_selected.connect(_on_relationship_node_selected)
	if relationship_graph_panel.has_signal("edge_selected"):
		relationship_graph_panel.edge_selected.connect(_on_relationship_edge_selected)

func _setup_conflict_log_panel():
	"""设置冲突日志面板"""
	if not conflict_log_panel:
		return

	# 创建必要的子节点
	var vbox = VBoxContainer.new()
	vbox.name = "VBoxContainer"
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	conflict_log_panel.add_child(vbox)

	# 过滤器容器
	var filter_container = HBoxContainer.new()
	filter_container.name = "FilterContainer"
	vbox.add_child(filter_container)

	var status_filter = OptionButton.new()
	status_filter.name = "StatusFilter"
	filter_container.add_child(status_filter)

	var severity_filter = OptionButton.new()
	severity_filter.name = "SeverityFilter"
	filter_container.add_child(severity_filter)

	# 冲突列表容器
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)

	var conflict_list = VBoxContainer.new()
	conflict_list.name = "ConflictList"
	conflict_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(conflict_list)

	# 空状态标签
	var empty_label = Label.new()
	empty_label.name = "EmptyLabel"
	empty_label.text = "暂无冲突记录"
	empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	empty_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	conflict_list.add_child(empty_label)

	# 连接信号
	if conflict_log_panel.has_signal("conflict_selected"):
		conflict_log_panel.conflict_selected.connect(_on_conflict_selected)

func _input(event: InputEvent):
	"""处理输入事件"""
	if event is InputEventKey and event.pressed:
		# O键切换显示
		if event.keycode == KEY_O and not event.is_echo():
			toggle_visibility()

func toggle_visibility():
	"""切换显示/隐藏"""
	_is_visible = not _is_visible

	if main_container:
		main_container.visible = _is_visible

	if _is_visible:
		_refresh_all_panels()
		print("[ObservationUI] 显示观察者UI")
	else:
		print("[ObservationUI] 隐藏观察者UI")

func show_ui():
	"""显示UI"""
	if not _is_visible:
		toggle_visibility()

func hide_ui():
	"""隐藏UI"""
	if _is_visible:
		toggle_visibility()

func _refresh_all_panels():
	"""刷新所有面板"""
	if relationship_graph_panel and relationship_graph_panel.has_method("refresh_graph"):
		relationship_graph_panel.refresh_graph()

	if conflict_log_panel and conflict_log_panel.has_method("refresh_list"):
		conflict_log_panel.refresh_list()

func _on_relationship_node_selected(ai_id: String):
	"""处理关系图节点选中事件

	Args:
		ai_id: 选中的AI ID
	"""
	print("[ObservationUI] 节点选中: %s" % ai_id)

	# 可以在这里添加逻辑,例如高亮该AI的所有关系

func _on_relationship_edge_selected(from_id: String, to_id: String):
	"""处理关系图连线选中事件

	Args:
		from_id: AI A的ID
		to_id: AI B的ID
	"""
	print("[ObservationUI] 连线选中: %s <-> %s" % [from_id, to_id])

	# 切换到关系详情面板并显示详情
	if tab_container:
		tab_container.current_tab = 2  # 关系详情是第3个标签

	if relationship_detail_panel and relationship_detail_panel.has_method("show_relationship"):
		relationship_detail_panel.show_relationship(from_id, to_id)

func _on_conflict_selected(conflict_id: String):
	"""处理冲突选中事件

	Args:
		conflict_id: 冲突ID
	"""
	print("[ObservationUI] 冲突选中: %s" % conflict_id)

	# 可以在这里添加逻辑,例如显示冲突详情弹窗

func get_relationship_graph_panel():
	"""获取关系图面板引用

	Returns:
		RelationshipGraphPanel实例
	"""
	return relationship_graph_panel

func get_conflict_log_panel():
	"""获取冲突日志面板引用

	Returns:
		ConflictLogPanel实例
	"""
	return conflict_log_panel

func get_relationship_detail_panel():
	"""获取关系详情面板引用

	Returns:
		RelationshipDetailPanel实例
	"""
	return relationship_detail_panel
