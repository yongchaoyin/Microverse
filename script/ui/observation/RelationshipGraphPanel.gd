extends Panel

# ========================================
# RelationshipGraphPanel - 关系图可视化面板
# ========================================
#
# 功能:
# - 显示所有AI角色的关系网络图
# - 节点显示角色头像和名称
# - 连线颜色表示关系类型(朋友/敌人/恋人/陌生人)
# - 点击节点查看详情,点击连线查看关系历史
#
# ========================================

# 系统引用
var _relationship_manager = null
var _character_manager = null
var _memory_manager = null

# UI引用
@onready var graph_canvas = $GraphCanvas
@onready var node_container = $NodeContainer
@onready var tooltip_label = $TooltipLabel

# 图形数据
var _character_nodes: Dictionary = {}  # {ai_id: {position: Vector2, node: Control}}
var _relationship_edges: Array = []  # [{from_id, to_id, relationship_data}]

# 布局参数
const NODE_SIZE = Vector2(80, 80)
const MIN_NODE_DISTANCE = 150.0
const GRAPH_CENTER = Vector2(400, 300)
const GRAPH_RADIUS = 250.0

# 拖拽状态
var _dragging_node_id: String = ""
var _drag_offset: Vector2 = Vector2.ZERO
var _is_dragging: bool = false

# 缩放和平移状态
var _zoom_level: float = 1.0
var _pan_offset: Vector2 = Vector2.ZERO
var _is_panning: bool = false
var _pan_start: Vector2 = Vector2.ZERO

# 缩放参数
const MIN_ZOOM = 0.5
const MAX_ZOOM = 2.0
const ZOOM_STEP = 0.1

# 关系颜色编码
const RELATIONSHIP_COLORS = {
	"friend": Color(0.3, 0.8, 0.3),      # 绿色 - 朋友
	"close_friend": Color(0.2, 0.9, 0.2), # 亮绿色 - 好友
	"enemy": Color(0.9, 0.2, 0.2),       # 红色 - 敌人
	"rival": Color(0.8, 0.3, 0.1),       # 橙红色 - 竞争对手
	"lover": Color(0.9, 0.3, 0.6),       # 粉色 - 恋人
	"spouse": Color(0.9, 0.1, 0.5),      # 深粉色 - 配偶
	"stranger": Color(0.5, 0.5, 0.5),    # 灰色 - 陌生人
	"acquaintance": Color(0.6, 0.6, 0.6), # 浅灰色 - 熟人
	"default": Color(0.7, 0.7, 0.7)      # 默认灰色
}

# 信号
signal node_selected(ai_id: String)
signal edge_selected(from_id: String, to_id: String)

func _ready():
	"""初始化面板"""
	# 获取系统引用
	_relationship_manager = get_node_or_null("/root/RelationshipManager")
	_character_manager = get_node_or_null("/root/CharacterManager")
	_memory_manager = get_node_or_null("/root/MemoryManager")

	# 隐藏提示标签
	if tooltip_label:
		tooltip_label.visible = false

	# 连接信号
	if _relationship_manager:
		if _relationship_manager.has_signal("relationship_changed"):
			_relationship_manager.relationship_changed.connect(_on_relationship_changed)

	print("[RelationshipGraphPanel] 关系图面板初始化完成")

func refresh_graph():
	"""刷新整个关系图"""
	_clear_graph()
	_load_characters()
	_load_relationships()
	_layout_nodes()
	queue_redraw()

func _clear_graph():
	"""清空图形"""
	_character_nodes.clear()
	_relationship_edges.clear()

	# 清空节点容器
	if node_container:
		for child in node_container.get_children():
			child.queue_free()

func _load_characters():
	"""加载所有角色节点"""
	if not _character_manager:
		return

	# 获取场景中所有角色
	var characters = get_tree().get_nodes_in_group("characters")

	for character in characters:
		var ai_id = character.get_meta("ai_id", character.name)
		_create_character_node(ai_id, character.name)

func _create_character_node(ai_id: String, character_name: String):
	"""创建角色节点

	Args:
		ai_id: AI ID
		character_name: 角色显示名称
	"""
	# 创建节点UI
	var node = Panel.new()
	node.custom_minimum_size = NODE_SIZE
	node.set_meta("ai_id", ai_id)

	# 创建垂直布局
	var vbox = VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	node.add_child(vbox)

	# 添加头像占位符(简单的ColorRect)
	var avatar = ColorRect.new()
	avatar.custom_minimum_size = Vector2(60, 60)
	avatar.color = Color(randf(), randf(), randf())  # 随机颜色作为占位
	avatar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vbox.add_child(avatar)

	# 添加名称标签
	var name_label = Label.new()
	name_label.text = character_name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 12)
	vbox.add_child(name_label)

	# 添加到容器
	if node_container:
		node_container.add_child(node)

	# 连接点击事件
	node.gui_input.connect(_on_node_gui_input.bind(ai_id))

	# 存储节点数据
	_character_nodes[ai_id] = {
		"position": Vector2.ZERO,  # 将在布局时设置
		"node": node,
		"name": character_name
	}

func _load_relationships():
	"""加载所有关系连线"""
	if not _relationship_manager:
		return

	# 获取所有角色对的关系
	var ai_ids = _character_nodes.keys()

	for i in range(ai_ids.size()):
		for j in range(i + 1, ai_ids.size()):
			var ai_a = ai_ids[i]
			var ai_b = ai_ids[j]

			# 获取关系数据
			var relationship = _relationship_manager.get_relationship(ai_a, ai_b)
			if relationship.is_empty():
				continue

			# 检查是否有显著关系(好感度或信任度 > 30 或 < -30)
			var affection = relationship.get("affection", 0.0)
			var trust = relationship.get("trust", 0.0)

			if abs(affection) > 30 or abs(trust) > 30:
				_relationship_edges.append({
					"from_id": ai_a,
					"to_id": ai_b,
					"relationship": relationship
				})

func _layout_nodes():
	"""布局节点位置(圆形布局)"""
	var node_count = _character_nodes.size()
	if node_count == 0:
		return

	var ai_ids = _character_nodes.keys()
	var angle_step = TAU / node_count  # 2*PI / count

	for i in range(node_count):
		var ai_id = ai_ids[i]
		var angle = i * angle_step

		# 计算圆形布局位置
		var pos = GRAPH_CENTER + Vector2(
			cos(angle) * GRAPH_RADIUS,
			sin(angle) * GRAPH_RADIUS
		)

		# 更新节点位置
		_character_nodes[ai_id]["position"] = pos

		# 设置UI节点位置
		var node = _character_nodes[ai_id]["node"]
		if node:
			node.position = pos - NODE_SIZE / 2  # 居中

func _draw():
	"""绘制关系连线"""
	if not graph_canvas:
		return

	# 绘制所有关系边
	for edge in _relationship_edges:
		_draw_relationship_edge(edge)

func _draw_relationship_edge(edge: Dictionary):
	"""绘制单条关系边

	Args:
		edge: 边数据 {from_id, to_id, relationship}
	"""
	var from_id = edge.get("from_id", "")
	var to_id = edge.get("to_id", "")

	if not _character_nodes.has(from_id) or not _character_nodes.has(to_id):
		return

	var from_pos = _character_nodes[from_id]["position"]
	var to_pos = _character_nodes[to_id]["position"]

	# 确定关系类型和颜色
	var relationship = edge.get("relationship", {})
	var relationship_type = _get_relationship_type(relationship)
	var color = RELATIONSHIP_COLORS.get(relationship_type, RELATIONSHIP_COLORS["default"])

	# 根据关系强度调整线宽
	var affection = relationship.get("affection", 0.0)
	var trust = relationship.get("trust", 0.0)
	var strength = (abs(affection) + abs(trust)) / 200.0  # 归一化到0-1
	var line_width = clamp(strength * 4, 1.0, 5.0)

	# 绘制连线
	if graph_canvas:
		graph_canvas.draw_line(from_pos, to_pos, color, line_width)

func _get_relationship_type(relationship: Dictionary) -> String:
	"""根据关系数据确定关系类型

	Args:
		relationship: 关系数据

	Returns:
		关系类型字符串
	"""
	var tags = relationship.get("tags", [])

	# 检查标签
	if "spouse" in tags:
		return "spouse"
	if "lover" in tags:
		return "lover"
	if "enemy" in tags:
		return "enemy"
	if "rival" in tags:
		return "rival"
	if "close_friend" in tags:
		return "close_friend"
	if "friend" in tags:
		return "friend"
	if "acquaintance" in tags:
		return "acquaintance"

	# 根据好感度和信任度判断
	var affection = relationship.get("affection", 0.0)
	var trust = relationship.get("trust", 0.0)

	if affection < -50 or trust < -50:
		return "enemy"
	elif affection > 70 and trust > 70:
		return "close_friend"
	elif affection > 50:
		return "friend"
	elif affection > 20:
		return "acquaintance"

	return "stranger"

func _gui_input(event: InputEvent):
	"""处理图形画布输入"""
	# 处理缩放
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_in(event.position)
			accept_event()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_out(event.position)
			accept_event()
		elif event.button_index == MOUSE_BUTTON_MIDDLE:
			if event.pressed:
				_start_pan(event.position)
			else:
				_end_pan()
			accept_event()

	# 处理平移拖拽
	elif event is InputEventMouseMotion:
		if _is_panning:
			_update_pan(event.position)
		elif _is_dragging:
			_update_drag(event.position)

func _on_node_gui_input(event: InputEvent, ai_id: String):
	"""处理节点点击事件

	Args:
		event: 输入事件
		ai_id: 角色AI ID
	"""
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				# 开始拖拽
				_start_drag(ai_id, event.position)
				node_selected.emit(ai_id)
				print("[RelationshipGraphPanel] 选中节点: %s" % ai_id)
			else:
				# 结束拖拽
				_end_drag()

	elif event is InputEventMouseMotion:
		if _is_dragging and _dragging_node_id == ai_id:
			_update_drag(event.position)

func _on_relationship_changed(ai_a: String, ai_b: String, change_data: Dictionary):
	"""处理关系变化事件

	Args:
		ai_a: 角色A ID
		ai_b: 角色B ID
		change_data: 变化数据
	"""
	# 延迟刷新(避免频繁更新)
	if not has_node("RefreshTimer"):
		var timer = Timer.new()
		timer.name = "RefreshTimer"
		timer.wait_time = 0.5
		timer.one_shot = true
		timer.timeout.connect(_delayed_refresh)
		add_child(timer)
		timer.start()

func _delayed_refresh():
	"""延迟刷新"""
	refresh_graph()

func show_tooltip(text: String, position: Vector2):
	"""显示提示框

	Args:
		text: 提示文本
		position: 显示位置
	"""
	if tooltip_label:
		tooltip_label.text = text
		tooltip_label.position = position
		tooltip_label.visible = true

func hide_tooltip():
	"""隐藏提示框"""
	if tooltip_label:
		tooltip_label.visible = false

# ========================================
# 拖拽功能
# ========================================

func _start_drag(ai_id: String, mouse_pos: Vector2):
	"""开始拖拽节点

	Args:
		ai_id: 节点AI ID
		mouse_pos: 鼠标位置
	"""
	if not _character_nodes.has(ai_id):
		return

	_is_dragging = true
	_dragging_node_id = ai_id

	var node_data = _character_nodes[ai_id]
	var node = node_data.get("node")
	if node:
		_drag_offset = mouse_pos - node.position

func _update_drag(mouse_pos: Vector2):
	"""更新拖拽位置

	Args:
		mouse_pos: 鼠标位置
	"""
	if not _is_dragging or _dragging_node_id.is_empty():
		return

	if not _character_nodes.has(_dragging_node_id):
		return

	var node_data = _character_nodes[_dragging_node_id]
	var node = node_data.get("node")
	if node:
		# 计算新位置
		var new_pos = mouse_pos - _drag_offset
		node.position = new_pos

		# 更新存储的逻辑位置
		node_data["position"] = new_pos + NODE_SIZE / 2  # 中心点

		# 重绘连线
		queue_redraw()

func _end_drag():
	"""结束拖拽"""
	_is_dragging = false
	_dragging_node_id = ""
	_drag_offset = Vector2.ZERO

# ========================================
# 缩放和平移功能
# ========================================

func _zoom_in(mouse_pos: Vector2):
	"""放大视图

	Args:
		mouse_pos: 鼠标位置(缩放中心)
	"""
	var old_zoom = _zoom_level
	_zoom_level = clamp(_zoom_level + ZOOM_STEP, MIN_ZOOM, MAX_ZOOM)

	if _zoom_level != old_zoom:
		_apply_zoom(mouse_pos, old_zoom)

func _zoom_out(mouse_pos: Vector2):
	"""缩小视图

	Args:
		mouse_pos: 鼠标位置(缩放中心)
	"""
	var old_zoom = _zoom_level
	_zoom_level = clamp(_zoom_level - ZOOM_STEP, MIN_ZOOM, MAX_ZOOM)

	if _zoom_level != old_zoom:
		_apply_zoom(mouse_pos, old_zoom)

func _apply_zoom(mouse_pos: Vector2, old_zoom: float):
	"""应用缩放变换

	Args:
		mouse_pos: 缩放中心点
		old_zoom: 旧缩放级别
	"""
	if not node_container:
		return

	# 设置缩放
	node_container.scale = Vector2(_zoom_level, _zoom_level)

	# 调整位置以保持鼠标位置不变
	var zoom_ratio = _zoom_level / old_zoom
	var offset = mouse_pos - node_container.position
	node_container.position = mouse_pos - offset * zoom_ratio

	queue_redraw()

func _start_pan(mouse_pos: Vector2):
	"""开始平移

	Args:
		mouse_pos: 鼠标位置
	"""
	_is_panning = true
	_pan_start = mouse_pos

func _update_pan(mouse_pos: Vector2):
	"""更新平移

	Args:
		mouse_pos: 鼠标位置
	"""
	if not _is_panning:
		return

	var delta = mouse_pos - _pan_start
	_pan_offset += delta
	_pan_start = mouse_pos

	# 应用平移
	if node_container:
		node_container.position += delta

	queue_redraw()

func _end_pan():
	"""结束平移"""
	_is_panning = false

func reset_view():
	"""重置视图(缩放和平移)"""
	_zoom_level = 1.0
	_pan_offset = Vector2.ZERO

	if node_container:
		node_container.scale = Vector2.ONE
		node_container.position = Vector2.ZERO

	queue_redraw()
	print("[RelationshipGraphPanel] 视图已重置")
