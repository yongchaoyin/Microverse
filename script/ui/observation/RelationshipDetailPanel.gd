extends Panel

# ========================================
# RelationshipDetailPanel - 关系详情面板
# ========================================
#
# 功能:
# - 显示两个AI之间的详细关系信息
# - 关系维度数值(好感/信任/尊重等)
# - 关系标签和里程碑
# - 互动历史和冲突历史
#
# ========================================

# 系统引用
var _relationship_manager = null
var _memory_manager = null
var _conflict_system = null

# UI引用
@onready var ai_a_label = $VBoxContainer/HeaderContainer/AIALabel
@onready var ai_b_label = $VBoxContainer/HeaderContainer/AIBLabel
@onready var relationship_icon = $VBoxContainer/HeaderContainer/RelationshipIcon

@onready var dimensions_container = $VBoxContainer/ScrollContainer/ContentContainer/DimensionsContainer
@onready var tags_container = $VBoxContainer/ScrollContainer/ContentContainer/TagsContainer
@onready var milestones_container = $VBoxContainer/ScrollContainer/ContentContainer/MilestonesContainer
@onready var history_container = $VBoxContainer/ScrollContainer/ContentContainer/HistoryContainer
@onready var conflicts_container = $VBoxContainer/ScrollContainer/ContentContainer/ConflictsContainer

@onready var empty_label = $VBoxContainer/EmptyLabel

# 当前显示的关系
var _current_ai_a: String = ""
var _current_ai_b: String = ""

func _ready():
	"""初始化面板"""
	# 获取系统引用
	_relationship_manager = get_node_or_null("/root/RelationshipManager")
	_memory_manager = get_node_or_null("/root/MemoryManager")
	_conflict_system = get_node_or_null("/root/ConflictSystem")

	# 初始显示空状态
	_show_empty_state()

	print("[RelationshipDetailPanel] 关系详情面板初始化完成")

func show_relationship(ai_a: String, ai_b: String):
	"""显示两个AI之间的关系

	Args:
		ai_a: AI A的ID
		ai_b: AI B的ID
	"""
	_current_ai_a = ai_a
	_current_ai_b = ai_b

	if ai_a.is_empty() or ai_b.is_empty():
		_show_empty_state()
		return

	if empty_label:
		empty_label.visible = false

	# 更新标题
	_update_header(ai_a, ai_b)

	# 更新各个部分
	_update_dimensions(ai_a, ai_b)
	_update_tags(ai_a, ai_b)
	_update_milestones(ai_a, ai_b)
	_update_history(ai_a, ai_b)
	_update_conflicts(ai_a, ai_b)

func _show_empty_state():
	"""显示空状态"""
	if empty_label:
		empty_label.text = "点击关系图节点或连线查看详情"
		empty_label.visible = true

	# 隐藏内容
	if dimensions_container:
		dimensions_container.visible = false
	if tags_container:
		tags_container.visible = false
	if milestones_container:
		milestones_container.visible = false
	if history_container:
		history_container.visible = false
	if conflicts_container:
		conflicts_container.visible = false

func _update_header(ai_a: String, ai_b: String):
	"""更新标题

	Args:
		ai_a: AI A的ID
		ai_b: AI B的ID
	"""
	if ai_a_label:
		ai_a_label.text = _get_display_name(ai_a)

	if ai_b_label:
		ai_b_label.text = _get_display_name(ai_b)

	# TODO: 根据关系类型设置图标
	if relationship_icon:
		relationship_icon.text = "❤️"  # 占位符

func _update_dimensions(ai_a: String, ai_b: String):
	"""更新关系维度

	Args:
		ai_a: AI A的ID
		ai_b: AI B的ID
	"""
	if not dimensions_container:
		return

	dimensions_container.visible = true

	# 清空旧内容
	for child in dimensions_container.get_children():
		if child.name.begins_with("Dimension"):
			child.queue_free()

	if not _relationship_manager:
		return

	# 获取关系数据
	var relationship = _relationship_manager.get_relationship(ai_a, ai_b)
	if relationship.is_empty():
		var no_data_label = Label.new()
		no_data_label.text = "暂无关系数据"
		no_data_label.name = "DimensionEmpty"
		dimensions_container.add_child(no_data_label)
		return

	# 显示各维度数值
	var dimensions = ["affection", "trust", "respect", "familiarity"]
	var dimension_labels = {
		"affection": "好感度",
		"trust": "信任度",
		"respect": "尊重度",
		"familiarity": "熟悉度"
	}

	for dim in dimensions:
		var value = relationship.get(dim, 0.0)
		_add_dimension_bar(dimensions_container, dimension_labels.get(dim, dim), value)

func _add_dimension_bar(container: Control, label_text: String, value: float):
	"""添加维度进度条

	Args:
		container: 容器
		label_text: 标签文本
		value: 数值 (-100 到 100)
	"""
	var hbox = HBoxContainer.new()
	hbox.name = "Dimension" + label_text

	# 标签
	var label = Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(80, 0)
	hbox.add_child(label)

	# 进度条
	var progress = ProgressBar.new()
	progress.min_value = -100
	progress.max_value = 100
	progress.value = value
	progress.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	progress.show_percentage = false
	hbox.add_child(progress)

	# 数值标签
	var value_label = Label.new()
	value_label.text = "%.0f" % value
	value_label.custom_minimum_size = Vector2(40, 0)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hbox.add_child(value_label)

	container.add_child(hbox)

func _update_tags(ai_a: String, ai_b: String):
	"""更新关系标签

	Args:
		ai_a: AI A的ID
		ai_b: AI B的ID
	"""
	if not tags_container:
		return

	tags_container.visible = true

	# 清空旧内容
	for child in tags_container.get_children():
		if child.name.begins_with("Tag"):
			child.queue_free()

	if not _relationship_manager:
		return

	# 获取关系数据
	var relationship = _relationship_manager.get_relationship(ai_a, ai_b)
	var tags = relationship.get("tags", [])

	if tags.is_empty():
		var no_tags_label = Label.new()
		no_tags_label.text = "暂无关系标签"
		no_tags_label.name = "TagEmpty"
		tags_container.add_child(no_tags_label)
		return

	# 添加标题
	var title = Label.new()
	title.text = "关系标签:"
	title.name = "TagTitle"
	tags_container.add_child(title)

	# 创建标签流容器
	var flow = HFlowContainer.new()
	flow.name = "TagFlow"
	tags_container.add_child(flow)

	# 显示标签
	for tag in tags:
		var tag_label = Label.new()
		tag_label.text = "• " + tag
		tag_label.add_theme_color_override("font_color", Color(0.3, 0.8, 0.9))
		flow.add_child(tag_label)

func _update_milestones(ai_a: String, ai_b: String):
	"""更新关系里程碑

	Args:
		ai_a: AI A的ID
		ai_b: AI B的ID
	"""
	if not milestones_container:
		return

	milestones_container.visible = true

	# 清空旧内容
	for child in milestones_container.get_children():
		if child.name.begins_with("Milestone"):
			child.queue_free()

	if not _relationship_manager:
		return

	# 获取里程碑
	var milestones = _relationship_manager.get_milestones(ai_a, ai_b)

	if milestones.is_empty():
		var no_milestones_label = Label.new()
		no_milestones_label.text = "暂无关系里程碑"
		no_milestones_label.name = "MilestoneEmpty"
		milestones_container.add_child(no_milestones_label)
		return

	# 添加标题
	var title = Label.new()
	title.text = "关系里程碑:"
	title.name = "MilestoneTitle"
	milestones_container.add_child(title)

	# 显示里程碑
	for milestone in milestones:
		var milestone_label = Label.new()
		milestone_label.text = "🏆 %s" % milestone.get("name", "未知里程碑")
		milestone_label.name = "Milestone" + str(milestone.get("id", ""))
		milestones_container.add_child(milestone_label)

func _update_history(ai_a: String, ai_b: String):
	"""更新互动历史

	Args:
		ai_a: AI A的ID
		ai_b: AI B的ID
	"""
	if not history_container:
		return

	history_container.visible = true

	# 清空旧内容
	for child in history_container.get_children():
		if child.name.begins_with("History"):
			child.queue_free()

	if not _memory_manager:
		return

	# 获取关系历史
	var history = _memory_manager.get_relationship_history(ai_a, ai_b, 10)

	if history.is_empty():
		var no_history_label = Label.new()
		no_history_label.text = "暂无互动历史"
		no_history_label.name = "HistoryEmpty"
		history_container.add_child(no_history_label)
		return

	# 添加标题
	var title = Label.new()
	title.text = "互动历史 (最近10条):"
	title.name = "HistoryTitle"
	history_container.add_child(title)

	# 显示历史记录
	for memory in history:
		var memory_label = Label.new()
		var time_str = _format_game_time(memory.game_time)
		var type_emoji = _get_memory_type_emoji(memory.memory_type)
		memory_label.text = "%s [%s] %s" % [type_emoji, time_str, memory.llm_summary]
		memory_label.name = "History" + memory.memory_id
		memory_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		history_container.add_child(memory_label)

func _update_conflicts(ai_a: String, ai_b: String):
	"""更新冲突历史

	Args:
		ai_a: AI A的ID
		ai_b: AI B的ID
	"""
	if not conflicts_container:
		return

	conflicts_container.visible = true

	# 清空旧内容
	for child in conflicts_container.get_children():
		if child.name.begins_with("Conflict"):
			child.queue_free()

	if not _conflict_system:
		return

	# 获取冲突历史
	var conflicts = _conflict_system.get_conflict_history(ai_a, ai_b)

	if conflicts.is_empty():
		var no_conflicts_label = Label.new()
		no_conflicts_label.text = "暂无冲突历史"
		no_conflicts_label.name = "ConflictEmpty"
		conflicts_container.add_child(no_conflicts_label)
		return

	# 添加标题
	var title = Label.new()
	title.text = "冲突历史:"
	title.name = "ConflictTitle"
	conflicts_container.add_child(title)

	# 显示冲突记录
	for conflict in conflicts:
		var conflict_label = Label.new()
		var status = conflict.get("status", "UNKNOWN")
		var conflict_type = conflict.get("conflict_type", "UNKNOWN")
		var severity = conflict.get("severity", 1)
		conflict_label.text = "⚔️ %s (严重度: %d) - %s" % [conflict_type, severity, status]
		conflict_label.name = "Conflict" + conflict.get("conflict_id", "")
		conflicts_container.add_child(conflict_label)

func _get_display_name(ai_id: String) -> String:
	"""获取显示名称

	Args:
		ai_id: AI ID

	Returns:
		显示名称
	"""
	var parts = ai_id.split("_")
	if parts.size() > 0:
		return parts[0].capitalize()
	return ai_id

func _format_game_time(game_time: Dictionary) -> String:
	"""格式化游戏时间

	Args:
		game_time: 游戏时间字典

	Returns:
		格式化的时间字符串
	"""
	var year = game_time.get("year", 1)
	var season = game_time.get("season", "春季")
	var day = game_time.get("day", 1)
	return "第%d年%s第%d天" % [year, season, day]

func _get_memory_type_emoji(memory_type: String) -> String:
	"""获取记忆类型对应的emoji

	Args:
		memory_type: 记忆类型

	Returns:
		Emoji字符
	"""
	var emoji_map = {
		"conversation": "💬",
		"gift_received": "🎁",
		"gift_given": "🎁",
		"conflict": "⚔️",
		"reconciliation": "🤝",
		"confession": "💕",
		"breakup": "💔",
		"first_meeting": "👋",
		"became_friends": "😊",
		"became_close_friends": "🤗",
		"became_couple": "💑",
		"marriage": "💒",
		"became_enemies": "😡"
	}

	return emoji_map.get(memory_type, "📝")
